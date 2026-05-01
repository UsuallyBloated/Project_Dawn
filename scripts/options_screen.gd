extends Panel

const W := 640.0
const H := 500.0

const _AUDIO_CHANNELS := [
	{id = "master", label = "Master Volume"},
	{id = "music",  label = "Music Volume"},
	{id = "sfx",    label = "SFX Volume"},
	{id = "ui",     label = "UI Volume"},
]

var _tab_container: TabContainer

# Graphics controls
var _win_mode_btn: OptionButton
var _res_btn: OptionButton
var _vsync_btn: OptionButton

# Audio controls
var _audio_rows: Dictionary = {}  # id -> {slider: HSlider, pct: Label}

# Keybind controls
var _keybind_btns: Dictionary = {}   # action_id -> Button
var _listening_action: String = ""
var _listening_btn: Button = null

# Interface controls
var _ft_master_cb: CheckBox = null
var _ft_damage_cb: CheckBox = null
var _ft_heals_cb:  CheckBox = null
var _ft_misses_cb: CheckBox = null
var _ft_xp_cb:     CheckBox = null

func _ready() -> void:
	_build()
	_load_from_settings()

# ── Build ─────────────────────────────────────────────────────────────────────

func _build() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left   = -W * 0.5
	offset_top    = -H * 0.5
	offset_right  =  W * 0.5
	offset_bottom =  H * 0.5

	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.C_WINDOW_BG
	bg.border_color = UITheme.C_GOLDEN_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", bg)

	var title := Label.new()
	title.text = "OPTIONS"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = 12.0
	title.offset_bottom = 38.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UITheme.C_TITLE)
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	_tab_container = TabContainer.new()
	_tab_container.position = Vector2(10.0, 48.0)
	_tab_container.size = Vector2(W - 20.0, H - 108.0)
	_style_tabs()
	add_child(_tab_container)

	_build_graphics_tab()
	_build_audio_tab()
	_build_interface_tab()
	_build_keybinds_tab()

	var btn_row := HBoxContainer.new()
	btn_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_row.offset_left   = -218.0
	btn_row.offset_top    = -52.0
	btn_row.offset_right  = -12.0
	btn_row.offset_bottom = -12.0
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	add_child(btn_row)

	var apply_btn := UITheme.make_button("Apply")
	apply_btn.pressed.connect(_on_apply)
	btn_row.add_child(apply_btn)

	var close_btn := UITheme.make_button("Close")
	close_btn.pressed.connect(func() -> void:
		_cancel_listening()
		visible = false)
	btn_row.add_child(close_btn)

func _style_tabs() -> void:
	var panel_s := StyleBoxFlat.new()
	panel_s.bg_color = UITheme.C_PANEL_BG
	panel_s.border_color = UITheme.C_BORDER
	panel_s.set_border_width_all(1)
	_tab_container.add_theme_stylebox_override("panel", panel_s)

	var sel := StyleBoxFlat.new()
	sel.bg_color = UITheme.C_PANEL_BG
	sel.border_color = UITheme.C_GOLDEN_BORDER
	sel.set_border_width_all(1)
	sel.border_width_bottom = 0
	sel.content_margin_left   = 10.0
	sel.content_margin_right  = 10.0
	sel.content_margin_top    = 4.0
	sel.content_margin_bottom = 6.0
	_tab_container.add_theme_stylebox_override("tab_selected", sel)

	var unsel := StyleBoxFlat.new()
	unsel.bg_color = UITheme.C_BTN_NORM
	unsel.border_color = UITheme.C_BORDER
	unsel.set_border_width_all(1)
	unsel.content_margin_left   = 10.0
	unsel.content_margin_right  = 10.0
	unsel.content_margin_top    = 4.0
	unsel.content_margin_bottom = 6.0
	_tab_container.add_theme_stylebox_override("tab_unselected", unsel)

	_tab_container.add_theme_color_override("font_selected_color",   UITheme.C_TITLE)
	_tab_container.add_theme_color_override("font_unselected_color", UITheme.C_TEXT)

func _make_tab(tab_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	UITheme.set_all_margins(margin, 20)
	_tab_container.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)
	return vbox

# ── Graphics tab ──────────────────────────────────────────────────────────────

