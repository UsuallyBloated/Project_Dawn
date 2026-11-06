extends SceneTree
# Headless probe for the trade window's placement (2026-10-26): it opens in the
# middle of the screen and can be dragged like the other windows. It used to
# land at (-280, -180), off the top-left corner, and could not be moved: its
# centering set `position` inside the HUD (measured from the screen's corner,
# not the anchor), and it was a plain Panel. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_trade_window_place.gd

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

# The autoloads join the tree after _initialize, so the checks run on the
# first frame.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	# A full-screen parent, as the HUD is, laid out before the window joins.
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	await process_frame
	var tw = load("res://scripts/trade_window.gd").new()
	hud.add_child(tw)
	await process_frame
	await process_frame
	var screen: Vector2 = hud.size
	var rect: Rect2 = tw.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "the window has a size (%s)" % rect.size)
	_check(Rect2(Vector2.ZERO, screen).encloses(rect), "the window is wholly on screen (%s in %s)" % [rect, screen])
	var off: Vector2 = rect.get_center() - screen / 2.0
	_check(off.length() < 1.0, "the window is centred (off by %s)" % off)
	_check(tw is DraggablePanel, "the window can be dragged like the others")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
