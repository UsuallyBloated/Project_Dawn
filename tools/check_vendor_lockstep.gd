extends SceneTree

# Vendor lockstep check: compares the client's vendor stock lists
# (data/vendor_definitions.gd) with the server's npcs.toml and prints where
# they disagree. The server sells only what a vendor in reach stocks, so a
# list that moves on one side alone either hides an item the server would sell
# or shows one it refuses ("The merchant doesn't stock that.").
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_vendor_lockstep.gd
#   godot --headless --path . -s tools/check_vendor_lockstep.gd -- <path to npcs.toml>
#
# It reports:
#   UNKNOWN TYPE   a server vendor whose vendor_type the client has no entry for.
#   SERVER-ONLY    an item the server vendor stocks and the client list lacks.
#   CLIENT-ONLY    an item the client list shows and the server vendor lacks.
#   UNPLACED       a vendor_type placed in scenes/world.tscn that no server
#                  vendor carries, so every purchase there would be refused.
#
# Exit code 1 on any of them, 0 when the two agree. Read-only.

const DEFAULT_SERVER_TOML := "F:/Projects/server/crates/projectdawn-server/data/npcs.toml"
const WORLD_SCENE := "res://scenes/world.tscn"

func _initialize() -> void:
	var toml_path := DEFAULT_SERVER_TOML
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		toml_path = args[0]

	var vendors := _parse_vendors(toml_path)
	if vendors.is_empty():
		printerr("No vendors read from %s (wrong path, or the server repo is not checked out there)." % toml_path)
		quit(2)
		return

	var problems: Array[String] = []
	var server_types := {}
	for v in vendors:
		var vtype: String = v["vendor_type"]
		server_types[vtype] = true
		if not VendorDefinitions.ALL.has(vtype):
			problems.append("UNKNOWN TYPE  %s: vendor_type \"%s\" is not in VendorDefinitions" % [v["id"], vtype])
			continue
		var client_stock: Array = VendorDefinitions.ALL[vtype]["stock"]
		for item in v["stock"]:
			if not client_stock.has(item):
				problems.append("SERVER-ONLY   %s (%s): %s" % [v["id"], vtype, item])
		for item in client_stock:
			if not v["stock"].has(item):
				problems.append("CLIENT-ONLY   %s (%s): %s" % [v["id"], vtype, item])

	for vtype in _placed_vendor_types():
		if not server_types.has(vtype):
			problems.append("UNPLACED      %s is placed in world.tscn but no server vendor carries it" % vtype)

	print("Vendors on the server: %d" % vendors.size())
	if problems.is_empty():
		print("Vendor stock in lockstep.")
		quit(0)
		return
	for p in problems:
		print(p)
	print("%d problem(s)." % problems.size())
	quit(1)

# Reads the [[npc]] entries that carry a vendor_type, with their stock lists.
# A small line parser for the shapes npcs.toml uses (key = "value", and a
# stock = [ ... ] array of one quoted name per line), not a general TOML reader.
func _parse_vendors(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var out: Array = []
	var current: Dictionary = {}
	var in_stock := false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("#") or line.is_empty():
			continue
		if line == "[[npc]]":
			_keep_if_vendor(current, out)
			current = {"id": "", "vendor_type": "", "stock": []}
			in_stock = false
			continue
		if in_stock:
			if line.begins_with("]"):
				in_stock = false
			else:
				current["stock"].append(line.trim_suffix(",").strip_edges().trim_prefix("\"").trim_suffix("\""))
			continue
		if line.begins_with("id ="):
			current["id"] = _quoted_value(line)
		elif line.begins_with("vendor_type ="):
			current["vendor_type"] = _quoted_value(line)
		elif line.begins_with("stock = ["):
			in_stock = true
	_keep_if_vendor(current, out)
	return out

func _keep_if_vendor(entry: Dictionary, out: Array) -> void:
	if not entry.is_empty() and entry["vendor_type"] != "":
		out.append(entry)

func _quoted_value(line: String) -> String:
	var first := line.find("\"")
	var last := line.rfind("\"")
	if first < 0 or last <= first:
		return ""
	return line.substr(first + 1, last - first - 1)

# The vendor types placed in the world scene, read from its text so the
# check needs no scene instancing.
func _placed_vendor_types() -> Array:
	var f := FileAccess.open(WORLD_SCENE, FileAccess.READ)
	if f == null:
		return []
	var types: Array = []
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("vendor_type ="):
			var t := _quoted_value(line)
			if t != "" and not types.has(t):
				types.append(t)
	return types
