extends Node

signal hp_changed(current: float, maximum: float)
signal mp_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal level_changed(new_level: int)
signal xp_changed(current_xp: int, xp_to_next: int)
signal xp_gained(amount: int, source: String)
signal healed(amount: int)
signal stats_changed
signal character_applied
signal coins_changed(platinum: int, gold: int, silver: int, copper: int)

# Four independent coin stacks (100:1 per tier — see autoloads/currency.gd and
# docs/concepts/world/currency.md). Independent on purpose: holding raw copper
# vs. converted silver is a player choice with a weight cost, so nothing may
# silently consolidate these. Server-authoritative in launcher mode via
# apply_remote_coins.
var platinum: int = 0
var gold: int = 0
var silver: int = 0
var copper: int = 100

var hp: float = 100.0
var max_hp: float = 100.0
var mp: float = 100.0
var max_mp: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0

# Level cap — mirrors the Rust world::skills::MAX_LEVEL. The XP curve (cubic;
# see _band_for / _hell_mod below) and the server's resolve() both stop here.
const MAX_LEVEL := 60

var level: int = 1
var xp: int = 0
var xp_to_next: int = 1000  # band(1) on the cubic curve; overwritten on login

var player_name: String = ""
var player_class: String = ""
var race: String = ""

var bind_zone_path: String = ""
var bind_entry_id: String = "default"
var bind_zone_name: String = ""

var transformation: String = ""

# Public (live) stats — include race + class + level + currently-equipped gear bonuses.
# Read these everywhere for combat math, UI, etc.
var strength: int = 10
var dexterity: int = 10
var agility: int = 10
var intelligence: int = 10
var wisdom: int = 10
var charisma: int = 10
var constitution: int = 10

# Intrinsic ("base") stats — race + class + level only. Gear bonuses are NOT
# accumulated here. apply_item_bonuses/remove_item_bonuses touch the public
# fields but leave these alone, so saves capture the gear-independent state.
var _base_strength: int = 10
var _base_dexterity: int = 10
var _base_agility: int = 10
var _base_intelligence: int = 10
var _base_wisdom: int = 10
var _base_charisma: int = 10
var _base_constitution: int = 10
var _base_max_hp: float = 100.0
var _base_max_mp: float = 100.0
var _base_max_stamina: float = 100.0

func set_hp(value: float) -> void:
	var old := hp
	hp = clamp(value, 0.0, max_hp)
	if hp > old:
		healed.emit(int(hp - old))
	hp_changed.emit(hp, max_hp)

func set_mp(value: float) -> void:
	mp = clamp(value, 0.0, max_mp)
	mp_changed.emit(mp, max_mp)

func set_stamina(value: float) -> void:
	stamina = clamp(value, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)

func set_bind_point(zone_path: String, entry_id: String, zone_name: String) -> void:
	bind_zone_path = zone_path
	bind_entry_id  = entry_id
	bind_zone_name = zone_name

