extends Node

# `user://` resolves to a writable per-project data dir on every
# platform, including exported builds where `res://` is read-only.
# On Windows: %APPDATA%\Godot\app_userdata\Project_Dawn\debug.log.
# Open from the editor via Project > Open User Data Folder, or
# inspect `OS.get_user_data_dir()` to print the absolute path at
# runtime.
const LOG_PATH := "user://debug.log"
const MAX_LINES := 2000

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _file != null:
			_write_raw("=== Session ended %s ===" % Time.get_datetime_string_from_system())
			_file.close()
			_file = null

# ── Public API ────────────────────────────────────────────────────────────────

func info(msg: String) -> void:
	_write("[INFO ] %s" % msg)

func warn(msg: String) -> void:
	_write("[WARN ] %s" % msg)
	push_warning(msg)

func error(msg: String) -> void:
	_write("[ERROR] %s" % msg)
	push_error(msg)

func combat(msg: String) -> void:
	_write("[COMBТ] %s" % msg)

# ── Internal ──────────────────────────────────────────────────────────────────

func _write(msg: String) -> void:
	var ts := Time.get_time_string_from_system()
	_write_raw("%s %s" % [ts, msg])

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
