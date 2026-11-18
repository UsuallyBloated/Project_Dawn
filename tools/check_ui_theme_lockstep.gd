extends SceneTree
# Lockstep check for the UI theme (2026-11-18, the dark wood and brass pass).
# The palette has two homes: assets/ui/dark_wood_brass.tres, the project Theme
# every Control inherits, and scripts/ui_theme.gd (UITheme), the constants
# code colours things with at runtime. This check fails when they disagree,
# when the project no longer names the theme, or when a script asks for a
# theme type variation the theme does not define (a typo there draws the
# engine's grey box with no error). Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/check_ui_theme_lockstep.gd

const THEME_PATH := "res://assets/ui/dark_wood_brass.tres"
const TOLERANCE := 0.005
const SCRIPT_DIRS := ["res://scripts", "res://autoloads"]

var _fails := 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	_run()

static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < TOLERANCE and absf(a.g - b.g) < TOLERANCE and absf(a.b - b.b) < TOLERANCE and absf(a.a - b.a) < TOLERANCE

func _box(theme: Theme, type_name: String, item: String) -> StyleBoxFlat:
	var sb := theme.get_stylebox(item, type_name)
	return sb as StyleBoxFlat

func _check_box(theme: Theme, type_name: String, item: String, bg: Color, border: Color, what: String) -> void:
	var sb := _box(theme, type_name, item)
	_check(sb != null, "%s: %s/%s is a StyleBoxFlat" % [what, type_name, item])
	if sb == null:
		return
	_check(_same(sb.bg_color, bg), "%s: field %s matches UITheme (%s)" % [what, sb.bg_color, bg])
	_check(_same(sb.border_color, border), "%s: border %s matches UITheme (%s)" % [what, sb.border_color, border])

func _run() -> void:
	# 1. The project names the theme.
	var custom: String = ProjectSettings.get_setting("gui/theme/custom", "")
	_check(custom == THEME_PATH, "project.godot gui/theme/custom is %s (%s)" % [THEME_PATH, custom])

	var theme := load(THEME_PATH) as Theme
	_check(theme != null, "the theme loads")
	if theme == null:
		quit(1)
		return

	# 2. The palette agrees with UITheme.
	_check_box(theme, "WindowPanel", "panel", UITheme.C_WINDOW_BG, UITheme.C_GOLDEN_BORDER, "WindowPanel")
	_check_box(theme, "SectionPanel", "panel", UITheme.C_PANEL_BG, UITheme.C_BORDER, "SectionPanel")
	_check_box(theme, "SlotCell", "panel", UITheme.C_SLOT_BG, UITheme.C_BORDER, "SlotCell")
	_check_box(theme, "Tooltip", "panel", UITheme.C_TOOLTIP, UITheme.C_BORDER, "Tooltip")
	_check_box(theme, "Button", "normal", UITheme.C_BTN_NORM, UITheme.C_BORDER, "Button normal")
	_check_box(theme, "Button", "hover", UITheme.C_BTN_HOVER, UITheme.C_GOLDEN_BORDER, "Button hover")
	_check(_same(theme.get_color("font_color", "Label"), UITheme.C_TEXT), "Label font_color is UITheme.C_TEXT")
	_check(_same(theme.get_color("font_color", "Button"), UITheme.C_TEXT), "Button font_color is UITheme.C_TEXT")
	_check(_same(theme.get_color("font_color", "TitleLabel"), UITheme.C_TITLE), "TitleLabel font_color is UITheme.C_TITLE")
	_check(_same(theme.get_color("font_hover_color", "Button"), UITheme.C_TITLE), "Button hover text is UITheme.C_TITLE")

	# 3. Every variation a script names exists in the theme.
	var defined := {}
	for type_name in theme.get_type_list():
		if theme.get_type_variation_base(type_name) != &"":
			defined[String(type_name)] = true
	_check(defined.size() >= 5, "the theme defines its variations (%d)" % defined.size())
	var named := {}
	for dir_path in SCRIPT_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir_path + "/" + file)
			var rx := RegEx.new()
			rx.compile("theme_type_variation = &\"([A-Za-z0-9_]+)\"")
			for m in rx.search_all(text):
				var v: String = m.get_string(1)
				if not named.has(v):
					named[v] = []
				named[v].append(file)
	_check(named.size() >= 4, "scripts name variations (%d kinds)" % named.size())
	for v in named.keys():
		_check(defined.has(v), "variation %s (named in %s) is defined in the theme" % [v, ", ".join(named[v])])

	print("\n" + ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
