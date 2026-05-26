extends Control

# ── Colors ─────────────────────────────────────────────────────────────────────

const C_BG                      := UITheme.C_SCREEN_BG
const C_PANEL                   := UITheme.C_PANEL_BG
const C_BORDER                  := UITheme.C_BORDER
const C_TEXT                    := UITheme.C_TEXT
const C_TITLE                   := UITheme.C_TITLE
const C_SELECTED                := UITheme.C_SELECTED
const C_BTN_NORM                := UITheme.C_BTN_NORM
const C_BTN_HOVER               := UITheme.C_BTN_HOVER
const C_POS                     := UITheme.C_POSITIVE
const C_NEG                     := UITheme.C_NEGATIVE
const C_NEUTRAL                 := UITheme.C_NEUTRAL
const C_GOLDEN_BORDER           := UITheme.C_GOLDEN_BORDER
const C_BTN_LOCKED_BG           := UITheme.C_BTN_LOCKED_BG
const C_BTN_LOCKED_BORDER       := UITheme.C_BTN_LOCKED_BORDER
const C_BTN_LOCKED_TEXT         := UITheme.C_BTN_LOCKED_TEXT
const C_CONFIRM_BG              := UITheme.C_CONFIRM_BG
const C_CONFIRM_BG_HOVER        := UITheme.C_CONFIRM_BG_HOVER
const C_CONFIRM_BG_DISABLED     := UITheme.C_CONFIRM_BG_DISABLED
const C_CONFIRM_BORDER_DISABLED := UITheme.C_CONFIRM_BORDER_DISABLED

# ── State ──────────────────────────────────────────────────────────────────────

var selected_race: String = ""
var selected_class: String = ""
var _race_btns: Dictionary = {}
var _class_btns: Dictionary = {}
var _stat_labels: Dictionary = {}
var _res_labels: Dictionary = {}
var _identity_lbl: Label
var _race_desc_lbl: Label
var _class_desc_lbl: Label
var _confirm_btn: Button
var _name_input: LineEdit

