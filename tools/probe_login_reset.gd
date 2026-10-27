extends SceneTree
# Headless probe for the login reset (2026-10-26): apply_character sets the
# bars to the level's full pools, which is a reset, not a heal. Logging in as a
# level 5 Gnome Warrior used to print "You were healed for 22 health." (the
# placeholder 100 HP to the level's 122) and float a heal number. A real heal
# afterwards is still announced. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_login_reset.gd

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
	var net = root.get_node("/root/Net")
	var ps = root.get_node("/root/PlayerStats")
	var log = root.get_node("/root/CombatLog")
	var heal_lines: Array[int] = [0]
	var heal_numbers: Array[int] = [0]
	log.line_added.connect(func(text: String, _t: int) -> void:
		if text.begins_with("You were healed for"):
			heal_lines[0] += 1)
	ps.healed.connect(func(_n: int) -> void: heal_numbers[0] += 1)

	# Launcher mode BEFORE the character is applied: a level change fires
	# SaveManager's autosave, which refuses online and would otherwise write
	# this probe's character over the real Test Room save.
	net._char_id = 7
	_check(ps.hp == 100.0, "starts at the placeholder 100 HP")
	ps.player_name = "ProbeBun"
	ps.apply_character("Gnome", "Warrior", 5)
	_check(ps.hp == ps.max_hp and ps.max_hp == 122.0, "the reset fills the bar to the level's 122 (got %s / %s)" % [ps.hp, ps.max_hp])
	_check(heal_lines[0] == 0, "the reset prints no heal line (got %d)" % heal_lines[0])
	_check(heal_numbers[0] == 0, "the reset floats no heal number (got %d)" % heal_numbers[0])

	# The server's dead seed lands next on a dead relogin: HP 0, no heal.
	ps.set_hp(0.0)
	_check(heal_lines[0] == 0, "dropping to 0 prints nothing")

	# A real heal afterwards is still announced.
	ps.set_hp(40.0)
	_check(heal_lines[0] == 1, "a real heal of 40 is still announced")
	_check(heal_numbers[0] == 1, "and floats its number")

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
