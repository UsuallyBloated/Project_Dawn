class_name ZoneObstacles
extends RefCounted

# What stands in a body's way in the zone, and the rule for it. The client's
# copy of the server's `world/obstacles.rs`: the same data file, the same
# rule, the same numbers, so the body drawn here stops where the server stops
# it (the server moves every player; this is the prediction).
#
# The data (data/zone_obstacles.bin, written by tools/export_obstacles.gd) is
# a list of prisms. A prism is one solid of the scenery seen from above: a
# convex outline in world x and z, with the height of its lowest and highest
# point. Each carries two flags:
#   WALK   it stands in a body's way. For walking a prism is a column of any
#          height: nothing is stood on or jumped over.
#   SIGHT  it blocks a line of sight where the line passes through the
#          outline between its base and its top.
#
# The rule (`resolve`): a step is taken in short pieces; after each, a body
# whose centre is inside a WALK outline grown by the body's radius is moved
# out the shortest way, which keeps the part of the step along the surface
# and drops the part into it: a slide. A piece that cannot be settled ends
# the step where the body last stood free.
#
# Every constant marked "lockstep" is held equal to the server's by
# tools/check_constant_lockstep.gd, and the rule itself is held to the
# server's by tools/check_obstacle_rule.gd (the server's own answers, replayed).

const FILE_PATH := "res://data/zone_obstacles.bin"

# The file: a 12-byte header (magic, version, prism count, little-endian u32),
# then 32-bit floats (per prism: flags, base, top, sight scale, corner count,
# then x and z of each corner, counter-clockwise), then the SHA-256 of
# everything before it.
const MAGIC := 0x424F4450  # "PDOB"
const VERSION := 1
const HEADER_BYTES := 12
const HASH_BYTES := 32
const FLAG_WALK := 1
const FLAG_SIGHT := 2

# The rule's numbers (lockstep with world/obstacles.rs).
const BODY_RADIUS := 0.4
const CELL := 8.0
const SUBSTEP := 0.1
const PIECE_STRETCH := 1.5
const PASSES := 4
const CLEAR_PASSES := 16
const CLEAR_RING_STEP := 0.25
const CLEAR_RINGS := 160
# The directions tried on each ring, written out (not computed with a cosine)
# so this and every build of the server try exactly the same points. Sixteen
# ways round the compass, to two places: directions to look in.
const CLEAR_SPOKES: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(0.92, 0.38), Vector2(0.7, 0.7), Vector2(0.38, 0.92),
	Vector2(0.0, 1.0), Vector2(-0.38, 0.92), Vector2(-0.7, 0.7), Vector2(-0.92, 0.38),
	Vector2(-1.0, 0.0), Vector2(-0.92, -0.38), Vector2(-0.7, -0.7), Vector2(-0.38, -0.92),
	Vector2(0.0, -1.0), Vector2(0.38, -0.92), Vector2(0.7, -0.7), Vector2(0.92, -0.38),
]
const ESCAPE_REACH := 4.0
const ESCAPE_NEED := 3.0
const FREE_SLACK := 0.001
const DEFLECT_EPS := 0.0001

# Past this many grid cells under a sight line, every prism is tested instead.
const SIGHT_CELL_LIMIT := 1024

var _flags := PackedInt32Array()
var _base := PackedFloat32Array()
var _top := PackedFloat32Array()
var _scale := PackedFloat32Array()
# Where prism i's corners start in `_pts` (pairs of x, z), and how many it has.
var _first := PackedInt32Array()
var _count := PackedInt32Array()
var _pts := PackedFloat32Array()
# The corners drawn in towards the outline's middle by the prism's sight
# scale: what a line of sight is tested against.
var _sight_pts := PackedFloat32Array()
var _walk_cells: Dictionary = {}
var _sight_cells: Dictionary = {}
var _sight_all := PackedInt32Array()
var _hash_hex := ""

# Whether the last `resolve` was turned aside or stopped by anything.
var last_deflected := false

static var _shared: ZoneObstacles
static var _shared_tried := false


