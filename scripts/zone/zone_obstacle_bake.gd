class_name ZoneObstacleBake
extends RefCounted

# Makes the zone's obstacle data (zone_obstacles.gd) from the scenery as it is
# built: every solid the town's and the landmarks' pieces recorded
# (LowPoly.volumes) and every planted tree, bush, boulder and bone (its
# model's solids, SceneryModels). A solid's
# boundary is its own shape: the outline of its corners seen from above, with
# the height of its lowest and highest corner. Nothing is drawn by hand, so a
# piece that changes shape changes its boundary with it.
#
# tools/export_obstacles.gd writes what this returns for both sides;
# tools/check_obstacle_lockstep.gd bakes again and fails when the files differ.

# A solid stands in a body's way when it comes down to within this of the
# ground under it (a crown, a roof's overhang and a gate's lintel do not)...
const WALK_REACH := 1.0
# ...and rises at least this far above it (anything lower is stepped over).
const WALK_MIN_HEIGHT := 0.3
# A solid blocks a line of sight when it is at least this wide at its
# narrowest (a banner's pole and a fence's rail hide nothing)...
const SIGHT_MIN_WIDTH := 0.3
# ...and has at least this much of itself above the ground.
const SIGHT_MIN_HEIGHT := 0.3
# An outline smaller than this (square metres) is no solid at all.
const MIN_AREA := 0.0004
# Everything is rounded to a millimetre before it is written.
const SNAP := 0.001
# A bush or a rock ("merge", see flora_groups) is at most two prisms: its foot
# (the solids that start under this height, on a thing of scale 1) and its
# crown (the rest), each the outline of its solids taken together.
const FLORA_SPLIT := 1.0
const DRESSING_NODES := ["Town", "Landmarks"]


# The zone's obstacle file from a built world scene. Returns a dictionary:
# "bytes" (the file), "count", "walk", "sight" (prisms holding each flag),
# "sources" (prism count by what made them), or "error".
static func bake(world: Node) -> Dictionary:
	var terrain := world.get_node_or_null("TerrainMesh") as TerrainMesh
	if terrain == null:
		return {"error": "the scene has no TerrainMesh"}
	var floats := PackedFloat32Array()
	var stats := {"count": 0, "walk": 0, "sight": 0, "sources": {}}
	for dressing_name in DRESSING_NODES:
		var node := world.get_node_or_null(dressing_name) as ZoneDressing
		if node == null:
			return {"error": "the scene has no %s node" % dressing_name}
		var xf := node.global_transform
		for v in node.volumes():
			_emit(floats, stats, dressing_name, xf * (v[0] as PackedVector3Array), v[1], terrain)
	var flora := world.get_node_or_null("Flora") as ZoneFlora
	if flora == null:
		return {"error": "the scene has no Flora node"}
	var groups_of: Dictionary = {}
	var kinds := flora.placed_kinds()
	var transforms := flora.placed_transforms()
	for i in kinds.size():
		var kind := kinds[i]
		if not groups_of.has(kind):
			groups_of[kind] = flora_groups(ZoneFlora.kind_volumes(kind), ZoneFlora.bake_mode(kind))
		var source := kind.get_slice("#", 0)
		for group in groups_of[kind]:
			_emit(floats, stats, source, transforms[i] * (group[0] as PackedVector3Array), group[1], terrain)
	stats["bytes"] = ZoneObstacles.encode_file(stats["count"], floats)
	return stats


# One planted kind's solids as the prisms the bake makes of them, in the
# kind's own space: a list of [corners, sight scale]. By `mode`:
#   "merge"   a bush or a rock: its foot and its crown (see FLORA_SPLIT).
#   "trunk"   a tree: every piece that starts under ZoneFlora.CROWN_FROM on
#             its own (the trunk's lengths, so a bent trunk walls nothing
#             off), and the rest as one crown. Merged with the trunk, a crown
#             would come down to the trunk's middle, and on a small tree that
#             is low enough for the whole crown to stop a body.
#   "pieces"  bones: every piece on its own, so a body steps over the low ones.
# A crown keeps only solids wide enough to hide something (bare branches do not).
static func flora_groups(volumes: Array, mode: String = "merge") -> Array:
	if mode == "pieces":
		return volumes.duplicate()
	var split := ZoneFlora.CROWN_FROM if mode == "trunk" else FLORA_SPLIT
	var out: Array = []
	var foot := PackedVector3Array()
	var crown := PackedVector3Array()
	var foot_scale := 1.0
	var crown_scale := 1.0
	for v in volumes:
		var pts: PackedVector3Array = v[0]
		var lowest := INF
		var flat := PackedVector2Array()
		for p in pts:
			lowest = minf(lowest, p.y)
			flat.append(Vector2(p.x, p.z))
		if lowest < split:
			if mode == "trunk":
				out.append(v)
			else:
				foot.append_array(pts)
				foot_scale = minf(foot_scale, v[1])
		elif min_width(convex_hull(flat)) >= SIGHT_MIN_WIDTH:
			crown.append_array(pts)
			crown_scale = minf(crown_scale, v[1])
	if not foot.is_empty():
		out.append([_unique(foot), foot_scale])
	if not crown.is_empty():
		out.append([_unique(crown), crown_scale])
	return out


