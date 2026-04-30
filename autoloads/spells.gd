extends Node

signal spell_cast(spell: SpellData)
signal spell_failed(reason: String)
signal spell_cooldown_updated(spell_name: String, remaining: float, total: float)
signal casting_started(spell: SpellData)
signal casting_cancelled
signal spells_changed

var _all_spells: Dictionary = {}
var _cooldowns: CooldownTracker
var available: Array[SpellData] = []

var _casting: SpellData = null
var _cast_timer: float = 0.0
var _hit_during_cast: bool = false

func _ready() -> void:
	SpellDefinitions.validate()
	_cooldowns = CooldownTracker.new()
	_cooldowns.cooldown_updated.connect(func(n, r, t): spell_cooldown_updated.emit(n, r, t))
	_load_spells()
	PlayerStats.level_changed.connect(_on_level_changed)
	PlayerStats.alignment_changed.connect(_on_alignment_changed)

func _process(delta: float) -> void:
	if _casting != null:
		_cast_timer -= delta
		if _cast_timer <= 0.0:
			_finish_cast()
	_cooldowns.tick(delta)

func setup_for_class(_player_class: String) -> void:
	var effective := PlayerStats.get_effective_class()
	available.clear()
	for sname in _all_spells:
		var spell: SpellData = _all_spells[sname]
		if spell.allowed_classes.is_empty() or effective in spell.allowed_classes:
			available.append(spell)
	available.sort_custom(func(a, b): return a.spell_name < b.spell_name)
	spells_changed.emit()

func _get_alignment_effectiveness(player_class: String) -> float:
	var tier := PlayerStats.alignment_tier
	match player_class:
		"Paladin":
			match tier:
				"Neutral": return 0.7
				"Bad":     return 0.4
		"Shadow Knight":
			match tier:
				"Neutral": return 0.7
				"Good":    return 0.4
	return 1.0

func cast_spell(spell: SpellData) -> bool:
	if _casting != null:
		return false
	if _cooldowns.is_active(spell.spell_name):
		spell_failed.emit("Spell is on cooldown.")
		return false
	if PlayerStats.mp < spell.mana_cost:
		spell_failed.emit("Not enough mana.")
		return false
	if spell.target_type == SpellData.TargetType.ENEMY:
		if not Combat.has_valid_target():
			spell_failed.emit("No valid target.")
			return false
	if spell.target_type == SpellData.TargetType.PET_CHARM:
		if not Combat.has_valid_target():
			spell_failed.emit("No valid target to charm.")
			return false

	if spell.target_type == SpellData.TargetType.PORT:
		var is_gate        := spell.port_zone_path.is_empty() and spell.port_entry_id.is_empty()
		var is_same_zone   := spell.port_zone_path.is_empty() and not spell.port_entry_id.is_empty()
		if is_gate and PlayerStats.bind_zone_path.is_empty():
			spell_failed.emit("You have no bind point. Cast Bind Affinity first.")
			return false
		if is_same_zone and ZoneLoader.current_zone_path.is_empty():
			spell_failed.emit("Cannot port — no zone loaded.")
			return false
		if not spell.port_zone_path.is_empty() and not FileAccess.file_exists(spell.port_zone_path):
			spell_failed.emit("That destination has not yet been discovered.")
			return false

	if spell.target_type == SpellData.TargetType.BIND:
		if ZoneLoader.current_zone_path.is_empty():
			spell_failed.emit("You cannot bind here.")
			return false
		if ZoneLoader.current_zone_path in ZoneData.NON_BINDABLE_ZONES:
			spell_failed.emit("The magic will not anchor here.")
			return false

	PlayerStats.set_mp(PlayerStats.mp - spell.mana_cost)

	if spell.cast_time > 0.0:
		_casting = spell
		_cast_timer = spell.cast_time
		_hit_during_cast = false
		casting_started.emit(spell)
	else:
		_apply_spell(spell)
	return true

func cast_by_index(index: int) -> bool:
	if index < 0 or index >= available.size():
		return false
	return cast_spell(available[index])