func apply_character(race_id: String, cls: String, lvl: int) -> void:
	lvl = clampi(lvl, 1, 99)

	var stats: Dictionary = {}
	for k in CharacterData.STAT_KEYS:
		stats[k] = CharacterData.BASE
	for k: String in CharacterData.RACE_DATA[race_id]["bonuses"]:
		stats[k] += CharacterData.RACE_DATA[race_id]["bonuses"][k]
	for k: String in CharacterData.CLASS_DATA[cls]["bonuses"]:
		stats[k] += CharacterData.CLASS_DATA[cls]["bonuses"][k]

	var cd: Dictionary = CharacterData.CLASS_DATA[cls]
	var con_hp_bonus: float = (stats["constitution"] - 10) * 5.0
	var new_max_hp  := maxf(50.0, CharacterData.BASE_HP + cd["hp_bonus"] + con_hp_bonus)
	var new_max_mp  := maxf(20.0, CharacterData.BASE_MP + cd["mp_bonus"])
	var new_max_st  := maxf(20.0, CharacterData.BASE_ST + cd["stamina_bonus"])

	var gains: Dictionary = CharacterData.CLASS_LEVEL_GAINS.get(cls, CharacterData.CLASS_LEVEL_GAINS["_default"])
	for _i in lvl - 1:
		var con_before: int = stats["constitution"]
		for stat in gains["stats"]:
			stats[stat] += gains["stats"][stat]
		new_max_hp += gains["max_hp"]
		new_max_mp += gains["max_mp"]
		new_max_st += gains["max_stamina"]
		new_max_hp += (stats["constitution"] - con_before) * 5.0

	var new_xp_to_next := _band_for(lvl)

	self.race            = race_id
	self.player_class    = cls
	self.strength        = stats["strength"]
	self.dexterity       = stats["dexterity"]
	self.agility         = stats["agility"]
	self.intelligence    = stats["intelligence"]
	self.wisdom          = stats["wisdom"]
	self.charisma        = stats["charisma"]
	self.constitution    = stats["constitution"]
	self.level           = lvl
	self.xp              = 0
	self.xp_to_next      = new_xp_to_next
	self.max_hp          = new_max_hp
	self.max_mp          = new_max_mp
	self.max_stamina     = new_max_st
	# Intrinsic snapshot — apply_character runs before any gear is equipped, so
	# the values above are gear-free and become the new baseline.
	_base_strength      = strength
	_base_dexterity     = dexterity
	_base_agility       = agility
	_base_intelligence  = intelligence
	_base_wisdom        = wisdom
	_base_charisma      = charisma
	_base_constitution  = constitution
	_base_max_hp        = max_hp
	_base_max_mp        = max_mp
	_base_max_stamina   = max_stamina
	Alignment.set_alignment(CharacterData.CLASS_STARTING_ALIGNMENT.get(cls, 0))
	set_hp(new_max_hp)
	set_mp(new_max_mp)
	set_stamina(new_max_st)
	level_changed.emit(lvl)
	xp_changed.emit(0, new_xp_to_next)
	stats_changed.emit()
	character_applied.emit()

# `source` differentiates kill XP from quest turn-ins so the chat
# broker can render distinct lines ("You gained experience!" vs
# "You received experience."). Defaults to "kill" so legacy callers
# don't need updating; quest turn-ins must pass "quest" explicitly.
func gain_xp(amount: int, source: String = "kill") -> void:
	xp += amount
	xp_gained.emit(amount, source)
	# Cap at MAX_LEVEL and pin the bar full there, mirroring the server's
	# resolve(). (Local-only / Test Room path; launcher mode is server-driven.)
	while xp >= xp_to_next and level < MAX_LEVEL:
		xp -= xp_to_next
		_level_up()
	if level >= MAX_LEVEL and xp > xp_to_next:
		xp = xp_to_next
	xp_changed.emit(xp, xp_to_next)

# Apply one level's intrinsic gains to BOTH the public live stats and the
# gear-free `_base_` snapshot, so equipment deltas layered on top survive.
# Shared by the local-only `_level_up` and the server-mirror `apply_server_level`.
# Does NOT touch level / xp / current resources.
func _apply_level_gain() -> void:
	var con_before := constitution
	var g: Dictionary = CharacterData.CLASS_LEVEL_GAINS.get(player_class, CharacterData.CLASS_LEVEL_GAINS["_default"])
	for stat in g["stats"]:
		var delta: int = g["stats"][stat]
		self[stat] += delta
		set("_base_" + stat, get("_base_" + stat) + delta)
	max_hp           += g["max_hp"]
	max_mp           += g["max_mp"]
	max_stamina      += g["max_stamina"]
	_base_max_hp     += g["max_hp"]
	_base_max_mp     += g["max_mp"]
	_base_max_stamina+= g["max_stamina"]
	var con_delta := (constitution - con_before) * 5.0
	max_hp           += con_delta
	_base_max_hp     += con_delta

