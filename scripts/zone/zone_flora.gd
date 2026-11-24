@tool
class_name ZoneFlora
extends Node3D

# The zone's trees, bushes, boulders and bones: scattered at load from
# data/zone_layout.gd's SCATTER regions, the same on every client (each region
# is seeded by its name), standing on the TerrainMesh's ground. Every kind has
# a few variants, models made in Blender (tools/blender/, loaded through
# SceneryModels), each drawn many times: the things of one variant in a
# CELL-metre square are one MultiMesh, so 25,000 trees are a few hundred draw
# calls, and a far tree is a five-triangle cone until the camera is near.
#
# Which variant grows where is decided by the spot itself (a hash of where it
# stands), never by another throw of the scatter's dice, so adding a variant
# or a kind moves no tree. A cell draws at most MAX_VARIANTS_PER_CELL of a
# kind's variants, to keep the draw calls down; every variant still grows
# somewhere in the zone.
#
# Drawn only: no node here is a physics body. What stops a player at a trunk
# or a boulder is the zone's obstacle data (zone_obstacles.gd), which the
# server holds too; tools/export_obstacles.gd makes it from what is planted
# here (`placed_kinds`, `placed_transforms`) and each variant's solids
# (`kind_volumes`).

# The scatter is bucketed into squares this wide; each is culled as one.
const CELL := 400.0
# Roads and clearings are looked up in a grid of squares this wide.
const BLOCK_CELL := 100.0
# Nothing grows on ground steeper than this (rise over run: about 40 degrees).
const MAX_SLOPE := 0.84
# The clumping noise's wavelength, metres: how big a glade is.
const CLUMP_WAVELENGTH := 150.0
# A cell draws at most this many of a kind's variants (see the header).
const MAX_VARIANTS_PER_CELL := 3
# A tree's crown starts at or above this (metres, at scale 1; the generators
# keep every crown at 2.2 m or higher, so a body stops at the trunk). The far
# stand-in is fitted to what a variant has above it, and the obstacle bake
# merges it into one crown.
const CROWN_FROM := 2.0
# About one tree in 40 of a kind marked "colossal" (its size throw above
# COLOSSAL_FROM) grows to COLOSSAL_SCALE instead of the kind's own range.
const COLOSSAL_FROM := 0.975
const COLOSSAL_SCALE := Vector2(1.5, 2.0)

# The far stand-ins' colours (the near models carry their own).
const PINE_GREEN := Color(0.14, 0.27, 0.17)
const LEAF_GREEN := Color(0.28, 0.40, 0.17)
const DARK_LEAF := Color(0.14, 0.20, 0.15)
const BONE := Color(0.84, 0.81, 0.70)

# What grows. `model` is the folder its variants are in and `variants` which of
# them it draws; `scale` is the range of sizes; `near` is how far the model is
# drawn; a kind with a `far` stand-in is drawn as that from `near` out to
# `end`, fitted to each variant's crown (`far_fit`: a cone or a blob). `bake`
# is how the obstacle bake makes its solids (ZoneObstacleBake.flora_groups):
# "trunk" for a tree, "merge" for a bush or a rock, "pieces" for bones, whose
# pieces a body steps over one by one. `squash: false` keeps a kind's
# proportions (a skeleton is the height of its race).
const KINDS := {
	"pine": {"model": "pine", "variants": [1, 2, 3], "scale": Vector2(0.85, 1.15), "colossal": true,
		"near": 450.0, "far": "pine_far", "far_fit": "cone", "end": 2000.0, "sink": 0.2, "bake": "trunk"},
	"tall_pine": {"model": "pine", "variants": [4, 5, 6], "scale": Vector2(0.85, 1.15), "colossal": true,
		"near": 450.0, "far": "tall_pine_far", "far_fit": "cone", "end": 2000.0, "sink": 0.2, "bake": "trunk"},
	"broadleaf": {"model": "broadleaf", "variants": [1, 2, 3, 4, 5, 6], "scale": Vector2(0.85, 1.15), "colossal": true,
		"near": 450.0, "far": "crown_far", "far_fit": "blob", "end": 1600.0, "sink": 0.2, "bake": "trunk"},
	"dark_tree": {"model": "dark_tree", "variants": [1, 2, 3, 4, 5, 6], "scale": Vector2(0.85, 1.15), "colossal": true,
		"near": 450.0, "far": "dark_crown_far", "far_fit": "blob", "end": 1400.0, "sink": 0.2, "bake": "trunk"},
	"dead_tree": {"model": "dead_tree", "variants": [1, 2, 3, 4, 5, 6], "scale": Vector2(0.85, 1.15), "colossal": true,
		"near": 900.0, "sink": 0.2, "bake": "trunk"},
	"bush": {"model": "bush", "variants": [1, 2, 3, 4, 5, 6, 7, 8], "scale": Vector2(0.8, 1.2),
		"near": 480.0, "sink": 0.1, "bake": "merge"},
	"scrub": {"model": "scrub", "variants": [1, 2, 3, 4, 5, 6, 7, 8], "scale": Vector2(0.8, 1.2),
		"near": 460.0, "sink": 0.05, "bake": "merge"},
	"boulder": {"model": "boulder", "variants": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "scale": Vector2(0.5, 2.0),
		"near": 1000.0, "sink": 0.25, "tumble": true, "bake": "merge"},
	"bones": {"model": "bones", "variants": [1, 2, 3, 4, 5, 6], "scale": Vector2(0.85, 1.15),
		"near": 520.0, "sink": 0.05, "bake": "pieces"},
	"skeleton": {"model": "skeleton", "variants": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
		"scale": Vector2(0.95, 1.05), "squash": false, "near": 150.0, "far": "skeleton_far", "far_fit": "blob",
		"end": 450.0, "sink": 0.03, "bake": "pieces"},
}

