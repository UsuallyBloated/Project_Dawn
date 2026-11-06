extends SceneTree
# Regression check (run headless, exits 1 on failure): a click on any part of an
# open window stops at that window. It never reaches a window under it, the
# HUD, or the world (a world click while holding an item is a ground drop).
#
# The rule it holds: Godot picks the control under the mouse by TREE ORDER and
# ignores z_index (verified on 4.4.1), so a window raised with z_index draws on
# top while its clicks go to whatever sits later in the tree. That was the bank
# window on 2026-10-26. So no window carries z_index, and a window moves to the
# front of its siblings when it opens and when it is clicked (DraggablePanel).
#
# What runs: the real hud.tscn, the hotbar and the Test Panel, and the chat
# windows, over a full-screen sentinel that stands for the world. Every window
# is shown alone and clicked on a grid of points: nothing may reach the
# sentinel. Then the stacking rules: an opened window is on top of one that
# overlaps it, a clicked window comes to the front, the disconnect notice
# covers everything, the debug console blocks only its own panel.
#   godot --headless --path . -s tools/check_window_click_blocking.gd

const HUD_SCENE := "res://scenes/hud.tscn"
const HOTBAR_SCRIPT := "res://scripts/hotbar.gd"
const TEST_PANEL_SCRIPT := "res://scripts/test_panel.gd"
const SCREEN := Vector2i(1920, 1080)
const GRID := 16.0   # px between the probe points over a window
const WATCHDOG_SECS := 240.0

var _fails := 0
var _sentinel: Control
var _sentinel_hits := 0
var _hud: CanvasLayer
var _all_windows: Array = []   # [window, label] pairs, every window found

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["OK     " if ok else "FAILED ", what])
	if not ok:
		_fails += 1

func _initialize() -> void:
	# The autoloads join the tree after _initialize; everything runs on the
	# first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)
	# A script error inside _run would leave the process running forever with
	# no verdict; the watchdog turns that into a failure.
	create_timer(WATCHDOG_SECS).timeout.connect(func() -> void:
		print("FAILED  the check did not finish within %d s" % WATCHDOG_SECS)
		quit(1))

# ── Input delivery ───────────────────────────────────────────────────────────
# Pushed in canvas coordinates: the headless window is 64 px square, so a
# window-space event would land outside every panel after the stretch.

func _hover(p: Vector2) -> Control:
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	root.push_input(mv, true)
	return root.gui_get_hovered_control()

func _press(p: Vector2, button: MouseButton) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.position = p
	down.global_position = p
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = p
	up.global_position = p
	root.push_input(down, true)
	root.push_input(up, true)

# The window a control belongs to: the nearest ancestor that is a window
# root, or the sentinel. A bag's confirm panel is top_level but still a
# child, so the walk finds its bag.
func _owner_window(c: Control) -> Node:
	var n: Node = c
	while n != null:
		if n == _sentinel or _is_window_root(n):
			return n
		n = n.get_parent()
	return null

func _is_window_root(n: Node) -> bool:
	if n is DraggablePanel:
		return true
	var s: Script = n.get_script() as Script
	if s == null:
		return false
	var file: String = s.resource_path.get_file()
	return file == "debug_console.gd" or file == "hud_disconnect_notice.gd"

func _label(n: Node) -> String:
	if n == null:
		return "nothing"
	if n == _sentinel:
		return "THE WORLD"
	var s: Script = n.get_script() as Script
	if s != null and s.resource_path.get_file() != "draggable_panel.gd":
		return s.resource_path.get_file()
	return n.name

# A visible, mouse-stopping control inside `w` whose rect lies clear of
# `avoid`, and not a button (a button's release could close the window).
func _stop_child_outside(w: Control, avoid: Rect2) -> Control:
	var queue: Array = w.get_children()
	while not queue.is_empty():
		var n = queue.pop_front()
		if n is Control:
			var c := n as Control
			if c.visible and c.mouse_filter == Control.MOUSE_FILTER_STOP and not (c is BaseButton) and not c.top_level:
				var r := c.get_global_rect()
				if r.size.x >= 8.0 and r.size.y >= 8.0 and not r.intersects(avoid) and w.get_global_rect().encloses(r):
					return c
		queue.append_array(n.get_children())
	return null

