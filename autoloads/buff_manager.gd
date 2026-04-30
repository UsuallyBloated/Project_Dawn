extends Node

signal buffs_changed
signal dot_applied(target_name: String, spell_name: String)
signal hot_applied(spell_name: String)
signal absorb_applied(amount: int, spell_name: String)
signal absorb_damaged(absorbed: int, remaining: int)
signal absorb_broken
signal evade_boost_applied
signal dot_ticked(target_name: String, amount: int, spell_name: String)
signal hot_ticked(amount: int, spell_name: String)
signal food_buff_changed
signal drink_buff_changed

const TICK_INTERVAL := 3.0

var _absorb_hp: float = 0.0
var _is_hot_healing: bool = false
var _evade_boost_remaining: float = 0.0

# {target, dps, remaining, spell_name, tick_acc}
var _dots: Array = []
# {hps, remaining, spell_name, tick_acc}
var _hots: Array = []

# {hp_regen, mp_regen, remaining, buff_name}
var _food_buff: Dictionary = {}
var _drink_buff: Dictionary = {}

func _ready() -> void:
	PlayerDeath.player_died.connect(clear_all)
	ZoneLoader.zone_changed.connect(func(_z): clear_all())

func get_hots() -> Array:
	return _hots

func get_absorb_hp() -> float:
	return _absorb_hp

func get_evade_remaining() -> float:
	return _evade_boost_remaining

func is_hot_healing() -> bool:
	return _is_hot_healing

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
	dot_applied.emit(target.mob_name, spell_name)

func add_hot(hps: float, duration: float, spell_name: String) -> void:
	for h in _hots:
		if h.spell_name == spell_name:
			h.remaining = duration
			h.tick_acc = 0.0
			return
	_hots.append({hps = hps, remaining = duration, spell_name = spell_name, tick_acc = 0.0})
	hot_applied.emit(spell_name)
	buffs_changed.emit()

func add_absorb(amount: float, source_name: String) -> void:
	var was_zero := _absorb_hp <= 0.0
	_absorb_hp += amount
	absorb_applied.emit(int(_absorb_hp), source_name)
	if was_zero:
		buffs_changed.emit()

func consume_absorb(damage: int) -> int:
	if _absorb_hp <= 0.0:
		return damage
	var absorbed := minf(_absorb_hp, float(damage))
	_absorb_hp -= absorbed
	var remaining := damage - int(absorbed)
	if _absorb_hp <= 0.0:
		absorb_broken.emit()
		buffs_changed.emit()
	else:
		absorb_damaged.emit(int(absorbed), int(_absorb_hp))
	return remaining

func add_evade_boost(duration: float) -> void:
	var was_zero := _evade_boost_remaining <= 0.0
	_evade_boost_remaining = duration
	evade_boost_applied.emit()
	if was_zero:
		buffs_changed.emit()

func is_evade_boosted() -> bool:
	return _evade_boost_remaining > 0.0

func add_food_buff(hp_regen: float, mp_regen: float, duration: float, buff_name: String) -> void:
	_food_buff = {hp_regen = hp_regen, mp_regen = mp_regen, remaining = duration, buff_name = buff_name}
	food_buff_changed.emit()
	buffs_changed.emit()

func add_drink_buff(hp_regen: float, mp_regen: float, duration: float, buff_name: String) -> void:
	_drink_buff = {hp_regen = hp_regen, mp_regen = mp_regen, remaining = duration, buff_name = buff_name}
	drink_buff_changed.emit()
	buffs_changed.emit()

func get_food_buff() -> Dictionary:
	return _food_buff

func get_drink_buff() -> Dictionary:
	return _drink_buff

func has_food_buff() -> bool:
	return not _food_buff.is_empty()

func has_drink_buff() -> bool:
	return not _drink_buff.is_empty()

func get_food_hp_regen() -> float:
	return _food_buff.get("hp_regen", 0.0)

func get_food_mp_regen() -> float:
	return _food_buff.get("mp_regen", 0.0)

func get_drink_hp_regen() -> float:
	return _drink_buff.get("hp_regen", 0.0)

func get_drink_mp_regen() -> float:
	return _drink_buff.get("mp_regen", 0.0)

func clear_all() -> void:
	_dots.clear()
	_hots.clear()
	_absorb_hp = 0.0
	_evade_boost_remaining = 0.0
	_food_buff.clear()
	_drink_buff.clear()
	buffs_changed.emit()

func _process(delta: float) -> void:
	if _evade_boost_remaining > 0.0:
		_evade_boost_remaining -= delta
		if _evade_boost_remaining <= 0.0:
			buffs_changed.emit()
	_tick_dots(delta)
	_tick_hots(delta)
	_tick_consumable_buffs(delta)

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
				dot_ticked.emit(d.target.mob_name, dmg, d.spell_name)
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
			_is_hot_healing = true
			PlayerStats.set_hp(PlayerStats.hp + heal)
			_is_hot_healing = false
			hot_ticked.emit(int(heal), h.spell_name)
		if h.remaining <= 0.0:
			_hots.remove_at(i)
			buffs_changed.emit()
		i -= 1

func _tick_consumable_buffs(delta: float) -> void:
	if not _food_buff.is_empty():
		_food_buff.remaining -= delta
		if _food_buff.remaining <= 0.0:
			_food_buff.clear()
			food_buff_changed.emit()
			buffs_changed.emit()
	if not _drink_buff.is_empty():
		_drink_buff.remaining -= delta
		if _drink_buff.remaining <= 0.0:
			_drink_buff.clear()
			drink_buff_changed.emit()
			buffs_changed.emit()
