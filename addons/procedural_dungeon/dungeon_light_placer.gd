class_name DungeonLightPlacer
extends RefCounted

const TORCH_COLOR    = Color(1.0, 0.62, 0.28)
const TORCH_ENERGY   = 3.0
const TORCH_RANGE    = 28.0    # world units — covers ~4.5 cells per side
const TORCH_ATTEN    = 1.8     # falloff curve
static var MIN_DIST:    int  = 1     # set via dungeon_test.gd export
static var MAX_TORCHES: int  = 200   # set via dungeon_test.gd export
const DEBUG_LABELS          = true   # set false to remove numbered labels before shipping

static func place(layout: DungeonLayout, parent: Node3D, y_offset: float = 0.0, start_idx: int = 0, groups: Dictionary = {}) -> int:
	var cs      = layout.cell_size
	var light_y = y_offset + layout.room_height * 0.65
	var idx     = start_idx

	# Candidates: passable cells with a CELL_INTERIOR_WALL neighbor to mount on
	var candidates: Array = []
	for gy in layout.grid_height:
		for gx in layout.grid_width:
			if not layout.is_passable(gx, gy):
				continue
			var offset = _wall_nudge(layout, gx, gy, cs * 0.48)
			if offset == Vector2.ZERO:
				continue
			candidates.append({"gx": gx, "gy": gy, "offset": offset})

	# Seeded shuffle — breaks grid-line patterns, stays deterministic per seed
	var rng = RandomNumberGenerator.new()
	rng.seed = layout.seed_value
	for i in range(candidates.size() - 1, 0, -1):
		var j   = rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	# Greedy placement: skip any candidate within MIN_DIST cells of an existing torch
	var placed: Dictionary = {}
	for c in candidates:
		var gx: int = c["gx"]
		var gy: int = c["gy"]
		var too_close := false
		for dy in range(-MIN_DIST, MIN_DIST + 1):
			for dx in range(-MIN_DIST, MIN_DIST + 1):
				if placed.has(Vector2i(gx + dx, gy + dy)):
					too_close = true
					break
			if too_close:
				break
		if too_close:
			continue

		placed[Vector2i(gx, gy)] = true
		var corner = layout.cell_to_world(gx, gy)
		var cx     = corner.x + cs * 0.5
		var cz     = corner.z + cs * 0.5
		var pos    = Vector3(cx + c["offset"].x, light_y, cz + c["offset"].y)

		var light  = _make_light(pos)
		light.name = "Torch_%d" % idx
		parent.add_child(light)

		if DEBUG_LABELS:
			var label       = Label3D.new()
			label.text      = str(idx)
			label.font_size = 96
			label.modulate  = Color.YELLOW
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position  = pos + Vector3(0, 1.2, 0)
			parent.add_child(label)

			var ox: float = c["offset"].x
			var oy: float = c["offset"].y
			var dir := "N"
			if   oy > 0.0: dir = "S"
			elif ox > 0.0: dir = "E"
			elif ox < 0.0: dir = "W"
			if not groups.has(dir):
				groups[dir] = []
			groups[dir].append("[Torch %d] gx=%d gy=%d  world=(%.1f, %.1f, %.1f)" % [idx, gx, gy, pos.x, pos.y, pos.z])

		idx += 1
		if MAX_TORCHES >= 0 and (idx - start_idx) >= MAX_TORCHES:
			break

	if DEBUG_LABELS:
		_place_compass_labels(layout, parent, y_offset)

	return idx


static func print_debug_groups(groups: Dictionary) -> void:
	for dir in ["N", "S", "E", "W"]:
		if not groups.has(dir) or groups[dir].is_empty():
			continue
		print("\n--- %s wall (%d) ---" % [dir, groups[dir].size()])
		for line in groups[dir]:
			print(line)


static func _place_compass_labels(layout: DungeonLayout, parent: Node3D, y_offset: float) -> void:
	var cs    = layout.cell_size
	var mid_x = layout.grid_width  * cs * 0.5
	var mid_z = layout.grid_height * cs * 0.5
	var label_y = y_offset + layout.room_height * 1.5

	var compass = [
		["N", Vector3(mid_x,                label_y, 0.0)],
		["S", Vector3(mid_x,                label_y, layout.grid_height * cs)],
		["E", Vector3(layout.grid_width * cs, label_y, mid_z)],
		["W", Vector3(0.0,                  label_y, mid_z)],
	]
	for entry in compass:
		var label       = Label3D.new()
		label.text      = entry[0]
		label.font_size = 256
		label.modulate  = Color.CYAN
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position  = entry[1]
		parent.add_child(label)


## Only nudge toward CELL_INTERIOR_WALL neighbors — room perimeter walls only.
static func _wall_nudge(layout: DungeonLayout, gx: int, gy: int, dist: float) -> Vector2:
	var dirs = [
		Vector2i( 0, -1),
		Vector2i( 0,  1),
		Vector2i( 1,  0),
		Vector2i(-1,  0),
	]
	for i in dirs.size():
		var d  = dirs[i]
		var nb := Vector2i(gx + d.x, gy + d.y)
		if layout.get_cell(nb.x, nb.y) == DungeonLayout.CELL_INTERIOR_WALL:
			return Vector2(d.x, d.y) * dist
	return Vector2.ZERO


static func _make_light(pos: Vector3) -> OmniLight3D:
	var light              = OmniLight3D.new()
	light.position         = pos
	light.light_color      = TORCH_COLOR
	light.light_energy     = TORCH_ENERGY
	light.omni_range       = TORCH_RANGE
	light.omni_attenuation = TORCH_ATTEN
	light.shadow_enabled   = false
	return light
