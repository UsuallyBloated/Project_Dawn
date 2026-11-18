extends SceneTree
# Check (run headless, exits 1 on failure; part of check_all.ps1): every chat command, typed into the
# real HUD, does what it is meant to. Nothing else drives the chat
# commands (scripts/hud_chat_commands.gd), so this is their net: written
# against the dispatcher as it stood in hud.gd on 2026-11-18 and kept green
# through its move and its turn into lookup tables. Eight rows changed on
# purpose the same day: a command that takes something says how it is used
# when typed bare (/give, /lang, /kick, /damage, /heal, /tell, /t), and
# "/itemsfoo" is no command.
#
# What runs: the real hud.tscn with a stub body in the "player" group. Each
# input goes in where a typed line does (CombatLog.chat_submitted), and the
# lines the game prints back (CombatLog.line_added) are compared with the
# table below. The commands that print nothing are held by what they do to
# the stub body and the windows, and by not being an "Unknown command".
#
# A command added to the tables fails this until it has a row here.
#
# Not covered: what a command sends to the server (there is no world
# connection, and every send is a request the server judges for itself) and
# the commands' effects in a live world, which the playtest sheet walks.
#   godot --headless --path . -s tools/check_chat_commands.gd
#   godot --headless --path . -s tools/check_chat_commands.gd -- --dump
# `--dump` prints what each input produces today, in the table's own form,
# for writing a new row.

const HUD_SCENE := "res://scenes/hud.tscn"
const WATCHDOG_SECS := 120.0
const TESTER_NAME := "Tester"
const STUB_POSITION := Vector3(12.34, 5.0, -67.8)

# In an expected list: ONE matches exactly one line of any text, REST matches
# whatever lines are left, and a line ending in "*" matches by its start.
const ONE := "?"
const REST := "..."

const UNKNOWN := "INFO|Unknown command: %s"

# The body the HUD finds in the "player" group: it counts what the commands
# ask of it and has a place to stand for /loc.
const STUB_BODY_SOURCE := """extends Node3D
var sat := 0
var stood := 0
func sit() -> void:
	sat += 1
func stand() -> void:
	stood += 1
"""

