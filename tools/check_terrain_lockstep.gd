extends SceneTree

# Terrain lockstep check (the server height model,
# docs/design/server_height_model.md): the server's `terrain.toml` must be the
# ground in `scenes/world.tscn`, or the server measures distances, slopes and
# sight on a surface nobody walks on. A server ground that disagrees with the
# client's is worse than none, so this fails loudly on any difference.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_terrain_lockstep.gd
#   godot --headless --path . -s tools/check_terrain_lockstep.gd -- <server data dir>
#
# It reports:
#   DRIFT     the grid, the origin, the floor, a height or the hash differs
#             between the scene and the TOML (a scene edit nobody exported, or
#             a hand-edited TOML).
#   COLLIDER  the colliders TerrainMesh builds from the scene's heights are not
#             the triangles those heights make (a cell missing, doubled or split
#             on the other diagonal, so the client walks on a ground the server
#             does not sample), or a triangle faces down (wound the wrong way:
#             the ground is culled from above and a body sinks into the
#             one-sided collider).
#   NPC       an NPC in the server's npcs.toml has no node in the scene, stands
#             somewhere else in XZ, or does not stand on the ground (5 cm).
#
# Exit code 1 on any problem, 2 when a file cannot be read, 0 otherwise.
# Read-only. The scene reader, the hash and the ground sampler are the
# exporter's own (tools/export_terrain.gd), so the check and the exporter
# cannot disagree about what the server carries.

const DEFAULT_SERVER_DATA := "F:/Projects/server/crates/projectdawn-server/data"
const Exporter := preload("res://tools/export_terrain.gd")
# Two floats closer than this are the same number written differently.
const EPSILON := 0.000001
# An NPC may stand this far from its server position, and this far off the ground.
const NPC_TOLERANCE := 0.05
# How many differing heights to name before summing the rest up.
const MAX_LISTED := 5


func _initialize() -> void:
	var data_dir := DEFAULT_SERVER_DATA
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		data_dir = args[0]

	var scene := Exporter.read_scene(Exporter.WORLD_SCENE)
	if scene.has("error"):
		printerr("Cannot read the terrain from %s: %s" % [Exporter.WORLD_SCENE, scene["error"]])
		quit(2)
		return
	var toml_path := data_dir.path_join("terrain.toml")
	var toml := _parse_terrain_toml(toml_path)
	if toml.is_empty():
		printerr("No terrain read from %s (wrong path, or the server repo is not checked out there)." % toml_path)
		quit(2)
		return
	var npcs_path := data_dir.path_join("npcs.toml")
	var npcs := _parse_npc_positions(npcs_path)
	if npcs.is_empty():
		printerr("No NPC positions read from %s." % npcs_path)
		quit(2)
		return

	var problems: Array[String] = []
	_check_grid(scene, toml, problems)
	_check_heights(scene, toml, problems)
	_check_hash(scene, toml, problems)
	_check_collider(scene, problems)
	_check_npcs(scene, toml, npcs, problems)

	if problems.is_empty():
		var heights: PackedFloat32Array = scene["heights"]
		print("Terrain in lockstep: %d heights (%dx%d cells of %s m, floor %s), the colliders built from them, %d NPCs on the ground." % [
			heights.size(), scene["grid_size"], scene["grid_size"], str(scene["cell_size"]), str(scene["floor_y"]), npcs.size()])
		quit(0)
		return
	for p in problems:
		print(p)
	print("%d problem(s)." % problems.size())
	quit(1)


func _check_grid(scene: Dictionary, toml: Dictionary, problems: Array[String]) -> void:
	if int(toml["grid_size"]) != int(scene["grid_size"]):
		problems.append("DRIFT grid_size: scene %d, server %d" % [scene["grid_size"], toml["grid_size"]])
	if absf(float(toml["cell_size"]) - float(scene["cell_size"])) > EPSILON:
		problems.append("DRIFT cell_size: scene %s, server %s" % [str(scene["cell_size"]), str(toml["cell_size"])])
	var so: Vector3 = scene["origin"]
	var to: Vector3 = toml["origin"]
	if absf(so.x - to.x) > EPSILON or absf(so.y - to.y) > EPSILON or absf(so.z - to.z) > EPSILON:
		problems.append("DRIFT origin: scene %s, server %s" % [so, to])
	if absf(float(toml["floor_y"]) - float(scene["floor_y"])) > EPSILON:
		problems.append("DRIFT floor_y: scene %s, server %s" % [str(scene["floor_y"]), str(toml["floor_y"])])