@export var terrain_path := NodePath("../TerrainMesh")

var _meshes: Dictionary = {}
var _block_grid: Dictionary = {}
var _curves: Array = []
var _grown_fields: Array[Rect2] = []
# Where everything was planted (world positions), for tools/check_zone_scenery.gd:
# a MultiMesh cannot be read back under the headless renderer.
var _planted := PackedVector3Array()
# The kind and the world transform of everything planted, in the same order.
var _placed_kinds := PackedStringArray()
var _placed_transforms: Array[Transform3D] = []


func _ready() -> void:
	build()


func build() -> void:
	var terrain := get_node_or_null(terrain_path) as TerrainMesh
	if terrain == null:
		push_warning("ZoneFlora: no TerrainMesh at %s; nothing planted." % terrain_path)
		return
	for child in get_children():
		remove_child(child)
		child.free()
	_planted.clear()
	_placed_kinds.clear()
	_placed_transforms.clear()
	var started := Time.get_ticks_msec()
	_build_block_grid()
	var clump := FastNoiseLite.new()
	clump.seed = 4711
	clump.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	clump.frequency = 1.0 / CLUMP_WAVELENGTH
	# One list of placements per (cell, kind).
	var buckets: Dictionary = {}
	var planted := 0
	for region in ZoneLayout.SCATTER:
		planted += _scatter(region, terrain, clump, buckets)
	for key in buckets:
		_emit(key, buckets[key], terrain)
	# The log autoload is looked up, never named: this script is also compiled
	# by tools that run before the autoloads exist, and in the editor, where
	# they never do.
	var debug_log := get_node_or_null("/root/DebugLog")
	if debug_log != null:
		debug_log.info("ZoneFlora: %d things in %d batches, %d ms" % [planted, buckets.size(), Time.get_ticks_msec() - started])


# --- Where nothing grows -------------------------------------------------

# Roads and clearings, each noted in every BLOCK_CELL square it touches, so a
# point is tested against the handful near it and not against all of them.
func _build_block_grid() -> void:
	_block_grid.clear()
	_curves = ZoneLayout.road_curves()
	for ci in _curves.size():
		var pts: PackedVector2Array = _curves[ci]["points"]
		var reach: float = float(_curves[ci]["half_width"]) + ZoneLayout.ROAD_MARGIN
		for s in pts.size() - 1:
			var a := pts[s]
			var b := pts[s + 1]
			var lo := Vector2(minf(a.x, b.x) - reach, minf(a.y, b.y) - reach)
			var hi := Vector2(maxf(a.x, b.x) + reach, maxf(a.y, b.y) + reach)
			_note_block(lo, hi, [a, b, reach])
	for site_name in ZoneLayout.SITES:
		var at: Vector2 = ZoneLayout.SITES[site_name]
		var r: float = ZoneLayout.SITE_CLEARINGS.get(site_name, ZoneLayout.SITE_CLEARING)
		_note_block(at - Vector2(r, r), at + Vector2(r, r), [at, r])
	for extra in ZoneLayout.EXTRA_CLEARINGS:
		var at: Vector2 = extra[0]
		var r: float = extra[1]
		_note_block(at - Vector2(r, r), at + Vector2(r, r), [at, r])
	_grown_fields.clear()
	for field in ZoneLayout.FIELDS:
		_grown_fields.append((field["rect"] as Rect2).grow(6.0))


