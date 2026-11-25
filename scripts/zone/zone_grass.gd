class_name ZoneGrass
extends Node3D

# The zone's grass: tufts (the grass models, SceneryModels) grown only round
# the camera, a CELL-metre square at a time, and faded out by distance past
# FADE_FROM. A square grows the same tufts every time (its own dice, seeded by
# where it is), so every client sees the same grass and a square dropped and
# grown again comes back as it was. The grass never touches ZoneFlora's dice,
# so no tree moves for it.
#
# Where it grows and how thick is data/zone_layout.gd's (GRASS_PER_M2,
# GRASS_PATCHES); it keeps off the ground the flora keeps off
# (ZoneFlora.is_blocked). Drawn only: grass blocks nothing, hides no body worth
# hiding, and is not in the obstacle data. Nothing grows while there is no
# camera (headless tools call grow_cell themselves).

const CELL := 32.0
# Tufts fade out between these distances from the camera (metres).
const FADE_FROM := 48.0
const RANGE := 60.0
# A square is grown when its middle comes within RANGE plus this of the
# camera, and dropped past RANGE plus DROP_MARGIN (so standing on a square's
# edge does not grow and drop it over and over).
const GROW_MARGIN := 24.0
const DROP_MARGIN := 40.0
# At most this many squares grow in one frame.
const GROWN_PER_FRAME := 2
# A square draws at most this many of the grass variants.
const VARIANTS_PER_CELL := 3
const VARIANTS := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const SCALE := Vector2(0.8, 1.35)
const SINK := 0.02
# A dry patch's grass is tinted by this (straw from green).
const DRY_TINT := Color(1.35, 1.08, 0.58)
# The ground follows the terrain shader (assets/materials/terrain.gdshader):
# grass-green low, tan by TINT_TOP metres up (its tint_top), so the grass dries
# as it climbs and keeps HIGH_SHARE of itself at the top; where a slope turns
# to rock (the cosine of its angle from ROCK_FROM down to ROCK_FULL, the
# shader's numbers) it thins to nothing.
const TINT_TOP := 110.0
const HIGH_SHARE := 0.5
const ROCK_FROM := 0.80
const ROCK_FULL := 0.60
# A camp's worn ground (ZoneLayout.SITE_GROUND) keeps this much grass, fading
# in over this share of its radius.
const WORN_SHARE := 0.08
const WORN_FEATHER := 0.3

@export var terrain_path := NodePath("../TerrainMesh")
@export var flora_path := NodePath("../Flora")

static var _material: StandardMaterial3D

var _terrain: TerrainMesh
var _flora: ZoneFlora
# The squares grown, by cell: the node holding their MultiMeshes.
var _grown: Dictionary = {}
var _camera_cell := Vector2i(1 << 30, 0)
var _queue: Array[Vector2i] = []


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as TerrainMesh
	_flora = get_node_or_null(flora_path) as ZoneFlora


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _terrain == null or _flora == null:
		return
	var at := camera.global_position - _terrain.global_position
	var cell := Vector2i(int(floor(at.x / CELL)), int(floor(at.z / CELL)))
	if cell != _camera_cell:
		_camera_cell = cell
		_replan(Vector2(at.x, at.z))
	var grown := 0
	while not _queue.is_empty() and grown < GROWN_PER_FRAME:
		var next: Vector2i = _queue.pop_front()
		if not _grown.has(next):
			_add(next, grow_cell(next))
			grown += 1


# What to grow and drop for a camera at `at` (world x, z under the terrain).
func _replan(at: Vector2) -> void:
	for cell in _grown.keys():
		if _middle(cell).distance_to(at) > RANGE + DROP_MARGIN:
			(_grown[cell] as Node).queue_free()
			_grown.erase(cell)
	_queue.clear()
	var reach := int(ceil((RANGE + GROW_MARGIN) / CELL))
	var wanted: Array = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := _camera_cell + Vector2i(dx, dz)
			var d := _middle(cell).distance_to(at)
			if d <= RANGE + GROW_MARGIN and not _grown.has(cell):
				wanted.append([d, cell])
	wanted.sort_custom(func(a, b): return a[0] < b[0])
	for w in wanted:
		_queue.append(w[1])


