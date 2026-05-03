class_name DungeonGenerator
extends RefCounted

# Grid dimensions (in cells)
@export var dungeon_w:       int = 48
@export var dungeon_h:       int = 48

# BSP tuning
@export var bsp_max_depth:   int = 4
@export var bsp_min_split:   int = 8   # minimum cells on the split axis before we stop splitting
@export var room_margin:     int = 1   # cells of padding between room edge and partition edge
@export var room_min_size:   int = 4   # minimum room dimension in cells
@export var corridor_width:  int = 2   # cells wide

class BSPNode:
	var rect: Rect2i
	var left:  BSPNode
	var right: BSPNode
	var room_id: int = -1  # only valid on leaf nodes

	func is_leaf() -> bool:
		return left == null and right == null

	# Returns any room_id reachable from this subtree.
	func any_room_id() -> int:
		if is_leaf():
			return room_id
		if left  != null and left.any_room_id()  >= 0: return left.any_room_id()
		if right != null and right.any_room_id() >= 0: return right.any_room_id()
		return -1


func generate(p_seed: int) -> DungeonLayout:
	var rng = RandomNumberGenerator.new()
	rng.seed = p_seed

	var layout = DungeonLayout.new()
	layout.seed_value = p_seed
	layout.setup_grid(dungeon_w, dungeon_h)

	# Build BSP tree and place rooms
	var root = _bsp_split(Rect2i(0, 0, dungeon_w, dungeon_h), rng, 0)
	_place_rooms(root, layout, rng)

	# Connect rooms top-down through the BSP tree
	_connect_bsp(root, layout, rng)

	# Assign entrance/exit
	if not layout.rooms.is_empty():
		layout.rooms[0].room_type = RoomData.RoomType.ENTRANCE
		layout.rooms[layout.rooms.size() - 1].room_type = RoomData.RoomType.EXIT

	return layout


# ── BSP ────────────────────────────────────────────────────────────────

func _bsp_split(rect: Rect2i, rng: RandomNumberGenerator, depth: int) -> BSPNode:
	var node = BSPNode.new()
	node.rect = rect

	if depth >= bsp_max_depth:
		return node

	# Decide split axis; prefer the longer axis
	var split_h: bool
	if rect.size.x > rect.size.y + 4:
		split_h = false
	elif rect.size.y > rect.size.x + 4:
		split_h = true
	else:
		split_h = rng.randi() % 2 == 0

	if split_h:
		# horizontal split (cut along y)
		if rect.size.y < bsp_min_split * 2:
			return node
		var min_cut = rect.position.y + bsp_min_split
		var max_cut = rect.position.y + rect.size.y - bsp_min_split
		if min_cut >= max_cut:
			return node
		var cut = rng.randi_range(min_cut, max_cut)
		node.left  = _bsp_split(Rect2i(rect.position.x, rect.position.y, rect.size.x, cut - rect.position.y), rng, depth + 1)
		node.right = _bsp_split(Rect2i(rect.position.x, cut, rect.size.x, rect.position.y + rect.size.y - cut), rng, depth + 1)
	else:
		# vertical split (cut along x)
		if rect.size.x < bsp_min_split * 2:
			return node
		var min_cut = rect.position.x + bsp_min_split
		var max_cut = rect.position.x + rect.size.x - bsp_min_split
		if min_cut >= max_cut:
			return node
		var cut = rng.randi_range(min_cut, max_cut)
		node.left  = _bsp_split(Rect2i(rect.position.x, rect.position.y, cut - rect.position.x, rect.size.y), rng, depth + 1)
		node.right = _bsp_split(Rect2i(cut, rect.position.y, rect.position.x + rect.size.x - cut, rect.size.y), rng, depth + 1)

	return node


