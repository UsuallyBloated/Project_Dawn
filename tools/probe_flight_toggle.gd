extends SceneTree
# Headless probe for the client half of GM flight (docs/design/handoff_gm_flight.md,
# scripts/player.gd): a GM's body takes off on `start_flight` and tells the
# server once on the GM line; in flight its Moves flow and the body climbs with
# no gravity; it never goes under the ground and descending into it lands; a
# Teleport from the server ends the flight without a second `fly off`; a death
# ends it; `stop_flight` tells the server once; a non-GM cannot take off; a bad
# speed is refused. Then four rules of the eased flight, each stepped with a
# chosen frame time so the numbers are the same on every run: a speed lowered
# in flight cuts the velocity carried over; a Move's recorded prediction is
# held above the ground as the server holds the body; slow frames are not paid
# back as a burst of Moves; the body's frame step runs before Net's.
# Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_flight_toggle.gd

const PLAYER_SCENE := "res://scenes/player.tscn"

var _fails: int = 0
var _gm_lines: Array[String] = []
# Frame time as the nodes are given it, summed. Flight moves on rendered-frame
# deltas (player.gd's _process), so the probe times a flight by those: a count
# of physics steps says nothing exact about the time a flier was given.
var _clock: float = 0.0
var _last_delta: float = 0.0

# The main loop's own frame step: called with each frame's delta before the
# frame's `process_frame` signal and before any node's _process.
func _process(delta: float) -> bool:
	_clock += delta
	_last_delta = delta
	return false

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _on_gm_line(line: String) -> void:
	_gm_lines.append(line)

