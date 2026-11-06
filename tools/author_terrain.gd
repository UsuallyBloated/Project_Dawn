extends SceneTree

# Terrain author (the first hills, docs/design/first_hills_plan.md): composes
# the zone's relief from data/terrain_features.toml into the TerrainMesh's
# heights in scenes/world.tscn, after a report that fails on ground a camp or
# an NPC could not stand on.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/author_terrain.gd -- <server data dir>
#   godot --headless --path . -s tools/author_terrain.gd -- <server data dir> --report-only
#
# The server data dir is where zone_camps.toml and npcs.toml live (the report
# needs them); always pass it, since the default is the deploy checkout.
#
# The report: for every camp spawn and the four corners of its jitter square,
# and for every NPC, the steepest slope under it (FAIL past 55 degrees, the
# steepest floor a body stands on, fall.rs::FLOOR_MAX_ANGLE_DEG); the town
# square and the NPC row (FAIL if any ground there is not at 0); the steepest
# grade on the straight line from the town to each camp (WARN past 30
# degrees: a route that bends round a feature is fine); the rim's height round
# the plate's edge; and how much of the ground is floor, too steep to stand on
# (55 to 60 degrees: a body slides, a step up is still allowed) and face (past
# 60: a step up is refused). Nothing is written when the report fails.
#
# What it writes: the TerrainMesh node's grid_size, cell_size and heights, and
# the bodies of the three terrain subresources (the mesh, its material and the
# collider), which a TerrainMesh built from the new heights produces through
# Godot's own text saver. Every other byte of the scene is left alone. Then run
# tools/export_terrain.gd (with the path) and tools/check_terrain_lockstep.gd.
#
# Exit code 0 when written (or a clean report with --report-only), 1 when the
# report fails, 2 when a file cannot be read, 3 when the scene cannot be
# written as expected.

const FEATURES_PATH := "res://data/terrain_features.toml"
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const TERRAIN_SCRIPT := "res://scripts/terrain_mesh.gd"
const DEFAULT_SERVER_DATA := "F:/Projects/server/crates/projectdawn-server/data"
const Exporter := preload("res://tools/export_terrain.gd")

# The steepest floor a body (a player's or a mob's) stands on, fall.rs.
const FLOOR_MAX_ANGLE_DEG := 55.0
# The steepest step up the server allows, terrain.rs::SLOPE_LIMIT_DEG.
const SLOPE_LIMIT_DEG := 60.0
# A route from the town steeper than this is worth a look.
const ROUTE_WARN_DEG := 30.0
# The town: the safe square round the origin and the NPC row, which stay flat.
const TOWN_RADIUS := 10.0
const NPC_ROW_Z := 5.0
const NPC_ROW_X0 := -5.0
const NPC_ROW_X1 := 11.0
const DEFAULT_CAMP_RADIUS := 3.0
# A height closer to 0 than this is 0 (float noise in the composition).
const FLAT_EPSILON := 0.0001
# Every height is rounded to this. Godot's Mesh.create_trimesh_shape snaps each
# vertex to 0.0001 m as it builds the collider, so the client walks on rounded
# heights whatever the mesh holds; rounding first makes the snap change nothing,
# and the server then samples exactly the triangles the client collides with.
const HEIGHT_STEP := 0.0001

# The subresources the scene keeps the built terrain in.
const MESH_SECTION := "[sub_resource type=\"ArrayMesh\" id=\"ArrayMesh_jka67\"]"
const MATERIAL_SECTION := "[sub_resource type=\"StandardMaterial3D\" id=\"StandardMaterial3D_r3fl7\"]"
const MATERIAL_ID := "StandardMaterial3D_r3fl7"
const COLLIDER_SECTION := "[sub_resource type=\"ConcavePolygonShape3D\" id=\"ConcavePolygonShape3D_i5arm\"]"
const TERRAIN_NODE_HEADER := "[node name=\"TerrainMesh\" type=\"Node3D\" parent=\".\"]"
const SCRATCH_MESH := "user://author_terrain_mesh.tres"
const SCRATCH_SHAPE := "user://author_terrain_shape.tres"


func _initialize() -> void:
	var data_dir := DEFAULT_SERVER_DATA
	var report_only := false
	for a in OS.get_cmdline_user_args():
		if a == "--report-only":
			report_only = true
		else:
			data_dir = a
	quit(_run(data_dir, report_only))


