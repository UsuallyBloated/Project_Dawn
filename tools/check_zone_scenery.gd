extends SceneTree

# Zone scenery check: builds scenes/world.tscn's ground and dressing (the
# TerrainMesh's chunks, ZoneFlora's scatter, ZoneTown, ZoneLandmarks) headless
# and holds them to the rules they are built under:
#
#   GROUND     the terrain is the chunks its grid makes, one collider each.
#   COLLIDES   nothing under Flora, Town or Landmarks is a physics body or a
#              collision shape. What stops a body at a tree or a wall is the
#              zone's obstacle data and the rule the server runs too
#              (scripts/zone/zone_obstacles.gd, invariant L2); a physics shape
#              on the scenery would stop the client's body by a second rule
#              the server does not have.
#   SCATTER    the flora is the same every time it is built (every client
#              plants the same wood), stands on the ground, and keeps off the
#              roads, out of the town and off the rim.
#   VARIANTS   every planted thing is one of its kind's models, a cell holds
#              no more of a kind's variants than ZoneFlora allows, and every
#              variant grows somewhere.
#   GRASS      a square of grass (zone_grass.gd) grows the same tufts every
#              time, on the ground, off the roads and the town, no thicker
#              than GRASS_PER_M2, thinner under the Greywood than on the plain.
#   PIECES     every set piece the layout names was built.
#   BUDGET     lights, smoke columns, triangles and draw batches stay inside
#              what a modest machine draws.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_zone_scenery.gd
#
# Exit code 1 on any FAIL, 2 when the scene cannot be loaded, 0 otherwise.

