extends SceneTree
# Headless probe for fall damage slice 0's client half (2026-10-24,
# docs/design/server_fall_damage.md): online a hard landing computes no damage
# and prints no "You hit the ground hard" line (the server ignored that dev
# DamageSelf for everyone but GMs), and the Test Panel's Trigger Death leaves
# the local HP alone (it asks the server, whose death sweep kills). Offline the
# landing still hurts. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_fall_and_death_online.gd

const HARD_LANDING := 30.0  # m/s, well past FALL_DAMAGE_THRESHOLD

var _fails: int = 0
var _ground_lines: int = 0

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
	log.line_added.connect(func(text: String, _t: int) -> void:
		if text.begins_with("You hit the ground hard"):
			_ground_lines += 1)

	# Launcher mode BEFORE the character is applied: a level change fires
	# SaveManager's autosave, which refuses online and would otherwise write
	# this probe's character over the real Test Room save.
	net._char_id = 7
	ps.player_name = "ProbeFaller"
	ps.apply_character("Human", "Warrior", 10)
	ps.set_hp(ps.max_hp)

	var player = load("res://scripts/player.gd").new()

	# Online: a hard landing does nothing on the client.
	player._peak_fall_speed = HARD_LANDING
	player._on_land()
	_check(_ground_lines == 0, "online, a hard landing prints no fall-damage line")

	# Online: Trigger Death asks the server and leaves the local HP alone.
	var panel = load("res://scripts/test_panel.gd").new()
	var hp_before: float = ps.hp
	panel._trigger_death()
	_check(is_equal_approx(ps.hp, hp_before), "online, Trigger Death leaves the local HP to the server")
	net._char_id = -1

	# Offline: the landing still hurts (the Test Room keeps its own falls). The
	# player node is outside the tree, so its damage number logs one harmless
	# "!is_inside_tree()" engine error here.
	var lines_before := _ground_lines
	player._peak_fall_speed = HARD_LANDING
	player._on_land()
	_check(_ground_lines == lines_before + 1, "offline, a hard landing still prints its line")

	player.free()
	panel.free()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
