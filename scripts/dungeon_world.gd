extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@export var zone_name: String = "The Dungeon"

@onready var dungeon_spawner: DungeonSpawner = $DungeonSpawner
@onready var players_container: Node3D = $Players


func _ready() -> void:
	ZoneLoader.current_zone_name = zone_name
	ZoneLoader.current_zone_path = scene_file_path

	# The Test Panel mounts for GM accounts only, as in world.gd.
	if Net.is_gm():
		add_child(preload("res://scripts/test_panel.gd").new())

	dungeon_spawner.dungeon_ready.connect(_on_dungeon_ready)
	dungeon_spawner.generate()


func _on_dungeon_ready(layout: DungeonLayout) -> void:
	_spawn_player(1, _entrance_world_pos(layout))
	ZoneLoader.on_zone_ready()


func _entrance_world_pos(layout: DungeonLayout) -> Vector3:
	var entrance: RoomData = layout.entrance_room()
	if entrance == null:
		return Vector3(0.0, 1.0, 0.0)
	var c: Vector2i = entrance.center_cell()
	return layout.cell_to_world(c.x, c.y) + Vector3(0.0, 1.0, 0.0)


func _spawn_player(peer_id: int, pos: Vector3) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = pos
	players_container.add_child(player)
