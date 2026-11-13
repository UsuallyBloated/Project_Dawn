extends SceneTree

# Terrain author: composes the zone's relief from data/terrain_features.toml
# into the TerrainMesh's heights in scenes/world.tscn, after a report that
# fails on ground a camp or an NPC could not stand on, and paints the ground
# texture (roads, farms, forest floor) from data/zone_layout.gd.
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
# (FAIL if any ground inside town_flat_radius is not at 0); the steepest grade
# on the straight line from the town to each camp (WARN past 30 degrees: a
# route that bends round a feature is fine); the rim's height round the
# plate's edge; how much of the ground is floor, too steep to stand on (55 to
# 60 degrees: a body slides, a step up is still allowed) and face (past 60: a
# step up is refused); how far each set piece in data/zone_layout.gd stands
# from the camp it dresses (WARN past 80 m); and who can walk where: a walk
# from the town must reach every camp spawn, and must reach neither the
# plate's outer edge nor any point the features file lists as unreachable.
# Nothing is written when the report fails.
#
# What it writes: the TerrainMesh node's grid_size, cell_size and heights
# (the node builds its meshes and colliders from them at load), and the paint
# texture at PAINT_PATH. Every other byte of the scene is left alone. Then run
# `godot --headless --path . --import` (the paint is an imported texture),
# tools/export_terrain.gd (with the path) and tools/check_terrain_lockstep.gd.
#
# Exit code 0 when written (or a clean report with --report-only), 1 when the
# report fails, 2 when a file cannot be read, 3 when the scene cannot be
# written as expected.

const FEATURES_PATH := "res://data/terrain_features.toml"
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const PAINT_PATH := "res://assets/textures/environment/zone_paint.png"
const DEFAULT_SERVER_DATA := "F:/Projects/server/crates/projectdawn-server/data"
const Exporter := preload("res://tools/export_terrain.gd")
const Layout := preload("res://data/zone_layout.gd")

# The steepest floor a body (a player's or a mob's) stands on, fall.rs.
const FLOOR_MAX_ANGLE_DEG := 55.0
# The steepest step up the server allows, terrain.rs::SLOPE_LIMIT_DEG.
const SLOPE_LIMIT_DEG := 60.0
# A route from the town steeper than this is worth a look.
const ROUTE_WARN_DEG := 30.0
# A set piece further than this from its camp's nearest spawn has drifted.
const SITE_WARN_M := 80.0
const DEFAULT_TOWN_FLAT_RADIUS := 10.0
const DEFAULT_CAMP_RADIUS := 3.0
# A height closer to 0 than this is 0 (float noise in the composition).
const FLAT_EPSILON := 0.0001
# Every height is rounded to this, so the text the scene and the server's file
# carry is short and both sides read back the same 32-bit number.
const HEIGHT_STEP := 0.0001
# The paint texture: this many pixels a side over the whole plate.
const PAINT_SIZE := 2048

const TERRAIN_NODE_HEADER := "[node name=\"TerrainMesh\" type=\"Node3D\" parent=\".\"]"


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

	var fails := report(terrain, features, camps, npcs)
	if fails > 0:
		print("\n%d FAIL(s): nothing written. Move or soften the feature, never the camp." % fails)
		return 1
	if report_only:
		print("\nReport clean (--report-only: nothing written).")
		return 0
	var paint_code := _write_paint(terrain)
	if paint_code != 0:
		return paint_code
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
	var noises := make_noises(features)
	var heights := PackedFloat32Array()
	heights.resize((gs + 1) * (gs + 1))
	for iz in gs + 1:
		for ix in gs + 1:
			var p := Vector2(origin.x - half + ix * cell, origin.z - half + iz * cell)
			heights[iz * (gs + 1) + ix] = snappedf(height_at(features, noises, p, half), HEIGHT_STEP)
	return heights


