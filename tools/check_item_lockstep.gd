extends SceneTree

# Item lockstep check: compares the client's item resources
# (data/loot/items/*.tres) with the server's items.toml and prints where they
# disagree. The two are the same shape as the spell pair: the client authors
# the .tres files, the server reads a TOML the exporter is supposed to
# regenerate, and nothing else notices when one side moves without the other.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_item_lockstep.gd
#   godot --headless --path . -s tools/check_item_lockstep.gd -- <path to items.toml>
#
# It reports three things:
#   DRIFT        a field the server carries whose value differs from the
#                client's. A key the TOML omits is compared against the
#                server's default (stack 1, weapon_delay 2.0, zero, "", false),
#                so an affix added to a .tres and never exported shows up here.
#   SERVER-ONLY  a path the server knows and the client has no resource for.
#   CLIENT-ONLY  a resource the server has no entry for; GmGive, loot and the
#                vendor refuse such a path as unknown.
#
# Exit code 1 on DRIFT or SERVER-ONLY, 0 otherwise. Read-only: unlike
# export_items.gd it writes nothing. The field map and type names are the
# exporter's own constants, so the two tools cannot disagree about what the
# server carries; what the server does NOT carry (description, icon,
# the mount fields, augment contents) is client-side by design and never
# compared.

const DEFAULT_SERVER_TOML := "F:/Projects/server/crates/projectdawn-server/data/items.toml"
const ITEMS_DIR := "res://data/loot/items"
# Two floats closer than this are the same number written differently.
const EPSILON := 0.001
# The exporter owns the map from .tres field to TOML key and the type names.
const Exporter := preload("res://tools/export_items.gd")
# What the server reads when the TOML omits a key (crates/projectdawn-server/
# src/world/items.rs, the serde defaults).
const SERVER_DEFAULTS := {"stack_size": 1, "weapon_delay": 2.0}

func _initialize() -> void:
	var toml_path := DEFAULT_SERVER_TOML
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		toml_path = args[0]

	var server := _parse_items_toml(toml_path)
	if server.is_empty():
		printerr("No items read from %s (wrong path, or the server repo is not checked out there)." % toml_path)
		quit(2)
		return

	var client := _load_client_items()
	if client.is_empty():
		printerr("No .tres items found under %s." % ITEMS_DIR)
		quit(2)
		return

	var field_map: Dictionary = Exporter.FIELD_MAP
	var type_names: Array = Exporter.TYPE_NAMES
	var drift: Array[String] = []
	var server_only: Array[String] = []
	var client_only: Array[String] = []

	for path in server:
		if not client.has(path):
			server_only.append(path)
			continue
		var s: Dictionary = server[path]
		var item: ItemData = client[path]
		var label := "%s (%s)" % [item.item_name, path.get_file()]
		# The type is an enum on the client and a snake_case name on the server.
		var want_type: String = type_names[int(item.type)] if int(item.type) < type_names.size() else "?"
		if String(s.get("item_type", "")) != want_type:
			drift.append("%s: item_type is %s on the server, %s on the client" % [
				label, str(s.get("item_type", "")), want_type])
		# A weapon that never procs carries the client enum's NONE (9) in
		# `proc_damage_type` and the server's default 0 (Fire): meaningless on
		# both sides while `proc_chance` is 0, so the proc fields are compared
		# only when either side says the item procs.
		var procs := float(item.proc_chance) > 0.0 or float(s.get("proc_chance", 0.0)) > 0.0
		for field in field_map:
			var key: String = field_map[field]
			if key.begins_with("proc_") and not procs:
				continue
			var client_value: Variant = item.get(field)
			if field == "proc_damage_type":
				client_value = int(client_value)
			var server_value: Variant = s.get(key, SERVER_DEFAULTS.get(key, _zero_like(client_value)))
			if not _same(server_value, client_value):
				drift.append("%s: %s is %s on the server, %s on the client" % [
					label, key, str(server_value), str(client_value)])

	for path in client:
		if not server.has(path):
			client_only.append("%s (%s)" % [(client[path] as ItemData).item_name, path.get_file()])

	print("Item lockstep: client %d, server %d (%s)" % [client.size(), server.size(), toml_path])
	print("")
	print("DRIFT: %d" % drift.size())
	drift.sort()
	for line in drift:
		print("  " + line)
	print("SERVER-ONLY: %d" % server_only.size())
	server_only.sort()
	for path in server_only:
		print("  " + path)
	print("CLIENT-ONLY: %d (refused online as unknown items)" % client_only.size())
	client_only.sort()
	for line in client_only:
		print("  " + line)

	quit(1 if (not drift.is_empty() or not server_only.is_empty()) else 0)

# The server default for a key the exporter emits only when non-default: the
# zero of the client's type.
func _zero_like(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT: return 0
		TYPE_FLOAT: return 0.0
		TYPE_BOOL: return false
		TYPE_STRING: return ""
	return 0

func _same(a, b) -> bool:
	if a is String or b is String:
		return String(a) == String(b)
	if a is bool or b is bool:
		return bool(a) == bool(b)
	return absf(float(a) - float(b)) < EPSILON

# Every ItemData under ITEMS_DIR, keyed by its res:// path (the key the
# server's TOML and every wire message use).
func _load_client_items() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path := ITEMS_DIR + "/" + fname
			var res := load(path)
			if res is ItemData:
				out[path] = res
		fname = dir.get_next()
	dir.list_dir_end()
	return out

# Just enough TOML for items.toml: `[[item]]` blocks of `key = value` lines
# where a value is a quoted string, a number, or true/false. Returns
# path -> { key: value }.
func _parse_items_toml(path: String) -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var current: Dictionary = {}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line == "[[item]]":
			if current.has("path"):
				out[String(current["path"])] = current
			current = {}
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges()
		current[key] = _parse_value(line.substr(eq + 1).strip_edges())
	if current.has("path"):
		out[String(current["path"])] = current
	return out

func _parse_value(raw: String):
	if raw.begins_with("\""):
		return raw.trim_prefix("\"").trim_suffix("\"").replace("\\\"", "\"").replace("\\\\", "\\")
	if raw == "true":
		return true
	if raw == "false":
		return false
	if "." in raw or "e" in raw.to_lower():
		return raw.to_float()
	return raw.to_int()
