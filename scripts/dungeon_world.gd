extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE  := preload("res://scenes/enemy.tscn")

@export var zone_name: String = "The Dungeon"
@export var enemies_per_room: int = 2
@export var enemy_level: int = 1

@onready var dungeon_spawner: DungeonSpawner = $DungeonSpawner
@onready var players_container: Node3D = $Players


func _ready() -> void:
	ZoneLoader.current_zone_name = zone_name
	ZoneLoader.current_zone_path = scene_file_path

	# See world.gd for context: same dual-gate so launcher-mode sessions
	# get the dev panel too.
	if Network.is_test_room or Net.is_launcher_mode():
		add_child(preload("res://scripts/test_panel.gd").new())

	dungeon_spawner.dungeon_ready.connect(_on_dungeon_ready)
	dungeon_spawner.generate()


func _on_dungeon_ready(layout: DungeonLayout) -> void:
	_seed_enemies(layout)
	_spawn_player(1, _entrance_world_pos(layout))
	ZoneLoader.on_zone_ready()


func _entrance_world_pos(layout: DungeonLayout) -> Vector3:
	var entrance: RoomData = layout.entrance_room()
	if entrance == null:
		return Vector3(0.0, 1.0, 0.0)
	var c: Vector2i = entrance.center_cell()
	return layout.cell_to_world(c.x, c.y) + Vector3(0.0, 1.0, 0.0)


func _seed_enemies(layout: DungeonLayout) -> void:
	for room in layout.rooms:
		var r := room as RoomData
		if r == null or r.room_type == RoomData.RoomType.ENTRANCE:
			continue
		var c: Vector2i = r.center_cell()
		var world_pos: Vector3 = layout.cell_to_world(c.x, c.y)
		for i in enemies_per_room:
			var es := EnemySpawner.new()
			es.enemy_scene = ENEMY_SCENE
			es.respawn_time = 60.0
			es.spawn_radius = 4.0
			if enemy_level > 0:
				es.level_override = enemy_level
			add_child(es)
			es.global_position = world_pos


func _spawn_player(peer_id: int, pos: Vector3) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = pos
	players_container.add_child(player)