static func _unique(pts: PackedVector3Array) -> PackedVector3Array:
	var seen: Dictionary = {}
	var out := PackedVector3Array()
	for p in pts:
		if not seen.has(p):
			seen[p] = true
			out.append(p)
	return out


# One solid (its corners in world space) as a prism, if it is one.
static func _emit(floats: PackedFloat32Array, stats: Dictionary, source: String, pts: PackedVector3Array, sight_scale: float, terrain: TerrainMesh) -> void:
	var base := INF
	var top := -INF
	var flat := PackedVector2Array()
	for p in pts:
		base = minf(base, p.y)
		top = maxf(top, p.y)
		flat.append(Vector2(snappedf(p.x, SNAP), snappedf(p.z, SNAP)))
	var hull := convex_hull(flat)
	if hull.size() < 3 or area(hull) < MIN_AREA:
		return
	var mid := Vector2.ZERO
	for c in hull:
		mid += c
	mid /= hull.size()
	var origin := terrain.global_position
	var ground := origin.y + terrain.height_at(mid.x - origin.x, mid.y - origin.z)
	var flags := 0
	if base < ground + WALK_REACH and top >= ground + WALK_MIN_HEIGHT:
		flags |= ZoneObstacles.FLAG_WALK
	if min_width(hull) >= SIGHT_MIN_WIDTH and top - maxf(base, ground) >= SIGHT_MIN_HEIGHT:
		flags |= ZoneObstacles.FLAG_SIGHT
	if flags == 0:
		return
	floats.append_array(ZoneObstacles.encode_prism(flags, snappedf(base, SNAP), snappedf(top, SNAP), snappedf(sight_scale, SNAP), hull))
	stats["count"] += 1
	if flags & ZoneObstacles.FLAG_WALK:
		stats["walk"] += 1
	if flags & ZoneObstacles.FLAG_SIGHT:
		stats["sight"] += 1
	stats["sources"][source] = int(stats["sources"].get(source, 0)) + 1


# --- Outlines ------------------------------------------------------------

# The convex outline of a set of points, counter-clockwise (x to the right,
# the second coordinate up), with no three corners in a line.
static func convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	var pts := points.duplicate()
	pts.sort()
	var unique := PackedVector2Array()
	for p in pts:
		if unique.is_empty() or unique[unique.size() - 1] != p:
			unique.append(p)
	if unique.size() < 3:
		return unique
	var lower := PackedVector2Array()
	for p in unique:
		while lower.size() >= 2 and _turn(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.remove_at(lower.size() - 1)
		lower.append(p)
	var upper := PackedVector2Array()
	for k in range(unique.size() - 1, -1, -1):
		var p := unique[k]
		while upper.size() >= 2 and _turn(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.remove_at(upper.size() - 1)
		upper.append(p)
	lower.remove_at(lower.size() - 1)
	upper.remove_at(upper.size() - 1)
	lower.append_array(upper)
	return lower


# Twice the signed area of the triangle a, b, c: positive when c is to the
# left of the line from a to b. In doubles, so corners a millimetre apart on
# a line 100 m long still read as a line.
static func _turn(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (float(b.x) - float(a.x)) * (float(c.y) - float(a.y)) - (float(b.y) - float(a.y)) * (float(c.x) - float(a.x))


static func area(hull: PackedVector2Array) -> float:
	var twice := 0.0
	for i in hull.size():
		var a := hull[i]
		var b := hull[(i + 1) % hull.size()]
		twice += float(a.x) * float(b.y) - float(b.x) * float(a.y)
	return absf(twice) * 0.5


# How wide a convex outline is at its narrowest: the least, over its edges, of
# how far its furthest corner stands from that edge's line.
static func min_width(hull: PackedVector2Array) -> float:
	if hull.size() < 3:
		return 0.0
	var narrowest := INF
	for i in hull.size():
		var a := hull[i]
		var e := hull[(i + 1) % hull.size()] - a
		var length := e.length()
		if length <= 0.0:
			continue
		var normal := Vector2(e.y, -e.x) / length
		var widest := 0.0
		for c in hull:
			widest = maxf(widest, absf((c - a).dot(normal)))
		narrowest = minf(narrowest, widest)
	return narrowest
