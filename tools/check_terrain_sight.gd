extends SceneTree

# Terrain sight check (the height model's line of sight, the first hills):
# the client refuses a targeted cast it cannot see before the bar runs
# (Spells._target_out_of_sight, a physics ray against the terrain's own
# layer), and the server refuses one at the release (world/terrain.rs::
# can_see). The two must agree, or an honest player is refused by the server
# after the client let the cast through (or refused by the client where the
# server would have let it land).
#
# Builds the scene's stored collider (the TerrainCol triangles) and the Floor
# on the terrain layer in a bare tree, then for seeded random pairs of points
# standing on the ground compares the ray, raised as the client raises it,
# with the exporter's port of the server's rule (Exporter.can_see_at). A pair
# whose lowest clearance is within GRAZE of the ground may go either way on
# float rounding and is left out. Exit 1 on any disagreement, or when no pair
# was blocked at all (a ground that blocks nothing proves nothing).
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_terrain_sight.gd

const Exporter := preload("res://tools/export_terrain.gd")
# The client's own sight constants, read at run time: spells.gd names other
# autoloads, so it compiles only once they are in the tree.
const SPELLS_SCRIPT := "res://autoloads/spells.gd"
const PAIRS := 3000
const SEED := 20261104
const GRAZE := 0.05

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var scene := Exporter.read_scene(Exporter.WORLD_SCENE)
	if scene.has("error"):
		printerr("Cannot read the terrain from %s: %s" % [Exporter.WORLD_SCENE, scene["error"]])
		quit(2)
		return
	var spells_consts: Dictionary = (load(SPELLS_SCRIPT) as Script).get_script_constant_map()
	var layer: int = spells_consts["TERRAIN_LAYER_MASK"]
	var los_height: float = spells_consts["LOS_HEIGHT"]
	var collider: PackedVector3Array = scene["collider"]
	if collider.is_empty():
		printerr("The scene's TerrainCol has no triangles.")
		quit(2)
		return

	# The terrain as the client collides with it, on the terrain layer only.
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = scene["origin"]
	var shape := ConcavePolygonShape3D.new()
	shape.data = collider
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	root.add_child(body)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = layer
	var floor_shape := CollisionShape3D.new()
	var plane := WorldBoundaryShape3D.new()
	plane.plane = Plane(Vector3.UP, float(scene["floor_y"]))
	floor_shape.shape = plane
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	await physics_frame
	await physics_frame

	var space := root.get_world_3d().direct_space_state
	var half := int(scene["grid_size"]) * float(scene["cell_size"]) * 0.5
	var origin: Vector3 = scene["origin"]
	var up := Vector3(0.0, los_height, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var seen := 0
	var blocked := 0
	var grazes := 0
	var disagreements := 0
	var worst := 0.0
	var worst_case := ""
	for i in PAIRS:
		var a := _on_ground(scene, rng, origin, half)
		var b := _on_ground(scene, rng, origin, half)
		var clearance := Exporter.min_clearance_at(scene, a + up, b + up)
		if absf(clearance) <= GRAZE:
			grazes += 1
			continue
		var params := PhysicsRayQueryParameters3D.create(a + up, b + up, layer)
		params.collide_with_areas = false
		var ray_blocked := not space.intersect_ray(params).is_empty()
		var port_sees := Exporter.can_see_at(scene, a, b)
		if port_sees:
			seen += 1
		else:
			blocked += 1
		if ray_blocked == port_sees:
			disagreements += 1
			if absf(clearance) > worst:
				worst = absf(clearance)
				worst_case = "%s to %s: the ray %s, the server's rule %s (clearance %.3f m)" % [
					a, b, "blocked" if ray_blocked else "clear", "sees" if port_sees else "blocks", clearance]
	print("%d pairs over the scene's ground: %d seen, %d blocked by the server's rule, %d grazes left out." % [
		PAIRS, seen, blocked, grazes])
	if disagreements > 0:
		print("FAIL %d pairs where the client's ray and the server's rule disagree; the worst: %s" % [disagreements, worst_case])
		quit(1)
		return
	if blocked == 0:
		print("FAIL no pair was blocked: this ground cannot tell the two apart.")
		quit(1)
		return
	print("The client's sight ray agrees with the server's rule on every pair.")
	quit(0)


# A point standing on the ground, anywhere on the plate.
func _on_ground(scene: Dictionary, rng: RandomNumberGenerator, origin: Vector3, half: float) -> Vector3:
	var x := origin.x + rng.randf_range(-half, half)
	var z := origin.z + rng.randf_range(-half, half)
	return Vector3(x, Exporter.ground_at(scene, x, z), z)
