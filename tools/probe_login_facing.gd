extends SceneTree
# Headless probe for the login facing seed (2026-11-09): the player's own body
# takes its facing from the first server Position (the yaw the server saved at
# the last logout, which every watcher already draws), and sends no Move until
# that Position has arrived (a Move carries the body's yaw, so one sent first
# would overwrite the saved facing with the scene's default: the small turn
# seen right after a relogin). Later Positions never re-seed the facing; the
# body's own is the truth from then on. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_login_facing.gd

const PLAYER_SCENE := "res://scenes/player.tscn"
const SAVED_YAW := 1.25
const SCENE_YAW := 0.3

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
	net._player_id = 7
	net._move_sequence = 0

	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	root.add_child(player)
	player.rotation.y = SCENE_YAW

	# The app is "ready" (the wire layer refuses the send with no connection,
	# so nothing leaves the process) and physics frames pass: the Move send
	# runs every 50 ms once it is allowed, and `Net.send_movement` counts.
	net._state = net.State.CONNECTED_APP
	await _wait_physics(20)
	_check(net._move_sequence == 0,
		"no Move is sent before the first server Position (sent %d)" % net._move_sequence)
	_check(is_equal_approx(player.rotation.y, SCENE_YAW), "the body still faces the scene's default meanwhile")

	# The first server Position: the saved spawn and the saved facing.
	player._on_world_position(7, Vector3(3.0, 0.0, 4.0), Vector3.ZERO, SAVED_YAW, 0)
	_check(player._received_first_pos, "the first Position is taken")
	_check(is_equal_approx(player.rotation.y, SAVED_YAW),
		"the body faces the server's saved yaw (%.2f, want %.2f)" % [player.rotation.y, SAVED_YAW])
	_check(is_equal_approx(player.global_position.x, 3.0) and is_equal_approx(player.global_position.z, 4.0),
		"and stands where the server put it")

	await _wait_physics(20)
	_check(net._move_sequence > 0, "Moves flow once the first Position has arrived (sent %d)" % net._move_sequence)

	# A later Position carries this body's own yaw back and never re-seeds it:
	# the body turned since, and the server's copy is a round trip behind.
	player.rotation.y = 2.0
	player._on_world_position(7, Vector3(3.0, 0.0, 4.0), Vector3.ZERO, SAVED_YAW, 5)
	_check(is_equal_approx(player.rotation.y, 2.0), "a later Position leaves the body's own facing alone")

	# Another player's Position is not this body's.
	var other: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	root.add_child(other)
	other.rotation.y = SCENE_YAW
	other._on_world_position(8, Vector3(9.0, 0.0, 9.0), Vector3.ZERO, 2.5, 0)
	_check(not other._received_first_pos and is_equal_approx(other.rotation.y, SCENE_YAW),
		"a Position for another id seeds nothing")

	net._state = net.State.DISCONNECTED
	net._move_sequence = 0
	net._player_id = -1
	player.queue_free()
	other.queue_free()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)

func _wait_physics(frames: int) -> void:
	for _i in range(frames):
		await physics_frame