func _run() -> void:
	var net = root.get_node("/root/Net")
	net._player_id = 7
	net._move_sequence = 0
	# The app is "ready": the wire layer refuses the real sends with no
	# connection, and the GM lines are read off Net's own signal.
	net._state = net.State.CONNECTED_APP
	net.gm_line_sent.connect(_on_gm_line)

	# A floor at y = 0, so the body on foot has something to stand on (the
	# flight clamps need none: they read the terrain, or 0 without one).
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	root.add_child(player)
	player._on_world_position(7, Vector3(3.0, 0.0, 4.0), Vector3.ZERO, 0.0, 0)
	var lowest_in_flight: float = 0.0
	player.flight_changed.connect(func(flying: bool, _speed: float) -> void:
		if not flying:
			lowest_in_flight = minf(lowest_in_flight, player.global_position.y))

	net.set_is_gm(false)
	player.start_flight(25.0)
	_check(not player.is_flying and _gm_lines.is_empty(), "a non-GM cannot take off and nothing is sent")

	net.set_is_gm(true)
	player.start_flight(1000.0)
	_check(not player.is_flying and _gm_lines.is_empty(), "a speed past the limit is refused and nothing is sent")

	player.start_flight(25.0)
	_check(player.is_flying, "a GM takes off")
	_check(_gm_lines == ["fly 25.0"], "and tells the server once (%s)" % [_gm_lines])

	# The game's own loop flies the body: every rendered frame, along the ease,
	# for exactly the frame time it was given. Flight stepped anywhere else (the
	# physics step it used to run in) lands off this by a step's worth of time.
	var y0: float = player.global_position.y
	var sent_before: int = net._move_sequence
	var flown: float = await _hold("jump", 0.3)
	var climbed: float = player.global_position.y - y0
	var eased: float = FlyGlide.advance(Vector3.ZERO, Vector3.UP * 25.0, flown)[0].y
	_check(net._move_sequence > sent_before, "Moves flow in flight")
	_check(absf(climbed - eased) < 0.01,
		"the body climbs every rendered frame along the ease (%.3f m in %.3f s of frames; the ease at 25 m/s gives %.3f m)" % [climbed, flown, eased])
	_check(player.velocity == Vector3.ZERO, "no gravity acts on a flier")

	await _hold("fly_down", 1.5)
	_check(not player.is_flying, "descending into the ground lands")
	_check(lowest_in_flight >= -0.001,
		"the body landed on the ground, never under it (y %.3f at the landing)" % lowest_in_flight)
	_check(player.global_position.y >= -0.1 and player.global_position.y <= 0.6,
		"and stands on the floor after (y %.3f)" % player.global_position.y)
	_check(_gm_lines == ["fly 25.0", "fly off"], "and the landing is told (%s)" % [_gm_lines])

	_gm_lines.clear()
	player.start_flight(50.0)
	_check(player.is_flying and _gm_lines == ["fly 50.0"], "takeoff at another speed")
	net._on_teleport(Vector3(20.0, 0.0, 20.0))
	_check(not player.is_flying, "a Teleport ends the flight")
	_check(_gm_lines == ["fly 50.0"], "without telling the server again (%s)" % [_gm_lines])
	_check(player.global_position.is_equal_approx(Vector3(20.0, 0.0, 20.0)), "the body is where the server put it")

	_gm_lines.clear()
	player.start_flight(25.0)
	await _hold("jump", 0.3)
	_check(player.global_position.y > 4.0, "up again (y %.2f)" % player.global_position.y)
	root.get_node("/root/PlayerDeath").player_died.emit()
	_check(not player.is_flying and _gm_lines == ["fly 25.0"], "a death ends the flight, nothing more is sent")
	_check(absf(player.global_position.y) < 0.01,
		"and the body is put on the ground under it, as the server's is (y %.3f)" % player.global_position.y)

	# A speed is sent to a tenth and kept as sent, so the prediction, the HUD
	# and the server fly the same number.
	_gm_lines.clear()
	player.start_flight(12.34)
	_check(_gm_lines == ["fly 12.3"] and is_equal_approx(player.fly_speed, 12.3),
		"a speed is rounded to the tenth sent (%s, %.2f)" % [_gm_lines, player.fly_speed])
	player.stop_flight()

	_gm_lines.clear()
	player.start_flight(25.0)
	player.stop_flight()
	player.stop_flight()
	_check(_gm_lines == ["fly 25.0", "fly off"], "stop tells the server once (%s)" % [_gm_lines])

	# From here the probe calls the body's frame step itself with a chosen frame
	# time (the ease is exact for any), with no frame of the game's in between.
	var boost: float = (player.get_script() as GDScript).get_script_constant_map()["FLY_BOOST"]

	# A speed lowered in flight: the server flies the new speed at once, so the
	# velocity carried from the old one is cut to what the new one can fly. A
	# speed raised leaves it to the ease.
	_gm_lines.clear()
	player.start_flight(100.0)
	Input.action_press("move_forward")
	player._fly_tick(0.5, false)
	Input.action_release("move_forward")
	var fast: float = player._fly_vel.length()
	player.start_flight(10.0)
	var kept: float = player._fly_vel.length()
	_check(fast > 99.0 and absf(kept - 10.0 * boost) < 0.001,
		"the speed lowered from 100 to 10 m/s in flight cuts the %.1f m/s the body carried to the %.1f the new speed can fly" % [fast, kept])
	player.start_flight(50.0)
	_check(is_equal_approx(player._fly_vel.length(), kept),
		"a speed raised in flight leaves the velocity to the ease (%.1f m/s)" % player._fly_vel.length())
	_check(_gm_lines == ["fly 100.0", "fly 10.0", "fly 50.0"], "and each change is told once (%s)" % [_gm_lines])
	player.stop_flight()

	# The prediction a Move records is held as the server holds what it flies.
	# Three metres up and descending at 100 m/s, one tick takes the body down
	# 1.2 m and the Move it sends plans 2.9 m more: under the ground, where the
	# server will not put it.
	player.start_flight(100.0)
	player.global_position.y = 3.0
	player._move_send_accum = 0.0
	var seq_before: int = net._move_sequence
	Input.action_press("fly_down")
	player._fly_tick(0.05, false)
	Input.action_release("fly_down")
	var predicted: Dictionary = player._fly_recon._predicted
	var lowest: float = INF
	for entry in predicted.values():
		lowest = minf(lowest, entry[0].y)
	_check(player.is_flying and net._move_sequence == seq_before + 1 and predicted.size() == 1
			and player.global_position.y > 1.0,
		"one tick of descent from three metres sends one Move and does not land (y %.2f)" % player.global_position.y)
	_check(lowest >= 0.0, "and the Move's prediction is on the ground, not under it (y %.3f)" % lowest)
	player.stop_flight()

	# Six seconds at 15 frames a second cannot send 20 Moves a second, and what
	# it could not send is not owed: the half second at 144 that follows sends
	# its own ten and no more.
	player.start_flight(25.0)
	for _i in range(90):
		player._fly_tick(1.0 / 15.0, false)
	var before_fast: int = net._move_sequence
	for _i in range(72):
		player._fly_tick(1.0 / 144.0, false)
	var in_half_second: int = net._move_sequence - before_fast
	_check(in_half_second >= 9 and in_half_second <= 11,
		"after six seconds at 15 frames a second, half a second at 144 sends its ten Moves and no backlog (%d)" % in_half_second)
	player.stop_flight()

	_check(player.process_priority < net.process_priority,
		"the body's frame step runs before Net's, so a flight Move leaves in the frame that queued it (priority %d before %d)" % [player.process_priority, net.process_priority])

	net.gm_line_sent.disconnect(_on_gm_line)
	net._state = net.State.DISCONNECTED
	net._move_sequence = 0
	net._player_id = -1
	net.set_is_gm(false)
	player.queue_free()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)

# Hold `action` while the game's own loop runs for at least `secs` of frame
# time, and return the frame time the body was given with the key down. The key
# goes down and comes up at the top of a frame (`process_frame` is emitted
# before any node's step for it), so the time is exact: `_clock` already holds
# the frame that is about to run, which is why it is taken off at both ends.
func _hold(action: String, secs: float) -> float:
	await process_frame
	Input.action_press(action)
	var from := _clock - _last_delta
	while _clock - _last_delta - from < secs:
		await process_frame
	Input.action_release(action)
	return _clock - _last_delta - from
