extends SceneTree
# Headless probe of every window's GEOMETRY: where each window sits, how big it
# is, and where every control inside it lands. Written for the theming pass
# (2026-11-18, R5 of the structure assessment): the pass changes colours,
# fonts and borders on purpose, so colours are not recorded here; what must
# not change by accident is the layout. The probe records a fixture once and
# compares every later run against it, so a container that collapsed, a
# window that drifted off screen or a label that lost its row is caught, and
# the few pixels a thicker border moves a child by are reported, not failed.
#
# Each control is keyed by its class and its index among its siblings, never
# by name: code-built controls get engine names (`@Label@23`) that change
# with any node added earlier, and a window moved to a scene renames them all.
#
#   godot --headless --path . -s tools/probe_window_geometry.gd              # compare
#   godot --headless --path . -s tools/probe_window_geometry.gd -- --write   # record
#   godot --headless --path . -s tools/probe_window_geometry.gd -- --tolerance 12
#
# Exits 1 on a missing or added window, a window whose own rect moved by more
# than WINDOW_TOLERANCE_PX, a control missing or added inside one, a
# visibility change, or a child that drifted by more than the tolerance.

const FIXTURE := "res://tools/fixtures/window_geometry.txt"
const HUD_SCENE := "res://scenes/hud.tscn"
const HOTBAR_SCRIPT := "res://scripts/hotbar.gd"
const TEST_PANEL_SCRIPT := "res://scripts/test_panel.gd"
const SCREEN := Vector2i(1920, 1080)
const WINDOW_TOLERANCE_PX := 1.0
const DEFAULT_CHILD_TOLERANCE_PX := 8.0
const WATCHDOG_SECS := 120.0

var _fails := 0
var _write := false
var _tolerance := DEFAULT_CHILD_TOLERANCE_PX

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--write":
			_write = true
		elif args[i] == "--tolerance" and i + 1 < args.size():
			_tolerance = float(args[i + 1])
	process_frame.connect(_run, CONNECT_ONE_SHOT)

# ── Discovery (the click check's, 2026-10-29) ───────────────────────────────

# A window's label: its script's file, or, for a bare DraggablePanel built in
# code (whose engine name, `@Panel@980`, changes with any node added before
# it), `panel[i]`, its index among the bare panels of its layer.
func _label(n: Node, bare_index: Array) -> String:
	var s: Script = n.get_script() as Script
	if s != null and s.resource_path.get_file() != "draggable_panel.gd":
		return s.resource_path.get_file()
	var i: int = bare_index[0]
	bare_index[0] += 1
	return "panel[%d]" % i

func _find_windows(hud: CanvasLayer, hotbar: CanvasLayer, test_panel: CanvasLayer) -> Array:
	var windows: Array = []
	var layers := [[hud, "hud"], [hotbar, "hotbar"], [test_panel, "test_panel"]]
	var chat_mgr: CanvasLayer = root.get_node_or_null("ChatWindowManager") as CanvasLayer
	if chat_mgr != null:
		chat_mgr.visible = true
		layers.append([chat_mgr, "chat"])
	for layer in layers:
		var bare := [0]
		for child in (layer[0] as Node).get_children():
			if child is DraggablePanel or (child.get_script() != null and child.get_script().resource_path.get_file() in ["debug_console.gd", "hud_disconnect_notice.gd"]):
				windows.append([child, "%s/%s" % [layer[1], _label(child, bare)]])
	return windows

# ── Recording ───────────────────────────────────────────────────────────────

static func _fmt(r: Rect2) -> String:
	return "%d,%d %dx%d" % [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]

# One line per control under `w`, depth first, keyed by class and sibling
# index among Controls; the window itself is the first line with key ".".
func _record(w: Control, label: String, out: Array) -> void:
	out.append("%s | . | %s | %s" % [label, _fmt(w.get_global_rect()), "shown" if w.visible else "hidden"])
	_record_children(w, "", label, out)

func _record_children(parent: Node, prefix: String, label: String, out: Array) -> void:
	var index := 0
	for child in parent.get_children():
		if not (child is Control):
			continue
		var c := child as Control
		var key := "%s%s[%d]" % [prefix, c.get_class(), index]
		index += 1
		out.append("%s | %s | %s | %s" % [label, key, _fmt(c.get_global_rect()), "shown" if c.visible else "hidden"])
		_record_children(c, key + "/", label, out)

# ── Comparing ───────────────────────────────────────────────────────────────

static func _parse(lines: PackedStringArray) -> Dictionary:
	var out := {}
	for line in lines:
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var parts := line.split(" | ")
		if parts.size() != 4:
			continue
		var rect_parts := parts[2].split(" ")
		var pos := rect_parts[0].split(",")
		var sz := rect_parts[1].split("x")
		out[parts[0] + " | " + parts[1]] = {
			"rect": Rect2(float(pos[0]), float(pos[1]), float(sz[0]), float(sz[1])),
			"vis": parts[3],
		}
	return out

