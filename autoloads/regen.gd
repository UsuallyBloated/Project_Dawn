extends Node

# Ticks every TICK_INTERVAL seconds.
# Regen rates are per-tick values.
# Sitting (crouching) grants a bonus multiplier.

const TICK_INTERVAL   := 3.0   # seconds between regen ticks
const SIT_MULTIPLIER  := 3.0   # regen bonus while sitting

var _tick_timer: float = 0.0
var _in_combat: bool = false
var _player: Node3D = null

func register_player(node: Node3D) -> void:
	_player = node

func unregister_player() -> void:
	_player = null

func _ready() -> void:
	Combat.target_changed.connect(_on_target_changed)

func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		_do_regen()

func _do_regen() -> void:
	if _in_combat:
		return

	var is_sitting: bool = is_instance_valid(_player) and _player.get("is_crouching") == true
	var mult := SIT_MULTIPLIER if is_sitting else 1.0

	var hp_rate  := _hp_regen_per_tick()  * mult
	var mp_rate  := _mp_regen_per_tick()  * mult
	var st_rate  := _st_regen_per_tick()  * mult

	if PlayerStats.hp < PlayerStats.max_hp:
		PlayerStats.set_hp(minf(PlayerStats.hp + hp_rate, PlayerStats.max_hp))
	if PlayerStats.mp < PlayerStats.max_mp:
		PlayerStats.set_mp(minf(PlayerStats.mp + mp_rate, PlayerStats.max_mp))
	if PlayerStats.stamina < PlayerStats.max_stamina:
		PlayerStats.set_stamina(minf(PlayerStats.stamina + st_rate, PlayerStats.max_stamina))

func _hp_regen_per_tick() -> float:
	return 2.0 + PlayerStats.constitution * 0.15

func _mp_regen_per_tick() -> float:
	return 2.0 + PlayerStats.wisdom * 0.20

func _st_regen_per_tick() -> float:
	return 3.0 + PlayerStats.agility * 0.10

func _on_target_changed(enemy) -> void:
	_in_combat = enemy != null and is_instance_valid(enemy)
	if not _in_combat:
		_tick_timer = TICK_INTERVAL * 0.5
