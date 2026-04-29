extends Node

# Ticks every TICK_INTERVAL seconds.
# Sitting grants large regen bonuses for all three stats.

const TICK_INTERVAL := 3.0

var _tick_timer: float = 0.0
var _in_combat: bool = false
var _player: Node3D = null

func register_player(node: Node3D) -> void:
	_player = node
	if _player.has_signal("state_changed"):
		_player.state_changed.connect(_on_player_state_changed)

func unregister_player() -> void:
	if is_instance_valid(_player) and _player.has_signal("state_changed"):
		if _player.state_changed.is_connected(_on_player_state_changed):
			_player.state_changed.disconnect(_on_player_state_changed)
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

	var is_sitting: bool = is_instance_valid(_player) and _player.state == 2  # PlayerState.SITTING
	var hp_mult := 5.0 if is_sitting else 1.0
	var mp_mult := 5.0 if is_sitting else 1.0
	var st_mult := 3.0 if is_sitting else 1.0

	if PlayerStats.hp < PlayerStats.max_hp:
		PlayerStats.set_hp(minf(PlayerStats.hp + _hp_regen_per_tick() * hp_mult, PlayerStats.max_hp))
	if PlayerStats.mp < PlayerStats.max_mp:
		PlayerStats.set_mp(minf(PlayerStats.mp + _mp_regen_per_tick() * mp_mult, PlayerStats.max_mp))
	if PlayerStats.stamina < PlayerStats.max_stamina:
		PlayerStats.set_stamina(minf(PlayerStats.stamina + _st_regen_per_tick() * st_mult, PlayerStats.max_stamina))

func _hp_regen_per_tick() -> float:
	return 2.0 + PlayerStats.constitution * 0.15

func _mp_regen_per_tick() -> float:
	return 2.0 + PlayerStats.wisdom * 0.20

func _st_regen_per_tick() -> float:
	return 3.0 + PlayerStats.agility * 0.10

func _on_player_state_changed(_new_state: int) -> void:
	_tick_timer = TICK_INTERVAL * 0.5

func _on_target_changed(enemy) -> void:
	_in_combat = enemy != null and is_instance_valid(enemy)
	if not _in_combat:
		_tick_timer = TICK_INTERVAL * 0.5
	elif is_instance_valid(_player) and _player.state == 2:
		_player.stand()
