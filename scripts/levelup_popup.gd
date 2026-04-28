extends CanvasLayer

const DISPLAY_TIME := 3.5
const RISE_PX      := 40.0

var _label: Label = null
var _age: float = 0.0
var _active: bool = false
var _start_y: float = 0.0

func _ready() -> void:
	_label = Label.new()
	_label.text = "LEVEL UP!"
	_label.add_theme_font_size_override("font_size", 42)
	_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.25))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_left  = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top   = 0.5
	_label.anchor_bottom = 0.5
	_label.visible = false
	add_child(_label)

	PlayerStats.level_changed.connect(_on_level_up)

func _on_level_up(new_level: int) -> void:
	_label.text = "LEVEL UP!  Level %d" % new_level
	_label.size = Vector2.ZERO
	_label.offset_left  = -200
	_label.offset_right =  200
	_start_y = -80.0
	_label.offset_top    = _start_y
	_label.offset_bottom = _start_y + 60
	_label.modulate = Color(0.95, 0.78, 0.25, 1.0)
	_label.visible = true
	_age = 0.0
	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var t := _age / DISPLAY_TIME
	_label.offset_top    = _start_y - RISE_PX * t
	_label.offset_bottom = _label.offset_top + 60

	if _age > DISPLAY_TIME * 0.6:
		var fade := 1.0 - (_age - DISPLAY_TIME * 0.6) / (DISPLAY_TIME * 0.4)
		_label.modulate.a = clampf(fade, 0.0, 1.0)

	if _age >= DISPLAY_TIME:
		_label.visible = false
		_active = false
