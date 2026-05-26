extends CanvasLayer

# Owns all chat windows. Replaces the single-window CanvasLayer that
# CombatLog used to be — CombatLog is now a pure broker emitting
# `line_added` and this manager fans output into N ChatWindow nodes.
#
# Layout (positions, sizes, names) persists through GameSettings.
# Chunk 1 of the multi-window chat plan: framework + create/rename/delete.
# Per-window filters and per-window display settings are deferred.

signal active_window_changed(id: int)

const _ChatWindowScript := preload("res://scripts/chat_window.gd")

const DEFAULT_POS  := Vector2(10, 540)
const DEFAULT_SIZE := Vector2(300, 168)
const MIN_SIZE     := Vector2(180, 100)

# Cascade offset applied to each newly-created window so they don't all
# stack at the same coordinates.
const NEW_WINDOW_CASCADE := Vector2(24, 24)

var _windows: Array[ChatWindow] = []
var _windows_by_id: Dictionary = {}
var _next_window_id: int = 1
var _active_window_id: int = 0

var _rename_dialog: AcceptDialog = null
var _rename_line_edit: LineEdit = null
var _rename_target_id: int = 0
var _context_menu: PopupMenu = null
var _context_target_id: int = 0

func _ready() -> void:
	# Match the legacy CombatLog behaviour: hidden until the local
	# player's `_ready` flips us on after entering world.tscn.
	# Otherwise the chat would render over the lobby / Enter World
	# screen and catch pre-world signal noise.
	visible = false
	_build_rename_dialog()
	_build_context_menu()
	_restore_or_seed_windows()
	CombatLog.show_chat_input_requested.connect(_on_show_chat_input)

# ── Window creation / deletion / rename ──────────────────────────────────────

func new_window(window_name: String = "") -> ChatWindow:
	var id := _next_window_id
	_next_window_id += 1
	var w := _ChatWindowScript.new()
	w.window_id = id
	var name_to_use := window_name if window_name != "" else "Chat %d" % id
	var pos := DEFAULT_POS + NEW_WINDOW_CASCADE * (_windows.size())
	w.setup(pos, DEFAULT_SIZE, MIN_SIZE)
	w.set_window_name(name_to_use)
	_wire_window_signals(w)
	add_child(w)
	_windows.append(w)
	_windows_by_id[id] = w
	if _active_window_id == 0:
		_set_active(id)
	_save_layout()
	return w

func _wire_window_signals(w: ChatWindow) -> void:
	w.window_renamed.connect(_on_window_renamed)
	w.close_requested.connect(_on_window_close_requested)
	w.context_menu_requested.connect(_on_window_context_menu_requested)
	w.focus_requested.connect(_on_window_focus_requested)
	w.text_submitted.connect(_on_window_text_submitted)

func delete_window(id: int) -> void:
	if _windows.size() <= 1:
		return
	var w: ChatWindow = _windows_by_id.get(id, null)
	if w == null:
		return
	_windows.erase(w)
	_windows_by_id.erase(id)
	w.queue_free()
	if _active_window_id == id:
		_set_active(_windows[0].window_id if not _windows.is_empty() else 0)
	_save_layout()

func rename_window(id: int, new_name: String) -> void:
	var w: ChatWindow = _windows_by_id.get(id, null)
	if w == null:
		return
	w.set_window_name(new_name)

# ── Active window tracking ───────────────────────────────────────────────────

func _set_active(id: int) -> void:
	if _active_window_id == id:
		return
	_active_window_id = id
	active_window_changed.emit(id)

func get_active_window() -> ChatWindow:
	return _windows_by_id.get(_active_window_id, null)

func _on_window_focus_requested(id: int) -> void:
	_set_active(id)

func _on_window_renamed(_id: int, _new_name: String) -> void:
	_save_layout()

func _on_window_close_requested(id: int) -> void:
	delete_window(id)

# ── Right-click context menu ─────────────────────────────────────────────────

const _MENU_ID_NEW    := 1
const _MENU_ID_RENAME := 2
const _MENU_ID_DELETE := 3

func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.add_item("New Window", _MENU_ID_NEW)
	_context_menu.add_item("Rename...",  _MENU_ID_RENAME)
	_context_menu.add_item("Delete",     _MENU_ID_DELETE)
	_context_menu.id_pressed.connect(_on_context_menu_selected)
	add_child(_context_menu)

