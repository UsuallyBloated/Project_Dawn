extends Node

signal hp_changed(current: float, maximum: float)
signal mp_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal level_changed(new_level: int)
signal xp_changed(current_xp: int, xp_to_next: int)
signal xp_gained(amount: int)
signal healed(amount: int)
signal stats_changed
signal character_applied
signal coins_changed(new_amount: int)

var coins: int = 100

var hp: float = 100.0
var max_hp: float = 100.0
var mp: float = 100.0
var max_mp: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0

var level: int = 1
var xp: int = 0
var xp_to_next: int = 100

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

	var new_xp_to_next := 100
	for _i in lvl - 1:
		new_xp_to_next = int(new_xp_to_next * 1.5)

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

func gain_xp(amount: int) -> void:
	xp += amount
	xp_gained.emit(amount)
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	xp_changed.emit(xp, xp_to_next)

func _level_up() -> void:
	level += 1
	xp_to_next = int(xp_to_next * 1.5)
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

	set_hp(max_hp)
	set_mp(max_mp)
	set_stamina(max_stamina)
	level_changed.emit(level)

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

func add_coins(amount: int) -> void:
	coins = max(0, coins + amount)
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

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
		"coins": coins,
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
	xp_to_next     = int(d.get("xp_to_next", 100))
	coins          = int(d.get("coins", 100))
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
	coins_changed.emit(coins)
	stats_changed.emit()
	character_applied.emit()
