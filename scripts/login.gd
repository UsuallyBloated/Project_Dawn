extends Control

# Login / character-select screen. Three views (Login -> CharSelect ->
# CharCreate) built programmatically and toggled by visibility.
#
# Phase 2: this is the standalone launcher folded into the game client, so a
# tester runs ONE executable. Two things changed in the port:
#   * Race/class come from `CharacterData` (the client's canonical lists)
#     instead of the launcher's hand-copied duplicate, which could drift.
#   * On Play the renet ConnectToken is handed to `Net` IN PROCESS
#     (`Net.start_with_token`) instead of being written to a tempfile and
#     passed to a second executable over CLI args. That removes the tempfile
#     entirely and keeps the session token out of the command line, which is
#     readable by any other process.
#
# After a successful handoff we change to the LOBBY scene rather than straight
# into the world: the lobby already owns the ConnectOk -> `apply_character`
# step (which must run before the world loads, or the character arrives with no
# class and default stats) and the Enter World button. Reusing it keeps that
# playtested path intact.
#
# The UI is built in code because it is a direct port of working launcher code;
# rebuilding it as a .tscn would risk the flow for no functional gain. New HUD
# work should still prefer scenes (see CLAUDE.md code style).

const CONFIG_PATH := "user://login.cfg"
const DEFAULT_AUTH_HOST := "127.0.0.1:8765"
const LOBBY_SCENE := "res://scenes/lobby.tscn"

# Session state
var _session_token := ""
var _account_id := -1
var _is_gm := false
var _world_endpoint := ""
var _username := ""
var _characters: Array = []  # Array of CharacterSummary dicts
var _selected_char_id := -1

# Connection helpers
var _pending_msg: Dictionary = {}
var _password_pending := ""  # held during Register -> auto-Login
var _play_pending := false   # Play clicked, awaiting WorldConnectToken

# View roots
var _login_view: Control
var _char_select_view: Control
var _char_create_view: Control

# Login widgets
var _server_input: LineEdit
var _username_input: LineEdit
var _password_input: LineEdit
var _login_status: Label

# CharSelect widgets
var _welcome_label: Label
var _char_list: ItemList
var _select_status: Label
var _play_btn: Button
var _delete_btn: Button

# CharCreate widgets
var _name_input: LineEdit
var _race_dropdown: OptionButton
var _class_dropdown: OptionButton
var _create_status: Label

# ─── Lifecycle ───────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Backward compatibility: the standalone launcher is retired, but if someone
	# still runs it, it starts a world session from CLI args in Net's _ready
	# before this scene loads. Showing a login form on top of a live session
	# would be nonsense, so hand straight over to the lobby.
	if Net.is_launcher_mode():
		call_deferred("_goto_lobby")
		return
	AuthClient.connected.connect(_on_ws_connected)
	AuthClient.disconnected.connect(_on_ws_disconnected)
	AuthClient.connection_failed.connect(_on_ws_failed)
	AuthClient.message_received.connect(_on_message)
	_build_login_view()
	_build_char_select_view()
	_build_char_create_view()
	_load_config()
	_show_login()

func _load_config() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(CONFIG_PATH) == OK
	_server_input.text = cfg.get_value("server", "host", DEFAULT_AUTH_HOST) if ok else DEFAULT_AUTH_HOST
	_username_input.text = cfg.get_value("login", "last_username", "") if ok else ""

func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("server", "host", _server_input.text.strip_edges())
	cfg.set_value("login", "last_username", _username_input.text.strip_edges())
	cfg.save(CONFIG_PATH)

# ─── View construction ───────────────────────────────────────────────

func _make_view() -> Control:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 32)
	m.add_theme_constant_override("margin_right", 32)
	m.add_theme_constant_override("margin_top", 32)
	m.add_theme_constant_override("margin_bottom", 32)
	add_child(m)
	return m

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _make_status() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l

