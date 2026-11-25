extends SceneTree
# Lockstep check for the UI themes (2026-11-18). The palette has three homes:
# data/ui_theme_palettes.gd (the table), the generated Theme resources under
# assets/ui/themes/ (one per palette, from tools/author_ui_themes.gd's one
# template), and scripts/ui_theme.gd (UITheme), whose defaults are the default
# palette and which apply_palette fills from the table at runtime. This check
# fails when a theme file is stale against the table (run the author tool),
# when the project does not name the default theme, when a script asks for a
# theme type variation a theme does not define (a typo there draws the
# engine's grey box with no error), when a theme's structural numbers (border
# widths, content margins: what the geometry fixture depends on) differ from
# the default theme's, or when UITheme's defaults disagree with the default
# palette. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/check_ui_theme_lockstep.gd

const TOLERANCE := 0.005
const SCRIPT_DIRS := ["res://scripts", "res://autoloads"]
const AUTHOR := preload("res://tools/author_ui_themes.gd")

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

# The lines of a theme file that fix geometry: border widths and content margins.
static func _structure(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		if line.begins_with("border_width_") or line.begins_with("content_margin_"):
			out.append(line)
	return out

func _run() -> void:
	var default_id := UIThemePalettes.DEFAULT_ID
	var default_path := UIThemePalettes.theme_path(default_id)

	# 1. The project names the default theme (what the first frame and every
	#    headless check see before settings load).
	var custom: String = ProjectSettings.get_setting("gui/theme/custom", "")
	_check(custom == default_path, "project.godot gui/theme/custom is the default theme (%s)" % custom)
	_check(UIThemePalettes.is_known(default_id) and UIThemePalettes.ORDER.has(default_id), "the default palette is in the table and the picker's order")
	_check(UIThemePalettes.ORDER.size() == UIThemePalettes.ALL.size(), "every palette is in the picker's order (%d of %d)" % [UIThemePalettes.ORDER.size(), UIThemePalettes.ALL.size()])

	# 2. Every theme file equals its render from the table, and shares the
	#    default's structural numbers.
	var reference_structure := _structure(AUTHOR.render(default_id))
	for id: String in UIThemePalettes.ORDER:
		var path := UIThemePalettes.theme_path(id)
		var on_disk := FileAccess.get_file_as_string(path)
		_check(on_disk != "", "%s exists" % path)
		var rendered: String = AUTHOR.render(id)
		_check(on_disk == rendered, "%s is up to date with the palette table (else run tools/author_ui_themes.gd)" % id)
		_check(_structure(rendered) == reference_structure, "%s keeps the default theme's border widths and content margins" % id)

	# 3. The variations every script names exist in every theme.
	var named := {}
	var rx := RegEx.new()
	rx.compile("theme_type_variation = &\"([A-Za-z0-9_]+)\"")
	for dir_path in SCRIPT_DIRS + ["res://scenes"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if not (file.ends_with(".gd") or file.ends_with(".tscn")):
				continue
			for m in rx.search_all(FileAccess.get_file_as_string(dir_path + "/" + file)):
				var v: String = m.get_string(1)
				if not named.has(v):
					named[v] = []
				if not named[v].has(file):
					named[v].append(file)
	_check(named.size() >= 6, "scripts and scenes name variations (%d kinds)" % named.size())
	for id: String in UIThemePalettes.ORDER:
		var theme := load(UIThemePalettes.theme_path(id)) as Theme
		_check(theme != null, "%s loads as a Theme" % id)
		if theme == null:
			continue
		for v in named.keys():
			_check(theme.get_type_variation_base(v) != &"", "%s defines %s (named in %s)" % [id, v, ", ".join(named[v])])

	# 4. UITheme's defaults are the default palette's runtime colours, and the
	#    default theme file agrees with them where both carry a value.
	var runtime := UIThemePalettes.runtime_colors(default_id)
	var ui := UITheme.new()
	for key in runtime.keys():
		var have: Color = ui.get(key)
		_check(_same(have, runtime[key]), "UITheme.%s default equals the %s palette (%s / %s)" % [key, default_id, have, runtime[key]])
	var theme := load(default_path) as Theme
	if theme != null:
		var win := theme.get_stylebox("panel", "WindowPanel") as StyleBoxFlat
		_check(win != null and _same(win.bg_color, UITheme.C_WINDOW_BG) and _same(win.border_color, UITheme.C_GOLDEN_BORDER), "the default theme's WindowPanel is UITheme's field and band")
		_check(_same(theme.get_color("font_color", "Label"), UITheme.C_TEXT), "the default theme's Label colour is UITheme.C_TEXT")
		_check(_same(theme.get_color("font_color", "TitleLabel"), UITheme.C_TITLE), "the default theme's TitleLabel colour is UITheme.C_TITLE")
		var btn := theme.get_stylebox("normal", "Button") as StyleBoxFlat
		_check(btn != null and _same(btn.bg_color, UITheme.C_BTN_NORM), "the default theme's Button plate is UITheme.C_BTN_NORM")

	print("\n" + ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
