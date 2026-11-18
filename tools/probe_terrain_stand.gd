extends SceneTree
# Headless probe for the ground's winding (the first hills): every triangle the
# TerrainMesh builds faces up, in the mesh and in the collider, and a body
# dropped onto a raised plateau stands on top of it. Built the other way round,
# every face pointed down: the ground was culled when seen from above, and the
# body sank 0.6 m into the one-sided collider and never stood on it (the flat
# world hid both, since the Floor plane at y = 0 caught everyone). Run on a
# grid one chunk wide and on one that spans several, so a chunk's seam is
# stood on too. Exits 1 on any miss.
# Run:
#   godot --headless --path . -s tools/probe_terrain_stand.gd

const TERRAIN_SCRIPT := "res://scripts/terrain_mesh.gd"
# TerrainMesh.CHUNK_CELLS: how many cells a chunk is across.
const TERRAIN_CHUNK := 40
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

# A grid of 10 m cells whose middle corners stand at PLATEAU_TOP: a square top
# with slopes down to 0 all round.
func _terrain(grid: int) -> Node3D:
	var t: Node3D = load(TERRAIN_SCRIPT).new()
	t.grid_size = grid
	t.cell_size = 10.0
	var row := grid + 1
	var h := PackedFloat32Array()
	h.resize(row * row)
	for z in range(1, grid):
		for x in range(1, grid):
			h[z * row + x] = PLATEAU_TOP
	t.heights = h
	root.add_child(t)
	return t

# Godot's front face is the one its corners run clockwise round seen from the
# front, so a triangle a, b, c faces up when (c - a) x (b - a) points up.
func _mesh_faces_up(t: Node3D) -> bool:
	var checked := 0
	for chunk in t.get_node("TerrainVisual").get_children():
		var arrays: Array = (chunk as MeshInstance3D).mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for n in normals:
			if n.y <= 0.0:
				return false
		for i in range(0, indices.size(), 3):
			var a := verts[indices[i]]
			if (verts[indices[i + 2]] - a).cross(verts[indices[i + 1]] - a).y <= 0.0:
				return false
			checked += 1
	return checked > 0

func _collider_faces_up(t: Node3D) -> bool:
	var faces: PackedVector3Array = t.collider_faces()
	for i in range(0, faces.size(), 3):
		if (faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i]).y <= 0.0:
			return false
	return not faces.is_empty()

func _run() -> void:
	# One chunk, then a grid three chunks wide whose middle is a chunk corner.
	for grid in [4, 2 * TERRAIN_CHUNK + 20]:
		var t := _terrain(grid)
		await process_frame
		var label := "%d x %d cells" % [grid, grid]
		_check(_mesh_faces_up(t), "every mesh triangle and normal faces up (%s)" % label)
		_check(_collider_faces_up(t), "every collider triangle faces up (%s)" % label)
		var want_chunks := int(ceil(float(grid) / TERRAIN_CHUNK))
		_check(t.get_node("TerrainBody").get_child_count() == want_chunks * want_chunks,
			"the ground is %d chunk(s) (%s)" % [want_chunks * want_chunks, label])

		var body := CharacterBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = CAPSULE_RADIUS
		capsule.height = CAPSULE_HEIGHT
		shape.shape = capsule
		body.add_child(shape)
		root.add_child(body)
		# Where four chunks meet on the wide grid (a seam must hold a body too).
		var drop := Vector2.ZERO
		if grid > TERRAIN_CHUNK:
			drop = Vector2.ONE * (-grid * 5.0 + TERRAIN_CHUNK * 10.0)
		body.global_position = Vector3(drop.x, PLATEAU_TOP + 4.0, drop.y)
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
