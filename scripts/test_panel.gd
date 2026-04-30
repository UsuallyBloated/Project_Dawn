extends CanvasLayer

var _race_opt: OptionButton
var _class_opt: OptionButton
var _level_lbl: Label
var _body: VBoxContainer
var _toggle_btn: Button
var _collapsed: bool = false

const C_BG     := Color(0.10, 0.08, 0.06, 0.93)
const C_BORDER := Color(0.80, 0.60, 0.20, 1.00)
const C_TITLE  := Color(0.90, 0.75, 0.30, 1.00)
const C_TEXT   := Color(0.75, 0.70, 0.60, 1.00)
const C_DIE    := Color(0.70, 0.15, 0.15, 1.00)

func _ready() -> void:
	layer = 10
	_build_ui()
	_populate_options()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size.x = 230
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 8
	style.content_margin_top    = 6
	style.content_margin_right  = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "TEST ROOM"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", C_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_toggle_btn = Button.new()
	_toggle_btn.text = "−"
	_toggle_btn.custom_minimum_size = Vector2(24, 24)
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(_toggle_collapse)
	header.add_child(_toggle_btn)

	# Body (collapsible)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	vbox.add_child(_body)

	_body.add_child(_make_label("Race"))
	_race_opt = OptionButton.new()
	_race_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_opt.focus_mode = Control.FOCUS_NONE
	_body.add_child(_race_opt)

	_body.add_child(_make_label("Class"))
	_class_opt = OptionButton.new()
	_class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_opt.focus_mode = Control.FOCUS_NONE
	_body.add_child(_class_opt)

	# Level row
	_body.add_child(_make_label("Level"))
	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 4)
	_body.add_child(lvl_row)

	var btn_minus := _make_step_btn("−")
	btn_minus.pressed.connect(_change_level.bind(-1))
	lvl_row.add_child(btn_minus)

	_level_lbl = Label.new()
	_level_lbl.text = "1"
	_level_lbl.add_theme_font_size_override("font_size", 14)
	_level_lbl.add_theme_color_override("font_color", C_TITLE)
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_row.add_child(_level_lbl)

	var btn_plus := _make_step_btn("+")
	btn_plus.pressed.connect(_change_level.bind(1))
	lvl_row.add_child(btn_plus)

	var apply_btn := _make_btn("Apply Race / Class / Level", C_BORDER)
	apply_btn.pressed.connect(_apply_race_class)
	_body.add_child(apply_btn)

	_body.add_child(HSeparator.new())

	var heal_btn := _make_btn("Full Heal", Color(0.20, 0.55, 0.20, 1.0))
	heal_btn.pressed.connect(_full_heal)
	_body.add_child(heal_btn)

	var die_btn := _make_btn("Trigger Death", C_DIE)
	die_btn.pressed.connect(_trigger_death)
	_body.add_child(die_btn)

func _make_label(t: String) -> Label:
	var lbl := Label.new()
	lbl.text = t
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_TEXT)
	return lbl

func _make_step_btn(t: String) -> Button:
	var btn := Button.new()
	btn.text = t
	btn.custom_minimum_size = Vector2(30, 28)
	btn.focus_mode = Control.FOCUS_NONE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.14, 0.08, 1.0)
	s.border_color = C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("focus", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.30, 0.22, 0.10, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", C_TITLE)
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func _make_btn(t: String, border: Color) -> Button:
	var btn := Button.new()
	btn.text = t
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(border.r * 0.25, border.g * 0.25, border.b * 0.25, 1.0)
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 8
	s.content_margin_top    = 5
	s.content_margin_right  = 8
	s.content_margin_bottom = 5
	for state in ["normal", "focus"]:
		btn.add_theme_stylebox_override(state, s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(border.r * 0.4, border.g * 0.4, border.b * 0.4, 1.0)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	return btn

func _populate_options() -> void:
	for race in CharacterData.RACES:
		_race_opt.add_item(race)
	for cls in CharacterData.CLASSES:
		_class_opt.add_item(cls)

	var race_idx := CharacterData.RACES.find(PlayerStats.race)
	if race_idx >= 0:
		_race_opt.select(race_idx)
	var cls_idx := CharacterData.CLASSES.find(PlayerStats.player_class)
	if cls_idx >= 0:
		_class_opt.select(cls_idx)

	_level_lbl.text = str(PlayerStats.level)

func _toggle_collapse() -> void:
	_collapsed = !_collapsed
	_body.visible = !_collapsed
	_toggle_btn.text = "+" if _collapsed else "−"

func _apply_race_class() -> void:
	PlayerStats.apply_character(
		CharacterData.RACES[_race_opt.selected],
		CharacterData.CLASSES[_class_opt.selected],
		PlayerStats.level)

func _change_level(delta: int) -> void:
	var new_lvl := clampi(PlayerStats.level + delta, 1, 99)
	if new_lvl == PlayerStats.level:
		return
	PlayerStats.apply_character(PlayerStats.race, PlayerStats.player_class, new_lvl)
	_level_lbl.text = str(PlayerStats.level)

func _full_heal() -> void:
	PlayerStats.set_hp(PlayerStats.max_hp)
	PlayerStats.set_mp(PlayerStats.max_mp)
	PlayerStats.set_stamina(PlayerStats.max_stamina)

func _trigger_death() -> void:
	PlayerStats.set_hp(0.0)
