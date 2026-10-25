extends SceneTree
# Headless probe for the client half of factions and alignment (2026-10-23):
# the Alignment autoload follows the server (a server score wins over the
# class seed and keeps winning across a class re-apply, a Paladin at Evil is
# a Paladin_Fallen, entering the world as another character forgets the old
# standings), the faction level names, the /con NPC-name helper, and that the
# Test Panel script still compiles with its faction section. Exits 1 on any
# miss. Run:
#   godot --headless --path . -s tools/probe_factions.gd

var _fails: int = 0
var _changes: int = 0

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
	var al = root.get_node("/root/Alignment")
	var ps = root.get_node("/root/PlayerStats")
	al.alignment_changed.connect(func(_t, _s): _changes += 1)

	# Offline / before the server speaks: the class seed applies.
	ps.player_class = "Paladin"
	al._on_app_connected(1)
	al.seed_class_start(500)
	_check(al.alignment_tier == "Good" and al.get_effective_class() == "Paladin",
		"the class seed sets a Paladin Good")

	# The server's score wins and re-runs the kits.
	var before := _changes
	al._on_server_alignment(-1600.0)
	_check(al.alignment_tier == "Evil", "a server score of -1600 reads Evil")
	_check(al.get_effective_class() == "Paladin_Fallen", "a Paladin at Evil casts as Paladin_Fallen")
	_check(_changes > before, "the server's first score re-runs the kits")

	# A class re-apply (level change, Test Panel) must not reseed it.
	al.seed_class_start(500)
	_check(is_equal_approx(al.exact_score, -1600.0), "a class re-apply leaves the server's score")

	# A same-tier move from the server changes the number, emits nothing.
	before = _changes
	al._on_server_alignment(-1601.5)
	_check(is_equal_approx(al.exact_score, -1601.5) and _changes == before,
		"a same-tier move updates the score without re-running the kits")

	# Shadow Knight at Exalted.
	ps.player_class = "Shadow Knight"
	al._on_server_alignment(1600.0)
	_check(al.get_effective_class() == "Shadow Knight_Redeemed", "a Shadow Knight at Exalted is Redeemed")

	# Standings.
	al._on_server_faction("greyveil_town", "The Folk of Greyveil", -200.0, 2)
	_check(al.factions.has("greyveil_town") and al.faction_level_name(2) == "Dubious",
		"a FactionUpdate is kept and level 2 reads Dubious")
	_check(al.faction_level_name(8) == "Ally" and al.faction_level_name(0) == "Scowls"
		and al.faction_level_name(99) == "Ally", "the level names clamp at both ends")

	# Another character: standings forgotten, the seed applies again.
	al._on_app_connected(2)
	_check(al.factions.is_empty(), "entering the world forgets the last character's standings")
	ps.player_class = "Cleric"
	al.seed_class_start(400)
	_check(is_equal_approx(al.exact_score, 400.0), "a new character takes its class seed until the server speaks")

	# The /con NPC-name helper: npc_name first, the role after a dash trimmed.
	var hud = load("res://scripts/hud.gd").new()
	var cases := {
		"var npc_name = \"Brom\"\nvar vendor_name = \"Brom — Provisioner\"": "Brom",
		"var banker_name = \"Thalia Mourne — Banker\"": "Thalia Mourne",
		"var vendor_name = \"Hadrik — Blacksmith\"": "Hadrik",
		"var enemy_id = 1000000001": "",
	}
	for src in cases:
		var gs := GDScript.new()
		gs.source_code = "extends Node\n" + src + "\n"
		gs.reload()
		var n: Node = gs.new()
		_check(hud._npc_display_name(n) == cases[src], "/con names %s" % (cases[src] if cases[src] != "" else "nothing for a mob"))
		n.free()
	hud.free()

	_check(load("res://scripts/test_panel.gd") != null, "the Test Panel script loads")
	_check(FactionDefinitions.ALL.size() == 6, "six factions on the client")

	print("probe_factions: %d failed" % _fails)
	quit(1 if _fails > 0 else 0)