func _run(data_dir: String, report_only: bool) -> int:
	var features := parse_features(FEATURES_PATH)
	if features.has("error"):
		printerr("Cannot read %s: %s" % [FEATURES_PATH, features["error"]])
		return 2
	var scene := Exporter.read_scene(WORLD_SCENE_PATH)
	if scene.has("error"):
		printerr("Cannot read the terrain from %s: %s" % [WORLD_SCENE_PATH, scene["error"]])
		return 2
	var camps := parse_camps(data_dir.path_join("zone_camps.toml"))
	var npcs := parse_npcs(data_dir.path_join("npcs.toml"))
	if camps.is_empty() or npcs.is_empty():
		printerr("No camps or NPCs read from %s (pass the server's data dir after --)." % data_dir)
		return 2

	var terrain := {
		"grid_size": int(features["grid_size"]),
		"cell_size": float(features["cell_size"]),
		"origin": scene["origin"],
		"floor_y": scene["floor_y"],
	}
	terrain["heights"] = compose(features, terrain)

	var fails := report(terrain, camps, npcs)
	if fails > 0:
		print("\n%d FAIL(s): nothing written. Move or soften the feature, never the camp." % fails)
		return 1
	if report_only:
		print("\nReport clean (--report-only: nothing written).")
		return 0
	return _write_scene(terrain)


# --- The features file ---------------------------------------------------

# The shape data/terrain_features.toml uses: top-level `key = value` lines,
# `[[name]]` tables (each appended to an array under that name), values that
# are numbers, quoted strings, arrays of numbers or `{ k = v, ... }` tables of
# numbers, and `#` comments. Not a general TOML reader.
static func parse_features(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "cannot open (error %d)" % FileAccess.get_open_error()}
	var out := {}
	var current: Dictionary = out
	var line_no := 0
	while not f.eof_reached():
		line_no += 1
		var line := _strip_comment(f.get_line()).strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("[[") and line.ends_with("]]"):
			var table_name := line.substr(2, line.length() - 4).strip_edges()
			if not out.has(table_name):
				out[table_name] = []
			current = {}
			out[table_name].append(current)
			continue
		var eq := line.find("=")
		if eq < 0:
			return {"error": "line %d is not key = value: %s" % [line_no, line]}
		var key := line.substr(0, eq).strip_edges()
		var value = _parse_value(line.substr(eq + 1).strip_edges())
		if value == null:
			return {"error": "line %d has a value this reader does not know: %s" % [line_no, line]}
		current[key] = value
	if not (out.has("grid_size") and out.has("cell_size")):
		return {"error": "grid_size and cell_size are required"}
	return out


static func _strip_comment(line: String) -> String:
	var in_string := false
	for i in line.length():
		var c := line[i]
		if c == "\"":
			in_string = not in_string
		elif c == "#" and not in_string:
			return line.substr(0, i)
	return line


static func _parse_value(s: String) -> Variant:
	if s.begins_with("\"") and s.ends_with("\"") and s.length() >= 2:
		return s.substr(1, s.length() - 2)
	if s.begins_with("[") and s.ends_with("]"):
		var arr: Array = []
		for part in s.substr(1, s.length() - 2).split(","):
			var p := part.strip_edges()
			if p.is_empty():
				continue
			if not p.is_valid_float():
				return null
			arr.append(float(p))
		return arr
	if s.begins_with("{") and s.ends_with("}"):
		var table := {}
		for part in s.substr(1, s.length() - 2).split(","):
			var p := part.strip_edges()
			if p.is_empty():
				continue
			var eq := p.find("=")
			if eq < 0:
				return null
			var v := p.substr(eq + 1).strip_edges()
			if not v.is_valid_float():
				return null
			table[p.substr(0, eq).strip_edges()] = float(v)
		return table
	if s.is_valid_float():
		return float(s)
	return null


# --- The composition -----------------------------------------------------

