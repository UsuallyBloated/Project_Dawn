extends SceneTree

# Terrain exporter (the server height model, docs/design/server_height_model.md):
# writes the server's `terrain.toml` from `scenes/world.tscn`, so the server
# samples exactly the ground the client walks on: the TerrainMesh's grid,
# heights and origin, and the Floor plane's height. The scene is read as data
# (its PackedScene state), never instanced, so this runs headless.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/export_terrain.gd
#   godot --headless --path . -s tools/export_terrain.gd -- <path to terrain.toml>
#
# Commit the regenerated TOML in the server repo alongside the scene change.
# `tools/check_terrain_lockstep.gd` (in check_all.ps1) fails when the two
# disagree, so a scene edit nobody exported cannot reach a build unnoticed. The
# scene reader, the canonical hash and the ground sampler below are static so
# the check uses the same code and the two tools cannot disagree about what
# the server carries.

const DEFAULT_OUTPUT := "F:/Projects/server/crates/projectdawn-server/data/terrain.toml"
const WORLD_SCENE := "res://scenes/world.tscn"
const TERRAIN_SCRIPT := "res://scripts/terrain_mesh.gd"
const TERRAIN_NODE := "TerrainMesh"
const FLOOR_NODE := "Floor"
const FLOOR_SHAPE_NODE := "FloorShape"
# Heights are written with this many decimals: enough for a 32-bit float to
# come back from the text as the same number, which the hash relies on.
const DECIMALS := 9


func _initialize() -> void:
	var out_path := DEFAULT_OUTPUT
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_path = args[0]

	var scene := read_scene(WORLD_SCENE)
	if scene.has("error"):
		printerr("Cannot read the terrain from %s: %s" % [WORLD_SCENE, scene["error"]])
		quit(2)
		return

	var text := render_toml(scene)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("Cannot open %s for writing (error %d)." % [out_path, FileAccess.get_open_error()])
		quit(2)
		return
	f.store_string(text)
	f.close()
	var heights: PackedFloat32Array = scene["heights"]
	print("Wrote %d heights (%dx%d cells of %s m, floor %s, hash %s) to %s" % [
		heights.size(), scene["grid_size"], scene["grid_size"], str(scene["cell_size"]),
		str(scene["floor_y"]), written_hash(scene).substr(0, 12), out_path])
	quit(0)


