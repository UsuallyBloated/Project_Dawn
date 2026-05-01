class_name SpellBook
extends DraggablePanel

const C_BG   := Color(0.07, 0.06, 0.04, 0.95)
const C_ROW  := Color(0.12, 0.10, 0.07, 1.00)
const C_HOVER := Color(0.20, 0.16, 0.10, 1.00)
const ROW_H  := 28

var _vbox: VBoxContainer = null
var _rows: Array = []

func _ready() -> void:
	_build()
	Spells.spells_changed.connect(_rebuild)
	_rebuild()

func _build() -> void:
	custom_minimum_size = Vector2(300, 320)
	position = Vector2(220, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = UITheme.C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 4)
	outer.offset_left = 8; outer.offset_top = 8
	outer.offset_right = -8; outer.offset_bottom = -8
	add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)

	var title := Label.new()
	title.text = "Spellbook"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	outer.add_child(HSeparator.new())

	var col_row := HBoxContainer.new()
	col_row.add_theme_constant_override("separation", 4)
	outer.add_child(col_row)
	_add_col_hdr(col_row, "Spell", 0, true)
	_add_col_hdr(col_row, "MP",   36, false)
	_add_col_hdr(col_row, "CD",   44, false)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_vbox)

func _add_col_hdr(parent: HBoxContainer, text: String, min_w: float, expand: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	if min_w > 0:
		lbl.custom_minimum_size.x = min_w
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)

func _rebuild() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for spell in Spells.available:
		var row := _make_row(spell)
		_vbox.add_child(row)
		_rows.append(row)

func _make_row(spell: SpellData) -> Panel:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = C_ROW
	normal_style.set_corner_radius_all(2)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_HOVER
	hover_style.set_corner_radius_all(2)

	var bg := Panel.new()
	bg.custom_minimum_size.y = ROW_H
	bg.add_theme_stylebox_override("panel", normal_style)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.tooltip_text = "%s\n%s\nMP: %d  Cast: %s  CD: %s" % [
		spell.spell_name, spell.description, int(spell.mana_cost),
		("%.1fs" % spell.cast_time) if spell.cast_time > 0.0 else "instant",
		("%.0fs" % spell.cooldown) if spell.cooldown > 0.0 else "—",
	]

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4; row.offset_top = 2
	row.offset_right = -4; row.offset_bottom = -2
	row.add_theme_constant_override("separation", 4)
	bg.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = spell.spell_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	var mp_lbl := Label.new()
	mp_lbl.text = "%d" % int(spell.mana_cost)
	mp_lbl.custom_minimum_size.x = 36
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_lbl.add_theme_font_size_override("font_size", 11)
	mp_lbl.add_theme_color_override("font_color", Color(0.45, 0.60, 1.00))
	row.add_child(mp_lbl)

	var cd_lbl := Label.new()
	cd_lbl.text = ("%.0fs" % spell.cooldown) if spell.cooldown > 0.0 else "—"
	cd_lbl.custom_minimum_size.x = 44
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cd_lbl.add_theme_font_size_override("font_size", 11)
	cd_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	row.add_child(cd_lbl)

	bg.mouse_entered.connect(func(): bg.add_theme_stylebox_override("panel", hover_style))
	bg.mouse_exited.connect(func(): bg.add_theme_stylebox_override("panel", normal_style))
	bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Spells.cast_spell(spell)
			bg.accept_event())

	return bg
