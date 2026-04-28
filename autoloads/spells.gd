extends Node

signal spell_cast(spell: SpellData)
signal spell_failed(reason: String)
signal spell_cooldown_updated(spell_name: String, remaining: float, total: float)
signal casting_started(spell: SpellData)
signal casting_cancelled

var _all_spells: Dictionary = {}
var _cooldowns: CooldownTracker
var available: Array[SpellData] = []

var _casting: SpellData = null
var _cast_timer: float = 0.0

func _ready() -> void:
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

func setup_for_class(player_class: String) -> void:
	var effective := _get_effective_class(player_class)
	available.clear()
	for sname in _all_spells:
		var spell: SpellData = _all_spells[sname]
		if spell.allowed_classes.is_empty() or effective in spell.allowed_classes:
			available.append(spell)
	available.sort_custom(func(a, b): return a.spell_name < b.spell_name)

func _get_effective_class(player_class: String) -> String:
	var tier := PlayerStats.alignment_tier
	match player_class:
		"Paladin":
			if tier == "Evil":
				return "Paladin_Fallen"
		"Shadow Knight":
			if tier == "Exalted":
				return "Shadow Knight_Redeemed"
	return player_class

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

	PlayerStats.set_mp(PlayerStats.mp - spell.mana_cost)

	if spell.cast_time > 0.0:
		_casting = spell
		_cast_timer = spell.cast_time
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
	casting_cancelled.emit()

func is_on_cooldown(spell_name: String) -> bool:
	return _cooldowns.is_active(spell_name)

func get_cooldown_remaining(spell_name: String) -> float:
	return _cooldowns.get_remaining(spell_name)

func _finish_cast() -> void:
	var spell := _casting
	_casting = null
	_cast_timer = 0.0
	_apply_spell(spell)

func _apply_spell(spell: SpellData) -> void:
	_cooldowns.start(spell.spell_name, spell.cooldown)
	var effectiveness := _get_alignment_effectiveness(PlayerStats.player_class)

	if spell.target_type == SpellData.TargetType.ENEMY:
		Combat.deal_damage_to_target(int((spell.base_damage + PlayerStats.intelligence * 0.5) * effectiveness))

	if spell.heal_amount > 0.0:
		var heal := (spell.heal_amount + PlayerStats.wisdom * 0.3) * effectiveness
		PlayerStats.set_hp(PlayerStats.hp + heal)

	if spell.hp_cost > 0.0:
		PlayerStats.set_hp(PlayerStats.hp - spell.hp_cost)

	spell_cast.emit(spell)

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
		"ENEMY": return SpellData.TargetType.ENEMY
		"SELF":  return SpellData.TargetType.SELF
	return SpellData.TargetType.NONE
