extends SceneTree
# Screenshots of the game's windows for a look at the UI theme, taken by a
# real (not headless) Godot run on a plain backdrop, with no server and no
# character: the windows show their empty state. Written for the dark wood
# and brass pass (2026-11-18) so the user can see a theme change before the
# rest of the windows follow it. Two shots: the item windows (inventory, bank,
# character) and the reading windows (quest journal, spell book, options,
# vendor). Run from a desktop session (it opens a window):
#   godot --path . -s tools/shot_windows.gd -- --out <dir>
# Files: <dir>/ui_items.png and <dir>/ui_reading.png. With `--theme <id>` (a
# palette id from data/ui_theme_palettes.gd) the theme is applied first and
# one combined shot of seven windows is written to <dir>/ui_<id>.png, for
# comparing the themes side by side. `--login` shoots the login screen instead
# (ui_login_<id>.png), the one screen built entirely from UITheme's colours.

const HUD_SCENE := "res://scenes/hud.tscn"
const SCREEN := Vector2i(1920, 1080)

var _out := ""
var _theme := ""
var _saved_theme := ""
var _login := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--theme" and i + 1 < args.size():
			_theme = args[i + 1]
		elif args[i] == "--login":
			_login = true
	if _out == "":
		_out = OS.get_user_data_dir()
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _window(hud: Node, script_file: String) -> Control:
	for child in hud.get_children():
		var s = child.get_script()
		if s != null and s.resource_path.get_file() == script_file:
			return child
	return null

func _place(hud: Node, script_file: String, at: Vector2) -> void:
	var w := _window(hud, script_file)
	if w == null:
		printerr("no window for " + script_file)
		return
	w.visible = true
	w.position = at

func _hide_all(hud: Node) -> void:
	for child in hud.get_children():
		if child is DraggablePanel:
			child.visible = false

func _shoot(file: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := _out.path_join(file)
	var err := img.save_png(path)
	print("%s %s" % ["wrote" if err == OK else "FAILED to write", path])

func _run() -> void:
	DisplayServer.window_set_size(SCREEN)
	root.size = SCREEN
	await process_frame
	# A plain backdrop in the game's dusk tones, so a translucent field reads.
	var back := ColorRect.new()
	back.color = Color(0.22, 0.26, 0.24)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	if _theme != "":
		var theme := load(UIThemePalettes.theme_path(_theme)) as Theme
		if theme == null:
			printerr("no theme for " + _theme)
			quit(1)
			return
		# Through the real path, then back: something saves the settings at
		# exit, and a screenshot must not change the dev box's own theme.
		var settings: Node = root.get_node("/root/GameSettings")
		_saved_theme = settings.ui_theme
		settings.ui_theme = _theme
		settings.apply_ui_theme()
	# `--login`: the login screen alone (it reads UITheme for its whole look),
	# as ui_login_<id>.png; no server, so it shows the form before any connect.
	if _login:
		var login_scene := load("res://scenes/login.tscn") as PackedScene
		var login := login_scene.instantiate()
		root.add_child(login)
		await _shoot("ui_login_%s.png" % (_theme if _theme != "" else "default"))
		if _theme != "":
			root.get_node("/root/GameSettings").ui_theme = _saved_theme
		quit(0)
		return
	var hud: CanvasLayer = (load(HUD_SCENE) as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	_hide_all(hud)
	var panel: Control = hud.get_node_or_null("Panel")
	if panel != null:
		panel.visible = true

	if _theme != "":
		_place(hud, "inventory_window.gd", Vector2(60, 180))
		_place(hud, "bank_window.gd", Vector2(560, 180))
		_place(hud, "character_window.gd", Vector2(1340, 180))
		_place(hud, "quest_journal.gd", Vector2(30, 640))
		_place(hud, "spell_book.gd", Vector2(700, 756))
		_place(hud, "vendor_window.gd", Vector2(1180, 620))
		await _shoot("ui_%s.png" % _theme)
		root.get_node("/root/GameSettings").ui_theme = _saved_theme
		quit(0)
		return

	_place(hud, "inventory_window.gd", Vector2(60, 200))
	_place(hud, "bank_window.gd", Vector2(560, 200))
	_place(hud, "character_window.gd", Vector2(1340, 200))
	await _shoot("ui_items.png")

	_hide_all(hud)
	if panel != null:
		panel.visible = true
	_place(hud, "quest_journal.gd", Vector2(60, 200))
	_place(hud, "spell_book.gd", Vector2(700, 200))
	_place(hud, "vendor_window.gd", Vector2(1180, 200))
	_place(hud, "options_screen.gd", Vector2(60, 640))
	await _shoot("ui_reading.png")
	quit(0)
