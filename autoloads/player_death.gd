extends Node

signal player_died
signal player_respawned

const RESPAWN_DELAY := 5.0
const XP_LOSS_PERCENT := 0.05   # lose 5% of current XP on death

var is_dead: bool = false
var _respawn_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	PlayerStats.hp_changed.connect(_on_hp_changed)

func set_respawn_point(pos: Vector3) -> void:
	_respawn_position = pos

func _on_hp_changed(current: float, _max: float) -> void:
	if is_dead or current > 0.0:
		return
	_die()

func _die() -> void:
	is_dead = true
	Combat.set_target(null)
	var xp_loss := int(PlayerStats.xp * XP_LOSS_PERCENT)
	PlayerStats.xp = max(0, PlayerStats.xp - xp_loss)
	player_died.emit()
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn)

func _respawn() -> void:
	is_dead = false
	PlayerStats.set_hp(PlayerStats.max_hp * 0.25)
	PlayerStats.set_mp(PlayerStats.max_mp * 0.25)
	PlayerStats.set_stamina(PlayerStats.max_stamina * 0.50)

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player != null:
		player.global_position = _respawn_position
		player.velocity = Vector3.ZERO

	player_respawned.emit()
