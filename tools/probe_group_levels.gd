extends SceneTree
# Headless probe for group-mates' levels and classes (2026-11-17, PD_W0031).
# The roster the server sends carries each member's level and class; the
# group panel shows them as "12 WAR" (never the old "Lv 0"); every class has
# a three-letter name. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_group_levels.gd

const PANEL_SCRIPT := "res://scripts/hud_group_panel.gd"

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

# The autoloads join the tree after _initialize, so the checks run on the
# first frame.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	# Every class has a three-letter name, all different; the user's examples.
	var seen: Dictionary = {}
	for cls in CharacterData.CLASSES:
		var ab := CharacterData.class_abbrev(cls)
		_check(CharacterData.CLASS_ABBREV.has(cls), "%s has a table entry" % cls)
		_check(ab.length() == 3 and ab == ab.to_upper(), "%s is three capitals (%s)" % [cls, ab])
		_check(not seen.has(ab), "%s's %s is not shared" % [cls, ab])
		seen[ab] = cls
	_check(CharacterData.class_abbrev("Warrior") == "WAR", "Warrior is WAR")
	_check(CharacterData.class_abbrev("Necromancer") == "NEC", "Necromancer is NEC")
	_check(CharacterData.class_abbrev("Warlock") == "WAR", "an unlisted class falls back to its first three letters")
	_check(CharacterData.class_abbrev("") == "", "no class, no name")

	# The roster's levels and classes reach the member rows.
	var net = root.get_node("/root/Net")
	net._player_id = 7
	var gm = root.get_node("/root/GroupManager")
	var ids := PackedInt64Array([7, 9])
	var names := PackedStringArray(["Me", "Mate"])
	var levels := PackedInt32Array([3, 12])
	var classes := PackedStringArray(["Cleric", "Warrior"])
	net.world_group_roster.emit(1, 7, ids, names, 0, levels, classes)
	_check(gm.in_group and gm.members.size() == 2, "the roster forms the group")
	var mate: Dictionary = {}
	for m in gm.members:
		if m.get("peer_id") == 9:
			mate = m
	_check(mate.get("level", 0) == 12, "the mate's row carries level 12 (got %s)" % str(mate.get("level")))
	_check(mate.get("class", "") == "Warrior", "the mate's row carries Warrior (got %s)" % str(mate.get("class")))

	# A re-sent roster (the mate died and lost a level) replaces the level and
	# keeps the bars the mate already had.
	mate["hp"] = 40.0
	mate["max_hp"] = 50.0
	net.world_group_roster.emit(1, 7, ids, names, 0, PackedInt32Array([3, 11]), classes)
	for m in gm.members:
		if m.get("peer_id") == 9:
			mate = m
	_check(mate.get("level", 0) == 11, "a re-sent roster moves the level down (got %s)" % str(mate.get("level")))
	_check(mate.get("hp", 0.0) == 40.0 and mate.get("max_hp", 0.0) == 50.0,
		"and keeps the mate's bars (hp %s / %s)" % [str(mate.get("hp")), str(mate.get("max_hp"))])

	# The panel's text.
	var panel_script = load(PANEL_SCRIPT)
	_check(panel_script.member_level_text(mate) == "11 WAR", "the panel shows \"11 WAR\" (got \"%s\")" % panel_script.member_level_text(mate))
	_check(panel_script.member_level_text({"level": 0, "class": "Warrior"}) == "", "no level yet shows nothing, never Lv 0")
	_check(panel_script.member_level_text({"level": 5, "class": ""}) == "5", "a level with no class shows the level alone")

	# And a built row shows it.
	var panel = panel_script.new()
	root.add_child(panel)
	var row: Dictionary = panel._build_member_row(mate)
	var texts: Array[String] = []
	_collect_labels(row.panel, texts)
	_check(texts.has("11 WAR"), "a built member row has the label \"11 WAR\" (labels %s)" % str(texts))

	net.world_group_roster.emit(1, 7, PackedInt64Array(), PackedStringArray(), 0, PackedInt32Array(), PackedStringArray())
	_check(not gm.in_group, "an empty roster ends the group")

	print("probe_group_levels: %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	quit(1 if _fails > 0 else 0)

func _collect_labels(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_labels(c, out)
