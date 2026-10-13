extends SceneTree

# Headless probe for the launcher's public-host rules (docs/design/
# public_hosting_plan.md, slice 3): which WebSocket URL the Server field turns
# into, and that Register carries the invite code only when one was typed.
#
#   godot --headless --path . -s tools/check_login_url.gd
#
# Prints one line per case and exits 1 on the first failure. Pure functions
# only: nothing connects, nothing is written.

# Preloaded rather than named: a fresh checkout has no global class cache yet,
# and this script must run (and quit) without one.
const Protocol := preload("res://scripts/net/protocol.gd")

var _failed := false

func _check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		print("PASS  %s -> %s" % [label, got])
	else:
		_failed = true
		print("FAIL  %s -> %s (wanted %s)" % [label, got, want])

func _init() -> void:
	# Local dev servers keep plain ws, with the dev port when none was typed.
	_check("127.0.0.1:8765", Protocol.auth_url_for("127.0.0.1:8765"), "ws://127.0.0.1:8765")
	_check("localhost", Protocol.auth_url_for("localhost"), "ws://localhost:8765")
	_check(" 127.0.0.1 ", Protocol.auth_url_for(" 127.0.0.1 "), "ws://127.0.0.1:8765")
	# Anything else is wss, with the TLS port when none was typed.
	_check("bare name", Protocol.auth_url_for("projectdawn.duckdns.org"), "wss://projectdawn.duckdns.org:443")
	_check("name:port", Protocol.auth_url_for("projectdawn.duckdns.org:8443"), "wss://projectdawn.duckdns.org:8443")
	_check("tailnet ip:port", Protocol.auth_url_for("100.93.108.112:8765"), "wss://100.93.108.112:8765")
	# A scheme typed by hand wins (a tailnet server without TLS stays reachable).
	_check("explicit ws", Protocol.auth_url_for("ws://100.93.108.112:8765"), "ws://100.93.108.112:8765")
	_check("explicit wss", Protocol.auth_url_for("wss://example.org"), "wss://example.org")
	# IPv6 literals.
	_check("[::1]", Protocol.auth_url_for("[::1]"), "ws://[::1]:8765")
	_check("[::1]:9000", Protocol.auth_url_for("[::1]:9000"), "ws://[::1]:9000")
	_check("bare v6", Protocol.auth_url_for("2001:db8::7"), "wss://[2001:db8::7]:443")

	# Register carries the invite only when one was typed.
	var plain: Dictionary = Protocol.make_register("sam", "hunter2!")
	_check("register without invite has no key", plain.has("invite"), false)
	var with: Dictionary = Protocol.make_register("sam", "hunter2!", "", "abcd")
	_check("register with invite carries it", with.get("invite", ""), "abcd")
	_check("register type tag", with.get("type", ""), "Register")

	quit(1 if _failed else 0)
