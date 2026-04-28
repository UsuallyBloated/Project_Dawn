class_name EnemySpawner
extends Node3D

@export var enemy_scene: PackedScene = null
@export var respawn_time: float = 30.0
@export var spawn_radius: float = 2.0

var _current_enemy: Node3D = null
var _respawn_timer: float = 0.0
var _waiting: bool = false

func _ready() -> void:
	_spawn()

func _process(delta: float) -> void:
	if not _waiting:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_waiting = false
		_spawn()

func _spawn() -> void:
	if enemy_scene == null:
		return
	var enemy: Node3D = enemy_scene.instantiate()
	var offset := Vector3(
		randf_range(-spawn_radius, spawn_radius),
		0.0,
		randf_range(-spawn_radius, spawn_radius)
	)
	enemy.global_position = global_position + offset
	get_tree().current_scene.add_child(enemy)
	_current_enemy = enemy
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(_enemy) -> void:
	_current_enemy = null
	_waiting = true
	_respawn_timer = respawn_time
