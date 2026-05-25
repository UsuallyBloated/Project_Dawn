extends Node

# RemoteLootBagManager — visual + interaction replication for every
# server-owned loot bag in the current zone. Mirrors RemoteEnemyManager
# in shape (two maps + scene-swap rehydrate) but routes by the
# LOOT_BAG_ID_BASE partition (>= 2_000_000_000) instead of the enemy
# partition.
#
# Listens to:
#   • Net.world_loot_bag_spawn — initial spawn + every server-side
#     resnapshot after a successful LootItem / LootAll.
#   • Net.world_entity_despawn — empty bag or expired linger.
#   • Net.world_loot_granted — private confirmation that the local
#     player's pickup landed; add to local inventory.
#
# LootBagSpawn carries `(item_path, count)` pairs. We map paths to
# the local ItemData catalog with load(); the LootBag node only
# stores the ItemData refs going forward.

const LOOT_BAG_SCENE := preload("res://scripts/loot_bag.gd")
# Mirror of protocol::world::LOOT_BAG_ID_BASE. Authoritative source
# is the Rust crate; manual mirror like ENEMY_ID_BASE in
# RemoteEnemyManager.
const LOOT_BAG_ID_BASE: int = 2_000_000_000

var _spawn_data: Dictionary = {}   # bag_id -> {pos, items: Array[{item, count}]}
var _by_id: Dictionary = {}        # bag_id -> LootBag node
var _last_scene: Node = null
var _needs_rehydrate: bool = false

func _ready() -> void:
	Net.world_loot_bag_spawn.connect(_on_loot_bag_spawn)
	Net.world_entity_despawn.connect(_on_entity_despawn)
	Net.world_loot_granted.connect(_on_loot_granted)

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _last_scene:
		for bag in _by_id.values():
			if is_instance_valid(bag):
				bag.queue_free()
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

func _on_loot_bag_spawn(
		bag_id: int,
		pos: Vector3,
		item_paths: PackedStringArray,
		item_counts: PackedInt32Array) -> void:
	var items := _materialize_items(item_paths, item_counts)
	_spawn_data[bag_id] = {"pos": pos, "items": items}
	var scene: Node = get_tree().current_scene
	if scene == null or not _scene_hosts_local_player(scene):
		return
	var existing = _by_id.get(bag_id)
	if existing != null and is_instance_valid(existing):
		# Re-snapshot for an existing bag: assignment + signal lets the
		# open LootWindow (if any) refresh without us touching it.
		existing.items = items
		existing.items_changed.emit()
		return
	_instantiate_into(bag_id, scene)

func _on_entity_despawn(id: int) -> void:
	if id < LOOT_BAG_ID_BASE:
		return
	_spawn_data.erase(id)
	var bag = _by_id.get(id)
	if bag != null:
		if is_instance_valid(bag):
			bag.queue_free()
		_by_id.erase(id)

func _on_loot_granted(item_path: String, count: int) -> void:
	var item := load(item_path) as ItemData
	if item == null:
		push_warning("RemoteLootBagManager: LootGranted with unknown path '%s'" % item_path)
		return
	# Track 13.2 — in launcher mode the server's InventoryDelta does
	# the slot mutation; we just log the pickup line. Solo / Test
	# Room mode (Inventory autoload not server-driven) keeps the
	# legacy local add_item path.
	if Net.is_launcher_mode():
		CombatLog.add_line("You loot: %s." % item.item_name, CombatLog.MsgType.LOOT)
		return
	if Inventory.add_item(item, count):
		CombatLog.add_line("You loot: %s." % item.item_name, CombatLog.MsgType.LOOT)
	else:
		# Inventory full. The item is already gone server-side; sub-task
		# 4 doesn't model "give it back" — note the loss in the log.
		CombatLog.add_line(
			"You receive %s but your inventory is full." % item.item_name,
			CombatLog.MsgType.INFO,
		)

func _instantiate_into(bag_id: int, scene: Node) -> void:
	var data: Dictionary = _spawn_data[bag_id]
	var bag = LOOT_BAG_SCENE.new()
	bag.bag_id = bag_id
	bag.items = data["items"]
	scene.add_child(bag)
	bag.global_position = data["pos"]
	_by_id[bag_id] = bag

func _materialize_items(paths: PackedStringArray, counts: PackedInt32Array) -> Array:
	var out: Array = []
	var n := mini(paths.size(), counts.size())
	for i in n:
		var item := load(paths[i]) as ItemData
		if item == null:
			push_warning("RemoteLootBagManager: unknown loot path '%s'" % paths[i])
			continue
		out.append({"item": item, "count": int(counts[i])})
	return out

func _scene_hosts_local_player(_scene: Node) -> bool:
	return get_tree().get_first_node_in_group("player") != null

func clear_all() -> void:
	for id in _by_id:
		var bag = _by_id[id]
		if is_instance_valid(bag):
			bag.queue_free()
	_by_id.clear()
	_spawn_data.clear()
