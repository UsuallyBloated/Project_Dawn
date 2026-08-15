extends Node

# `user://` resolves to a writable per-project data dir on every
# platform, including exported builds where `res://` is read-only.
# On Windows: %APPDATA%\Godot\app_userdata\Project_Dawn\debug.log.
# Open from the editor via Project > Open User Data Folder, or
# inspect `OS.get_user_data_dir()` to print the absolute path at
# runtime. The in-game console (F2) reads from `recent_lines` and
# subscribes to `line_emitted` for live tail without needing to
# open the file.
const LOG_PATH := "user://debug.log"
const MAX_LINES := 2000
const RING_CAPACITY := 2000

# Emitted on every successful _write so the in-game DebugConsole can
# tail without re-reading the file. `level` is one of INFO/WARN/
# ERROR/COMBAT for colorization.
signal line_emitted(text: String, level: String)

# Ring buffer of the most recent lines so the console can seed from
# whatever has accumulated before the player opened the window.
var recent_lines: Array[Dictionary] = []

var _file: FileAccess = null
var _line_count: int = 0

func _ready() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _file == null:
		push_warning("DebugLog: could not open %s for writing (error %d)" % [LOG_PATH, FileAccess.get_open_error()])
		return
	# Print the resolved absolute path so the dev can locate the file
	# even when running from the launcher (where the user:// dir lives
	# under %APPDATA%\Godot\app_userdata\...).
	print("DebugLog: writing to ", ProjectSettings.globalize_path(LOG_PATH))
	_write_raw("=== Session started %s ===" % Time.get_datetime_string_from_system())
	_write_raw("=== %s ===" % BuildInfo.one_line())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _file != null:
			_write_raw("=== Session ended %s ===" % Time.get_datetime_string_from_system())
			_file.close()
			_file = null

# ── Public API ────────────────────────────────────────────────────────────────

func info(msg: String) -> void:
	_write("INFO", msg)

func warn(msg: String) -> void:
	_write("WARN", msg)
	push_warning(msg)

func error(msg: String) -> void:
	_write("ERROR", msg)
	push_error(msg)

func combat(msg: String) -> void:
	_write("COMBAT", msg)

# ── Internal ──────────────────────────────────────────────────────────────────

func _write(level: String, msg: String) -> void:
	var ts := Time.get_time_string_from_system()
	# Explicit String type — Dictionary.get returns Variant, which the
	# strict-mode linter (Warnings = Errors in project.godot) rejects
	# when assigned via `:=` inference.
	var tag: String
	match level:
		"WARN":   tag = "[WARN ]"
		"ERROR":  tag = "[ERROR]"
		"COMBAT": tag = "[COMBT]"
		_:        tag = "[INFO ]"
	var line := "%s %s %s" % [ts, tag, msg]
	_write_raw(line)
	# Maintain in-memory ring for the in-game console and emit the
	# signal whether or not the file write succeeded — the console
	# stays useful even if file IO is broken.
	recent_lines.append({"text": line, "level": level})
	if recent_lines.size() > RING_CAPACITY:
		recent_lines.pop_front()
	line_emitted.emit(line, level)

func _write_raw(line: String) -> void:
	if _file == null:
		return
	_file.store_line(line)
	_file.flush()
	_line_count += 1
	if _line_count >= MAX_LINES:
		_rotate()

func _rotate() -> void:
	_file.close()
	var old_path := LOG_PATH.replace(".log", "_prev.log")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(LOG_PATH),
		ProjectSettings.globalize_path(old_path))
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_line_count = 0
	if _file != null:
		_write_raw("=== Log rotated (prev saved to debug_prev.log) ===")
		# Re-stamp after rotation. The build line is written once at session
		# start, so without this a session long enough to rotate (2000 lines,
		# entirely normal in a real playtest) hands us a debug.log with no
		# indication of which client produced it — exactly when we most need it.
		_write_raw("=== %s ===" % BuildInfo.one_line())
