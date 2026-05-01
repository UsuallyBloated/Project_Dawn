extends DraggablePanel
class_name TrackWindow

const TRACK_RANGE := 60.0
const REFRESH_INTERVAL := 2.0

var _list: VBoxContainer
var _timer: float = 0.0

func _ready() -> void:
	anchor_left   = 1.0
	anchor_right  = 1.0
	anchor_top    = 0.0
	anchor_bottom = 0.0
	offset_left   = -200
	offset_right  = -10
	offset_top    = 60
	offset_bottom = 300

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.04, 0.04, 0.06, 0.90)
	style.border_color = Color(0.30, 0.55, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.text = "Track"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.55, 0.90, 0.45))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 4
	title.offset_bottom = 20
	title.offset_left = 8
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 22
	scroll.offset_left = 4
	scroll.offset_right = -4
	scroll.offset_bottom = -4
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_list)

	visible = false
	_refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= REFRESH_INTERVAL:
		_timer = 0.0
		_refresh()

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var entries: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var dist: float = player.global_position.distance_to(enemy.global_position)
		if dist <= TRACK_RANGE:
			entries.append({name = enemy.mob_name, dist = dist, level = enemy.level})

	entries.sort_custom(func(a, b): return a.dist < b.dist)

	for e in entries:
		var row := Label.new()
		row.text = "%s (L%d)  %.0fm" % [e.name, e.level, e.dist]
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", Color(0.85, 0.85, 0.80))
		_list.add_child(row)

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Nothing nearby."
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50))
		_list.add_child(empty)

func toggle() -> void:
	visible = not visible
	if visible:
		_timer = REFRESH_INTERVAL
