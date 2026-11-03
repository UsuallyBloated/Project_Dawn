extends Node

# The local player's death state: HP reaching zero (as the server reports it)
# starts the death view, refuses actions the dead cannot take, and after the
# delay sends the Respawn intent. The server decides the death penalty, the
# corpse and where you reappear.

signal player_died
signal player_respawned

const RESPAWN_DELAY := 5.0

var is_dead: bool = false
# Said "You cannot do that while dead." during this death already.
var _told_dead: bool = false

func _ready() -> void:
	PlayerStats.hp_changed.connect(_on_hp_changed)

func _on_hp_changed(current: float, _max: float) -> void:
	if is_dead or current > 0.0:
		return
	_die()

## For actions the dead cannot take (a skill, a spell, auto-attack): true
## while dead, so the caller refuses before anything is sent, announced or put
## on cooldown. Says the line once per death, as the server's gate does.
func refuse_if_dead() -> bool:
	if not is_dead:
		return false
	if not _told_dead:
		CombatLog.add_line("You cannot do that while dead.", CombatLog.MsgType.INFO)
		_told_dead = true
	return true

func _die() -> void:
	is_dead = true
	_told_dead = false
	Combat.set_target(null)
	# Death XP penalty is server-authoritative now (Slice 0): the server applies
	# it in world::progression (5% of the level band, cascading de-level, floor
	# at level 5) and reports it back via XpGained (plus a LevelUp if you
	# de-leveled), which the client mirrors. No local loss computed here.
	# Online the server already knows: HP only reaches zero on the server, and
	# its death sweep has run the death (penalty, corpse, EntityDied to peers)
	# before this client hears HealthUpdate(0). No DeathBroadcast is sent; the
	# server treats that message as a GM command now. _respawn() below sends
	# the Respawn intent once the delay elapses.
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

	# The SERVER decides where you reappear: it teleports you to your bind
	# point (or the starter spawn if unbound) and sends a Teleport, which
	# player.gd applies. Moving the player here as well would be a fight the
	# client loses anyway — the server owns position, so its next Position
	# broadcast overrides whatever we set. That fight is exactly what produced
	# the death loop: the client tried to move you, the server dragged you back
	# to the corpse, and you died again.
	player_respawned.emit()
