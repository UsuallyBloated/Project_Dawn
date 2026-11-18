extends Node

# Languages: the character's skill in each language and the one they speak
# in. Only the readout exists today; the passive gain from hearing speech,
# the garbling of text the listener half-knows and the trainer grant were
# removed as dead code on 2026-11-18 (git has them) and come back with the
# chat-receive wiring (the "Language system wiring" To-Do).

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