# Each row: [what is typed, the lines that come back as "TYPE|text"]. A String
# row is a step for the runner: "@sender <name>" puts a tell sender on file,
# "@no_senders" clears them, "@leader on|off" sets group leadership,
# "@languages on|off" gives the character two languages or none.
const TABLE := [
	# ── The channels (ChatChannel hands each on in one canonical form) ────
	["hello there", ["SAY|Tester says, 'hello there'"]],
	["/say hi", ["SAY|Tester says, 'hi'"]],
	["/s hi", ["SAY|Tester says, 'hi'"]],
	["/SAY Hi There", ["SAY|Tester says, 'Hi There'"]],
	["/shout hi", ["SHOUT|Tester shouts, 'hi'"]],
	["/sh hi", ["SHOUT|Tester shouts, 'hi'"]],
	["/ooc hi", ["OOC|[OOC] Tester: hi"]],
	["/g hi", ["GROUP_CHAT|[Group] Tester: hi"]],
	["/group hi", ["GROUP_CHAT|[Group] Tester: hi"]],
	["/gsay hi", ["GROUP_CHAT|[Group] Tester: hi"]],
	["/tell Bob hi there", ["TELL_OUT|You -> Bob: hi there"]],
	["/t Bob hi", ["TELL_OUT|You -> Bob: hi"]],
	# A channel command with nothing to say sends nothing and says nothing.
	["/say", []],
	["/shout", []],
	["/ooc", []],
	["/g", []],
	["/tell Bob", []],
	["   ", []],
	# A tell with no name says how one is written.
	["/tell", ["INFO|Usage: /tell <name> <message>"]],
	["/t", ["INFO|Usage: /tell <name> <message>"]],

	# ── Replies ───────────────────────────────────────────────────────────
	"@no_senders",
	["/r", ["INFO|No one has sent you a tell yet."]],
	["/reply", ["INFO|No one has sent you a tell yet."]],
	["/r hi", ["INFO|No one has sent you a tell yet."]],
	["/reply hi", ["INFO|No one has sent you a tell yet."]],
	"@sender Ann",
	["/r hi", ["TELL_OUT|You -> Ann: hi"]],
	["/reply hi there", ["TELL_OUT|You -> Ann: hi there"]],
	# A bare /r re-addresses the chat line (the sticky channel) and sends nothing.
	["/r", []],
	["/reply", []],
	"@no_senders",

	# ── Posture, camp, pets ───────────────────────────────────────────────
	["/camp", ["INFO|You must be sitting to camp."]],
	["/camp cancel", []],
	["/pet follow", []],
	["/pet guard", []],
	["/pet passive", []],
	["/pet sit", []],
	["/pet dismiss", []],
	["/pet attack", []],
	["/pet back", []],

	# ── Looking around ────────────────────────────────────────────────────
	["/inspect", ["INFO|Target a player to inspect."]],
	["/sense", [ONE]],
	["/sense heading", [ONE]],
	["/con", ["INFO|You are not connected to the world."]],
	["/consider", ["INFO|You are not connected to the world."]],
	["/factions", ["INFO|You have moved no faction's standing yet."]],
	["/stopsong", []],
	["/loc", ["INFO|Your location is 67.8, -12.3, 5.0 (north, west, height)."]],
	["/location", ["INFO|Your location is 67.8, -12.3, 5.0 (north, west, height)."]],
	["/loc raw", ["INFO|Your world position is 12.3, 5.0, -67.8 (x, y, z)."]],
	["/location raw", ["INFO|Your world position is 12.3, 5.0, -67.8 (x, y, z)."]],
	["/LOC", ["INFO|Your location is 67.8, -12.3, 5.0 (north, west, height)."]],

	# ── Languages ─────────────────────────────────────────────────────────
	"@languages off",
	["/languages", ["INFO|You know no languages."]],
	["/lang zzzz", ["INFO|You do not know the language 'zzzz'."]],
	["/lang", ["INFO|Usage: /lang [language name]"]],
	"@languages on",
	["/languages", ["INFO|Known languages:", "INFO|  Common — 100 (active)", "INFO|  Elvish — 25"]],
	["/lang Elvish", ["INFO|You are now speaking Elvish."]],
	["/languages", ["INFO|Known languages:", "INFO|  Common — 100", "INFO|  Elvish — 25 (active)"]],
	["/lang Orcish", ["INFO|You do not know the language 'Orcish'."]],
	"@languages off",

	# ── Dev tools (the server gates what they ask for) ────────────────────
	["/give zzzz", ["INFO|No items match 'zzzz'."]],
	["/give sword", ["INFO|Multiple matches for 'sword':", REST]],
	["/give iron short sword", ["INFO|Requested Iron Short Sword from server."]],
	["/give iron short sword 3", ["INFO|Requested Iron Short Sword x3 from server."]],
	["/give  zzzz", ["INFO|No items match 'zzzz'."]],
	["/GIVE zzzz", ["INFO|No items match 'zzzz'."]],
	["/give", ["INFO|Usage: /give <item name> [count]"]],
	["/items zzzz", ["INFO|No items match 'zzzz'."]],
	["/items sword", ["INFO|Items matching 'sword' (*", REST]],
	["/items", ["INFO|Usage: /items <substring> (registry has *"]],
	["/itemsfoo", [UNKNOWN % "/itemsfoo"]],
	["/damage 5", ["INFO|Dev damage self: 5"]],
	["/damage x", ["INFO|Usage: /damage <amount>"]],
	["/damage", ["INFO|Usage: /damage <amount>"]],
	["/heal 5", ["INFO|Dev heal self: 5"]],
	["/heal x", ["INFO|Usage: /heal <amount>"]],
	["/heal", ["INFO|Usage: /heal <amount>"]],
	["/testpanel", ["INFO|Test Panel unavailable (GM: no).*"]],
	["/gm", ["INFO|Test Panel unavailable (GM: no).*"]],

	# ── Toggles ───────────────────────────────────────────────────────────
	["/pvp", ["INFO|PvP override: on"]],
	["/pvp on", ["INFO|PvP override: on"]],
	["/pvp off", ["INFO|PvP override: off"]],
	["/autosplit", ["INFO|Auto-split loot: on"]],
	["/autosplit on", ["INFO|Auto-split loot: on"]],
	["/autosplit off", ["INFO|Auto-split loot: off"]],

	# ── Groups and loot ───────────────────────────────────────────────────
	"@leader off",
	["/loot", ["INFO|Loot mode: *"]],
	["/loot rr", ["INFO|Only the group leader can set the loot mode."]],
	["/loot roundrobin", ["INFO|Only the group leader can set the loot mode."]],
	["/loot ffa", ["INFO|Only the group leader can set the loot mode."]],
	["/loot freeforall", ["INFO|Only the group leader can set the loot mode."]],
	["/invite", ["INFO|Usage: /invite <character name> — or target a player first."]],
	["/invite Bob", ["INFO|Invited Bob to your group."]],
	["/accept", ["INFO|No pending group invite."]],
	["/accept invite", ["INFO|No pending group invite."]],
	["/leave", ["INFO|You aren't in a group."]],
	["/leave group", ["INFO|You aren't in a group."]],
	["/kick Bob", ["INFO|Only the group leader can kick."]],
	["/kick", ["INFO|Usage: /kick <character name>"]],
	"@leader on",
	["/loot ffa", ["INFO|Loot mode set to Free-for-all."]],
	["/loot rr", ["INFO|Loot mode set to Round Robin."]],
	["/kick Bob", ["INFO|Kicked Bob from the group."]],
	"@leader off",

	# ── The link and the build ────────────────────────────────────────────
	["/ping", ["INFO|Not connected to a world server."]],
	["/latency", ["INFO|Not connected to a world server."]],
	["/version", ["INFO|Build *", REST]],
	["/build", ["INFO|Build *", REST]],
	["/Version", ["INFO|Build *", REST]],

	# ── Not commands ──────────────────────────────────────────────────────
	["/nosuch", [UNKNOWN % "/nosuch"]],
	["/sit down", [UNKNOWN % "/sit down"]],
	["/stand up", [UNKNOWN % "/stand up"]],
	["/camp now", [UNKNOWN % "/camp now"]],
	["/pet", [UNKNOWN % "/pet"]],
	["/pet follow now", [UNKNOWN % "/pet follow now"]],
	["/pvp maybe", [UNKNOWN % "/pvp maybe"]],
	["/autosplit maybe", [UNKNOWN % "/autosplit maybe"]],
	["/loot xyz", [UNKNOWN % "/loot xyz"]],
	["/lootfoo", [UNKNOWN % "/lootfoo"]],
	["/loc now", [UNKNOWN % "/loc now"]],
	["/track now", [UNKNOWN % "/track now"]],
	["/console now", [UNKNOWN % "/console now"]],
	["/factions now", [UNKNOWN % "/factions now"]],
	["/sensefoo", [UNKNOWN % "/sensefoo"]],
	["/camp cancel now", [UNKNOWN % "/camp cancel now"]],
	["/inspect now", [UNKNOWN % "/inspect now"]],
	["/con now", [UNKNOWN % "/con now"]],
	["/consider now", [UNKNOWN % "/consider now"]],
	["/stopsong now", [UNKNOWN % "/stopsong now"]],
	["/languages now", [UNKNOWN % "/languages now"]],
	["/ping now", [UNKNOWN % "/ping now"]],
	["/latency now", [UNKNOWN % "/latency now"]],
	["/version now", [UNKNOWN % "/version now"]],
	["/build now", [UNKNOWN % "/build now"]],
	["/testpanel now", [UNKNOWN % "/testpanel now"]],
	["/gm now", [UNKNOWN % "/gm now"]],
	["/accept now", [UNKNOWN % "/accept now"]],
	["/leave now", [UNKNOWN % "/leave now"]],

	# ── A message that begins with a slash runs as a command (ChatChannel) ─
	["/tell Bob /camp", ["INFO|You must be sitting to camp."]],
	["/say /nosuch", [UNKNOWN % "/nosuch"]],
]