func _compare(recorded: Array) -> void:
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	_check(f != null, "the fixture exists at %s (record it with -- --write)" % FIXTURE)
	if f == null:
		return
	var before := _parse(f.get_as_text().split("\n"))
	var after := _parse(PackedStringArray(recorded))
	var windows_before := {}
	var windows_after := {}
	for k: String in before.keys():
		windows_before[k.split(" | ")[0]] = true
	for k: String in after.keys():
		windows_after[k.split(" | ")[0]] = true
	for wname in windows_before.keys():
		_check(windows_after.has(wname), "window still present: %s" % wname)
	for wname in windows_after.keys():
		_check(windows_before.has(wname), "window in the fixture: %s" % wname)
	var worst := {}   # window -> [max drift, key]
	var missing := 0
	var added := 0
	for k: String in before.keys():
		if not after.has(k):
			var wname: String = k.split(" | ")[0]
			if windows_after.has(wname):
				missing += 1
				print("      missing: " + k)
			continue
		var a: Dictionary = before[k]
		var b: Dictionary = after[k]
		var parts := k.split(" | ")
		var wname := parts[0]
		var is_window := parts[1] == "."
		var ra: Rect2 = a["rect"]
		var rb: Rect2 = b["rect"]
		var dp := (ra.position - rb.position).abs()
		var ds := (ra.size - rb.size).abs()
		var drift := maxf(maxf(dp.x, dp.y), maxf(ds.x, ds.y))
		if a["vis"] != b["vis"]:
			_check(false, "%s visibility unchanged (%s to %s)" % [k, a["vis"], b["vis"]])
		if is_window:
			_check(drift <= WINDOW_TOLERANCE_PX, "%s sits where it did (%s to %s)" % [wname, _fmt(ra), _fmt(rb)])
		else:
			if drift > _tolerance:
				_check(false, "%s within %.0f px (%s to %s)" % [k, _tolerance, _fmt(ra), _fmt(rb)])
			if not worst.has(wname) or drift > worst[wname][0]:
				worst[wname] = [drift, parts[1]]
	for k: String in after.keys():
		if not before.has(k):
			var wname: String = k.split(" | ")[0]
			if windows_before.has(wname):
				added += 1
				print("      added:   " + k)
	_check(missing == 0, "no control missing inside a window (%d)" % missing)
	_check(added == 0, "no control added inside a window (%d)" % added)
	var names := worst.keys()
	names.sort()
	for wname in names:
		print("      drift %5.1f px  %s  (%s)" % [worst[wname][0], wname, worst[wname][1]])

# ── Run ─────────────────────────────────────────────────────────────────────

func _run() -> void:
	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = WATCHDOG_SECS
	watchdog.timeout.connect(func() -> void:
		printerr("probe_window_geometry: watchdog fired after %d s" % int(WATCHDOG_SECS))
		quit(1))
	root.add_child(watchdog)
	watchdog.start()
	await process_frame
	root.size = SCREEN
	await process_frame

	var hud: CanvasLayer = (load(HUD_SCENE) as PackedScene).instantiate()
	root.add_child(hud)
	var hotbar: CanvasLayer = load(HOTBAR_SCRIPT).new()
	root.add_child(hotbar)
	var test_panel: CanvasLayer = load(TEST_PANEL_SCRIPT).new()
	root.add_child(test_panel)
	await process_frame
	await process_frame

	var windows := _find_windows(hud, hotbar, test_panel)
	_check(windows.size() >= 20, "found the windows (%d)" % windows.size())

	# Every window shown, so hidden-by-default ones are laid out too; a frame
	# for the containers to settle.
	for pair in windows:
		(pair[0] as Control).visible = true
	await process_frame
	await process_frame

	var recorded: Array = []
	var screen := Rect2(Vector2.ZERO, Vector2(SCREEN))
	for pair in windows:
		var w: Control = pair[0]
		var r := w.get_global_rect()
		_check(r.size.x > 0.0 and r.size.y > 0.0, "%s has a size (%s)" % [pair[1], _fmt(r)])
		_check(screen.intersects(r), "%s is on screen (%s)" % [pair[1], _fmt(r)])
		_record(w, pair[1], recorded)
	print("      %d windows, %d controls recorded" % [windows.size(), recorded.size()])

	if _write:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE.get_base_dir()))
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		_check(f != null, "fixture written to %s" % FIXTURE)
		if f != null:
			f.store_line("# Window geometry fixture, written by tools/probe_window_geometry.gd -- --write.")
			f.store_line("# window | class[index] path | x,y wxh | shown/hidden   (screen %dx%d)" % [SCREEN.x, SCREEN.y])
			for line in recorded:
				f.store_line(line)
	else:
		_compare(recorded)

	print("\n" + ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
