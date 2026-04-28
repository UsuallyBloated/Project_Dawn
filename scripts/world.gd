extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var players_container: Node3D = $Players

func _ready() -> void:
	if not Network.is_online:
		_spawn_player(1, Vector3.ZERO)
		return

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id(), Vector3.ZERO)
	else:
		_request_spawn.rpc_id(1)

# Client calls this on the server to request initial spawn data.
@rpc("any_peer", "reliable")
func _request_spawn() -> void:
	if not multiplayer.is_server():
		return
	var new_id := multiplayer.get_remote_sender_id()
	# Send all existing players to the newly connected client only.
	for child in players_container.get_children():
		var existing_id := str(child.name).to_int()
		_spawn_player.rpc_id(new_id, existing_id, child.global_position)
	# Spawn the new player on all peers.
	_spawn_player.rpc(new_id, Vector3.ZERO)

@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int, pos: Vector3) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = pos
	players_container.add_child(player)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		_remove_player.rpc(id)

@rpc("authority", "call_local", "reliable")
func _remove_player(peer_id: int) -> void:
	var player := players_container.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
