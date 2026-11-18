extends SceneTree
# Headless probe for the saved UI scale (2026-11-11): the value the options
# screen saves (Esc, Options, Graphics, UI Scale, Apply) is the window's scale
# the moment the world's HUD is on screen, whatever the launcher set before
# it. From 2026-09-23 to 2026-11-11 hud.gd reset the window to a constant 1.0
# in its _ready, so the saved slider value was thrown away at every login and
# held only after an Apply in the same session. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_ui_scale_persists.gd

const HUD_SCENE := "res://scenes/hud.tscn"
const LOGIN_SCRIPT := "res://scripts/login.gd"
const WATCHDOG_SECS := 120.0

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

# The autoloads join the tree after _initialize, so the checks run on the
# first frame. The watchdog ends a run the old code aborts mid-way (a script
# error leaves no quit behind it).
func _initialize() -> void:
	create_timer(WATCHDOG_SECS).timeout.connect(func() -> void:
		print("FAIL  the probe did not finish within %d s" % WATCHDOG_SECS)
		quit(1))
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	await process_frame
	var settings: Node = root.get_node("/root/GameSettings")
	var dial: float = settings.GAME_UI_SCALE
	var saved: float = settings.ui_scale   # the dev box's own setting, put back at the end

	# The rule: the game scale is the slider times the HUD dial, clamped as
	# the loader clamps it.
	settings.ui_scale = 1.25
	_check(is_equal_approx(settings.game_ui_scale(), 1.25 * dial),
		"the game scale is the slider times the HUD dial (%.2f)" % settings.game_ui_scale())
	settings.ui_scale = 3.0
	_check(is_equal_approx(settings.game_ui_scale(), 2.0 * dial),
		"a slider value past the clamp is held at 2.0 (%.2f)" % settings.game_ui_scale())
	settings.ui_scale = 0.75
	settings.apply_ui_scale()
	_check(is_equal_approx(root.content_scale_factor, 0.75 * dial),
		"apply_ui_scale sets the window to it (%.2f)" % root.content_scale_factor)

	# The launch order: the launcher scales the window for itself, then the
	# world's HUD takes the saved value back. The old _ready set 1.0 here
	# whatever had been saved.
	settings.ui_scale = 1.25
	var login_scale: float = load(LOGIN_SCRIPT).LOGIN_UI_SCALE
	root.content_scale_factor = login_scale
	_check(not is_equal_approx(login_scale, 1.25 * dial),
		"the launcher's own scale differs from the saved value, so the next check means something (%.2f)" % login_scale)
	var hud: CanvasLayer = (load(HUD_SCENE) as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	_check(is_equal_approx(root.content_scale_factor, 1.25 * dial),
		"the HUD's _ready applies the saved scale over the launcher's (%.2f)" % root.content_scale_factor)

	# The options screen's Apply runs apply_graphics; it lands on the same
	# number (one home), and nothing the HUD does afterwards resets it.
	settings.ui_scale = 1.5
	settings.apply_graphics()
	await process_frame
	await process_frame
	_check(is_equal_approx(root.content_scale_factor, 1.5 * dial),
		"an Apply in game moves the window to the new value and it stays (%.2f)" % root.content_scale_factor)

	settings.ui_scale = saved
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
