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
# Tab-docking state. Each group is { "members": Array[int], "active": int }.
# Group ids are allocated from `_next_group_seq` and are deliberately
# disjoint from window ids — otherwise undocking a window whose original
# solo group_id happened to equal its window_id would overwrite the live
# multi-tab group that still uses that key (and orphan its siblings).
var _groups: Dictionary = {}
var _next_group_seq: int = 1

var _rename_dialog: AcceptDialog = null
var _rename_line_edit: LineEdit = null
var _rename_target_id: int = 0
var _context_menu: PopupMenu = null
var _context_target_id: int = 0
var _filters_dialog: AcceptDialog = null
var _filters_checkboxes: Dictionary = {}  # filter_key -> CheckBox
var _filters_target_id: int = 0
var _display_dialog: AcceptDialog = null
var _display_bg_slider: HSlider = null
var _display_bg_label: Label = null
var _display_font_slider: HSlider = null
var _display_font_label: Label = null
var _display_size_spin: SpinBox = null
var _display_channel_option: OptionButton = null
var _display_target_id: int = 0

func _ready() -> void:
	# Match the legacy CombatLog behaviour: hidden until the local
	# player's `_ready` flips us on after entering world.tscn.
	# Otherwise the chat would render over the lobby / Enter World
	# screen and catch pre-world signal noise.
	visible = false
	_build_rename_dialog()
	_build_filters_dialog()
	_build_display_dialog()
	_build_context_menu()
	_restore_or_seed_windows()
	CombatLog.show_chat_input_requested.connect(_on_show_chat_input)

# ── Window creation / deletion / rename ──────────────────────────────────────

func new_window(window_name: String = "") -> ChatWindow:
	var id := _next_window_id
	_next_window_id += 1
	var gid := _allocate_group_id()
	var w := _ChatWindowScript.new()
	w.window_id = id
	w.group_id = gid
	var name_to_use := window_name if window_name != "" else "Chat %d" % id
	var pos := DEFAULT_POS + NEW_WINDOW_CASCADE * (_windows.size())
	w.setup(pos, DEFAULT_SIZE, MIN_SIZE)
	w.set_window_name(name_to_use)
	_wire_window_signals(w)
	add_child(w)
	_windows.append(w)
	_windows_by_id[id] = w
	_groups[gid] = {"members": [id], "active": id}
	_refresh_group(gid)
	if _active_window_id == 0:
		_set_active(id)
	_save_layout()
	return w

func _allocate_group_id() -> int:
	var gid := _next_group_seq
	_next_group_seq += 1
	return gid

func _wire_window_signals(w: ChatWindow) -> void:
	w.window_renamed.connect(_on_window_renamed)
	w.close_requested.connect(_on_window_close_requested)
	w.context_menu_requested.connect(_on_window_context_menu_requested)
	w.focus_requested.connect(_on_window_focus_requested)
	w.text_submitted.connect(_on_window_text_submitted)
	w.drag_ended.connect(_on_window_drag_ended)
	w.tab_activated.connect(_on_tab_activated)
	w.tab_dragged_out.connect(_on_tab_dragged_out)

func delete_window(id: int) -> void:
	if _windows.size() <= 1:
		return
	var w: ChatWindow = _windows_by_id.get(id, null)
	if w == null:
		return
	var gid := w.group_id
	_windows.erase(w)
	_windows_by_id.erase(id)
	w.queue_free()
	_remove_from_group(id, gid)
	if _groups.has(gid):
		_refresh_group(gid)
	if _active_window_id == id:
		_set_active(_windows[0].window_id if not _windows.is_empty() else 0)
	_save_layout()

func rename_window(id: int, new_name: String) -> void:
	var w: ChatWindow = _windows_by_id.get(id, null)
	if w == null:
		return
	w.set_window_name(new_name)
	# Tab-strip button text mirrors window_name; siblings need to redraw.
	if _groups.has(w.group_id):
		_refresh_group(w.group_id)

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

# ── Tab docking ──────────────────────────────────────────────────────────────
#
# A "group" is a set of windows that share a position/size and render a
# tab strip in place of the title bar. Groups are keyed by an int id.
# Solo windows live in a group of size 1 whose group_id equals the
# window's own id; that invariant lets us allocate fresh group ids
# without a counter and lets a window's "go solo" state be implicit
# whenever its members list shrinks to one.

