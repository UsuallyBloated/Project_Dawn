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
signal stealth_changed(active: bool)
signal lich_form_changed(active: bool)
signal haste_changed
signal primary_stat_buff_changed
signal damage_shield_applied(amount: int, buff_name: String)

const TICK_INTERVAL := 3.0

var _absorb_hp: float = 0.0
# Most recent absorb source name (spell or skill). Used by
# reconcile_with_server_snapshot to clear the pool when the server
# strips the absorb buff (e.g. drained to 0 by incoming damage in
# launcher mode, since the local consume_absorb path isn't taken when
# damage arrives via HealthUpdate).
var _absorb_source: String = ""
var _is_hot_healing: bool = false
var _evade_boost_remaining: float = 0.0

# {target, dps, remaining, spell_name, tick_acc}
var _dots: Array = []
# {hps, remaining, spell_name, tick_acc}
var _hots: Array = []

# {hp_regen, mp_regen, remaining, buff_name}
var _food_buff: Dictionary = {}
var _drink_buff: Dictionary = {}

# {speed_mult, remaining, buff_name}
var _speed_buff: Dictionary = {}
# {hps, remaining, buff_name}
var _mp_regen_buff: Dictionary = {}
# {amount, remaining, buff_name}
var _haste_buff: Dictionary = {}
# {accuracy, crit, remaining, buff_name}
var _stat_buff: Dictionary = {}
# {str, agi, int, wis, con, max_hp, max_mp, remaining, buff_name}
# Values are already applied to PlayerStats; undone on expire or clear_all.
var _primary_stat_buff: Dictionary = {}
# {amount, remaining, buff_name}
var _damage_shield: Dictionary = {}
# stealth state
var _stealth_remaining: float = 0.0
# Lich Form
var _lich_form_active: bool = false
var _lich_mp_regen: float = 0.0

# Track 6 dispel sync — server is authoritative for buff lifetime in
# launcher mode. reconcile_with_server_snapshot() drops any locally
# tracked named buff that no longer appears in the server's snapshot
# (e.g. after Antimagic Ward / Expose). Local-only buffs (food, drink,
# stealth, evade) are skipped — the server doesn't track those.

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
	_absorb_source = source_name
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

func add_speed_buff(speed_mult: float, duration: float, buff_name: String) -> void:
	_speed_buff = {speed_mult = speed_mult, remaining = duration, buff_name = buff_name}
	buffs_changed.emit()

func get_speed_mult() -> float:
	return _speed_buff.get("speed_mult", 1.0)

func get_speed_buff() -> Dictionary:
	return _speed_buff

func add_mp_regen_buff(hps: float, duration: float, buff_name: String) -> void:
	_mp_regen_buff = {hps = hps, remaining = duration, buff_name = buff_name}
	buffs_changed.emit()

func get_mp_regen_buff() -> Dictionary:
	return _mp_regen_buff

func add_haste_buff(amount: float, duration: float, buff_name: String) -> void:
	_haste_buff = {amount = amount, remaining = duration, buff_name = buff_name}
	haste_changed.emit()
	buffs_changed.emit()

func get_haste_amount() -> float:
	return _haste_buff.get("amount", 0.0)

func get_haste_buff() -> Dictionary:
	return _haste_buff

func add_stat_buff(accuracy: float, crit: float, duration: float, buff_name: String) -> void:
	_stat_buff = {accuracy = accuracy, crit = crit, remaining = duration, buff_name = buff_name}
	buffs_changed.emit()

func get_accuracy_bonus() -> float:
	return _stat_buff.get("accuracy", 0.0)

func get_crit_bonus() -> float:
	return _stat_buff.get("crit", 0.0)

func get_stat_buff() -> Dictionary:
	return _stat_buff

func add_damage_shield(amount: float, duration: float, buff_name: String) -> void:
	# Overwrites any existing shield; only one active at a time (matches haste/speed pattern).
	_damage_shield = {amount = amount, remaining = duration, buff_name = buff_name}
	damage_shield_applied.emit(int(amount), buff_name)
	buffs_changed.emit()

