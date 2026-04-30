class_name ArmorSkillDefinitions

const MAX_LEVEL: int = 60

const ALL: Array[String] = [
	"cloth", "leather", "chain", "plate", "shield",
]

const DISPLAY: Dictionary = {
	"cloth":   "Cloth Armor",
	"leather": "Leather Armor",
	"chain":   "Chain Armor",
	"plate":   "Plate Armor",
	"shield":  "Shield",
}

# Max skill value at level MAX_LEVEL per class. 0 = class cannot train this armor type.
const CLASS_CAPS: Dictionary = {
	"Warrior":       {"cloth":  75, "leather": 150, "chain": 225, "plate": 250, "shield": 250},
	"Paladin":       {"cloth":  75, "leather": 150, "chain": 200, "plate": 225, "shield": 250},
	"Shadow Knight": {"cloth":  75, "leather": 150, "chain": 200, "plate": 225, "shield": 225},
	"Cleric":        {"cloth": 100, "leather": 100, "chain": 200, "plate": 225, "shield": 225},
	"Druid":         {"cloth": 100, "leather": 200, "chain": 175, "plate":   0, "shield": 125},
	"Shaman":        {"cloth": 100, "leather": 175, "chain": 225, "plate":   0, "shield": 175},
	"Rogue":         {"cloth": 100, "leather": 250, "chain": 100, "plate":   0, "shield": 100},
	"Monk":          {"cloth": 150, "leather":   0, "chain":   0, "plate":   0, "shield":   0},
	"Ranger":        {"cloth":  75, "leather": 225, "chain": 225, "plate":   0, "shield": 175},
	"Beast Master":  {"cloth":  75, "leather": 200, "chain": 200, "plate":   0, "shield": 150},
	"Bard":          {"cloth":  75, "leather": 200, "chain": 225, "plate":   0, "shield": 150},
	"Witch Hunter":  {"cloth":  75, "leather": 200, "chain": 225, "plate":   0, "shield": 150},
	"Magician":      {"cloth": 250, "leather":  50, "chain":   0, "plate":   0, "shield":   0},
	"Wizard":        {"cloth": 250, "leather":  50, "chain":   0, "plate":   0, "shield":   0},
	"Sorcerer":      {"cloth": 250, "leather":  50, "chain":   0, "plate":   0, "shield":   0},
	"Necromancer":   {"cloth": 250, "leather":  50, "chain":   0, "plate":   0, "shield":   0},
	"Enchanter":     {"cloth": 250, "leather":  50, "chain":   0, "plate":   0, "shield":   0},
	"Blood Mage":    {"cloth": 200, "leather": 100, "chain":  50, "plate":   0, "shield":   0},
}

static func get_cap(player_class: String, skill: String, level: int) -> int:
	var class_data: Dictionary = CLASS_CAPS.get(player_class, CLASS_CAPS["Magician"])
	var max_cap: int = class_data.get(skill, 0)
	if max_cap == 0:
		return 0
	return max(1, int(max_cap * level / MAX_LEVEL))

static func get_starting_value(player_class: String, skill: String) -> int:
	return get_cap(player_class, skill, 1)
