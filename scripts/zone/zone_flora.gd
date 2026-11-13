class_name ZoneFlora
extends Node3D

# The zone's trees, bushes, boulders and bones: scattered at load from
# data/zone_layout.gd's SCATTER regions, the same on every client (each region
# is seeded by its name), standing on the TerrainMesh's ground. Every kind is
# one small LowPoly mesh drawn many times: the things in a CELL-metre square
# of one kind are one MultiMesh, so 25,000 trees are a few hundred draw calls,
# and a far tree is a five-triangle cone until the camera is near.
#
# Scenery only: nothing here collides, and the server knows none of it (it
# knows the ground). Keep it that way until the server has obstacles: a trunk
# the client stopped at the server would walk through, and the two would
# disagree about where the player stands.

# The scatter is bucketed into squares this wide; each is culled as one.
const CELL := 250.0
# Roads and clearings are looked up in a grid of squares this wide.
const BLOCK_CELL := 100.0
# Nothing grows on ground steeper than this (rise over run: about 40 degrees).
const MAX_SLOPE := 0.84
# The clumping noise's wavelength, metres: how big a glade is.
const CLUMP_WAVELENGTH := 150.0

const BARK := Color(0.33, 0.25, 0.18)
const PINE_GREEN := Color(0.14, 0.27, 0.17)
const LEAF_GREEN := Color(0.28, 0.40, 0.17)
const DARK_LEAF := Color(0.14, 0.20, 0.15)
const DEAD_WOOD := Color(0.37, 0.33, 0.29)
const BUSH_GREEN := Color(0.24, 0.35, 0.16)
const SCRUB := Color(0.43, 0.42, 0.22)
const STONE := Color(0.47, 0.46, 0.44)
const BONE := Color(0.84, 0.81, 0.70)

# What grows. `scale` is the range of sizes; `near` is how far the full mesh
# is drawn; a kind with a `far` mesh is drawn as that from `near` out to `end`.
const KINDS := {
	"pine": {"scale": Vector2(0.9, 1.6), "near": 380.0, "far": "pine_far", "end": 2000.0, "sink": 0.2},
	"tall_pine": {"scale": Vector2(0.9, 1.5), "near": 380.0, "far": "tall_pine_far", "end": 2000.0, "sink": 0.2},
	"broadleaf": {"scale": Vector2(0.8, 1.4), "near": 380.0, "far": "crown_far", "end": 1600.0, "sink": 0.2},
	"dark_tree": {"scale": Vector2(0.9, 1.5), "near": 380.0, "far": "dark_crown_far", "end": 1400.0, "sink": 0.2},
	"dead_tree": {"scale": Vector2(0.7, 1.4), "near": 900.0, "sink": 0.2},
	"bush": {"scale": Vector2(0.7, 1.5), "near": 420.0, "sink": 0.1},
	"scrub": {"scale": Vector2(0.6, 1.4), "near": 360.0, "sink": 0.05},
	"boulder": {"scale": Vector2(0.5, 2.6), "near": 1000.0, "sink": 0.25, "tumble": true},
	"bones": {"scale": Vector2(0.7, 1.6), "near": 450.0, "sink": 0.05},
}

@export var terrain_path := NodePath("../TerrainMesh")

var _meshes: Dictionary = {}
var _block_grid: Dictionary = {}
var _curves: Array = []
var _grown_fields: Array[Rect2] = []


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
	if not Engine.is_editor_hint():
		DebugLog.info("ZoneFlora: %d things in %d batches, %d ms" % [planted, buckets.size(), Time.get_ticks_msec() - started])


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


func _is_blocked(p: Vector2) -> bool:
	if maxf(absf(p.x), absf(p.y)) > ZoneLayout.RIM_START:
		return true
	if p.length_squared() < ZoneLayout.TOWN_CLEARING * ZoneLayout.TOWN_CLEARING:
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

