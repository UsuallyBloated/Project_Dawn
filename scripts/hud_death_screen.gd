extends ColorRect

var _lbl: Label

func _ready() -> void:
	color = Color(0.4, 0.0, 0.0, 0.55)
	anchor_left   = 0.0
	anchor_top    = 0.0
	anchor_right  = 1.0
	anchor_bottom = 1.0
	offset_left   = 0
	offset_top    = 0
	offset_right  = 0
	offset_bottom = 0
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.anchor_left   = 0.0
	_lbl.anchor_top    = 0.0
	_lbl.anchor_right  = 1.0
	_lbl.anchor_bottom = 1.0
	_lbl.offset_left   = 0
	_lbl.offset_top    = 0
	_lbl.offset_right  = 0
	_lbl.offset_bottom = 0
	_lbl.add_theme_font_size_override("font_size", 36)
	_lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.20))
	add_child(_lbl)

	PlayerDeath.player_died.connect(_show)
	PlayerDeath.player_respawned.connect(_hide)

func _show() -> void:
	var zone := PlayerStats.bind_zone_name
	var dest := ("Returning to %s..." % zone) if zone != "" else "Respawning..."
	_lbl.text = "YOU HAVE DIED\n" + dest
	visible = true

func _hide() -> void:
	visible = false