static func smoothstep01(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# The distance from p to the segment a..b (its ends rounded).
static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 == 0.0 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# The heights, row-major by z then x, as the TerrainMesh stores them.
static func compose(features: Dictionary, terrain: Dictionary) -> PackedFloat32Array:
	var gs: int = terrain["grid_size"]
	var cell: float = terrain["cell_size"]
	var origin: Vector3 = terrain["origin"]
	var half := gs * cell * 0.5
	var heights := PackedFloat32Array()
	heights.resize((gs + 1) * (gs + 1))
	for iz in gs + 1:
		for ix in gs + 1:
			var p := Vector2(origin.x - half + ix * cell, origin.z - half + iz * cell)
			heights[iz * (gs + 1) + ix] = snappedf(height_at(features, p, half), HEIGHT_STEP)
	return heights


static func height_at(features: Dictionary, p: Vector2, half: float) -> float:
	var h := 0.0
	for f in features.get("hill", []):
		var d := p.distance_to(_v2(f["center"]))
		if d < f["radius"]:
			h += float(f["height"]) * smoothstep01(1.0 - d / f["radius"])
	for f in features.get("ridge", []):
		var d := segment_distance(p, _v2(f["from"]), _v2(f["to"]))
		if d < f["half_width"]:
			h += float(f["height"]) * smoothstep01(1.0 - d / f["half_width"])
	for f in features.get("plateau", []):
		h = maxf(h, _plateau_height(f, p))
	for f in features.get("cut", []):
		if segment_distance(p, _v2(f["from"]), _v2(f["to"])) <= f["half_width"]:
			h = minf(h, f["floor"])
	for f in features.get("rim", []):
		var r := maxf(absf(p.x), absf(p.y))
		if r > f["start_at"]:
			h = maxf(h, float(f["height"]) * (r - f["start_at"]) / (half - f["start_at"]))
	return maxf(h, 0.0)


# A plateau's height at p: its top inside the rect; a ramp falling to 0 over
# its width outside an edge, measured straight out from that edge, within the
# edge's span (a corner outside two edges gets nothing); 0 elsewhere.
static func _plateau_height(f: Dictionary, p: Vector2) -> float:
	var r: Array = f["rect"]
	var x0: float = r[0]
	var z0: float = r[1]
	var x1: float = r[2]
	var z1: float = r[3]
	var top: float = f["height"]
	var ramps: Dictionary = f.get("ramps", {})
	var inside_x := p.x >= x0 and p.x <= x1
	var inside_z := p.y >= z0 and p.y <= z1
	if inside_x and inside_z:
		return top
	var best := 0.0
	if inside_z:
		best = maxf(best, _ramp(top, ramps.get("west", 0.0), x0 - p.x))
		best = maxf(best, _ramp(top, ramps.get("east", 0.0), p.x - x1))
	if inside_x:
		best = maxf(best, _ramp(top, ramps.get("south", 0.0), z0 - p.y))
		best = maxf(best, _ramp(top, ramps.get("north", 0.0), p.y - z1))
	return best


static func _ramp(top: float, width: float, dist: float) -> float:
	if width <= 0.0 or dist <= 0.0 or dist >= width:
		return 0.0
	return top * (1.0 - dist / width)


# --- The server's camps and NPCs ------------------------------------------

# [{name, pos: Vector2, radius}] for every spawn in zone_camps.toml.
static func parse_camps(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text().replace("\r\n", "\n")
	var default_radius := DEFAULT_CAMP_RADIUS
	var dr := RegEx.create_from_string("(?m)^default_radius\\s*=\\s*(-?[\\d.]+)")
	var m := dr.search(text)
	if m:
		default_radius = float(m.get_string(1))
	var desc_re := RegEx.create_from_string("desc\\s*=\\s*\"([^\"]*)\"")
	var radius_re := RegEx.create_from_string("(?m)^radius\\s*=\\s*(-?[\\d.]+)")
	var triple_re := RegEx.create_from_string("\\[\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*\\]")
	var out: Array = []
	var blocks := text.split("[[camp]]")
	for bi in range(1, blocks.size()):
		var block: String = blocks[bi]
		var dm := desc_re.search(block)
		var name := dm.get_string(1).get_slice(" \u2014 ", 0) if dm else "camp %d" % bi
		var rm := radius_re.search(block)
		var radius := float(rm.get_string(1)) if rm else default_radius
		var start := block.find("spawns = [")
		var end := block.find("\n]", start)
		if start < 0 or end < 0:
			continue
		for t in triple_re.search_all(block.substr(start + 9, end - start - 8)):
			out.append({"name": name, "pos": Vector2(float(t.get_string(1)), float(t.get_string(3))), "radius": radius})
	return out


# [{name, pos: Vector2}] for every NPC in npcs.toml.
static func parse_npcs(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text().replace("\r\n", "\n")
	var name_re := RegEx.create_from_string("(?m)^name\\s*=\\s*\"([^\"]*)\"")
	var pos_re := RegEx.create_from_string("(?m)^pos\\s*=\\s*\\[\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*\\]")
	var out: Array = []
	var blocks := text.split("[[npc]]")
	for bi in range(1, blocks.size()):
		var nm := name_re.search(blocks[bi])
		var pm := pos_re.search(blocks[bi])
		if nm and pm:
			out.append({"name": nm.get_string(1), "pos": Vector2(float(pm.get_string(1)), float(pm.get_string(3)))})
	return out


# --- The report ----------------------------------------------------------

static func _steepest(terrain: Dictionary, points: Array) -> float:
	var worst := 0.0
	for p in points:
		worst = maxf(worst, Exporter.slope_deg_at(terrain, p.x, p.y))
	return worst


static func _jitter_square(p: Vector2, r: float) -> Array:
	return [p, p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(-r, r), p + Vector2(r, r)]


# Prints the report; returns the number of FAILs.
static func report(terrain: Dictionary, camps: Array, npcs: Array) -> int:
	var fails := 0
	var gs: int = terrain["grid_size"]
	var cell: float = terrain["cell_size"]
	var origin: Vector3 = terrain["origin"]
	var half := gs * cell * 0.5
	print("Terrain: %dx%d cells of %s m, %d heights." % [gs, gs, str(cell), (gs + 1) * (gs + 1)])

	print("\nCamp spawns (the spawn and its jitter corners; FAIL past %d degrees):" % int(FLOOR_MAX_ANGLE_DEG))
	for c in camps:
		var p: Vector2 = c["pos"]
		var steep := _steepest(terrain, _jitter_square(p, c["radius"]))
		var bad := steep > FLOOR_MAX_ANGLE_DEG
		if bad:
			fails += 1
		print("  %-4s %-28s (%6.1f, %6.1f)  ground %5.1f m, steepest %4.1f deg" % [
			"FAIL" if bad else "ok", c["name"], p.x, p.y, Exporter.ground_at(terrain, p.x, p.y), steep])

	print("\nNPCs:")
	for n in npcs:
		var p: Vector2 = n["pos"]
		var steep := Exporter.slope_deg_at(terrain, p.x, p.y)
		var h := Exporter.ground_at(terrain, p.x, p.y)
		var bad := steep > FLOOR_MAX_ANGLE_DEG or absf(h - float(terrain["floor_y"])) > FLAT_EPSILON
		if bad:
			fails += 1
		print("  %-4s %-28s (%6.1f, %6.1f)  ground %5.1f m, steepest %4.1f deg" % ["FAIL" if bad else "ok", n["name"], p.x, p.y, h, steep])

	# The town square and the NPC row, every metre: all at the floor.
	var town_bad := 0
	var town_points := 0
	for ix in range(-int(TOWN_RADIUS), int(TOWN_RADIUS) + 1):
		for iz in range(-int(TOWN_RADIUS), int(TOWN_RADIUS) + 1):
			var p := Vector2(origin.x + ix, origin.z + iz)
			if Vector2(ix, iz).length() > TOWN_RADIUS:
				continue
			town_points += 1
			if not _flat_at(terrain, p):
				town_bad += 1
	for ix in range(int(NPC_ROW_X0), int(NPC_ROW_X1) + 1):
		town_points += 1
		if not _flat_at(terrain, Vector2(ix, NPC_ROW_Z)):
			town_bad += 1
	if town_bad > 0:
		fails += 1
	print("\n  %-4s the town square (radius %d m) and the NPC row: %d of %d points off the floor" % [
		"FAIL" if town_bad > 0 else "ok", int(TOWN_RADIUS), town_bad, town_points])

	print("\nRoutes from the town, the straight line to each camp's first spawn, every metre (WARN past %d degrees):" % int(ROUTE_WARN_DEG))
	var seen := {}
	for c in camps:
		if seen.has(c["name"]):
			continue
		seen[c["name"]] = true
		var target: Vector2 = c["pos"]
		var start := Vector2(origin.x, origin.z)
		var steps := maxi(1, int(start.distance_to(target)))
		var worst := 0.0
		for i in steps + 1:
			var q := start.lerp(target, float(i) / steps)
			worst = maxf(worst, Exporter.slope_deg_at(terrain, q.x, q.y))
		print("  %-4s %-28s steepest %4.1f deg" % ["WARN" if worst > ROUTE_WARN_DEG else "", c["name"], worst])

	# The rim: the ground round the plate's edge, every metre.
	var rim_min := INF
	var edge := half - 0.001
	for i in range(int(-half), int(half) + 1):
		for q in [Vector2(i, -edge), Vector2(i, edge), Vector2(-edge, i), Vector2(edge, i)]:
			rim_min = minf(rim_min, Exporter.ground_at(terrain, origin.x + q.x, origin.z + q.y))
	print("\nThe rim: the lowest ground round the plate's edge is %.1f m (north %.1f, south %.1f, east %.1f, west %.1f at the middle)." % [
		rim_min,
		Exporter.ground_at(terrain, origin.x, origin.z + edge), Exporter.ground_at(terrain, origin.x, origin.z - edge),
		Exporter.ground_at(terrain, origin.x + edge, origin.z), Exporter.ground_at(terrain, origin.x - edge, origin.z)])

	# Every triangle, by class: the centroid's slope is the triangle's.
	var floors := 0
	var slides := 0
	var faces := 0
	var slide_at: Array = []
	for iz in gs:
		for ix in gs:
			var x0 := origin.x - half + ix * cell
			var z0 := origin.z - half + iz * cell
			for centroid in [Vector2(x0 + cell / 3.0, z0 + cell / 3.0), Vector2(x0 + cell * 2.0 / 3.0, z0 + cell * 2.0 / 3.0)]:
				var a := Exporter.slope_deg_at(terrain, centroid.x, centroid.y)
				if a <= FLOOR_MAX_ANGLE_DEG:
					floors += 1
				elif a <= SLOPE_LIMIT_DEG:
					slides += 1
					if slide_at.size() < 6:
						slide_at.append("(%d, %d) %.1f deg" % [int(centroid.x), int(centroid.y), a])
				else:
					faces += 1
	print("\nTriangles: %d floor, %d too steep to stand on but climbable (%d to %d deg), %d face." % [
		floors, slides, int(FLOOR_MAX_ANGLE_DEG), int(SLOPE_LIMIT_DEG), faces])
	if slides > 0:
		print("  WARN a modified client can step up a %d to %d degree slope the honest body slides off: %s%s" % [
			int(FLOOR_MAX_ANGLE_DEG), int(SLOPE_LIMIT_DEG), ", ".join(slide_at), " ..." if slides > slide_at.size() else ""])
	return fails


static func _flat_at(terrain: Dictionary, p: Vector2) -> bool:
	return absf(Exporter.ground_at(terrain, p.x, p.y) - float(terrain["floor_y"])) <= FLAT_EPSILON \
		and Exporter.slope_deg_at(terrain, p.x, p.y) <= FLAT_EPSILON


# --- Writing the scene ---------------------------------------------------

func _write_scene(terrain: Dictionary) -> int:
	var scene_file := ProjectSettings.globalize_path(WORLD_SCENE_PATH)
	var f := FileAccess.open(scene_file, FileAccess.READ)
	if f == null:
		printerr("Cannot open %s." % scene_file)
		return 2
	var text := f.get_as_text()
	f.close()

	# A TerrainMesh built from the new heights, outside any tree: the mesh,
	# its material and the collider exactly as the node makes them at runtime.
	var node: Node3D = load(TERRAIN_SCRIPT).new()
	node.grid_size = terrain["grid_size"]
	node.cell_size = terrain["cell_size"]
	node.heights = terrain["heights"]
	node._ensure_children()
	node._rebuild()
	var mesh: Mesh = (node.get_node("TerrainVisual") as MeshInstance3D).mesh
	var shape: Shape3D = (node.get_node("TerrainBody/TerrainCol") as CollisionShape3D).shape
	if ResourceSaver.save(mesh, SCRATCH_MESH) != OK or ResourceSaver.save(shape, SCRATCH_SHAPE) != OK:
		printerr("Cannot save the built mesh and collider to user://.")
		node.free()
		return 3
	node.free()
	var mesh_text := FileAccess.get_file_as_string(SCRATCH_MESH)
	var shape_text := FileAccess.get_file_as_string(SCRATCH_SHAPE)

	# The saved mesh holds its material as its one sub_resource, then the mesh.
	var sub_ids := _section_headers(mesh_text, "[sub_resource ")
	if sub_ids.size() != 1:
		printerr("The saved mesh has %d sub-resources, expected its material alone." % sub_ids.size())
		return 3
	var saved_material_header: String = sub_ids[0]
	var saved_material_id := saved_material_header.get_slice("id=\"", 1).get_slice("\"", 0)
	var material_body := _section_body(mesh_text, saved_material_header)
	var mesh_body := _section_body(mesh_text, "[resource]").replace(
		"SubResource(\"%s\")" % saved_material_id, "SubResource(\"%s\")" % MATERIAL_ID)
	var shape_body := _section_body(shape_text, "[resource]")
	if material_body.is_empty() or mesh_body.is_empty() or shape_body.is_empty():
		printerr("Could not read the saved mesh, material or collider.")
		return 3

	var out := text
	for pair in [[MATERIAL_SECTION, material_body], [MESH_SECTION, mesh_body], [COLLIDER_SECTION, shape_body]]:
		var replaced := _replace_section_body(out, pair[0], pair[1])
		if replaced.is_empty():
			printerr("The scene has no section %s." % pair[0])
			return 3
		out = replaced
	out = _replace_node_properties(out, terrain)
	if out.is_empty():
		printerr("The scene's TerrainMesh node is not in the shape this tool writes.")
		return 3

	var w := FileAccess.open(scene_file, FileAccess.WRITE)
	if w == null:
		printerr("Cannot write %s." % scene_file)
		return 3
	w.store_string(out)
	w.close()

	# Read it back the way the exporter does.
	var reread: PackedScene = ResourceLoader.load(WORLD_SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if reread == null:
		printerr("The written scene does not load.")
		return 3
	print("\nWrote %d heights (%dx%d cells of %s m), the mesh and the collider into %s." % [
		(terrain["heights"] as PackedFloat32Array).size(), terrain["grid_size"], terrain["grid_size"],
		str(terrain["cell_size"]), WORLD_SCENE_PATH])
	print("Next: tools/export_terrain.gd -- <server data dir>/terrain.toml, then tools/check_terrain_lockstep.gd -- <server data dir>.")
	return 0


# Every section header line in a text resource that begins with `prefix`.
static func _section_headers(text: String, prefix: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		if line.begins_with(prefix):
			out.append(line)
	return out


# The lines of a section after its header, up to the blank line before the
# next section (or the end), without the trailing blank lines.
static func _section_body(text: String, header: String) -> String:
	var at := text.find(header + "\n")
	if at < 0:
		return ""
	var start := at + header.length() + 1
	var next := text.find("\n[", start)
	var body := text.substr(start, (next if next >= 0 else text.length()) - start)
	return body.strip_edges(false, true)


# `text` with the body of the section under `header` replaced, or "" if the
# section is not there.
static func _replace_section_body(text: String, header: String, body: String) -> String:
	var at := text.find(header + "\n")
	if at < 0:
		return ""
	var start := at + header.length() + 1
	var next := text.find("\n\n[", start)
	if next < 0:
		return ""
	return text.substr(0, start) + body + text.substr(next)


# `text` with the TerrainMesh node's grid_size, cell_size and heights lines
# written (the scene keeps an exported property only when it differs from the
# script's default, and the exporter falls back to the defaults, so all three
# are always written), or "" when the node block is not where it should be.
static func _replace_node_properties(text: String, terrain: Dictionary) -> String:
	var at := text.find(TERRAIN_NODE_HEADER + "\n")
	if at < 0:
		return ""
	var start := at + TERRAIN_NODE_HEADER.length() + 1
	var next := text.find("\n\n[", start)
	if next < 0:
		return ""
	var kept: PackedStringArray = []
	for line in text.substr(start, next - start).split("\n"):
		if line.begins_with("grid_size = ") or line.begins_with("cell_size = ") or line.begins_with("heights = "):
			continue
		kept.append(line)
	if kept.is_empty() or not kept[0].begins_with("script = "):
		return ""
	var props: PackedStringArray = [kept[0]]
	props.append("grid_size = %s" % var_to_str(int(terrain["grid_size"])))
	props.append("cell_size = %s" % var_to_str(float(terrain["cell_size"])))
	props.append("heights = %s" % var_to_str(terrain["heights"]))
	for i in range(1, kept.size()):
		props.append(kept[i])
	return text.substr(0, start) + "\n".join(props) + text.substr(next)
