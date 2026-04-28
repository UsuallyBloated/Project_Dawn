extends Node

signal spell_cast(spell: SpellData)
signal spell_failed(reason: String)
signal spell_cooldown_updated(spell_name: String, remaining: float, total: float)
signal casting_started(spell: SpellData)
signal casting_cancelled

var _all_spells: Dictionary = {}
var _cooldowns: Dictionary = {}
var available: Array[SpellData] = []
var _finished_keys: Array[String] = []

var _casting: SpellData = null
var _cast_timer: float = 0.0

func _ready() -> void:
	_register_defaults()
	PlayerStats.level_changed.connect(_on_level_changed)

func _process(delta: float) -> void:
	if _casting != null:
		_cast_timer -= delta
		if _cast_timer <= 0.0:
			_finish_cast()

	_finished_keys.clear()
	for sname in _cooldowns:
		_cooldowns[sname] -= delta
		var sp: SpellData = _all_spells.get(sname)
		if sp:
			spell_cooldown_updated.emit(sname, maxf(_cooldowns[sname], 0.0), sp.cooldown)
		if _cooldowns[sname] <= 0.0:
			_finished_keys.append(sname)
	for sname in _finished_keys:
		_cooldowns.erase(sname)

func setup_for_class(player_class: String) -> void:
	available.clear()
	for sname in _all_spells:
		var spell: SpellData = _all_spells[sname]
		if spell.allowed_classes.is_empty() or player_class in spell.allowed_classes:
			available.append(spell)
	available.sort_custom(func(a, b): return a.spell_name < b.spell_name)

func cast_spell(spell: SpellData) -> bool:
	if _casting != null:
		return false
	if is_on_cooldown(spell.spell_name):
		spell_failed.emit("Spell is on cooldown.")
		return false
	if PlayerStats.mp < spell.mana_cost:
		spell_failed.emit("Not enough mana.")
		return false
	if spell.target_type == SpellData.TargetType.ENEMY:
		if Combat.current_target == null or not is_instance_valid(Combat.current_target):
			spell_failed.emit("No target.")
			return false
		if Combat.current_target.is_dead:
			spell_failed.emit("Target is dead.")
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
	return _cooldowns.has(spell_name)

func get_cooldown_remaining(spell_name: String) -> float:
	return _cooldowns.get(spell_name, 0.0)

func _finish_cast() -> void:
	var spell := _casting
	_casting = null
	_cast_timer = 0.0
	_apply_spell(spell)

func _apply_spell(spell: SpellData) -> void:
	_cooldowns[spell.spell_name] = spell.cooldown

	if spell.target_type == SpellData.TargetType.ENEMY and Combat.current_target != null:
		var dmg := int(spell.base_damage + PlayerStats.intelligence * 0.5)
		Combat.current_target.take_damage(dmg)
		CombatLog.add_damage_out(Combat.current_target.mob_name, dmg)

	if spell.heal_amount > 0.0:
		var heal := spell.heal_amount + PlayerStats.wisdom * 0.3
		PlayerStats.set_hp(PlayerStats.hp + heal)

	spell_cast.emit(spell)

func _on_level_changed(_level: int) -> void:
	setup_for_class(PlayerStats.player_class)

func _register_defaults() -> void:
	_register(_make_spell(
		"Fireball", "Hurls a ball of flame at the target.",
		30.0, 1.5, 8.0, 50.0, SpellData.DamageType.FIRE, SpellData.TargetType.ENEMY, 0.0, ["Mage"]
	))
	_register(_make_spell(
		"Frost Bolt", "A bolt of freezing ice.",
		20.0, 0.0, 4.0, 30.0, SpellData.DamageType.ICE, SpellData.TargetType.ENEMY, 0.0, ["Mage"]
	))
	_register(_make_spell(
		"Lightning Strike", "Calls down a bolt of lightning.",
		40.0, 2.0, 12.0, 80.0, SpellData.DamageType.LIGHTNING, SpellData.TargetType.ENEMY, 0.0, ["Mage"]
	))
	_register(_make_spell(
		"Heal", "Restores HP to yourself.",
		25.0, 1.0, 6.0, 0.0, SpellData.DamageType.NONE, SpellData.TargetType.SELF, 40.0, ["Mage"]
	))
	_register(_make_spell(
		"Arcane Missile", "Rapid arcane shots.",
		15.0, 0.0, 2.0, 20.0, SpellData.DamageType.ARCANE, SpellData.TargetType.ENEMY, 0.0, ["Mage"]
	))

func _make_spell(
	sname: String, desc: String,
	mana: float, cast_t: float, cd: float,
	base_dmg: float, dmg_type: SpellData.DamageType,
	tgt: SpellData.TargetType, heal: float, classes: Array
) -> SpellData:
	var s := SpellData.new()
	s.spell_name = sname
	s.description = desc
	s.mana_cost = mana
	s.cast_time = cast_t
	s.cooldown = cd
	s.base_damage = base_dmg
	s.damage_type = dmg_type
	s.target_type = tgt
	s.heal_amount = heal
	for c in classes:
		s.allowed_classes.append(c)
	return s

func _register(spell: SpellData) -> void:
	_all_spells[spell.spell_name] = spell
