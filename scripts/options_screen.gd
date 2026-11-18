extends DraggablePanel

const BUG_REPORT_URL := "https://discord.gg/xpAv5Ra4aT"

const _AUDIO_CHANNELS := [
	{id = "master", label = "Master Volume"},
	{id = "music",  label = "Music Volume"},
	{id = "sfx",    label = "SFX Volume"},
	{id = "ui",     label = "UI Volume"},
]

@onready var _tab_container: TabContainer = $Tabs
@onready var _bug_btn: Button = $BtnRow/BugBtn
@onready var _quit_btn: Button = $BtnRow/QuitBtn
@onready var _apply_btn: Button = $BtnRow/ApplyBtn
@onready var _close_btn: Button = $BtnRow/CloseBtn

# Graphics controls
var _win_mode_btn: OptionButton
var _res_btn: OptionButton
var _vsync_btn: OptionButton
var _ui_scale_slider: HSlider = null
var _ui_scale_label: Label = null

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

# The frame is scenes/options_screen.tscn (title, the tab container, the
# button row); this script builds the four tabs' contents.
func _build() -> void:
	_build_graphics_tab()
	_build_audio_tab()
	_build_interface_tab()
	_build_keybinds_tab()
	_bug_btn.pressed.connect(_on_report_bug_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_apply_btn.pressed.connect(_on_apply)
	_close_btn.pressed.connect(func() -> void:
		_cancel_listening()
		visible = false)

func _on_quit_pressed() -> void:
	Net.leave_session()
	get_tree().quit()

func _on_report_bug_pressed() -> void:
	OS.shell_open(BUG_REPORT_URL)

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

	var scale_row := _make_row("UI Scale")
	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = 0.75
	_ui_scale_slider.max_value = 1.50
	_ui_scale_slider.step = 0.05
	_ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_scale_label = Label.new()
	_ui_scale_label.custom_minimum_size = Vector2(48.0, 0.0)
	_ui_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_scale_slider.value_changed.connect(func(v: float) -> void:
		_ui_scale_label.text = "%d%%" % int(v * 100.0))
	scale_row.add_child(_ui_scale_slider)
	scale_row.add_child(_ui_scale_label)
	vbox.add_child(scale_row)

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
	lbl.theme_type_variation = &"TitleLabel"
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)
	parent.add_child(HSeparator.new())

func _add_keybind_row(parent: VBoxContainer, action: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = action.label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120.0, 28.0)
	btn.add_theme_stylebox_override("normal",  UITheme.make_stylebox(UITheme.C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",   UITheme.make_stylebox(UITheme.C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", UITheme.make_stylebox(UITheme.C_BTN_HOVER))
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
	_listening_action = ""
	_listening_btn = null

func _commit_listening(keycode: int) -> void:
	# Reserved keys (Enter/Numpad-Enter/Escape) are wired to chat and menu nav;
	# rebinding to them would break the game. Cancel the rebind, leaving the
	# previous binding intact.
	if GameSettings.is_reserved_key(keycode):
		_cancel_listening()
		return
	GameSettings.keybinds[_listening_action] = keycode
	GameSettings.apply_keybinds()
	_listening_btn.text = _key_label(_listening_action)
	_listening_btn.add_theme_stylebox_override("normal", UITheme.make_stylebox(UITheme.C_BTN_NORM))
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
	_ui_scale_slider.value = GameSettings.ui_scale
	_ui_scale_label.text = "%d%%" % int(GameSettings.ui_scale * 100.0)
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
	GameSettings.ui_scale         = _ui_scale_slider.value
	for ch: Dictionary in _AUDIO_CHANNELS:
		GameSettings.set(ch.id + "_volume", _audio_rows[ch.id].slider.value)
	GameSettings.floating_text_enabled = _ft_master_cb.button_pressed
	GameSettings.floating_text_damage  = _ft_damage_cb.button_pressed
	GameSettings.floating_text_heals   = _ft_heals_cb.button_pressed
	GameSettings.floating_text_misses  = _ft_misses_cb.button_pressed
	GameSettings.floating_text_xp      = _ft_xp_cb.button_pressed
	GameSettings.apply_all()
	GameSettings.save_settings()
