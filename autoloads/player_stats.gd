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

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	xp_changed.emit(xp, xp_to_next)

func _level_up() -> void:
	level += 1
	xp_to_next = int(xp_to_next * 1.5)
	var _con_before := constitution

	match player_class:
		"Warrior":
			strength += 2
			constitution += 2
			max_hp += 20.0
			max_stamina += 8.0
			max_mp += 2.0
		"Mage":
			intelligence += 3
			wisdom += 2
			max_mp += 25.0
			max_hp += 5.0
			max_stamina += 2.0
		"Rogue":
			dexterity += 2
			agility += 2
			max_hp += 12.0
			max_stamina += 10.0
			max_mp += 3.0
		"Cleric":
			wisdom += 3
			constitution += 1
			max_hp += 12.0
			max_mp += 20.0
			max_stamina += 2.0
		"Druid":
			wisdom += 2
			intelligence += 2
			max_hp += 8.0
			max_mp += 22.0
			max_stamina += 2.0
		"Shaman":
			wisdom += 2
			constitution += 1
			strength += 1
			max_hp += 12.0
			max_mp += 15.0
			max_stamina += 5.0
		"Blood Mage":
			intelligence += 3
			constitution += 1
			max_hp += 7.0
			max_mp += 22.0
			max_stamina += 2.0
		"Paladin":
			strength += 2
			wisdom += 2
			constitution += 1
			max_hp += 15.0
			max_mp += 12.0
			max_stamina += 5.0
		"Shadow Knight":
			strength += 2
			intelligence += 2
			constitution += 1
			max_hp += 14.0
			max_mp += 12.0
			max_stamina += 4.0
		"Necromancer":
			intelligence += 3
			wisdom += 2
			max_hp += 3.0
			max_mp += 25.0
			max_stamina += 1.0
		"Enchanter":
			intelligence += 3
			charisma += 2
			max_hp += 3.0
			max_mp += 23.0
			max_stamina += 1.0
		"Bard":
			dexterity += 2
			charisma += 2
			agility += 1
			max_hp += 10.0
			max_mp += 8.0
			max_stamina += 8.0
		"Ranger":
			dexterity += 2
			agility += 2
			wisdom += 1
			max_hp += 10.0
			max_mp += 8.0
			max_stamina += 8.0
		"Monk":
			strength += 2
			dexterity += 2
			agility += 1
			max_hp += 12.0
			max_mp += 4.0
			max_stamina += 10.0
		"Witch Hunter":
			intelligence += 2
			wisdom += 2
			constitution += 1
			max_hp += 10.0
			max_mp += 15.0
			max_stamina += 4.0
		_:
			max_hp += 10.0
			max_mp += 10.0
			max_stamina += 5.0

	max_hp += (constitution - _con_before) * 5.0

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
	max_hp       += item.bonus_max_hp
	max_mp       += item.bonus_max_mp
	max_stamina  += item.bonus_max_stamina
	stats_changed.emit()

func remove_item_bonuses(item: ItemData) -> void:
	strength     -= item.bonus_strength
	dexterity    -= item.bonus_dexterity
	agility      -= item.bonus_agility
	intelligence -= item.bonus_intelligence
	wisdom       -= item.bonus_wisdom
	charisma     -= item.bonus_charisma
	constitution -= item.bonus_constitution
	max_hp       = maxf(max_hp - item.bonus_max_hp, 1.0)
	max_mp       = maxf(max_mp - item.bonus_max_mp, 0.0)
	max_stamina  = maxf(max_stamina - item.bonus_max_stamina, 1.0)
	stats_changed.emit()
