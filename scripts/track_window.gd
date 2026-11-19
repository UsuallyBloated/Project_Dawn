extends DraggablePanel
class_name TrackWindow

const TRACK_RANGE := 60.0
const REFRESH_INTERVAL := 2.0

@onready var _list: VBoxContainer = $Scroll/List
var _timer: float = 0.0

# The frame is scenes/track_window.tscn; this script fills the list.
func _ready() -> void:
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