func cancel_cast() -> void:
	if _casting == null:
		return
	_casting = null
	_cast_timer = 0.0
	_hit_during_cast = false
	casting_cancelled.emit()

# Called by combat when the player takes a hit during a cast.
# Uses Channeling skill to determine whether the cast is interrupted or survives.
func try_interrupt_cast() -> void:
	if _casting == null:
		return
	if randf() < CastingSkills.get_interrupt_chance():
		cancel_cast()
	else:
		_hit_during_cast = true

func is_on_cooldown(spell_name: String) -> bool:
	return _cooldowns.is_active(spell_name)

func get_cooldown_remaining(spell_name: String) -> float:
	return _cooldowns.get_remaining(spell_name)

func _finish_cast() -> void:
	var spell := _casting
	var was_hit := _hit_during_cast
	_casting = null
	_cast_timer = 0.0
	_hit_during_cast = false
	if was_hit:
		CastingSkills.try_advance("channeling")
	_apply_spell(spell)

func _apply_spell(spell: SpellData) -> void:
	_cooldowns.start(spell.spell_name, spell.cooldown)
	var effectiveness := _get_alignment_effectiveness(PlayerStats.player_class)
	var dmg_mult    := CastingSkills.get_damage_mult(spell.discipline)
	var dur_mult    := CastingSkills.get_duration_mult(spell.discipline)
	var absorb_mult := CastingSkills.get_absorb_mult(spell.discipline)

	if spell.target_type == SpellData.TargetType.ENEMY:
		Combat.deal_damage_to_target(int((spell.base_damage + PlayerStats.intelligence * 0.5) * effectiveness * dmg_mult))

	if spell.target_type == SpellData.TargetType.PET_SUMMON:
		PetManager.summon(spell.pet_type)

	if spell.target_type == SpellData.TargetType.PET_CHARM:
		PetManager.charm_current_target(spell.duration)

	if spell.target_type == SpellData.TargetType.PET_HEAL:
		PetManager.heal_warder(spell.heal_amount + PlayerStats.wisdom * 0.3)

	if spell.heal_amount > 0.0 and spell.target_type != SpellData.TargetType.PET_HEAL:
		var heal := (spell.heal_amount + PlayerStats.wisdom * 0.3) * effectiveness
		PlayerStats.set_hp(PlayerStats.hp + heal)

	if spell.hp_cost > 0.0:
		PlayerStats.set_hp(PlayerStats.hp - spell.hp_cost)

	if spell.dot_dps > 0.0 and spell.dot_duration > 0.0:
		if spell.target_type == SpellData.TargetType.ENEMY and Combat.has_valid_target():
			BuffManager.add_dot(Combat.current_target, spell.dot_dps * effectiveness,
				spell.dot_duration * dur_mult, spell.spell_name)

	if spell.hot_hps > 0.0 and spell.hot_duration > 0.0:
		BuffManager.add_hot(spell.hot_hps * effectiveness, spell.hot_duration * dur_mult, spell.spell_name)

	if spell.absorb_amount > 0.0:
		BuffManager.add_absorb(spell.absorb_amount * effectiveness * absorb_mult, spell.spell_name)

	if spell.cc_duration > 0.0:
		if spell.target_type == SpellData.TargetType.ENEMY and Combat.has_valid_target():
			Combat.current_target.mesmerize(spell.cc_duration * dur_mult)

	if spell.target_type == SpellData.TargetType.PORT:
		_execute_port(spell)

	if spell.target_type == SpellData.TargetType.BIND:
		_execute_bind()

	if spell.discipline != "":
		CastingSkills.try_advance(spell.discipline)

	spell_cast.emit(spell)

func _execute_bind() -> void:
	var zone_path := ZoneLoader.current_zone_path
	if zone_path.is_empty():
		spell_failed.emit("You cannot bind here.")
		return
	if zone_path in ZoneData.NON_BINDABLE_ZONES:
		spell_failed.emit("The magic will not anchor here.")
		return
	# TODO: when multiplayer RPC is wired, check GroupManager for a valid grouped
	# player target and call set_bind_point on them via RPC instead.
	PlayerStats.set_bind_point(zone_path, "default", ZoneLoader.current_zone_name)
	CombatLog.add_line("You are now bound to %s." % ZoneLoader.current_zone_name, CombatLog.MsgType.INFO)

