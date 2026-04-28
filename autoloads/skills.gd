extends Node

signal skill_used(skill: SkillData)
signal skill_cooldown_updated(skill_name: String, remaining: float, total: float)

# Registry of all skills by name
var _all_skills: Dictionary = {}
var _cooldowns: Dictionary = {}
var available: Array[SkillData] = []
var _finished_keys: Array[String] = []

func _ready() -> void:
	_register_defaults()
	PlayerStats.level_changed.connect(_on_level_changed)

func _process(delta: float) -> void:
	_finished_keys.clear()
	for sname in _cooldowns:
		_cooldowns[sname] -= delta
		skill_cooldown_updated.emit(sname, maxf(_cooldowns[sname], 0.0), _get_skill(sname).cooldown)
		if _cooldowns[sname] <= 0.0:
			_finished_keys.append(sname)
	for sname in _finished_keys:
		_cooldowns.erase(sname)

func setup_for_class(player_class: String) -> void:
	available.clear()
	for sname in _all_skills:
		var skill: SkillData = _all_skills[sname]
		if skill.allowed_classes.is_empty() or player_class in skill.allowed_classes:
			available.append(skill)
	available.sort_custom(func(a, b): return a.skill_name < b.skill_name)

func use_skill(skill: SkillData) -> bool:
	if is_on_cooldown(skill.skill_name):
		return false
	if PlayerStats.stamina < skill.stamina_cost:
		return false
	if skill.target_type == SkillData.TargetType.ENEMY:
		if Combat.current_target == null or not is_instance_valid(Combat.current_target):
			return false
		if Combat.current_target.is_dead:
			return false

	PlayerStats.set_stamina(PlayerStats.stamina - skill.stamina_cost)
	_cooldowns[skill.skill_name] = skill.cooldown
	skill_cooldown_updated.emit(skill.skill_name, skill.cooldown, skill.cooldown)

	if skill.target_type == SkillData.TargetType.ENEMY:
		var dmg := int(Combat.calc_damage() * skill.damage_multiplier)
		Combat.current_target.take_damage(dmg)
		CombatLog.add_damage_out(Combat.current_target.mob_name, dmg)

	skill_used.emit(skill)
	return true

func use_skill_by_index(index: int) -> bool:
	if index < 0 or index >= available.size():
		return false
	return use_skill(available[index])

func is_on_cooldown(skill_name: String) -> bool:
	return _cooldowns.has(skill_name)

func get_cooldown_remaining(skill_name: String) -> float:
	return _cooldowns.get(skill_name, 0.0)

func _get_skill(skill_name: String) -> SkillData:
	return _all_skills.get(skill_name)

func _on_level_changed(_level: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _register_defaults() -> void:
	_register(_make_skill(
		"Slash", "A quick slashing strike.", 3.0, 8.0, 1.5, ["Warrior", "Rogue"]
	))
	_register(_make_skill(
		"Shield Bash", "Stuns and damages with your shield.", 8.0, 15.0, 1.2, ["Warrior"]
	))
	_register(_make_skill(
		"Backstab", "A devastating blow from the shadows.", 6.0, 20.0, 3.0, ["Rogue"]
	))
	_register(_make_skill(
		"Evade", "Grants a burst of agility.", 12.0, 10.0, 0.0, ["Rogue"]
	))
	_register(_make_skill(
		"Pummel", "A rapid series of blows.", 5.0, 12.0, 1.0, ["Warrior"]
	))

func _make_skill(
	sname: String, desc: String, cd: float, st_cost: float,
	dmg_mult: float, classes: Array
) -> SkillData:
	var s := SkillData.new()
	s.skill_name = sname
	s.description = desc
	s.cooldown = cd
	s.stamina_cost = st_cost
	s.damage_multiplier = dmg_mult
	s.target_type = SkillData.TargetType.ENEMY if dmg_mult > 0.0 else SkillData.TargetType.SELF
	for c in classes:
		s.allowed_classes.append(c)
	return s

func _register(skill: SkillData) -> void:
	_all_skills[skill.skill_name] = skill
