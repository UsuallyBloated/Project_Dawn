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
#   COLLIDER  the scene's TerrainCol triangles are not the triangles its
#             heights make (the mesh was edited and never rebuilt, so the
#             client walks on an older ground than it draws or exports).
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
		print("Terrain in lockstep: %d heights (%dx%d cells of %s m, floor %s), the collider rebuilt, %d NPCs on the ground." % [
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


# The collider the client walks on must be the triangles its heights make, in
# the order TerrainMesh._rebuild emits them (two per cell, split from (x1, z0)
# to (x0, z1)); otherwise the scene draws and exports one ground and collides
# with another.
func _check_collider(scene: Dictionary, problems: Array[String]) -> void:
	var data: PackedVector3Array = scene["collider"]
	var gs: int = scene["grid_size"]
	var cell: float = scene["cell_size"]
	var heights: PackedFloat32Array = scene["heights"]
	if data.is_empty():
		problems.append("COLLIDER the scene's TerrainCol has no triangles: open the scene so TerrainMesh rebuilds, then save it")
		return
	var want := gs * gs * 6
	if data.size() != want:
		problems.append("COLLIDER the scene's TerrainCol has %d vertices, its heights make %d: rebuild the mesh and save the scene" % [data.size(), want])
		return
	var half := gs * cell * 0.5
	var row := gs + 1
	var differing := 0
	var i := 0
	for z in gs:
		for x in gs:
			var corners := [
				Vector2i(x, z), Vector2i(x, z + 1), Vector2i(x + 1, z),
				Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1),
			]
			for c in corners:
				var expect := Vector3(-half + c.x * cell, heights[c.y * row + c.x], -half + c.y * cell)
				if not data[i].is_equal_approx(expect) and data[i].distance_to(expect) > EPSILON:
					differing += 1
					if differing <= MAX_LISTED:
						problems.append("COLLIDER vertex %d is %s, the heights make %s" % [i, data[i], expect])
				i += 1
	if differing > MAX_LISTED:
		problems.append("COLLIDER ... and %d more vertices differ (rebuild the mesh and save the scene)" % (differing - MAX_LISTED))


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
