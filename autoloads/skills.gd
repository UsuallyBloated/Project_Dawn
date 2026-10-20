extends Node

signal skill_used(skill: SkillData)
signal skill_cooldown_updated(skill_name: String, remaining: float, total: float)
signal skills_changed

var _all_skills: Dictionary = {}
var _cooldowns: CooldownTracker
var available: Array[SkillData] = []
var no_cooldowns: bool = false

# The last skill sent to the server and when: a SkillFail for it arriving
# within REFUSAL_WINDOW_MSEC means that use never happened, so the cooldown
# drawn for it is cleared (the spell bar's rule, spells.gd).
const REFUSAL_WINDOW_MSEC := 1500
var _sent_skill_name: String = ""
var _sent_at_msec: int = 0

func _ready() -> void:
	SkillDefinitions.validate()
	_cooldowns = CooldownTracker.new()
	_cooldowns.cooldown_updated.connect(func(n, r, t): skill_cooldown_updated.emit(n, r, t))
	_load_skills()
	PlayerStats.level_changed.connect(_on_level_changed)
	Alignment.alignment_changed.connect(_on_alignment_changed)
	# Deferred: Net is a later autoload than Skills, so it does not exist yet
	# while this _ready runs.
	(func() -> void: Net.world_skill_fail.connect(_on_server_skill_refused)).call_deferred()

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
	if _cooldowns.is_active(skill.skill_name) and not no_cooldowns:
		return false
	if PlayerStats.stamina < skill.stamina_cost:
		return false
	if skill.target_type == SkillData.TargetType.ENEMY:
		if not Combat.has_valid_target():
			return false
	# Online the server owns the skill (client-authority audit item 6): the
	# stamina, the cooldown, the swing times the multiplier, and the effect.
	# The checks above are an honest pre-flight; the cooldown below is drawn
	# optimistically and handed back on a SkillFail (the server stamped none).
	if Net.is_launcher_mode():
		return _use_skill_online(skill)

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

# The online path: send the skill by name and let the server answer. The
# server's Hit / Miss / StaminaUpdate / BuffSnapshot show the outcome; a
# SkillFail inside REFUSAL_WINDOW_MSEC hands the cooldown back.
func _use_skill_online(skill: SkillData) -> bool:
	var target_id := 0
	if skill.target_type == SkillData.TargetType.ENEMY:
		var t: Node = Combat.current_target
		if t is RemoteEnemy:
			target_id = (t as RemoteEnemy).enemy_id
		elif t is RemotePlayer:
			target_id = (t as RemotePlayer).char_id
		elif t is RemotePet:
			target_id = (t as RemotePet).pet_id
		if target_id == 0:
			return false
	if not Net.use_skill(skill.skill_name, target_id):
		CombatLog.add_line("%s isn't available online yet." % skill.skill_name, CombatLog.MsgType.INFO)
		return false
	_cooldowns.start(skill.skill_name, skill.cooldown)
	_sent_skill_name = skill.skill_name
	_sent_at_msec = Time.get_ticks_msec()
	if skill.target_type == SkillData.TargetType.ENEMY:
		BuffManager.break_stealth()
	skill_used.emit(skill)
	return true

func _on_server_skill_refused(skill_name: String, reason: String) -> void:
	if reason != "":
		CombatLog.add_line(reason, CombatLog.MsgType.INFO)
	if skill_name == _sent_skill_name and Time.get_ticks_msec() - _sent_at_msec <= REFUSAL_WINDOW_MSEC:
		_cooldowns.clear(skill_name)
	_sent_skill_name = ""

func get_skill_by_name(skill_name: String) -> SkillData:
	return _all_skills.get(skill_name)

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
