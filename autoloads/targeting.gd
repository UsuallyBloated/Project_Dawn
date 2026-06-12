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
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.is_action("target_cycle"):
		_cycle_target()
		return
	# F2–F6 → group members 1–5 (F1/self is handled in the HUD).
	for slot in range(1, 6):
		if event.is_action("target_group_%d" % slot):
			_target_group_slot(slot)
			return

# Target the Nth (1-based) other member of the group, in roster order. Our
# combat targeting is node-based, so a member who isn't loaded in-zone (no
# RemotePlayer node) can't be targeted — we say so rather than silently fail.
func _target_group_slot(slot: int) -> void:
	if not GroupManager.in_group:
		return
	var self_id := Net.get_player_id()
	var others: Array = []
	for m in GroupManager.members:
		var pid: int = int(m.get("peer_id", 0))
		if pid != 0 and pid != self_id:
			others.append(pid)
	if slot < 1 or slot > others.size():
		return
	var node := RemotePlayerManager.get_by_id(others[slot - 1])
	if node == null or not is_instance_valid(node):
		CombatLog.add_line("That group member is not nearby.", CombatLog.MsgType.INFO)
		return
	Combat.set_target(node)

# Select whatever is under `mouse_pos` (viewport coords). Called by the local
# player on a clean left-click — a left *drag* orbits the camera instead, so the
# player script owns the click-vs-drag split and forwards only true clicks here.
func click_target(mouse_pos: Vector2) -> void:
	var camera := _camera
	if camera == null:
		return
	var space := camera.get_world_3d().direct_space_state
	var origin := camera.project_ray_origin(mouse_pos)
	var end := origin + camera.project_ray_normal(mouse_pos) * 100.0
	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.collide_with_areas = true
	var result := space.intersect_ray(params)
	if result.is_empty():
		Combat.set_target(null)
		return
	var body = result["collider"]
	if body.is_in_group("enemies") and not body.is_dead:
		Combat.set_target(body)
	elif body.is_in_group("remote_players") and not body.is_dead:
		Combat.set_target(body)
	elif body.is_in_group("pets") or body.is_in_group("remote_pets"):
		# Targeting own/remote pets is allowed — useful for inspecting
		# pet HP on the target frame and as a base for buff/heal target
		# resolution. Combat.can_attack still gates whether a pet is a
		# legal hostile target (it isn't, by default).
		Combat.set_target(body)
	elif body.is_in_group("vendor_npcs") or body.is_in_group("dialogue_npcs"):
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