func _check_heights(scene: Dictionary, toml: Dictionary, problems: Array[String]) -> void:
	var sh: PackedFloat32Array = scene["heights"]
	var th: PackedFloat32Array = toml["heights"]
	if sh.size() != th.size():
		problems.append("DRIFT heights: the scene holds %d, the server %d" % [sh.size(), th.size()])
		return
	var row: int = int(scene["grid_size"]) + 1
	var differing := 0
	for i in sh.size():
		if absf(sh[i] - th[i]) > EPSILON:
			differing += 1
			if differing <= MAX_LISTED:
				problems.append("DRIFT height at x=%d z=%d: scene %s, server %s" % [i % row, i / row, str(sh[i]), str(th[i])])
	if differing > MAX_LISTED:
		problems.append("DRIFT ... and %d more heights differ" % (differing - MAX_LISTED))


func _check_hash(scene: Dictionary, toml: Dictionary, problems: Array[String]) -> void:
	var want := Exporter.written_hash(scene)
	var got := String(toml["hash"]).to_lower()
	if want != got:
		problems.append("DRIFT hash: the scene's ground hashes to %s, the server file says %s (a hand edit, or a stale export)" % [want.substr(0, 12), got.substr(0, 12)])


# The colliders the client walks on must be the triangles its heights make:
# two per cell, split from (x1, z0) to (x0, z1), each exactly once, whatever
# chunk it was built in. The game's own TerrainMesh is built from the scene's
# heights and every triangle of every chunk's collider is placed in its cell
# and held to that cell's corners. And every triangle must face up: Godot's
# front face is the one its corners run clockwise round, its normal
# (c - a) x (b - a), and a trimesh collides on its front side only.
func _check_collider(scene: Dictionary, problems: Array[String]) -> void:
	var gs: int = scene["grid_size"]
	var cell: float = scene["cell_size"]
	var heights: PackedFloat32Array = scene["heights"]
	var node := Exporter.build_terrain(scene)
	var data: PackedVector3Array = node.collider_faces()
	node.free()
	if data.is_empty():
		problems.append("COLLIDER TerrainMesh built no collider triangles from the scene's heights")
		return
	var want := gs * gs * 6
	if data.size() != want:
		problems.append("COLLIDER TerrainMesh built %d collider vertices, the heights make %d" % [data.size(), want])
		return
	var half := gs * cell * 0.5
	var row := gs + 1
	var seen := PackedByteArray()
	seen.resize(gs * gs * 2)
	var differing := 0
	var misplaced := 0
	var doubled := 0
	var facing_down := 0
	for t in range(0, data.size(), 3):
		var a := data[t]
		var b := data[t + 1]
		var c := data[t + 2]
		if (c - a).cross(b - a).y <= 0.0:
			facing_down += 1
		# The cell is the one the triangle's lowest corner on each axis is in;
		# the upper triangle is the one whose corners sum past that corner by 4
		# cell sides (the lower one's by 2).
		var min_x := minf(a.x, minf(b.x, c.x))
		var min_z := minf(a.z, minf(b.z, c.z))
		var cx := int(round((min_x + half) / cell))
		var cz := int(round((min_z + half) / cell))
		if cx < 0 or cz < 0 or cx >= gs or cz >= gs:
			misplaced += 1
			continue
		var spread := (a.x + b.x + c.x - 3.0 * min_x + a.z + b.z + c.z - 3.0 * min_z) / cell
		var upper := 1 if spread > 3.0 else 0
		var corners: Array
		if upper == 0:
			corners = [Vector2i(cx, cz), Vector2i(cx + 1, cz), Vector2i(cx, cz + 1)]
		else:
			corners = [Vector2i(cx + 1, cz), Vector2i(cx + 1, cz + 1), Vector2i(cx, cz + 1)]
		var got := [a, b, c]
		for k in 3:
			var corner: Vector2i = corners[k]
			var expect := Vector3(-half + corner.x * cell, heights[corner.y * row + corner.x], -half + corner.y * cell)
			if got[k].distance_to(expect) > EPSILON and not got[k].is_equal_approx(expect):
				differing += 1
				if differing <= MAX_LISTED:
					problems.append("COLLIDER a triangle's corner in cell (%d, %d) is %s, the heights make %s" % [cx, cz, got[k], expect])
		var slot := (cz * gs + cx) * 2 + upper
		if seen[slot] == 1:
			doubled += 1
		seen[slot] = 1
	if differing > MAX_LISTED:
		problems.append("COLLIDER ... and %d more corners differ" % (differing - MAX_LISTED))
	if misplaced > 0:
		problems.append("COLLIDER %d triangles lie outside the grid" % misplaced)
	if doubled > 0:
		problems.append("COLLIDER %d triangles were built twice" % doubled)
	var missing := seen.count(0)
	if missing > 0:
		problems.append("COLLIDER %d of the %d triangles the heights make have no collider" % [missing, seen.size()])
	if facing_down > 0:
		problems.append("COLLIDER %d of %d triangles face down (wound the wrong way round)" % [facing_down, data.size() / 3])


