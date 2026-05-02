class_name MobileCharacter
extends CharacterBody3D

func _move_at_speed(target_pos: Vector3, speed: float) -> void:
	var dir := (target_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_toward(target_pos)

func _face_toward(target_pos: Vector3) -> void:
	var look_pos := Vector3(target_pos.x, global_position.y, target_pos.z)
	if look_pos.distance_to(global_position) > 0.01:
		look_at(look_pos, Vector3.UP)