func _place_rooms(node: BSPNode, layout: DungeonLayout, rng: RandomNumberGenerator) -> void:
	if node == null:
		return
	if node.is_leaf():
		var part = node.rect
		# Random inset within the partition (keeps ROOM_MARGIN padding on all sides)
		var avail_x = part.size.x - room_min_size - room_margin * 2
		var avail_y = part.size.y - room_min_size - room_margin * 2

		if avail_x < 0 or avail_y < 0:
			return  # partition too small to fit a room

		var inset_x = rng.randi_range(0, avail_x)
		var inset_y = rng.randi_range(0, avail_y)

		var rx = part.position.x + room_margin + inset_x
		var ry = part.position.y + room_margin + inset_y

		# Room width/height: between room_min_size and the remaining space
		var max_rw = part.size.x - room_margin * 2 - inset_x
		var max_rh = part.size.y - room_margin * 2 - inset_y
		max_rw = max(max_rw, room_min_size)
		max_rh = max(max_rh, room_min_size)

		var rw = rng.randi_range(room_min_size, max_rw)
		var rh = rng.randi_range(room_min_size, max_rh)

		# Hard clamp to grid bounds
		rw = mini(rw, dungeon_w - rx - 1)
		rh = mini(rh, dungeon_h - ry - 1)
		if rw < room_min_size or rh < room_min_size:
			return

		var room = RoomData.new()
		room.id = layout.rooms.size()
		room.grid_rect = Rect2i(rx, ry, rw, rh)
		layout.rooms.append(room)
		node.room_id = room.id

		# Tag perimeter ring as interior walls (only over empty cells)
		for py in range(ry - 1, ry + rh + 1):
			for px in range(rx - 1, rx + rw + 1):
				if px >= rx and px < rx + rw and py >= ry and py < ry + rh:
					continue
				if layout.get_cell(px, py) == DungeonLayout.CELL_EMPTY:
					layout.set_cell(px, py, DungeonLayout.CELL_INTERIOR_WALL)

		# Carve floor cells (overwrites any interior wall tag inside the room)
		for cy in range(ry, ry + rh):
			for cx in range(rx, rx + rw):
				layout.set_cell(cx, cy, DungeonLayout.CELL_FLOOR)
		return

	_place_rooms(node.left,  layout, rng)
	_place_rooms(node.right, layout, rng)


func _connect_bsp(node: BSPNode, layout: DungeonLayout, rng: RandomNumberGenerator) -> void:
	if node == null or node.is_leaf():
		return
	_connect_bsp(node.left,  layout, rng)
	_connect_bsp(node.right, layout, rng)

	var left_id  = node.left.any_room_id()  if node.left  != null else -1
	var right_id = node.right.any_room_id() if node.right != null else -1
	if left_id < 0 or right_id < 0:
		return

	var ra: RoomData = layout.rooms[left_id]
	var rb: RoomData = layout.rooms[right_id]
	ra.connected_to.append(rb.id)
	rb.connected_to.append(ra.id)

	_carve_corridor(ra.center_cell(), rb.center_cell(), layout, rng)


func _carve_corridor(a: Vector2i, b: Vector2i, layout: DungeonLayout, rng: RandomNumberGenerator) -> void:
	# L-shaped corridor; randomly choose which leg goes first
	var mid: Vector2i
	if rng.randi() % 2 == 0:
		mid = Vector2i(b.x, a.y)
	else:
		mid = Vector2i(a.x, b.y)

	_carve_line(a, mid, layout)
	_carve_line(mid, b, layout)


func _carve_line(a: Vector2i, b: Vector2i, layout: DungeonLayout) -> void:
	var dx = sign(b.x - a.x)
	var dy = sign(b.y - a.y)
	var cx = a.x
	var cy = a.y

	while cx != b.x or cy != b.y:
		_carve_wide(cx, cy, layout)
		if cx != b.x:
			cx += dx
		elif cy != b.y:
			cy += dy

	_carve_wide(b.x, b.y, layout)


func _carve_wide(cx: int, cy: int, layout: DungeonLayout) -> void:
	var half: int = corridor_width >> 1
	for oy in range(-half, half + (corridor_width % 2)):
		for ox in range(-half, half + (corridor_width % 2)):
			layout.set_cell(cx + ox, cy + oy, DungeonLayout.CELL_FLOOR)
