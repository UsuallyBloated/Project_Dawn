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

@export_group("Caster Overrides")
@export var spell_damage_override:    int   = 0
@export var spell_interval_override:  float = 0.0
@export var caster_range_override:    float = 0.0
@export var spell_damage_type_override: SpellData.DamageType = SpellData.DamageType.NONE

@export_group("Healer Overrides")
@export var healer_flee_hp_override: float = 0.0
@export var heal_amount_override:    float = 0.0
@export var heal_interval_override:  float = 0.0

@export_group("Named Mob")
@export var named_mob_id: String = ""
@export var named_respawn_time: float = 300.0   # seconds; replaces respawn_time for named spawns

@export_group("Spawn Conditions")
@export var night_only: bool = false

@export_group("Resist Overrides")
@export var fire_resist:      float = -1.0
@export var ice_resist:       float = -1.0
@export var lightning_resist: float = -1.0
@export var arcane_resist:    float = -1.0
@export var holy_resist:      float = -1.0
@export var nature_resist:    float = -1.0
@export var spirit_resist:    float = -1.0
@export var shadow_resist:    float = -1.0

var _current_enemy: Node3D = null
var _respawn_timer: float = 0.0
var _waiting: bool = false

func _is_night() -> bool:
	var h := TimeOfDay.get_hour()
	return h >= 20 or h < 6

func _ready() -> void:
	TimeOfDay.hour_changed.connect(_on_hour_changed)
	call_deferred("_spawn")

func _process(delta: float) -> void:
	if not _waiting:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_waiting = false
		_spawn()

func _on_hour_changed(hour: int) -> void:
	if not night_only:
		return
	if hour == 20 and _current_enemy == null and not _waiting:
		_spawn()
	elif hour == 6 and is_instance_valid(_current_enemy):
		_current_enemy.queue_free()
		_current_enemy = null
		_waiting = false

func _spawn() -> void:
	if enemy_scene == null:
		return
	if night_only and not _is_night():
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
	if named_mob_id != "":
		enemy.apply_named(named_mob_id)
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
	if spell_damage_override > 0:
		enemy.spell_damage = spell_damage_override
	if spell_interval_override > 0.0:
		enemy.spell_interval = spell_interval_override
	if caster_range_override > 0.0:
		enemy.caster_range = caster_range_override
	if spell_damage_type_override != SpellData.DamageType.NONE:
		enemy.spell_damage_type = spell_damage_type_override
	if healer_flee_hp_override > 0.0:
		enemy.healer_flee_hp = healer_flee_hp_override
	if heal_amount_override > 0.0:
		enemy.heal_amount = heal_amount_override
	if heal_interval_override > 0.0:
		enemy.heal_interval = heal_interval_override
	for field in ["fire_resist", "ice_resist", "lightning_resist", "arcane_resist",
			"holy_resist", "nature_resist", "spirit_resist", "shadow_resist"]:
		if get(field) >= 0.0:
			enemy.set(field, get(field))

func _on_enemy_died(_enemy) -> void:
	_current_enemy = null
	_waiting = true
	_respawn_timer = named_respawn_time if named_mob_id != "" else respawn_time