# The zone's obstacles as the running game uses them: read once from the
# exported file. Null, with an error logged, when the file is missing or
# damaged: the body then stops at nothing here while the server still stops
# it, which shows as being pulled back at every tree, so a build without the
# file is a broken build (tools/check_obstacle_lockstep.gd, EXPORT).
static func shared() -> ZoneObstacles:
	if not _shared_tried:
		_shared_tried = true
		var problem: Array = []
		_shared = load_file(FILE_PATH, problem)
		if _shared == null:
			push_error("ZoneObstacles: %s. Nothing in the zone will stop this client's body." % ", ".join(problem))
		# In the log beside the build stamp: the server's boot line prints the
		# same twelve digits for its copy, so a client and a server holding
		# different obstacles can be told apart from two logs. (The autoload
		# is looked up, never named: tools load this script with no autoloads.)
		var tree := Engine.get_main_loop() as SceneTree
		var debug_log: Node = tree.root.get_node_or_null("/root/DebugLog") if tree != null else null
		if debug_log != null:
			if _shared != null:
				debug_log.info("ZoneObstacles: %d prisms, hash %s" % [_shared.size(), _shared.hash_hex()])
			else:
				debug_log.error("ZoneObstacles: %s" % ", ".join(problem))
	return _shared


# --- Loading -------------------------------------------------------------

# The zone's obstacles from the exported file, or null (with the reason in
# `problem`) when the file is missing or damaged.
static func load_file(path: String = FILE_PATH, problem: Array = []) -> ZoneObstacles:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		problem.append("%s is missing or empty" % path)
		return null
	return from_bytes(bytes, problem)


static func from_bytes(bytes: PackedByteArray, problem: Array = []) -> ZoneObstacles:
	if bytes.size() < HEADER_BYTES + HASH_BYTES or (bytes.size() - HEADER_BYTES - HASH_BYTES) % 4 != 0:
		problem.append("the obstacle data is %d bytes: not a whole file" % bytes.size())
		return null
	if bytes.decode_u32(0) != MAGIC or bytes.decode_u32(4) != VERSION:
		problem.append("the obstacle data has the wrong magic or version")
		return null
	var body_end := bytes.size() - HASH_BYTES
	var digest := sha256(bytes.slice(0, body_end))
	if digest != bytes.slice(body_end):
		problem.append("the obstacle data does not match its own hash (edited by hand, or cut short)")
		return null
	var out := ZoneObstacles.new()
	out._hash_hex = digest.hex_encode().substr(0, 12)
	var declared := bytes.decode_u32(8)
	var f := bytes.slice(HEADER_BYTES, body_end).to_float32_array()
	var i := 0
	while i < f.size():
		if i + 5 > f.size():
			problem.append("the obstacle data ends inside a prism")
			return null
		var n := int(f[i + 4])
		if n < 3 or i + 5 + 2 * n > f.size():
			problem.append("a prism has %d corners" % n)
			return null
		out._add(int(f[i]), f[i + 1], f[i + 2], f[i + 3], f.slice(i + 5, i + 5 + 2 * n))
		i += 5 + 2 * n
	if out.size() != declared:
		problem.append("the obstacle data declares %d prisms and holds %d" % [declared, out.size()])
		return null
	return out


