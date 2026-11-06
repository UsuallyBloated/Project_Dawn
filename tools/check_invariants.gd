extends SceneTree

# Invariants check: every rule in docs/reference/invariants.md must name at
# least one test or check that enforces it, and every name must still exist.
# A test renamed or deleted would otherwise leave its rule unenforced with
# nothing saying so.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_invariants.gd
#   godot --headless --path . -s tools/check_invariants.gd -- <path to the server repo>
#
# A name ending in .gd must be a file in tools/. Any other name must be a Rust
# function (`fn <name>`) somewhere under the server repo's crates/. A name
# tagged "(on <branch>)" lives only on that server branch for now: if the
# checkout lacks it, it is looked up on the branch with git instead, and a
# branch that no longer exists fails (drop the tag once the branch merges).
#
# It reports:
#   NO HOLDER   a rule whose "Held by:" line names nothing.
#   MISSING     a name that no longer exists.
#   NO BRANCH   a "(on <branch>)" tag naming a branch the server repo lacks.
#
# Exit code 1 on any of them, 0 when every rule is held. Read-only.

const RULES := "res://docs/reference/invariants.md"
const DEFAULT_SERVER_ROOT := "F:/Projects/server"
const HOLDER := "`([A-Za-z0-9_.]+)`(?:\\s*\\(on ([^)]+)\\))?"

func _initialize() -> void:
	var server_root := DEFAULT_SERVER_ROOT
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		server_root = args[0]

	var rules := _parse_rules(RULES)
	if rules.is_empty():
		printerr("No rules read from %s." % RULES)
		quit(2)
		return
	var functions := {}
	_index_functions(server_root.path_join("crates"), functions)
	if functions.is_empty():
		printerr("No Rust functions found under %s/crates (wrong path, or the server repo is not checked out there)." % server_root)
		quit(2)
		return

	var problems: Array[String] = []
	var named := 0
	for rule in rules:
		var holders: Array = rule["holders"]
		if holders.is_empty():
			problems.append("NO HOLDER  %s" % rule["title"])
		for h in holders:
			named += 1
			var problem := _check_holder(h["name"], h["branch"], functions, server_root)
			if problem != "":
				problems.append("%s  (%s)" % [problem, rule["title"]])

	print("Rules: %d, names checked: %d" % [rules.size(), named])
	if problems.is_empty():
		print("Every rule is held.")
		quit(0)
		return
	for p in problems:
		print(p)
	quit(1)

# One problem line for a holder, or "" when it exists.
func _check_holder(name: String, branch: String, functions: Dictionary, server_root: String) -> String:
	if name.ends_with(".gd"):
		return "" if FileAccess.file_exists("res://tools/" + name) else "MISSING    tools/%s" % name
	if functions.has(name):
		return ""
	if branch == "":
		return "MISSING    fn %s" % name
	if OS.execute("git", ["-C", server_root, "rev-parse", "--verify", "-q", branch]) != 0:
		return "NO BRANCH  %s (holder %s)" % [branch, name]
	var found := OS.execute("git", ["-C", server_root, "grep", "-q", "-w", "fn " + name, branch, "--", "crates"])
	return "" if found == 0 else "MISSING    fn %s on %s" % [name, branch]

# The rules as [{title, holders: [{name, branch}]}]. A rule starts at a "### "
# heading; its holders are the backticked names in the paragraph that begins
# "Held by:" and runs to the next blank line.
func _parse_rules(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var holder_re := RegEx.new()
	holder_re.compile(HOLDER)
	var rules: Array = []
	var in_holders := false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("### "):
			rules.append({"title": line.substr(4), "holders": []})
			in_holders = false
			continue
		if rules.is_empty():
			continue
		if line.begins_with("Held by:"):
			in_holders = true
		elif line == "" or line.begins_with("#"):
			in_holders = false
		if in_holders:
			for m in holder_re.search_all(line):
				rules[-1]["holders"].append({"name": m.get_string(1), "branch": m.get_string(2)})
	return rules

# Every `fn <name>` in the .rs files under `dir`, as a set.
func _index_functions(dir: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	var fn_re := RegEx.new()
	fn_re.compile("\\bfn\\s+([a-z0-9_]+)")
	for sub in d.get_directories():
		if sub != "target":
			_index_functions(dir.path_join(sub), out)
	for file in d.get_files():
		if file.ends_with(".rs"):
			var text := FileAccess.get_file_as_string(dir.path_join(file))
			for m in fn_re.search_all(text):
				out[m.get_string(1)] = true
