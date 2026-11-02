extends Node

# Sit / stand bookkeeping for the local player. The server owns regen (its
# regen.rs ticks HP, mana and stamina by level, posture, race and Meditate and
# fans the results), so the client only tells it when the player sits or
# stands, and stands a seated player who takes a target.

var _player: Node3D = null
var _is_sitting: bool = false

func register_player(node: Node3D) -> void:
	_player = node
	if _player.has_signal("state_changed"):
		_player.state_changed.connect(_on_player_state_changed)

func unregister_player() -> void:
	if is_instance_valid(_player) and _player.has_signal("state_changed"):
		if _player.state_changed.is_connected(_on_player_state_changed):
			_player.state_changed.disconnect(_on_player_state_changed)
	_player = null
	_is_sitting = false

func _ready() -> void:
	Combat.target_changed.connect(_on_target_changed)

func _on_player_state_changed(new_state: int) -> void:
	var was_sitting := _is_sitting
	_is_sitting = new_state == PlayerCharacter.PlayerState.SITTING
	# Track 6: forward sit/stand transitions to the server so its regen
	# tick can apply the same multiplier. Only fire on actual transitions
	# to avoid spamming the wire on every state_changed (which also fires
	# for crouch / stand-from-crouch).
	if was_sitting != _is_sitting:
		if _is_sitting:
			Net.broadcast_sit()
		else:
			Net.broadcast_stand()

func _on_target_changed(enemy) -> void:
	if enemy != null and is_instance_valid(enemy) and _is_sitting and is_instance_valid(_player):
		_player.stand()
