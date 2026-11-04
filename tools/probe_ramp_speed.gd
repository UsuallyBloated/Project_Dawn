extends SceneTree
# Measures how fast the player's body covers ground up a slope (the server
# height model, docs/design/server_height_model.md section 3.4): the server
# integrates a flat 5 m/s, and if `move_and_slide` covers less ground uphill
# the reconciliation would pull an honest client forward on every hill, so the
# number has to be known before the slope rule is built. Prints the XZ speed
# and the along-slope speed on ramps of 0, 15, 30, 45 and 50 degrees after the
# body has settled, running straight uphill. Exits 1 only if the flat control
# is not the plain run speed. Run:
#   godot --headless --path . -s tools/probe_ramp_speed.gd

const PLAYER_SCENE := "res://scenes/player.tscn"
# Ramp angle and which way the body runs on it: up the slope, down it, or
# across it (along the contour).
const RUNS := [
	[0.0, "up"], [15.0, "up"], [30.0, "up"], [45.0, "up"], [50.0, "up"],
	[54.0, "up"], [56.0, "up"], [60.0, "up"],
	[30.0, "down"], [45.0, "down"], [30.0, "across"], [45.0, "across"],
]
const SETTLE_SECS := 0.5
const RUN_SECS := 2.0

var _fails: int = 0

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	for run in RUNS:
		var deg: float = run[0]
		var way: String = run[1]
		var speeds := await _measure(deg, way)
		print("ramp %4.1f deg %-6s: xz %.3f m/s, along the slope %.3f m/s, rise %+.3f m/s (flat run speed 5.0)" % [deg, way, speeds.x, speeds.y, speeds.z])
		if deg == 0.0 and absf(speeds.x - 5.0) > 0.15:
			print("FAIL  the flat control should run at 5 m/s")
			_fails += 1
	print("")
	quit(_fails)

# A slab whose top face passes through the origin and rises toward -Z at `deg`
# degrees, the player standing on it at the origin, facing uphill, downhill or
# along the contour. Returns (xz speed, along-slope speed, vertical speed).
func _measure(deg: float, way: String) -> Vector3:
	var theta := deg_to_rad(deg)
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 2.0, 400.0)
	shape.shape = box
	ramp.add_child(shape)
	ramp.rotation.x = theta
	var normal := Vector3(0.0, cos(theta), sin(theta))
	ramp.position = -normal
	root.add_child(ramp)

	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	root.add_child(player)
	player.global_position = Vector3(0.0, 0.2, 0.0)
	match way:
		"down":
			player.rotation.y = PI
		"across":
			player.rotation.y = PI * 0.5

	# Let it land and settle.
	await _wait(SETTLE_SECS)
	Input.action_press("move_forward")
	# Reach a steady state before measuring.
	await _wait(1.0)
	var start := player.global_position
	await _wait(RUN_SECS)
	var end := player.global_position
	Input.action_release("move_forward")
	await _wait(0.1)

	var xz := Vector2(end.x - start.x, end.z - start.z).length() / RUN_SECS
	var along := start.distance_to(end) / RUN_SECS
	var rise := (end.y - start.y) / RUN_SECS
	player.queue_free()
	ramp.queue_free()
	await _wait(0.1)
	return Vector3(xz, along, rise)

func _wait(secs: float) -> void:
	var frames := int(ceil(secs * Engine.physics_ticks_per_second))
	for i in frames:
		await physics_frame
