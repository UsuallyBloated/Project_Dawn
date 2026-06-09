extends Node

# RemotePetManager — Track 11. Visual replication of every server-spawned
# player-owned pet in the current zone. Mirrors RemoteEnemyManager's
# two-map / scene-swap-survival pattern, but routes EntityIDs in the
# reserved pet partition (`>= PET_ID_BASE`, 3B+) to RemotePet instances.
#
# Lifetime invariants identical to RemoteEnemyManager:
#   _spawn_data — last known identity + pose per pet id. Survives
#       scene swaps; source of truth for re-instantiation.
#   _by_id — live RemotePet node per pet id. Dies with the scene on
#       transition; rehydrated from _spawn_data when the next scene
#       hosts the local player.
#
# Listens to a dedicated signal (world_pet_spawn) plus the shared
# id-routed signals (world_position, world_health_update,
# world_entity_died, world_entity_despawn). Shared signals come through
# the same FFI as players and enemies — this manager filters by
# `id >= PET_ID_BASE` to claim only the pet half.

const REMOTE_PET_SCENE := preload("res://scenes/remote_pet.tscn")

# Mirror of protocol::world::PET_ID_BASE. Authoritative source is the
# Rust crate; this constant must stay in sync.
const PET_ID_BASE: int = 3_000_000_000

var _spawn_data: Dictionary = {}   # int pet_id -> spawn dict
var _by_id: Dictionary = {}        # int pet_id -> RemotePet node
var _last_scene: Node = null
var _needs_rehydrate: bool = false

func _ready() -> void:
	Net.world_pet_spawn.connect(_on_pet_spawn)
	Net.world_position.connect(_on_position)
	Net.world_health_update.connect(_on_health_update)
	Net.world_entity_died.connect(_on_entity_died)
	Net.world_entity_despawn.connect(_on_entity_despawn)
	# Central refresh of every live pet's allegiance tint when group
	# membership changes or the local /pvp flag flips. RemotePet nodes
	# also subscribe per-instance, but the Round-7 playtest showed pets
	# stuck on the wrong color after `group_updated` fired — this
	# central loop is the redundant path that guarantees the refresh.
	GroupManager.group_updated.connect(_refresh_all_allegiances)
	Net.pvp_toggled.connect(_refresh_all_allegiances_pvp)

func _refresh_all_allegiances(_membership_changed: bool) -> void:
	_refresh_all_allegiances_impl()

func _refresh_all_allegiances_pvp(_on: bool) -> void:
	_refresh_all_allegiances_impl()

func _refresh_all_allegiances_impl() -> void:
	for rp in _by_id.values():
		if is_instance_valid(rp) and rp.has_method("refresh_allegiance"):
			rp.refresh_allegiance()

# Track 21B — public accessor used by the target-of-target frame
# to resolve a server-sent pet_id back to its RemotePet node.
func get_by_id(id: int) -> Node:
	return _by_id.get(id)

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _last_scene:
		for rp in _by_id.values():
			if is_instance_valid(rp):
				rp.queue_free()
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
			# Match the post-spawn registration that `_on_pet_spawn`
			# does for live spawns. Without this the rehydrated pet
			# exists in the scene but PetManager.active_pet stays
			# null — pet-damage chat lines + /pet attack + the HUD
			# pet panel all silently fail until the pet dies and the
			# next PetSpawn lands while the scene is already current.
			var owner_id: int = _spawn_data[id].get("owner", 0)
			if owner_id == Net.get_player_id():
				var rp = _by_id.get(id)
				if rp != null and is_instance_valid(rp):
					PetManager.register_remote_pet(rp)
	_needs_rehydrate = false

func _on_pet_spawn(
		id: int,
		owner: int,
		pet_name: String,
		level: int,
		max_hp: float,
		hp: float,
		pos: Vector3,
		yaw: float) -> void:
	_spawn_data[id] = {
		"owner": owner,
		"pet_name": pet_name,
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
	# Track 11.5 — local player's pet routes through PetManager so
	# the HUD pet panel + any other PetManager.pet_summoned listener
	# fires uniformly across solo and launcher modes.
	if owner == Net.get_player_id():
		var rp = _by_id.get(id)
		if rp != null and is_instance_valid(rp):
			PetManager.register_remote_pet(rp)

func _on_entity_despawn(id: int) -> void:
	if not _is_pet_id(id):
		return
	# Notify PetManager when the local player's pet despawns so the
	# HUD pet panel clears. Identity-gated: during warder respawn the
	# new PetSpawn can arrive before the old corpse's EntityDespawn,
	# briefly making `active_pet` point at the new pet while this
	# handler runs for the old pet. Without the id check we'd orphan
	# the new pet and silently break pet-damage chat + /pet attack
	# until the next death cycle.
	var data: Dictionary = _spawn_data.get(id, {})
	if data.get("owner", 0) == Net.get_player_id():
		var active = PetManager.active_pet
		if active != null and is_instance_valid(active) and active is RemotePet:
			if (active as RemotePet).pet_id == id:
				PetManager.dismiss_remote_pet()
	_spawn_data.erase(id)
	var rp = _by_id.get(id)
	if rp != null:
		if is_instance_valid(rp):
			rp.queue_free()
		_by_id.erase(id)

func _on_position(id: int, pos: Vector3, _vel: Vector3, yaw: float, sequence: int) -> void:
	if not _is_pet_id(id):
		return
	var rp = _by_id.get(id)
	if rp == null:
		return
	rp.on_position_update(pos, yaw, sequence)

func _on_health_update(id: int, hp: float, max_hp: float) -> void:
	if not _is_pet_id(id):
		return
	if not _spawn_data.has(id):
		return
	var data: Dictionary = _spawn_data[id]
	data["hp"] = hp
	data["max_hp"] = max_hp
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_health_update(hp, max_hp)

func _on_entity_died(id: int) -> void:
	if not _is_pet_id(id):
		return
	var rp = _by_id.get(id)
	if rp != null and is_instance_valid(rp):
		rp.apply_death()

func _instantiate_into(id: int, scene: Node) -> void:
	var data: Dictionary = _spawn_data[id]
	var rp := REMOTE_PET_SCENE.instantiate()
	rp.pet_id = id
	rp.owner_id = data["owner"]
	rp.pet_name = data["pet_name"]
	rp.level = data["level"]
	rp.max_hp = data["max_hp"]
	rp.hp = data["hp"]
	rp.global_position = data["pos"]
	rp.rotation.y = data["yaw"]
	scene.add_child(rp)
	_by_id[id] = rp

func _scene_hosts_local_player(_scene: Node) -> bool:
	return get_tree().get_first_node_in_group("player") != null

func _is_pet_id(id: int) -> bool:
	return id >= PET_ID_BASE

# Public lookup — for callers that need to resolve a server-originated
# pet id (e.g. a damage shield triggered by a pet hit) to the live node.
func get_pet(id: int) -> Node:
	return _by_id.get(id)

func clear_all() -> void:
	for id in _by_id:
		var rp = _by_id[id]
		if is_instance_valid(rp):
			rp.queue_free()
	_by_id.clear()
	_spawn_data.clear()