var _fails := 0
var _dump := false
var _lines: Array[String] = []
# The table keys the rows have reached, for the every-command-has-a-row check.
var _typed: Dictionary = {}
var _log: Node
var _hud: CanvasLayer
var _body: Node3D

func _check(ok: bool, what: String) -> void:
	if _dump:
		return
	print("%s  %s" % ["OK     " if ok else "FAILED ", what])
	if not ok:
		_fails += 1

func _initialize() -> void:
	_dump = "--dump" in OS.get_cmdline_user_args()
	# The autoloads join the tree after _initialize; everything runs on the
	# first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)
	create_timer(WATCHDOG_SECS).timeout.connect(func() -> void:
		print("FAILED  the check did not finish within %d s" % WATCHDOG_SECS)
		quit(1))

# One typed line through the real entry point; what the game printed back.
func _type(input: String) -> Array[String]:
	_note_key(input)
	_lines.clear()
	_log.chat_submitted.emit(input)
	return _lines.duplicate()

# Which table key this line will reach, found the way the dispatcher finds it.
func _note_key(input: String) -> void:
	var commands = _hud._chat_commands
	var line: String = ChatChannel.normalize(input, _log.last_tell_sender()).to_lower()
	if commands._exact.has(line):
		_typed[line] = true
		return
	var space := line.find(" ")
	var word := line if space < 0 else line.substr(0, space)
	if commands._with_args.has(word):
		_typed[word] = true