func _note_block(lo: Vector2, hi: Vector2, entry: Array) -> void:
	for cz in range(int(floor(lo.y / BLOCK_CELL)), int(floor(hi.y / BLOCK_CELL)) + 1):
		for cx in range(int(floor(lo.x / BLOCK_CELL)), int(floor(hi.x / BLOCK_CELL)) + 1):
			var key := Vector2i(cx, cz)
			if not _block_grid.has(key):
				_block_grid[key] = []
			_block_grid[key].append(entry)


# Whether nothing of the flora grows at `p` (a map point): the town, the
# mountains past the edge, the fields, the roads and the clearings. The grass
# (zone_grass.gd) keeps to the same ground.
func is_blocked(p: Vector2) -> bool:
	if p.length_squared() < ZoneLayout.TOWN_CLEARING * ZoneLayout.TOWN_CLEARING:
		return true
	# Nothing grows on the mountains: the wood and the plain stop at the edge.
	if not ZoneLayout.inside(p):
		return true
	for rect in _grown_fields:
		if rect.has_point(p):
			return true
	var entries = _block_grid.get(Vector2i(int(floor(p.x / BLOCK_CELL)), int(floor(p.y / BLOCK_CELL))))
	if entries == null:
		return false
	for e in entries:
		if e.size() == 2:
			if p.distance_squared_to(e[0]) < e[1] * e[1]:
				return true
		else:
			var a: Vector2 = e[0]
			var ab: Vector2 = e[1] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < e[2]:
				return true
	return false


# --- Scattering ----------------------------------------------------------

# Plants one region into `buckets`; returns how many things it planted. A
# region is a rect, a circle, or (with "per_km") a strip along every road,
# "offset" metres (a range) past each verge.
func _scatter(region: Dictionary, terrain: TerrainMesh, clump: FastNoiseLite, buckets: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region["name"])
	var is_rect := region.has("rect")
	var along_roads := region.has("per_km")
	var rect: Rect2 = region.get("rect", Rect2())
	var center: Vector2 = region.get("center", Vector2.ZERO)
	var radius: float = region.get("radius", 0.0)
	var count: int
	var road_lengths: Array[float] = []
	var road_total := 0.0
	if along_roads:
		for curve in _curves:
			var pts: PackedVector2Array = curve["points"]
			for s in pts.size() - 1:
				road_total += pts[s].distance_to(pts[s + 1])
				road_lengths.append(road_total)
		count = int(road_total / 1000.0 * float(region["per_km"]))
	else:
		var area := rect.get_area() if is_rect else PI * radius * radius
		count = int(area / 10000.0 * float(region["per_hectare"]))
	var clumping: float = region.get("clumping", 0.0)
	# The kinds as a running total of their weights, to pick one by a throw.
	var names: Array = []
	var totals: Array[float] = []
	var total := 0.0
	for kind in region["kinds"]:
		total += float(region["kinds"][kind])
		names.append(kind)
		totals.append(total)
	var planted := 0
	for i in count:
		var p: Vector2
		if along_roads:
			p = _beside_road(rng.randf() * road_total, rng.randf() < 0.5, rng.randf(), region["offset"], road_lengths)
		elif is_rect:
			p = rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		else:
			p = center + Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
		# Every throw is made before any test, so moving a road or a clearing
		# removes the trees it covers and leaves the rest where they stood.
		var throw := rng.randf() * total
		var size_t := rng.randf()
		var yaw := rng.randf() * TAU
		var squash := rng.randf_range(0.88, 1.16)
		var tint := rng.randf_range(0.84, 1.1)
		var warm := rng.randf_range(-0.05, 0.05)
		if clumping > 0.0 and clump.get_noise_2d(p.x, p.y) * 0.5 + 0.5 < clumping * 0.72:
			continue
		if is_blocked(p):
			continue
		# The scatter is a map's (p is east, north); the ground is the world's.
		var w := ZoneLayout.to_world_xz(p)
		if terrain.slope_at(w.x, w.y) > MAX_SLOPE:
			continue
		var kind: String = names[names.size() - 1]
		for k in totals.size():
			if throw <= totals[k]:
				kind = names[k]
				break
		var info: Dictionary = KINDS[kind]
		var s := _size(info, size_t)
		if not info.get("squash", true):
			squash = 1.0
		var basis := Basis(Vector3.UP, yaw)
		if info.get("tumble", false):
			basis = basis * Basis(Vector3.RIGHT, (squash - 1.0) * 3.0)
		basis = basis.scaled(Vector3(s, s * squash, s))
		var ground := terrain.height_at(w.x, w.y) - float(info["sink"]) * s
		var cell := Vector2i(int(floor(w.x / CELL)), int(floor(w.y / CELL)))
		var chosen := cell_variants(cell, kind)
		var variant: int = chosen[posmod(spot_hash(w), chosen.size())]
		var key := "%d,%d,%s" % [cell.x, cell.y, kind]
		if not buckets.has(key):
			buckets[key] = {"cell": cell, "kind": kind, "variants": {}}
		var by_variant: Dictionary = buckets[key]["variants"]
		if not by_variant.has(variant):
			by_variant[variant] = {"xf": [], "tint": PackedColorArray()}
		var bucket: Dictionary = by_variant[variant]
		bucket["xf"].append(Transform3D(basis, Vector3(w.x, ground, w.y)))
		bucket["tint"].append(Color(tint + warm, tint, tint - warm))
		planted += 1
	return planted


