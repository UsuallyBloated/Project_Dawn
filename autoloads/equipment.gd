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
# paperdoll reflects authoritative state. Mirrors the local `equip`
# path's stat application (the item registry is online now): the six
# primary stats have no server->client sync, so the client must apply
# gear bonuses itself for the character sheet to reflect them; max
# HP/MP/Stamina still get corrected absolutely by the server's resource
# fan (remote_player_manager `_on_health_update`). Remove any item
# already in this slot first (defensive — the server normally sends the
# unequip delta first, but this keeps the invariant if it doesn't).
func apply_remote_equip(equip_slot_idx: int, item: ItemData) -> void:
	if equip_slot_idx < 0 or equip_slot_idx >= SLOTS.size():
		return
	var slot_name: String = SLOTS[equip_slot_idx]
	var old = equipped[slot_name]
	if old != null:
		_remove_stat_bonuses(old)
	equipped[slot_name] = item
	_apply_stat_bonuses(item)
	equipment_changed.emit(slot_name, item)

func apply_remote_unequip(equip_slot_idx: int) -> void:
	if equip_slot_idx < 0 or equip_slot_idx >= SLOTS.size():
		return
	var slot_name: String = SLOTS[equip_slot_idx]
	var old = equipped[slot_name]
	if old != null:
		_remove_stat_bonuses(old)
	equipped[slot_name] = null
	equipment_changed.emit(slot_name, null)

# Track 13.3 — wipe all paperdoll slots before applying a fresh
# server snapshot. Avoids stale items lingering across reconnects, and
# strips their stat bonuses too (this is also the death path: the server
# fans an emptied snapshot to drive the naked respawn, so the stripped
# gear's stats must come off). On a relog this stays balanced because
# `PlayerStats.apply_character` re-layers the worn gear onto the freshly
# reset base right before this runs.
func apply_remote_snapshot_clear() -> void:
	for s in SLOTS:
		if equipped[s] != null:
			_remove_stat_bonuses(equipped[s])
			equipped[s] = null
			equipment_changed.emit(s, null)

# Dual wield is earned at a class's level (Combat.can_dual_wield, the server's
# rule): it decides where a second one-hander lands and whether an off-hand
# weapon goes on at all.
func can_dual_wield() -> bool:
	return Combat.can_dual_wield()

# Why this class may not wear `item` in `slot_name`, or "" when it may: the
# server's rule (`skills::equip_refusal`), asked here first so an honest
# player gets the line without a round trip. EQ's rule, since 2026-10-27: a
# weapon of a type the class never trains, armor of a kind it never trains,
# and a weapon in the off hand before the class can dual wield are refused at
# the equip, not worn badly. The two-hander rule, since 2026-10-29: a
# two-hander goes in the main hand only, and only while the off hand is
# empty; nothing goes in the off hand while the main hand holds one (the
# user's call: a two-hander beside an off-hand weapon is an end-game Warrior
# ability, and nobody has it until that ability exists).
func equip_refusal(item: ItemData, slot_name: String) -> String:
	if item == null:
		return ""
	if item.type == ItemData.Type.WEAPON:
		if not WeaponSkills.class_trains(WeaponSkills.skill_key_for(item)):
			return "Your class cannot wield that."
		if slot_name == "offhand":
			if item.is_two_handed:
				return "A two-handed weapon goes in the main hand."
			if not can_dual_wield():
				var at: int = WeaponSkillDefinitions.DUAL_WIELD_LEVELS.get(PlayerStats.player_class, 0)
				if at > 0:
					return "You will be able to dual wield at level %d." % at
				return "Your class cannot dual wield."
			var main_wpn: ItemData = equipped.get("weapon")
			if main_wpn != null and main_wpn.is_two_handed:
				return "You cannot hold that with a two-handed weapon."
		elif slot_name == "weapon" and item.is_two_handed and equipped.get("offhand") != null:
			return "Empty your off hand first."
		return ""
	if item.armor_type != "" and ArmorSkills.get_cap(item.armor_type) <= 0:
		return "Your class cannot wear that."
	return ""

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
# that location. Returns false if the equip is blocked (no valid slot, or
# a refusal from `equip_refusal`, printed as its line).
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
	var refusal := equip_refusal(item, slot_name)
	if refusal != "":
		CombatLog.add_line(refusal, CombatLog.MsgType.INFO)
		return false

	if Net.is_launcher_mode():
		# A two-hander with a full off hand was refused above ("Empty your
		# off hand first."), as the server refuses it: EQ's way, never an
		# unequip sent on the player's behalf. (Until 2026-10-29 this path
		# unequipped the off hand itself, keyed on a flag both staves lacked.)
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

# PD_W0027 slice 1.5 — lift a worn item straight onto the cursor (EQ's
# click-the-doll-with-an-empty-hand). The server refuses if the hand is full.
func request_unequip_to_cursor(slot_name: String) -> bool:
	if equipped.get(slot_name) == null or not Net.is_launcher_mode():
		return false
	var equip_slot_idx: int = SLOTS.find(slot_name)
	if equip_slot_idx < 0:
		return false
	Net.broadcast_unequip_item(equip_slot_idx, NetProtocol.INV_LOCATION_CURSOR, 0)
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
