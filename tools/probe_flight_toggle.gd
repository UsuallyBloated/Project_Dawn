extends SceneTree
# Headless probe for the client half of GM flight (docs/design/handoff_gm_flight.md,
# scripts/player.gd): a GM's body takes off on `start_flight` and tells the
# server once on the GM line; in flight its Moves flow and the body climbs with
# no gravity; it never goes under the ground and descending into it lands; a
# Teleport from the server ends the flight without a second `fly off`; a death
# ends it; `stop_flight` tells the server once; a non-GM cannot take off; a bad
# speed is refused. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_flight_toggle.gd

const PLAYER_SCENE := "res://scenes/player.tscn"

var _fails: int = 0
var _gm_lines: Array[String] = []

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

	Input.action_press("jump")
	var sent_before: int = net._move_sequence
	await _wait_physics(20)
	Input.action_release("jump")
	_check(net._move_sequence > sent_before, "Moves flow in flight")
	_check(player.global_position.y > 4.0,
		"the body climbs at the flight speed (y %.2f after a third of a second at 25 m/s)" % player.global_position.y)
	_check(player.velocity == Vector3.ZERO, "no gravity acts on a flier")

	Input.action_press("fly_down")
	await _wait_physics(40)
	Input.action_release("fly_down")
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
	root.get_node("/root/PlayerDeath").player_died.emit()
	_check(not player.is_flying and _gm_lines == ["fly 25.0"], "a death ends the flight, nothing more is sent")

	_gm_lines.clear()
	player.start_flight(25.0)
	player.stop_flight()
	player.stop_flight()
	_check(_gm_lines == ["fly 25.0", "fly off"], "stop tells the server once (%s)" % [_gm_lines])

	net.gm_line_sent.disconnect(_on_gm_line)
	net._state = net.State.DISCONNECTED
	net._move_sequence = 0
	net._player_id = -1
	net.set_is_gm(false)
	player.queue_free()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)

func _wait_physics(frames: int) -> void:
	for _i in range(frames):
		await physics_frame