# The terrain as the scene holds it: {grid_size, cell_size, origin, floor_y,
# heights, collider (the TerrainCol triangles, local to the node), npcs
# ([{name, pos}])}, or {error}. Reads the PackedScene's state, so nothing in
# the scene runs.
static func read_scene(scene_path: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {"error": "not a PackedScene"}
	var state := packed.get_state()
	var terrain_script := load(TERRAIN_SCRIPT)
	if terrain_script == null:
		return {"error": "cannot load %s" % TERRAIN_SCRIPT}
	# The script's defaults, for the properties the scene leaves unset.
	var defaults: Node = terrain_script.new()
	var out := {
		"grid_size": int(defaults.grid_size),
		"cell_size": float(defaults.cell_size),
		"origin": Vector3.ZERO,
		"floor_y": 0.0,
		"heights": PackedFloat32Array(),
		"collider": PackedVector3Array(),
		"npcs": [],
	}
	defaults.free()
	var found_terrain := false
	var found_floor := false
	var floor_origin_y := 0.0
	var plane := Plane(Vector3.UP, 0.0)
	for i in state.get_node_count():
		var props := _node_props(state, i)
		var name := String(state.get_node_name(i))
		var path := String(state.get_node_path(i))
		if name == TERRAIN_NODE:
			found_terrain = true
			if props.has("grid_size"):
				out["grid_size"] = int(props["grid_size"])
			if props.has("cell_size"):
				out["cell_size"] = float(props["cell_size"])
			if props.has("transform"):
				var t: Transform3D = props["transform"]
				# The model carries a position only: a rotated or scaled
				# TerrainMesh would export, hash and parse cleanly while the
				# server sampled a ground the client does not have.
				if not t.basis.is_equal_approx(Basis.IDENTITY):
					return {"error": "the %s node is rotated or scaled (%s); the height model carries a position only" % [TERRAIN_NODE, t.basis]}
				out["origin"] = t.origin
			if props.has("heights"):
				out["heights"] = PackedFloat32Array(props["heights"])
		elif name == "TerrainCol" and path.begins_with("./" + TERRAIN_NODE):
			var shape = props.get("shape")
			if shape is ConcavePolygonShape3D:
				out["collider"] = (shape as ConcavePolygonShape3D).data
		elif name == FLOOR_NODE and path == "./" + FLOOR_NODE:
			found_floor = true
			if props.has("transform"):
				var t: Transform3D = props["transform"]
				if not t.basis.is_equal_approx(Basis.IDENTITY):
					return {"error": "the %s node is rotated or scaled (%s); the height model only knows a flat floor" % [FLOOR_NODE, t.basis]}
				floor_origin_y = t.origin.y
		elif name == FLOOR_SHAPE_NODE and path.begins_with("./" + FLOOR_NODE):
			var shape = props.get("shape")
			if shape is WorldBoundaryShape3D:
				plane = (shape as WorldBoundaryShape3D).plane
		if props.has("npc_name") or props.has("banker_name") or props.has("vendor_name"):
			var npc_name: String = props.get("npc_name", props.get("banker_name", props.get("vendor_name", "")))
			var pos := Vector3.ZERO
			if props.has("transform"):
				pos = (props["transform"] as Transform3D).origin
			out["npcs"].append({"name": npc_name, "pos": pos})
	if not found_terrain:
		return {"error": "no %s node" % TERRAIN_NODE}
	if not found_floor:
		return {"error": "no %s node" % FLOOR_NODE}
	if not plane.normal.is_equal_approx(Vector3.UP):
		return {"error": "the Floor plane is not horizontal (normal %s); the height model only knows a flat floor" % plane.normal}
	out["floor_y"] = floor_origin_y + plane.d
	var gs: int = out["grid_size"]
	var heights: PackedFloat32Array = out["heights"]
	if heights.size() != (gs + 1) * (gs + 1):
		# The script resizes an empty array on _ready; the scene stores the
		# full one. Anything else is a scene the model cannot read.
		if heights.is_empty():
			heights.resize((gs + 1) * (gs + 1))
			out["heights"] = heights
		else:
			return {"error": "a %dx%d grid needs %d heights, the scene holds %d" % [gs, gs, (gs + 1) * (gs + 1), heights.size()]}
	return out


static func _node_props(state: SceneState, i: int) -> Dictionary:
	var props := {}
	for j in state.get_node_property_count(i):
		props[String(state.get_node_property_name(i, j))] = state.get_node_property_value(i, j)
	return props


# A float as the TOML carries it: DECIMALS places, always with a point so TOML
# reads a float and never an integer.
static func fmt(v: float) -> String:
	var s := String.num(v, DECIMALS)
	if s.find(".") < 0 and s.find("e") < 0:
		s += ".0"
	return s


# The value the server will read back from `fmt(v)`: the text parsed again,
# then narrowed to 32 bits. The hash covers these, not the scene's raw values,
# so both sides hash the same bits whatever the formatting dropped.
static func written(v: float) -> float:
	return float(fmt(v))


static func written_heights(heights: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(heights.size())
	for i in heights.size():
		out[i] = written(heights[i])
	return out


# The canonical bytes both sides hash: the grid size as a u32, then every
# float as its 32-bit IEEE-754 bits, little-endian, in this order.
static func canonical_bytes(grid_size: int, cell_size: float, origin: Vector3, floor_y: float, heights: PackedFloat32Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(24 + 4 * heights.size())
	b.encode_u32(0, grid_size)
	b.encode_float(4, cell_size)
	b.encode_float(8, origin.x)
	b.encode_float(12, origin.y)
	b.encode_float(16, origin.z)
	b.encode_float(20, floor_y)
	var off := 24
	for h in heights:
		b.encode_float(off, h)
		off += 4
	return b


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


# The hash the TOML written from `scene` carries (of the written values).
static func written_hash(scene: Dictionary) -> String:
	var origin: Vector3 = scene["origin"]
	var w_origin := Vector3(written(origin.x), written(origin.y), written(origin.z))
	return sha256_hex(canonical_bytes(
		scene["grid_size"], written(scene["cell_size"]), w_origin,
		written(scene["floor_y"]), written_heights(scene["heights"])))


static func render_toml(scene: Dictionary) -> String:
	var gs: int = scene["grid_size"]
	var origin: Vector3 = scene["origin"]
	var heights: PackedFloat32Array = scene["heights"]
	var lines: PackedStringArray = []
	lines.append("# Written by tools/export_terrain.gd (client repo) from scenes/world.tscn. Do not edit")
	lines.append("# by hand: the server refuses a file whose hash does not match its heights, and")
	lines.append("# tools/check_terrain_lockstep.gd fails when the scene and this file differ.")
	lines.append("# The client's TerrainMesh: grid_size x grid_size cells of cell_size metres, centred")
	lines.append("# on origin, (grid_size + 1)^2 heights row-major by z then x, each cell two triangles")
	lines.append("# split from (x1, z0) to (x0, z1); and the Floor plane at floor_y under everything.")
	lines.append("grid_size = %d" % gs)
	lines.append("cell_size = %s" % fmt(scene["cell_size"]))
	lines.append("origin = [%s, %s, %s]" % [fmt(origin.x), fmt(origin.y), fmt(origin.z)])
	lines.append("floor_y = %s" % fmt(scene["floor_y"]))
	lines.append("heights = [")
	var row := gs + 1
	for iz in row:
		var cells: PackedStringArray = []
		for ix in row:
			cells.append(fmt(heights[iz * row + ix]))
		lines.append("    " + ", ".join(cells) + ",")
	lines.append("]")
	lines.append("hash = \"%s\"" % written_hash(scene))
	return "\n".join(lines) + "\n"


# The ground the server computes at (x, z) for a terrain dictionary (the
# scene's, or one parsed from the TOML): the mesh's triangle plane where the
# point is inside the grid, floored by floor_y; the floor outside. The same
# rule as world/terrain.rs::ground.
static func ground_at(terrain: Dictionary, x: float, z: float) -> float:
	var gs: int = terrain["grid_size"]
	var cell: float = terrain["cell_size"]
	var origin: Vector3 = terrain["origin"]
	var floor_y: float = terrain["floor_y"]
	var heights: PackedFloat32Array = terrain["heights"]
	var half := gs * cell * 0.5
	var lx := x - origin.x + half
	var lz := z - origin.z + half
	var extent := gs * cell
	if not (lx >= 0.0 and lx <= extent and lz >= 0.0 and lz <= extent):
		return floor_y
	var fx := lx / cell
	var fz := lz / cell
	var cx := mini(int(floor(fx)), gs - 1)
	var cz := mini(int(floor(fz)), gs - 1)
	var u := fx - cx
	var v := fz - cz
	var row := gs + 1
	var h00 := heights[cz * row + cx]
	var h10 := heights[cz * row + cx + 1]
	var h01 := heights[(cz + 1) * row + cx]
	var h11 := heights[(cz + 1) * row + cx + 1]
	var h: float
	if u + v <= 1.0:
		h = h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		h = h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)
	return maxf(origin.y + h, floor_y)


# The slope of the ground at (x, z) for a terrain dictionary, as
# Vector2(dh/dx, dh/dz): the plane of the triangle there, flat where the ground
# is the floor (past the grid, or where the mesh is under the floor). The same
# rule as world/terrain.rs::gradient, on the same cell split as ground_at.
static func gradient_at(terrain: Dictionary, x: float, z: float) -> Vector2:
	var gs: int = terrain["grid_size"]
	var cell: float = terrain["cell_size"]
	var origin: Vector3 = terrain["origin"]
	var floor_y: float = terrain["floor_y"]
	var heights: PackedFloat32Array = terrain["heights"]
	var half := gs * cell * 0.5
	var lx := x - origin.x + half
	var lz := z - origin.z + half
	var extent := gs * cell
	if not (lx >= 0.0 and lx <= extent and lz >= 0.0 and lz <= extent):
		return Vector2.ZERO
	var fx := lx / cell
	var fz := lz / cell
	var cx := mini(int(floor(fx)), gs - 1)
	var cz := mini(int(floor(fz)), gs - 1)
	var u := fx - cx
	var v := fz - cz
	var row := gs + 1
	var h00 := heights[cz * row + cx]
	var h10 := heights[cz * row + cx + 1]
	var h01 := heights[(cz + 1) * row + cx]
	var h11 := heights[(cz + 1) * row + cx + 1]
	var h: float
	var d: Vector2
	if u + v <= 1.0:
		h = h00 + u * (h10 - h00) + v * (h01 - h00)
		d = Vector2(h10 - h00, h01 - h00)
	else:
		h = h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)
		d = Vector2(h11 - h01, h11 - h10)
	if origin.y + h < floor_y:
		return Vector2.ZERO
	return d / cell


# The angle of that slope, in degrees.
static func slope_deg_at(terrain: Dictionary, x: float, z: float) -> float:
	return rad_to_deg(atan(gradient_at(terrain, x, z).length()))
