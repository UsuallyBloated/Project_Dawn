extends SceneTree

# Character lockstep check: compares the tables that build a character on
# both sides (each race's stat bonuses, each class's bonuses and stamina, each
# class's per-level gains, and the XP curve's hell-level modifier) with the
# server's (char_data.rs) and prints where they disagree. The server computes
# every character and every level; the client's copies draw the character
# sheet, creation screen and XP bar, so a table that moves on one side alone
# shows stats or an XP band the server is not using.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_character_lockstep.gd
#   godot --headless --path . -s tools/check_character_lockstep.gd -- <path to char_data.rs>
#
# It reports:
#   DRIFT        a value differs (a stat, a stamina figure, a level's hell modifier).
#   SERVER-ONLY  a race or class the server's table has and the client's lacks.
#   CLIENT-ONLY  a race or class the client's table has and the server's lacks.
#
# A stat a table leaves out counts as 0 on both sides (Rust's
# `..Default::default()`, the client's missing key). Exit code 1 on any
# problem, 2 when char_data.rs cannot be read, 0 otherwise.

const DEFAULT_CHAR_DATA_RS := "F:/Projects/server/crates/projectdawn-server/src/char_data.rs"
const STATS := ["strength", "dexterity", "agility", "intelligence", "wisdom", "charisma", "constitution"]
const FLOAT_TOLERANCE := 0.000001

func _initialize() -> void:
	var path := DEFAULT_CHAR_DATA_RS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		path = args[0]
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		printerr("Could not read %s (pass the path to char_data.rs after --)." % path)
		quit(2)
		return

	var cd: Dictionary = load("res://data/character_data.gd").get_script_constant_map()
	var problems: Array[String] = []

	# Races: stat bonuses.
	var server_races := _parse_inserts(text, "races")
	var client_races := {}
	for r in cd["RACE_DATA"]:
		client_races[r] = {"stats": cd["RACE_DATA"][r].get("bonuses", {})}
	_compare("race", server_races, client_races, "", problems)

	# Classes: stat bonuses and the stamina bonus.
	var server_classes := _parse_inserts(text, "classes")
	var client_classes := {}
	for c in cd["CLASS_DATA"]:
		client_classes[c] = {"stats": cd["CLASS_DATA"][c].get("bonuses", {}),
			"stamina": float(cd["CLASS_DATA"][c].get("stamina_bonus", 0.0))}
	_compare("class", server_classes, client_classes, "stamina_bonus", problems)

	# Per-level gains, with the server's default against the client's "_default".
	var server_gains := _parse_inserts(text, "level_gains")
	var default_gain := _parse_inserts(text, "default_level_gain", true)
	if default_gain.has("_default"):
		server_gains["_default"] = default_gain["_default"]
	var client_gains := {}
	for c in cd["CLASS_LEVEL_GAINS"]:
		client_gains[c] = {"stats": cd["CLASS_LEVEL_GAINS"][c].get("stats", {}),
			"stamina": float(cd["CLASS_LEVEL_GAINS"][c].get("max_stamina", 0.0))}
	_compare("level gain", server_gains, client_gains, "max_stamina", problems)

	# The XP curve's hell-level modifier, level by level.
	var server_hell := _parse_hell_mod(text)
	if server_hell.is_empty():
		problems.append("SERVER-ONLY  hell_mod not found in char_data.rs")
	else:
		var ps = load("res://autoloads/player_stats.gd").new()
		for level in range(1, 61):
			var c: float = ps._hell_mod(level)
			if absf(c - server_hell[level]) > FLOAT_TOLERANCE:
				problems.append("DRIFT        hell_mod level %d: server %s, client %s" % [level, str(server_hell[level]), str(c)])
		ps.free()

	if problems.is_empty():
		print("Race and class bonuses, level gains and the XP curve's hell modifier in lockstep.")
		quit(0)
		return
	for line in problems:
		print(line)
	print("%d problem(s)." % problems.size())
	quit(1)