func _hud_window(script_file: String) -> Control:
	for child in _hud.get_children():
		var s = child.get_script()
		if s != null and s.resource_path.get_file() == script_file:
			return child
	return null

# ── The scan of one window ───────────────────────────────────────────────────
# Middle button: the picking is the same for every button, and a middle press
# fires no Button, no tab and no cell handler, so a scan cannot close the
# window it is scanning.

func _scan_window(w: Control, label: String) -> void:
	# Alone on screen: a click that lands on another window drawn above it (the
	# Test Panel's layer sits over the HUD) is that window's, not a leak.
	var others_visible := {}
	for pair in _all_windows:
		var other: Control = pair[0]
		if other != w:
			others_visible[other] = other.visible
			other.visible = false
	var was_visible := w.visible
	w.visible = true
	await process_frame
	await process_frame
	var rect := w.get_global_rect()
	_check(rect.size.x > 8.0 and rect.size.y > 8.0, "%s has a size (%s)" % [label, rect.size])
	var screen := Rect2(Vector2.ZERO, Vector2(SCREEN))
	rect = rect.intersection(screen)
	var points := 0
	var leaks := 0
	var first_leak := ""
	var y := rect.position.y + 1.0
	while y < rect.end.y - 1.0:
		var x := rect.position.x + 1.0
		while x < rect.end.x - 1.0:
			var p := Vector2(x, y)
			var before := _sentinel_hits
			var hovered := _hover(p)
			_press(p, MOUSE_BUTTON_MIDDLE)
			points += 1
			var owner := _owner_window(hovered) if hovered != null else null
			if hovered == null or owner == _sentinel or _sentinel_hits != before or owner != w:
				leaks += 1
				if first_leak == "":
					first_leak = "at %s the click reached %s" % [p, _label(owner)]
			x += GRID
		y += GRID
	_check(points > 0 and leaks == 0, "%s: %d points, every click stays on it%s" % [
		label, points, "" if leaks == 0 else " (%d leaks; first %s)" % [leaks, first_leak]])
	w.visible = was_visible
	for other in others_visible:
		other.visible = others_visible[other]
	await process_frame

# ── Run ──────────────────────────────────────────────────────────────────────