func dock(source_id: int, target_group_id: int) -> void:
	var source_w: ChatWindow = _windows_by_id.get(source_id, null)
	if source_w == null or not _groups.has(target_group_id):
		return
	var src_group_id := source_w.group_id
	if src_group_id == target_group_id:
		return

	_remove_from_group(source_id, src_group_id)
	source_w.group_id = target_group_id
	_groups[target_group_id]["members"].append(source_id)

	# Snap source onto the target group's current rect, then make the
	# newly docked tab active so the user sees what they just dropped.
	var target_active_id: int = _groups[target_group_id]["active"]
	var target_w: ChatWindow = _windows_by_id.get(target_active_id, null)
	if target_w != null:
		source_w.position = target_w.position
		source_w.size = target_w.size
	_groups[target_group_id]["active"] = source_id

	if _groups.has(src_group_id):
		_refresh_group(src_group_id)
	_refresh_group(target_group_id)
	# Newly docked tab is the visible one — keep the input-routing
	# pointer in sync so Enter focuses the right window.
	_set_active(source_id)
	_save_layout()

func undock(member_id: int, screen_pos: Vector2) -> void:
	var w: ChatWindow = _windows_by_id.get(member_id, null)
	if w == null:
		return
	var old_group_id := w.group_id
	if not _groups.has(old_group_id):
		return
	if _groups[old_group_id]["members"].size() <= 1:
		return  # already solo

	_remove_from_group(member_id, old_group_id)
	var new_gid := _allocate_group_id()
	w.group_id = new_gid
	_groups[new_gid] = {"members": [member_id], "active": member_id}

	# Drop the undocked window so the cursor lands roughly on its title
	# bar — feels natural after a tab drag. Clamp inside the viewport.
	var vp_size := get_viewport().get_visible_rect().size
	var pos := Vector2(
		clampf(screen_pos.x - w.size.x * 0.5, 0.0, maxf(0.0, vp_size.x - w.size.x)),
		clampf(screen_pos.y, 0.0, maxf(0.0, vp_size.y - w.size.y)),
	)
	w.position = pos

	if _groups.has(old_group_id):
		_refresh_group(old_group_id)
	_refresh_group(new_gid)
	_save_layout()

func set_active_tab(group_id: int, new_active_id: int) -> void:
	if not _groups.has(group_id):
		return
	var group: Dictionary = _groups[group_id]
	var old_active_id: int = group["active"]
	if old_active_id == new_active_id:
		return
	var old_w: ChatWindow = _windows_by_id.get(old_active_id, null)
	var new_w: ChatWindow = _windows_by_id.get(new_active_id, null)
	if new_w == null:
		return
	# Carry position/size across the swap so the group's window-frame
	# stays put when the user switches tabs.
	if old_w != null:
		new_w.position = old_w.position
		new_w.size = old_w.size
	group["active"] = new_active_id
	_refresh_group(group_id)

func _refresh_group(gid: int) -> void:
	if not _groups.has(gid):
		return
	var group: Dictionary = _groups[gid]
	var members_data: Array = []
	for member_id in group["members"]:
		var w: ChatWindow = _windows_by_id.get(member_id, null)
		if w != null:
			members_data.append({"id": member_id, "name": w.window_name})
	var active_id: int = group["active"]
	for member_id in group["members"]:
		var w: ChatWindow = _windows_by_id.get(member_id, null)
		if w != null:
			w.set_group_state(members_data, active_id)

func _remove_from_group(removed_id: int, gid: int) -> void:
	if not _groups.has(gid):
		return
	var members: Array = _groups[gid]["members"]
	members.erase(removed_id)
	if members.is_empty():
		_groups.erase(gid)
		return
	if _groups[gid]["active"] == removed_id:
		_groups[gid]["active"] = members[0]

func _find_dock_target(source_id: int, pos: Vector2) -> ChatWindow:
	# Hit-test all other windows' drop-target rects (title bar for solo,
	# tab strip when grouped). Excludes the source's own group so that
	# dragging within a group can't recurse-dock onto itself.
	var source_w: ChatWindow = _windows_by_id.get(source_id, null)
	if source_w == null:
		return null
	var source_gid := source_w.group_id
	for w in _windows:
		if w.window_id == source_id:
			continue
		if w.group_id == source_gid:
			continue
		if w.get_drop_target_rect().has_point(pos):
			return w
	return null

