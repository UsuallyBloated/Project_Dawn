extends Node

var _tab_index := 0
var _camera: Camera3D = null
var _player: Node3D = null

func register_camera(cam: Camera3D) -> void:
	_camera = cam

func register_player(node: Node3D) -> void:
	_player = node

func unregister_player() -> void:
	_player = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action("target_cycle") and event.pressed and not event.echo:
		_cycle_target()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_click_target(event.position)

func _click_target(mouse_pos: Vector2) -> void:
	var camera := _camera
	if camera == null:
		return
	var space := camera.get_world_3d().direct_space_state
	var origin := camera.project_ray_origin(mouse_pos)
	var end := origin + camera.project_ray_normal(mouse_pos) * 100.0
	var params := PhysicsRayQueryParameters3D.create(origin, end)
	var result := space.intersect_ray(params)
	if result.is_empty():
		Combat.set_target(null)
		return
	var body = result["collider"]
	if body.is_in_group("enemies") and not body.is_dead:
		Combat.set_target(body)
	elif body is Area3D:
		pass  # interactable (e.g. loot bag) — let its own input_event handle it
	else:
		Combat.set_target(null)

func _cycle_target() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	if enemies.is_empty():
		Combat.set_target(null)
		return
	enemies.sort_custom(func(a, b):
		if not is_instance_valid(_player):
			return false
		return _player.global_position.distance_to(a.global_position) < _player.global_position.distance_to(b.global_position)
	)
	if Combat.current_target == null or not enemies.has(Combat.current_target):
		_tab_index = 0
	else:
		_tab_index = (enemies.find(Combat.current_target) + 1) % enemies.size()
	Combat.set_target(enemies[_tab_index])
