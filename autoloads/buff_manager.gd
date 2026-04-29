extends Node

const TICK_INTERVAL := 3.0

var _absorb_hp: float = 0.0
var _evade_boost_remaining: float = 0.0

# {target, dps, remaining, spell_name, tick_acc}
var _dots: Array = []
# {hps, remaining, spell_name, tick_acc}
var _hots: Array = []

func _ready() -> void:
	PlayerDeath.player_died.connect(clear_all)
	ZoneLoader.zone_changed.connect(func(_z): clear_all())

func add_dot(target, dps: float, duration: float, spell_name: String) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
	for d in _dots:
		if d.target == target and d.spell_name == spell_name:
			d.remaining = duration
			d.tick_acc = 0.0
			return
	_dots.append({target = target, dps = dps, remaining = duration,
		spell_name = spell_name, tick_acc = 0.0})
	CombatLog.add_line("%s is afflicted by %s." % [target.mob_name, spell_name],
		CombatLog.MsgType.DAMAGE_OUT)

func add_hot(hps: float, duration: float, spell_name: String) -> void:
	for h in _hots:
		if h.spell_name == spell_name:
			h.remaining = duration
			h.tick_acc = 0.0
			return
	_hots.append({hps = hps, remaining = duration, spell_name = spell_name, tick_acc = 0.0})
	CombatLog.add_line("You feel the effects of %s." % spell_name, CombatLog.MsgType.HEAL)

func add_absorb(amount: float, source_name: String) -> void:
	_absorb_hp += amount
	CombatLog.add_line(
		"A %s shield forms around you. (%d HP)" % [source_name, int(_absorb_hp)],
		CombatLog.MsgType.HEAL)

func consume_absorb(damage: int) -> int:
	if _absorb_hp <= 0.0:
		return damage
	var absorbed := minf(_absorb_hp, float(damage))
	_absorb_hp -= absorbed
	var remaining := damage - int(absorbed)
	if _absorb_hp <= 0.0:
		CombatLog.add_line("Your shield has been destroyed!", CombatLog.MsgType.DAMAGE_IN)
	else:
		CombatLog.add_line("Your shield absorbs %d damage. (%d remaining)" % [int(absorbed), int(_absorb_hp)],
			CombatLog.MsgType.HEAL)
	return remaining

func add_evade_boost(duration: float) -> void:
	_evade_boost_remaining = duration
	CombatLog.add_line("You slip into a defensive stance.", CombatLog.MsgType.INFO)

func is_evade_boosted() -> bool:
	return _evade_boost_remaining > 0.0

func clear_all() -> void:
	_dots.clear()
	_hots.clear()
	_absorb_hp = 0.0
	_evade_boost_remaining = 0.0

func _process(delta: float) -> void:
	if _evade_boost_remaining > 0.0:
		_evade_boost_remaining -= delta
	_tick_dots(delta)
	_tick_hots(delta)

func _tick_dots(delta: float) -> void:
	var i := _dots.size() - 1
	while i >= 0:
		var d: Dictionary = _dots[i]
		if not is_instance_valid(d.target) or d.target.is_dead:
			_dots.remove_at(i)
			i -= 1
			continue
		d.remaining -= delta
		d.tick_acc += delta
		if d.tick_acc >= TICK_INTERVAL:
			d.tick_acc -= TICK_INTERVAL
			var dmg := int(d.dps * TICK_INTERVAL)
			d.target.take_damage(dmg)
			if is_instance_valid(d.target) and not d.target.is_dead:
				CombatLog.add_line("%s takes %d from %s." % [d.target.mob_name, dmg, d.spell_name],
					CombatLog.MsgType.DAMAGE_OUT)
		if d.remaining <= 0.0:
			_dots.remove_at(i)
		i -= 1

func _tick_hots(delta: float) -> void:
	var i := _hots.size() - 1
	while i >= 0:
		var h: Dictionary = _hots[i]
		h.remaining -= delta
		h.tick_acc += delta
		if h.tick_acc >= TICK_INTERVAL:
			h.tick_acc -= TICK_INTERVAL
			var heal: float = h.hps * TICK_INTERVAL
			PlayerStats.set_hp(PlayerStats.hp + heal)
			CombatLog.add_line("You recover %d health from %s." % [int(heal), h.spell_name],
				CombatLog.MsgType.HEAL)
		if h.remaining <= 0.0:
			_hots.remove_at(i)
		i -= 1