func _execute_port(spell: SpellData) -> void:
	var zone_path := spell.port_zone_path
	var entry_id  := spell.port_entry_id
	var zone_name := spell.port_zone_name

	if zone_path.is_empty() and entry_id.is_empty():
		zone_path = PlayerStats.bind_zone_path
		entry_id  = PlayerStats.bind_entry_id
		zone_name = PlayerStats.bind_zone_name
	elif zone_path.is_empty():
		zone_path = ZoneLoader.current_zone_path
		zone_name = ZoneLoader.current_zone_name

	if zone_path.is_empty():
		spell_failed.emit("No destination zone available.")
		return

	if spell.port_is_group and GroupManager.in_group:
		CombatLog.add_line("Porting group — multiplayer RPC not yet wired.", CombatLog.MsgType.INFO)

	ZoneLoader.travel_to(zone_path, entry_id, zone_name)

func _on_level_changed(_level: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _on_alignment_changed(_tier: String, _score: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _load_spells() -> void:
	for d in SpellDefinitions.ALL:
		var s := SpellData.new()
		s.spell_name = d["name"]
		s.description = d["desc"]
		s.mana_cost = d["mana_cost"]
		s.cast_time = d["cast_time"]
		s.cooldown = d["cooldown"]
		s.base_damage = d["base_damage"]
		s.damage_type = _parse_damage_type(d["damage_type"])
		s.target_type = _parse_target_type(d["target_type"])
		s.heal_amount = d["heal_amount"]
		s.hp_cost = d.get("hp_cost", 0.0)
		s.duration = d.get("duration", 0.0)
		s.pet_type = d.get("pet_type", "")
		s.dot_dps = d.get("dot_dps", 0.0)
		s.dot_duration = d.get("dot_duration", 0.0)
		s.hot_hps = d.get("hot_hps", 0.0)
		s.hot_duration = d.get("hot_duration", 0.0)
		s.absorb_amount = d.get("absorb_amount", 0.0)
		s.cc_duration    = d.get("cc_duration", 0.0)
		s.port_zone_path = d.get("port_zone_path", "")
		s.port_entry_id  = d.get("port_entry_id", "")
		s.port_zone_name = d.get("port_zone_name", "")
		s.port_is_group  = d.get("port_is_group", false)
		s.discipline = SpellDefinitions.DISCIPLINE.get(d["name"], "")
		for c in d["classes"]:
			s.allowed_classes.append(c)
		_all_spells[s.spell_name] = s

func _parse_damage_type(s: String) -> SpellData.DamageType:
	match s:
		"FIRE":      return SpellData.DamageType.FIRE
		"ICE":       return SpellData.DamageType.ICE
		"LIGHTNING": return SpellData.DamageType.LIGHTNING
		"ARCANE":    return SpellData.DamageType.ARCANE
		"HOLY":      return SpellData.DamageType.HOLY
		"NATURE":    return SpellData.DamageType.NATURE
		"SPIRIT":    return SpellData.DamageType.SPIRIT
		"SHADOW":    return SpellData.DamageType.SHADOW
	return SpellData.DamageType.NONE

func _parse_target_type(s: String) -> SpellData.TargetType:
	match s:
		"ENEMY":      return SpellData.TargetType.ENEMY
		"SELF":       return SpellData.TargetType.SELF
		"PET_SUMMON": return SpellData.TargetType.PET_SUMMON
		"PET_CHARM":  return SpellData.TargetType.PET_CHARM
		"PET_HEAL":   return SpellData.TargetType.PET_HEAL
		"PORT":       return SpellData.TargetType.PORT
		"BIND":       return SpellData.TargetType.BIND
	return SpellData.TargetType.NONE
