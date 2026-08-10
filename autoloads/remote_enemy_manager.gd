extends Node

# RemoteEnemyManager — visual replication of every server-spawned enemy
# in the current zone. Mirrors RemotePlayerManager's two-map / scene-
# swap-survival pattern, but routes EntityIDs in the reserved enemy
# partition (`>= ENEMY_ID_BASE`) to RemoteEnemy instances.
#
# Lifetime invariants identical to RemotePlayerManager:
#   _spawn_data — last known identity + pose per enemy id. Survives
#       scene swaps; source of truth for re-instantiation.
#   _by_id — live RemoteEnemy node per enemy id. Dies with the scene
#       on transition; rehydrated from _spawn_data when the next
#       scene hosts the local player.
#
# Listens to a mix of dedicated signals (world_enemy_spawn,
# world_entity_target) and shared signals (world_position,
# world_health_update, world_entity_died, world_entity_despawn). The
# shared ones come through the same FFI signal as players — this
# manager filters by `id >= ENEMY_ID_BASE` to claim only the enemy
# half. Mirror filter in RemotePlayerManager: `id == get_player_id()`
# is rejected; enemy ids never collide with player char_ids by
# construction.

const REMOTE_ENEMY_SCENE := preload("res://scenes/remote_enemy.tscn")

# Mirror of protocol::world::ENEMY_ID_BASE. Authoritative source is
# the Rust crate; this constant must stay in sync. The lib unit test
# `embedded_toml_parses` covers the server side, and the manual
# verification flow surfaces drift instantly (enemies wouldn't render).
const ENEMY_ID_BASE: int = 1_000_000_000

var _spawn_data: Dictionary = {}   # int enemy_id -> spawn dict
var _by_id: Dictionary = {}        # int enemy_id -> RemoteEnemy node
var _last_scene: Node = null
var _needs_rehydrate: bool = false

func _ready() -> void:
	Net.world_enemy_spawn.connect(_on_enemy_spawn)
	Net.world_entity_target.connect(_on_entity_target)
	Net.world_position.connect(_on_position)
	Net.world_health_update.connect(_on_health_update)
	Net.world_entity_died.connect(_on_entity_died)
	Net.world_entity_despawn.connect(_on_entity_despawn)

# Track 21B — public accessor for the target-of-target frame to
# resolve a server-sent target_id back to a RemoteEnemy node.
func get_by_id(id: int) -> Node:
	return _by_id.get(id)

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _last_scene:
		for re in _by_id.values():
			if is_instance_valid(re):
				re.queue_free()
		_last_scene = scene
		_by_id.clear()
		_needs_rehydrate = true
	if not _needs_rehydrate or scene == null:
		return
	if not _scene_hosts_local_player(scene):
		return
	for id in _spawn_data:
		if not _by_id.has(id):
			_instantiate_into(id, scene)
	_needs_rehydrate = false

func _on_enemy_spawn(
		id: int,
		mob_name: String,
		level: int,
		max_hp: float,
		hp: float,
		pos: Vector3,
		yaw: float) -> void:
	_spawn_data[id] = {
		"mob_name": mob_name,
		"level": level,
		"max_hp": max_hp,
		"hp": hp,
		"pos": pos,
		"yaw": yaw,
	}
	var scene: Node = get_tree().current_scene
	if scene == null or not _scene_hosts_local_player(scene):
		return
	if _by_id.has(id):
		var old = _by_id[id]
		if is_instance_valid(old):
			old.queue_free()
		_by_id.erase(id)
	_instantiate_into(id, scene)

func _on_entity_despawn(id: int) -> void:
	if not _is_enemy_id(id):
		return
	_spawn_data.erase(id)
	var re = _by_id.get(id)
	if re != null:
		if is_instance_valid(re):
			re.queue_free()
		_by_id.erase(id)

func _on_position(id: int, pos: Vector3, _vel: Vector3, yaw: float, sequence: int) -> void:
	if not _is_enemy_id(id):
		return
	var re = _by_id.get(id)
	if re == null:
		return
	re.on_position_update(pos, yaw, sequence)

func _on_health_update(id: int, hp: float, max_hp: float) -> void:
	if not _is_enemy_id(id):
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["hp"] = hp
	data["max_hp"] = max_hp
	var re = _by_id.get(id)
	if re != null and is_instance_valid(re):
		re.apply_health_update(hp, max_hp)

func _on_entity_died(id: int) -> void:
	if not _is_enemy_id(id):
		return
	var re = _by_id.get(id)
	if re != null and is_instance_valid(re):
		re.apply_death()

func _on_entity_target(id: int, target_id: int) -> void:
	if not _is_enemy_id(id):
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["target_id"] = target_id
	var re = _by_id.get(id)
	if re != null and is_instance_valid(re):
		re.apply_target_change(target_id)

func _instantiate_into(id: int, scene: Node) -> void:
	var data: Dictionary = _spawn_data[id]
	var re := REMOTE_ENEMY_SCENE.instantiate()
	re.enemy_id = id
	re.mob_name = data["mob_name"]
	re.level = data["level"]
	re.max_hp = data["max_hp"]
	re.hp = data["hp"]
	# add_child before positioning: global_position on a node that is not yet
	# in the tree logs an error and does not take.
	scene.add_child(re)
	re.global_position = data["pos"]
	re.rotation.y = data["yaw"]
	_by_id[id] = re
	if data.has("target_id"):
		re.apply_target_change(data["target_id"])

func _scene_hosts_local_player(_scene: Node) -> bool:
	return get_tree().get_first_node_in_group("player") != null

func _is_enemy_id(id: int) -> bool:
	return id >= ENEMY_ID_BASE

# Public lookup — used by RemotePlayerManager's _on_hit to resolve a
# server-originated enemy attacker into the live RemoteEnemy node, so
# the damage shield retaliation in Combat.receive_player_damage can
# fire properly (the existing GDScript path takes the attacker Node).
# Returns null if the id isn't tracked or hasn't been instantiated yet.
func get_enemy(id: int) -> Node:
	return _by_id.get(id)

# Defensive — call before zone swaps if needed. Scene change already
# frees the children when the parent scene goes away.
func clear_all() -> void:
	for id in _by_id:
		var re = _by_id[id]
		if is_instance_valid(re):
			re.queue_free()
	_by_id.clear()
	_spawn_data.clear()
