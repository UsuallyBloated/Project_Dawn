extends Node

signal hp_changed(current: float, maximum: float)
signal mp_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal level_changed(new_level: int)
signal xp_changed(current_xp: int, xp_to_next: int)
signal alignment_changed(tier: String, score: int)
signal stats_changed

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

var alignment_score: int = 0
var alignment_tier: String = "Neutral"
var transformation: String = ""

var strength: int = 10
var dexterity: int = 10
var agility: int = 10
var intelligence: int = 10
var wisdom: int = 10
var charisma: int = 10
var constitution: int = 10

func set_hp(value: float) -> void:
	hp = clamp(value, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)

func set_mp(value: float) -> void:
	mp = clamp(value, 0.0, max_mp)
	mp_changed.emit(mp, max_mp)

func set_stamina(value: float) -> void:
	stamina = clamp(value, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)

func set_alignment(score: int) -> void:
	alignment_score = clamp(score, -2000, 2000)
	alignment_tier = _calc_alignment_tier()

func modify_alignment(delta: int) -> void:
	alignment_score = clamp(alignment_score + delta, -2000, 2000)
	var new_tier := _calc_alignment_tier()
	if new_tier != alignment_tier:
		alignment_tier = new_tier
		alignment_changed.emit(alignment_tier, alignment_score)

func _calc_alignment_tier() -> String:
	if alignment_score >= 1500:
		return "Exalted"
	elif alignment_score >= 300:
		return "Good"
	elif alignment_score >= -300:
		return "Neutral"
	elif alignment_score >= -1500:
		return "Bad"
	else:
		return "Evil"

# Returns the alignment-modified class key used to look up skills and spells.
# Add new alignment variants here when a class gains a fallen/redeemed path.
func get_effective_class() -> String:
	match player_class:
		"Paladin":
			if alignment_tier == "Evil":
				return "Paladin_Fallen"
		"Shadow Knight":
			if alignment_tier == "Exalted":
				return "Shadow Knight_Redeemed"
	return player_class

func gain_xp(amount: int) -> void:
	xp += amount
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
		self[stat] += g["stats"][stat]
	max_hp      += g["max_hp"]
	max_mp      += g["max_mp"]
	max_stamina += g["max_stamina"]
	max_hp += (constitution - con_before) * 5.0

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
