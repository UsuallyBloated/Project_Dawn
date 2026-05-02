class_name MobLootTables

# Named loot tables for common mob archetypes.
# Each entry: { path, weight, min, max }
# Partial mob_name matching is supported ("Infected Wolf" → "Wolf").

const TABLES: Dictionary = {
	"Wolf": {
		"rolls": 1, "empty_weight": 0.5,
		"entries": [
			{path = "res://data/loot/items/wolf_meat.tres",          weight = 3.0, min = 1, max = 2},
			{path = "res://data/loot/items/damaged_wolf_pelt.tres",  weight = 2.0, min = 1, max = 1},
			{path = "res://data/loot/items/fresh_wolf_pelt.tres",    weight = 1.0, min = 1, max = 1},
			{path = "res://data/loot/items/sinew.tres",              weight = 2.0, min = 1, max = 2},
		]
	},
	"Skeleton": {
		"rolls": 1, "empty_weight": 1.0,
		"entries": [
			{path = "res://data/loot/items/bone_fragment.tres",      weight = 3.0, min = 1, max = 2},
			{path = "res://data/loot/items/cloth_scraps.tres",       weight = 1.5, min = 1, max = 2},
		]
	},
	"Gnoll": {
		"rolls": 1, "empty_weight": 0.5,
		"entries": [
			{path = "res://data/loot/items/cloth_scraps.tres",       weight = 3.0, min = 1, max = 3},
			{path = "res://data/loot/items/gnoll_meat.tres",         weight = 2.0, min = 1, max = 1},
			{path = "res://data/loot/items/gnoll_tooth.tres",        weight = 1.5, min = 1, max = 2},
			{path = "res://data/loot/items/sinew.tres",              weight = 1.0, min = 1, max = 1},
		]
	},
	"Rat": {
		"rolls": 1, "empty_weight": 1.0,
		"entries": [
			{path = "res://data/loot/items/rat_meat.tres",           weight = 3.0, min = 1, max = 1},
			{path = "res://data/loot/items/bone_fragment.tres",      weight = 1.0, min = 1, max = 1},
		]
	},
	"Boar": {
		"rolls": 1, "empty_weight": 0.5,
		"entries": [
			{path = "res://data/loot/items/boar_hide.tres",          weight = 2.5, min = 1, max = 1},
			{path = "res://data/loot/items/wolf_meat.tres",          weight = 2.0, min = 1, max = 2},
			{path = "res://data/loot/items/sinew.tres",              weight = 1.5, min = 1, max = 2},
		]
	},
	"Snake": {
		"rolls": 1, "empty_weight": 0.5,
		"entries": [
			{path = "res://data/loot/items/snake_skin.tres",         weight = 2.5, min = 1, max = 1},
			{path = "res://data/loot/items/snake_meat.tres",         weight = 2.0, min = 1, max = 1},
			{path = "res://data/loot/items/snake_venom_sac.tres",    weight = 0.8, min = 1, max = 1},
		]
	},
	"Bear": {
		"rolls": 2, "empty_weight": 0.3,
		"entries": [
			{path = "res://data/loot/items/bear_hide.tres",          weight = 2.5, min = 1, max = 1},
			{path = "res://data/loot/items/wolf_meat.tres",          weight = 2.5, min = 2, max = 3},
			{path = "res://data/loot/items/sinew.tres",              weight = 2.0, min = 2, max = 3},
		]
	},
	"Spider": {
		"rolls": 1, "empty_weight": 0.5,
		"entries": [
			{path = "res://data/loot/items/spiderling_silk.tres",    weight = 2.5, min = 1, max = 2},
			{path = "res://data/loot/items/spider_venom_sac.tres",   weight = 1.0, min = 1, max = 1},
		]
	},
	"Bat": {
		"rolls": 1, "empty_weight": 1.0,
		"entries": [
			{path = "res://data/loot/items/bat_blood.tres",          weight = 2.0, min = 1, max = 1},
			{path = "res://data/loot/items/bat_wing.tres",           weight = 1.5, min = 1, max = 2},
		]
	},
	"Zombie": {
		"rolls": 1, "empty_weight": 1.0,
		"entries": [
			{path = "res://data/loot/items/cloth_scraps.tres",       weight = 3.0, min = 1, max = 3},
			{path = "res://data/loot/items/bone_fragment.tres",      weight = 2.0, min = 1, max = 2},
		]
	},
	"Bandit": {
		"rolls": 2, "empty_weight": 0.5,
		"entries": [
			{path = "res://data/loot/items/cloth_scraps.tres",       weight = 3.0, min = 1, max = 3},
			{path = "res://data/loot/items/copper_ore.tres",         weight = 1.0, min = 1, max = 2},
			{path = "res://data/loot/items/metal_bits.tres",         weight = 1.5, min = 1, max = 3},
			{path = "res://data/loot/items/coal.tres",               weight = 1.0, min = 1, max = 2},
		]
	},
}

