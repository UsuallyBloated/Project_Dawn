extends Panel
class_name DraggablePanel

const RESIZE_MARGIN := 6
const MIN_SIZE := Vector2(120.0, 60.0)

var _dragging := false
var _drag_offset := Vector2.ZERO
var _anchors_reset := false

var _resizing := false
var _resize_dir := Vector2.ZERO
var _resize_start_mouse := Vector2.ZERO
var _resize_start_pos := Vector2.ZERO
var _resize_start_size := Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _resizing:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _dragging and not _resizing:
		_update_cursor(_get_resize_dir(event.position))

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var dir := _get_resize_dir(event.position)
			if dir != Vector2.ZERO:
				_start_resize(dir)
			else:
				_start_drag()
		else:
			_stop_interaction()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_interaction()
		return
	if not _dragging and not _resizing:
		return
	if event is InputEventMouseMotion:
		if _dragging:
			_do_drag()
		elif _resizing:
			_do_resize()

func _stop_interaction() -> void:
	_dragging = false
	_resizing = false
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)

func _get_resize_dir(mouse_local: Vector2) -> Vector2:
	var dir := Vector2.ZERO
	if mouse_local.x < RESIZE_MARGIN:
		dir.x = -1
	elif mouse_local.x > size.x - RESIZE_MARGIN:
		dir.x = 1
	if mouse_local.y < RESIZE_MARGIN:
		dir.y = -1
	elif mouse_local.y > size.y - RESIZE_MARGIN:
		dir.y = 1
	return dir

func _update_cursor(dir: Vector2) -> void:
	if dir.x != 0 and dir.y != 0:
		DisplayServer.cursor_set_shape(
			DisplayServer.CURSOR_FDIAGSIZE if dir.x == dir.y else DisplayServer.CURSOR_BDIAGSIZE
		)
	elif dir.x != 0:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_HSIZE)
	elif dir.y != 0:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_VSIZE)
	else:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)

func _ensure_anchors_reset() -> void:
	if _anchors_reset:
		return
	_anchors_reset = true
	var abs_pos := global_position
	var abs_size := size
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 0.0; anchor_bottom = 0.0
	offset_left = abs_pos.x; offset_top = abs_pos.y
	offset_right = abs_pos.x + abs_size.x; offset_bottom = abs_pos.y + abs_size.y

func _start_drag() -> void:
	_ensure_anchors_reset()
	_dragging = true
	_drag_offset = get_global_mouse_position() - global_position

func _start_resize(dir: Vector2) -> void:
	_ensure_anchors_reset()
	_resizing = true
	_resize_dir = dir
	_resize_start_mouse = get_global_mouse_position()
	_resize_start_pos = global_position
	_resize_start_size = size
	_update_cursor(dir)

func _do_drag() -> void:
	var new_pos := get_global_mouse_position() - _drag_offset
	var vp := get_viewport_rect().size
	new_pos.x = clampf(new_pos.x, 0.0, vp.x - size.x)
	new_pos.y = clampf(new_pos.y, 0.0, vp.y - size.y)
	position = new_pos

func _do_resize() -> void:
	var delta := get_global_mouse_position() - _resize_start_mouse
	var vp := get_viewport_rect().size
	var new_pos := _resize_start_pos
	var new_size := _resize_start_size

	if _resize_dir.x == -1:
		new_size.x = maxf(MIN_SIZE.x, _resize_start_size.x - delta.x)
		new_pos.x = _resize_start_pos.x + (_resize_start_size.x - new_size.x)
	elif _resize_dir.x == 1:
		new_size.x = maxf(MIN_SIZE.x, _resize_start_size.x + delta.x)

	if _resize_dir.y == -1:
		new_size.y = maxf(MIN_SIZE.y, _resize_start_size.y - delta.y)
		new_pos.y = _resize_start_pos.y + (_resize_start_size.y - new_size.y)
	elif _resize_dir.y == 1:
		new_size.y = maxf(MIN_SIZE.y, _resize_start_size.y + delta.y)

	new_pos.x = clampf(new_pos.x, 0.0, vp.x - MIN_SIZE.x)
	new_pos.y = clampf(new_pos.y, 0.0, vp.y - MIN_SIZE.y)
	new_size.x = minf(new_size.x, vp.x - new_pos.x)
	new_size.y = minf(new_size.y, vp.y - new_pos.y)

	position = new_pos
	size = new_size

# Public API: build a standard tooltip panel attached as a child. Returns [Panel, Label].
func make_tooltip() -> Array:
	var panel := Panel.new()
	panel.visible = false
	panel.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.C_TOOLTIP
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UITheme.C_TEXT)
	panel.add_child(label)
	add_child(panel)
	return [panel, label]

func _append_stat_lines(item: ItemData, lines: Array) -> void:
	var checks := [
		["bonus_strength", "STR"], ["bonus_dexterity", "DEX"], ["bonus_agility", "AGI"],
		["bonus_intelligence", "INT"], ["bonus_wisdom", "WIS"], ["bonus_charisma", "CHA"],
		["bonus_constitution", "CON"], ["bonus_max_hp", "Max HP"],
		["bonus_max_mp", "Max MP"], ["bonus_max_stamina", "Max ST"],
	]
	for pair in checks:
		var val = item.get(pair[0])
		if val != 0:
			lines.append(("%s +%s" if val > 0 else "%s %s") % [pair[1], val])
	if item.heal_on_use > 0.0:
		lines.append("Use: Restores %d HP" % int(item.heal_on_use))
	if item.mp_on_use > 0.0:
		lines.append("Use: Restores %d MP" % int(item.mp_on_use))

func _find_meta_child(parent: Node, meta_key: String) -> Node:
	for child in parent.get_children():
		if child.has_meta(meta_key):
			return child
	return null
