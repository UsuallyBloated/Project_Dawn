extends SceneTree
# Headless probe for what every remote body shares (R3, 2026-11-18): the
# network interpolation (a cold start snaps to the one snapshot, two snapshots
# interpolate toward the newer and arrive, a stale sequence is dropped, a dead
# body takes no snapshot and does not move) and the buff countdown (a duration
# ticks down and emits buffs_changed; the infinite sentinel does not move), on
# the three remote scenes as they are. Written before the RemoteEntity base
# was lifted out of them, so the base is held to the behaviour the three
# scripts had. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_remote_interpolation.gd

const SCENES := {
	"player": "res://scenes/remote_player.tscn",
	"enemy": "res://scenes/remote_enemy.tscn",
	"pet": "res://scenes/remote_pet.tscn",
}
const A := Vector3(0.0, 0.0, 0.0)
const B := Vector3(10.0, 0.0, 0.0)
const FAR := Vector3(500.0, 0.0, 500.0)
const EPS := 0.01

var _fails: int = 0
var _emits: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	await _probe_all()
	print("\n%d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)

func _probe_all() -> void:
	for kind in SCENES:
		var body: CharacterBody3D = load(SCENES[kind]).instantiate()
		root.add_child(body)
		await physics_frame
		await _probe_interpolation(kind, body)
		await _probe_buffs(kind, body)
		body.queue_free()
		await process_frame

func _probe_interpolation(kind: String, body: CharacterBody3D) -> void:
	# Cold start: one snapshot, the body stands on it and faces its yaw.
	body.on_position_update(B, 1.0, 1)
	await physics_frame
	_check(body.global_position.distance_to(B) < EPS, "%s: a cold start snaps to the one snapshot" % kind)
	_check(absf(body.rotation.y - 1.0) < EPS, "%s: a cold start takes the snapshot's yaw" % kind)

	# Two snapshots 100 ms apart: the body is drawn INTERP_LAG behind the
	# newest, so it moves from A toward B over the frames that follow and
	# arrives without overshooting.
	body.on_position_update(A, 0.0, 2)
	await physics_frame
	var waited := 0.0
	while waited < 0.1:
		await physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	body.on_position_update(B, 2.0, 3)
	var xs: PackedFloat32Array = PackedFloat32Array()
	for i in 20:
		await physics_frame
		xs.append(body.global_position.x)
	var monotone := true
	for i in range(1, xs.size()):
		if xs[i] < xs[i - 1] - EPS:
			monotone = false
	_check(xs[0] >= -EPS and xs[0] <= B.x + EPS, "%s: between the two snapshots the body is between them (x=%.2f)" % [kind, xs[0]])
	_check(monotone, "%s: the body moves toward the newer snapshot and never back" % kind)
	_check(absf(xs[xs.size() - 1] - B.x) < EPS, "%s: it arrives at the newer snapshot (x=%.2f)" % [kind, xs[xs.size() - 1]])
	_check(absf(body.rotation.y - 2.0) < EPS, "%s: and faces its yaw" % kind)

	# A stale sequence is dropped: the body stays where it is.
	body.on_position_update(FAR, 0.0, 2)
	for i in 5:
		await physics_frame
	_check(body.global_position.distance_to(B) < EPS, "%s: a stale sequence is dropped" % kind)

	# A dead body takes no snapshot and does not move.
	body.is_dead = true
	body.on_position_update(FAR, 0.0, 9)
	for i in 5:
		await physics_frame
	_check(body.global_position.distance_to(B) < EPS, "%s: a dead body takes no snapshot and stays put" % kind)
	body.is_dead = false

func _probe_buffs(kind: String, body: CharacterBody3D) -> void:
	_emits = 0
	var on_changed := func() -> void: _emits += 1
	body.buffs_changed.connect(on_changed)
	body.buff_names = PackedStringArray(["Haste", "Lich"])
	body.buff_durations = PackedFloat32Array([1.0, 999999.0])
	for i in 10:
		await process_frame
	_check(body.buff_durations[0] < 1.0 and body.buff_durations[0] > 0.0, "%s: a buff's duration ticks down (%.3f)" % [kind, body.buff_durations[0]])
	_check(body.buff_durations[1] == 999999.0, "%s: the infinite sentinel does not move" % kind)
	_check(_emits > 0, "%s: buffs_changed is emitted as it ticks (%d)" % [kind, _emits])
	body.buffs_changed.disconnect(on_changed)
	body.buff_names = PackedStringArray()
	body.buff_durations = PackedFloat32Array()
