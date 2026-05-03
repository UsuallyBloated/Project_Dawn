class_name MultiFloorGenerator
extends RefCounted

const SHAFT_W = 2
const SHAFT_D = 2

func generate(p_seed: int, floor_count: int) -> MultiFloorLayout:
	var rng = RandomNumberGenerator.new()
	rng.seed = p_seed

	var ml = MultiFloorLayout.new()
	ml.seed_value  = p_seed
	ml.floor_count = floor_count

	var gen = DungeonGenerator.new()
	for i in floor_count:
		ml.floors.append(gen.generate(_floor_seed(p_seed, i)))

	for i in floor_count - 1:
		var stair = _connect_floors(ml.floors[i], ml.floors[i + 1], i, rng)
		if stair != null:
			ml.stairs.append(stair)

	return ml


func _floor_seed(base: int, idx: int) -> int:
	# Large prime offset keeps floors visually uncorrelated
	return (base + idx * 1000003) & 0x7FFFFFFF


# ── Stair placement ────────────────────────────────────────────────────────

func _connect_floors(lower: DungeonLayout, upper: DungeonLayout,
		from_floor: int, rng: RandomNumberGenerator) -> StairData:

	var room = _pick_stair_room(lower, rng)
	if room == null:
		return null

	var rect = room.grid_rect
	var min_gx = rect.position.x + 1
	var min_gy = rect.position.y + 1
	var max_gx = rect.position.x + rect.size.x - SHAFT_W - 1
	var max_gy = rect.position.y + rect.size.y - SHAFT_D - 1

	if max_gx < min_gx or max_gy < min_gy:
		return null

	var shaft_gx = rng.randi_range(min_gx, max_gx)
	var shaft_gy = rng.randi_range(min_gy, max_gy)

	# Mark shaft cells on lower floor (no ceiling rendered above them)
	for dy in SHAFT_D:
		for dx in SHAFT_W:
			lower.set_cell(shaft_gx + dx, shaft_gy + dy, DungeonLayout.CELL_STAIR_BOTTOM)

	# Mark shaft cells on upper floor (no floor rendered below them)
	for dy in SHAFT_D:
		for dx in SHAFT_W:
			upper.set_cell(shaft_gx + dx, shaft_gy + dy, DungeonLayout.CELL_STAIR_TOP)

	# Carve a path from the shaft to the nearest existing room on the upper floor
	var shaft_center = Vector2i(shaft_gx + (SHAFT_W >> 1), shaft_gy + (SHAFT_D >> 1))
	_connect_shaft_to_nearest(upper, shaft_center)

	var stair      = StairData.new()
	stair.from_floor = from_floor
	stair.to_floor   = from_floor + 1
	stair.shaft_gx   = shaft_gx
	stair.shaft_gy   = shaft_gy
	stair.shaft_w    = SHAFT_W
	stair.shaft_d    = SHAFT_D
	stair.cell_size  = lower.cell_size
	return stair


func _pick_stair_room(layout: DungeonLayout, rng: RandomNumberGenerator) -> RoomData:
	var candidates: Array = []
	for room in layout.rooms:
		if room.room_type != RoomData.RoomType.GENERIC:
			continue
		if room.grid_rect.size.x >= SHAFT_W + 2 and room.grid_rect.size.y >= SHAFT_D + 2:
			candidates.append(room)
	if candidates.is_empty():
		# Fallback — any non-entrance/exit room
		for room in layout.rooms:
			if room.room_type == RoomData.RoomType.GENERIC:
				candidates.append(room)
	if candidates.is_empty():
		return null
	return candidates[rng.randi() % candidates.size()]


func _connect_shaft_to_nearest(layout: DungeonLayout, shaft_center: Vector2i) -> void:
	# BFS outward from shaft_center until we hit an existing CELL_FLOOR cell,
	# then carve a 2-wide L-shaped corridor to it.
	var visited: Dictionary = {}
	var queue: Array        = [shaft_center]
	visited[shaft_center]   = true
	var target              = Vector2i(-1, -1)

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if layout.get_cell(pos.x, pos.y) == DungeonLayout.CELL_FLOOR:
			target = pos
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var np: Vector2i = pos + d
			if np.x >= 0 and np.x < layout.grid_width \
					and np.y >= 0 and np.y < layout.grid_height \
					and not visited.has(np):
				visited[np] = true
				queue.append(np)

	if target.x < 0:
		return  # no reachable floor found — shaft is isolated, still functional

	_carve_corridor(shaft_center, target, layout)


# ── Corridor carving (mirrors DungeonGenerator logic) ─────────────────────

func _carve_corridor(a: Vector2i, b: Vector2i, layout: DungeonLayout) -> void:
	var mid = Vector2i(b.x, a.y)
	_carve_line(a, mid, layout)
	_carve_line(mid, b, layout)


func _carve_line(a: Vector2i, b: Vector2i, layout: DungeonLayout) -> void:
	var dx = sign(b.x - a.x)
	var dy = sign(b.y - a.y)
	var cx = a.x
	var cy = a.y
	while cx != b.x or cy != b.y:
		_carve_wide(cx, cy, layout)
		if cx != b.x: cx += dx
		elif cy != b.y: cy += dy
	_carve_wide(b.x, b.y, layout)


func _carve_wide(cx: int, cy: int, layout: DungeonLayout) -> void:
	for oy in [-1, 0]:
		for ox in [-1, 0]:
			var nx = cx + ox
			var ny = cy + oy
			if nx >= 0 and nx < layout.grid_width and ny >= 0 and ny < layout.grid_height:
				if layout.get_cell(nx, ny) == DungeonLayout.CELL_EMPTY:
					layout.set_cell(nx, ny, DungeonLayout.CELL_FLOOR)
