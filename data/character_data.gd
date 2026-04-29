class_name CharacterData

const RACES: Array[String] = [
	"Human", "Elf", "Dark Elf", "Wood Elf", "Gnome",
	"Halfling", "Dwarf", "Half-Elf", "Ogre", "Troll",
	"Iksar", "Minotaur", "Revenant", "Fae", "Vah Shir", "Kobold", "Half-Ogre"
]

const CLASSES: Array[String] = [
	"Warrior", "Mage", "Rogue", "Cleric", "Druid", "Shaman", "Blood Mage",
	"Paladin", "Shadow Knight", "Necromancer", "Enchanter", "Bard", "Ranger", "Monk", "Witch Hunter"
]

const RACE_DATA: Dictionary = {
	"Human": {
		"desc": "Versatile and adaptable. Balanced bonuses across all attributes suit any profession.",
		"bonuses": {"strength": 2, "dexterity": 2, "agility": 2, "intelligence": 2, "wisdom": 2, "charisma": 2, "constitution": 2}
	},
	"Elf": {
		"desc": "Graceful and keen. High dexterity and intellect, but physically fragile.",
		"bonuses": {"dexterity": 10, "agility": 10, "intelligence": 10, "wisdom": 5, "strength": -5, "constitution": -5}
	},
	"Dark Elf": {
		"desc": "Cunning masters of dark magic with exceptional reflexes. Few trust them.",
		"bonuses": {"intelligence": 15, "dexterity": 10, "agility": 5, "wisdom": -5, "charisma": -10}
	},
	"Gnome": {
		"desc": "Brilliant tinkerers with extraordinary intellect and wisdom, but weak in body.",
		"bonuses": {"intelligence": 15, "wisdom": 5, "strength": -5, "constitution": -5}
	},
	"Halfling": {
		"desc": "Quick and nimble folk. Masters of stealth and sleight of hand.",
		"bonuses": {"dexterity": 10, "agility": 10, "charisma": 5, "strength": -5, "constitution": -5}
	},
	"Dwarf": {
		"desc": "Hardy mountainfolk, nearly unbreakable. Exceptional constitution and wisdom.",
		"bonuses": {"constitution": 15, "strength": 5, "wisdom": 5, "charisma": -5, "agility": -5}
	},
	"Wood Elf": {
		"desc": "Children of the forest, swift and sure-eyed. Exceptional hunters and rangers.",
		"bonuses": {"dexterity": 10, "agility": 10, "wisdom": 5, "intelligence": -5, "charisma": -5}
	},
	"Half-Elf": {
		"desc": "Blending elven grace with human resilience. Well-rounded and adaptable.",
		"bonuses": {"dexterity": 5, "agility": 5, "intelligence": 5, "wisdom": 5}
	},
	"Ogre": {
		"desc": "Massive and brutish. Unmatched raw power at the cost of wit and charm.",
		"bonuses": {"strength": 20, "constitution": 10, "charisma": -15, "intelligence": -5, "wisdom": -5}
	},
	"Troll": {
		"desc": "Savage regenerators with extraordinary endurance. Fearsome but repugnant.",
		"bonuses": {"constitution": 20, "strength": 10, "charisma": -15, "wisdom": -10, "intelligence": -5}
	},
	"Iksar": {
		"desc": "Ancient lizardfolk from a fallen empire. Cold-blooded and calculating, their natural scales make them fearsome survivors.",
		"bonuses": {"constitution": 15, "strength": 8, "charisma": -15, "wisdom": -5}
	},
	"Minotaur": {
		"desc": "Bull-headed titans who carry the weight of generations in bondage. Their rage is matched only by their grief.",
		"bonuses": {"strength": 20, "constitution": 10, "charisma": -10, "intelligence": -8, "agility": -5}
	},
	"Revenant": {
		"desc": "The returned dead. Neither fully alive nor fully gone, immune to fear and numb to pain.",
		"bonuses": {"intelligence": 10, "constitution": 10, "strength": 5, "charisma": -15, "wisdom": -5}
	},
	"Fae": {
		"desc": "Ageless creatures of pure magic from the hidden world. Impossibly small, impossibly old, impossibly powerful.",
		"bonuses": {"intelligence": 20, "wisdom": 10, "agility": 15, "charisma": 5, "strength": -15, "constitution": -10}
	},
	"Vah Shir": {
		"desc": "Proud feline warriors from a distant land. Graceful, deadly, and deeply tribal. They treat combat as an art form.",
		"bonuses": {"dexterity": 12, "agility": 12, "constitution": 5, "wisdom": -5, "intelligence": -5, "charisma": -5}
	},
	"Kobold": {
		"desc": "Dog-faced scavengers with bat ears and wiry fur, scrappy and relentlessly underestimated. Kobolds survive through cunning, traps, and sheer stubborn spite.",
		"bonuses": {"dexterity": 10, "intelligence": 8, "agility": 5, "strength": -8, "constitution": -5, "charisma": -10}
	},
	"Half-Ogre": {
		"desc": "Born between brutality and humanity. Too large for one world, too feeling for the other.",
		"bonuses": {"strength": 15, "constitution": 8, "charisma": -8, "intelligence": -3, "wisdom": -3}
	},
}