func _on_window_drag_ended(source_id: int, drop_pos: Vector2) -> void:
	var target := _find_dock_target(source_id, drop_pos)
	if target != null:
		dock(source_id, target.group_id)
	else:
		# Plain reposition — persist so the new position survives quit.
		_save_layout()

func _on_tab_activated(target_id: int) -> void:
	var target_w: ChatWindow = _windows_by_id.get(target_id, null)
	if target_w == null:
		return
	set_active_tab(target_w.group_id, target_id)
	# `_active_window_id` drives `show_chat_input` and friends; keep it
	# in sync with the visible tab so Enter focuses the right LineEdit.
	_set_active(target_id)

func _on_tab_dragged_out(member_id: int, drop_pos: Vector2) -> void:
	undock(member_id, drop_pos)
	_set_active(member_id)

# ── Right-click context menu ─────────────────────────────────────────────────

const _MENU_ID_NEW     := 1
const _MENU_ID_RENAME  := 2
const _MENU_ID_FILTERS := 3
const _MENU_ID_DISPLAY := 4
const _MENU_ID_DELETE  := 5

# Filter dialog layout. Each entry is [group_label, rows] where rows is
# an array of [filter_key, display_label]. filter_key matches one of
# ChatWindow.FILTER_KEYS.
const _FILTER_GROUPS := [
	["Combat", [
		["damage_out", "Damage Dealt"],
		["damage_in",  "Damage Taken"],
		["crit",       "Critical Hits"],
		["heal",       "Heals"],
		["evade",      "Evades"],
	]],
	["Chat", [
		["say",        "Say"],
		["shout",      "Shout"],
		["ooc",        "OOC"],
		["tell_out",   "Tells (Out)"],
		["tell_in",    "Tells (In)"],
		["group_chat", "Group"],
	]],
	["System", [
		["info",       "System"],
		["level_up",   "Level Up"],
		["loot",       "Loot"],
	]],
]

func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.add_item("New Window", _MENU_ID_NEW)
	_context_menu.add_item("Rename...",  _MENU_ID_RENAME)
	_context_menu.add_item("Filters...", _MENU_ID_FILTERS)
	_context_menu.add_item("Display...", _MENU_ID_DISPLAY)
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
		_MENU_ID_FILTERS:
			_open_filters_dialog(_context_target_id)
		_MENU_ID_DISPLAY:
			_open_display_dialog(_context_target_id)
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

# ── Filters dialog ───────────────────────────────────────────────────────────

func _build_filters_dialog() -> void:
	_filters_dialog = AcceptDialog.new()
	_filters_dialog.title = "Chat Window Filters"
	_filters_dialog.dialog_hide_on_ok = true
	_filters_dialog.min_size = Vector2i(280, 360)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_filters_dialog.add_child(vbox)
	for group_any in _FILTER_GROUPS:
		var group: Array = group_any
		var header := Label.new()
		header.text = String(group[0])
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
		vbox.add_child(header)
		var rows: Array = group[1]
		for row_any in rows:
			var row: Array = row_any
			var key := String(row[0])
			var cb := CheckBox.new()
			cb.text = String(row[1])
			vbox.add_child(cb)
			_filters_checkboxes[key] = cb
	_filters_dialog.confirmed.connect(_on_filters_confirmed)
	add_child(_filters_dialog)

func _open_filters_dialog(id: int) -> void:
	var w: ChatWindow = _windows_by_id.get(id, null)
	if w == null:
		return
	_filters_target_id = id
	for key in _filters_checkboxes:
		var cb: CheckBox = _filters_checkboxes[key]
		cb.button_pressed = bool(w.filters.get(key, true))
	_filters_dialog.popup_centered()

func _on_filters_confirmed() -> void:
	var w: ChatWindow = _windows_by_id.get(_filters_target_id, null)
	if w == null:
		return
	var new_filters: Dictionary = {}
	for key in _filters_checkboxes:
		var cb: CheckBox = _filters_checkboxes[key]
		new_filters[key] = cb.button_pressed
	w.set_filters(new_filters)
	_save_layout()

# ── Display dialog ───────────────────────────────────────────────────────────

