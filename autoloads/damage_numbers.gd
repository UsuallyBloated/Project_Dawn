extends Node

const _Script := preload("res://scripts/damage_number.gd")

func _ready() -> void:
	PlayerStats.healed.connect(spawn_heal)
	PlayerStats.xp_gained.connect(spawn_xp)

func spawn_damage(pos: Vector3, amount: int, is_crit: bool) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_damage:
		return
	_spawn(pos, amount, _Script.Type.CRIT if is_crit else _Script.Type.DAMAGE)

func spawn_incoming(pos: Vector3, amount: int) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_damage:
		return
	_spawn(pos, amount, _Script.Type.INCOMING)

func spawn_miss(pos: Vector3) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_misses:
		return
	_spawn(pos, 0, _Script.Type.MISS)

func spawn_heal(amount: int) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_heals:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_spawn((players[0] as Node3D).global_position, amount, _Script.Type.HEAL)

func spawn_xp(amount: int) -> void:
	if not GameSettings.floating_text_enabled or not GameSettings.floating_text_xp:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_spawn((players[0] as Node3D).global_position, amount, _Script.Type.XP)

func _spawn(pos: Vector3, amount: int, type: DamageNumber.Type) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var lbl := Label3D.new()
	lbl.set_script(_Script)
	lbl.position = pos + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3))
	scene.add_child(lbl)
	lbl.setup(amount, type)
