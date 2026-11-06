extends SceneTree
# Headless probe for fall damage slice 0's client half (2026-10-24,
# docs/design/server_fall_damage.md): the client computes no fall damage (the
# player script carries no landing-damage path; falls are the server's to
# judge), and the Test Panel's Trigger Death leaves the local HP alone (it asks
# the server, whose death sweep kills). Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_fall_and_death_online.gd

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

	net._char_id = 7
	ps.player_name = "ProbeFaller"
	ps.apply_character("Human", "Warrior", 10)
	ps.set_hp(ps.max_hp)

	var player = load("res://scripts/player.gd").new()
	_check(not player.has_method("_on_land") and not ("_peak_fall_speed" in player),
		"the player script computes no fall damage")

	# Trigger Death asks the server and leaves the local HP alone.
	var panel = load("res://scripts/test_panel.gd").new()
	var hp_before: float = ps.hp
	panel._trigger_death()
	_check(is_equal_approx(ps.hp, hp_before), "Trigger Death leaves the local HP to the server")
	net._char_id = -1

	player.free()
	panel.free()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