# The scale a planted thing grows to from its size throw (0 to 1).
static func _size(info: Dictionary, size_t: float) -> float:
	var scale_range: Vector2 = info["scale"]
	if info.get("colossal", false):
		if size_t > COLOSSAL_FROM:
			return lerpf(COLOSSAL_SCALE.x, COLOSSAL_SCALE.y, (size_t - COLOSSAL_FROM) / (1.0 - COLOSSAL_FROM))
		return lerpf(scale_range.x, scale_range.y, size_t / COLOSSAL_FROM)
	return lerpf(scale_range.x, scale_range.y, size_t * size_t if info.get("tumble", false) else size_t)


# A map point `along` metres down the roads (taken end to end), on the left or
# right, `offset_t` (0 to 1) of the way through `offset` past the verge.
func _beside_road(along: float, left: bool, offset_t: float, offset: Vector2, lengths: Array[float]) -> Vector2:
	var k := lengths.bsearch(along)
	var n := 0
	for curve in _curves:
		var pts: PackedVector2Array = curve["points"]
		if k < n + pts.size() - 1:
			var a := pts[k - n]
			var b := pts[k - n + 1]
			var start := 0.0 if k == 0 else lengths[k - 1]
			var t := clampf((along - start) / maxf(a.distance_to(b), 0.0001), 0.0, 1.0)
			var side := (b - a).orthogonal().normalized() * (1.0 if left else -1.0)
			var reach: float = float(curve["half_width"]) + ZoneLayout.ROAD_MARGIN + lerpf(offset.x, offset.y, offset_t)
			return a.lerp(b, t) + side * reach
		n += pts.size() - 1
	return Vector2.ZERO


# Which of a kind's variants grow in a cell: all of them when there are few
# enough, else MAX_VARIANTS_PER_CELL picked by the cell itself.
static func cell_variants(cell: Vector2i, kind: String) -> Array:
	var variants: Array = KINDS[kind]["variants"]
	if variants.size() <= MAX_VARIANTS_PER_CELL:
		return variants
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d,%d,%s" % [cell.x, cell.y, kind])
	var pool := variants.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var chosen := pool.slice(0, MAX_VARIANTS_PER_CELL)
	chosen.sort()
	return chosen


# A number from where a thing stands (world x, z, to the millimetre): the
# same spot always gives the same number, on every client.
static func spot_hash(w: Vector2) -> int:
	return hash(Vector2i(roundi(w.x * 1000.0), roundi(w.y * 1000.0)))


# Where everything stands (world positions), in the order it was planted.
func planted() -> PackedVector3Array:
	return _planted


# The kind of everything planted ("pine#2": the kind, then its model's
# variant), and its world transform, in that same order.
func placed_kinds() -> PackedStringArray:
	return _placed_kinds


func placed_transforms() -> Array[Transform3D]:
	return _placed_transforms


# The solids a planted kind ("pine#2") is made of, in the model's own space:
# what one planted thing puts in a body's way.
static func kind_volumes(placed_kind: String) -> Array:
	var kind := placed_kind.get_slice("#", 0)
	return SceneryModels.volumes(KINDS[kind]["model"], int(placed_kind.get_slice("#", 1)))