static func sha256(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()


# One prism as the file holds it (see the header): the bytes of its floats.
static func encode_prism(flags: int, base: float, top: float, sight_scale: float, corners: PackedVector2Array) -> PackedFloat32Array:
	var f := PackedFloat32Array([float(flags), base, top, sight_scale, float(corners.size())])
	for c in corners:
		f.append(c.x)
		f.append(c.y)
	return f


# A whole file from every prism's floats laid end to end.
static func encode_file(prism_count: int, floats: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(HEADER_BYTES)
	bytes.encode_u32(0, MAGIC)
	bytes.encode_u32(4, VERSION)
	bytes.encode_u32(8, prism_count)
	bytes.append_array(floats.to_byte_array())
	bytes.append_array(sha256(bytes))
	return bytes


func _add(flags: int, base: float, top: float, sight_scale: float, corners: PackedFloat32Array) -> void:
	var index := _flags.size()
	var n := corners.size() / 2
	_flags.append(flags)
	_base.append(base)
	_top.append(top)
	_scale.append(sight_scale)
	_first.append(_pts.size())
	_count.append(n)
	_pts.append_array(corners)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var mid := Vector2.ZERO
	for k in n:
		var c := Vector2(corners[2 * k], corners[2 * k + 1])
		lo = lo.min(c)
		hi = hi.max(c)
		mid += c
	mid /= n
	for k in n:
		_sight_pts.append(mid.x + (corners[2 * k] - mid.x) * sight_scale)
		_sight_pts.append(mid.y + (corners[2 * k + 1] - mid.y) * sight_scale)
	for cz in range(_cell(lo.y), _cell(hi.y) + 1):
		for cx in range(_cell(lo.x), _cell(hi.x) + 1):
			var key := Vector2i(cx, cz)
			if flags & FLAG_WALK:
				if not _walk_cells.has(key):
					_walk_cells[key] = PackedInt32Array()
				_walk_cells[key].append(index)
			if flags & FLAG_SIGHT:
				if not _sight_cells.has(key):
					_sight_cells[key] = PackedInt32Array()
				_sight_cells[key].append(index)
	if flags & FLAG_SIGHT:
		_sight_all.append(index)


static func _cell(v: float) -> int:
	return int(floor(v / CELL))


# --- Reading -------------------------------------------------------------

func size() -> int:
	return _flags.size()


# The first twelve hex digits of the file's SHA-256: what the server's boot
# line prints for its own copy.
func hash_hex() -> String:
	return _hash_hex


func flags_of(i: int) -> int:
	return _flags[i]


func base_of(i: int) -> float:
	return _base[i]


func top_of(i: int) -> float:
	return _top[i]


func corners_of(i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in _count[i]:
		out.append(Vector2(_pts[_first[i] + 2 * k], _pts[_first[i] + 2 * k + 1]))
	return out


# The WALK prisms whose outline comes within `reach` of `p`, lowest index first.
func walk_near(p: Vector2, reach: float) -> PackedInt32Array:
	return _gather(_walk_cells, p.x - reach, p.y - reach, p.x + reach, p.y + reach)


# Every prism, of either kind, with a corner's cell inside the box from
# (x0, z0) to (x1, z1): what the dev outline view draws.
func prisms_near(x0: float, z0: float, x1: float, z1: float) -> PackedInt32Array:
	var found := _gather(_walk_cells, x0, z0, x1, z1)
	found.append_array(_gather(_sight_cells, x0, z0, x1, z1))
	found.sort()
	var out := PackedInt32Array()
	for v in found:
		if out.is_empty() or out[out.size() - 1] != v:
			out.append(v)
	return out


func _gather(cells: Dictionary, x0: float, z0: float, x1: float, z1: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	for cz in range(_cell(z0), _cell(z1) + 1):
		for cx in range(_cell(x0), _cell(x1) + 1):
			var held = cells.get(Vector2i(cx, cz))
			if held != null:
				found.append_array(held)
	if found.size() < 2:
		return found
	found.sort()
	var out := PackedInt32Array()
	for v in found:
		if out.is_empty() or out[out.size() - 1] != v:
			out.append(v)
	return out


# --- The walk ------------------------------------------------------------

# Where `p` ends up after prism i has had its say: `p` itself when the body
# (a circle of `radius` round p) is clear of the outline, otherwise p moved
# out the shortest way until it only touches.
func _push_from(i: int, p: Vector2, radius: float) -> Vector2:
	var first := _first[i]
	var n := _count[i]
	var inside := true
	# For a centre inside the outline: the edge it is least far behind.
	var best_d := -INF
	var best_n := Vector2.ZERO
	# For a centre outside it: the nearest point of the outline.
	var near_d2 := INF
	var near := Vector2.ZERO
	var a := Vector2(_pts[first + 2 * (n - 1)], _pts[first + 2 * (n - 1) + 1])
	for k in n:
		var b := Vector2(_pts[first + 2 * k], _pts[first + 2 * k + 1])
		var e := b - a
		var length := e.length()
		if length > 0.0:
			# The outline runs counter-clockwise, so this points out of it.
			var normal := Vector2(e.y, -e.x) / length
			var d := (p - a).dot(normal)
			if d > 0.0:
				inside = false
			if d > best_d:
				best_d = d
				best_n = normal
			var t := clampf((p - a).dot(e) / (length * length), 0.0, 1.0)
			var q := a + e * t
			var d2 := p.distance_squared_to(q)
			if d2 < near_d2:
				near_d2 = d2
				near = q
		a = b
	if inside:
		return p + best_n * (radius - best_d)
	if near_d2 >= radius * radius:
		return p
	var dist := sqrt(near_d2)
	if dist < 0.000001:
		return p + best_n * radius
	return near + (p - near) * (radius / dist)


# Whether a body of `radius` at `p` touches no WALK prism (a millimetre of
# overlap is allowed: a body pushed out to exactly its radius is free).
func is_free(p: Vector2, radius: float) -> bool:
	for i in walk_near(p, radius):
		if _blocks(i, p, radius - FREE_SLACK):
			return false
	return true


func _blocks(i: int, p: Vector2, radius: float) -> bool:
	var first := _first[i]
	var n := _count[i]
	var inside := true
	var near_d2 := INF
	var a := Vector2(_pts[first + 2 * (n - 1)], _pts[first + 2 * (n - 1) + 1])
	for k in n:
		var b := Vector2(_pts[first + 2 * k], _pts[first + 2 * k + 1])
		var e := b - a
		var length := e.length()
		if length > 0.0:
			if (p - a).dot(Vector2(e.y, -e.x)) > 0.0:
				inside = false
			var t := clampf((p - a).dot(e) / (length * length), 0.0, 1.0)
			near_d2 = minf(near_d2, p.distance_squared_to(a + e * t))
		a = b
	return inside or near_d2 < radius * radius


# `p` after every nearby prism has pushed it, up to `passes` times over (a
# corner between two solids takes more than one).
func _settle(p: Vector2, radius: float, passes: int) -> Vector2:
	for _pass in passes:
		var moved := false
		for i in walk_near(p, radius):
			var q := _push_from(i, p, radius)
			if q != p:
				moved = true
				p = q
		if not moved:
			break
	return p


# One step of a body of `radius` from `from` towards `to`: where it ends.
# `last_deflected` says whether anything turned it aside or stopped it. With
# nothing near the step, `to` comes back untouched.
func resolve(from: Vector2, to: Vector2, radius: float) -> Vector2:
	last_deflected = false
	if not (is_finite(from.x) and is_finite(from.y) and is_finite(to.x) and is_finite(to.y)):
		return from
	# With nothing near the step, it is taken whole.
	if _gather(_walk_cells, minf(from.x, to.x) - radius, minf(from.y, to.y) - radius,
			maxf(from.x, to.x) + radius, maxf(from.y, to.y) + radius).is_empty():
		return to
	if not is_free(from, radius):
		# Standing inside something (a scenery edit since the body was put
		# here): the step is spent getting out. (The flag is set after the
		# search, which takes trial steps of its own.)
		var out := clear_of(from, radius)
		last_deflected = true
		return out
	var whole := to - from
	var length := whole.length()
	if length == 0.0:
		return from
	var pieces := int(floor(length / SUBSTEP)) + 1
	var piece := whole / pieces
	# No piece moves the body much further than it asked to go (the server's
	# PIECE_STRETCH has the reasoning): one that would ends the step.
	var furthest := length / pieces * PIECE_STRETCH + 2.0 * FREE_SLACK
	var p := from
	for _s in pieces:
		var want := p + piece
		var got := _settle(want, radius, PASSES)
		if not is_free(got, radius) or got.distance_squared_to(p) > furthest * furthest:
			last_deflected = true
			return p
		if got.distance_squared_to(want) > DEFLECT_EPS * DEFLECT_EPS:
			last_deflected = true
		p = got
	return p


# Whether a body standing free at `p` can walk away from it: a walk of
# ESCAPE_REACH in one of the ring directions ends ESCAPE_NEED or more from
# `p`. False in a gap closed all round by solids.
func can_leave(p: Vector2, radius: float) -> bool:
	if walk_near(p, radius + ESCAPE_REACH).is_empty():
		return true
	for spoke in CLEAR_SPOKES:
		var ended := resolve(p, p + spoke * ESCAPE_REACH, radius)
		if ended.distance_squared_to(p) >= ESCAPE_NEED * ESCAPE_NEED:
			return true
	return false


# Whether a body may be put at `p`: free of every solid, and able to walk away.
func stands(p: Vector2, radius: float) -> bool:
	return is_free(p, radius) and can_leave(p, radius)


# The nearest place to `p` a body of `radius` can be put (`stands`): `p` itself
# when it will do, else where the push-out settles, else the first such point
# on widening rings round it. Everything that puts a body somewhere without
# walking it there goes through this, so nothing ever stands inside a solid or
# in a gap it cannot leave.
func clear_of(p: Vector2, radius: float) -> Vector2:
	if not (is_finite(p.x) and is_finite(p.y)):
		return p
	if stands(p, radius):
		return p
	var q := _settle(p, radius, CLEAR_PASSES)
	if stands(q, radius):
		return q
	for ring in range(1, CLEAR_RINGS + 1):
		var reach := ring * CLEAR_RING_STEP
		for spoke in CLEAR_SPOKES:
			var c := p + spoke * reach
			if stands(c, radius):
				return c
	return p


# --- Sight ---------------------------------------------------------------

# Whether a SIGHT prism stands between `a` and `b` (world points, already at
# eye height): the line passes through an outline between its base and top.
func sight_blocked(a: Vector3, b: Vector3) -> bool:
	if not (a.is_finite() and b.is_finite()):
		return true
	var x0 := minf(a.x, b.x)
	var x1 := maxf(a.x, b.x)
	var z0 := minf(a.z, b.z)
	var z1 := maxf(a.z, b.z)
	var cells := (_cell(x1) - _cell(x0) + 1) * (_cell(z1) - _cell(z0) + 1)
	var candidates := _sight_all if cells > SIGHT_CELL_LIMIT else _gather(_sight_cells, x0, z0, x1, z1)
	for i in candidates:
		if _line_meets(i, a, b):
			return true
	return false


func _line_meets(i: int, a: Vector3, b: Vector3) -> bool:
	var first := _first[i]
	var n := _count[i]
	var t0 := 0.0
	var t1 := 1.0
	var from := Vector2(a.x, a.z)
	var along := Vector2(b.x - a.x, b.z - a.z)
	var p := Vector2(_sight_pts[first + 2 * (n - 1)], _sight_pts[first + 2 * (n - 1) + 1])
	for k in n:
		var q := Vector2(_sight_pts[first + 2 * k], _sight_pts[first + 2 * k + 1])
		var e := q - p
		var normal := Vector2(e.y, -e.x)
		var behind := (from - p).dot(normal)
		var rate := along.dot(normal)
		if absf(rate) < 0.000000000001:
			if behind > 0.0:
				return false
		else:
			var t := -behind / rate
			if rate < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
			if t0 > t1:
				return false
		p = q
	var base := _base[i]
	var top := _top[i]
	# A line that begins or ends inside this prism is not blocked by it: a body
	# under a tree on a slope has its eye inside the crown, and sees out as it
	# is seen. (No body is ever inside a prism that stands in its way; this is
	# crowns, roofs and lintels.) Every other prism on the line still blocks.
	if (t0 == 0.0 and a.y > base and a.y < top) or (t1 == 1.0 and b.y > base and b.y < top):
		return false
	var y0 := a.y + (b.y - a.y) * t0
	var y1 := a.y + (b.y - a.y) * t1
	return maxf(y0, y1) > base and minf(y0, y1) < top
