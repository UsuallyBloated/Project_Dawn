extends Node

signal inventory_changed
signal item_added(item: ItemData)
signal item_removed(item: ItemData)

const MAX_SLOTS := 40

# Each slot: null or { "item": ItemData, "count": int }
var slots: Array = []

func _ready() -> void:
	slots.resize(MAX_SLOTS)
	slots.fill(null)

func add_item(item: ItemData, count: int = 1) -> bool:
	if item.stack_size > 1:
		for i in MAX_SLOTS:
			if slots[i] != null and slots[i]["item"] == item:
				var space: int = item.stack_size - (slots[i]["count"] as int)
				if space > 0:
					var add := mini(count, space)
					slots[i]["count"] += add
					count -= add
					inventory_changed.emit()
					if count == 0:
						item_added.emit(item)
						return true

	while count > 0:
		var free_slot := _first_free_slot()
		if free_slot == -1:
			return false
		var batch := mini(count, item.stack_size)
		slots[free_slot] = {"item": item, "count": batch}
		count -= batch

	inventory_changed.emit()
	item_added.emit(item)
	return true

func remove_item(item: ItemData, count: int = 1) -> bool:
	var remaining := count
	for i in MAX_SLOTS:
		if remaining == 0:
			break
		if slots[i] != null and slots[i]["item"] == item:
			var take := mini(remaining, slots[i]["count"])
			slots[i]["count"] -= take
			remaining -= take
			if slots[i]["count"] == 0:
				slots[i] = null
	if remaining < count:
		inventory_changed.emit()
		item_removed.emit(item)
		return true
	return false

func remove_at(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
	if slots[slot_index] == null:
		return
	var item: ItemData = slots[slot_index]["item"]
	slots[slot_index] = null
	inventory_changed.emit()
	item_removed.emit(item)

func _first_free_slot() -> int:
	for i in MAX_SLOTS:
		if slots[i] == null:
			return i
	return -1
