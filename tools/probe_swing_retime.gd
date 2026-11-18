extends SceneTree
# Headless probe for the swing re-time (2026-11-09): the auto-attack timers
# read the worn weapon's interval every time they start, so a weapon swapped
# with nothing targeted paces the NEXT fight at the new weapon's delay. Before,
# the equipment hook returned early with no target and the timer started on
# the wait_time the last fight left in it (a club's 2.0 s), so the first
# interval of a bow fight was the club's and the server dropped the second
# swing as too fast (one honest arrow lost, seen in the journal 2026-11-09).
# Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_swing_retime.gd

const ENEMY_SCENE := "res://scenes/remote_enemy.tscn"
const CLUB_DELAY := 2.0
const BOW_DELAY := 3.0

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

func _weapon(delay: float, name: String) -> ItemData:
	var w := ItemData.new()
	w.item_name = name
	w.type = ItemData.Type.WEAPON
	w.weapon_delay = delay
	return w

func _run() -> void:
	var combat = root.get_node("/root/Combat")
	var equipment = root.get_node("/root/Equipment")
	var ps = root.get_node("/root/PlayerStats")
	ps.player_name = "ProbeSwinger"
	ps.apply_character("Human", "Druid", 10)

	var enemy = load(ENEMY_SCENE).instantiate()
	root.add_child(enemy)

	# A fight with the club: the timer runs the club's interval.
	equipment.equipped["weapon"] = _weapon(CLUB_DELAY, "Trainee's Club")
	equipment.equipped.erase("offhand")
	combat.set_target(enemy)
	if not combat.is_auto_attacking:
		combat.toggle_auto_attack()
	_check(is_equal_approx(combat._auto_attack_timer.wait_time, CLUB_DELAY),
		"a club fight runs the club's %.1f s interval (got %.2f)" % [CLUB_DELAY, combat._auto_attack_timer.wait_time])

	# The fight ends, nothing targeted; the bow goes on. The equipment hook
	# has no running timer to re-time.
	combat.set_target(null)
	_check(combat._auto_attack_timer.is_stopped(), "the timer stops with nothing targeted")
	equipment.equipped["weapon"] = _weapon(BOW_DELAY, "Hunter's Shortbow")
	equipment.equipment_changed.emit("weapon", equipment.equipped["weapon"])

	# The next fight starts on the bow's interval, not the club's.
	combat.set_target(enemy)
	_check(not combat._auto_attack_timer.is_stopped(), "the next fight starts the timer")
	_check(is_equal_approx(combat._auto_attack_timer.wait_time, BOW_DELAY),
		"it runs the bow's %.1f s interval (got %.2f)" % [BOW_DELAY, combat._auto_attack_timer.wait_time])
	_check(combat._auto_attack_timer.time_left > CLUB_DELAY + 0.5,
		"and the first swing is a full bow interval away (%.2f s left)" % combat._auto_attack_timer.time_left)

	# Toggling auto-attack back on reads the interval fresh as well.
	combat.toggle_auto_attack()
	equipment.equipped["weapon"] = _weapon(CLUB_DELAY, "Trainee's Club")
	combat.toggle_auto_attack()
	_check(is_equal_approx(combat._auto_attack_timer.wait_time, CLUB_DELAY),
		"the toggle starts on the weapon worn now (got %.2f)" % combat._auto_attack_timer.wait_time)

	combat.toggle_auto_attack()
	combat.set_target(null)
	equipment.equipped.erase("weapon")
	enemy.queue_free()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
