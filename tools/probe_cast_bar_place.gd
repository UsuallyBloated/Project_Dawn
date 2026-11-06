extends SceneTree
# Headless probe for the player's own cast bar (2026-10-29): it sits centred,
# a little below the middle of the screen, clear of the band the hotbars
# occupy along the bottom edge, and shows on a cast's start and hides on its
# cancel. It used to sit 72 to 120 px above the bottom edge, under the
# hotbars, so a player never saw their own bar (the equip sheet's fizzle row:
# "Player cannot see their own casting bar."). Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_cast_bar_place.gd

# The hotbars' band: two bars anchored to the bottom edge (hotbar.gd).
const HOTBAR_BAND_PX := 160.0

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
	# A full-screen parent, as the HUD is, laid out before the bar joins.
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	await process_frame
	var bar = load("res://scripts/hud_cast_bar.gd").new()
	hud.add_child(bar)
	await process_frame
	await process_frame
	var screen: Vector2 = hud.size
	var rect: Rect2 = bar.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "the bar has a size (%s)" % rect.size)
	_check(Rect2(Vector2.ZERO, screen).encloses(rect), "the bar is wholly on screen (%s in %s)" % [rect, screen])
	var off: Vector2 = rect.get_center() - screen / 2.0
	_check(absf(off.x) < 1.0, "the bar is centred left to right (off by %.1f)" % off.x)
	_check(off.y >= 0.0 and off.y <= 150.0, "and a little below the middle (%.1f px down)" % off.y)
	_check(screen.y - rect.end.y >= HOTBAR_BAND_PX, "clear of the hotbars' band (%.0f px above the bottom edge)" % (screen.y - rect.end.y))
	_check(bar is DraggablePanel, "the bar can be dragged like the other panels")
	_check(not bar.visible, "hidden until a cast starts")

	var spells = root.get_node("/root/Spells")
	var spell := SpellData.new()
	spell.spell_name = "Probe Bolt"
	spell.cast_time = 1.2
	spells.casting_started.emit(spell)
	_check(bar.visible, "shown when a cast starts")
	_check(bar._label.text == "Probe Bolt", "with the spell's name (%s)" % bar._label.text)
	spells.casting_cancelled.emit()
	_check(not bar.visible, "hidden when the cast is cancelled")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
