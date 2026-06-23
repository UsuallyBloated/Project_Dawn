extends Node

# RemoteCorpseManager — visual replication for every server-owned player corpse
# in the current zone (corpse / resurrection epic, Slice 1). Mirrors
# RemoteLootBagManager in shape (two maps + scene-swap rehydrate) but renders a
# body + "<name>'s corpse" nameplate from CorpseSpawn instead of a loot sack.
#
# Corpse ids share the loot-bag id partition, so EntityDespawn is shared between
# this and RemoteLootBagManager — each frees only the ids it actually spawned
# (we guard on `_spawn_data.has(id)`). Looting is Slice 2.

const CORPSE_SCENE := preload("res://scripts/corpse.gd")

var _spawn_data: Dictionary = {}   # corpse_id -> {pos, owner_id, owner_name}
var _by_id: Dictionary = {}        # corpse_id -> Corpse node
var _last_scene: Node = null
var _needs_rehydrate: bool = false

func _ready() -> void:
	Net.world_corpse_spawn.connect(_on_corpse_spawn)
	Net.world_entity_despawn.connect(_on_entity_despawn)

func _process(_delta: float) -> void:
	# Re-instantiate corpses after a scene swap (zone change), once the local
	# player exists in the new scene — same rehydrate dance as the loot bags.
	var scene: Node = get_tree().current_scene
	if scene != _last_scene:
		for c in _by_id.values():
			if is_instance_valid(c):
				c.queue_free()
		_last_scene = scene
		_by_id.clear()
		_needs_rehydrate = true
	if not _needs_rehydrate or scene == null:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	for id in _spawn_data:
		if not _by_id.has(id):
			_instantiate_into(id, scene)
	_needs_rehydrate = false

func _on_corpse_spawn(corpse_id: int, owner_id: int, owner_name: String, pos: Vector3) -> void:
	var first_sighting := not _spawn_data.has(corpse_id)
	_spawn_data[corpse_id] = {"pos": pos, "owner_id": owner_id, "owner_name": owner_name}
	# Tell the owner where their body is, the first time we learn of it.
	if first_sighting and owner_id == Net.get_player_id():
		CombatLog.add_line("Your corpse rests where you fell.", CombatLog.MsgType.INFO)
	var scene: Node = get_tree().current_scene
	if scene == null or get_tree().get_first_node_in_group("player") == null:
		return
	if _by_id.has(corpse_id):
		return
	_instantiate_into(corpse_id, scene)

func _on_entity_despawn(id: int) -> void:
	# Shared partition with loot bags — only handle ids we actually own.
	if not _spawn_data.has(id):
		return
	_spawn_data.erase(id)
	var c = _by_id.get(id)
	if c != null:
		if is_instance_valid(c):
			c.queue_free()
		_by_id.erase(id)

func _instantiate_into(corpse_id: int, scene: Node) -> void:
	var data: Dictionary = _spawn_data[corpse_id]
	var corpse = CORPSE_SCENE.new()
	corpse.corpse_id = corpse_id
	corpse.owner_id = data["owner_id"]
	corpse.owner_name = data["owner_name"]
	scene.add_child(corpse)
	corpse.global_position = data["pos"]
	_by_id[corpse_id] = corpse

func clear_all() -> void:
	for id in _by_id:
		var c = _by_id[id]
		if is_instance_valid(c):
			c.queue_free()
	_by_id.clear()
	_spawn_data.clear()
