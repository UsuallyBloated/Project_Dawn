extends Node

var _ui_layer: CanvasLayer

func _ready() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 5
	add_child(_ui_layer)

func register_enemy(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
	var table: LootTable = enemy.loot_table
	if table == null or table.entries.is_empty():
		return
	var items := _roll(table)
	if items.is_empty():
		return
	var bag := LootBag.new()
	bag.items = items
	get_tree().current_scene.add_child(bag)
	bag.global_position = enemy.global_position + Vector3(0.0, 0.3, 0.0)

func _roll(table: LootTable) -> Array:
	var result: Array = []
	for _i in table.rolls:
		var pool: Array = []
		for e in table.entries:
			if e.item != null:
				pool.append(e)
		if pool.is_empty():
			continue
		var total: float = table.empty_weight
		for e in pool:
			total += e.weight
		var r := randf() * total
		if r < table.empty_weight:
			continue
		r -= table.empty_weight
		for e in pool:
			if r < e.weight:
				result.append({"item": e.item, "count": randi_range(e.min_count, e.max_count)})
				break
			r -= e.weight
	return result

func show_window(bag: LootBag) -> void:
	for child in _ui_layer.get_children():
		if child is LootWindow and child.bag == bag:
			child.visible = true
			return
	var window := LootWindow.new(bag)
	_ui_layer.add_child(window)
