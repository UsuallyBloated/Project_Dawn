extends Node

const SAVE_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{id = "toggle_character", label = "Character Window", category = "Windows",  default_key = KEY_C},
	{id = "toggle_inventory", label = "Inventory Window", category = "Windows",  default_key = KEY_I},
	{id = "toggle_paperdoll", label = "Paperdoll Window", category = "Windows",  default_key = KEY_P},
	{id = "target_cycle",     label = "Cycle Target",     category = "Combat",   default_key = KEY_TAB},
	{id = "move_forward",     label = "Move Forward",     category = "Movement", default_key = KEY_W},
	{id = "move_backward",    label = "Move Back",        category = "Movement", default_key = KEY_S},
	{id = "move_left",        label = "Strafe Left",      category = "Movement", default_key = KEY_A},
	{id = "move_right",       label = "Strafe Right",     category = "Movement", default_key = KEY_D},
	{id = "jump",             label = "Jump",             category = "Movement", default_key = KEY_SPACE},
	{id = "toggle_crouch",    label = "Crouch",           category = "Movement", default_key = KEY_X},
	{id = "toggle_sit",       label = "Sit / Rest",       category = "Movement", default_key = KEY_Z},
]

# Audio (0.0 – 1.0 linear)
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0

# Graphics
var window_mode: int = 0       # 0=windowed, 1=fullscreen, 2=borderless
var vsync_mode: int = 1        # 0=disabled, 1=enabled, 2=adaptive
var resolution_index: int = 2  # index into RESOLUTIONS; -1 = don't touch

# Keybinds: action_id -> Key enum value
var keybinds: Dictionary = {}

func _ready() -> void:
	load_settings()
	apply_all()

func apply_all() -> void:
	apply_audio()
	apply_graphics()
	apply_keybinds()

# ── Audio ─────────────────────────────────────────────────────────────────────

func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music",  music_volume)
	_set_bus_volume("SFX",    sfx_volume)
	_set_bus_volume("UI",     ui_volume)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

# ── Graphics ──────────────────────────────────────────────────────────────────

func apply_graphics() -> void:
	const MODES := [
		DisplayServer.WINDOW_MODE_WINDOWED,
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]
	const VSYNC_MODES := [
		DisplayServer.VSYNC_DISABLED,
		DisplayServer.VSYNC_ENABLED,
		DisplayServer.VSYNC_ADAPTIVE,
	]

	var target_mode: DisplayServer.WindowMode = MODES[window_mode]
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)

	var target_vsync: DisplayServer.VSyncMode = VSYNC_MODES[vsync_mode]
	if DisplayServer.window_get_vsync_mode() != target_vsync:
		DisplayServer.window_set_vsync_mode(target_vsync)

	if resolution_index >= 0 and resolution_index < RESOLUTIONS.size():
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_size(RESOLUTIONS[resolution_index])

# ── Keybinds ──────────────────────────────────────────────────────────────────

func apply_keybinds() -> void:
	for action: Dictionary in REBINDABLE_ACTIONS:
		var id: String = action.id
		if not keybinds.has(id):
			keybinds[id] = action.default_key
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var key: int = keybinds[id]
		if key != KEY_NONE:
			var ev := InputEventKey.new()
			ev.keycode = key
			InputMap.action_add_event(id, ev)

# ── Persist ───────────────────────────────────────────────────────────────────

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master",              master_volume)
	cfg.set_value("audio", "music",               music_volume)
	cfg.set_value("audio", "sfx",                 sfx_volume)
	cfg.set_value("audio", "ui",                  ui_volume)
	cfg.set_value("graphics", "window_mode",      window_mode)
	cfg.set_value("graphics", "vsync_mode",       vsync_mode)
	cfg.set_value("graphics", "resolution_index", resolution_index)
	for action: Dictionary in REBINDABLE_ACTIONS:
		cfg.set_value("keybinds", action.id, keybinds.get(action.id, action.default_key))
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_volume    = cfg.get_value("audio",    "master",           1.0)
	music_volume     = cfg.get_value("audio",    "music",            0.8)
	sfx_volume       = cfg.get_value("audio",    "sfx",              1.0)
	ui_volume        = cfg.get_value("audio",    "ui",               1.0)
	window_mode      = cfg.get_value("graphics", "window_mode",      0)
	vsync_mode       = cfg.get_value("graphics", "vsync_mode",       1)
	resolution_index = cfg.get_value("graphics", "resolution_index", 2)
	for action: Dictionary in REBINDABLE_ACTIONS:
		keybinds[action.id] = cfg.get_value("keybinds", action.id, action.default_key)