# Every NPC the server places must have a node in the scene at the same XZ,
# standing on the ground the server computes there.
func _check_npcs(scene: Dictionary, toml: Dictionary, npcs: Array, problems: Array[String]) -> void:
	var placed: Array = scene["npcs"]
	for npc in npcs:
		var name: String = npc["name"]
		var pos: Vector3 = npc["pos"]
		var node: Dictionary = {}
		for p in placed:
			var placed_name: String = p["name"]
			if placed_name == name or placed_name.begins_with(name):
				node = p
				break
		if node.is_empty():
			problems.append("NPC %s is in npcs.toml at %s but has no node in world.tscn" % [name, pos])
			continue
		var at: Vector3 = node["pos"]
		if absf(at.x - pos.x) > NPC_TOLERANCE or absf(at.z - pos.z) > NPC_TOLERANCE:
			problems.append("NPC %s stands at x=%s z=%s in the scene, x=%s z=%s on the server" % [name, str(at.x), str(at.z), str(pos.x), str(pos.z)])
		var ground := Exporter.ground_at(toml, at.x, at.z)
		if absf(at.y - ground) > NPC_TOLERANCE:
			problems.append("NPC %s stands at y=%s in the scene, the ground there is %s" % [name, str(at.y), str(ground)])


# A line reader for the shape the exporter writes: `key = value` lines, one
# multi-line `heights = [ ... ]` array, a quoted hash. Not a general TOML reader.
func _parse_terrain_toml(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var out := {"grid_size": 0, "cell_size": 0.0, "origin": Vector3.ZERO, "floor_y": 0.0, "heights": PackedFloat32Array(), "hash": ""}
	var in_heights := false
	var heights := PackedFloat32Array()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if in_heights:
			if line.begins_with("]"):
				in_heights = false
			else:
				for cell in line.split(","):
					var s := cell.strip_edges()
					if not s.is_empty():
						heights.append(float(s))
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges()
		match key:
			"grid_size":
				out["grid_size"] = int(value)
			"cell_size":
				out["cell_size"] = float(value)
			"floor_y":
				out["floor_y"] = float(value)
			"origin":
				var parts := value.trim_prefix("[").trim_suffix("]").split(",")
				if parts.size() == 3:
					out["origin"] = Vector3(float(parts[0].strip_edges()), float(parts[1].strip_edges()), float(parts[2].strip_edges()))
			"heights":
				in_heights = true
				# Anything on the same line after the bracket.
				var rest := value.trim_prefix("[").strip_edges()
				if rest.ends_with("]"):
					in_heights = false
					rest = rest.trim_suffix("]")
				for cell in rest.split(","):
					var s := cell.strip_edges()
					if not s.is_empty():
						heights.append(float(s))
			"hash":
				out["hash"] = value.trim_prefix("\"").trim_suffix("\"")
	out["heights"] = heights
	if out["grid_size"] <= 0 or heights.is_empty():
		return {}
	return out


# The [[npc]] entries' names and positions from the server's npcs.toml.
func _parse_npc_positions(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var out: Array = []
	var current: Dictionary = {}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line == "[[npc]]":
			_keep_npc(current, out)
			current = {"name": "", "pos": Vector3.ZERO, "has_pos": false}
			continue
		if current.is_empty():
			continue
		if line.begins_with("name ="):
			var first := line.find("\"")
			var last := line.rfind("\"")
			if first >= 0 and last > first:
				current["name"] = line.substr(first + 1, last - first - 1)
		elif line.begins_with("pos ="):
			var value := line.substr(line.find("=") + 1).strip_edges()
			var parts := value.trim_prefix("[").trim_suffix("]").split(",")
			if parts.size() == 3:
				current["pos"] = Vector3(float(parts[0].strip_edges()), float(parts[1].strip_edges()), float(parts[2].strip_edges()))
				current["has_pos"] = true
	_keep_npc(current, out)
	return out


func _keep_npc(entry: Dictionary, out: Array) -> void:
	if not entry.is_empty() and entry["name"] != "" and entry["has_pos"]:
		out.append({"name": entry["name"], "pos": entry["pos"]})
