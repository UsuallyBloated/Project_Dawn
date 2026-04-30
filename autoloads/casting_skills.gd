extends Node

signal skill_advanced(skill_name: String, new_value: int, cap: int)

var _skills: Dictionary = {}
var _player_class: String = ""
var _level: int = 1

func _ready() -> void:
	PlayerStats.level_changed.connect(_on_level_changed)

func initialize(player_class: String, level: int) -> void:
	_player_class = player_class
	_level = level
	_skills.clear()
	for skill in CastingSkillDefinitions.ALL:
		_skills[skill] = CastingSkillDefinitions.get_starting_value(player_class, skill)

func try_advance(skill_name: String) -> void:
	if _player_class == "" or not _skills.has(skill_name):
		return
	var current: int = _skills[skill_name]
	var cap: int = CastingSkillDefinitions.get_cap(_player_class, skill_name, _level)
	if cap == 0 or current >= cap:
		return
	var advance_chance := 0.2 * (1.0 - float(current) / float(cap))
	if randf() < advance_chance:
		_skills[skill_name] = current + 1
		skill_advanced.emit(skill_name, _skills[skill_name], cap)

func get_current(skill_name: String) -> int:
	return _skills.get(skill_name, 0)

func get_cap(skill_name: String) -> int:
	return CastingSkillDefinitions.get_cap(_player_class, skill_name, _level)

func _get_ratio(skill_name: String) -> float:
	var cap := get_cap(skill_name)
	if cap == 0:
		return 0.0
	return float(get_current(skill_name)) / float(cap)

# 1.0–1.15× damage multiplier for Evocation spells.
func get_damage_mult(discipline: String) -> float:
	if discipline != "evocation":
		return 1.0
	return 1.0 + 0.15 * _get_ratio("evocation")

# 1.0–1.25× duration multiplier for Alteration effects (HoT, DoT, CC duration).
func get_duration_mult(discipline: String) -> float:
	if discipline != "alteration":
		return 1.0
	return 1.0 + 0.25 * _get_ratio("alteration")

# 1.0–1.20× absorb multiplier for Abjuration shields.
func get_absorb_mult(discipline: String) -> float:
	if discipline != "abjuration":
		return 1.0
	return 1.0 + 0.20 * _get_ratio("abjuration")

# Probability [0.10, 0.70] that an incoming hit interrupts an active cast.
# At channeling skill 0: 70%. At max skill: 10%.
# Returns 1.0 for non-casters (cap = 0) — should never be reached in practice.
func get_interrupt_chance() -> float:
	var cap := get_cap("channeling")
	if cap == 0:
		return 1.0
	var ratio := float(get_current("channeling")) / float(cap)
	return maxf(0.10, 0.70 - ratio * 0.60)

func _on_level_changed(new_level: int) -> void:
	_level = new_level