# Plants one region into `buckets`; returns how many things it planted.
func _scatter(region: Dictionary, terrain: TerrainMesh, clump: FastNoiseLite, buckets: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region["name"])
	var is_rect := region.has("rect")
	var rect: Rect2 = region.get("rect", Rect2())
	var center: Vector2 = region.get("center", Vector2.ZERO)
	var radius: float = region.get("radius", 0.0)
	var area := rect.get_area() if is_rect else PI * radius * radius
	var count := int(area / 10000.0 * float(region["per_hectare"]))
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
		if is_rect:
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
		if _is_blocked(p):
			continue
		if terrain.slope_at(p.x, p.y) > MAX_SLOPE:
			continue
		var kind: String = names[names.size() - 1]
		for k in totals.size():
			if throw <= totals[k]:
				kind = names[k]
				break
		var info: Dictionary = KINDS[kind]
		var scale_range: Vector2 = info["scale"]
		var s := lerpf(scale_range.x, scale_range.y, size_t * size_t if info.get("tumble", false) else size_t)
		var basis := Basis(Vector3.UP, yaw)
		if info.get("tumble", false):
			basis = basis * Basis(Vector3.RIGHT, (squash - 1.0) * 3.0)
		basis = basis.scaled(Vector3(s, s * squash, s))
		var ground := terrain.height_at(p.x, p.y) - float(info["sink"]) * s
		var cell := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
		var key := "%d,%d,%s" % [cell.x, cell.y, kind]
		if not buckets.has(key):
			buckets[key] = {"cell": cell, "kind": kind, "xf": [], "tint": PackedColorArray()}
		var bucket: Dictionary = buckets[key]
		bucket["xf"].append(Transform3D(basis, Vector3(p.x, ground, p.y)))
		bucket["tint"].append(Color(tint + warm, tint, tint - warm))
		planted += 1
	return planted