const CLASS_DATA: Dictionary = {
	"Warrior": {
		"desc": "Masters of melee combat. Heavy armor, high HP, and physical dominance define their path.",
		"bonuses": {"strength": 10, "constitution": 8},
		"hp_bonus": 50.0, "mp_bonus": 0.0, "stamina_bonus": 20.0
	},
	"Mage": {
		"desc": "Wielders of arcane power. Devastating spells and vast mana, at the cost of physical frailty.",
		"bonuses": {"intelligence": 15, "wisdom": 10},
		"hp_bonus": -10.0, "mp_bonus": 100.0, "stamina_bonus": 0.0
	},
	"Rogue": {
		"desc": "Cunning infiltrators. Precision strikes, poisons, and unmatched agility define their craft.",
		"bonuses": {"dexterity": 15, "agility": 10},
		"hp_bonus": 20.0, "mp_bonus": 0.0, "stamina_bonus": 20.0
	},
	"Cleric": {
		"desc": "Devoted healers armored in faith. Divine magic mends wounds and smites the wicked.",
		"bonuses": {"wisdom": 12, "constitution": 8},
		"hp_bonus": 30.0, "mp_bonus": 60.0, "stamina_bonus": 0.0
	},
	"Druid": {
		"desc": "Guardians of the natural world. They balance potent nature spells with restorative magic.",
		"bonuses": {"wisdom": 10, "intelligence": 8},
		"hp_bonus": 10.0, "mp_bonus": 70.0, "stamina_bonus": 0.0
	},
	"Shaman": {
		"desc": "Spiritual warriors who commune with ancestors. Blend melee combat with healing and spirit magic.",
		"bonuses": {"wisdom": 10, "constitution": 8, "strength": 5},
		"hp_bonus": 30.0, "mp_bonus": 40.0, "stamina_bonus": 15.0
	},
	"Blood Mage": {
		"desc": "Masters of dark vitomancy. They drain life from enemies and bend mortal flesh to their will.",
		"bonuses": {"intelligence": 15, "constitution": 5},
		"hp_bonus": 0.0, "mp_bonus": 80.0, "stamina_bonus": 0.0
	},
	"Paladin": {
		"desc": "A holy warrior armored in faith. Divine strikes, protective auras, and battlefield healing define their calling.",
		"bonuses": {"strength": 10, "wisdom": 8, "constitution": 5},
		"hp_bonus": 40.0, "mp_bonus": 30.0, "stamina_bonus": 15.0
	},
	"Shadow Knight": {
		"desc": "A dark champion fueled by death and suffering. Lifetap strikes and shadow magic sustain them in battle.",
		"bonuses": {"strength": 10, "intelligence": 8, "constitution": 5},
		"hp_bonus": 35.0, "mp_bonus": 30.0, "stamina_bonus": 10.0
	},
	"Necromancer": {
		"desc": "Masters of death magic. They raise the fallen as servants and drain life with corrupting curses.",
		"bonuses": {"intelligence": 15, "wisdom": 5},
		"hp_bonus": -10.0, "mp_bonus": 100.0, "stamina_bonus": 0.0
	},
	"Enchanter": {
		"desc": "Wielders of illusion and mental magic. Unmatched crowd control and mana restoration, but they never throw the first punch.",
		"bonuses": {"intelligence": 12, "charisma": 12, "wisdom": 5},
		"hp_bonus": -10.0, "mp_bonus": 90.0, "stamina_bonus": 0.0
	},
	"Bard": {
		"desc": "Wandering storytellers who weave magic through music. Their songs reshape the battlefield while their blades keep them in it.",
		"bonuses": {"dexterity": 8, "charisma": 12, "agility": 5},
		"hp_bonus": 20.0, "mp_bonus": 30.0, "stamina_bonus": 20.0
	},
	"Ranger": {
		"desc": "Hunters and trackers of the wild. Swift with both blade and bow, they read the land like a second language.",
		"bonuses": {"dexterity": 12, "agility": 8, "wisdom": 5},
		"hp_bonus": 20.0, "mp_bonus": 20.0, "stamina_bonus": 20.0
	},
	"Monk": {
		"desc": "Unarmed masters of discipline. No armor, no weapons — only speed, technique, and unbreakable focus.",
		"bonuses": {"strength": 8, "dexterity": 8, "agility": 8},
		"hp_bonus": 25.0, "mp_bonus": 10.0, "stamina_bonus": 30.0
	},
	"Witch Hunter": {
		"desc": "Relentless pursuers of the arcane and the corrupted. Expert at unraveling dark magic and those who wield it.",
		"bonuses": {"intelligence": 8, "constitution": 8, "wisdom": 8},
		"hp_bonus": 20.0, "mp_bonus": 40.0, "stamina_bonus": 10.0
	},
}

