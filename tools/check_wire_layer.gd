extends SceneTree

# Wire-layer freshness check: does the gdext_net.dll this checkout carries
# have everything Net (and the Test Panel, through Net) reaches for BY NAME? The DLL is gitignored and
# hand-copied into addons/gdext_net/ and builds/, so a clean commit can run
# on a stale wire layer, which then presents as a server bug (CLAUDE.md,
# "Every export is stamped automatically"). Net guards each late addition
# with has_signal / has_method and degrades (a local sky, no /ping) instead
# of failing to load; this prints which of those it would be degrading.
#
# Run from the client repo root, with the DLL built (addons/gdext_net/build.ps1):
#   godot --headless --path . -s tools/check_wire_layer.gd
#
# Exit code 1 when anything is missing, 0 when the DLL carries it all.
# Add a name here whenever Net gains another by-name lookup.

const SIGNALS: Array[String] = ["time_of_day", "entity_replaced", "hunger_update", "player_jumped"]
const METHODS: Array[String] = ["rtt_ms", "packet_loss", "send_dev_despawn_enemies"]


func _init() -> void:
	var client := NetClient.new()
	var missing: Array[String] = []
	for sig in SIGNALS:
		var ok := client.has_signal(sig)
		print("%s  signal %s" % ["OK     " if ok else "MISSING", sig])
		if not ok:
			missing.append("signal " + sig)
	for method in METHODS:
		var ok := client.has_method(method)
		print("%s  method %s" % ["OK     " if ok else "MISSING", method])
		if not ok:
			missing.append("method " + method)
	if missing.is_empty():
		# Unconnected, the getters must answer 0 rather than error.
		print("rtt_ms() unconnected = %s, packet_loss() unconnected = %s" % [
			str(client.call("rtt_ms")), str(client.call("packet_loss"))])
	client.free()
	if missing.is_empty():
		print("wire layer: complete")
		quit(0)
	else:
		print("wire layer: %d missing; rebuild with addons/gdext_net/build.ps1" % missing.size())
		quit(1)