func get_damage_shield_amount() -> float:
	return _damage_shield.get("amount", 0.0)

func get_damage_shield() -> Dictionary:
	return _damage_shield

func add_primary_stat_buff(str_b: int, agi_b: int, int_b: int, wis_b: int, con_b: int,
		max_hp_b: float, max_mp_b: float, duration: float, buff_name: String) -> void:
	if not _primary_stat_buff.is_empty():
		_undo_primary_stat_buff()
	_primary_stat_buff = {strength = str_b, agility = agi_b, intelligence = int_b,
		wisdom = wis_b, constitution = con_b, max_hp = max_hp_b, max_mp = max_mp_b,
		remaining = duration, buff_name = buff_name}
	PlayerStats.strength     += str_b
	PlayerStats.agility      += agi_b
	PlayerStats.intelligence += int_b
	PlayerStats.wisdom       += wis_b
	PlayerStats.constitution += con_b
	PlayerStats.max_hp       += max_hp_b
	PlayerStats.max_mp       += max_mp_b
	PlayerStats.stats_changed.emit()
	primary_stat_buff_changed.emit()
	buffs_changed.emit()

func get_primary_stat_buff() -> Dictionary:
	return _primary_stat_buff

func _undo_primary_stat_buff() -> void:
	if _primary_stat_buff.is_empty():
		return
	PlayerStats.strength     -= _primary_stat_buff.strength
	PlayerStats.agility      -= _primary_stat_buff.agility
	PlayerStats.intelligence -= _primary_stat_buff.intelligence
	PlayerStats.wisdom       -= _primary_stat_buff.wisdom
	PlayerStats.constitution -= _primary_stat_buff.constitution
	PlayerStats.max_hp        = maxf(PlayerStats.max_hp - _primary_stat_buff.max_hp, 1.0)
	PlayerStats.max_mp        = maxf(PlayerStats.max_mp - _primary_stat_buff.max_mp, 0.0)
	PlayerStats.set_hp(PlayerStats.hp)
	PlayerStats.set_mp(PlayerStats.mp)
	PlayerStats.stats_changed.emit()
	_primary_stat_buff.clear()

func add_stealth(duration: float, _buff_name: String) -> void:
	var was_stealthed := _stealth_remaining > 0.0
	_stealth_remaining = duration
	if not was_stealthed:
		stealth_changed.emit(true)
		buffs_changed.emit()

func is_stealthed() -> bool:
	return _stealth_remaining > 0.0

func get_stealth_remaining() -> float:
	return _stealth_remaining

func break_stealth() -> void:
	if _stealth_remaining <= 0.0:
		return
	_stealth_remaining = 0.0
	stealth_changed.emit(false)
	buffs_changed.emit()

func toggle_lich_form(mp_regen_hps: float) -> void:
	_lich_form_active = not _lich_form_active
	_lich_mp_regen = mp_regen_hps if _lich_form_active else 0.0
	lich_form_changed.emit(_lich_form_active)
	buffs_changed.emit()

func is_lich_form() -> bool:
	return _lich_form_active

func get_lich_mp_regen() -> float:
	return _lich_mp_regen

