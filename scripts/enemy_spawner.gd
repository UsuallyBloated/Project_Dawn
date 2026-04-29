class_name EnemySpawner
extends Node3D

@export var enemy_scene: PackedScene = null
@export var respawn_time: float = 30.0
@export var spawn_radius: float = 2.0

@export_group("Mob Config")
@export var mob_name_override: String = ""
@export var level_override: int = 0
@export var max_hp_override: float = 0.0
@export var base_damage_override: int = 0
@export var xp_reward_override: int = 0
@export var move_speed_override: float = 0.0
@export var aggro_range_override: float = 0.0

var _current_enemy: Node3D = null
var _respawn_timer: float = 0.0
var _waiting: bool = false

func _ready() -> void:
	call_deferred("_spawn")

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
	_apply_overrides(enemy)
	var offset := Vector3(
		randf_range(-spawn_radius, spawn_radius),
		0.0,
		randf_range(-spawn_radius, spawn_radius)
	)
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = global_position + offset
	_current_enemy = enemy
	enemy.died.connect(_on_enemy_died)

func _apply_overrides(enemy: Node3D) -> void:
	if mob_name_override != "":
		enemy.mob_name = mob_name_override
	if level_override > 0:
		enemy.level = level_override
	if max_hp_override > 0.0:
		enemy.max_hp = max_hp_override
	if base_damage_override > 0:
		enemy.base_damage = base_damage_override
	if xp_reward_override > 0:
		enemy.xp_reward = xp_reward_override
	if move_speed_override > 0.0:
		enemy.move_speed = move_speed_override
	if aggro_range_override > 0.0:
		enemy.aggro_range = aggro_range_override

func _on_enemy_died(_enemy) -> void:
	_current_enemy = null
	_waiting = true
	_respawn_timer = respawn_time