# A noise source of the given wavelength, whose values n01() reads as 0 to 1.
static func _noise(seed_value: int, wavelength: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0 / maxf(wavelength, 1.0)
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


static func n01(noise: FastNoiseLite, x: float, y: float) -> float:
	return clampf(noise.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)


# The noise sources the composition uses: one per [[noise]] entry, one for the
# ridges' crests and one for the rim's peaks.
static func make_noises(features: Dictionary) -> Dictionary:
	var layers: Array = []
	for f in features.get("noise", []):
		layers.append(_noise(int(f.get("seed", 1)), float(f["wavelength"]), 2))
	var peak_wavelength := 170.0
	for f in features.get("rim", []):
		peak_wavelength = float(f.get("peak_wavelength", peak_wavelength))
	return {"layers": layers, "crest": _noise(101, 95.0, 2), "rim": _noise(202, peak_wavelength, 2)}


static func height_at(features: Dictionary, noises: Dictionary, p: Vector2, half: float) -> float:
	var h := 0.0
	for f in features.get("hill", []):
		var d := p.distance_to(_v2(f["center"]))
		var radius: float = f["radius"]
		if d < radius:
			var flat: float = f.get("flat_radius", 0.0)
			var t := 1.0 if d <= flat else 1.0 - (d - flat) / (radius - flat)
			h += float(f["height"]) * smoothstep01(t)
	for f in features.get("ring", []):
		var t := 1.0 - absf(p.distance_to(_v2(f["center"])) - float(f["radius"])) / float(f["width"])
		if t > 0.0:
			h += float(f["height"]) * smoothstep01(t)
	for f in features.get("ridge", []):
		h += _ridge_height(f, noises, p)
	var layers: Array = noises["layers"]
	var noise_features: Array = features.get("noise", [])
	for i in noise_features.size():
		var f: Dictionary = noise_features[i]
		var mask := 1.0
		if f.has("full_radius"):
			var calm: float = f.get("calm_radius", 0.0)
			mask *= smoothstep01(clampf((p.length() - calm) / (float(f["full_radius"]) - calm), 0.0, 1.0))
		if f.has("edge_to"):
			var from: float = f.get("edge_from", 0.0)
			mask *= smoothstep01(clampf((maxf(absf(p.x), absf(p.y)) - from) / (float(f["edge_to"]) - from), 0.0, 1.0))
		if mask > 0.0:
			h += float(f["amplitude"]) * mask * n01(layers[i], p.x, p.y)
	for f in features.get("plateau", []):
		h = maxf(h, _plateau_height(f, p))
	for f in features.get("cut", []):
		var d := segment_distance(p, _v2(f["from"]), _v2(f["to"]))
		var half_width: float = f["half_width"]
		var wall: float = f.get("wall_slope", 0.0)
		if d <= half_width:
			h = minf(h, f["floor"])
		elif wall > 0.0:
			h = minf(h, float(f["floor"]) + (d - half_width) * wall)
	for f in features.get("rim", []):
		var r := maxf(absf(p.x), absf(p.y))
		var start: float = f["start_at"]
		if r > start:
			# The peaks vary along the edge only, never across it: a peak that
			# changed with r would flatten the face somewhere.
			var on_x_side := absf(p.x) >= absf(p.y)
			var along := p.y if on_x_side else p.x
			var side := 0.0 if on_x_side else 5000.0
			if (p.x if on_x_side else p.y) < 0.0:
				side += 10000.0
			var peaks := 1.0 + float(f.get("peak_noise", 0.0)) * n01(noises["rim"], along, side)
			h += float(f["height"]) * peaks * (r - start) / (half - start)
	return maxf(h, 0.0)


# A ridge's height at p: its height inside, falling in a straight line to 0
# over face_width at its edge (the face), plus on its flat top a crown that
# swells towards the middle and noise that breaks the skyline. The top's extras
# are 0 at the lip, so the faces stay the slope face_width makes them.
static func _ridge_height(f: Dictionary, noises: Dictionary, p: Vector2) -> float:
	var d := segment_distance(p, _v2(f["from"]), _v2(f["to"]))
	var half_width: float = f["half_width"]
	if d >= half_width:
		return 0.0
	var height: float = f["height"]
	var face: float = f.get("face_width", 0.0)
	if face <= 0.0:
		return height * smoothstep01(1.0 - d / half_width)
	var top := half_width - face
	if d > top:
		return height * (half_width - d) / face
	var inside := smoothstep01(1.0 - d / top)
	return height + inside * (float(f.get("crown", 0.0))
		+ float(f.get("crest_noise", 0.0)) * n01(noises["crest"], p.x, p.y))


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
static func report(terrain: Dictionary, features: Dictionary, camps: Array, npcs: Array) -> int:
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
		print("  %-4s %-28s (%7.1f, %7.1f)  ground %6.1f m, steepest %4.1f deg" % [
			"FAIL" if bad else "ok", c["name"], p.x, p.y, Exporter.ground_at(terrain, p.x, p.y), steep])

	print("\nNPCs:")
	for n in npcs:
		var p: Vector2 = n["pos"]
		var steep := Exporter.slope_deg_at(terrain, p.x, p.y)
		var h := Exporter.ground_at(terrain, p.x, p.y)
		var bad := steep > FLOOR_MAX_ANGLE_DEG or absf(h - float(terrain["floor_y"])) > FLAT_EPSILON
		if bad:
			fails += 1
		print("  %-4s %-28s (%7.1f, %7.1f)  ground %6.1f m, steepest %4.1f deg" % ["FAIL" if bad else "ok", n["name"], p.x, p.y, h, steep])

	# The town, every other metre: all at the floor.
	var town_radius := int(features.get("town_flat_radius", DEFAULT_TOWN_FLAT_RADIUS))
	var town_bad := 0
	var town_points := 0
	for ix in range(-town_radius, town_radius + 1, 2):
		for iz in range(-town_radius, town_radius + 1, 2):
			if Vector2(ix, iz).length() > town_radius:
				continue
			town_points += 1
			if not _flat_at(terrain, Vector2(origin.x + ix, origin.z + iz)):
				town_bad += 1
	if town_bad > 0:
		fails += 1
	print("\n  %-4s the town (radius %d m): %d of %d points off the floor" % [
		"FAIL" if town_bad > 0 else "ok", town_radius, town_bad, town_points])

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
		print("  %-4s %-28s %5d m, steepest %4.1f deg" % ["WARN" if worst > ROUTE_WARN_DEG else "", c["name"], steps, worst])

	# The rim: the ground round the plate's edge, every metre.
	var rim_min := INF
	var rim_max := 0.0
	var edge := half - 0.001
	for i in range(int(-half), int(half) + 1):
		for q in [Vector2(i, -edge), Vector2(i, edge), Vector2(-edge, i), Vector2(edge, i)]:
			var g := Exporter.ground_at(terrain, origin.x + q.x, origin.z + q.y)
			rim_min = minf(rim_min, g)
			rim_max = maxf(rim_max, g)
	print("\nThe rim: the ground round the plate's edge runs from %.1f m to %.1f m." % [rim_min, rim_max])

	fails += _report_sites(camps)
	fails += _report_walk(terrain, features, camps)
	return fails


# Each set piece in the layout against the camp of the same name: a set piece
# with no camp, or one that has drifted from its camp's spawns, is a WARN (the
# dressing is scenery, so never a FAIL).
static func _report_sites(camps: Array) -> int:
	print("\nSet pieces (data/zone_layout.gd SITES) against their camps (WARN past %d m):" % int(SITE_WARN_M))
	for site_name in Layout.SITES:
		var at: Vector2 = Layout.SITES[site_name]
		var nearest := INF
		for c in camps:
			var camp_name: String = c["name"]
			if camp_name == site_name or camp_name.begins_with(site_name) or site_name.begins_with(camp_name):
				nearest = minf(nearest, at.distance_to(c["pos"]))
		if nearest == INF:
			print("  WARN %-24s no camp of that name in zone_camps.toml" % site_name)
		else:
			print("  %-4s %-24s %5.1f m from its nearest spawn" % ["WARN" if nearest > SITE_WARN_M else "ok", site_name, nearest])
	return 0


# Who can walk where. Every triangle is a place; a walker moves between two
# that share a corner. The server's rule (terrain.rs::slope_ok) refuses a step
# that rises onto ground past SLOPE_LIMIT_DEG, so a face is entered only from
# above, and from a face (which no body stands on, fall.rs) the only way is
# down. Starting in the town: every camp spawn must be reached, and neither
# the plate's outer row of cells nor any [[unreachable]] point may be.
static func _report_walk(terrain: Dictionary, features: Dictionary, camps: Array) -> int:
	var gs: int = terrain["grid_size"]
	var cell: float = terrain["cell_size"]
	var origin: Vector3 = terrain["origin"]
	var heights: PackedFloat32Array = terrain["heights"]
	var half := gs * cell * 0.5
	var row := gs + 1
	var limit := tan(deg_to_rad(SLOPE_LIMIT_DEG))
	var floor_limit := tan(deg_to_rad(FLOOR_MAX_ANGLE_DEG))
	var tri_count := gs * gs * 2
	var is_face := PackedByteArray()
	is_face.resize(tri_count)
	var mid := PackedFloat32Array()
	mid.resize(tri_count)
	var floors := 0
	var slides := 0
	var faces := 0
	for cz in gs:
		for cx in gs:
			var i := cz * row + cx
			var h00 := heights[i]
			var h10 := heights[i + 1]
			var h01 := heights[i + row]
			var h11 := heights[i + row + 1]
			var t := (cz * gs + cx) * 2
			var lower := Vector2(h10 - h00, h01 - h00).length() / cell
			var upper := Vector2(h11 - h01, h11 - h10).length() / cell
			mid[t] = (h00 + h10 + h01) / 3.0
			mid[t + 1] = (h10 + h11 + h01) / 3.0
			for pair in [[t, lower], [t + 1, upper]]:
				var slope: float = pair[1]
				if slope > limit:
					is_face[pair[0]] = 1
					faces += 1
				elif slope > floor_limit:
					slides += 1
				else:
					floors += 1
	print("\nTriangles: %d floor, %d too steep to stand on but climbable (%d to %d deg), %d face." % [
		floors, slides, int(FLOOR_MAX_ANGLE_DEG), int(SLOPE_LIMIT_DEG), faces])

	# The triangles that share a corner with a cell's lower and upper triangle,
	# as (dx, dz, which) offsets.
	var around := [_corner_neighbours(0), _corner_neighbours(1)]
	var reached := PackedByteArray()
	reached.resize(tri_count)
	var queue := PackedInt32Array()
	queue.resize(tri_count)
	var head := 0
	var tail := 0
	var start := _triangle_at(terrain, Vector2(origin.x, origin.z))
	reached[start] = 1
	queue[tail] = start
	tail += 1
	while head < tail:
		var t := queue[head]
		head += 1
		var which := t & 1
		var c := t >> 1
		var cx := c % gs
		var cz := c / gs
		var from_face := is_face[t] == 1
		var from_mid := mid[t]
		for n in around[which]:
			var nx: int = cx + n[0]
			var nz: int = cz + n[1]
			if nx < 0 or nz < 0 or nx >= gs or nz >= gs:
				continue
			var u: int = (nz * gs + nx) * 2 + n[2]
			if reached[u] == 1:
				continue
			# Onto a face, or off one: downhill only.
			if (from_face or is_face[u] == 1) and mid[u] > from_mid:
				continue
			reached[u] = 1
			queue[tail] = u
			tail += 1
	print("A walk from the town reaches %d of %d triangles (%.1f%% of the plate)." % [tail, tri_count, 100.0 * tail / tri_count])

	var fails := 0
	var stranded := {}
	for c in camps:
		var p: Vector2 = c["pos"]
		if reached[_triangle_at(terrain, p)] == 0:
			stranded[c["name"]] = true
	for camp_name in stranded:
		fails += 1
		print("  FAIL no walk from the town reaches %s" % camp_name)
	if stranded.is_empty():
		print("  ok   every camp spawn can be walked to")

	var escaped := 0
	for cz in gs:
		for cx in gs:
			if cx == 0 or cz == 0 or cx == gs - 1 or cz == gs - 1:
				var t := (cz * gs + cx) * 2
				if reached[t] == 1 or reached[t + 1] == 1:
					escaped += 1
	if escaped > 0:
		fails += 1
	print("  %-4s the plate's outer row of cells: %d reached" % ["FAIL" if escaped > 0 else "ok", escaped])

	for u in features.get("unreachable", []):
		var p := _v2(u["point"])
		var hit := reached[_triangle_at(terrain, p)] == 1
		if hit:
			fails += 1
		print("  %-4s %s (%d, %d, ground %.1f m) %s" % [
			"FAIL" if hit else "ok", u.get("name", "a point"), int(p.x), int(p.y),
			Exporter.ground_at(terrain, p.x, p.y), "can be walked to" if hit else "cannot be walked to"])
	return fails


# The index of the triangle a point is in: (cell z * grid + cell x) * 2, plus 1
# for the upper triangle (the one without the cell's first corner).
static func _triangle_at(terrain: Dictionary, p: Vector2) -> int:
	var gs: int = terrain["grid_size"]
	var cell: float = terrain["cell_size"]
	var origin: Vector3 = terrain["origin"]
	var half := gs * cell * 0.5
	var fx := clampf((p.x - origin.x + half) / cell, 0.0, gs - 0.001)
	var fz := clampf((p.y - origin.z + half) / cell, 0.0, gs - 0.001)
	var cx := int(fx)
	var cz := int(fz)
	var upper := 1 if (fx - cx) + (fz - cz) > 1.0 else 0
	return (cz * gs + cx) * 2 + upper


# A triangle's corners as grid offsets from its cell: the lower one has the
# cell's first corner, the upper one its last.
static func _corners(which: int) -> Array:
	if which == 0:
		return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	return [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]


# Every other triangle that shares a corner with this one, as [dx, dz, which].
static func _corner_neighbours(which: int) -> Array:
	var mine := _corners(which)
	var out: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for other in 2:
				if dx == 0 and dz == 0 and other == which:
					continue
				for c in _corners(other):
					if mine.has(c + Vector2i(dx, dz)):
						out.append([dx, dz, other])
						break
	return out


static func _flat_at(terrain: Dictionary, p: Vector2) -> bool:
	return absf(Exporter.ground_at(terrain, p.x, p.y) - float(terrain["floor_y"])) <= FLAT_EPSILON \
		and Exporter.slope_deg_at(terrain, p.x, p.y) <= FLAT_EPSILON


# --- The ground paint ----------------------------------------------------

# Paints data/zone_layout.gd's ground onto one texture over the whole plate:
# the broad patches, the worn ground under the camps, the farm strips, then the
# roads on top. Alpha is how much of the paint shows over the shader's own
# ground colour; pixel (px, py) is the point (-half + (px + 0.5) * m, the same
# for z), so the shader samples it at xz / size + 0.5.
func _write_paint(terrain: Dictionary) -> int:
	var extent := int(terrain["grid_size"]) * float(terrain["cell_size"])
	var half := extent * 0.5
	var mpp := extent / PAINT_SIZE
	var data := PackedByteArray()
	data.resize(PAINT_SIZE * PAINT_SIZE * 4)
	# Unpainted pixels are clear, but hold a grass colour: the texture filter
	# blends a patch's edge with its neighbours, and black would rim it.
	for i in range(0, data.size(), 4):
		data[i] = 66
		data[i + 1] = 102
		data[i + 2] = 41
	var mottle := _noise(303, 55.0, 3)

	for patch in Layout.GROUND_PATCHES:
		_paint_patch(data, half, mpp, mottle, patch)
	for site_name in Layout.SITE_GROUND:
		var entry: Array = Layout.SITE_GROUND[site_name]
		_paint_patch(data, half, mpp, mottle, {
			"center": Layout.SITES[site_name], "radius": entry[0], "color": entry[1],
			"feather": float(entry[0]) * 0.6, "strength": 0.7, "mottle": 0.5})
	for field in Layout.FIELDS:
		_paint_field(data, half, mpp, field)
	for road in Layout.ROADS:
		_paint_road(data, half, mpp, mottle, road)

	var image := Image.create_from_data(PAINT_SIZE, PAINT_SIZE, false, Image.FORMAT_RGBA8, data)
	var path := ProjectSettings.globalize_path(PAINT_PATH)
	if image.save_png(path) != OK:
		printerr("Cannot write %s." % path)
		return 3
	print("\nPainted %s (%d px a side, %.2f m a pixel)." % [PAINT_PATH, PAINT_SIZE, mpp])
	return 0


# Lays `color` at opacity `a` over what pixel `i` holds.
static func _over(data: PackedByteArray, i: int, color: Color, a: float) -> void:
	if a <= 0.004:
		return
	var da := data[i + 3] / 255.0
	var keep := da * (1.0 - a)
	var out_a := a + keep
	data[i] = int(clampf((color.r * a + data[i] / 255.0 * keep) / out_a, 0.0, 1.0) * 255.0)
	data[i + 1] = int(clampf((color.g * a + data[i + 1] / 255.0 * keep) / out_a, 0.0, 1.0) * 255.0)
	data[i + 2] = int(clampf((color.b * a + data[i + 2] / 255.0 * keep) / out_a, 0.0, 1.0) * 255.0)
	data[i + 3] = int(clampf(out_a, 0.0, 1.0) * 255.0)


# The pixel range [from, to) that covers the world span lo..hi on one axis.
static func _pixel_span(lo: float, hi: float, half: float, mpp: float) -> Vector2i:
	return Vector2i(clampi(int((lo + half) / mpp), 0, PAINT_SIZE), clampi(int(ceil((hi + half) / mpp)) + 1, 0, PAINT_SIZE))


static func _paint_patch(data: PackedByteArray, half: float, mpp: float, mottle: FastNoiseLite, patch: Dictionary) -> void:
	var color: Color = patch["color"]
	var feather: float = maxf(patch.get("feather", 1.0), 0.01)
	var strength: float = patch.get("strength", 1.0)
	var mottled: float = patch.get("mottle", 0.0)
	var is_rect := patch.has("rect")
	var rect: Rect2 = patch.get("rect", Rect2())
	var center: Vector2 = patch.get("center", Vector2.ZERO)
	var radius: float = patch.get("radius", 0.0)
	if not is_rect:
		rect = Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	var xs := _pixel_span(rect.position.x, rect.end.x, half, mpp)
	var zs := _pixel_span(rect.position.y, rect.end.y, half, mpp)
	for py in range(zs.x, zs.y):
		var z := -half + (py + 0.5) * mpp
		for px in range(xs.x, xs.y):
			var x := -half + (px + 0.5) * mpp
			var inside: float
			if is_rect:
				inside = minf(minf(x - rect.position.x, rect.end.x - x), minf(z - rect.position.y, rect.end.y - z))
			else:
				inside = radius - Vector2(x, z).distance_to(center)
			if inside <= 0.0:
				continue
			var a := strength * smoothstep01(clampf(inside / feather, 0.0, 1.0))
			if mottled > 0.0:
				a *= lerpf(1.0, smoothstep01(clampf(n01(mottle, x, z) * 1.6 - 0.3, 0.0, 1.0)), mottled)
			_over(data, (py * PAINT_SIZE + px) * 4, color, a)


# A farm strip: its crop's colour with a furrow every fourth pixel row.
static func _paint_field(data: PackedByteArray, half: float, mpp: float, field: Dictionary) -> void:
	var rect: Rect2 = field["rect"]
	var crop: Color = field["color"]
	var xs := _pixel_span(rect.position.x, rect.end.x, half, mpp)
	var zs := _pixel_span(rect.position.y, rect.end.y, half, mpp)
	for py in range(zs.x, zs.y):
		var z := -half + (py + 0.5) * mpp
		if z < rect.position.y or z > rect.end.y:
			continue
		var color := Layout.COLOR_FURROW if py % 4 == 0 else (crop.darkened(0.12) if py % 4 == 2 else crop)
		for px in range(xs.x, xs.y):
			var x := -half + (px + 0.5) * mpp
			if x < rect.position.x or x > rect.end.x:
				continue
			_over(data, (py * PAINT_SIZE + px) * 4, color, 0.95)


static func _paint_road(data: PackedByteArray, half: float, mpp: float, mottle: FastNoiseLite, road: Dictionary) -> void:
	var pts := Layout.road_points(road)
	var half_width: float = float(road["width"]) * 0.5
	# The road fades out over this much past its edge.
	var soft := 2.5
	var reach := half_width + soft
	for s in pts.size() - 1:
		var a := pts[s]
		var b := pts[s + 1]
		var xs := _pixel_span(minf(a.x, b.x) - reach, maxf(a.x, b.x) + reach, half, mpp)
		var zs := _pixel_span(minf(a.y, b.y) - reach, maxf(a.y, b.y) + reach, half, mpp)
		for py in range(zs.x, zs.y):
			var z := -half + (py + 0.5) * mpp
			for px in range(xs.x, xs.y):
				var x := -half + (px + 0.5) * mpp
				var d := segment_distance(Vector2(x, z), a, b)
				if d >= reach:
					continue
				var alpha := 0.93 * (1.0 - smoothstep01(clampf((d - half_width + 1.0) / (soft + 1.0), 0.0, 1.0)))
				var i := (py * PAINT_SIZE + px) * 4
				# Segments overlap at their joints: never darken a pixel twice.
				if data[i + 3] / 255.0 >= alpha and _is_road_pixel(data, i):
					continue
				var shade := lerpf(0.9, 1.08, n01(mottle, x * 3.0, z * 3.0))
				_over(data, i, Color(Layout.COLOR_ROAD.r * shade, Layout.COLOR_ROAD.g * shade, Layout.COLOR_ROAD.b * shade), alpha)


# Whether a pixel already holds road colour (within the mottle's range of it).
static func _is_road_pixel(data: PackedByteArray, i: int) -> bool:
	var c := Layout.COLOR_ROAD
	return absf(data[i] / 255.0 - c.r) < 0.08 and absf(data[i + 1] / 255.0 - c.g) < 0.08 and absf(data[i + 2] / 255.0 - c.b) < 0.08


# --- Writing the scene ---------------------------------------------------

func _write_scene(terrain: Dictionary) -> int:
	var scene_file := ProjectSettings.globalize_path(WORLD_SCENE_PATH)
	var f := FileAccess.open(scene_file, FileAccess.READ)
	if f == null:
		printerr("Cannot open %s." % scene_file)
		return 2
	var text := f.get_as_text()
	f.close()

	var out := _replace_node_properties(text, terrain)
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
	var reread := Exporter.read_scene(WORLD_SCENE_PATH)
	if reread.has("error") or (reread["heights"] as PackedFloat32Array).size() != (terrain["heights"] as PackedFloat32Array).size():
		printerr("The written scene does not read back: %s" % reread.get("error", "the heights differ in number"))
		return 3
	print("Wrote %d heights (%dx%d cells of %s m) into %s." % [
		(terrain["heights"] as PackedFloat32Array).size(), terrain["grid_size"], terrain["grid_size"],
		str(terrain["cell_size"]), WORLD_SCENE_PATH])
	print("Next: godot --headless --path . --import, then tools/export_terrain.gd -- <server data dir>/terrain.toml, then tools/check_terrain_lockstep.gd -- <server data dir>.")
	return 0


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
