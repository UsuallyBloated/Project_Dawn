class_name NamedMobDefinitions

# Named / boss mob data. Key = named_id string used in EnemySpawner.
#
# Fields:
#   display_name      — shown in nameplate
#   subtitle          — appended after display_name ("Rotfang the Feared")
#   hp_mult           — multiplied against the base scene's max_hp
#   damage_mult       — multiplied against base_damage and spell_damage at attack time
#   xp_mult           — multiplied against xp_reward
#   level             — overrides the scene level
#   enrage_threshold  — fraction (0.0–1.0); enrage fires once when hp/max_hp drops below; 0 = disabled
#   enrage_damage_mult — additional damage multiplier applied during enrage (stacks on damage_mult)
#   enrage_speed_mult  — move speed multiplier during enrage
#   guaranteed_loot   — Array of resource paths; always drops
#   rare_loot         — Array of { path: String, drop_chance: float } rolled at spawn time
#
# Track 20D — loot is now resource-path-based (was inline dicts).
# Each path resolves to an authored .tres in data/loot/items/, which
# means the server registry (items.toml) knows about these items.
# Before this lift, named drops were runtime-only items with no
# canonical path, so equip / sell / destroy silently failed server-
# side with "unknown item path".

const ALL: Dictionary = {
	"rotfang": {
		"display_name": "Rotfang",
		"subtitle": "the Feared",
		"hp_mult": 3.5,
		"damage_mult": 1.8,
		"xp_mult": 4.0,
		"level": 6,
		"enrage_threshold": 0.20,
		"enrage_damage_mult": 1.4,
		"enrage_speed_mult": 1.3,
		"guaranteed_loot": [
			"res://data/loot/items/rotfangs_fang.tres",
		],
		"rare_loot": [
			{"path": "res://data/loot/items/predators_collar.tres", "drop_chance": 0.30},
		]
	},

	"greth": {
		"display_name": "Greth Bonecrusher",
		"subtitle": "",
		"hp_mult": 4.0,
		"damage_mult": 2.0,
		"xp_mult": 5.0,
		"level": 10,
		"enrage_threshold": 0.25,
		"enrage_damage_mult": 1.5,
		"enrage_speed_mult": 1.2,
		"guaranteed_loot": [
			"res://data/loot/items/gnoll_chiefs_seal.tres",
		],
		"rare_loot": [
			{"path": "res://data/loot/items/bonecrushers_war_axe.tres", "drop_chance": 0.25},
		]
	},

	"ancient_crawler": {
		"display_name": "Ancient Crawler",
		"subtitle": "",
		"hp_mult": 3.0,
		"damage_mult": 1.6,
		"xp_mult": 3.5,
		"level": 8,
		"enrage_threshold": 0.30,
		"enrage_damage_mult": 1.3,
		"enrage_speed_mult": 1.4,
		"guaranteed_loot": [
			"res://data/loot/items/pristine_venom_sac.tres",
		],
		"rare_loot": [
			{"path": "res://data/loot/items/chitinous_ring.tres", "drop_chance": 0.25},
		]
	},

	"sable": {
		"display_name": "Sable",
		"subtitle": "the Dark",
		"hp_mult": 2.5,
		"damage_mult": 1.5,
		"xp_mult": 3.0,
		"level": 5,
		"enrage_threshold": 0.0,
		"enrage_damage_mult": 1.0,
		"enrage_speed_mult": 1.0,
		"guaranteed_loot": [
			"res://data/loot/items/sable_wing_membrane.tres",
		],
		"rare_loot": [
			{"path": "res://data/loot/items/shadow_signet.tres", "drop_chance": 0.20},
		]
	},

	"the_undying": {
		"display_name": "The Undying",
		"subtitle": "",
		"hp_mult": 5.0,
		"damage_mult": 2.2,
		"xp_mult": 6.0,
		"level": 12,
		"enrage_threshold": 0.40,
		"enrage_damage_mult": 1.6,
		"enrage_speed_mult": 1.1,
		"guaranteed_loot": [
			"res://data/loot/items/undying_marrow.tres",
		],
		"rare_loot": [
			{"path": "res://data/loot/items/cursed_femur.tres", "drop_chance": 0.20},
		]
	}
}

# Loads an ItemData by resource path. Returns null with a warning if
# the file is missing — protects boss kills from silently dropping
# nothing because an authoring typo broke the path. Used by
# enemy.apply_named().
static func load_item(path: String) -> ItemData:
	if not ResourceLoader.exists(path):
		push_warning("named mob loot path missing: %s" % path)
		return null
	return load(path) as ItemData