# Track 4 sub-task 3 — walk every buff source the local buff bar shows and
# emit parallel name/duration arrays for over-the-wire snapshot replication.
# 0.0 duration means "indefinite / toggle" (Lich, raw Absorb) — receiver
# displays the name without a countdown.
func get_snapshot_arrays() -> Dictionary:
	var names := PackedStringArray()
	var durations := PackedFloat32Array()
	for h in _hots:
		names.append(h.spell_name)
		durations.append(h.remaining)
	if _absorb_hp > 0.0:
		names.append("Shield")
		durations.append(0.0)
	if _evade_boost_remaining > 0.0:
		names.append("Evade")
		durations.append(_evade_boost_remaining)
	if not _food_buff.is_empty():
		names.append(_food_buff.get("buff_name", "Food"))
		durations.append(_food_buff.get("remaining", 0.0))
	if not _drink_buff.is_empty():
		names.append(_drink_buff.get("buff_name", "Drink"))
		durations.append(_drink_buff.get("remaining", 0.0))
	if not _speed_buff.is_empty():
		names.append(_speed_buff.get("buff_name", "SoW"))
		durations.append(_speed_buff.get("remaining", 0.0))
	if not _haste_buff.is_empty():
		names.append(_haste_buff.get("buff_name", "Haste"))
		durations.append(_haste_buff.get("remaining", 0.0))
	if not _mp_regen_buff.is_empty():
		names.append(_mp_regen_buff.get("buff_name", "Clarity"))
		durations.append(_mp_regen_buff.get("remaining", 0.0))
	if not _stat_buff.is_empty():
		names.append(_stat_buff.get("buff_name", "Focused"))
		durations.append(_stat_buff.get("remaining", 0.0))
	if not _primary_stat_buff.is_empty():
		names.append(_primary_stat_buff.get("buff_name", "Bless"))
		durations.append(_primary_stat_buff.get("remaining", 0.0))
	if not _damage_shield.is_empty():
		names.append(_damage_shield.get("buff_name", "Thorns"))
		durations.append(_damage_shield.get("remaining", 0.0))
	if _stealth_remaining > 0.0:
		names.append("Hidden")
		durations.append(_stealth_remaining)
	if _lich_form_active:
		names.append("Lich")
		durations.append(0.0)
	return {"names": names, "durations": durations}

func reconcile_with_server_snapshot(names: PackedStringArray, durations: PackedFloat32Array) -> void:
	# Build a name -> remaining map. Matching local buffs get their
	# remaining synced to the server's value so the HUD countdown
	# tracks the authoritative timer (avoids a 50-100ms drift where
	# the local timer expires before the server's 20Hz tick removes
	# the buff — manifested as e.g. "thorns reflected after my buff
	# icon disappeared"). Missing names trigger a local clear.
	var server_remaining: Dictionary = {}
	for idx in names.size():
		var dur: float = durations[idx] if idx < durations.size() else 0.0
		server_remaining[names[idx]] = dur
	var changed := false
	var i := _hots.size() - 1
	while i >= 0:
		var nm: String = _hots[i].spell_name
		if not server_remaining.has(nm):
			_hots.remove_at(i)
			changed = true
		else:
			_hots[i].remaining = server_remaining[nm]
		i -= 1
	if not _primary_stat_buff.is_empty():
		var nm: String = _primary_stat_buff.get("buff_name", "")
		if not server_remaining.has(nm):
			_undo_primary_stat_buff()
			primary_stat_buff_changed.emit()
			changed = true
		else:
			_primary_stat_buff.remaining = server_remaining[nm]
	if not _stat_buff.is_empty():
		var nm: String = _stat_buff.get("buff_name", "")
		if not server_remaining.has(nm):
			_stat_buff.clear()
			changed = true
		else:
			_stat_buff.remaining = server_remaining[nm]
	if not _speed_buff.is_empty():
		var nm: String = _speed_buff.get("buff_name", "")
		if not server_remaining.has(nm):
			_speed_buff.clear()
			changed = true
		else:
			_speed_buff.remaining = server_remaining[nm]
	if not _haste_buff.is_empty():
		var nm: String = _haste_buff.get("buff_name", "")
		if not server_remaining.has(nm):
			_haste_buff.clear()
			haste_changed.emit()
			changed = true
		else:
			_haste_buff.remaining = server_remaining[nm]
	if not _mp_regen_buff.is_empty():
		var nm: String = _mp_regen_buff.get("buff_name", "")
		if not server_remaining.has(nm):
			_mp_regen_buff.clear()
			changed = true
		else:
			_mp_regen_buff.remaining = server_remaining[nm]
	if not _damage_shield.is_empty():
		var nm: String = _damage_shield.get("buff_name", "")
		if not server_remaining.has(nm):
			_damage_shield.clear()
			changed = true
		else:
			_damage_shield.remaining = server_remaining[nm]
	# Absorb: the server drains the pool and strips the buff when it
	# hits 0. In launcher mode the local _absorb_hp never drains
	# (damage arrives via HealthUpdate, bypassing local consume_absorb),
	# so without this clear the "Shield Xhp" icon would linger forever.
	if _absorb_hp > 0.0 and _absorb_source != "" and not server_remaining.has(_absorb_source):
		_absorb_hp = 0.0
		_absorb_source = ""
		absorb_broken.emit()
		changed = true
	if _lich_form_active and not server_remaining.has("Lich Form"):
		_lich_form_active = false
		_lich_mp_regen = 0.0
		lich_form_changed.emit(false)
		changed = true
	if changed:
		buffs_changed.emit()

