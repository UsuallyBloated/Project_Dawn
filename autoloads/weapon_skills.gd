extends PassiveSkillTracker

func initialize(player_class: String, level: int) -> void:
	_player_class = player_class
	_level = level
	_skills.clear()
	for skill in WeaponSkillDefinitions.ALL:
		_skills[skill] = WeaponSkillDefinitions.get_starting_value(player_class, skill)

func get_cap(skill_name: String) -> int:
	return WeaponSkillDefinitions.get_cap(_player_class, skill_name, _level)

# 0.05–0.35 miss chance scaling from skill vs cap. Unusable weapon type = 80% miss.
func get_miss_chance(skill_name: String) -> float:
	if _player_class == "":
		return 0.0
	var cap := get_cap(skill_name)
	if cap == 0:
		return 0.80
	var current := get_current(skill_name)
	return maxf(0.05, 0.35 * (1.0 - float(current) / float(cap)))

# 1.0–1.15 damage multiplier from skill proficiency. Unusable weapon type = 0.5x.
func get_damage_multiplier(skill_name: String) -> float:
	if _player_class == "":
		return 1.0
	var cap := get_cap(skill_name)
	if cap == 0:
		return 0.5
	var current := get_current(skill_name)
	return 1.0 + 0.15 * float(current) / float(cap)
