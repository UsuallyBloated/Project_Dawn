extends Node3D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

func _ready() -> void:
	for camp in ZoneData.STARTER_ZONE_CAMPS:
		var mob: Dictionary    = camp["mob"]
		var radius: float      = camp.get("radius",  ZoneData.DEFAULT_RADIUS)
		var respawn: float     = camp.get("respawn", ZoneData.DEFAULT_RESPAWN)
		for pos: Vector3 in camp["spawns"]:
			_place_spawner(pos, mob, radius, respawn)

func _place_spawner(pos: Vector3, mob: Dictionary, radius: float, respawn: float) -> void:
	var s := EnemySpawner.new()
	s.enemy_scene            = ENEMY_SCENE
	s.position               = pos
	s.respawn_time           = respawn
	s.spawn_radius           = radius
	s.mob_name_override      = mob["name"]
	s.level_override         = mob["level"]
	s.max_hp_override        = mob["hp"]
	s.base_damage_override   = mob["dmg"]
	s.xp_reward_override     = mob["xp"]
	s.move_speed_override    = mob["speed"]
	s.aggro_range_override   = mob["aggro"]
	add_child(s)
