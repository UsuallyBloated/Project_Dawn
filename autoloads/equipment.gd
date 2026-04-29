extends Node

signal equipment_changed(slot: String, item)

# Slot names match ItemData.Type enum labels for weapons/armor
const SLOTS := ["weapon", "offhand", "head", "chest", "legs", "feet", "hands", "ring", "neck"]

# slot_name -> ItemData or null
var equipped: Dictionary = {}

func _ready() -> void:
	for s in SLOTS:
		equipped[s] = null

func equip(item: ItemData) -> void:
	var slot := _slot_for_type(item.type)
	if slot == "":
		return
	var old = equipped[slot]
	if old != null:
		_remove_stat_bonuses(old)
	equipped[slot] = item
	_apply_stat_bonuses(item)
	equipment_changed.emit(slot, item)

func unequip(slot: String) -> ItemData:
	var item = equipped.get(slot)
	if item == null:
		return null
	_remove_stat_bonuses(item)
	equipped[slot] = null
	equipment_changed.emit(slot, null)
	Inventory.add_item(item)
	return item

func _apply_stat_bonuses(item: ItemData) -> void:
	PlayerStats.apply_item_bonuses(item)

func _remove_stat_bonuses(item: ItemData) -> void:
	PlayerStats.remove_item_bonuses(item)

func get_total_armor() -> int:
	var total := 0
	for slot in equipped:
		var item = equipped[slot]
		if item != null:
			total += item.bonus_armor
	return total

func get_armor_class() -> int:
	return (PlayerStats.agility / 4) + get_total_armor()

func _slot_for_type(type: ItemData.Type) -> String:
	match type:
		ItemData.Type.WEAPON:   return "weapon"
		ItemData.Type.OFFHAND:  return "offhand"
		ItemData.Type.HEAD:     return "head"
		ItemData.Type.CHEST:    return "chest"
		ItemData.Type.LEGS:     return "legs"
		ItemData.Type.FEET:     return "feet"
		ItemData.Type.HANDS:    return "hands"
		ItemData.Type.RING:     return "ring"
		ItemData.Type.NECK:     return "neck"
	return ""
