extends Node

const SAVE_PATH := "user://settings.cfg"

# Reserved keys cannot be rebound — they're hardcoded for chat (Enter) and
# menu navigation (Escape). Enforced at both rebind-commit and load time.
const RESERVED_KEYS: Array[int] = [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{id = "toggle_character",  label = "Character Window",  category = "Windows",  default_key = KEY_C},
	{id = "toggle_inventory",  label = "Inventory Window",  category = "Windows",  default_key = KEY_I},
	{id = "toggle_paperdoll",  label = "Paperdoll Window",  category = "Windows",  default_key = KEY_P},
	{id = "toggle_crafting",   label = "Tradeskill Window", category = "Windows",  default_key = KEY_K},
	{id = "toggle_spell_book",    label = "Spellbook",         category = "Windows",  default_key = KEY_B},
	{id = "toggle_quest_journal", label = "Quest Journal",     category = "Windows",  default_key = KEY_J},
	{id = "interact",          label = "Interact / Talk",   category = "World",    default_key = KEY_F},
	{id = "target_cycle",      label = "Cycle Target",      category = "Combat",   default_key = KEY_TAB},
	{id = "target_self",       label = "Target Self",       category = "Combat",   default_key = KEY_F1},
	{id = "move_forward",      label = "Move Forward",      category = "Movement", default_key = KEY_W},
	{id = "move_backward",     label = "Move Back",         category = "Movement", default_key = KEY_S},
	{id = "move_left",         label = "Strafe Left",       category = "Movement", default_key = KEY_A},
	{id = "move_right",        label = "Strafe Right",      category = "Movement", default_key = KEY_D},
	{id = "jump",              label = "Jump",              category = "Movement", default_key = KEY_SPACE},
	{id = "toggle_crouch",     label = "Crouch",            category = "Movement", default_key = KEY_X},
	{id = "toggle_sit",        label = "Sit / Rest",        category = "Movement", default_key = KEY_Z},
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
var ui_scale: float = 1.0      # multiplier on top of canvas_items stretch (0.75–1.5)

# Floating combat text
var floating_text_enabled: bool = true
var floating_text_damage:  bool = true
var floating_text_heals:   bool = true
var floating_text_misses:  bool = true
var floating_text_xp:      bool = true

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

	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = clampf(ui_scale, 0.5, 2.0)

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
			ev.keycode = key as Key
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
	cfg.set_value("graphics", "ui_scale",         ui_scale)
	cfg.set_value("interface", "floating_text_enabled", floating_text_enabled)
	cfg.set_value("interface", "floating_text_damage",  floating_text_damage)
	cfg.set_value("interface", "floating_text_heals",   floating_text_heals)
	cfg.set_value("interface", "floating_text_misses",  floating_text_misses)
	cfg.set_value("interface", "floating_text_xp",      floating_text_xp)
	for action: Dictionary in REBINDABLE_ACTIONS:
		cfg.set_value("keybinds", action.id, keybinds.get(action.id, action.default_key))
	cfg.save(SAVE_PATH)

func is_reserved_key(keycode: int) -> bool:
	return keycode in RESERVED_KEYS

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
	ui_scale         = clampf(cfg.get_value("graphics", "ui_scale",  1.0), 0.5, 2.0)
	floating_text_enabled = cfg.get_value("interface", "floating_text_enabled", true)
	floating_text_damage  = cfg.get_value("interface", "floating_text_damage",  true)
	floating_text_heals   = cfg.get_value("interface", "floating_text_heals",   true)
	floating_text_misses  = cfg.get_value("interface", "floating_text_misses",  true)
	floating_text_xp      = cfg.get_value("interface", "floating_text_xp",      true)
	var sanitized := false
	for action: Dictionary in REBINDABLE_ACTIONS:
		var saved: int = cfg.get_value("keybinds", action.id, action.default_key)
		# Reserved keys (Enter/Escape) are hardcoded for chat/menus and cannot be
		# rebound. If a saved binding hit one, reset it to the default.
		if saved in RESERVED_KEYS:
			saved = action.default_key
			sanitized = true
		keybinds[action.id] = saved
	if sanitized:
		save_settings()