func _build_graphics_tab() -> void:
	var vbox := _make_tab("Graphics")

	var win_row := _make_row("Window Mode")
	_win_mode_btn = OptionButton.new()
	_win_mode_btn.add_item("Windowed",   0)
	_win_mode_btn.add_item("Fullscreen", 1)
	_win_mode_btn.add_item("Borderless", 2)
	_win_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_row.add_child(_win_mode_btn)
	vbox.add_child(win_row)

	var res_row := _make_row("Resolution")
	_res_btn = OptionButton.new()
	for r: Vector2i in GameSettings.RESOLUTIONS:
		_res_btn.add_item("%d × %d" % [r.x, r.y])
	_res_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(_res_btn)
	vbox.add_child(res_row)

	var vsync_row := _make_row("VSync")
	_vsync_btn = OptionButton.new()
	_vsync_btn.add_item("Disabled", 0)
	_vsync_btn.add_item("Enabled",  1)
	_vsync_btn.add_item("Adaptive", 2)
	_vsync_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsync_row.add_child(_vsync_btn)
	vbox.add_child(vsync_row)

# ── Audio tab ─────────────────────────────────────────────────────────────────

func _build_audio_tab() -> void:
	var vbox := _make_tab("Audio")
	for ch: Dictionary in _AUDIO_CHANNELS:
		var row_data := _make_slider_row(vbox, ch.label)
		_audio_rows[ch.id] = {slider = row_data[0], pct = row_data[1]}

# ── Interface tab ─────────────────────────────────────────────────────────────

func _build_interface_tab() -> void:
	var vbox := _make_tab("Interface")

	var master_row := HBoxContainer.new()
	_ft_master_cb = CheckBox.new()
	_ft_master_cb.text = "Floating Combat Text"
	_ft_master_cb.add_theme_color_override("font_color", UITheme.C_TEXT)
	master_row.add_child(_ft_master_cb)
	vbox.add_child(master_row)

	var sub_margin := MarginContainer.new()
	sub_margin.add_theme_constant_override("margin_left", 28)
	vbox.add_child(sub_margin)

	var sub_vbox := VBoxContainer.new()
	sub_vbox.add_theme_constant_override("separation", 8)
	sub_margin.add_child(sub_vbox)

	_ft_damage_cb = _make_sub_checkbox("Damage Numbers", sub_vbox)
	_ft_heals_cb  = _make_sub_checkbox("Heals",          sub_vbox)
	_ft_misses_cb = _make_sub_checkbox("Misses",         sub_vbox)
	_ft_xp_cb     = _make_sub_checkbox("XP Gains",       sub_vbox)

	var sub_cbs := [_ft_damage_cb, _ft_heals_cb, _ft_misses_cb, _ft_xp_cb]
	_ft_master_cb.toggled.connect(func(on: bool) -> void:
		for cb: CheckBox in sub_cbs:
			cb.disabled = not on)

func _make_sub_checkbox(label: String, parent: VBoxContainer) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label
	cb.add_theme_color_override("font_color", UITheme.C_TEXT)
	parent.add_child(cb)
	return cb

# ── Keybinds tab ──────────────────────────────────────────────────────────────

func _build_keybinds_tab() -> void:
	var margin := MarginContainer.new()
	margin.name = "Keybinds"
	UITheme.set_all_margins(margin, 10)
	_tab_container.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	var current_category := ""
	for action: Dictionary in GameSettings.REBINDABLE_ACTIONS:
		if action.category != current_category:
			current_category = action.category
			_add_keybind_header(vbox, current_category)
		_add_keybind_row(vbox, action)

	vbox.add_child(HSeparator.new())

	var reset_btn := UITheme.make_button("Reset to Defaults")
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.pressed.connect(_on_keybinds_reset)
	vbox.add_child(reset_btn)

func _add_keybind_header(parent: VBoxContainer, category: String) -> void:
	var lbl := Label.new()
	lbl.text = category.to_upper()
	lbl.add_theme_color_override("font_color", UITheme.C_TITLE)
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)
	parent.add_child(HSeparator.new())