# Reverse of `_apply_level_gain` — subtract one level's intrinsic gains. Used
# when the server reports a de-level (a death penalty can drop a level). The
# con-based HP bonus is derived from the gain table so it mirrors the gain
# exactly regardless of the current constitution.
func _apply_level_loss() -> void:
	var g: Dictionary = CharacterData.CLASS_LEVEL_GAINS.get(player_class, CharacterData.CLASS_LEVEL_GAINS["_default"])
	var con_delta := float(g["stats"].get("constitution", 0)) * 5.0
	max_hp           -= con_delta
	_base_max_hp     -= con_delta
	for stat in g["stats"]:
		var delta: int = g["stats"][stat]
		self[stat] -= delta
		set("_base_" + stat, get("_base_" + stat) - delta)
	max_hp           -= g["max_hp"]
	max_mp           -= g["max_mp"]
	max_stamina      -= g["max_stamina"]
	_base_max_hp     -= g["max_hp"]
	_base_max_mp     -= g["max_mp"]
	_base_max_stamina-= g["max_stamina"]

# Local-only level-up (Test Room / no server). In launcher mode the server
# drives leveling via `apply_server_level`, so this is not called there.
func _level_up() -> void:
	level += 1
	xp_to_next = _band_for(level)
	_apply_level_gain()
	set_hp(max_hp)
	set_mp(max_mp)
	set_stamina(max_stamina)
	level_changed.emit(level)

# EQ-style cubic XP curve — mirror of the Rust `char_data` curve. Total XP to
# complete level L = L^3 * 1000 * hell_mod(L); the per-level band is the
# difference total(L) - total(L-1). The hell_mod spikes make the classic hell
# levels (30/35/40/45, then every level 51-60). f64 throughout (GDScript float is
# f64) + round() so the band matches the server byte-for-byte. Change BOTH sides
# in the same commit; the server's `compute` anchor tests guard the drift.
func _hell_mod(level_in: int) -> float:
	if level_in <= 29: return 1.0
	elif level_in <= 34: return 1.1
	elif level_in <= 39: return 1.2
	elif level_in <= 44: return 1.3
	elif level_in <= 50: return 1.4
	elif level_in == 51: return 1.5
	elif level_in == 52: return 1.6
	elif level_in == 53: return 1.7
	elif level_in == 54: return 1.9
	elif level_in == 55: return 2.1
	elif level_in == 56: return 2.3
	elif level_in == 57: return 2.5
	elif level_in == 58: return 2.7
	elif level_in == 59: return 3.0
	else: return 3.1

# Cumulative XP to *complete* `level_in` (total(0) == 0).
func _total_xp(level_in: int) -> float:
	if level_in < 1: return 0.0
	return float(level_in) * level_in * level_in * 1000.0 * _hell_mod(level_in)

# The band (xp_to_next) for `level_in`, clamped to the cap so the cubic can never
# overrun the server's i32 storage.
func _band_for(level_in: int) -> int:
	var lvl: int = clampi(level_in, 1, MAX_LEVEL)
	return int(round(_total_xp(lvl) - _total_xp(lvl - 1)))

# Launcher mode (server-authoritative): mirror a level change the server
# decided (up on xp gain, DOWN on a death penalty). Applies the matching
# intrinsic stat deltas locally — the client and server level tables are kept
# in lockstep — and sets the authoritative level + xp. Max pools move with the
# deltas; the server's HealthUpdate stays the backstop. Does NOT heal: the
# server owns current hp/mp/stamina (which arrive via the resource updates).
func apply_server_level(new_level: int, new_xp: int, new_xp_to_next: int) -> void:
	var steps := new_level - level
	for _i in absi(steps):
		if steps > 0:
			_apply_level_gain()
		else:
			_apply_level_loss()
	level = new_level
	xp = new_xp
	xp_to_next = new_xp_to_next
	# A de-level can drop a max below the current value; re-clamp via the setters.
	set_hp(hp)
	set_mp(mp)
	set_stamina(stamina)
	level_changed.emit(level)
	xp_changed.emit(xp, xp_to_next)
	stats_changed.emit()

