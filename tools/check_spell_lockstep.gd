extends SceneTree

# Spell lockstep check: compares the client's spell data
# (data/spell_definitions.gd) with the server's (spells.toml in the server
# repo) and prints where they disagree. Spells live in both places by design,
# and nothing else notices when one side is edited without the other.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_spell_lockstep.gd
#   godot --headless --path . -s tools/check_spell_lockstep.gd -- <path to spells.toml>
#
# It reports three things:
#   DRIFT        a value the server has that differs from the client's. A bug.
#   SERVER-ONLY  a spell the server knows and the client does not. A bug.
#   CLIENT-ONLY  a spell the client has that the server refuses as unknown.
#                Expected for spells that need something the server does not
#                model yet (see the header of spells.toml); listed so the
#                number is a fact and not a guess.
#
# Exit code 1 on DRIFT or SERVER-ONLY, 0 otherwise. Read-only: unlike
# export_spells.gd it writes nothing.

const DEFAULT_SERVER_TOML := "F:/Projects/server/crates/projectdawn-server/data/spells.toml"
# Two floats closer than this are the same number written differently.
const EPSILON := 0.001
# The fields a Bard song keeps on the client only (see the loop below).
const SONG_CLIENT_SIDE_KEYS: Array[String] = ["base_damage", "heal_amount"]

func _initialize() -> void:
	var toml_path := DEFAULT_SERVER_TOML
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		toml_path = args[0]

	var server := _parse_spells_toml(toml_path)
	if server.is_empty():
		printerr("No spells read from %s (wrong path, or the server repo is not checked out there)." % toml_path)
		quit(2)
		return

	var client: Dictionary = {}
	for d in SpellDefinitions.ALL:
		client[String(d["name"])] = d

	var drift: Array[String] = []
	var server_only: Array[String] = []
	var client_only: Dictionary = {}   # target_type -> Array of names

	for spell_name in server:
		if not client.has(spell_name):
			server_only.append(spell_name)
			continue
		var s: Dictionary = server[spell_name]
		var c: Dictionary = client[spell_name]
		for key in s:
			if key == "name":
				continue
			# A key the client never authors (res_xp_percent, for one) is the
			# server's own business, not drift.
			if not c.has(key):
				continue
			# Bard songs: the server only gates the cast and deliberately
			# carries 0 damage and 0 heal, because the per-pulse effect is
			# still applied client-side by BardSongs (see the Bard section of
			# spells.toml and the "Bard song rework" To-Do).
			if bool(c.get("is_song", false)) and key in SONG_CLIENT_SIDE_KEYS:
				continue
			if not _same(s[key], c[key]):
				drift.append("%s: %s is %s on the server, %s on the client" % [
					spell_name, key, str(s[key]), str(c[key])])

	for spell_name in client:
		if server.has(spell_name):
			continue
		var tt := String(client[spell_name].get("target_type", "?"))
		if not client_only.has(tt):
			client_only[tt] = []
		client_only[tt].append(spell_name)

	print("Spell lockstep: client %d, server %d (%s)" % [client.size(), server.size(), toml_path])
	print("")
	print("DRIFT: %d" % drift.size())
	for line in drift:
		print("  " + line)
	print("SERVER-ONLY: %d" % server_only.size())
	for spell_name in server_only:
		print("  " + spell_name)
	var client_only_total := 0
	for tt in client_only:
		client_only_total += client_only[tt].size()
	print("CLIENT-ONLY: %d (refused online as unknown spells)" % client_only_total)
	var types := client_only.keys()
	types.sort()
	for tt in types:
		var names: Array = client_only[tt]
		names.sort()
		print("  %s (%d): %s" % [tt, names.size(), ", ".join(PackedStringArray(names))])

	quit(1 if (not drift.is_empty() or not server_only.is_empty()) else 0)

func _same(a, b) -> bool:
	if a is Array or b is Array:
		if not (a is Array and b is Array) or a.size() != b.size():
			return false
		for i in a.size():
			if String(a[i]) != String(b[i]):
				return false
		return true
	if a is String or b is String:
		return String(a) == String(b)
	if a is bool or b is bool:
		return bool(a) == bool(b)
	return absf(float(a) - float(b)) < EPSILON

# Just enough TOML for spells.toml: `[[spell]]` blocks of `key = value` lines
# where a value is a quoted string, a number, true/false, or an array of
# quoted strings. Returns name -> { key: value }.
func _parse_spells_toml(path: String) -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var current: Dictionary = {}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line == "[[spell]]":
			if current.has("name"):
				out[String(current["name"])] = current
			current = {}
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges()
		current[key] = _parse_value(line.substr(eq + 1).strip_edges())
	if current.has("name"):
		out[String(current["name"])] = current
	return out

func _parse_value(raw: String):
	if raw.begins_with("\""):
		return raw.trim_prefix("\"").trim_suffix("\"")
	if raw.begins_with("["):
		var items: Array = []
		for part in raw.trim_prefix("[").trim_suffix("]").split(",", false):
			items.append(part.strip_edges().trim_prefix("\"").trim_suffix("\""))
		return items
	if raw == "true":
		return true
	if raw == "false":
		return false
	return raw.to_float()
