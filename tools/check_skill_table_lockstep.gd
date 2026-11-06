extends SceneTree

# Skill table lockstep check: compares the passive skill caps (weapon, armor,
# casting: the most each class can reach at level 60) and the dual wield levels
# the client holds with the server's (world/skills.rs) and prints where they
# disagree. The server trains and caps every skill and decides who may swing an
# off hand; the client's copies draw the skill window and the "you will be
# able to dual wield at level N" line, so a table that moves on one side alone
# shows a cap or a level the server is not using.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_skill_table_lockstep.gd
#   godot --headless --path . -s tools/check_skill_table_lockstep.gd -- <path to skills.rs>
#
# It reports:
#   DRIFT        a class's cap for a skill, or its dual wield level, differs.
#   SERVER-ONLY  a class or skill the server's table has and the client's lacks.
#   CLIENT-ONLY  a class or skill the client's table has and the server's lacks.
#
# Exit code 1 on any of them, 2 when skills.rs cannot be read, 0 otherwise.

const DEFAULT_SKILLS_RS := "F:/Projects/server/crates/projectdawn-server/src/world/skills.rs"

const TABLES := [
	# server table,  client definitions
	["WEAPON_CAPS",  "res://data/weapon_skill_definitions.gd"],
	["ARMOR_CAPS",   "res://data/armor_skill_definitions.gd"],
	["CASTING_CAPS", "res://data/casting_skill_definitions.gd"],
]

func _initialize() -> void:
	var path := DEFAULT_SKILLS_RS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		path = args[0]
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		printerr("Could not read %s (pass the path to skills.rs after --)." % path)
		quit(2)
		return

	var problems: Array[String] = []
	for t in TABLES:
		var server := _parse_cap_table(text, t[0])
		if server.is_empty():
			problems.append("SERVER-ONLY  %s not found or empty in skills.rs (renamed? update TABLES)" % t[0])
			continue
		var client: Dictionary = load(t[1]).get_script_constant_map().get("CLASS_CAPS", {})
		_compare(t[0], server, client, problems)

	var dual_server := _parse_dual_wield(text)
	var dual_client: Dictionary = load("res://data/weapon_skill_definitions.gd").get_script_constant_map().get("DUAL_WIELD_LEVELS", {})
	if dual_server.is_empty():
		problems.append("SERVER-ONLY  dual_wield_level not found in skills.rs")
	for cls in dual_server:
		if not dual_client.has(cls):
			problems.append("SERVER-ONLY  dual wield: %s (level %d)" % [cls, dual_server[cls]])
		elif int(dual_client[cls]) != dual_server[cls]:
			problems.append("DRIFT        dual wield %s: server %d, client %d" % [cls, dual_server[cls], int(dual_client[cls])])
	for cls in dual_client:
		if not dual_server.has(cls):
			problems.append("CLIENT-ONLY  dual wield: %s (level %d)" % [cls, int(dual_client[cls])])

	if problems.is_empty():
		print("Skill caps (weapon, armor, casting) and dual wield levels in lockstep.")
		quit(0)
		return
	for line in problems:
		print(line)
	print("%d problem(s)." % problems.size())
	quit(1)

func _compare(table: String, server: Dictionary, client: Dictionary, problems: Array[String]) -> void:
	for cls in server:
		if not client.has(cls):
			problems.append("SERVER-ONLY  %s: class %s" % [table, cls])
			continue
		var sc: Dictionary = server[cls]
		var cc: Dictionary = client[cls]
		for key in sc:
			if not cc.has(key):
				problems.append("SERVER-ONLY  %s %s: %s" % [table, cls, key])
			elif int(cc[key]) != sc[key]:
				problems.append("DRIFT        %s %s %s: server %d, client %d" % [table, cls, key, sc[key], int(cc[key])])
		for key in cc:
			if not sc.has(key):
				problems.append("CLIENT-ONLY  %s %s: %s" % [table, cls, key])
	for cls in client:
		if not server.has(cls):
			problems.append("CLIENT-ONLY  %s: class %s" % [table, cls])

# `const NAME: CapTable<'static> = &[ ("Class", &[("key", n), ...]), ... ];`
# into { "Class": { "key": n } }.
func _parse_cap_table(text: String, name: String) -> Dictionary:
	var start := text.find("const %s:" % name)
	if start < 0:
		return {}
	var end := text.find("];", start)
	var body := text.substr(start, end - start)
	var row := RegEx.new()
	row.compile("\\(\"([^\"]+)\",\\s*&\\[(.*?)\\]\\)")
	var pair := RegEx.new()
	pair.compile("\\(\"([^\"]+)\",\\s*(-?\\d+)\\)")
	var out := {}
	for r in row.search_all(body):
		var caps := {}
		for p in pair.search_all(r.get_string(2)):
			caps[p.get_string(1)] = int(p.get_string(2))
		out[r.get_string(1)] = caps
	return out

# The match arms of `fn dual_wield_level`: `"A" | "B" => Some(n),`.
func _parse_dual_wield(text: String) -> Dictionary:
	var start := text.find("fn dual_wield_level")
	if start < 0:
		return {}
	var end := text.find("\n}", start)
	var body := text.substr(start, end - start)
	var arm := RegEx.new()
	arm.compile("((?:\"[^\"]+\"\\s*\\|?\\s*)+)=>\\s*Some\\((\\d+)\\)")
	var name := RegEx.new()
	name.compile("\"([^\"]+)\"")
	var out := {}
	for a in arm.search_all(body):
		for n in name.search_all(a.get_string(1)):
			out[n.get_string(1)] = int(a.get_string(2))
	return out