# How the obstacle bake makes a planted kind's solids (see KINDS).
static func bake_mode(placed_kind: String) -> String:
	return KINDS[placed_kind.get_slice("#", 0)]["bake"]


# One (cell, kind) bucket at the (world) cell's middle: a MultiMesh per
# variant, and one of the kind's far stand-in past its `near` distance.
func _emit(key: String, bucket: Dictionary, terrain: TerrainMesh) -> void:
	var kind: String = bucket["kind"]
	var info: Dictionary = KINDS[kind]
	var cell: Vector2i = bucket["cell"]
	var mid := Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)
	var origin := terrain.position + Vector3(mid.x, terrain.height_at(mid.x, mid.y), mid.y)
	var near: float = info["near"]
	var by_variant: Dictionary = bucket["variants"]
	var far_xf: Array[Transform3D] = []
	var far_tint := PackedColorArray()
	for variant in by_variant:
		var placements: Array = by_variant[variant]["xf"]
		var tints: PackedColorArray = by_variant[variant]["tint"]
		var fit := _far_fit(info, variant) if info.has("far") else Transform3D.IDENTITY
		var mm := _multimesh(SceneryModels.mesh(info["model"], variant), placements.size())
		for i in placements.size():
			var xf: Transform3D = placements[i]
			_planted.append(terrain.position + xf.origin)
			_placed_kinds.append("%s#%d" % [kind, variant])
			_placed_transforms.append(Transform3D(xf.basis, terrain.position + xf.origin))
			xf.origin += terrain.position - origin
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, tints[i])
			far_xf.append(xf * fit)
			far_tint.append(tints[i])
		var mmi := _instance("%s_%d" % [key.replace(",", "_"), variant], mm, origin)
		mmi.material_override = LowPoly.solid_material()
		mmi.visibility_range_end = near
		add_child(mmi)
	if info.has("far"):
		var mm := _multimesh(_mesh(info["far"]), far_xf.size())
		for i in far_xf.size():
			mm.set_instance_transform(i, far_xf[i])
			mm.set_instance_color(i, far_tint[i])
		var mmi := _instance("%s_far" % key.replace(",", "_"), mm, origin)
		mmi.visibility_range_begin = near
		mmi.visibility_range_end = info["end"]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


static func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm


static func _instance(node_name: String, mm: MultiMesh, origin: Vector3) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.position = origin
	return mmi


# Where a variant's far stand-in (built a unit cone or ball) goes, in the
# model's own space: over what the variant has above CROWN_FROM (all of it,
# for a kind with no crown), so a far tree is the size of the near one.
static func _far_fit(info: Dictionary, variant: int) -> Transform3D:
	var from := CROWN_FROM if info["bake"] == "trunk" else -INF
	var box := SceneryModels.bounds_above(info["model"], variant, from)
	var mid := box.get_center()
	if info["far_fit"] == "cone":
		var r := maxf(box.size.x, box.size.z) * 0.5
		return Transform3D(Basis.from_scale(Vector3(r, box.size.y, r)), Vector3(mid.x, box.position.y, mid.z))
	return Transform3D(Basis.from_scale(box.size * 0.5), mid)


# --- The far stand-ins ---------------------------------------------------

func _mesh(mesh_name: String) -> Mesh:
	if not _meshes.has(mesh_name):
		_meshes[mesh_name] = _build(mesh_name).mesh()
	return _meshes[mesh_name]


# A far stand-in, built at unit size (a cone on the origin one high and one
# round, or a ball one round) for _far_fit to size to each variant.
static func _build(mesh_name: String) -> LowPoly:
	var b := LowPoly.new(hash(mesh_name))
	b.jitter = 0.0
	match mesh_name:
		"pine_far":
			b.cone(LowPoly.at(Vector3.ZERO), 1.0, 1.0, 5, PINE_GREEN)
		"tall_pine_far":
			b.cone(LowPoly.at(Vector3.ZERO), 1.0, 1.0, 5, PINE_GREEN.darkened(0.06))
		"crown_far":
			b.blob(LowPoly.at(Vector3.ZERO), Vector3.ONE, 0.15, LEAF_GREEN)
		"dark_crown_far":
			b.blob(LowPoly.at(Vector3.ZERO), Vector3.ONE, 0.15, DARK_LEAF)
		"skeleton_far":
			b.blob(LowPoly.at(Vector3.ZERO), Vector3.ONE, 0.1, BONE)
		_:
			push_error("ZoneFlora: no far stand-in called %s" % mesh_name)
	return b
