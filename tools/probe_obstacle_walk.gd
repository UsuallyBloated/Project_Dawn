extends SceneTree
# Headless probe for the body's half of the obstacle model
# (docs/design/obstacle_collision.md): the real player body, on a flat floor,
# run at a house and at a tree trunk. It must rest where the server's rule
# rests a body (its centre the body's radius from the wall), slide round the
# trunk without ever standing inside it, and pick the zone's real obstacle
# data up when it enters the scene. No scenery is a physics body: what stops
# the body is scripts/zone/zone_obstacles.gd, the server's own rule.
# Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_obstacle_walk.gd

const PLAYER_SCENE := "res://scenes/player.tscn"
# A house 10 m square with its west face at x = 10, and a trunk 0.3 m in
# radius a hand north of the row the body runs along (the server's
# integration tests use the same two: tests/world/obstacles.rs).
const HOUSE_WEST := 10.0
const TRUNK := Vector2(-10.0, 0.2)
const TRUNK_RADIUS := 0.3

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _yard() -> ZoneObstacles:
	var floats := PackedFloat32Array()
	floats.append_array(ZoneObstacles.encode_prism(3, 0.0, 4.0, 1.0, PackedVector2Array([
		Vector2(HOUSE_WEST, -5.0), Vector2(HOUSE_WEST + 10.0, -5.0), Vector2(HOUSE_WEST + 10.0, 5.0), Vector2(HOUSE_WEST, 5.0)])))
	var trunk := PackedVector2Array()
	for k in 6:
		trunk.append(TRUNK + Vector2.from_angle(TAU * k / 6.0) * TRUNK_RADIUS)
	floats.append_array(ZoneObstacles.encode_prism(3, 0.0, 8.0, 1.0, trunk))
	return ZoneObstacles.from_bytes(ZoneObstacles.encode_file(2, floats))


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await physics_frame


# A body standing at (x, 0), facing east, with the probe's yard to walk in.
func _body_at(x: float, yard: ZoneObstacles) -> CharacterBody3D:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	root.add_child(player)
	player.global_position = Vector3(x, 0.05, 0.0)
	# Facing east: the body runs along its own -z.
	player.rotation.y = -PI * 0.5
	player._obstacles = yard
	return player


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	# The real data is what a body gets when it enters the scene.
	var fresh: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	root.add_child(fresh)
	_check(fresh._obstacles != null and fresh._obstacles.size() > 1000,
		"a body entering the scene holds the zone's obstacle data (%d prisms)" % (fresh._obstacles.size() if fresh._obstacles != null else 0))
	fresh.queue_free()

	var yard := _yard()
	_check(yard != null and yard.size() == 2, "the probe's yard loads")

	# 1. At the house: six seconds of running east from 6 m out.
	var runner := _body_at(4.0, yard)
	await _wait_physics(10)
	runner._autorun = true
	var furthest := -INF
	for _i in 360:
		await physics_frame
		furthest = maxf(furthest, runner.global_position.x)
	var rest := runner.global_position
	_check(furthest <= HOUSE_WEST - ZoneObstacles.BODY_RADIUS + 0.01,
		"the body never passes the wall's face (furthest x %.3f, the face holds a body at %.1f)" % [furthest, HOUSE_WEST - ZoneObstacles.BODY_RADIUS])
	_check(absf(rest.x - (HOUSE_WEST - ZoneObstacles.BODY_RADIUS)) < 0.02 and absf(rest.z) < 0.02,
		"it rests against the face where the server rests it (%.3f, %.3f)" % [rest.x, rest.z])
	# Turned north along the wall, it slides freely.
	runner.rotation.y = PI
	await _wait_physics(60)
	_check(runner.global_position.z > 3.0 and absf(runner.global_position.x - rest.x) < 0.02,
		"turned along the wall it runs along it (z %.2f)" % runner.global_position.z)
	runner._autorun = false
	runner.queue_free()

	# 2. At the trunk: three seconds east from 4 m out.
	var walker := _body_at(-14.0, yard)
	await _wait_physics(10)
	walker._autorun = true
	var inside := 0
	var widest := 0.0
	for _i in 180:
		await physics_frame
		var at := Vector2(walker.global_position.x, walker.global_position.z)
		if not yard.is_free(at, ZoneObstacles.BODY_RADIUS):
			inside += 1
		widest = maxf(widest, -at.y)
	_check(inside == 0, "no frame has the body inside the trunk (%d did)" % inside)
	_check(walker.global_position.x > TRUNK.x + 2.0,
		"it slides round the trunk and carries on (x %.2f)" % walker.global_position.x)
	_check(widest > 0.2 and widest < TRUNK_RADIUS + ZoneObstacles.BODY_RADIUS + 0.05,
		"turned aside by no more than the trunk and the body are wide (%.2f m)" % widest)
	walker._autorun = false
	walker.queue_free()

	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)
