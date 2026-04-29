class_name WeaponSkillDefinitions

const MAX_LEVEL: int = 60

const ALL: Array[String] = [
	"1h_slashing", "2h_slashing", "1h_blunt", "2h_blunt",
	"piercing", "hand_to_hand", "defense", "dodge",
]

const DISPLAY: Dictionary = {
	"1h_slashing":  "1H Slashing",
	"2h_slashing":  "2H Slashing",
	"1h_blunt":     "1H Blunt",
	"2h_blunt":     "2H Blunt",
	"piercing":     "Piercing",
	"hand_to_hand": "Hand to Hand",
	"defense":      "Defense",
	"dodge":        "Dodge",
}

# Max skill value at level MAX_LEVEL per class. 0 = class cannot train this skill.
const CLASS_CAPS: Dictionary = {
	"Warrior":       {"1h_slashing": 250, "2h_slashing": 250, "1h_blunt": 250, "2h_blunt": 250, "piercing": 250, "hand_to_hand": 100, "defense": 250, "dodge": 200},
	"Rogue":         {"1h_slashing": 225, "2h_slashing":   0, "1h_blunt":  75, "2h_blunt":   0, "piercing": 250, "hand_to_hand": 200, "defense": 200, "dodge": 250},
	"Magician":      {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt":  75, "2h_blunt":   0, "piercing":   0, "hand_to_hand":  25, "defense": 100, "dodge":  75},
	"Wizard":        {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt":  75, "2h_blunt":   0, "piercing":   0, "hand_to_hand":  25, "defense": 100, "dodge":  75},
	"Sorcerer":      {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt":  75, "2h_blunt":   0, "piercing":   0, "hand_to_hand":  25, "defense": 100, "dodge":  75},
	"Necromancer":   {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt":  75, "2h_blunt":   0, "piercing":   0, "hand_to_hand":  25, "defense": 100, "dodge":  75},
	"Enchanter":     {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt":  75, "2h_blunt":   0, "piercing":   0, "hand_to_hand":  25, "defense": 100, "dodge":  75},
	"Blood Mage":    {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt": 100, "2h_blunt":   0, "piercing":  50, "hand_to_hand":  50, "defense": 100, "dodge":  75},
	"Cleric":        {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt": 200, "2h_blunt": 200, "piercing":   0, "hand_to_hand":  50, "defense": 200, "dodge": 150},
	"Druid":         {"1h_slashing":   0, "2h_slashing":   0, "1h_blunt": 175, "2h_blunt": 175, "piercing":   0, "hand_to_hand":  50, "defense": 175, "dodge": 150},
	"Shaman":        {"1h_slashing": 150, "2h_slashing":   0, "1h_blunt": 200, "2h_blunt": 200, "piercing": 100, "hand_to_hand": 100, "defense": 200, "dodge": 150},
	"Paladin":       {"1h_slashing": 225, "2h_slashing": 225, "1h_blunt": 225, "2h_blunt": 225, "piercing": 150, "hand_to_hand":  75, "defense": 225, "dodge": 175},
	"Shadow Knight": {"1h_slashing": 225, "2h_slashing": 225, "1h_blunt": 225, "2h_blunt": 225, "piercing": 150, "hand_to_hand":  75, "defense": 225, "dodge": 175},
	"Bard":          {"1h_slashing": 200, "2h_slashing": 150, "1h_blunt": 175, "2h_blunt": 150, "piercing": 200, "hand_to_hand": 100, "defense": 175, "dodge": 200},
	"Ranger":        {"1h_slashing": 225, "2h_slashing": 225, "1h_blunt": 175, "2h_blunt": 175, "piercing": 225, "hand_to_hand": 100, "defense": 200, "dodge": 225},
	"Monk":          {"1h_slashing":  50, "2h_slashing":   0, "1h_blunt": 200, "2h_blunt": 100, "piercing":   0, "hand_to_hand": 250, "defense": 250, "dodge": 250},
	"Witch Hunter":  {"1h_slashing": 200, "2h_slashing": 150, "1h_blunt": 100, "2h_blunt":   0, "piercing": 225, "hand_to_hand": 125, "defense": 200, "dodge": 200},
}

static func get_cap(player_class: String, skill: String, level: int) -> int:
	var class_data: Dictionary = CLASS_CAPS.get(player_class, CLASS_CAPS["Magician"])
	var max_cap: int = class_data.get(skill, 0)
	if max_cap == 0:
		return 0
	return max(1, int(max_cap * level / MAX_LEVEL))

static func get_starting_value(player_class: String, skill: String) -> int:
	var cap := get_cap(player_class, skill, 1)
	return cap