const LOCKED_COMBOS: Dictionary = {
	"Dark Elf":  ["Paladin"],
	"Wood Elf":  ["Necromancer"],
	"Halfling":  ["Shadow Knight"],
	"Dwarf":     ["Necromancer"],
	"Troll":     ["Paladin", "Monk"],
	"Iksar":     ["Paladin"],
	"Fae":       ["Shadow Knight", "Monk"],
	"Kobold":    ["Paladin"],
}

const CLASS_STARTING_ALIGNMENT: Dictionary = {
	"Paladin":       500,
	"Cleric":        400,
	"Monk":          100,
	"Witch Hunter":  100,
	"Warrior":       0,
	"Mage":          0,
	"Rogue":         0,
	"Druid":         0,
	"Shaman":        0,
	"Ranger":        0,
	"Bard":          0,
	"Enchanter":     0,
	"Blood Mage":   -500,
	"Shadow Knight": -1600,
	"Necromancer":   -1600,
}

const STAT_KEYS: Array[String] = [
	"strength", "dexterity", "agility",
	"intelligence", "wisdom", "charisma", "constitution"
]

const STAT_SHORT: Array[String] = ["STR", "DEX", "AGI", "INT", "WIS", "CHA", "CON"]

const BASE: int        = 10
const BASE_HP: float   = 100.0
const BASE_MP: float   = 100.0
const BASE_ST: float   = 100.0

# Per-level stat and resource gains for each class.
# player_stats.gd reads this in _level_up() — add new classes here, not there.
const CLASS_LEVEL_GAINS: Dictionary = {
	"Warrior":       {"stats": {"strength": 2, "constitution": 2},                    "max_hp": 20.0, "max_mp":  2.0, "max_stamina":  8.0},
	"Mage":          {"stats": {"intelligence": 3, "wisdom": 2},                       "max_hp":  5.0, "max_mp": 25.0, "max_stamina":  2.0},
	"Rogue":         {"stats": {"dexterity": 2, "agility": 2},                         "max_hp": 12.0, "max_mp":  3.0, "max_stamina": 10.0},
	"Cleric":        {"stats": {"wisdom": 3, "constitution": 1},                       "max_hp": 12.0, "max_mp": 20.0, "max_stamina":  2.0},
	"Druid":         {"stats": {"wisdom": 2, "intelligence": 2},                       "max_hp":  8.0, "max_mp": 22.0, "max_stamina":  2.0},
	"Shaman":        {"stats": {"wisdom": 2, "constitution": 1, "strength": 1},        "max_hp": 12.0, "max_mp": 15.0, "max_stamina":  5.0},
	"Blood Mage":    {"stats": {"intelligence": 3, "constitution": 1},                 "max_hp":  7.0, "max_mp": 22.0, "max_stamina":  2.0},
	"Paladin":       {"stats": {"strength": 2, "wisdom": 2, "constitution": 1},        "max_hp": 15.0, "max_mp": 12.0, "max_stamina":  5.0},
	"Shadow Knight": {"stats": {"strength": 2, "intelligence": 2, "constitution": 1}, "max_hp": 14.0, "max_mp": 12.0, "max_stamina":  4.0},
	"Necromancer":   {"stats": {"intelligence": 3, "wisdom": 2},                       "max_hp":  3.0, "max_mp": 25.0, "max_stamina":  1.0},
	"Enchanter":     {"stats": {"intelligence": 3, "charisma": 2},                     "max_hp":  3.0, "max_mp": 23.0, "max_stamina":  1.0},
	"Bard":          {"stats": {"dexterity": 2, "charisma": 2, "agility": 1},          "max_hp": 10.0, "max_mp":  8.0, "max_stamina":  8.0},
	"Ranger":        {"stats": {"dexterity": 2, "agility": 2, "wisdom": 1},            "max_hp": 10.0, "max_mp":  8.0, "max_stamina":  8.0},
	"Monk":          {"stats": {"strength": 2, "dexterity": 2, "agility": 1},          "max_hp": 12.0, "max_mp":  4.0, "max_stamina": 10.0},
	"Witch Hunter":  {"stats": {"intelligence": 2, "wisdom": 2, "constitution": 1},   "max_hp": 10.0, "max_mp": 15.0, "max_stamina":  4.0},
	"_default":      {"stats": {},                                                      "max_hp": 10.0, "max_mp": 10.0, "max_stamina":  5.0},
}