const WORLD_SCENE := "res://scenes/world.tscn"
const SKIP_NODES := ["HUD", "Hotbar", "LevelUpPopup", "Players"]
const DRESSING_NODES := ["Flora", "Grass", "Town", "Landmarks"]
const TOWN_PIECES := ["Walls", "Houses", "Square", "Farms", "Barn", "Mill", "MillSails"]
const LANDMARK_PIECES := [
	"Pass", "WardStones", "BarrowDoor", "Ossuary", "WraithGate", "WraithGateLight", "BrokenCrypt",
	"GnollRaiderCamp", "WagonWreck", "GnollWarCamp", "GrethsTent", "BanditOutpost", "Bonepile",
	"ShallowGraves", "Dens", "FesteringMound", "SpiderCopse", "Doors", "Overlook", "Milestones",
]
const FLORA_MIN := 15000
const FLORA_MAX := 70000
const MAX_LIGHTS := 24
const MAX_SMOKE := 16
const MAX_SET_PIECE_TRIANGLES := 200000
const MAX_FLORA_BATCHES := 3500
# A planted thing may sit this far under the ground (its sink) or over it.
const GROUND_SLACK := 1.5

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var packed := load(WORLD_SCENE) as PackedScene
	if packed == null:
		printerr("Cannot load %s." % WORLD_SCENE)
		quit(2)
		return
	var started := Time.get_ticks_msec()
	var world := packed.instantiate()
	world.set_script(null)
	for skip in SKIP_NODES:
		var node := world.get_node_or_null(skip)
		if node != null:
			world.remove_child(node)
			node.free()
	root.add_child(world)
	await process_frame
	print("Built the zone's ground and scenery in %d ms." % (Time.get_ticks_msec() - started))

	var terrain := world.get_node_or_null("TerrainMesh") as TerrainMesh
	if terrain == null:
		printerr("world.tscn has no TerrainMesh.")
		quit(2)
		return
	_check_ground(terrain)
	_check_collides(world)
	_check_scatter(world, terrain)
	_check_variants(world)
	_check_grass(world, terrain)
	_check_pieces(world)
	_check_budget(world)

	print("%d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)


func _check_ground(terrain: TerrainMesh) -> void:
	var chunks := terrain.chunk_count() * terrain.chunk_count()
	_check(terrain.get_node("TerrainVisual").get_child_count() == chunks, "GROUND the terrain draws as %d chunks" % chunks)
	_check(terrain.get_node("TerrainBody").get_child_count() == chunks, "GROUND every chunk has its collider")
	_check(terrain.paint != null and terrain.paint.get_width() >= 1024, "GROUND the ground paint is loaded")


func _check_collides(world: Node) -> void:
	var found: Array[String] = []
	for dressing in DRESSING_NODES:
		var node := world.get_node_or_null(dressing)
		if node == null:
			_check(false, "COLLIDES world.tscn has a %s node" % dressing)
			continue
		for n in _descendants(node):
			if n is CollisionObject3D or n is CollisionShape3D or n is CollisionPolygon3D:
				found.append(str(world.get_path_to(n)))
	_check(found.is_empty(), "COLLIDES no scenery is a physics body%s" % ("" if found.is_empty() else ": " + ", ".join(found.slice(0, 5))))


func _check_scatter(world: Node, terrain: TerrainMesh) -> void:
	var flora := world.get_node_or_null("Flora") as ZoneFlora
	if flora == null:
		return
	var first := _flora_points(flora)
	_check(first.size() >= FLORA_MIN and first.size() <= FLORA_MAX, "SCATTER %d things planted (%d to %d)" % [first.size(), FLORA_MIN, FLORA_MAX])
	flora.build()
	var second := _flora_points(flora)
	var same := first.size() == second.size()
	if same:
		for i in first.size():
			if not first[i].is_equal_approx(second[i]):
				same = false
				break
	_check(same, "SCATTER a second build plants the same wood")

	var curves := ZoneLayout.road_curves()
	var in_town := 0
	var on_rim := 0
	var on_road := 0
	var off_ground := 0
	for i in first.size():
		var p := first[i]
		var flat := ZoneLayout.to_map(p)
		if flat.length() < ZoneLayout.TOWN_CLEARING:
			in_town += 1
		if not ZoneLayout.inside(flat):
			on_rim += 1
		if absf(p.y - terrain.height_at(p.x, p.z)) > GROUND_SLACK:
			off_ground += 1
		# The roads are checked on every eighth thing: the test walks every
		# road segment, and 40,000 of those is a minute.
		if i % 8 == 0 and ZoneLayout.road_clearance(flat, curves) < 0.0:
			on_road += 1
	_check(in_town == 0, "SCATTER nothing is planted inside the town (%d)" % in_town)
	_check(on_rim == 0, "SCATTER nothing is planted outside the edge, on the mountains (%d)" % on_rim)
	_check(on_road == 0, "SCATTER nothing is planted on a road (%d of the sample)" % on_road)
	_check(off_ground == 0, "SCATTER everything stands on the ground (%d do not)" % off_ground)


func _check_variants(world: Node) -> void:
	var flora := world.get_node_or_null("Flora") as ZoneFlora
	if flora == null:
		return
	var kinds := flora.placed_kinds()
	var points := flora.planted()
	var unknown := 0
	var seen: Dictionary = {}
	var per_cell: Dictionary = {}
	for i in kinds.size():
		var kind := kinds[i].get_slice("#", 0)
		var variant := int(kinds[i].get_slice("#", 1))
		if not ZoneFlora.KINDS.has(kind) or not (ZoneFlora.KINDS[kind]["variants"] as Array).has(variant):
			unknown += 1
			continue
		seen[kinds[i]] = true
		var cell := Vector2i(int(floor(points[i].x / ZoneFlora.CELL)), int(floor(points[i].z / ZoneFlora.CELL)))
		var key := "%s %s" % [cell, kind]
		if not per_cell.has(key):
			per_cell[key] = {}
		per_cell[key][variant] = true
	_check(unknown == 0, "VARIANTS every planted thing is one of its kind's models (%d are not)" % unknown)
	var crowded := 0
	for key in per_cell:
		if (per_cell[key] as Dictionary).size() > ZoneFlora.MAX_VARIANTS_PER_CELL:
			crowded += 1
	_check(crowded == 0, "VARIANTS no cell holds more than %d variants of a kind (%d do)" % [ZoneFlora.MAX_VARIANTS_PER_CELL, crowded])
	var missing: Array[String] = []
	for kind in ZoneFlora.KINDS:
		for variant in ZoneFlora.KINDS[kind]["variants"]:
			if not seen.has("%s#%d" % [kind, variant]):
				missing.append("%s#%d" % [kind, variant])
	_check(missing.is_empty(), "VARIANTS every variant grows somewhere%s" % ("" if missing.is_empty() else "; none of " + ", ".join(missing)))


# Squares of grass on open plain, in the Greywood, and under every road's
# middle: grown twice and held to the rules.
func _check_grass(world: Node, terrain: TerrainMesh) -> void:
	var grass := world.get_node_or_null("Grass") as ZoneGrass
	var flora := world.get_node_or_null("Flora") as ZoneFlora
	if grass == null or flora == null:
		_check(false, "GRASS world.tscn has a Grass node")
		return
	var plain := [Vector2(300, -300), Vector2(-700, 300), Vector2(900, -1000), Vector2(-400, -900)]
	var wood := [Vector2(0, 1400), Vector2(-900, 1500), Vector2(900, 1300), Vector2(400, 1700)]
	var spots: Array = plain + wood
	for curve in ZoneLayout.road_curves():
		var pts: PackedVector2Array = curve["points"]
		spots.append(pts[pts.size() / 2])
	var per_square := int(ZoneGrass.CELL * ZoneGrass.CELL * ZoneLayout.GRASS_PER_M2)
	var differ := 0
	var too_thick := 0
	var off_ground := 0
	var blocked := 0
	var bodies := 0
	var batches := 0
	var counts: Array[int] = []
	for spot in spots:
		var w := ZoneLayout.to_world_xz(spot)
		var cell := Vector2i(int(floor(w.x / ZoneGrass.CELL)), int(floor(w.y / ZoneGrass.CELL)))
		var first := grass.grow_cell(cell)
		var second := grass.grow_cell(cell)
		var a: PackedVector3Array = first.get_meta("tufts")
		var b: PackedVector3Array = second.get_meta("tufts")
		if a != b:
			differ += 1
		if a.size() > per_square:
			too_thick += 1
		counts.append(a.size())
		for t in a:
			if absf(t.y - terrain.height_at(t.x, t.z)) > GROUND_SLACK:
				off_ground += 1
			if flora.is_blocked(ZoneLayout.to_map(t)):
				blocked += 1
		batches = maxi(batches, first.get_child_count())
		for n in _descendants(first):
			if n is CollisionObject3D or n is CollisionShape3D:
				bodies += 1
		first.free()
		second.free()
	var plain_total := 0
	var wood_total := 0
	for i in plain.size():
		plain_total += counts[i]
		wood_total += counts[plain.size() + i]
	_check(differ == 0, "GRASS a square grows the same tufts every time (%d differ)" % differ)
	_check(plain_total > 0 and wood_total < plain_total, "GRASS the plain grows grass, the Greywood less (%d against %d tufts)" % [plain_total, wood_total])
	_check(too_thick == 0, "GRASS no square holds more than %d tufts (%d do)" % [per_square, too_thick])
	_check(off_ground == 0, "GRASS every tuft stands on the ground (%d do not)" % off_ground)
	_check(blocked == 0, "GRASS no tuft grows where the flora may not: a road, the town, a field (%d do)" % blocked)
	_check(bodies == 0 and batches <= ZoneGrass.VARIANTS_PER_CELL, "GRASS a square is at most %d batches and no physics body" % ZoneGrass.VARIANTS_PER_CELL)


# The world position of every near-mesh flora instance, in build order.
# Where the flora planted everything. The node keeps the list: under the
# headless renderer a MultiMesh's instances read back as identity, so reading
# them here would test every batch's origin and nothing else.
func _flora_points(flora: ZoneFlora) -> PackedVector3Array:
	return flora.planted().duplicate()


func _check_pieces(world: Node) -> void:
	for pair in [["Town", TOWN_PIECES], ["Landmarks", LANDMARK_PIECES]]:
		var node := world.get_node_or_null(pair[0])
		if node == null:
			continue
		var missing: Array[String] = []
		for piece in pair[1]:
			if node.get_node_or_null(piece) == null:
				missing.append(piece)
		_check(missing.is_empty(), "PIECES %s built all %d of its pieces%s" % [pair[0], (pair[1] as Array).size(), "" if missing.is_empty() else "; missing: " + ", ".join(missing)])
	for site_name in ZoneLayout.SITES:
		var at: Vector2 = ZoneLayout.SITES[site_name]
		if not ZoneLayout.inside(at):
			_check(false, "PIECES the site %s is inside the edge" % site_name)


func _check_budget(world: Node) -> void:
	var lights := 0
	var smoke := 0
	var triangles := 0
	var batches := 0
	for dressing in DRESSING_NODES:
		var node := world.get_node_or_null(dressing)
		if node == null:
			continue
		for n in _descendants(node):
			if n is Light3D:
				lights += 1
			elif n is CPUParticles3D or n is GPUParticles3D:
				smoke += 1
			elif n is MultiMeshInstance3D:
				batches += 1
			elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				triangles += (n as MeshInstance3D).mesh.get_faces().size() / 3
	_check(lights <= MAX_LIGHTS, "BUDGET %d lights (at most %d)" % [lights, MAX_LIGHTS])
	_check(smoke <= MAX_SMOKE, "BUDGET %d smoke columns (at most %d)" % [smoke, MAX_SMOKE])
	_check(triangles <= MAX_SET_PIECE_TRIANGLES, "BUDGET %d triangles in the town and the set pieces (at most %d)" % [triangles, MAX_SET_PIECE_TRIANGLES])
	_check(batches <= MAX_FLORA_BATCHES, "BUDGET %d flora batches (at most %d)" % [batches, MAX_FLORA_BATCHES])


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			out.append(child)
			stack.append(child)
	return out
