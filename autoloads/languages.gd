extends Node

signal skill_improved(language: String, new_skill: int)
signal active_language_changed(language: String)

# { "Common": 100, "Elvish": 75, … }
var skills: Dictionary = {}
var active_language: String = "Common"

func initialize(race: String) -> void:
	skills.clear()
	var starting: Dictionary = LanguageDefinitions.RACE_STARTING_SKILLS.get(race, {})
	for lang in LanguageDefinitions.LANGUAGES:
		skills[lang] = starting.get(lang, 0)
	active_language = "Common"

func get_skill(lang: String) -> int:
	return skills.get(lang, 0)

func set_active_language(lang: String) -> void:
	if skills.get(lang, 0) == 0:
		return
	active_language = lang
	active_language_changed.emit(lang)

# Call when the player receives speech in a language they partially know.
# Skill 0 requires a trainer; passive gain only kicks in above 0.
# Future hook: trainers set skill to 1, then hearing does the rest.
func hear_language(lang: String) -> void:
	var current: int = skills.get(lang, 0)
	if current <= 0 or current >= 100:
		return
	if randf() < 0.05:
		skills[lang] = current + 1
		skill_improved.emit(lang, skills[lang])

# Returns text garbled according to the receiver's skill in lang.
# Intended to be called on the receiving client, never the sender.
func garble(text: String, lang: String) -> String:
	var skill: int = get_skill(lang)
	if skill >= 100:
		return text
	var cipher: String = LanguageDefinitions.GARBLE_CIPHERS.get(lang, "")
	if cipher.length() != 26:
		return text
	var clarity: float = skill / 100.0
	var words: PackedStringArray = text.split(" ")
	var result: PackedStringArray = PackedStringArray()
	for word in words:
		if randf() < clarity:
			result.append(word)
		else:
			result.append(_apply_cipher(word, cipher))
	return " ".join(result)

func grant_language(lang: String, skill: int) -> void:
	if skills.get(lang, 0) >= skill:
		return
	skills[lang] = skill
	skill_improved.emit(lang, skill)

func _apply_cipher(word: String, cipher: String) -> String:
	var out := ""
	for c in word:
		if c >= "a" and c <= "z":
			out += cipher[c.unicode_at(0) - "a".unicode_at(0)]
		elif c >= "A" and c <= "Z":
			out += cipher[c.unicode_at(0) - "A".unicode_at(0)].to_upper()
		else:
			out += c
	return out
