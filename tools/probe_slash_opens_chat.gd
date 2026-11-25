extends SceneTree
# Probe (run headless, exits 1 on failure): the "/" key opens the chat line
# with the slash already typed (EQ's command key).
#
# What runs: the real hud.tscn and the chat windows the manager builds. Key
# presses are pushed into the root window as the engine delivers them, so the
# HUD's own key handling decides. Held: "/" opens the line on a slash with the
# caret after it; a second "/" is typed by the line and does not reset it;
# Shift+"/" opens nothing; Enter still opens the line empty; and "/" cannot be
# bound to an action.
#   godot --headless --path . -s tools/probe_slash_opens_chat.gd

const HUD_SCENE := "res://scenes/hud.tscn"
const SCREEN := Vector2i(1920, 1080)
const WATCHDOG_SECS := 60.0

var _fails := 0

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["OK     " if ok else "FAILED ", what])
	if not ok:
		_fails += 1

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)
	create_timer(WATCHDOG_SECS).timeout.connect(func() -> void:
		print("FAILED  the probe did not finish within %d s" % WATCHDOG_SECS)
		quit(1))

# One key press as the engine delivers it (press only; the release does nothing here).
func _press(keycode: Key, unicode: int = 0, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.shift_pressed = shift
	ev.pressed = true
	root.push_input(ev)

func _run() -> void:
	# Headless starts with a 64 px window; controls need a real one to take focus.
	root.size = SCREEN
	var chat_mgr := root.get_node("/root/ChatWindowManager") as CanvasLayer
	# The chat layer is hidden until the player enters the world; shown here.
	chat_mgr.visible = true
	var hud = load(HUD_SCENE).instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame

	var window = chat_mgr.get_active_window()
	_check(window != null, "the chat manager has a window for the line")
	if window == null:
		quit(1)
		return
	var line: LineEdit = window._chat_input

	_check(not chat_mgr.is_chat_input_focused(), "the chat line starts closed")

	# Shift+"/" is "?": it opens nothing.
	_press(KEY_SLASH, "?".unicode_at(0), true)
	await process_frame
	_check(not chat_mgr.is_chat_input_focused(), "Shift with the slash key opens nothing")

	_press(KEY_SLASH, "/".unicode_at(0))
	await process_frame
	_check(chat_mgr.is_chat_input_focused(), "the slash key opens the chat line")
	_check(line.text == "/", "the line opens holding one slash (it holds %s)" % var_to_str(line.text))
	_check(line.caret_column == 1, "the caret is after the slash (column %d)" % line.caret_column)

	# With the line open the key belongs to the line.
	_press(KEY_SLASH, "/".unicode_at(0))
	await process_frame
	_check(line.text == "//", "a slash typed into the open line is typed, not a reset (it holds %s)" % var_to_str(line.text))

	# Close the line, then Enter opens it empty as it always has.
	line.text = ""
	window._on_chat_text_submitted("")
	await process_frame
	_check(not chat_mgr.is_chat_input_focused(), "an empty submit closes the line")
	_press(KEY_ENTER)
	await process_frame
	_check(chat_mgr.is_chat_input_focused() and line.text == "", "Enter still opens the line empty")

	var settings := root.get_node("/root/GameSettings")
	_check(settings.is_reserved_key(KEY_SLASH), "the slash key cannot be bound to an action")
	_check(settings.is_reserved_key(KEY_ENTER) and settings.is_reserved_key(KEY_ESCAPE),
		"Enter and Escape are reserved as before")

	print("\n%s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)
