@tool
extends EditorScript

# Track 14.1 — auto-exports every `.tres` ItemData under
# `data/loot/items/` to a server-consumable TOML the
# `projectdawn-server` crate ingests via `include_str!`.
#
# Companion to `tools/export_spells.gd`. The bootstrap one-shot was
# `tools/export_items_oneshot.py`; this script is the canonical
# regen tool — re-run after touching any item `.tres` field that
# the server cares about (item type, stack size, equip slot, stat
# affixes, bag capacity, weapon damage, etc.).
#
# How to run:
#   1. Open this script in the Godot editor (File → Open).
#   2. File → Run (Ctrl+Shift+X).
#   3. Check the output panel for the "Wrote N items to..." line.
#   4. Commit the regenerated TOML alongside the .tres changes.
#
# Output path: writes to the absolute filesystem path so the
# server repo gets the fresh data without needing both repos open
# in Godot. Adjust OUTPUT_PATH if your server lives elsewhere.

const OUTPUT_PATH := "F:/Projects/server/crates/projectdawn-server/data/items.toml"
const ITEMS_DIR := "res://data/loot/items"

# Mirrors `ItemData.Type` order. Index = numeric `type` field on the
# resource; value = snake_case discriminant the Rust `ItemType` enum
# expects (matches #[serde(rename_all = "snake_case")]).
const TYPE_NAMES := [
	"weapon", "offhand", "head", "chest", "legs", "feet", "hands",
	"ring", "neck", "consumable", "misc", "augment", "bag",
]

# Map of (item field on ItemData → TOML key). Anything not in here
# is dropped — descriptions, icons, augment slot contents, etc. stay
# client-side.
const FIELD_MAP := {
	"item_name":           "name",
	"stack_size":          "stack_size",
	"rarity":              "rarity",
	# Stat affixes
	"bonus_strength":      "str_bonus",
	"bonus_dexterity":     "dex_bonus",
	"bonus_agility":       "agi_bonus",
	"bonus_intelligence":  "int_bonus",
	"bonus_wisdom":        "wis_bonus",
	"bonus_charisma":      "cha_bonus",
	"bonus_constitution":  "con_bonus",
	"bonus_max_hp":        "max_hp_bonus",
	"bonus_max_mp":        "max_mp_bonus",
	"bonus_max_stamina":   "max_stamina_bonus",
	# Weapon
	"weapon_damage_min":   "damage_min",
	"weapon_damage_max":   "damage_max",
	"weapon_delay":        "weapon_delay",
	"weapon_skill":        "skill",
	"is_two_handed":       "is_two_handed",
	"is_ranged":           "is_ranged",
	# Armor
	"bonus_armor":         "armor",
	"armor_type":          "armor_type",
	# Bag
	"bag_num_slots":       "bag_num_slots",
	# Consumable
	"heal_on_use":         "heal_on_use",
	"mp_on_use":           "mp_on_use",
	"is_food":             "is_food",
	"is_drink":            "is_drink",
	"food_hp_regen":       "food_hp_regen",
	"food_mp_regen":       "food_mp_regen",
	"food_duration":       "food_duration",
	# Proc weapons
	"proc_chance":         "proc_chance",
	"proc_damage":         "proc_damage",
	"proc_damage_type":    "proc_damage_type",
	"proc_name":           "proc_name",
	# Augmentation
	"gem_slots":           "gem_slots",
	# Vendor
	"vendor_price":        "vendor_price",
}

# Emit order — keeps the TOML stable across runs. Path, name,
# item_type, stack_size are always emitted; the rest only if
# nonzero / non-empty.
const EMIT_ORDER := [
	"path", "name", "item_type", "rarity", "stack_size",
	"damage_min", "damage_max", "weapon_delay", "skill",
	"is_two_handed", "is_ranged",
	"armor", "armor_type",
	"str_bonus", "dex_bonus", "agi_bonus", "int_bonus", "wis_bonus",
	"cha_bonus", "con_bonus",
	"max_hp_bonus", "max_mp_bonus", "max_stamina_bonus",
	"bag_num_slots",
	"heal_on_use", "mp_on_use",
	"is_food", "is_drink", "food_hp_regen", "food_mp_regen", "food_duration",
	"proc_chance", "proc_damage", "proc_damage_type", "proc_name",
	"gem_slots",
	"vendor_price",
]

const ALWAYS_EMIT := ["path", "name", "item_type", "stack_size"]


func _run() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("export_items: cannot open %s" % ITEMS_DIR)
		return

	var paths: PackedStringArray = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			paths.append(ITEMS_DIR + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	paths.sort()

	var lines: PackedStringArray = []
	lines.append("# AUTO-GENERATED — do not edit by hand.")
	lines.append("# Source: Project_Dawn/data/loot/items/*.tres")
	lines.append("# Canonical regen tool: Project_Dawn/tools/export_items.gd")
	lines.append("# (open in Godot editor, File → Run).")
	lines.append("")

	var written := 0
	for path in paths:
		var item: ItemData = load(path) as ItemData
		if item == null:
			push_warning("export_items: %s did not load as ItemData" % path)
			continue
		var type_idx: int = int(item.type)
		if type_idx < 0 or type_idx >= TYPE_NAMES.size():
			push_warning("export_items: %s has invalid type %d" % [path, type_idx])
			continue
		var entry: Dictionary = {
			"path": path,
			"name": item.item_name,
			"item_type": TYPE_NAMES[type_idx],
		}
		for src_key in FIELD_MAP:
			var dst_key: String = FIELD_MAP[src_key]
			if not src_key in item:
				continue
			entry[dst_key] = item.get(src_key)

		lines.append("[[item]]")
		for key in EMIT_ORDER:
			if not entry.has(key):
				continue
			var v: Variant = entry[key]
			if not (key in ALWAYS_EMIT) and _is_default(v):
				continue
			lines.append("%s = %s" % [key, _toml_value(v)])
		lines.append("")
		written += 1

	var f := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("export_items: could not open %s for writing (err %d)"
			% [OUTPUT_PATH, FileAccess.get_open_error()])
		return
	for line in lines:
		f.store_line(line)
	f.close()
	print("export_items: wrote %d items to %s" % [written, OUTPUT_PATH])


# Default detection — keeps the TOML lean by omitting fields whose
# values match the script's defaults. Stat affix ints default to 0;
# bonuses default to 0.0; flags default to false; strings default
# to "".
func _is_default(v: Variant) -> bool:
	match typeof(v):
		TYPE_INT:    return int(v) == 0
		TYPE_FLOAT:  return float(v) == 0.0
		TYPE_BOOL:   return not bool(v)
		TYPE_STRING: return String(v).is_empty()
	return false


func _toml_value(v: Variant) -> String:
	match typeof(v):
		TYPE_STRING:
			return "\"" + (v as String).replace("\\", "\\\\").replace("\"", "\\\"") + "\""
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var s := str(v)
			if not "." in s and not "e" in s.to_lower():
				s += ".0"
			return s
		TYPE_BOOL:
			return "true" if v else "false"
	push_error("export_items: unsupported TOML type %s for value %s" % [typeof(v), v])
	return "null"
