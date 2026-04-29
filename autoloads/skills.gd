extends Node

signal skill_used(skill: SkillData)
signal skill_cooldown_updated(skill_name: String, remaining: float, total: float)

var _all_skills: Dictionary = {}
var _cooldowns: CooldownTracker
var available: Array[SkillData] = []

func _ready() -> void:
	SkillDefinitions.validate()
	_cooldowns = CooldownTracker.new()
	_cooldowns.cooldown_updated.connect(func(n, r, t): skill_cooldown_updated.emit(n, r, t))
	_load_skills()
	PlayerStats.level_changed.connect(_on_level_changed)
	PlayerStats.alignment_changed.connect(_on_alignment_changed)

func _process(delta: float) -> void:
	_cooldowns.tick(delta)

func setup_for_class(_player_class: String) -> void:
	var effective := PlayerStats.get_effective_class()
	available.clear()
	for sname in _all_skills:
		var skill: SkillData = _all_skills[sname]
		if skill.allowed_classes.is_empty() or effective in skill.allowed_classes:
			available.append(skill)
	available.sort_custom(func(a, b): return a.skill_name < b.skill_name)

func use_skill(skill: SkillData) -> bool:
	if _cooldowns.is_active(skill.skill_name):
		return false
	if PlayerStats.stamina < skill.stamina_cost:
		return false
	if skill.target_type == SkillData.TargetType.ENEMY:
		if not Combat.has_valid_target():
			return false

	PlayerStats.set_stamina(PlayerStats.stamina - skill.stamina_cost)
	_cooldowns.start(skill.skill_name, skill.cooldown)

	if skill.target_type == SkillData.TargetType.ENEMY:
		Combat.deal_damage_to_target(int(Combat.calc_damage() * skill.damage_multiplier))

	skill_used.emit(skill)
	return true

func use_skill_by_index(index: int) -> bool:
	if index < 0 or index >= available.size():
		return false
	return use_skill(available[index])

func is_on_cooldown(skill_name: String) -> bool:
	return _cooldowns.is_active(skill_name)

func get_cooldown_remaining(skill_name: String) -> float:
	return _cooldowns.get_remaining(skill_name)

func _on_level_changed(_level: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _on_alignment_changed(_tier: String, _score: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _load_skills() -> void:
	for d in SkillDefinitions.ALL:
		var s := SkillData.new()
		s.skill_name = d["name"]
		s.description = d["desc"]
		s.cooldown = d["cooldown"]
		s.stamina_cost = d["stamina_cost"]
		s.damage_multiplier = d["damage_multiplier"]
		s.target_type = SkillData.TargetType.ENEMY if d["damage_multiplier"] > 0.0 else SkillData.TargetType.SELF
		for c in d["classes"]:
			s.allowed_classes.append(c)
		_all_skills[s.skill_name] = s
