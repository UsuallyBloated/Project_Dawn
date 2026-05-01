extends ColorRect

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

	var lbl := Label.new()
	lbl.text = "YOU HAVE DIED\nRespawning..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.anchor_left   = 0.0
	lbl.anchor_top    = 0.0
	lbl.anchor_right  = 1.0
	lbl.anchor_bottom = 1.0
	lbl.offset_left   = 0
	lbl.offset_top    = 0
	lbl.offset_right  = 0
	lbl.offset_bottom = 0
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.20))
	add_child(lbl)

	PlayerDeath.player_died.connect(_show)
	PlayerDeath.player_respawned.connect(_hide)

func _show() -> void:
	visible = true

func _hide() -> void:
	visible = false
