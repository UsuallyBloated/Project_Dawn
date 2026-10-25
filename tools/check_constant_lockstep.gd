extends SceneTree

# Constant lockstep check: compares single values the client and the server
# each hold for the same rule (the day length, carry weight, the spell bar,
# Bard song timing, res sickness, run speed, the global cooldown) and prints
# where they disagree. The server decides each rule; the client copy draws it
# (a sky, a weight bar, a gem count, a countdown), so a value that moves on one
# side alone shows the player something the server is not doing.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_constant_lockstep.gd
#   godot --headless --path . -s tools/check_constant_lockstep.gd -- <server crate src dir>
#
# The server's constants are read from its Rust source: `const NAME: T = value;`
# on one line, where value is a number, a string, `Duration::from_secs(n)` /
# `from_millis(n)` (read as seconds), or arithmetic over numbers and other
# constants in the same file. The client's are the scripts' own constants.
#
# It reports:
#   DRIFT     the two values differ (or, for a "client longer" pair, the
#             client's is shorter, which would let it run ahead of the server).
#   MISSING   a constant this check expects is gone from one side (renamed or
#             removed: update PAIRS below along with it).
#
# Exit code 1 on either, 2 when the server source cannot be read, 0 otherwise.

const DEFAULT_SERVER_SRC := "F:/Projects/server/crates/projectdawn-server/src"

# Relations: "eq" the two must match; "client_longer" the client's may be
# longer (a client-side wait set a little past the server's, so an honest
# player is never refused) but never shorter.
const PAIRS := [
	# server file,         server constant,           client script,                     client constant,          relation
	["world/clock.rs",      "DAY_LENGTH_SECS",         "res://autoloads/time_of_day.gd",   "DAY_DURATION",           "eq"],
	["world/hunger.rs",     "HUNGRY_AT_SECS",          "res://scripts/hud_hunger_panel.gd", "HUNGRY_AT_SECS",        "eq"],
	["world/encumbrance.rs", "COIN_WEIGHT",            "res://autoloads/encumbrance.gd",   "COIN_WEIGHT",            "eq"],
	["world/encumbrance.rs", "BASE_CAPACITY",          "res://autoloads/encumbrance.gd",   "BASE_CAPACITY",          "eq"],
	["world/encumbrance.rs", "CAPACITY_PER_STR",       "res://autoloads/encumbrance.gd",   "CAPACITY_PER_STR",       "eq"],
	["world/encumbrance.rs", "SPEED_PENALTY_RATE",     "res://autoloads/encumbrance.gd",   "SPEED_PENALTY_RATE",     "eq"],
	["world/encumbrance.rs", "MIN_SPEED_MULT",         "res://autoloads/encumbrance.gd",   "MIN_SPEED_MULT",         "eq"],
	["world/encumbrance.rs", "OVERLOADED_RATIO",       "res://autoloads/encumbrance.gd",   "OVERLOADED_RATIO",       "eq"],
	["world/spell_gems.rs", "GEM_COUNT",               "res://autoloads/spell_bar.gd",     "SLOT_COUNT",             "eq"],
	["world/spell_gems.rs", "MIN_GEMS",                "res://autoloads/spell_bar.gd",     "MIN_SLOTS",              "eq"],
	["world/spell_gems.rs", "LEVELS_PER_EXTRA_GEM",    "res://autoloads/spell_bar.gd",     "SLOTS_PER_LEVEL_TIER",   "eq"],
	["world/spell_gems.rs", "MEMORIZE_SECS",           "res://autoloads/memorize.gd",      "MEMORIZE_CAST_TIME",     "eq"],
	["world/spell_gems.rs", "MEMORIZE_COST_FACTOR",    "res://autoloads/memorize.gd",      "MEMORIZE_COST_FACTOR",   "eq"],
	["world/mod.rs",        "SONG_PULSE_SECS",         "res://autoloads/bard_songs.gd",    "PULSE_INTERVAL",         "eq"],
	["world/mod.rs",        "SONG_LINGER_SECS",        "res://autoloads/bard_songs.gd",    "LINGER",                 "eq"],
	["world/mod.rs",        "SONG_SCALE_AT_LEARN",     "res://autoloads/bard_songs.gd",    "SCALE_AT_LEARN",         "eq"],
	["world/mod.rs",        "SONG_FULL_AT_LEVEL",      "res://autoloads/bard_songs.gd",    "FULL_AT_LEVEL",          "eq"],
	["world/buffs.rs",      "RES_SICKNESS_NAME",       "res://autoloads/buff_manager.gd",  "RES_SICKNESS_NAME",      "eq"],
	["world/buffs.rs",      "RES_SICKNESS_CUT_AT_1",   "res://autoloads/buff_manager.gd",  "RES_SICKNESS_CUT_AT_1",  "eq"],
	["world/buffs.rs",      "RES_SICKNESS_CUT_AT_60",  "res://autoloads/buff_manager.gd",  "RES_SICKNESS_CUT_AT_60", "eq"],
	["world/mod.rs",        "RUN_SPEED",               "res://scripts/player.gd",          "SPEED",                  "eq"],
	["world/mod.rs",        "GLOBAL_COOLDOWN",         "res://autoloads/spells.gd",        "GLOBAL_COOLDOWN_SECS",   "client_longer"],
	["world/skills.rs",     "MAX_LEVEL",               "res://data/weapon_skill_definitions.gd",  "MAX_LEVEL",      "eq"],
	["world/skills.rs",     "MAX_LEVEL",               "res://data/armor_skill_definitions.gd",   "MAX_LEVEL",      "eq"],
	["world/skills.rs",     "MAX_LEVEL",               "res://data/casting_skill_definitions.gd", "MAX_LEVEL",      "eq"],
]