# Launcher mode: mirror an authoritative xp update from the server (kill /
# quest credit, or a death loss with a negative `amount`). Sets the bar to the
# server's values; a level change itself arrives separately via
# `apply_server_level`.
func apply_remote_xp(amount: int, current: int, to_next: int) -> void:
	xp = current
	xp_to_next = to_next
	if amount > 0:
		xp_gained.emit(amount, "kill")
	xp_changed.emit(xp, xp_to_next)

func apply_item_bonuses(item: ItemData) -> void:
	strength     += item.bonus_strength
	dexterity    += item.bonus_dexterity
	agility      += item.bonus_agility
	intelligence += item.bonus_intelligence
	wisdom       += item.bonus_wisdom
	charisma     += item.bonus_charisma
	constitution += item.bonus_constitution
	max_hp      += item.bonus_max_hp
	max_mp      += item.bonus_max_mp
	max_stamina += item.bonus_max_stamina
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	stamina_changed.emit(stamina, max_stamina)
	stats_changed.emit()

func remove_item_bonuses(item: ItemData) -> void:
	strength     -= item.bonus_strength
	dexterity    -= item.bonus_dexterity
	agility      -= item.bonus_agility
	intelligence -= item.bonus_intelligence
	wisdom       -= item.bonus_wisdom
	charisma     -= item.bonus_charisma
	constitution -= item.bonus_constitution
	max_hp      = maxf(max_hp - item.bonus_max_hp, 1.0)
	max_mp      = maxf(max_mp - item.bonus_max_mp, 0.0)
	max_stamina = maxf(max_stamina - item.bonus_max_stamina, 1.0)
	set_hp(hp)
	set_mp(mp)
	set_stamina(stamina)
	stats_changed.emit()

# Total wallet value in copper-equivalents — for affordability checks and
# display totals. Never write back from this; the four stacks are the truth.
func total_copper() -> int:
	return Currency.total_copper(platinum, gold, silver, copper)

# Credit exact per-tier stacks, no reduction — a 1000-copper grant stays
# 1000 raw copper. For loot drops that specify tiers and dev grants; vendor
# payouts use add_coins (reduced) instead.
func add_coin_stacks(p: int, g: int, s: int, c: int) -> void:
	platinum = maxi(platinum + p, 0)
	gold = maxi(gold + g, 0)
	silver = maxi(silver + s, 0)
	copper = maxi(copper + c, 0)
	coins_changed.emit(platinum, gold, silver, copper)

# Credit a payout of `amount` copper-equivalents, reduced to minimal coins
# (a 250c payout arrives as 2s 50c). Existing stacks are not re-reduced.
func add_coins(amount: int) -> void:
	var payout := Currency.from_copper(amount)
	platinum += payout[0]
	gold += payout[1]
	silver += payout[2]
	copper += payout[3]
	coins_changed.emit(platinum, gold, silver, copper)

# Spend `amount` copper-equivalents with make-change: low coins go first, a
# higher coin is broken only when the lower stacks fall short (see
# Currency.spend). Returns false (wallet untouched) if unaffordable.
func spend_coins(amount: int) -> bool:
	var wallet: Array[int] = [platinum, gold, silver, copper]
	if not Currency.spend(wallet, amount):
		return false
	platinum = wallet[0]
	gold = wallet[1]
	silver = wallet[2]
	copper = wallet[3]
	coins_changed.emit(platinum, gold, silver, copper)
	return true

