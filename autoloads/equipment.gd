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

# Track 15.1 — server-authoritative equip flow. The launcher-mode call
# site picks the paperdoll slot client-side (dual-wield + 2H rules live
# here) then ships EquipItem on the wire. Server-fanned InventoryDelta
# + apply_remote_equip update local state.
#
# `src_location` is "base" or "bag_<N>"; `src_slot` is the index inside
# that location. Returns false if the equip is blocked (no valid slot,
# 2H swap with full inventory, etc.).
func request_equip_from(src_location: String, src_slot: int, item: ItemData, target_slot_hint: String = "") -> bool:
	# `target_slot_hint` lets the caller force a specific paperdoll
	# slot — e.g. the paperdoll left-click "drop here" path. Empty
	# string keeps the auto-pick behaviour used by right-click equip.
	# An invalid hint (wrong item type for the slot) falls through to
	# auto-pick so the caller doesn't have to pre-validate.
	var slot_name := ""
	if target_slot_hint != "" and _is_valid_target_slot(item, target_slot_hint):
		slot_name = target_slot_hint
	else:
		slot_name = _pick_slot(item)
	if slot_name == "":
		# Offhand-while-2H is the only path that lands here; surface the
		# reason so the player isn't left guessing.
		if item.type == ItemData.Type.OFFHAND:
			CombatLog.add_line("Can't equip an offhand while wielding a two-handed weapon.", CombatLog.MsgType.INFO)
		return false
	var equip_slot_idx: int = SLOTS.find(slot_name)
	if equip_slot_idx < 0:
		return false

	if Net.is_launcher_mode():
		# 2H weapon while offhand is occupied → unequip offhand to a free
		# base slot first, then equip the 2H. Server processes the two
		# intents in send order (renet reliable channel).
		if item.type == ItemData.Type.WEAPON and item.is_two_handed \
				and equipped.get("offhand") != null:
			var dst := _first_free_base_slot()
			if dst < 0:
				CombatLog.add_line("Inventory full — free a slot to swap weapons.", CombatLog.MsgType.INFO)
				return false
			var oh_equip_idx: int = SLOTS.find("offhand")
			Net.broadcast_unequip_item(oh_equip_idx, NetProtocol.INV_LOCATION_BASE, dst)
		Net.broadcast_equip_item(src_location, src_slot, equip_slot_idx)
		return true

	# Solo / Test Room — preserve the optimistic local mutation path.
	_local_remove_from_source(src_location, src_slot)
	equip(item)
	return true

func unequip(slot: String) -> ItemData:
	var item = equipped.get(slot)
	if item == null:
		return null
	_remove_stat_bonuses(item)
	equipped[slot] = null
	equipment_changed.emit(slot, null)
	Inventory.add_item(item)
	return item

# Track 15.1 — server-authoritative unequip. The server's
# unequip_to_base requires a concrete dst; client picks the first
# empty base slot. If inventory is full the unequip rejects with a
# combat log line.
func request_unequip(slot_name: String) -> bool:
	if equipped.get(slot_name) == null:
		return false
	if Net.is_launcher_mode():
		var dst := _first_free_base_slot()
		if dst < 0:
			CombatLog.add_line("Inventory full — no room to unequip.", CombatLog.MsgType.INFO)
			return false
		var equip_slot_idx: int = SLOTS.find(slot_name)
		if equip_slot_idx < 0:
			return false
		Net.broadcast_unequip_item(equip_slot_idx, NetProtocol.INV_LOCATION_BASE, dst)
		return true
	unequip(slot_name)
	return true

func _resolve_slot(item: ItemData) -> String:
	var slot := _pick_slot(item)
	# Legacy path: the caller already removed the item from inventory,
	# so a blocked offhand-while-2H push gets re-added here so it isn't
	# lost. Launcher path uses _pick_slot directly to avoid the side
	# effect (the item never left inventory there).
	if slot == "" and item.type == ItemData.Type.OFFHAND:
		Inventory.add_item(item)
	return slot

# Pure paperdoll-slot picker — no side effects. Encodes the dual-wield
# + 2H rules used by both the legacy `equip` path and the new
# request_equip_from launcher path.
func _pick_slot(item: ItemData) -> String:
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
			return ""
		return "offhand"
	return _slot_for_type(item.type)

# True if `item` is eligible to land in the named paperdoll slot via
# the equip pipeline. Mirrors the wider item-type rules so a user
# clicking "Chest" with a sword in hand gets the auto-pick path
# instead of a silent rejection.
func _is_valid_target_slot(item: ItemData, slot_name: String) -> bool:
	match slot_name:
		"weapon":
			return item.type == ItemData.Type.WEAPON
		"offhand":
			# Weapons may dual-wield; OFFHAND items (shield, focus)
			# obviously fit. _pick_slot enforces the 2H-in-main-hand
			# guard separately.
			return item.type == ItemData.Type.OFFHAND or item.type == ItemData.Type.WEAPON
		"head":  return item.type == ItemData.Type.HEAD
		"chest": return item.type == ItemData.Type.CHEST
		"legs":  return item.type == ItemData.Type.LEGS
		"feet":  return item.type == ItemData.Type.FEET
		"hands": return item.type == ItemData.Type.HANDS
		"ring":  return item.type == ItemData.Type.RING
		"neck":  return item.type == ItemData.Type.NECK
	return false

func _first_free_base_slot() -> int:
	for i in Inventory.BASE_SLOT_COUNT:
		if Inventory.base_slots[i] == null:
			return i
	return -1

func _local_remove_from_source(src_location: String, src_slot: int) -> void:
	if src_location == NetProtocol.INV_LOCATION_BASE:
		Inventory.remove_base_at(src_slot)
		return
	if src_location.begins_with("bag_"):
		var bag_idx := int(src_location.substr(4))
		Inventory.remove_at(bag_idx, src_slot)

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
