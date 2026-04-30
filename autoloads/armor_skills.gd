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
	for skill in ArmorSkillDefinitions.ALL:
		_skills[skill] = ArmorSkillDefinitions.get_starting_value(player_class, skill)

func try_advance(skill_name: String) -> void:
	if _player_class == "" or not _skills.has(skill_name):
		return
	var current: int = _skills[skill_name]
	var cap: int = ArmorSkillDefinitions.get_cap(_player_class, skill_name, _level)
	if cap == 0 or current >= cap:
		return
	var advance_chance := 0.2 * (1.0 - float(current) / float(cap))
	if randf() < advance_chance:
		_skills[skill_name] = current + 1
		skill_advanced.emit(skill_name, _skills[skill_name], cap)

# Called when the player takes a hit. Advances skill for each unique armor type worn.
func try_advance_worn(equipped: Dictionary) -> void:
	var seen: Dictionary = {}
	for slot in equipped:
		var item = equipped[slot]
		if item == null or item.armor_type == "":
			continue
		if seen.has(item.armor_type):
			continue
		seen[item.armor_type] = true
		try_advance(item.armor_type)

func get_current(skill_name: String) -> int:
	return _skills.get(skill_name, 0)

func get_cap(skill_name: String) -> int:
	return ArmorSkillDefinitions.get_cap(_player_class, skill_name, _level)

# Returns the effective armor multiplier for a given armor type.
# cap=0 (wrong armor type): 0.5x. Trained: 1.0–1.25x scaling with skill.
func get_armor_multiplier(armor_type: String) -> float:
	if _player_class == "":
		return 1.0
	var cap := get_cap(armor_type)
	if cap == 0:
		return 0.5
	var current := get_current(armor_type)
	return 1.0 + 0.25 * float(current) / float(cap)

# Returns total effective armor from all equipped pieces, modified by armor skill.
func get_effective_armor(equipped: Dictionary) -> int:
	var total := 0
	for slot in equipped:
		var item = equipped[slot]
		if item == null or item.bonus_armor <= 0:
			continue
		var mult := get_armor_multiplier(item.armor_type)
		total += int(item.bonus_armor * mult)
	return total

func _on_level_changed(new_level: int) -> void:
	_level = new_level