const FLOAT_TOLERANCE := 0.000001

var _rust_cache := {}

func _initialize() -> void:
	var src := DEFAULT_SERVER_SRC
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		src = args[0]
	if not DirAccess.dir_exists_absolute(src):
		printerr("Server source not found at %s (pass the crate's src dir after --)." % src)
		quit(2)
		return

	var problems: Array[String] = []
	for p in PAIRS:
		var consts := _rust_consts(src.path_join(p[0]))
		var label := "%s %s / %s %s" % [p[0], p[1], p[2].get_file(), p[3]]
		if not consts.has(p[1]):
			problems.append("MISSING  server %s has no %s" % [p[0], p[1]])
			continue
		var script: Script = load(p[2])
		var client_consts: Dictionary = script.get_script_constant_map() if script != null else {}
		if not client_consts.has(p[3]):
			problems.append("MISSING  client %s has no %s" % [p[2], p[3]])
			continue
		var server_v = consts[p[1]]
		var client_v = client_consts[p[3]]
		if not _relation_holds(server_v, client_v, p[4]):
			problems.append("DRIFT    %s: server %s, client %s%s" % [label, str(server_v), str(client_v),
				" (the client's may be longer, never shorter)" if p[4] == "client_longer" else ""])

	print("Pairs checked: %d" % PAIRS.size())
	if problems.is_empty():
		print("Constants in lockstep.")
		quit(0)
		return
	for line in problems:
		print(line)
	print("%d problem(s)." % problems.size())
	quit(1)

func _relation_holds(server_v, client_v, relation: String) -> bool:
	if server_v is String or client_v is String:
		return str(server_v) == str(client_v) and relation == "eq"
	var s := float(server_v)
	var c := float(client_v)
	match relation:
		"eq":
			return absf(s - c) <= FLOAT_TOLERANCE
		"client_longer":
			return c >= s - FLOAT_TOLERANCE
	return false

# Every one-line `const NAME: T = value;` in a Rust file, evaluated. A value
# that cannot be read (a struct literal, a table) is skipped; a pair naming it
# then reports MISSING, which is the honest answer.
func _rust_consts(path: String) -> Dictionary:
	if _rust_cache.has(path):
		return _rust_cache[path]
	var out := {}
	var text := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("(?m)^\\s*(?:pub(?:\\([a-z]+\\))?\\s+)?const\\s+([A-Z][A-Z0-9_]*)\\s*:\\s*[^=]+=\\s*([^;]+);")
	for m in re.search_all(text):
		var v = _eval_rust(m.get_string(2).strip_edges(), out)
		if v != null:
			out[m.get_string(1)] = v
	_rust_cache[path] = out
	return out

func _eval_rust(expr: String, known: Dictionary):
	if expr.begins_with("\"") and expr.ends_with("\"") and expr.length() >= 2:
		return expr.substr(1, expr.length() - 2)
	var digits := RegEx.new()
	digits.compile("(\\d)_(\\d)")
	while digits.search(expr) != null:
		expr = digits.sub(expr, "$1$2", true)
	var dur := RegEx.new()
	dur.compile("Duration::from_(secs|millis)\\(\\s*([0-9.]+)\\s*\\)")
	var dm := dur.search(expr)
	if dm != null:
		var n := float(dm.get_string(2))
		return n / 1000.0 if dm.get_string(1) == "millis" else n
	# Plain arithmetic over numbers and earlier constants of the same file.
	var names: Array[String] = []
	var values: Array = []
	for k in known:
		if known[k] is float or known[k] is int:
			names.append(k)
			values.append(known[k])
	var e := Expression.new()
	if e.parse(expr, PackedStringArray(names)) != OK:
		return null
	var v = e.execute(values, null, false)
	if e.has_execute_failed() or not (v is float or v is int):
		return null
	return v
