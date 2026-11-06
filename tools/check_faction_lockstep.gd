extends SceneTree
# Compares the client's FactionDefinitions (data/faction_definitions.gd) with
# the server's data/factions.toml: every id on both sides, the same display
# name for each. Exits 0 when they agree, 1 on any drift, 2 when the TOML
# cannot be read. Run headless:
#   godot --headless --path . -s tools/check_faction_lockstep.gd -- <path to factions.toml>

const DEFAULT_SERVER_TOML := "F:/Projects/server/crates/projectdawn-server/data/factions.toml"

func _initialize() -> void:
	var toml_path := DEFAULT_SERVER_TOML
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		toml_path = args[0]

	var server := _parse_factions_toml(toml_path)
	if server.is_empty():
		printerr("No factions read from %s (wrong path, or the server repo is not checked out there)." % toml_path)
		quit(2)
		return

	var client: Dictionary = {}
	for f in FactionDefinitions.ALL:
		client[String(f["id"])] = String(f["name"])

	var problems: Array[String] = []
	for id in server:
		if not client.has(id):
			problems.append("server only: %s" % id)
		elif client[id] != server[id]:
			problems.append("name drift on %s: client %s, server %s" % [id, client[id], server[id]])
	for id in client:
		if not server.has(id):
			problems.append("client only: %s" % id)

	print("Faction lockstep: client %d, server %d (%s)" % [client.size(), server.size(), toml_path])
	for p in problems:
		print("  " + p)
	if problems.is_empty():
		print("  no drift")
	quit(1 if not problems.is_empty() else 0)

# Just enough TOML for factions.toml: the `id` and `name` lines of each
# `[[faction]]` block (start tables and links are server-only). Returns
# id -> name.
func _parse_factions_toml(path: String) -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var id := ""
	var name := ""
	var in_faction := false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("["):
			if in_faction and id != "":
				out[id] = name
			in_faction = line == "[[faction]]"
			id = ""
			name = ""
			continue
		if not in_faction:
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if key == "id":
			id = value
		elif key == "name":
			name = value
	if in_faction and id != "":
		out[id] = name
	return out
