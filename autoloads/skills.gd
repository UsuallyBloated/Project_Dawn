extends Node

signal skill_used(skill: SkillData)
signal skill_cooldown_updated(skill_name: String, remaining: float, total: float)
signal skills_changed

var _all_skills: Dictionary = {}
var _cooldowns: CooldownTracker
var available: Array[SkillData] = []
var no_cooldowns: bool = false

func _ready() -> void:
	SkillDefinitions.validate()
	_cooldowns = CooldownTracker.new()
	_cooldowns.cooldown_updated.connect(func(n, r, t): skill_cooldown_updated.emit(n, r, t))
	_load_skills()
	PlayerStats.level_changed.connect(_on_level_changed)
	Alignment.alignment_changed.connect(_on_alignment_changed)

func _process(delta: float) -> void:
	_cooldowns.tick(delta)

func setup_for_class(_player_class: String) -> void:
	var effective := Alignment.get_effective_class()
	available.clear()
	for sname in _all_skills:
		var skill: SkillData = _all_skills[sname]
		if skill.allowed_classes.is_empty() or effective in skill.allowed_classes:
			available.append(skill)
	available.sort_custom(func(a, b): return a.skill_name < b.skill_name)
	# Diagnostic (2026-08-26): a live session reported the Assign Skill menu
	# empty while the same build populates correctly headless. This line makes
	# the population visible in the debug console so the next report carries
	# the class string and count instead of a mystery.
	DebugLog.info("Skills: %d available for class '%s' (effective '%s')" % [
		available.size(), _player_class, effective])
	skills_changed.emit()

func use_skill(skill: SkillData) -> bool:
	if Combat.is_player_seated():
		CombatLog.add_line("You cannot use skills while sitting.", CombatLog.MsgType.INFO)
		return false
	# Effects the server cannot honor yet refuse honestly ONLINE, before any
	# stamina or cooldown is paid. Found by the 2026-08-24 dead-intents audit:
	# STUN and FEIGN_DEATH called methods that exist only on the local Enemy
	# (which launcher mode never spawns), aborting with a silent runtime error
	# AFTER the cost was spent; EVADE/ABSORB/STEALTH "worked" but were pure
	# decoration, consumed only by receive_player_damage, which server-dealt
	# damage never calls. An honest refusal beats a placebo — the tradeskill
	# rule. Pure damage skills (Backstab etc.) stay usable: they land as normal
	# server swings (the discarded multiplier is server work, tracked).
	if Net.is_launcher_mode():
		match skill.effect_type:
			SkillData.EffectType.STUN, SkillData.EffectType.FEIGN_DEATH, 			SkillData.EffectType.EVADE_BOOST, SkillData.EffectType.ABSORB_SHIELD, 			SkillData.EffectType.STEALTH:
				CombatLog.add_line(
					"%s isn't available online yet." % skill.skill_name,
					CombatLog.MsgType.INFO)
				return false
			_:
				pass
	if _cooldowns.is_active(skill.skill_name) and not no_cooldowns:
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

	match skill.effect_type:
		SkillData.EffectType.EVADE_BOOST:
			BuffManager.add_evade_boost(skill.effect_duration)
		SkillData.EffectType.ABSORB_SHIELD:
			BuffManager.add_absorb(skill.absorb_amount, skill.skill_name)
		SkillData.EffectType.WARDER_FURY:
			WarderAI.command_fury()
		SkillData.EffectType.STUN:
			if Combat.has_valid_target():
				Combat.current_target.stun(skill.stun_duration)
		SkillData.EffectType.FEIGN_DEATH:
			_do_feign_death()
		SkillData.EffectType.STEALTH:
			BuffManager.add_stealth(skill.stealth_duration, skill.skill_name)
		SkillData.EffectType.TRUESIGHT:
			pass  # damage already applied by the target_type == ENEMY block above

	if skill.target_type == SkillData.TargetType.ENEMY:
		BuffManager.break_stealth()

	skill_used.emit(skill)
	return true

func _do_feign_death() -> void:
	var success_chance := 0.80
	if randf() < success_chance:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and not enemy.is_dead:
				enemy.feign_death_deaggro()
		CombatLog.add_line("You feign death successfully.", CombatLog.MsgType.INFO)
	else:
		CombatLog.add_line("Your feign death fails!", CombatLog.MsgType.DAMAGE_IN)

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
		s.effect_duration = d.get("effect_duration", 0.0)
		s.absorb_amount = d.get("absorb_amount", 0.0)
		s.stun_duration = d.get("stun_duration", 0.0)
		s.stealth_duration = d.get("stealth_duration", 0.0)
		match d.get("effect_type", ""):
			"EVADE_BOOST":   s.effect_type = SkillData.EffectType.EVADE_BOOST
			"ABSORB_SHIELD": s.effect_type = SkillData.EffectType.ABSORB_SHIELD
			"WARDER_FURY":   s.effect_type = SkillData.EffectType.WARDER_FURY
			"STUN":          s.effect_type = SkillData.EffectType.STUN
			"FEIGN_DEATH":   s.effect_type = SkillData.EffectType.FEIGN_DEATH
			"STEALTH":       s.effect_type = SkillData.EffectType.STEALTH
			"TRUESIGHT":     s.effect_type = SkillData.EffectType.TRUESIGHT
			_:               s.effect_type = SkillData.EffectType.NONE
		for c in d["classes"]:
			s.allowed_classes.append(c)
		_all_skills[s.skill_name] = s
