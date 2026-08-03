extends Node

# WebSocketPeer wrapper for the auth service (register / login / character
# list / world-token request). One connection at a time. Polled every frame;
# emits signals on state changes and decoded messages.
#
# Phase 2: ported from the standalone launcher project so the game client can
# log in by itself. The launcher was a separate Godot executable that had to be
# shipped alongside the game and handed the session over via CLI args; folding
# it in means testers get ONE exe. `NetProtocol` already carried the auth
# message helpers (encode_auth / decode_auth), so nothing protocol-side moved.
#
# Distinct from the `Net` autoload, which owns the *world* connection (renet
# UDP via the gdext GDExtension). This is the TCP/WebSocket auth side only.

signal connected
signal disconnected(was_open: bool)
signal connection_failed(reason: String)
signal message_received(msg: Dictionary)

var _peer := WebSocketPeer.new()
var _was_open := false
var _connecting := false

func connect_to(url: String) -> bool:
	if _connecting or _was_open:
		_peer.close()
		_was_open = false
		_connecting = false
	var err := _peer.connect_to_url(url)
	if err != OK:
		connection_failed.emit("connect_to_url returned %s" % error_string(err))
		return false
	_connecting = true
	return true

func disconnect_now() -> void:
	if _connecting or _was_open:
		_peer.close(1000, "client disconnect")

func is_open() -> bool:
	return _peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func send_msg(msg: Dictionary) -> void:
	if not is_open():
		push_warning("AuthClient.send_msg called while socket not open")
		return
	var err := _peer.send_text(NetProtocol.encode_auth(msg))
	if err != OK:
		push_warning("AuthClient.send_msg send_text returned %s" % error_string(err))

func _process(_delta: float) -> void:
	if not _connecting and not _was_open:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_connecting = false
			connected.emit()
		while _peer.get_available_packet_count() > 0:
			var pkt := _peer.get_packet()
			var text := pkt.get_string_from_utf8()
			var parsed: Variant = NetProtocol.decode_auth(text)
			if parsed != null:
				message_received.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_open := _was_open
		var was_connecting := _connecting
		_was_open = false
		_connecting = false
		if was_open:
			disconnected.emit(true)
		elif was_connecting:
			connection_failed.emit("server unreachable")