# Track 14 follow-up — server-authoritative coins overwrite. Called
# from Net._on_coins_update when the server fans a CoinsUpdate
# (vendor BuyItem / SellItem, and any future coin-mutating flow).
# In launcher mode this is the only path that changes the wallet —
# vendor_window.gd no longer touches spend_coins / add_coins
# directly when Net.is_launcher_mode() is true.
func apply_remote_coins(new_platinum: int, new_gold: int, new_silver: int, new_copper: int) -> void:
	if platinum == new_platinum and gold == new_gold \
			and silver == new_silver and copper == new_copper:
		return
	platinum = new_platinum
	gold = new_gold
	silver = new_silver
	copper = new_copper
	coins_changed.emit(platinum, gold, silver, copper)

func lose_xp(amount: int) -> void:
	xp = max(0, xp - amount)
	xp_changed.emit(xp, xp_to_next)

# ── Save / load (Tier 1 persistence) ──────────────────────────────────────────

func save_state() -> Dictionary:
	# Persists intrinsic (gear-free) stats. Equipped items reapply their
	# bonuses on load via Equipment.equip(), avoiding double-counting.
	return {
		"player_name": player_name,
		"race": race,
		"player_class": player_class,
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"platinum": platinum, "gold": gold, "silver": silver, "copper": copper,
		"max_hp": _base_max_hp, "max_mp": _base_max_mp, "max_stamina": _base_max_stamina,
		"hp": hp, "mp": mp, "stamina": stamina,
		"strength": _base_strength, "dexterity": _base_dexterity, "agility": _base_agility,
		"intelligence": _base_intelligence, "wisdom": _base_wisdom, "charisma": _base_charisma,
		"constitution": _base_constitution,
		"bind_zone_path": bind_zone_path, "bind_entry_id": bind_entry_id,
		"bind_zone_name": bind_zone_name,
		"transformation": transformation,
	}

func load_state(d: Dictionary) -> void:
	player_name    = d.get("player_name", "")
	race           = d.get("race", "")
	player_class   = d.get("player_class", "")
	level          = int(d.get("level", 1))
	xp             = int(d.get("xp", 0))
	xp_to_next     = int(d.get("xp_to_next", 1000))
	# Four-tier wallet; a pre-currency save's single "coins" count carries
	# forward into copper (it was a flat count with no tiers).
	platinum       = int(d.get("platinum", 0))
	gold           = int(d.get("gold", 0))
	silver         = int(d.get("silver", 0))
	copper         = int(d.get("copper", d.get("coins", 100)))
	# Intrinsic stats restored. No gear is equipped at load time, so public
	# fields mirror the base values until Equipment re-equips items.
	_base_max_hp        = float(d.get("max_hp", 100.0))
	_base_max_mp        = float(d.get("max_mp", 100.0))
	_base_max_stamina   = float(d.get("max_stamina", 100.0))
	max_hp              = _base_max_hp
	max_mp              = _base_max_mp
	max_stamina         = _base_max_stamina
	hp                  = float(d.get("hp", max_hp))
	mp                  = float(d.get("mp", max_mp))
	stamina             = float(d.get("stamina", max_stamina))
	_base_strength      = int(d.get("strength", 10))
	_base_dexterity     = int(d.get("dexterity", 10))
	_base_agility       = int(d.get("agility", 10))
	_base_intelligence  = int(d.get("intelligence", 10))
	_base_wisdom        = int(d.get("wisdom", 10))
	_base_charisma      = int(d.get("charisma", 10))
	_base_constitution  = int(d.get("constitution", 10))
	strength            = _base_strength
	dexterity           = _base_dexterity
	agility             = _base_agility
	intelligence        = _base_intelligence
	wisdom              = _base_wisdom
	charisma            = _base_charisma
	constitution        = _base_constitution
	bind_zone_path = d.get("bind_zone_path", "")
	bind_entry_id  = d.get("bind_entry_id", "default")
	bind_zone_name = d.get("bind_zone_name", "")
	transformation = d.get("transformation", "")
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	stamina_changed.emit(stamina, max_stamina)
	xp_changed.emit(xp, xp_to_next)
	level_changed.emit(level)
	coins_changed.emit(platinum, gold, silver, copper)
	stats_changed.emit()
	character_applied.emit()