# ── Build ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	ChatWindowManager.visible = false

	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.offset_left = 40
	root.offset_top = 16
	root.offset_right = -40
	root.offset_bottom = -16
	add_child(root)

	root.add_child(_make_label("PROJECT DAWN", 36, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(_make_label("Choose Your Path", 13, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	root.add_child(cols)

	_build_selection_panel(cols, "— RACE —", CharacterData.RACES, _race_btns, _on_race_selected)
	_build_center_panel(cols)
	_build_selection_panel(cols, "— CLASS —", CharacterData.CLASSES, _class_btns, _on_class_selected)

	root.add_child(HSeparator.new())
	_build_bottom_bar(root)


func _build_selection_panel(parent: Control, header: String, items: Array, btns: Dictionary, callback: Callable) -> void:
	var pc := _make_panel_container(true)
	parent.add_child(pc)

	var margin := _make_margin(pc, 10)
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	vbox.add_child(_make_label(header, 14, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var btn_box := VBoxContainer.new()
	btn_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_box.add_theme_constant_override("separation", 4)
	scroll.add_child(btn_box)

	for item in items:
		var btn := _make_select_btn(item)
		btn.pressed.connect(callback.bind(item))
		btn_box.add_child(btn)
		btns[item] = btn


func _build_center_panel(parent: Control) -> void:
	var pc := _make_panel_container(false)
	pc.custom_minimum_size.x = 260
	parent.add_child(pc)

	var margin := _make_margin(pc, 10)
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Portrait frame — art drops in here later
	var portrait := PanelContainer.new()
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.custom_minimum_size = Vector2(0, 180)
	var ps := StyleBoxFlat.new()
	ps.bg_color        = Color(0.04, 0.03, 0.02, 1.0)
	ps.border_color    = C_GOLDEN_BORDER
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(2)
	portrait.add_theme_stylebox_override("panel", ps)
	var cc := CenterContainer.new()
	portrait.add_child(cc)
	cc.add_child(_make_label("[ Portrait ]", 13, C_BORDER, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(portrait)

	# Race · Class identity line
	_identity_lbl = _make_label("Select Race & Class", 15, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_identity_lbl)

	# Character name input
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_row)
	name_row.add_child(_make_label("Name:", 12, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT))

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.add_theme_font_size_override("font_size", 13)
	_name_input.add_theme_color_override("font_color", C_TEXT)
	_name_input.add_theme_color_override("font_placeholder_color", C_BORDER)
	var le_norm := StyleBoxFlat.new()
	le_norm.bg_color = C_PANEL
	le_norm.border_color = C_BORDER
	le_norm.set_border_width_all(1)
	le_norm.set_corner_radius_all(3)
	le_norm.content_margin_left = 6
	le_norm.content_margin_top = 4
	le_norm.content_margin_right = 6
	le_norm.content_margin_bottom = 4
	_name_input.add_theme_stylebox_override("normal", le_norm)
	var le_focus := le_norm.duplicate() as StyleBoxFlat
	le_focus.border_color = C_TITLE
	_name_input.add_theme_stylebox_override("focus", le_focus)
	_name_input.text_changed.connect(func(_t: String): _update_confirm())
	name_row.add_child(_name_input)

	vbox.add_child(HSeparator.new())

	# Race description
	_race_desc_lbl = _make_label("", 11, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_race_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_desc_lbl.custom_minimum_size.y = 34
	vbox.add_child(_race_desc_lbl)

	# Class description
	_class_desc_lbl = _make_label("", 11, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_class_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_desc_lbl.custom_minimum_size.y = 34
	vbox.add_child(_class_desc_lbl)


func _build_bottom_bar(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	parent.add_child(hbox)

	# Stats block
	var stats_pc := _make_panel_container(false)
	stats_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(stats_pc)
	var sm := _make_margin(stats_pc, 8)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sm.add_child(sv)

	var attr_row := HBoxContainer.new()
	attr_row.add_theme_constant_override("separation", 0)
	sv.add_child(attr_row)
	for i in CharacterData.STAT_KEYS.size():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		attr_row.add_child(col)
		col.add_child(_make_label(CharacterData.STAT_SHORT[i], 10, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var val_lbl := _make_label(str(CharacterData.BASE), 13, C_NEUTRAL, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(val_lbl)
		_stat_labels[CharacterData.STAT_KEYS[i]] = val_lbl

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 20)
	sv.add_child(res_row)
	for pair: Array in [["HP", "hp"], ["MP", "mp"], ["ST", "st"]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		res_row.add_child(r)
		r.add_child(_make_label(pair[0] + ":", 11, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		var val := _make_label("—", 11, C_NEUTRAL, HORIZONTAL_ALIGNMENT_LEFT)
		r.add_child(val)
		_res_labels[pair[1]] = val

	# Confirm button
	var confirm_wrap := CenterContainer.new()
	confirm_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(confirm_wrap)
	_confirm_btn = _make_confirm_btn()
	confirm_wrap.add_child(_confirm_btn)

# ── Selection ──────────────────────────────────────────────────────────────────

func _on_race_selected(race_id: String) -> void:
	selected_race = race_id
	for r in CharacterData.RACES:
		_style_btn(_race_btns[r], r == race_id)
	_race_desc_lbl.text = CharacterData.RACE_DATA[race_id]["desc"]
	_update_identity()
	_update_class_locks(race_id)
	_refresh_stats()
	_update_confirm()


func _on_class_selected(cls: String) -> void:
	selected_class = cls
	var locked_for_race := CharacterData.LOCKED_COMBOS.get(selected_race, []) as Array
	for c in CharacterData.CLASSES:
		if not locked_for_race.has(c):
			_style_btn(_class_btns[c], c == cls)
	_class_desc_lbl.text = CharacterData.CLASS_DATA[cls]["desc"]
	_update_identity()
	_update_race_locks(cls)
	_refresh_stats()
	_update_confirm()


func _update_identity() -> void:
	if selected_race == "" and selected_class == "":
		_identity_lbl.text = "Select Race & Class"
	elif selected_class == "":
		_identity_lbl.text = selected_race
	elif selected_race == "":
		_identity_lbl.text = selected_class
	else:
		_identity_lbl.text = selected_race + "  ·  " + selected_class


func _update_class_locks(race_id: String) -> void:
	var locked := CharacterData.LOCKED_COMBOS.get(race_id, []) as Array
	if selected_class in locked:
		selected_class = ""
		_class_desc_lbl.text = ""
		_update_identity()
	for cls in CharacterData.CLASSES:
		var btn: Button = _class_btns[cls]
		var is_locked: bool = cls in locked
		btn.disabled = is_locked
		if is_locked:
			_style_btn_locked(btn)
		else:
			_style_btn(btn, cls == selected_class)


func _update_race_locks(cls: String) -> void:
	var locked_races: Array = []
	for race_id in CharacterData.LOCKED_COMBOS:
		if cls in CharacterData.LOCKED_COMBOS[race_id]:
			locked_races.append(race_id)
	if selected_race in locked_races:
		selected_race = ""
		_race_desc_lbl.text = ""
		_update_identity()
	for race_id in CharacterData.RACES:
		var btn: Button = _race_btns[race_id]
		var is_locked: bool = race_id in locked_races
		btn.disabled = is_locked
		if is_locked:
			_style_btn_locked(btn)
		else:
			_style_btn(btn, race_id == selected_race)


func _compute_stat_totals() -> Dictionary:
	var totals: Dictionary = {}
	for k in CharacterData.STAT_KEYS:
		totals[k] = CharacterData.BASE
	if selected_race != "":
		for k: String in CharacterData.RACE_DATA[selected_race]["bonuses"]:
			totals[k] += CharacterData.RACE_DATA[selected_race]["bonuses"][k]
	if selected_class != "":
		for k: String in CharacterData.CLASS_DATA[selected_class]["bonuses"]:
			totals[k] += CharacterData.CLASS_DATA[selected_class]["bonuses"][k]
	return totals


func _refresh_stats() -> void:
	var totals := _compute_stat_totals()

	for k in CharacterData.STAT_KEYS:
		var lbl: Label = _stat_labels[k]
		var val: int = totals[k]
		lbl.text = str(val)
		if val > CharacterData.BASE:
			lbl.add_theme_color_override("font_color", C_POS)
		elif val < CharacterData.BASE:
			lbl.add_theme_color_override("font_color", C_NEG)
		else:
			lbl.add_theme_color_override("font_color", C_NEUTRAL)

	if selected_class != "":
		var cd: Dictionary = CharacterData.CLASS_DATA[selected_class]
		var con_total: int = totals["constitution"]
		var con_hp_bonus: float = (con_total - 10) * 5.0
		_res_labels["hp"].text = str(int(max(50.0, CharacterData.BASE_HP + cd["hp_bonus"] + con_hp_bonus)))
		_res_labels["mp"].text = str(int(max(20.0, CharacterData.BASE_MP + cd["mp_bonus"])))
		_res_labels["st"].text = str(int(max(20.0, CharacterData.BASE_ST + cd["stamina_bonus"])))
	else:
		for k in _res_labels:
			(_res_labels[k] as Label).text = "—"


func _update_confirm() -> void:
	_confirm_btn.disabled = selected_race == "" or selected_class == "" or _name_input.text.strip_edges().is_empty()

# ── Confirm ────────────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	PlayerStats.player_name = _name_input.text.strip_edges()
	PlayerStats.apply_character(selected_race, selected_class, 1)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_panel_container(expand_h: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	pc.add_theme_stylebox_override("panel", style)
	if expand_h:
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return pc


func _make_margin(parent: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_top", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_bottom", m)
	parent.add_child(mc)
	return mc


func _make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = align
	return lbl


func _make_select_btn(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	_style_btn(btn, false)
	return btn


func _style_btn(btn: Button, is_selected: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color     = C_SELECTED if is_selected else C_BTN_NORM
	s.border_color = C_TITLE    if is_selected else C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 10
	s.content_margin_top    = 5
	s.content_margin_right  = 10
	s.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
	btn.add_theme_color_override("font_color", C_TITLE if is_selected else C_TEXT)

	var h := s.duplicate() as StyleBoxFlat
	h.bg_color     = C_SELECTED if is_selected else C_BTN_HOVER
	h.border_color = C_TITLE
	btn.add_theme_stylebox_override("hover", h)


func _style_btn_locked(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color     = C_BTN_LOCKED_BG
	s.border_color = C_BTN_LOCKED_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 10
	s.content_margin_top    = 5
	s.content_margin_right  = 10
	s.content_margin_bottom = 5
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", C_BTN_LOCKED_TEXT)
	btn.add_theme_color_override("font_disabled_color", C_BTN_LOCKED_TEXT)


func _make_confirm_btn() -> Button:
	var btn := Button.new()
	btn.text = "Begin Adventure"
	btn.custom_minimum_size = Vector2(220, 42)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", C_TITLE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = true
	btn.pressed.connect(_on_confirm)

	var norm := StyleBoxFlat.new()
	norm.bg_color     = C_CONFIRM_BG
	norm.border_color = C_GOLDEN_BORDER
	norm.set_border_width_all(2)
	norm.set_corner_radius_all(6)
	norm.content_margin_left   = 24
	norm.content_margin_top    = 10
	norm.content_margin_right  = 24
	norm.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", norm)

	var hover := norm.duplicate() as StyleBoxFlat
	hover.bg_color     = C_CONFIRM_BG_HOVER
	hover.border_color = C_TITLE
	btn.add_theme_stylebox_override("hover", hover)

	var dis := norm.duplicate() as StyleBoxFlat
	dis.bg_color     = C_CONFIRM_BG_DISABLED
	dis.border_color = C_CONFIRM_BORDER_DISABLED
	dis.set_border_width_all(1)
	btn.add_theme_stylebox_override("disabled", dis)

	return btn
