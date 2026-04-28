extends Panel
class_name DraggablePanel

# Drag-on-background: _gui_input fires when the click isn't absorbed by an
# interactive child (button, slot, etc.), so any click on empty panel space
# starts a drag without interfering with child controls.

var _dragging := false
var _drag_offset := Vector2.ZERO
var _anchors_reset := false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag()
		else:
			_dragging = false

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_do_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false

func _start_drag() -> void:
	if not _anchors_reset:
		_anchors_reset = true
		var abs_pos := global_position
		var abs_size := size
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 0.0
		anchor_bottom = 0.0
		offset_left = abs_pos.x
		offset_top = abs_pos.y
		offset_right = abs_pos.x + abs_size.x
		offset_bottom = abs_pos.y + abs_size.y
	_dragging = true
	_drag_offset = get_global_mouse_position() - global_position

func _do_drag() -> void:
	var new_pos := get_global_mouse_position() - _drag_offset
	var vp := get_viewport_rect().size
	new_pos.x = clampf(new_pos.x, 0.0, vp.x - size.x)
	new_pos.y = clampf(new_pos.y, 0.0, vp.y - size.y)
	position = new_pos

# Builds a standard tooltip panel and attaches it as a child. Returns [Panel, Label].
func _make_tooltip() -> Array:
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

func _find_meta_child(parent: Node, meta_key: String) -> Node:
	for child in parent.get_children():
		if child.has_meta(meta_key):
			return child
	return null
