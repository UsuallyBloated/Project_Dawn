class_name LanguageDefinitions

const LANGUAGES: Array[String] = [
	"Common", "Elvish", "Dark Speech", "Gnomish", "Halfling", "Dwarvish",
	"Ogre", "Troll", "Kel`varath", "Minotaur", "Ghost Tongue", "Fae",
	"Felhari", "Kobold", "Elder Elvish",
]

# skill 0 = unknown, 100 = fluent
const RACE_STARTING_SKILLS: Dictionary = {
	"Human":     {"Common": 100},
	"Elf":       {"Common": 100, "Elvish": 100},
	"Dark Elf":  {"Common": 100, "Dark Speech": 100, "Elvish": 25},
	"Wood Elf":  {"Common": 100, "Elvish": 100},
	"Gnome":     {"Common": 100, "Gnomish": 100},
	"Halfling":  {"Common": 100, "Halfling": 100},
	"Dwarf":     {"Common": 100, "Dwarvish": 100},
	"Half-Elf":  {"Common": 100, "Elvish": 50},
	"Ogre":      {"Common": 50,  "Ogre": 100},
	"Troll":     {"Common": 30,  "Troll": 100},
	"Kel`varath": {"Common": 50,  "Kel`varath": 100},
	"Minotaur":  {"Common": 50,  "Minotaur": 100},
	"Revenant":  {"Common": 100, "Ghost Tongue": 100},
	"Fae":       {"Common": 100, "Fae": 100, "Elvish": 50},
	"Felhari":   {"Common": 50,  "Felhari": 100},
	"Kobold":    {"Common": 30,  "Kobold": 100},
	"Half-Ogre": {"Common": 75,  "Ogre": 100},
	# Revenant is a transformation, not a selectable race.
	# Language grants are handled in autoloads/transformations.gd via Languages.grant_language().
}

# Each value is a 26-char permutation mapping a→cipher[0], b→cipher[1], …
# Determines how garbled text looks to a receiver who doesn't know the language.
const GARBLE_CIPHERS: Dictionary = {
	"Common":      "abcdefghijklmnopqrstuvwxyz",
	"Elvish":      "livaenrostucphdmbyfgkwxzjq",
	"Dark Speech": "zqxjkvbpygwnrsdtfoiumclhea",
	"Gnomish":     "bcdefghijklmnopqrstuvwxyza",
	"Halfling":    "zyxwvutsrqponmlkjihgfedcba",
	"Dwarvish":    "defghijklmnopqrstuvwxyzabc",
	"Ogre":        "rstuvwxyzabcdefghijklmnopq",
	"Troll":       "nopqrstuvwxyzabcdefghijklm",
	"Kel`varath":  "qwertyuiopasdfghjklzxcvbnm",
	"Minotaur":    "mnbvcxzasdfghjklpoiuytrewq",
	"Ghost Tongue":"hijklmnopqrstuvwxyzabcdefg",
	"Fae":         "zyxabcwvutsrqponmlkjihgfed",
	"Felhari":     "fghijklmnopqrstuvwxyzabcde",
	"Kobold":      "dcbazywvutsrqponmlkjihgfex",
	"Elder Elvish":"aelionrstvucphdmbyfgkwxzjq",
}