func _build_display_dialog() -> void:
	_display_dialog = AcceptDialog.new()
	_display_dialog.title = "Chat Window Display"
	_display_dialog.dialog_hide_on_ok = true
	_display_dialog.min_size = Vector2i(320, 220)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	_display_dialog.add_child(grid)

	_display_bg_slider = _build_slider_row(grid, "Window Opacity:", 0, 100)
	_display_bg_label = _attach_value_label(_display_bg_slider)
	_display_font_slider = _build_slider_row(grid, "Font Opacity:",
			ChatWindow.FONT_ALPHA_MIN, 100)
	_display_font_label = _attach_value_label(_display_font_slider)

	grid.add_child(_build_label("Font Size:"))
	_display_size_spin = SpinBox.new()
	_display_size_spin.min_value = ChatWindow.FONT_SIZE_MIN
	_display_size_spin.max_value = ChatWindow.FONT_SIZE_MAX
	_display_size_spin.step = 1
	grid.add_child(_display_size_spin)

	grid.add_child(_build_label("Default Channel:"))
	_display_channel_option = OptionButton.new()
	for key in ChatWindow.CHANNEL_KEYS:
		_display_channel_option.add_item(
				String(ChatWindow.CHANNEL_LABELS.get(key, key)))
	grid.add_child(_display_channel_option)

	_display_dialog.confirmed.connect(_on_display_confirmed)
	add_child(_display_dialog)

func _build_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	return lbl

func _build_slider_row(grid: GridContainer, label_text: String,
		min_v: int, max_v: int) -> HSlider:
	grid.add_child(_build_label(label_text))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 1
	slider.custom_minimum_size = Vector2(160, 0)
	row.add_child(slider)
	grid.add_child(row)
	return slider

func _attach_value_label(slider: HSlider) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(32, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.get_parent().add_child(lbl)
	slider.value_changed.connect(func(v: float) -> void:
		lbl.text = "%d" % int(v))
	return lbl

func _open_display_dialog(id: int) -> void:
	var w: ChatWindow = _windows_by_id.get(id, null)
	if w == null:
		return
	_display_target_id = id
	_display_bg_slider.value = w.bg_alpha
	_display_bg_label.text = "%d" % w.bg_alpha
	_display_font_slider.value = w.font_alpha
	_display_font_label.text = "%d" % w.font_alpha
	_display_size_spin.value = w.font_size
	var ch_idx := ChatWindow.CHANNEL_KEYS.find(w.default_channel)
	_display_channel_option.selected = ch_idx if ch_idx >= 0 else 0
	_display_dialog.popup_centered()

func _on_display_confirmed() -> void:
	var w: ChatWindow = _windows_by_id.get(_display_target_id, null)
	if w == null:
		return
	var selected_idx := _display_channel_option.selected
	var channel := ""
	if selected_idx >= 0 and selected_idx < ChatWindow.CHANNEL_KEYS.size():
		channel = ChatWindow.CHANNEL_KEYS[selected_idx]
	w.set_display_settings({
		"bg_alpha":        int(_display_bg_slider.value),
		"font_alpha":      int(_display_font_slider.value),
		"font_size":       int(_display_size_spin.value),
		"default_channel": channel,
	})
	_save_layout()

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
		w.group_id = int(d.get("group_id", id))
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
		var saved_filters = d.get("filters", null)
		if saved_filters is Dictionary:
			w.set_filters(saved_filters)
		w.set_display_settings(d)
		_wire_window_signals(w)
		add_child(w)
		_windows.append(w)
		_windows_by_id[id] = w
		_next_window_id = max(_next_window_id, id + 1)
	# Rebuild groups from each window's restored group_id. The first
	# encountered member of a group is the initial active tab (matches
	# the layout's natural ordering).
	for w in _windows:
		var gid := w.group_id
		if not _groups.has(gid):
			_groups[gid] = {"members": [], "active": w.window_id}
		_groups[gid]["members"].append(w.window_id)
		# Keep the allocator past any saved id so future new_window /
		# undock calls can't collide with restored groups.
		if gid >= _next_group_seq:
			_next_group_seq = gid + 1
	for gid in _groups:
		_refresh_group(gid)
	# Pick an initial active that's actually visible — the first
	# window's `group["active"]`, not the first window itself, since
	# the first window may be a hidden tab.
	if not _windows.is_empty():
		var first_gid: int = _windows[0].group_id
		var initial_active: int = _groups[first_gid]["active"]
		_set_active(initial_active)

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