func _make_spacer(height: int = 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _build_login_view() -> void:
	_login_view = _make_view()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	_login_view.add_child(v)

	var title := Label.new()
	title.text = "Project Dawn"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_make_spacer(16))

	v.add_child(_make_label("Server"))
	_server_input = LineEdit.new()
	_server_input.placeholder_text = "host:port"
	v.add_child(_server_input)

	v.add_child(_make_label("Username"))
	_username_input = LineEdit.new()
	v.add_child(_username_input)

	v.add_child(_make_label("Password"))
	_password_input = LineEdit.new()
	_password_input.secret = true
	_password_input.text_submitted.connect(_on_password_submitted)
	v.add_child(_password_input)

	v.add_child(_make_spacer())

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	var login_btn := Button.new()
	login_btn.text = "Log In"
	login_btn.pressed.connect(_on_login_pressed)
	hb.add_child(login_btn)
	var register_btn := Button.new()
	register_btn.text = "Register"
	register_btn.pressed.connect(_on_register_pressed)
	hb.add_child(register_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	hb.add_child(spacer)
	# Dev escape hatch to the offline lobby (Test Room / local save). Testers
	# land here on launch and use the account fields above; this is the door to
	# the single-player flow that used to be what you got by running the game
	# without the launcher.
	var offline_btn := Button.new()
	offline_btn.text = "Offline"
	offline_btn.tooltip_text = "Single-player Test Room / local save. No account needed."
	offline_btn.pressed.connect(_on_offline_pressed)
	hb.add_child(offline_btn)

	_login_status = _make_status()
	v.add_child(_login_status)

func _build_char_select_view() -> void:
	_char_select_view = _make_view()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	_char_select_view.add_child(v)

	_welcome_label = Label.new()
	_welcome_label.add_theme_font_size_override("font_size", 24)
	v.add_child(_welcome_label)

	v.add_child(_make_label("Characters"))
	_char_list = ItemList.new()
	_char_list.custom_minimum_size = Vector2(0, 240)
	_char_list.size_flags_vertical = SIZE_EXPAND_FILL
	_char_list.item_selected.connect(_on_char_selected)
	_char_list.item_activated.connect(_on_char_activated)
	v.add_child(_char_list)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	_play_btn = Button.new()
	_play_btn.text = "Play"
	_play_btn.disabled = true
	_play_btn.pressed.connect(_on_play_pressed)
	hb.add_child(_play_btn)
	var create_btn := Button.new()
	create_btn.text = "Create"
	create_btn.pressed.connect(_on_create_pressed)
	hb.add_child(create_btn)
	_delete_btn = Button.new()
	_delete_btn.text = "Delete"
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete_pressed)
	hb.add_child(_delete_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	hb.add_child(spacer)
	var logout_btn := Button.new()
	logout_btn.text = "Logout"
	logout_btn.pressed.connect(_on_logout_pressed)
	hb.add_child(logout_btn)

	_select_status = _make_status()
	v.add_child(_select_status)

func _build_char_create_view() -> void:
	_char_create_view = _make_view()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	_char_create_view.add_child(v)

	var title := Label.new()
	title.text = "Create Character"
	title.add_theme_font_size_override("font_size", 24)
	v.add_child(title)
	v.add_child(_make_spacer(8))

	v.add_child(_make_label("Name"))
	_name_input = LineEdit.new()
	# The server accepts letters, apostrophes and backticks only (2-24 chars) —
	# digits and spaces are rejected. Say so up front instead of letting the
	# tester find out through a server error.
	_name_input.placeholder_text = "Letters only, no digits or spaces"
	v.add_child(_name_input)

	v.add_child(_make_label("Race"))
	_race_dropdown = OptionButton.new()
	for r in CharacterData.RACES:
		_race_dropdown.add_item(r)
	v.add_child(_race_dropdown)

	v.add_child(_make_label("Class"))
	_class_dropdown = OptionButton.new()
	for c in CharacterData.CLASSES:
		_class_dropdown.add_item(c)
	v.add_child(_class_dropdown)

	v.add_child(_make_spacer())

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	var create_btn := Button.new()
	create_btn.text = "Create"
	create_btn.pressed.connect(_on_confirm_create_pressed)
	hb.add_child(create_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_create_pressed)
	hb.add_child(cancel_btn)

	_create_status = _make_status()
	v.add_child(_create_status)

# ─── View switching ──────────────────────────────────────────────────

func _show_login() -> void:
	_login_view.show()
	_char_select_view.hide()
	_char_create_view.hide()

func _show_char_select() -> void:
	_login_view.hide()
	_char_select_view.show()
	_char_create_view.hide()
	_refresh_char_list()

func _show_char_create() -> void:
	_login_view.hide()
	_char_select_view.hide()
	_char_create_view.show()
	_name_input.text = ""
	_race_dropdown.selected = 0
	_class_dropdown.selected = 0
	_create_status.text = ""

func _refresh_char_list() -> void:
	_welcome_label.text = "Welcome, %s" % _username
	_char_list.clear()
	for ch in _characters:
		var lvl: int = int(ch.get("level", 1))
		var zone_str := ""
		var zone_v: Variant = ch.get("zone", null)
		if zone_v != null and typeof(zone_v) == TYPE_STRING and zone_v != "":
			zone_str = "  [%s]" % zone_v
		var line := "%s - Lvl %d %s %s%s" % [ch["name"], lvl, ch["race"], ch["class"], zone_str]
		_char_list.add_item(line)
	_selected_char_id = -1
	_play_btn.disabled = true
	_delete_btn.disabled = true

func _set_status(text: String) -> void:
	_login_status.text = text
	_select_status.text = text
	_create_status.text = text

# ─── Connection orchestration ────────────────────────────────────────

func _send_or_queue(msg: Dictionary) -> void:
	if AuthClient.is_open():
		AuthClient.send_msg(msg)
		return
	_pending_msg = msg
	var host := _server_input.text.strip_edges()
	if host == "":
		_set_status("Server host required")
		return
	_set_status("Connecting to %s..." % host)
	if not AuthClient.connect_to("ws://%s" % host):
		_set_status("Failed to start connection")

func _on_ws_connected() -> void:
	if _pending_msg.is_empty():
		return
	AuthClient.send_msg(_pending_msg)
	_pending_msg = {}

func _on_ws_disconnected(_was_open: bool) -> void:
	_pending_msg = {}
	if _session_token != "":
		# Server dropped us mid-session; bounce back to login.
		_session_token = ""
		_characters.clear()
		_set_status("Connection lost. Please log in again.")
		_show_login()

func _on_ws_failed(reason: String) -> void:
	_pending_msg = {}
	_set_status("Connection failed: %s" % reason)

func _on_message(msg: Dictionary) -> void:
	var t: String = str(msg.get("type", ""))
	match t:
		NetProtocol.AUTH_REGISTER_OK:
			_account_id = int(msg.get("account_id", -1))
			_set_status("Account created. Logging in...")
			AuthClient.send_msg(NetProtocol.make_login(
				_username_input.text.strip_edges(), _password_pending))
		NetProtocol.AUTH_LOGIN_OK:
			_session_token = str(msg.get("session_token", ""))
			_account_id = int(msg.get("account_id", -1))
			_is_gm = bool(msg.get("is_gm", false))
			# Stash on Net so the world scene can decide whether to mount the
			# dev Test Panel. Not a permission — the server gates dev commands
			# on the token's own is_gm bit.
			Net.set_is_gm(_is_gm)
			_world_endpoint = str(msg.get("world_endpoint", ""))
			_username = _username_input.text.strip_edges()
			_characters = msg.get("characters", []) as Array
			_password_pending = ""
			_save_config()
			_set_status("")
			_show_char_select()
		NetProtocol.AUTH_CHAR_LIST:
			_characters = msg.get("characters", []) as Array
			_refresh_char_list()
		NetProtocol.AUTH_CHAR_CREATED:
			AuthClient.send_msg(NetProtocol.make_char_list(_session_token))
			_show_char_select()
		NetProtocol.AUTH_CHAR_DELETED:
			AuthClient.send_msg(NetProtocol.make_char_list(_session_token))
		NetProtocol.AUTH_LOGOUT_OK:
			_session_token = ""
			_characters.clear()
			AuthClient.disconnect_now()
			_show_login()
			_set_status("Logged out.")
		NetProtocol.AUTH_WORLD_CONNECT_TOKEN:
			_handle_world_connect_token(msg)
		NetProtocol.AUTH_ERROR:
			var code: String = str(msg.get("code", ""))
			var emsg: String = str(msg.get("msg", ""))
			if _play_pending:
				# RequestWorldToken failed — re-enable Play so user can retry.
				_play_pending = false
				_play_btn.disabled = (_selected_char_id < 0)
			_set_status("Error (%s): %s" % [code, emsg])
		_:
			_set_status("Unknown message: %s" % t)

# ─── Button handlers ─────────────────────────────────────────────────

func _on_login_pressed() -> void:
	var u := _username_input.text.strip_edges()
	var p := _password_input.text
	if u == "" or p == "":
		_set_status("Username and password required")
		return
	_password_pending = ""
	_send_or_queue(NetProtocol.make_login(u, p))

func _on_register_pressed() -> void:
	var u := _username_input.text.strip_edges()
	var p := _password_input.text
	if u == "" or p == "":
		_set_status("Username and password required")
		return
	_password_pending = p  # held for auto-Login on RegisterOk
	_send_or_queue(NetProtocol.make_register(u, p))

func _on_password_submitted(_text: String) -> void:
	_on_login_pressed()

func _on_offline_pressed() -> void:
	# Straight to the legacy lobby with no session. `Net.is_launcher_mode()` is
	# false, so the lobby shows its local buttons (Test Room, Solo, dungeon).
	_goto_lobby()

func _goto_lobby() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_logout_pressed() -> void:
	if _session_token != "" and AuthClient.is_open():
		AuthClient.send_msg(NetProtocol.make_logout(_session_token))
	else:
		_session_token = ""
		_characters.clear()
		AuthClient.disconnect_now()
		_show_login()

func _on_create_pressed() -> void:
	_show_char_create()

func _on_confirm_create_pressed() -> void:
	var char_name := _name_input.text.strip_edges()
	if char_name == "":
		_create_status.text = "Name required"
		return
	var race: String = CharacterData.RACES[_race_dropdown.selected]
	var cls: String = CharacterData.CLASSES[_class_dropdown.selected]
	AuthClient.send_msg(NetProtocol.make_char_create(_session_token, char_name, race, cls))

func _on_cancel_create_pressed() -> void:
	_show_char_select()

func _on_delete_pressed() -> void:
	if _selected_char_id < 0:
		return
	AuthClient.send_msg(NetProtocol.make_char_delete(_session_token, _selected_char_id))

func _on_char_selected(idx: int) -> void:
	if idx < 0 or idx >= _characters.size():
		return
	_selected_char_id = int(_characters[idx]["id"])
	_play_btn.disabled = false
	_delete_btn.disabled = false

func _on_char_activated(idx: int) -> void:
	_on_char_selected(idx)
	_on_play_pressed()

func _on_play_pressed() -> void:
	if _selected_char_id < 0 or _play_pending:
		return
	_play_pending = true
	_play_btn.disabled = true
	_set_status("Requesting world token...")
	AuthClient.send_msg(NetProtocol.make_request_world_token(
		_session_token, _selected_char_id))

# WorldConnectToken arrived. Hand the bytes straight to `Net` in process and
# move to the lobby, which drives ConnectOk -> apply_character -> Enter World.
# The token has a ~30 s server-side TTL, so a slow first launch (shader compile,
# antivirus scan) can still expire it; the user can press Play again.
func _handle_world_connect_token(msg: Dictionary) -> void:
	if not _play_pending:
		# Stray reply (e.g. Play canceled) — ignore.
		return
	_play_pending = false
	_play_btn.disabled = (_selected_char_id < 0)

	var token_arr: Variant = msg.get("token_bytes", null)
	var token_bytes := NetProtocol.decode_world_token_bytes(token_arr)
	if token_bytes.is_empty():
		_set_status("Server returned empty world token.")
		return

	var endpoint := str(msg.get("world_endpoint", _world_endpoint))
	if endpoint == "":
		_set_status("Server omitted world_endpoint in WorldConnectToken.")
		return

	if not Net.start_with_token(
			token_bytes, _session_token, _selected_char_id,
			endpoint, NetProtocol.CLIENT_VERSION):
		_set_status("Could not start the world connection. Press Play to retry.")
		return

	get_tree().change_scene_to_file(LOBBY_SCENE)