# One (cell, kind) bucket as a MultiMesh at the cell's middle, and a second
# one of the kind's far mesh past its `near` distance.
func _emit(key: String, bucket: Dictionary, terrain: TerrainMesh) -> void:
	var kind: String = bucket["kind"]
	var info: Dictionary = KINDS[kind]
	var cell: Vector2i = bucket["cell"]
	var mid := Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)
	var origin := terrain.position + Vector3(mid.x, terrain.height_at(mid.x, mid.y), mid.y)
	var placements: Array = bucket["xf"]
	var tints: PackedColorArray = bucket["tint"]
	var near: float = info["near"]
	var has_far: bool = info.has("far")
	for far in ([false, true] if has_far else [false]):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh(info["far"] if far else kind)
		mm.instance_count = placements.size()
		for i in placements.size():
			var xf: Transform3D = placements[i]
			xf.origin += terrain.position - origin
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, tints[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s%s" % [key.replace(",", "_"), "_far" if far else ""]
		mmi.multimesh = mm
		mmi.position = origin
		if far:
			mmi.visibility_range_begin = near
			mmi.visibility_range_end = info["end"]
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mmi.visibility_range_end = near
		add_child(mmi)


# --- The meshes ----------------------------------------------------------

func _mesh(mesh_name: String) -> Mesh:
	if not _meshes.has(mesh_name):
		_meshes[mesh_name] = _build_mesh(mesh_name)
	return _meshes[mesh_name]


static func _build_mesh(mesh_name: String) -> Mesh:
	var b := LowPoly.new(hash(mesh_name))
	var up := Vector3.UP
	match mesh_name:
		"pine":
			b.column(LowPoly.at(Vector3.ZERO), 0.30, 0.16, 2.8, 5, BARK)
			for i in 3:
				b.cone(LowPoly.at(up * (1.6 + i * 2.3), i * 0.6), 2.5 - i * 0.65, 3.5, 6, PINE_GREEN.lightened(0.05 * i))
		"pine_far":
			b.jitter = 0.0
			b.cone(LowPoly.at(up * 1.5), 2.4, 8.2, 5, PINE_GREEN)
		"tall_pine":
			b.column(LowPoly.at(Vector3.ZERO), 0.36, 0.15, 5.4, 5, BARK)
			for i in 4:
				b.cone(LowPoly.at(up * (3.4 + i * 2.6), i * 0.5), 2.4 - i * 0.48, 3.8, 6, PINE_GREEN.darkened(0.08).lightened(0.05 * i))
		"tall_pine_far":
			b.jitter = 0.0
			b.cone(LowPoly.at(up * 3.2), 2.3, 12.0, 5, PINE_GREEN.darkened(0.06))
		"broadleaf":
			b.column(LowPoly.at(Vector3.ZERO), 0.42, 0.26, 3.6, 6, BARK)
			b.blob(LowPoly.at(up * 5.6), Vector3(3.2, 2.5, 3.2), 0.22, LEAF_GREEN)
			b.blob(LowPoly.at(Vector3(1.7, 4.5, 0.9)), Vector3(2.1, 1.7, 2.1), 0.24, LEAF_GREEN.darkened(0.08))
			b.blob(LowPoly.at(Vector3(-1.5, 4.9, -1.0)), Vector3(1.9, 1.6, 1.9), 0.24, LEAF_GREEN.lightened(0.05))
		"crown_far":
			b.jitter = 0.0
			b.blob(LowPoly.at(up * 5.2), Vector3(3.3, 2.6, 3.3), 0.15, LEAF_GREEN)
		"dark_tree":
			b.column(LowPoly.leaning(Vector3.ZERO, 0.7, 0.12), 0.5, 0.26, 4.4, 5, DEAD_WOOD.darkened(0.25))
			b.blob(LowPoly.at(Vector3(0.5, 5.6, 0.4)), Vector3(3.8, 1.9, 3.6), 0.3, DARK_LEAF)
			b.blob(LowPoly.at(Vector3(-1.8, 4.6, -1.2)), Vector3(2.2, 1.3, 2.2), 0.3, DARK_LEAF.lightened(0.05))
			# Web hanging off the crown.
			b.sheet(Vector3(2.6, 5.0, 0.4), Vector3(0.8, 4.9, 2.4), Vector3(0.9, 2.4, 1.8), Vector3(2.2, 2.9, 0.6), Color(0.78, 0.80, 0.80))
		"dark_crown_far":
			b.jitter = 0.0
			b.blob(LowPoly.at(up * 5.4), Vector3(3.8, 2.0, 3.6), 0.15, DARK_LEAF)
		"dead_tree":
			b.column(LowPoly.leaning(Vector3.ZERO, 0.0, 0.06), 0.34, 0.12, 5.6, 5, DEAD_WOOD)
			b.column(LowPoly.leaning(up * 2.8, 0.4, 0.95), 0.12, 0.03, 2.4, 4, DEAD_WOOD)
			b.column(LowPoly.leaning(up * 3.7, 2.6, 0.85), 0.11, 0.03, 2.1, 4, DEAD_WOOD)
			b.column(LowPoly.leaning(up * 4.5, 4.4, 0.7), 0.09, 0.02, 1.7, 4, DEAD_WOOD)
		"bush":
			b.blob(LowPoly.at(up * 0.7), Vector3(1.15, 0.85, 1.15), 0.25, BUSH_GREEN)
			b.blob(LowPoly.at(Vector3(0.8, 0.5, 0.4)), Vector3(0.7, 0.55, 0.7), 0.25, BUSH_GREEN.lightened(0.07))
		"scrub":
			b.blob(LowPoly.at(up * 0.4), Vector3(0.9, 0.5, 0.9), 0.3, SCRUB)
			b.cone(LowPoly.leaning(Vector3(0.2, 0.3, 0.1), 1.0, 0.4), 0.12, 1.0, 3, SCRUB.darkened(0.2))
			b.cone(LowPoly.leaning(Vector3(-0.2, 0.3, 0.0), 3.6, 0.5), 0.1, 0.9, 3, SCRUB.darkened(0.25))
		"boulder":
			b.blob(LowPoly.at(up * 0.55), Vector3(1.25, 0.85, 1.05), 0.26, STONE)
		"bones":
			# A ribcage half sunk in the ground, and a skull beside it.
			for i in 4:
				var z := -0.9 + i * 0.6
				b.column(LowPoly.leaning(Vector3(-0.55, 0.0, z), PI * 0.5, -0.5), 0.07, 0.03, 1.3, 4, BONE)
				b.column(LowPoly.leaning(Vector3(0.55, 0.0, z), PI * 0.5, 0.5), 0.07, 0.03, 1.3, 4, BONE)
			b.column(LowPoly.leaning(Vector3(0.0, 0.12, -1.2), 0.0, PI * 0.5), 0.09, 0.07, 2.4, 4, BONE.darkened(0.08))
			b.blob(LowPoly.at(Vector3(0.3, 0.28, 1.7)), Vector3(0.34, 0.3, 0.4), 0.12, BONE)
		_:
			push_error("ZoneFlora: no mesh called %s" % mesh_name)
	return b.mesh()