func _add_keybind_row(parent: VBoxContainer, action: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = action.label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	row.add_child(lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120.0, 28.0)
	btn.add_theme_stylebox_override("normal",  UITheme.make_stylebox(UITheme.C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",   UITheme.make_stylebox(UITheme.C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", UITheme.make_stylebox(UITheme.C_BTN_HOVER))
	btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	btn.pressed.connect(_start_listening.bind(action.id, btn))
	_keybind_btns[action.id] = btn
	row.add_child(btn)

	parent.add_child(row)

# ── Listening mode ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var keycode: int = (event as InputEventKey).keycode
	if keycode == KEY_ESCAPE:
		_cancel_listening()
	else:
		_commit_listening(keycode)
	get_viewport().set_input_as_handled()

func _start_listening(action_id: String, btn: Button) -> void:
	if not _listening_action.is_empty():
		_cancel_listening()
	_listening_action = action_id
	_listening_btn = btn
	btn.text = "Press a key…"
	btn.add_theme_stylebox_override("normal", UITheme.make_stylebox(Color(0.40, 0.28, 0.05)))
	btn.add_theme_color_override("font_color", UITheme.C_TITLE)

func _cancel_listening() -> void:
	if _listening_btn == null:
		return
	_listening_btn.text = _key_label(_listening_action)
	_listening_btn.add_theme_stylebox_override("normal", UITheme.make_stylebox(UITheme.C_BTN_NORM))
	_listening_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	_listening_action = ""
	_listening_btn = null

func _commit_listening(keycode: int) -> void:
	GameSettings.keybinds[_listening_action] = keycode
	GameSettings.apply_keybinds()
	_listening_btn.text = _key_label(_listening_action)
	_listening_btn.add_theme_stylebox_override("normal", UITheme.make_stylebox(UITheme.C_BTN_NORM))
	_listening_btn.add_theme_color_override("font_color", UITheme.C_TEXT)
	_listening_action = ""
	_listening_btn = null

func _key_label(action_id: String) -> String:
	var key: int = GameSettings.keybinds.get(action_id, KEY_NONE)
	if key == KEY_NONE:
		return "—"
	return OS.get_keycode_string(key)

func _on_keybinds_reset() -> void:
	_cancel_listening()
	for action: Dictionary in GameSettings.REBINDABLE_ACTIONS:
		GameSettings.keybinds[action.id] = action.default_key
	GameSettings.apply_keybinds()
	for id: String in _keybind_btns:
		_keybind_btns[id].text = _key_label(id)

# ── Shared row helpers ────────────────────────────────────────────────────────

func _make_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160.0, 0.0)
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	row.add_child(lbl)
	return row

func _make_slider_row(parent: VBoxContainer, label_text: String) -> Array:
	var row := _make_row(label_text)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pct := Label.new()
	pct.custom_minimum_size = Vector2(48.0, 0.0)
	pct.add_theme_color_override("font_color", UITheme.C_TEXT)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(v * 100.0))

	row.add_child(slider)
	row.add_child(pct)
	parent.add_child(row)
	return [slider, pct]

# ── Load / Apply ──────────────────────────────────────────────────────────────

func _load_from_settings() -> void:
	_win_mode_btn.selected = GameSettings.window_mode
	_res_btn.selected = max(0, GameSettings.resolution_index)
	_vsync_btn.selected = GameSettings.vsync_mode
	for ch: Dictionary in _AUDIO_CHANNELS:
		_audio_rows[ch.id].slider.value = GameSettings.get(ch.id + "_volume")
	_ft_master_cb.button_pressed = GameSettings.floating_text_enabled
	_ft_damage_cb.button_pressed = GameSettings.floating_text_damage
	_ft_heals_cb.button_pressed  = GameSettings.floating_text_heals
	_ft_misses_cb.button_pressed = GameSettings.floating_text_misses
	_ft_xp_cb.button_pressed     = GameSettings.floating_text_xp
	for cb: CheckBox in [_ft_damage_cb, _ft_heals_cb, _ft_misses_cb, _ft_xp_cb]:
		cb.disabled = not GameSettings.floating_text_enabled
	for id: String in _keybind_btns:
		_keybind_btns[id].text = _key_label(id)

func _on_apply() -> void:
	_cancel_listening()
	GameSettings.window_mode      = _win_mode_btn.selected
	GameSettings.resolution_index = _res_btn.selected
	GameSettings.vsync_mode       = _vsync_btn.selected
	for ch: Dictionary in _AUDIO_CHANNELS:
		GameSettings.set(ch.id + "_volume", _audio_rows[ch.id].slider.value)
	GameSettings.floating_text_enabled = _ft_master_cb.button_pressed
	GameSettings.floating_text_damage  = _ft_damage_cb.button_pressed
	GameSettings.floating_text_heals   = _ft_heals_cb.button_pressed
	GameSettings.floating_text_misses  = _ft_misses_cb.button_pressed
	GameSettings.floating_text_xp      = _ft_xp_cb.button_pressed
	GameSettings.apply_all()
	GameSettings.save_settings()
