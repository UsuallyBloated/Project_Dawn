extends Node3D

# The world scene's root: names the zone for ZoneLoader, spawns the local
# player, and mounts the Test Panel for GM accounts. Everyone else in the
# world (players, mobs, pets, loot) arrives from the server through the
# Remote*Manager autoloads.

# Set this in the Inspector for each zone scene.
@export var zone_name: String = "Ashfield Ruins"

const PLAYER_SCENE  := preload("res://scenes/player.tscn")
const TEST_PANEL_GD := preload("res://scripts/test_panel.gd")
# The local player's node name under $Players.
const LOCAL_PLAYER_NODE_NAME := "1"

@onready var players_container: Node3D = $Players

func _ready() -> void:
	ZoneLoader.current_zone_name = zone_name
	ZoneLoader.current_zone_path = scene_file_path

	# The Test Panel mounts for GM accounts only. Phase 2: it used to mount for
	# EVERY session, so an invited friend saw a gold-bordered overlay with
	# Spawn Mob / Level Up / Trigger Death. The server gates every power it
	# offers on the is_gm bit in the signed token regardless.
	if Net.is_gm():
		add_child(TEST_PANEL_GD.new())

	_spawn_player(ZoneLoader.get_spawn_position())
	ZoneLoader.on_zone_ready()

func _spawn_player(pos: Vector3) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = LOCAL_PLAYER_NODE_NAME
	player.position = pos
	players_container.add_child(player)
