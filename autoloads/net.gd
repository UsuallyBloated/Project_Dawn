extends NetClient

# Net — single-owner network adapter wrapping the gdext_net `NetClient`.
#
# This script *extends* the GDExtension class directly so all the typed
# signals (`transport_connected`, `position`, ...) are available as-is.
# On top, this layer:
#
#   1. Parses launcher CLI args once on `_ready`.
#   2. If launcher mode, reads the world-token tempfile, deletes it, and
#      kicks off the connect flow (transport handshake → app Connect →
#      ConnectOk).
#   3. Tracks the high-level state machine and re-emits coarser signals
#      callers care about: `app_connected`, `app_disconnected`.
#   4. Pumps `poll(delta)` every frame while a connection exists.
#
# Local-save / Test Room flow: when `CliArgs.parse()` returns null, this
# autoload sits idle. Nothing else changes; the existing client-authoritative
# code continues to drive the game.

enum State {
	DISCONNECTED,
	CONNECTING_TRANSPORT,  # renet handshake in flight
	CONNECTED_TRANSPORT,   # transport up, waiting for ConnectOk
	CONNECTED_APP,         # ready for gameplay intents
}

# Server kicks at HEARTBEAT_TIMEOUT (10 s) of app-layer silence. Beat at 4 s
# so a single dropped packet still leaves headroom — the system channel is
# reliable so loss is unlikely, but cheap insurance. Any other inbound app
# message (Move, etc.) also resets the server's idle timer, so once
# `send_movement` is wired into player.gd this becomes redundant but
# harmless.
const HEARTBEAT_INTERVAL_SEC := 4.0

# Coarse, high-level signals — most callers want these, not the raw
# transport-level ones from the GDExtension.
signal app_connected(player_id: int)
signal app_disconnected(reason: String)
signal world_position(id: int, pos: Vector3, vel: Vector3, yaw: float, sequence: int)

var _state: State = State.DISCONNECTED
var _session_token_bytes := PackedByteArray()
var _char_id: int = -1
var _client_version := ""
var _player_id: int = -1
var _move_sequence: int = 0
var _heartbeat_timer: Timer = null

func _ready() -> void:
	# Hook GDExtension signals — populated from the renet poll loop.
	transport_connected.connect(_on_transport_connected)
	transport_disconnected.connect(_on_transport_disconnected)
	connect_ok.connect(_on_connect_ok)
	kicked.connect(_on_kicked)
	position.connect(_on_position)

	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL_SEC
	_heartbeat_timer.one_shot = false
	_heartbeat_timer.autostart = false
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(_heartbeat_timer)

	var args: Variant = CliArgs.parse()
	if args == null:
		# Local-save / dev-iteration path. Nothing to do.
		return
	var ok := _start_from_args(args as Dictionary)
	if not ok:
		push_warning("Net: launcher handoff failed; staying disconnected")

func _process(delta: float) -> void:
	if _state == State.DISCONNECTED:
		return
	poll(delta)

# ─── Public API ─────────────────────────────────────────────────────

func is_launcher_mode() -> bool:
	return _state != State.DISCONNECTED or _char_id >= 0

func is_app_ready() -> bool:
	return _state == State.CONNECTED_APP

func get_player_id() -> int:
	return _player_id

# Send a Move intent. Server clamps the direction to unit length. Sequence
# is auto-incremented; out-of-order packets are dropped server-side.
func send_movement(direction: Vector3, jumping: bool = false) -> void:
	if _state != State.CONNECTED_APP:
		return
	_move_sequence += 1
	send_move(_move_sequence, direction, jumping)

func leave_session() -> void:
	if _state == State.CONNECTED_APP:
		send_disconnect()
	_stop_heartbeat()
	disconnect_now()
	_state = State.DISCONNECTED
	_player_id = -1

# ─── Internal: launcher flow ────────────────────────────────────────

func _start_from_args(args: Dictionary) -> bool:
	if _state != State.DISCONNECTED:
		push_warning("Net._start_from_args called in state %d" % _state)
		return false

	var token_path := str(args.get("world_token_path", ""))
	var endpoint := str(args.get("world_endpoint", ""))
	var auth_token_hex := str(args.get("auth_token", ""))
	var char_id := int(args.get("char_id", -1))
	var client_version := str(args.get("client_version", ""))

	if token_path == "" or endpoint == "" or auth_token_hex == "" or char_id < 0:
		push_warning("Net: launcher args incomplete")
		return false

	var token_bytes := _read_and_delete_token_file(token_path)
	if token_bytes.is_empty():
		push_warning("Net: world token file unreadable: %s" % token_path)
		return false

	var session_bytes := _hex_to_bytes(auth_token_hex)
	if session_bytes.size() != 32:
		push_warning("Net: auth token decode produced %d bytes (expected 32)"
			% session_bytes.size())
		return false

	_session_token_bytes = session_bytes
	_char_id = char_id
	_client_version = client_version
	_move_sequence = 0

	if not connect_to_server(token_bytes, endpoint):
		push_warning("Net: NetClient.connect_to_server returned false")
		return false

	_state = State.CONNECTING_TRANSPORT
	return true

# Reads the token bytes and immediately removes the tempfile. Even if the
# subsequent connect fails, the token is gone — the 30 s server-side TTL is
# the secondary safeguard, not the primary defense.
func _read_and_delete_token_file(path: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	if not FileAccess.file_exists(path):
		return bytes
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return bytes
	bytes = f.get_buffer(f.get_length())
	f.close()
	# Best-effort delete — log but don't fail if the OS won't let us remove it.
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_warning("Net: could not delete world token file (err=%d): %s" % [err, path])
	return bytes

func _hex_to_bytes(hex: String) -> PackedByteArray:
	var pba := PackedByteArray()
	if hex.length() % 2 != 0:
		return pba
	pba.resize(hex.length() / 2)
	for i in pba.size():
		pba[i] = hex.substr(i * 2, 2).hex_to_int() & 0xFF
	return pba

# ─── Internal: GDExtension signal handlers ──────────────────────────

func _on_transport_connected() -> void:
	_state = State.CONNECTED_TRANSPORT
	# Now safe to send the app-layer Connect.
	if not send_app_connect(_session_token_bytes, _char_id, _client_version):
		push_warning("Net: send_app_connect returned false")

func _on_transport_disconnected(reason: String) -> void:
	_stop_heartbeat()
	_state = State.DISCONNECTED
	_player_id = -1
	app_disconnected.emit(reason)

func _on_connect_ok(player_id: int) -> void:
	_player_id = player_id
	_state = State.CONNECTED_APP
	_heartbeat_timer.start()
	app_connected.emit(player_id)

func _on_kicked(reason: String, code: String) -> void:
	push_warning("Net: kicked code=%s reason=%s" % [code, reason])
	_stop_heartbeat()
	_state = State.DISCONNECTED
	_player_id = -1
	app_disconnected.emit("kicked: %s" % reason)
	disconnect_now()

func _on_position(id: int, pos: Vector3, vel: Vector3, yaw: float, sequence: int) -> void:
	world_position.emit(id, pos, vel, yaw, sequence)

func _on_heartbeat_tick() -> void:
	if _state == State.CONNECTED_APP:
		send_heartbeat()

func _stop_heartbeat() -> void:
	if _heartbeat_timer != null and not _heartbeat_timer.is_stopped():
		_heartbeat_timer.stop()
