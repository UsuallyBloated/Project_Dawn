extends SceneTree
# Headless probe for the ground's winding (the first hills): every triangle the
# TerrainMesh builds faces up, flat-shaded and smooth, and a body dropped onto
# a raised plateau stands on top of it. Built the other way round, every face
# pointed down: the ground was culled when seen from above, and the body sank
# 0.6 m into the one-sided collider and never stood on it (the flat world hid
# both, since the Floor plane at y = 0 caught everyone). Exits 1 on any miss.
# Run:
#   godot --headless --path . -s tools/probe_terrain_stand.gd

const TERRAIN_SCRIPT := "res://scripts/terrain_mesh.gd"
const PLATEAU_TOP := 10.0
const GRAVITY := 20.0
# A capsule the size of the player's body.
const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 1.8
# How far the body's feet may sit from the plateau top.
const STAND_TOLERANCE := 0.05

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

# A 4 x 4 grid of 10 m cells whose middle 3 x 3 corners stand at PLATEAU_TOP:
# a 20 m square top with slopes down to 0 all round.
func _terrain(flat_shaded: bool) -> Node3D:
	var t: Node3D = load(TERRAIN_SCRIPT).new()
	t.grid_size = 4
	t.cell_size = 10.0
	t.flat_shaded = flat_shaded
	var h := PackedFloat32Array()
	h.resize(25)
	for z in range(1, 4):
		for x in range(1, 4):
			h[z * 5 + x] = PLATEAU_TOP
	t.heights = h
	root.add_child(t)
	return t

func _normals_face_up(t: Node3D) -> bool:
	var mesh: ArrayMesh = t.get_node("TerrainVisual").mesh
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	if normals.is_empty():
		return false
	for n in normals:
		if n.y <= 0.0:
			return false
	return true

func _run() -> void:
	for flat in [true, false]:
		var t := _terrain(flat)
		await process_frame
		_check(_normals_face_up(t), "every normal faces up (%s)" % ("flat" if flat else "smooth"))

		var body := CharacterBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = CAPSULE_RADIUS
		capsule.height = CAPSULE_HEIGHT
		shape.shape = capsule
		body.add_child(shape)
		root.add_child(body)
		body.global_position = Vector3(0, PLATEAU_TOP + 4.0, 0)
		for i in range(120):
			await physics_frame
			body.velocity.y -= GRAVITY / 60.0
			body.move_and_slide()
		var feet := body.global_position.y - CAPSULE_HEIGHT * 0.5
		_check(absf(feet - PLATEAU_TOP) <= STAND_TOLERANCE,
			"a dropped body's feet rest on the plateau top (%.3f m, want %.1f)" % [feet, PLATEAU_TOP])
		_check(body.is_on_floor(), "the body stands on the plateau (is_on_floor)")
		body.queue_free()
		t.queue_free()
		await process_frame

	print("%d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
