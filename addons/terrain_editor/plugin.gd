@tool
extends EditorPlugin

var _terrain = null
var _camera: Camera3D = null
var _dragging := false
var _drag_vx := -1
var _drag_vz := -1
var _drag_start_mouse_y := 0.0
var _drag_start_h := 0.0
var _hover_vx := -1
var _hover_vz := -1

const PICK_RADIUS := 18.0

func _get_plugin_name() -> String:
	return "Terrain Editor"

func _handles(object) -> bool:
	return object is Node3D and object.has_method("get_height") and object.has_method("set_height")

func _make_visible(visible: bool) -> void:
	if not visible:
		_terrain = null
		_dragging = false
		update_overlays()

func _edit(object) -> void:
	_terrain = object
	_dragging = false
	update_overlays()

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	_camera = camera
	if _terrain == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.ctrl_pressed and not mb.shift_pressed:
			if mb.pressed:
				var hit := _pick_vertex(mb.position)
				if hit.x >= 0:
					_dragging = true
					_drag_vx = hit.x
					_drag_vz = hit.y
					_drag_start_mouse_y = mb.position.y
					_drag_start_h = _terrain.get_height(hit.x, hit.y)
					update_overlays()
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				if _dragging:
					_dragging = false
					update_overlays()
					return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			var delta_h := (_drag_start_mouse_y - mm.position.y) * 0.1
			_terrain.set_height(_drag_vx, _drag_vz, _drag_start_h + delta_h)
			update_overlays()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			var hit := _pick_vertex(mm.position)
			_hover_vx = hit.x
			_hover_vz = hit.y
			update_overlays()

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if _terrain == null or _camera == null:
		return

	var gs: int = _terrain.grid_size

	for z in range(gs + 1):
		for x in range(gs + 1):
			var wp: Vector3 = _terrain.get_vertex_world_pos(x, z)
			if _camera.is_position_behind(wp):
				continue
			var sp := _camera.unproject_position(wp)

			var is_hover := (x == _hover_vx and z == _hover_vz)
			var is_active := (_dragging and x == _drag_vx and z == _drag_vz)

			if is_active:
				overlay.draw_circle(sp, 6.0, Color.YELLOW)
			elif is_hover:
				overlay.draw_circle(sp, 5.0, Color.WHITE)
			else:
				overlay.draw_circle(sp, 3.0, Color(0.3, 0.9, 0.4, 0.7))

func _pick_vertex(mouse_pos: Vector2) -> Vector2i:
	if _terrain == null or _camera == null:
		return Vector2i(-1, -1)

	var gs: int = _terrain.grid_size
	var best_dist := PICK_RADIUS
	var best := Vector2i(-1, -1)

	for z in range(gs + 1):
		for x in range(gs + 1):
			var wp: Vector3 = _terrain.get_vertex_world_pos(x, z)
			if _camera.is_position_behind(wp):
				continue
			var sp := _camera.unproject_position(wp)
			var d := sp.distance_to(mouse_pos)
			if d < best_dist:
				best_dist = d
				best = Vector2i(x, z)

	return best
