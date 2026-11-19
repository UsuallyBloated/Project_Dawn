extends SceneTree
# Headless probe for the UI theme picker (2026-11-18): GameSettings holds a
# palette id, apply_ui_theme puts that palette's Theme on the root window and
# hands UITheme the same palette; an unknown id falls back to the default; the
# Options screen's Interface tab lists every palette and Apply moves the
# choice into GameSettings and onto the window. Nothing here saves to
# user://settings.cfg (the dev box's own settings live there). Exits 1 on any
# miss. Run:
#   godot --headless --path . -s tools/probe_ui_theme_picker.gd

var _fails := 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.005 and absf(a.g - b.g) < 0.005 and absf(a.b - b.b) < 0.005 and absf(a.a - b.a) < 0.005

func _run() -> void:
	await process_frame
	var settings: Node = root.get_node("/root/GameSettings")
	var original: String = settings.ui_theme

	# 1. apply_ui_theme puts the palette's theme on the root and into UITheme.
	settings.ui_theme = "carved_stone"
	settings.apply_ui_theme()
	var root_theme: Theme = ThemeDB.get_project_theme()
	var stone_file := load(UIThemePalettes.theme_path("carved_stone")) as Theme
	_check(root_theme != null and _same(root_theme.get_color("font_color", "TitleLabel"), stone_file.get_color("font_color", "TitleLabel")),
		"the project theme carries carved_stone's values")
	var stone := UIThemePalettes.runtime_colors("carved_stone")
	_check(_same(UITheme.C_TITLE, stone["C_TITLE"]) and _same(UITheme.C_WINDOW_BG, stone["C_WINDOW_BG"]),
		"UITheme carries carved_stone's title and field colours")
	_check(UITheme.current_palette == "carved_stone", "UITheme names the palette (%s)" % UITheme.current_palette)
	var title_from_theme := root_theme.get_color("font_color", "TitleLabel")
	_check(_same(title_from_theme, UITheme.C_TITLE), "the Theme's title colour and UITheme's agree (%s / %s)" % [title_from_theme, UITheme.C_TITLE])

	# 2. A label and a window panel UNDER A CANVASLAYER (as the HUD's are: a
	#    CanvasLayer breaks theme inheritance from the root window) resolve the
	#    new colours with no override.
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var lbl := Label.new()
	layer.add_child(lbl)
	var pane := Panel.new()
	pane.theme_type_variation = &"WindowPanel"
	layer.add_child(pane)
	await process_frame
	_check(_same(lbl.get_theme_color("font_color"), stone["C_TEXT"]), "a plain Label under a CanvasLayer reads carved_stone's text colour (%s)" % lbl.get_theme_color("font_color"))
	var box := pane.get_theme_stylebox("panel") as StyleBoxFlat
	_check(box != null and _same(box.bg_color, stone["C_WINDOW_BG"]), "a WindowPanel under a CanvasLayer wears carved_stone's field (%s)" % (box.bg_color if box else Color()))
	layer.queue_free()

	# 3. An unknown id falls back to the default palette.
	settings.ui_theme = "no_such_theme"
	settings.apply_ui_theme()
	_check(settings.ui_theme == UIThemePalettes.DEFAULT_ID, "an unknown id falls back to %s (%s)" % [UIThemePalettes.DEFAULT_ID, settings.ui_theme])
	var default_file := load(UIThemePalettes.theme_path(UIThemePalettes.DEFAULT_ID)) as Theme
	_check(_same(ThemeDB.get_project_theme().get_color("font_color", "Label"), default_file.get_color("font_color", "Label")), "and the project theme is the default again")

	# 4. Every palette has a theme file that loads and defines the variations.
	for id: String in UIThemePalettes.ORDER:
		var t := load(UIThemePalettes.theme_path(id)) as Theme
		_check(t != null and t.get_type_variation_base("WindowPanel") == &"Panel" and t.get_type_variation_base("TitleLabel") == &"Label",
			"%s loads with its variations" % id)

	# 5. The Options screen: the Interface tab lists every palette; Apply moves the choice.
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	var options = load("res://scenes/options_screen.tscn").instantiate()
	hud.add_child(options)
	await process_frame
	var btn: OptionButton = options._ui_theme_btn
	_check(btn != null and btn.item_count == UIThemePalettes.ORDER.size(), "the picker lists every palette (%d)" % (btn.item_count if btn else -1))
	_check(btn != null and btn.selected == UIThemePalettes.ORDER.find(settings.ui_theme), "the picker starts on the current theme")
	var iron := UIThemePalettes.ORDER.find("ironbound")
	btn.selected = iron
	options._on_apply()
	await process_frame
	_check(settings.ui_theme == "ironbound", "Apply moves the choice into GameSettings (%s)" % settings.ui_theme)
	var iron_file := load(UIThemePalettes.theme_path("ironbound")) as Theme
	_check(_same(ThemeDB.get_project_theme().get_color("font_color", "Label"), iron_file.get_color("font_color", "Label")), "and the project theme is ironbound")
	_check(_same(UITheme.C_TEXT, UIThemePalettes.runtime_colors("ironbound")["C_TEXT"]), "and UITheme followed")
	# Reopening the tab shows the saved choice.
	options._load_from_settings()
	_check(btn.selected == iron, "reopening shows ironbound selected")

	# Back to where the dev box was (Apply saved the file; put the original id back).
	settings.ui_theme = original
	settings.apply_ui_theme()
	settings.save_settings()

	print("\n" + ("all passed" if _fails == 0 else "%d failure(s)" % _fails))
	quit(1 if _fails > 0 else 0)