func _middle(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


func _add(cell: Vector2i, square: Node3D) -> void:
	_grown[cell] = square
	add_child(square)


# One square's grass: a node at the square's middle holding a MultiMesh per
# variant, in a fixed order. Empty (no children) where nothing grows. Its meta
# "tufts" is where every tuft stands (world positions), for
# tools/check_zone_scenery.gd: a MultiMesh cannot be read back headless.
func grow_cell(cell: Vector2i) -> Node3D:
	var square := Node3D.new()
	square.name = "Grass_%d_%d" % [cell.x, cell.y]
	var mid := _middle(cell)
	var origin := Vector3(mid.x, _terrain.height_at(mid.x, mid.y), mid.y)
	square.position = _terrain.position + origin
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("grass %d,%d" % [cell.x, cell.y])
	var chosen := _choose(rng)
	var patches := _patches_near(mid)
	var by_variant: Dictionary = {}
	var tufts := PackedVector3Array()
	var count := int(CELL * CELL * ZoneLayout.GRASS_PER_M2)
	for i in count:
		# Every throw first, as the flora does, so a change of rule thins the
		# grass without moving the rest.
		var w := Vector2(cell.x * CELL + rng.randf() * CELL, cell.y * CELL + rng.randf() * CELL)
		var keep := rng.randf()
		var pick := rng.randi_range(0, chosen.size() - 1)
		var yaw := rng.randf() * TAU
		var s := rng.randf_range(SCALE.x, SCALE.y)
		var tint := rng.randf_range(0.82, 1.1)
		var p := ZoneLayout.to_map_xz(w)
		var share := _share(p, patches)
		# The patch alone already says no: skip reading the ground.
		if keep >= share.x:
			continue
		var slope := _terrain.slope_at(w.x, w.y)
		if slope > ZoneFlora.MAX_SLOPE or _flora.is_blocked(p):
			continue
		var ground := _terrain.height_at(w.x, w.y)
		var high := clampf(ground / TINT_TOP, 0.0, 1.0)
		var rock := smoothstep(ROCK_FROM, ROCK_FULL, 1.0 / sqrt(1.0 + slope * slope))
		if keep >= share.x * lerpf(1.0, HIGH_SHARE, high) * (1.0 - rock):
			continue
		share.y = maxf(share.y, high)
		var y := ground - SINK * s
		var variant: int = chosen[pick]
		if not by_variant.has(variant):
			by_variant[variant] = [[], PackedColorArray()]
		var colour := Color(tint, tint, tint)
		if share.y > 0.0:
			colour = colour.lerp(Color(tint * DRY_TINT.r, tint * DRY_TINT.g, tint * DRY_TINT.b), share.y)
		by_variant[variant][0].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(w.x, y, w.y) - origin))
		by_variant[variant][1].append(colour)
		tufts.append(_terrain.position + Vector3(w.x, y, w.y))
	for variant in chosen:
		if not by_variant.has(variant):
			continue
		var xfs: Array = by_variant[variant][0]
		var colours: PackedColorArray = by_variant[variant][1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = SceneryModels.mesh("grass", variant)
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, colours[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "v%d" % variant
		mmi.multimesh = mm
		mmi.material_override = material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = RANGE + CELL
		square.add_child(mmi)
	square.set_meta("tufts", tufts)
	return square


# VARIANTS_PER_CELL of the variants, picked by the square's own dice.
func _choose(rng: RandomNumberGenerator) -> Array:
	var pool := VARIANTS.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var chosen := pool.slice(0, VARIANTS_PER_CELL)
	chosen.sort()
	return chosen


# The grass patches that may reach a square whose middle is `mid` (world x, z),
# and the camps' worn ground: each as [the patch (a rect, or a center and a
# radius), its share, whether it is dry, its feather].
func _patches_near(mid: Vector2) -> Array:
	var p := ZoneLayout.to_map_xz(mid)
	var reach := CELL * 0.75
	var out: Array = []
	for patch in ZoneLayout.GROUND_PATCHES:
		var rule = ZoneLayout.GRASS_PATCHES.get(patch["name"])
		if rule == null:
			continue
		var feather: float = patch["feather"]
		if patch.has("rect"):
			if not (patch["rect"] as Rect2).grow(reach).has_point(p):
				continue
		elif p.distance_to(patch["center"]) > float(patch["radius"]) + reach:
			continue
		out.append([patch, float(rule[0]), bool(rule[1]), feather])
	for site_name in ZoneLayout.SITE_GROUND:
		var at: Vector2 = ZoneLayout.SITES[site_name]
		var radius: float = ZoneLayout.SITE_GROUND[site_name][0]
		if p.distance_to(at) <= radius + reach:
			out.append([{"center": at, "radius": radius}, WORN_SHARE, false, radius * WORN_FEATHER])
	return out


# How much grass a map point keeps (x, 0 to 1) and how dry it is (y).
static func _share(p: Vector2, patches: Array) -> Vector2:
	var share := 1.0
	var dry := 0.0
	for entry in patches:
		var patch: Dictionary = entry[0]
		var inside: float
		if patch.has("rect"):
			var r: Rect2 = patch["rect"]
			inside = minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))
		else:
			inside = float(patch["radius"]) - p.distance_to(patch["center"])
		if inside <= 0.0:
			continue
		var w := clampf(inside / maxf(entry[3], 0.001), 0.0, 1.0)
		share = lerpf(share, entry[1], w)
		if entry[2]:
			dry = maxf(dry, w)
	return Vector2(share, dry)


# The grass's material: LowPoly's, fading each tuft out by its distance from
# the camera (dithered, so it needs no transparency).
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = LowPoly.solid_material().duplicate()
		_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		# Further out than in: a fade that thins with distance.
		_material.distance_fade_min_distance = RANGE
		_material.distance_fade_max_distance = FADE_FROM
	return _material