func _run() -> void:
	await process_frame
	root.size = SCREEN
	await process_frame

	# The world, and anything beneath every window: the first child of the
	# root, on the bottom canvas, so every control on every layer is picked
	# before it.
	_sentinel = Control.new()
	_sentinel.name = "WorldSentinel"
	_sentinel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sentinel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sentinel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_sentinel_hits += 1)
	root.add_child(_sentinel)
	root.move_child(_sentinel, 0)

	_hud = (load(HUD_SCENE) as PackedScene).instantiate()
	root.add_child(_hud)
	var hotbar: CanvasLayer = load(HOTBAR_SCRIPT).new()
	root.add_child(hotbar)
	var test_panel: CanvasLayer = load(TEST_PANEL_SCRIPT).new()
	root.add_child(test_panel)
	await process_frame
	await process_frame

	# Sanity: the sentinel is the world. A point with nothing over it.
	var clear := Vector2(1500.0, 700.0)
	var h := _hover(clear)
	_check(h == _sentinel, "a click on open ground reaches the world (hovered %s)" % _label(_owner_window(h) if h else null))

	# 1. The windows, and the invariant: no window root carries z_index.
	var windows: Array = []
	for child in _hud.get_children():
		if child is DraggablePanel or (child.get_script() != null and child.get_script().resource_path.get_file() == "debug_console.gd"):
			windows.append([child, "hud/" + _label(child)])
	for child in hotbar.get_children():
		if child is DraggablePanel:
			windows.append([child, "hotbar/" + child.name])
	for child in test_panel.get_children():
		if child is DraggablePanel:
			windows.append([child, "test_panel/" + child.name])
	# The chat layer is hidden until the player enters the world; shown here.
	var chat_mgr: CanvasLayer = root.get_node_or_null("ChatWindowManager") as CanvasLayer
	if chat_mgr != null:
		chat_mgr.visible = true
		for child in chat_mgr.get_children():
			if child is DraggablePanel:
				windows.append([child, "chat/" + child.name])
	_all_windows = windows
	_check(windows.size() >= 20, "found the windows (%d)" % windows.size())
	for pair in windows:
		var w: Control = pair[0]
		_check(w.z_index == 0, "%s carries no z_index (%d)" % [pair[1], w.z_index])
	for pair in windows:
		var w: Control = pair[0]
		if w.get_script() != null and w.get_script().resource_path.get_file() == "debug_console.gd":
			continue   # its own section below: it blocks only its panel
		await _scan_window(w, pair[1])

	# A window whose constructor takes an argument must still run the base
	# one, or it opens without the stacking hook (LootWindow, 2026-10-29).
	var stub_bag := Node.new()
	var loot_window: DraggablePanel = load("res://scripts/loot_window.gd").new(stub_bag)
	var hook := Callable(loot_window, "_on_draggable_visibility_changed")
	_check(loot_window.has_method("_on_draggable_visibility_changed") and loot_window.visibility_changed.is_connected(hook),
		"the loot window's constructor runs the base one (the raise-on-show hook)")
	loot_window.free()
	stub_bag.free()

	# From here every window starts hidden; each section shows what it needs.
	for pair in windows:
		(pair[0] as Control).visible = false
	await process_frame

	# 2. Stacking: an opened window is on top of an earlier one it overlaps.
	# The bank, the vendor and the dialogue window sit before the journal and
	# the trade window in the HUD's tree (the ones z_index used to raise).
	for pair in [["bank_window.gd", "quest_journal.gd"], ["vendor_window.gd", "trade_window.gd"], ["dialogue_window.gd", "trade_window.gd"], ["options_screen.gd", "quest_journal.gd"]]:
		var earlier := _hud_window(pair[0])
		var later := _hud_window(pair[1])
		if earlier == null or later == null:
			_check(false, "the HUD holds %s and %s" % pair)
			continue
		later.visible = true
		await process_frame
		await process_frame
		earlier.visible = true   # opened last: must come to the front
		await process_frame
		await process_frame
		# The window underneath is moved right so a good part of it shows (the
		# options screen encloses the journal outright; the others poke out by
		# twenty pixels), leaving an overlap to probe and a body to click.
		var later_home := later.position
		later.position.x += 300.0
		await process_frame
		var overlap := earlier.get_global_rect().intersection(later.get_global_rect())
		_check(overlap.size.x > 20.0 and overlap.size.y > 20.0, "%s and %s overlap (%s)" % [pair[0], pair[1], overlap])
		var mid := overlap.get_center()
		var got := _owner_window(_hover(mid))
		_check(got == earlier, "%s opened over %s gets the click at their overlap (it went to %s)" % [pair[0], pair[1], _label(got)])
		# 3. Clicking the window underneath brings it to the front.
		var lr := later.get_global_rect()
		var own := Vector2(lr.position.x + 8.0, lr.position.y + 8.0)   # inside its body, past the resize margin
		if overlap.has_point(own):
			own = Vector2(lr.end.x - 8.0, lr.end.y - 8.0)
		_hover(own)
		_press(own, MOUSE_BUTTON_LEFT)
		await process_frame
		await process_frame
		got = _owner_window(_hover(mid))
		_check(got == later, "a click on %s brings it to the front over %s (the overlap then went to %s)" % [pair[1], pair[0], _label(got)])
		# The same by a click on something INSIDE the window underneath (a cell,
		# a tab, a text line), which a child control takes before the window's
		# own input ever sees it.
		if earlier.has_method("raise_to_front"):   # absent on the pre-rule base class
			earlier.call("raise_to_front")
		await process_frame
		var child := _stop_child_outside(later, overlap)
		if child == null:
			print("note: %s has no plain control clear of the overlap; the child-click raise is not exercised on it" % pair[1])
		else:
			var at := child.get_global_rect().get_center()
			_hover(at)
			_press(at, MOUSE_BUTTON_LEFT)
			await process_frame
			await process_frame
			got = _owner_window(_hover(mid))
			_check(got == later, "a click on %s inside %s brings it to the front over %s (the overlap then went to %s)" % [child.get_class(), pair[1], pair[0], _label(got)])
		earlier.visible = false
		later.visible = false
		later.position = later_home
		await process_frame

	# 4. The disconnect notice covers everything, windows opened later included.
	var notice := _hud_window("hud_disconnect_notice.gd")
	var bank := _hud_window("bank_window.gd")
	if notice != null and bank != null:
		bank.visible = true
		await process_frame
		notice.call("_on_disconnected", "a test")
		await process_frame
		await process_frame
		var nrect := notice.get_global_rect()
		_check(nrect.size == Vector2(SCREEN), "the disconnect notice fills the screen when shown (%s)" % nrect)
		var over_bank := bank.get_global_rect().get_center()
		var got := _owner_window(_hover(over_bank))
		_check(got == notice, "with the notice up, a click over the bank reaches the notice (it went to %s)" % _label(got))
		got = _owner_window(_hover(clear))
		_check(got == notice, "with the notice up, a click on open ground reaches the notice (it went to %s)" % _label(got))
		# A window opened while the notice is up (a keyboard shortcut) goes
		# back beneath it.
		var journal := _hud_window("quest_journal.gd")
		if journal != null:
			journal.visible = true
			await process_frame
			await process_frame
			got = _owner_window(_hover(journal.get_global_rect().get_center()))
			_check(got == notice, "a window opened under the notice stays beneath it (the click went to %s)" % _label(got))
			journal.visible = false
		notice.visible = false
		bank.visible = false
		await process_frame
	else:
		_check(false, "the HUD holds the disconnect notice and the bank")

	# 5. The debug console blocks its own panel and nothing else.
	var console := _hud_window("debug_console.gd")
	if console != null and bank != null:
		console.call("toggle")
		await process_frame
		await process_frame
		var bg: Control = console.get("_bg")
		_check(console.visible and bg != null, "the console toggles on")
		if bg != null:
			var inside := bg.get_global_rect().get_center()
			var got := _owner_window(_hover(inside))
			_check(got == console, "a click on the console's panel stays on the console (it went to %s)" % _label(got))
			got = _owner_window(_hover(clear))
			_check(got == _sentinel, "with the console open, a click on open ground still reaches the world (it went to %s)" % _label(got))
			# A window opened while the console is up sits above it; a click on the
			# console's panel brings the console back.
			bank.visible = true
			await process_frame
			await process_frame
			var overlap := bg.get_global_rect().intersection(bank.get_global_rect())
			if overlap.size.x > 20.0 and overlap.size.y > 20.0:
				got = _owner_window(_hover(overlap.get_center()))
				_check(got == bank, "the bank opened over the console gets their overlap (it went to %s)" % _label(got))
				var corner := Vector2(bg.get_global_rect().position.x + 8.0, bg.get_global_rect().position.y + 8.0)
				_hover(corner)
				_press(corner, MOUSE_BUTTON_LEFT)
				await process_frame
				await process_frame
				got = _owner_window(_hover(overlap.get_center()))
				_check(got == console, "a click on the console brings it back over the bank (the overlap then went to %s)" % _label(got))
			bank.visible = false
		console.call("toggle")
		await process_frame
	else:
		_check(false, "the HUD holds the debug console and the bank")

	print("")
	print("window click blocking: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