# ── Skinning ──────────────────────────────────────────────────────────────────
# tier: creature quality (0=low, 1=medium, 2=high)
# yields: [tattered, damaged, fresh, pristine] — index clamped to max achievable
# Skill thresholds for each step: tier0=0, tier1=10, tier2=30, tier3=60

const SKINNING: Dictionary = {
	"Wolf": {
		"tier": 1,
		"yields": ["tattered_pelt", "damaged_wolf_pelt", "fresh_wolf_pelt", "pristine_wolf_pelt"],
	},
	"Boar": {
		"tier": 1,
		"yields": ["tattered_pelt", "boar_hide", "boar_hide", "boar_hide"],
	},
	"Bear": {
		"tier": 2,
		"yields": ["damaged_wolf_pelt", "bear_hide", "bear_hide", "bear_hide"],
	},
	"Snake": {
		"tier": 1,
		"yields": ["tattered_pelt", "snake_skin", "snake_skin", "snake_skin"],
	},
}

static func is_skinnable_type(mob_name: String) -> bool:
	return not _find_skinning(mob_name).is_empty()

static func skinning_tier_for(mob_name: String) -> int:
	return _find_skinning(mob_name).get("tier", 0)

static func roll_skin(mob_name: String, skill: int) -> ItemData:
	var data := _find_skinning(mob_name)
	if data.is_empty():
		return null
	var tier: int   = data.get("tier", 0)
	var thresholds  := [0, 10, 30, 60]
	var quality     := 0
	for t in range(tier + 1):
		if skill >= thresholds[t]:
			quality = t
	var yields: Array = data.get("yields", [])
	quality = mini(quality, yields.size() - 1)
	var path := "res://data/loot/items/%s.tres" % yields[quality]
	return load(path) as ItemData

static func _find_skinning(mob_name: String) -> Dictionary:
	if SKINNING.has(mob_name):
		return SKINNING[mob_name]
	for key: String in SKINNING.keys():
		if mob_name.containsn(key) or key.containsn(mob_name):
			return SKINNING[key]
	return {}

# ── Loot table factory ────────────────────────────────────────────────────────

static func build(mob_name: String) -> LootTable:
	var data := _find_table(mob_name)
	if data.is_empty():
		return null
	var table := LootTable.new()
	table.rolls        = data.get("rolls", 1)
	table.empty_weight = data.get("empty_weight", 1.5)
	for e: Dictionary in data.get("entries", []):
		var path: String = e.get("path", "")
		if path.is_empty():
			continue
		var item := load(path) as ItemData
		if item == null:
			continue
		var entry := LootEntry.new()
		entry.item      = item
		entry.weight    = e.get("weight", 1.0)
		entry.min_count = e.get("min", 1)
		entry.max_count = e.get("max", 1)
		table.entries.append(entry)
	return table

static func _find_table(mob_name: String) -> Dictionary:
	if TABLES.has(mob_name):
		return TABLES[mob_name]
	for key: String in TABLES.keys():
		if mob_name.containsn(key) or key.containsn(mob_name):
			return TABLES[key]
	return {}
