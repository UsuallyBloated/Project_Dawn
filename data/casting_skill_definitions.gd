class_name CastingSkillDefinitions

const MAX_LEVEL: int = 60

const ALL: Array[String] = [
	"evocation", "alteration", "abjuration", "conjuration", "divination", "channeling",
]

const DISPLAY: Dictionary = {
	"evocation":   "Evocation",
	"alteration":  "Alteration",
	"abjuration":  "Abjuration",
	"conjuration": "Conjuration",
	"divination":  "Divination",
	"channeling":  "Channeling",
}

# Max skill value at level MAX_LEVEL per class. 0 = class cannot train this discipline.
const CLASS_CAPS: Dictionary = {
	"Warrior":       {"evocation":   0, "alteration":   0, "abjuration":   0, "conjuration":   0, "divination":   0, "channeling":   0},
	"Paladin":       {"evocation": 125, "alteration": 150, "abjuration": 225, "conjuration":   0, "divination":  50, "channeling": 225},
	"Shadow Knight": {"evocation": 125, "alteration": 125, "abjuration": 100, "conjuration":   0, "divination":  50, "channeling": 225},
	"Cleric":        {"evocation": 150, "alteration": 200, "abjuration": 250, "conjuration":  75, "divination": 200, "channeling": 175},
	"Druid":         {"evocation": 175, "alteration": 225, "abjuration": 175, "conjuration":  75, "divination": 175, "channeling": 175},
	"Shaman":        {"evocation": 175, "alteration": 250, "abjuration": 125, "conjuration":  75, "divination": 150, "channeling": 200},
	"Rogue":         {"evocation":   0, "alteration":   0, "abjuration":   0, "conjuration":   0, "divination":   0, "channeling":   0},
	"Monk":          {"evocation":   0, "alteration":   0, "abjuration":   0, "conjuration":   0, "divination":   0, "channeling":   0},
	"Ranger":        {"evocation": 125, "alteration": 150, "abjuration":  75, "conjuration":   0, "divination": 150, "channeling": 200},
	"Beast Master":  {"evocation": 125, "alteration": 150, "abjuration": 100, "conjuration":  75, "divination":  75, "channeling": 175},
	"Bard":          {"evocation": 125, "alteration": 200, "abjuration": 100, "conjuration": 150, "divination":  75, "channeling": 200},
	"Witch Hunter":  {"evocation": 225, "alteration": 125, "abjuration": 100, "conjuration":   0, "divination":  75, "channeling": 200},
	"Magician":      {"evocation": 225, "alteration": 100, "abjuration":  75, "conjuration": 250, "divination":  75, "channeling": 150},
	"Wizard":        {"evocation": 250, "alteration": 100, "abjuration": 150, "conjuration": 100, "divination": 225, "channeling": 150},
	"Sorcerer":      {"evocation": 250, "alteration": 100, "abjuration":  75, "conjuration":  75, "divination":  50, "channeling": 150},
	"Necromancer":   {"evocation": 200, "alteration": 175, "abjuration":  50, "conjuration": 225, "divination": 100, "channeling": 150},
	"Enchanter":     {"evocation": 150, "alteration": 250, "abjuration": 200, "conjuration": 175, "divination": 125, "channeling": 150},
	"Blood Mage":    {"evocation": 200, "alteration": 175, "abjuration":  75, "conjuration":   0, "divination":  50, "channeling": 175},
}

static func get_cap(player_class: String, skill: String, level: int) -> int:
	var class_data: Dictionary = CLASS_CAPS.get(player_class, CLASS_CAPS["Warrior"])
	var max_cap: int = class_data.get(skill, 0)
	if max_cap == 0:
		return 0
	@warning_ignore("integer_division")
	return max(1, int(max_cap * level / MAX_LEVEL))

static func get_starting_value(player_class: String, skill: String) -> int:
	# Track 22.F: L1 cap / 4 with a floor of 1; cap == 0 stays 0.
	var cap := get_cap(player_class, skill, 1)
	if cap == 0:
		return 0
	@warning_ignore("integer_division")
	return max(1, cap / 4)