func _on_line(text: String, type: int) -> void:
	_lines.append("%s|%s" % [_log.MsgType.keys()[type], text])

static func _line_matches(expected: String, actual: String) -> bool:
	if expected == ONE:
		return true
	if expected.ends_with("*"):
		return actual.begins_with(expected.trim_suffix("*"))
	return expected == actual

static func _matches(expected: Array, actual: Array[String]) -> bool:
	for i in range(expected.size()):
		if expected[i] == REST:
			return true
		if i >= actual.size() or not _line_matches(expected[i], actual[i]):
			return false
	return actual.size() == expected.size()

func _step(step: String) -> void:
	var parts := step.split(" ")
	match parts[0]:
		"@sender":
			_log._note_tell_sender(parts[1])
		"@no_senders":
			_log._tell_senders.clear()
		"@leader":
			root.get_node("/root/GroupManager").is_leader = parts[1] == "on"
		"@languages":
			var languages := root.get_node("/root/Languages")
			languages.skills = {"Common": 100, "Elvish": 25} if parts[1] == "on" else {}
			languages.active_language = "Common"
		_:
			_check(false, "the table has a step the runner does not know: %s" % step)

func _run() -> void:
	_log = root.get_node("/root/CombatLog")
	root.get_node("/root/PlayerStats").player_name = TESTER_NAME

	var stub := GDScript.new()
	stub.source_code = STUB_BODY_SOURCE
	stub.reload()
	_body = Node3D.new()
	_body.set_script(stub)
	_body.add_to_group("player")
	root.add_child(_body)
	_body.global_position = STUB_POSITION

	_hud = load(HUD_SCENE).instantiate()
	root.add_child(_hud)
	await process_frame
	await process_frame
	_log.line_added.connect(_on_line)

	_table()
	_silent_commands()
	_tables_are_sound()
	_no_body()

	if _dump:
		quit(0)
		return
	print("\n%s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)

func _table() -> void:
	for row in TABLE:
		if row is String:
			_step(row)
			continue
		var input: String = row[0]
		var expected: Array = row[1]
		var actual := _type(input)
		if _dump:
			print("\t[%s, %s]," % [var_to_str(input), var_to_str(actual)])
			continue
		_check(_matches(expected, actual),
			"[%s] answers %s%s" % [input, str(expected),
				"" if _matches(expected, actual) else " (it answered %s)" % str(actual)])

# The commands that print nothing: held by what they do.
func _silent_commands() -> void:
	var sat: int = _body.sat
	_type("/sit")
	_check(_body.sat == sat + 1, "/sit sits the body")
	_type("/SIT")
	_check(_body.sat == sat + 2, "a command is matched whatever its case (/SIT)")
	var stood: int = _body.stood
	_type("/stand")
	_check(_body.stood == stood + 1, "/stand stands the body")
	_type("/say /sit")
	_check(_body.sat == sat + 3, "a say whose message is a command runs the command (/say /sit)")
	_type("/sit down")
	_check(_body.sat == sat + 3, "/sit with a trailing word sits nobody")

	var track = _hud._track_window
	var track_was: bool = track.visible
	_type("/track")
	_check(track.visible != track_was, "/track toggles the track window")
	_type("/track")
	_check(track.visible == track_was, "/track again puts it back")

	var console = _hud._debug_console
	var console_was: bool = console.visible
	var said := _type("/console")
	_check(console.visible != console_was and said.size() == 1
			and said[0].begins_with("INFO|Debug console: "), "/console toggles the debug console and says so")
	_type("/console")
	_check(console.visible == console_was, "/console again puts it back")

# The two lookup tables themselves (hud_chat_commands.gd). A command that
# prints nothing with no world to act on (the pet commands, /camp cancel,
# /stopsong) cannot be told from its neighbour by what comes back, so those
# are held by the function their key names.
const SILENT_HANDLERS := {
	"/camp cancel": "_cmd_camp_cancel",
	"/pet follow": "_cmd_pet_follow",
	"/pet guard": "_cmd_pet_guard",
	"/pet passive": "_cmd_pet_passive",
	"/pet sit": "_cmd_pet_passive",
	"/pet dismiss": "_cmd_pet_dismiss",
	"/pet attack": "_cmd_pet_attack",
	"/pet back": "_cmd_pet_back",
	"/stopsong": "_cmd_stopsong",
}

func _tables_are_sound() -> void:
	var commands = _hud._chat_commands
	var exact: Dictionary = commands._exact
	var with_args: Dictionary = commands._with_args
	var wrong: Array[String] = []
	for key in SILENT_HANDLERS:
		var handler: Callable = exact.get(key, Callable())
		if not handler.is_valid() or String(handler.get_method()) != SILENT_HANDLERS[key]:
			wrong.append(key)
	_check(wrong.is_empty(), "each command that prints nothing is run by its own function%s"
		% ("" if wrong.is_empty() else " (not so: %s)" % str(wrong)))

	var malformed: Array[String] = []
	var dead: Array[String] = []
	for table in [exact, with_args]:
		for key in table:
			var k := String(key)
			if k != k.to_lower() or k != k.strip_edges() or not k.begins_with("/") or k.contains("  "):
				malformed.append(k)
			if not (table[key] as Callable).is_valid():
				dead.append(k)
	for key in with_args:
		if String(key).contains(" "):
			malformed.append(String(key))
	_check(malformed.is_empty(), "every table key is a lowered command as it arrives%s"
		% ("" if malformed.is_empty() else " (not so: %s)" % str(malformed)))
	_check(dead.is_empty(), "every table key names a function that exists%s"
		% ("" if dead.is_empty() else " (not so: %s)" % str(dead)))

	# A first-word command answers its own bare form (with how it is used),
	# so the same word in the whole-line table would take that line from it.
	var in_both: Array[String] = []
	for key in exact:
		if with_args.has(key):
			in_both.append(String(key))
	_check(in_both.is_empty(), "no command word is in both tables%s"
		% ("" if in_both.is_empty() else " (in both: %s)" % str(in_both)))

	# Every command has a row: a new one cannot go in unheld.
	var unheld: Array[String] = []
	for table in [exact, with_args]:
		for key in table:
			if not _typed.has(key):
				unheld.append(String(key))
	_check(unheld.is_empty(), "every command in the tables is typed by a row of this check%s"
		% ("" if unheld.is_empty() else " (no row for: %s)" % str(unheld)))

# With no body in the world (the instant before it spawns, or after it is
# freed) a command says so or does nothing; it never errors.
func _no_body() -> void:
	_body.free()
	_check(_matches(["INFO|You have no location right now."], _type("/loc")),
		"/loc with no body says there is no location")
	_check(_type("/sit").is_empty() and _type("/stand").is_empty() and _type("/sense").is_empty(),
		"/sit, /stand and /sense with no body do nothing and say nothing")
