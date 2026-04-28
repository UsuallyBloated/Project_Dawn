extends Node

signal hp_changed(current: float, maximum: float)
signal mp_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal level_changed(new_level: int)

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

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()

func _level_up() -> void:
	level += 1
	xp_to_next = int(xp_to_next * 1.5)
	max_hp += 10.0
	max_mp += 10.0
	max_stamina += 5.0
	set_hp(max_hp)
	set_mp(max_mp)
	set_stamina(max_stamina)
	level_changed.emit(level)
