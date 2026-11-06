extends SceneTree

# Active skill lockstep check: compares the client's skill data
# (data/skill_definitions.gd) with the server's (active_skills.toml in the
# server repo) and prints where they disagree. The server owns a skill's
# cooldown, stamina, multiplier, classes and effect online (client-authority
# audit item 6), and the client shows the same numbers, so the two tables
# must match entry for entry.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_active_skill_lockstep.gd
#   godot --headless --path . -s tools/check_active_skill_lockstep.gd -- <path to active_skills.toml>
#
# Reports DRIFT (a value that differs), SERVER-ONLY and CLIENT-ONLY (a skill
# one side lacks). Unlike spells, every skill is meant to exist on both
# sides, so all three exit 1. Read-only.

const DEFAULT_SERVER_TOML := "F:/Projects/server/crates/projectdawn-server/data/active_skills.toml"
const EPSILON := 0.001
# Keys either side may leave out, meaning the same default on both.
const DEFAULTED_KEYS: Dictionary = {
	"effect_type": "", "effect_duration": 0.0, "absorb_amount": 0.0,
	"stun_duration": 0.0, "stealth_duration": 0.0,
}

func _initialize() -> void:
	var toml_path := DEFAULT_SERVER_TOML
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		toml_path = args[0]

	var server := _parse_toml(toml_path)
	if server.is_empty():
		printerr("No skills read from %s (wrong path, or the server repo is not checked out there)." % toml_path)
		quit(2)
		return

	var client: Dictionary = {}
	for d in SkillDefinitions.ALL:
		client[String(d["name"])] = d

	var drift: Array[String] = []
	var server_only: Array[String] = []
	var client_only: Array[String] = []

	for name in server:
		if not client.has(name):
			server_only.append(name)
			continue
		var s: Dictionary = server[name]
		var c: Dictionary = client[name]
		for key in DEFAULTED_KEYS:
			if not _same(s.get(key, DEFAULTED_KEYS[key]), c.get(key, DEFAULTED_KEYS[key])):
				drift.append("%s: %s is %s on the server, %s on the client" % [
					name, key, str(s.get(key, DEFAULTED_KEYS[key])), str(c.get(key, DEFAULTED_KEYS[key]))])
		for key in s:
			if key == "name" or DEFAULTED_KEYS.has(key) or not c.has(key):
				continue
			if not _same(s[key], c[key]):
				drift.append("%s: %s is %s on the server, %s on the client" % [name, key, str(s[key]), str(c[key])])
	for name in client:
		if not server.has(name):
			client_only.append(name)

	print("Active skill lockstep: client %d, server %d (%s)" % [client.size(), server.size(), toml_path])
	print("DRIFT: %d" % drift.size())
	for line in drift:
		print("  " + line)
	print("SERVER-ONLY: %d" % server_only.size())
	for name in server_only:
		print("  " + name)
	print("CLIENT-ONLY: %d" % client_only.size())
	for name in client_only:
		print("  " + name)
	quit(1 if (not drift.is_empty() or not server_only.is_empty() or not client_only.is_empty()) else 0)

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
	return absf(float(a) - float(b)) < EPSILON

# Just enough TOML for active_skills.toml: `[[skill]]` blocks of `key = value`
# lines (a quoted string, a number, or an array of quoted strings).
func _parse_toml(path: String) -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var current: Dictionary = {}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line == "[[skill]]":
			if current.has("name"):
				out[String(current["name"])] = current
			current = {}
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		current[line.substr(0, eq).strip_edges()] = _parse_value(line.substr(eq + 1).strip_edges())
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
	return raw.to_float()
