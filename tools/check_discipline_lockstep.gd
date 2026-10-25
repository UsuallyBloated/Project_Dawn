extends SceneTree

# Spell school lockstep check: compares the client's DISCIPLINE map
# (data/spell_definitions.gd: which casting skill each spell trains) with the
# server's (world/skills.rs, build_discipline_map) and prints where they
# disagree. The server uses the school to train the casting skill and to roll
# the fizzle chance; the client's copy draws the skill window. A spell missing
# from the server's map falls back to evocation there, so a spell mapped on one
# side only can fizzle and train against a different skill from the one the
# player is shown.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_discipline_lockstep.gd
#   godot --headless --path . -s tools/check_discipline_lockstep.gd -- <path to skills.rs>
#
# It reports:
#   DRIFT        a spell maps to a different school on each side.
#   SERVER-ONLY  a spell the server's map has and the client's lacks.
#   CLIENT-ONLY  a spell the client's map has and the server's lacks.
#
# Exit code 1 on any of them, 2 when skills.rs cannot be read, 0 otherwise.

const DEFAULT_SKILLS_RS := "F:/Projects/server/crates/projectdawn-server/src/world/skills.rs"

func _initialize() -> void:
	var path := DEFAULT_SKILLS_RS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		path = args[0]
	var text := FileAccess.get_file_as_string(path)
	var start := text.find("fn build_discipline_map(")
	if start < 0:
		printerr("Could not read build_discipline_map from %s (pass the path to skills.rs after --)." % path)
		quit(2)
		return
	var body := text.substr(start, text.find("\n}", start) - start)
	var pair := RegEx.new()
	pair.compile("\\(\"([^\"]+)\",\\s*\"([a-z_]+)\"\\)")
	var server := {}
	for m in pair.search_all(body):
		server[m.get_string(1)] = m.get_string(2)

	var client: Dictionary = load("res://data/spell_definitions.gd").get_script_constant_map().get("DISCIPLINE", {})
	var problems: Array[String] = []
	for spell in server:
		if not client.has(spell):
			problems.append("SERVER-ONLY  %s (%s)" % [spell, server[spell]])
		elif client[spell] != server[spell]:
			problems.append("DRIFT        %s: server %s, client %s" % [spell, server[spell], client[spell]])
	for spell in client:
		if not server.has(spell):
			problems.append("CLIENT-ONLY  %s (%s; the server falls back to evocation)" % [spell, client[spell]])

	print("Spells mapped: server %d, client %d" % [server.size(), client.size()])
	if problems.is_empty():
		print("Spell schools in lockstep.")
		quit(0)
		return
	for line in problems:
		print(line)
	print("%d problem(s)." % problems.size())
	quit(1)
