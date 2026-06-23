extends Node

signal player_died
signal player_respawned

const RESPAWN_DELAY := 5.0

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
	# Track 22.C — death dismounts (the killing blow's receive_player_damage
	# also dismounts, but death from a non-damage path — fall, scripted
	# event — needs this safety net).
	MountManager.dismount("died")
	# Death XP penalty is server-authoritative now (Slice 0): the server applies
	# it in world::progression (5% of the level band, cascading de-level, floor
	# at level 5) and reports it back via XpGained (plus a LevelUp if you
	# de-leveled), which the client mirrors. No local loss computed here.
	# Track 4 sub-task 5 / Track 6: notify the server. The server zeroes
	# its own conn.hp and fans HealthUpdate(0) + EntityDied so peer
	# RemotePlayer bars drop and the fall-over animation plays. _respawn()
	# below sends the matching Respawn intent once the delay elapses.
	Net.broadcast_death()
	player_died.emit()
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn)

func _respawn() -> void:
	is_dead = false
	PlayerStats.set_hp(PlayerStats.max_hp * 0.25)
	PlayerStats.set_mp(PlayerStats.max_mp * 0.25)
	PlayerStats.set_stamina(PlayerStats.max_stamina * 0.50)
	# Track 6: tell the server we're alive again. Server resets conn.hp
	# to the same weakened multipliers used above (matching avoids the
	# server's HealthUpdate immediately overriding the local set_hp) and
	# fans HealthUpdate / ManaUpdate / StaminaUpdate — peer RemotePlayer
	# .apply_health_update sees was_dead && new_hp > 0 → _apply_respawn().
	Net.broadcast_respawn()

	var bind := PlayerStats.bind_zone_path
	if bind != "" and FileAccess.file_exists(bind):
		player_respawned.emit()
		ZoneLoader.travel_to(bind, PlayerStats.bind_entry_id, PlayerStats.bind_zone_name)
	else:
		if is_instance_valid(_player):
			_player.global_position = _respawn_position
			_player.velocity = Vector3.ZERO
		player_respawned.emit()