func _compare(kind: String, server: Dictionary, client: Dictionary, stamina_label: String, problems: Array[String]) -> void:
	for name in server:
		if not client.has(name):
			problems.append("SERVER-ONLY  %s %s" % [kind, name])
			continue
		for stat in STATS:
			var s: int = server[name]["stats"].get(stat, 0)
			var c: int = int(client[name]["stats"].get(stat, 0))
			if s != c:
				problems.append("DRIFT        %s %s %s: server %d, client %d" % [kind, name, stat, s, c])
		if stamina_label != "":
			var ss: float = server[name].get("stamina", 0.0)
			var cs: float = client[name].get("stamina", 0.0)
			if absf(ss - cs) > FLOAT_TOLERANCE:
				problems.append("DRIFT        %s %s %s: server %s, client %s" % [kind, name, stamina_label, str(ss), str(cs)])
	for name in client:
		if not server.has(name):
			problems.append("CLIENT-ONLY  %s %s" % [kind, name])

# The body of `fn <fn_name>(` up to the closing brace at column 0.
func _fn_body(text: String, fn_name: String) -> String:
	var start := text.find("fn %s(" % fn_name)
	if start < 0:
		return ""
	var end := text.find("\n}", start)
	return text.substr(start, end - start)

# Every `m.insert("Name", ...);` in a table function into
# { "Name": { "stats": {stat: n}, "stamina": f } }. With `single`, the whole
# body is one unnamed entry, returned as "_default".
func _parse_inserts(text: String, fn_name: String, single: bool = false) -> Dictionary:
	var body := _fn_body(text, fn_name)
	if body.is_empty():
		return {}
	var stat_re := RegEx.new()
	stat_re.compile("\\b(strength|dexterity|agility|intelligence|wisdom|charisma|constitution)\\s*:\\s*(-?\\d+)")
	var stamina_re := RegEx.new()
	stamina_re.compile("\\b(?:stamina_bonus|max_stamina)\\s*:\\s*(-?[0-9.]+)")
	var entries := {}
	if single:
		entries["_default"] = body
	else:
		var insert_re := RegEx.new()
		insert_re.compile("(?s)m\\.insert\\(\"([^\"]+)\",(.*?)\\}\\);")
		for m in insert_re.search_all(body):
			entries[m.get_string(1)] = m.get_string(2)
	var out := {}
	for name in entries:
		var stats := {}
		for s in stat_re.search_all(entries[name]):
			stats[s.get_string(1)] = int(s.get_string(2))
		var entry := {"stats": stats}
		var st := stamina_re.search(entries[name])
		if st != null:
			entry["stamina"] = float(st.get_string(1))
		out[name] = entry
	return out

# `fn hell_mod`'s match arms (`a..=b => x`, `n => x`, `_ => x`) as level -> x
# for levels 1 to 60.
func _parse_hell_mod(text: String) -> Dictionary:
	var body := _fn_body(text, "hell_mod")
	if body.is_empty():
		return {}
	var range_re := RegEx.new()
	range_re.compile("(\\d+)\\.\\.=(\\d+)\\s*=>\\s*([0-9.]+)")
	var one_re := RegEx.new()
	one_re.compile("(?m)^\\s*(\\d+)\\s*=>\\s*([0-9.]+)")
	var rest_re := RegEx.new()
	rest_re.compile("_\\s*=>\\s*([0-9.]+)")
	var out := {}
	for m in range_re.search_all(body):
		for level in range(int(m.get_string(1)), int(m.get_string(2)) + 1):
			out[level] = float(m.get_string(3))
	for m in one_re.search_all(body):
		out[int(m.get_string(1))] = float(m.get_string(2))
	var rest := rest_re.search(body)
	for level in range(1, 61):
		if not out.has(level) and rest != null:
			out[level] = float(rest.get_string(1))
	return out