func _on_window_context_menu_requested(id: int, screen_pos: Vector2) -> void:
	_context_target_id = id
	# Disable Delete when only one window remains.
	var idx := _context_menu.get_item_index(_MENU_ID_DELETE)
	_context_menu.set_item_disabled(idx, _windows.size() <= 1)
	_context_menu.position = Vector2i(screen_pos)
	_context_menu.popup()

func _on_context_menu_selected(menu_id: int) -> void:
	match menu_id:
		_MENU_ID_NEW:
			new_window()
		_MENU_ID_RENAME:
			_open_rename_dialog(_context_target_id)
		_MENU_ID_DELETE:
			delete_window(_context_target_id)

# ── Rename dialog ────────────────────────────────────────────────────────────

func _build_rename_dialog() -> void:
	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = "Rename Chat Window"
	_rename_dialog.dialog_hide_on_ok = true
	_rename_dialog.min_size = Vector2i(280, 100)
	_rename_line_edit = LineEdit.new()
	_rename_line_edit.placeholder_text = "Window name"
	_rename_line_edit.custom_minimum_size = Vector2(240, 0)
	_rename_dialog.add_child(_rename_line_edit)
	_rename_dialog.register_text_enter(_rename_line_edit)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

func _open_rename_dialog(id: int) -> void:
	var w: ChatWindow = _windows_by_id.get(id, null)
	if w == null:
		return
	_rename_target_id = id
	_rename_line_edit.text = w.window_name
	_rename_dialog.popup_centered()
	_rename_line_edit.grab_focus()
	_rename_line_edit.select_all()

func _on_rename_confirmed() -> void:
	var new_name := _rename_line_edit.text.strip_edges()
	if new_name.is_empty():
		return
	rename_window(_rename_target_id, new_name)

# ── Chat input routing ───────────────────────────────────────────────────────
#
# Each ChatWindow owns its own LineEdit at the bottom (matches the legacy
# single-window layout). Pressing Enter routes to the active window's
# input. Submit fans back through CombatLog.chat_submitted so existing
# hud.gd command handlers see the same call shape as before.

func show_chat_input() -> void:
	var w := get_active_window()
	if w == null:
		return
	w.show_input()

func is_chat_input_focused() -> bool:
	for w in _windows:
		if w.is_input_focused():
			return true
	return false

func _on_show_chat_input() -> void:
	show_chat_input()

func _on_window_text_submitted(_id: int, text: String) -> void:
	CombatLog.chat_submitted.emit(text)

# ── Persistence ──────────────────────────────────────────────────────────────

func _restore_or_seed_windows() -> void:
	var layouts: Array = GameSettings.chat_windows
	if layouts.is_empty():
		new_window("Chat")
		return
	# Clamp restored positions / sizes so windows can't load off-screen or
	# below the minimum. Without this a corrupted settings.cfg or a window
	# dragged outside the viewport at quit time would silently hide.
	var vp_size := get_viewport().get_visible_rect().size
	for d_any in layouts:
		var d: Dictionary = d_any
		var w := _ChatWindowScript.new()
		var id := int(d.get("id", _next_window_id))
		w.window_id = id
		var size_v := Vector2(
			maxf(MIN_SIZE.x, float(d.get("w", DEFAULT_SIZE.x))),
			maxf(MIN_SIZE.y, float(d.get("h", DEFAULT_SIZE.y))),
		)
		var pos_v := Vector2(
			clampf(float(d.get("x", DEFAULT_POS.x)), 0.0, maxf(0.0, vp_size.x - size_v.x)),
			clampf(float(d.get("y", DEFAULT_POS.y)), 0.0, maxf(0.0, vp_size.y - size_v.y)),
		)
		w.setup(pos_v, size_v, MIN_SIZE)
		w.set_window_name(String(d.get("name", "Chat %d" % id)))
		_wire_window_signals(w)
		add_child(w)
		_windows.append(w)
		_windows_by_id[id] = w
		_next_window_id = max(_next_window_id, id + 1)
	if not _windows.is_empty():
		_set_active(_windows[0].window_id)

func _save_layout() -> void:
	var out: Array = []
	for w in _windows:
		out.append(w.get_layout())
	GameSettings.chat_windows = out
	GameSettings.save_settings()

func _exit_tree() -> void:
	# Capture final drag/resize state on shutdown. DraggablePanel mutates
	# position/size in place with no signal, so without this the user's
	# last layout before quitting would be lost.
	_save_layout()
