extends Node

signal player_died
signal player_respawned

const RESPAWN_DELAY := 5.0
const XP_LOSS_PERCENT := 0.05   # lose 5% of current XP on death

var is_dead: bool = false
var _respawn_position: Vector3 = Vector3.ZERO
var _player: Node3D = null

func register_player(node: Node3D) -> void:
	_player = node

func unregister_player() -> void:
	_player = null

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
	if xp_loss > 0:
		PlayerStats.lose_xp(xp_loss)
		CombatLog.add_line("You lost %d experience points." % xp_loss, CombatLog.MsgType.DAMAGE_IN)
	# Track 4 sub-task 5: notify the server so peers can play the
	# fall-over animation on their RemotePlayer for us. The matching
	# stand-up happens implicitly on the next ResourceUpdate (when
	# _respawn() below sets HP back above zero).
	Net.broadcast_death()
	player_died.emit()
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn)

func _respawn() -> void:
	is_dead = false
	PlayerStats.set_hp(PlayerStats.max_hp * 0.25)
	PlayerStats.set_mp(PlayerStats.max_mp * 0.25)
	PlayerStats.set_stamina(PlayerStats.max_stamina * 0.50)

	var bind := PlayerStats.bind_zone_path
	if bind != "" and FileAccess.file_exists(bind):
		player_respawned.emit()
		ZoneLoader.travel_to(bind, PlayerStats.bind_entry_id, PlayerStats.bind_zone_name)
	else:
		if is_instance_valid(_player):
			_player.global_position = _respawn_position
			_player.velocity = Vector3.ZERO
		player_respawned.emit()
