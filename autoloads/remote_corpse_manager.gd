extends Node

# RemoteCorpseManager — visual + loot replication for every server-owned player
# corpse in the current zone (corpse / resurrection epic). Mirrors
# RemoteLootBagManager in shape (two maps + scene-swap rehydrate): renders a body
# + "<name>'s corpse" nameplate from CorpseSpawn (all peers), and for the OWNER
# fills the corpse's item/coin list from the private CorpseContents (Slice 2) so
# clicking it opens the shared loot window.
#
# Corpse ids share the loot-bag id partition, so EntityDespawn is shared between
# this and RemoteLootBagManager — each frees only the ids it actually spawned
# (we guard on `_spawn_data.has(id)`).

const CORPSE_SCENE := preload("res://scripts/corpse.gd")

# corpse_id -> {pos, owner_id, owner_name, items: Array, coins: Dictionary}
var _spawn_data: Dictionary = {}
var _by_id: Dictionary = {}        # corpse_id -> Corpse node
var _last_scene: Node = null
var _needs_rehydrate: bool = false

func _ready() -> void:
	Net.world_corpse_spawn.connect(_on_corpse_spawn)
	Net.world_corpse_contents.connect(_on_corpse_contents)
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
	# Preserve any items/coins already learned (CorpseContents can't arrive before
	# CorpseSpawn on the reliable-ordered channel, but be safe on a re-spawn).
	var entry: Dictionary = _spawn_data.get(corpse_id, {})
	entry["pos"] = pos
	entry["owner_id"] = owner_id
	entry["owner_name"] = owner_name
	if not entry.has("items"):
		entry["items"] = []
	if not entry.has("coins"):
		entry["coins"] = {"platinum": 0, "gold": 0, "silver": 0, "copper": 0}
	_spawn_data[corpse_id] = entry
	# Tell the owner where their body is, the first time we learn of it.
	if first_sighting and owner_id == Net.get_player_id():
		CombatLog.add_line("Your corpse rests where you fell.", CombatLog.MsgType.INFO)
	var scene: Node = get_tree().current_scene
	if scene == null or get_tree().get_first_node_in_group("player") == null:
		return
	if _by_id.has(corpse_id):
		return
	_instantiate_into(corpse_id, scene)

# Slice 2 — owner-only corpse contents. Fills the loot list + coins; if the body
# is already spawned, push them onto the node and emit items_changed so an open
# loot window refreshes (also covers the re-snapshot after each partial loot).
func _on_corpse_contents(
		corpse_id: int,
		item_paths: PackedStringArray,
		item_counts: PackedInt32Array,
		coin_platinum: int,
		coin_gold: int,
		coin_silver: int,
		coin_copper: int) -> void:
	var items := _materialize_items(item_paths, item_counts)
	var coins := {"platinum": coin_platinum, "gold": coin_gold, "silver": coin_silver, "copper": coin_copper}
	var entry: Dictionary = _spawn_data.get(corpse_id, {})
	entry["items"] = items
	entry["coins"] = coins
	_spawn_data[corpse_id] = entry
	var c = _by_id.get(corpse_id)
	if c != null and is_instance_valid(c):
		_apply_contents(c, items, coins)
		c.items_changed.emit()

func _apply_contents(corpse, items: Array, coins: Dictionary) -> void:
	corpse.items = items
	corpse.coin_platinum = coins.get("platinum", 0)
	corpse.coin_gold = coins.get("gold", 0)
	corpse.coin_silver = coins.get("silver", 0)
	corpse.coin_copper = coins.get("copper", 0)

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
	_apply_contents(corpse, data.get("items", []), data.get("coins", {}))
	scene.add_child(corpse)
	corpse.global_position = data["pos"]
	_by_id[corpse_id] = corpse

func _materialize_items(paths: PackedStringArray, counts: PackedInt32Array) -> Array:
	var out: Array = []
	var n := mini(paths.size(), counts.size())
	for i in n:
		var item := load(paths[i]) as ItemData
		if item == null:
			push_warning("RemoteCorpseManager: unknown corpse item path '%s'" % paths[i])
			continue
		out.append({"item": item, "count": int(counts[i])})
	return out

func clear_all() -> void:
	for id in _by_id:
		var c = _by_id[id]
		if is_instance_valid(c):
			c.queue_free()
	_by_id.clear()
	_spawn_data.clear()
