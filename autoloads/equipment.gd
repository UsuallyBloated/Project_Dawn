extends Node

signal equipment_changed(slot: String, item)

# Slot names match ItemData.Type enum labels for weapons/armor
const SLOTS := ["weapon", "offhand", "head", "chest", "legs", "feet", "hands", "ring", "neck"]

# slot_name -> ItemData or null
var equipped: Dictionary = {}

func _ready() -> void:
	for s in SLOTS:
		equipped[s] = null

# Track 13.3 — server-driven apply path. The InventoryDelta /
# InventorySnapshot for `equip` location routes here so the local
# paperdoll reflects authoritative state. Skips stat recompute
# (the server-side item registry isn't online yet — Track 13.3+).
func apply_remote_equip(equip_slot_idx: int, item: ItemData) -> void:
	if equip_slot_idx < 0 or equip_slot_idx >= SLOTS.size():
		return
	var slot_name: String = SLOTS[equip_slot_idx]
	equipped[slot_name] = item
	equipment_changed.emit(slot_name, item)

func apply_remote_unequip(equip_slot_idx: int) -> void:
	if equip_slot_idx < 0 or equip_slot_idx >= SLOTS.size():
		return
	var slot_name: String = SLOTS[equip_slot_idx]
	equipped[slot_name] = null
	equipment_changed.emit(slot_name, null)

# Track 13.3 — wipe all paperdoll slots before applying a fresh
# server snapshot. Avoids stale items lingering across reconnects.
func apply_remote_snapshot_clear() -> void:
	for s in SLOTS:
		if equipped[s] != null:
			equipped[s] = null
			equipment_changed.emit(s, null)

func can_dual_wield() -> bool:
	return WeaponSkills.get_current("dual_wield") > 0

func equip(item: ItemData) -> void:
	var slot := _resolve_slot(item)
	if slot == "":
		return
	# Equipping a 2H weapon clears any offhand weapon (shields/weapons)
	if item.type == ItemData.Type.WEAPON and item.is_two_handed:
		var oh = equipped.get("offhand")
		if oh != null:
			_remove_stat_bonuses(oh)
			equipped["offhand"] = null
			equipment_changed.emit("offhand", null)
			Inventory.add_item(oh)
	var old = equipped[slot]
	if old != null:
		_remove_stat_bonuses(old)
		# When replacing main hand while offhand holds a weapon, push offhand back too
		if slot == "weapon" and item.is_two_handed:
			pass  # already cleared above
	equipped[slot] = item
	_apply_stat_bonuses(item)
	equipment_changed.emit(slot, item)

func _resolve_slot(item: ItemData) -> String:
	if item.type == ItemData.Type.WEAPON:
		var main_wpn: ItemData = equipped.get("weapon")
		# Main hand is empty → go there
		if main_wpn == null:
			return "weapon"
		# This is a 2H weapon → always replace main hand
		if item.is_two_handed:
			return "weapon"
		# Main hand holds a 2H weapon → replace it
		if main_wpn.is_two_handed:
			return "weapon"
		# Main hand is a 1H weapon; try offhand if dual wield is trained
		if can_dual_wield() and equipped.get("offhand") == null:
			return "offhand"
		# Replace main hand
		return "weapon"
	# OFFHAND (shield, focus, etc.) — block if main is 2H
	if item.type == ItemData.Type.OFFHAND:
		var main_wpn: ItemData = equipped.get("weapon")
		if main_wpn != null and main_wpn.is_two_handed:
			Inventory.add_item(item)
			return ""
		return "offhand"
	return _slot_for_type(item.type)

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

func get_armor_class() -> int:
	@warning_ignore("integer_division")
	var agi_bonus: int = PlayerStats.agility / 4
	return agi_bonus + ArmorSkills.get_effective_armor(equipped)

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

# ── Save / load (Tier 2) ──────────────────────────────────────────────────────

func save_state() -> Dictionary:
	var slots_out: Dictionary = {}
	for s in SLOTS:
		var item: ItemData = equipped.get(s)
		if item != null:
			slots_out[s] = item.to_save_dict()
	return {"slots": slots_out}

func load_state(d: Dictionary) -> void:
	# Clear current equipment + remove any lingering bonuses (defensive — load
	# normally runs from a clean state, but Equipment may have items from the
	# default character path).
	for s in SLOTS:
		var existing: ItemData = equipped.get(s)
		if existing != null:
			_remove_stat_bonuses(existing)
			equipped[s] = null
			equipment_changed.emit(s, null)
	var slots_in: Dictionary = d.get("slots", {})
	for s in SLOTS:
		if not slots_in.has(s):
			continue
		var item: ItemData = ItemData.from_save_dict(slots_in[s])
		if item == null:
			continue
		equipped[s] = item
		_apply_stat_bonuses(item)
		equipment_changed.emit(s, item)