func clear_all() -> void:
	_dots.clear()
	_hots.clear()
	_absorb_hp = 0.0
	_absorb_source = ""
	_evade_boost_remaining = 0.0
	_food_buff.clear()
	_drink_buff.clear()
	_speed_buff.clear()
	_mp_regen_buff.clear()
	_haste_buff.clear()
	_stat_buff.clear()
	_damage_shield.clear()
	if not _primary_stat_buff.is_empty():
		_undo_primary_stat_buff()
		primary_stat_buff_changed.emit()
	if _stealth_remaining > 0.0:
		stealth_changed.emit(false)
	_stealth_remaining = 0.0
	if _lich_form_active:
		lich_form_changed.emit(false)
	_lich_form_active = false
	_lich_mp_regen = 0.0
	buffs_changed.emit()

func _process(delta: float) -> void:
	if _evade_boost_remaining > 0.0:
		_evade_boost_remaining -= delta
		if _evade_boost_remaining <= 0.0:
			buffs_changed.emit()
	if _stealth_remaining > 0.0:
		_stealth_remaining -= delta
		if _stealth_remaining <= 0.0:
			stealth_changed.emit(false)
			buffs_changed.emit()
	_tick_timed_buff(_speed_buff, delta)
	_tick_timed_buff(_mp_regen_buff, delta)
	_tick_timed_buff(_damage_shield, delta)
	if not _haste_buff.is_empty():
		_haste_buff.remaining -= delta
		if _haste_buff.remaining <= 0.0:
			_haste_buff.clear()
			haste_changed.emit()
			buffs_changed.emit()
	_tick_timed_buff(_stat_buff, delta)
	if not _primary_stat_buff.is_empty():
		_primary_stat_buff.remaining -= delta
		if _primary_stat_buff.remaining <= 0.0:
			_undo_primary_stat_buff()
			primary_stat_buff_changed.emit()
			buffs_changed.emit()
	_tick_dots(delta)
	_tick_hots(delta)
	_tick_consumable_buffs(delta)

func _tick_timed_buff(buff: Dictionary, delta: float) -> void:
	if buff.is_empty():
		return
	buff.remaining -= delta
	if buff.remaining <= 0.0:
		buff.clear()
		buffs_changed.emit()

func _tick_dots(delta: float) -> void:
	# Track 6 sub-task 4a: server-side DoT application lands in 4b. In
	# launcher mode skip the damage tick (RemoteEnemy.take_damage is a
	# no-op, RemotePlayer has none) but still decrement remaining so
	# the local DoT entry expires on schedule. Test Room single-player
	# keeps the full local damage tick.
	var launcher := Net.is_launcher_mode()
	var i := _dots.size() - 1
	while i >= 0:
		var d: Dictionary = _dots[i]
		if not is_instance_valid(d.target) or d.target.is_dead:
			_dots.remove_at(i)
			i -= 1
			continue
		d.remaining -= delta
		if not launcher:
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
	# Track 6 sub-task 4a: server owns HoT application — applies heal
	# per tick to conn.hp and fans HealthUpdate. Skip the local heal
	# mutation in launcher mode (would fight the server), but still
	# decrement remaining so the HUD buff bar duration ticks down and
	# the entry expires on its own timer.
	var launcher := Net.is_launcher_mode()
	var i := _hots.size() - 1
	while i >= 0:
		var h: Dictionary = _hots[i]
		h.remaining -= delta
		if not launcher:
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
