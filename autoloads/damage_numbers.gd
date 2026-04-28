extends Node

const DamageNumberScript = preload("res://scripts/damage_number.gd")

func spawn(world_position: Vector3, amount: int, is_player_damage: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var lbl := Label3D.new()
	lbl.set_script(DamageNumberScript)
	var offset := Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3))
	lbl.position = world_position + offset
	scene.add_child(lbl)
	lbl.setup(amount, is_player_damage)
