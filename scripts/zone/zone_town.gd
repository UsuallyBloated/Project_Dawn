@tool
class_name ZoneTown
extends ZoneDressing

# The town, built from the prop kit (zone_props.gd) after the concept sheets
# "town from the east road" and "town square": a low battlemented wall with a
# gate on each road, the old watchtower by the east gate with its green
# banner, houses round a square, and behind the NPC row the things the NPCs
# keep: Hadrik's forge, Sister Maelis' shrine stone, Aldric's guard post,
# Elara's stall, Brom's shop front and Thalia's bank. Outside the walls: the
# fenced farm strips, a barn, and the windmill on the south road.
#
# Placeholder shapes, scenery only (see zone_dressing.gd): nothing collides,
# so the walls are walked through until the server knows obstacles. The NPCs
# themselves are nodes in world.tscn at the server's positions (npcs.toml);
# this script only dresses the ground round them.

const WALL_HEIGHT := 6.5
const WALL_THICK := 2.4
const GATE_OPENING := 9.0
const GATE_CLEAR := 6.0
# From a gate's middle to where its wall starts (half the opening, plus a pier).
const GATE_HALF := 7.9
const TOWER_AT := Vector2(90, 22)
const TOWER_WIDTH := 9.0
const TOWER_HEIGHT := 24.0
# Where the houses stand, as (x, z) in the north-east quarter; each is
# mirrored into the other three.
const HOUSE_LOTS := [
	Vector2(33, 31), Vector2(57, 29), Vector2(78, 40), Vector2(31, 57),
	Vector2(55, 59), Vector2(77, 68), Vector2(42, 80),
]
const MILL_BLADE_SPEED := 0.4

var _mill_blades: Node3D


func _build() -> void:
	_build_walls()
	_build_houses()
	_build_square()
	_build_farms()
	_build_mill()


func _process(delta: float) -> void:
	super(delta)
	if _mill_blades != null:
		_mill_blades.rotate_object_local(Vector3(0, 0, 1), delta * MILL_BLADE_SPEED)


# --- The walls -----------------------------------------------------------

func _build_walls() -> void:
	var b := LowPoly.new(11)
	var h := ZoneLayout.TOWN_HALF
	var g := GATE_HALF
	var tower_lo := TOWER_AT.y - TOWER_WIDTH * 0.5
	var tower_hi := TOWER_AT.y + TOWER_WIDTH * 0.5
	# Each run is drawn so its merlons face out (ZoneProps.wall puts them on
	# the run's left).
	var runs := [
		# East wall, south to north, broken by the gate and the watchtower.
		[Vector2(h, -h), Vector2(h, -g)], [Vector2(h, g), Vector2(h, tower_lo)], [Vector2(h, tower_hi), Vector2(h, h)],
		# North wall, east to west.
		[Vector2(h, h), Vector2(g, h)], [Vector2(-g, h), Vector2(-h, h)],
		# West wall, north to south.
		[Vector2(-h, h), Vector2(-h, g)], [Vector2(-h, -g), Vector2(-h, -h)],
		# South wall, west to east.
		[Vector2(-h, -h), Vector2(-g, -h)], [Vector2(g, -h), Vector2(h, -h)],
	]
	for run in runs:
		ZoneProps.wall(b, on_ground(run[0]), on_ground(run[1]), WALL_HEIGHT, WALL_THICK)
	for corner in [Vector2(h, h), Vector2(-h, h), Vector2(-h, -h), Vector2(h, -h)]:
		ZoneProps.tower(b, stand(corner), 7.0, 10.5, 0.0)
	# The gates: the way through runs along the road.
	ZoneProps.gate(b, stand(Vector2(h, 0), PI * 0.5), GATE_OPENING, GATE_CLEAR, 4.2)
	ZoneProps.gate(b, stand(Vector2(-h, 0), PI * 0.5), GATE_OPENING, GATE_CLEAR, 4.2)
	ZoneProps.gate(b, stand(Vector2(0, h)), GATE_OPENING, GATE_CLEAR, 4.2)
	ZoneProps.gate(b, stand(Vector2(0, -h)), GATE_OPENING, GATE_CLEAR, 4.2)
	# The old watchtower, and the banner that is the town's one bright colour.
	ZoneProps.tower(b, stand(TOWER_AT), TOWER_WIDTH, TOWER_HEIGHT, 7.5)
	ZoneProps.banner(b, stand(TOWER_AT, 0.5, TOWER_HEIGHT + 7.2), 5.5, 6.5, 2.6, ZoneProps.BANNER_GREEN)
	for gate_at in [Vector2(h + 2.4, 6.5), Vector2(h + 2.4, -6.5), Vector2(-h - 2.4, 6.5), Vector2(-h - 2.4, -6.5)]:
		ZoneProps.banner(b, stand(gate_at, PI * 0.5, 0.0), 8.6, 1.6, 2.4, ZoneProps.BANNER_GREEN)
	add_piece(b, "Walls")

	var signs := LowPoly.new(12)
	for at in [Vector2(h + 16, 7), Vector2(7, h + 16), Vector2(-h - 16, -6), Vector2(-7, -h - 16)]:
		ZoneProps.signpost(signs, stand(at, at.angle()))
	add_piece(signs, "Signposts", 400.0)


# --- The houses ----------------------------------------------------------

func _build_houses() -> void:
	var b := LowPoly.new(21)
	var glow := LowPoly.new(22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var smoking := 0
	for lot in HOUSE_LOTS:
		for flip in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			var at: Vector2 = lot * flip + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			# The door faces the nearer of the two streets through the square.
			var facing := Vector2(-signf(at.x), 0) if absf(at.x) > absf(at.y) else Vector2(0, -signf(at.y))
			var yaw := atan2(-facing.x, -facing.y) + rng.randf_range(-0.12, 0.12)
			var w := rng.randf_range(7.5, 11.5)
			var d := rng.randf_range(6.0, 8.5)
			var tall := rng.randf() < 0.3
			var wall_h := rng.randf_range(5.6, 6.6) if tall else rng.randf_range(3.3, 4.2)
			var style := 2 if tall else rng.randi_range(0, 1)
			var roof: Color = ZoneProps.ROOFS[rng.randi_range(0, ZoneProps.ROOFS.size() - 1)]
			var xf := stand(at, yaw)
			ZoneProps.house(b, xf, w, d, wall_h, rng.randf_range(2.6, 3.6), style, roof, glow)
			if rng.randf() < 0.3 and smoking < 5:
				smoking += 1
				add_smoke(xf * Vector3(w * 0.26, wall_h + 4.2, d * 0.18), 1.5)
	add_piece(b, "Houses")
	add_glow(glow, "HouseWindows", 1.3, 700.0)


# --- The square, and what the NPCs keep ------------------------------------

func _build_square() -> void:
	var b := LowPoly.new(31)
	var small := LowPoly.new(32)
	var glow := LowPoly.new(33)

	# Hadrik's forge, behind him: an open shed, the hearth and its chimney.
	var forge := stand(Vector2(-8.5, 13.5))
	ZoneProps.shed(b, forge, 8.0, 6.5, 3.2, 2.2, ZoneProps.ROOF_SLATE)
	b.box(forge.translated_local(Vector3(1.2, 0, 1.6)), Vector3(2.6, 1.3, 2.2), ZoneProps.STONE_DARK)
	b.box(forge.translated_local(Vector3(1.2, 1.3, 2.2)), Vector3(1.3, 6.2, 1.1), ZoneProps.STONE_DARK)
	glow.box(forge.translated_local(Vector3(1.2, 1.3, 1.3)), Vector3(1.4, 0.5, 0.9), ZoneProps.FLAME)
	small.box(forge.translated_local(Vector3(-1.2, 0, -0.6)), Vector3(0.5, 0.75, 0.9), Color(0.2, 0.2, 0.22))
	for i in 5:
		small.column(forge * LowPoly.leaning(Vector3(-3.4, 0.25 + 0.42 * (i % 2), -2.2 + i * 0.45), PI * 0.5, PI * 0.5), 0.2, 0.2, 2.6, 5, ZoneProps.TIMBER_PALE)
	add_light(forge * Vector3(1.2, 2.0, 0.8), ZoneProps.FLAME, 2.2, 13.0, true)
	add_smoke(forge * Vector3(1.2, 7.8, 2.2), 1.7)

	# Sister Maelis' shrine stone: a standing stone with a niche and a candle.
	var shrine := stand(Vector2(-2.0, 8.6))
	small.box(shrine, Vector3(2.4, 0.4, 2.0), ZoneProps.STONE_DARK)
	ZoneProps.standing_stone(small, shrine.translated_local(Vector3(0, 0.4, 0)), 1.7, 3.5, 0.0, ZoneProps.STONE_PALE)
	small.box(shrine.translated_local(Vector3(0, 1.5, -0.82)), Vector3(0.55, 0.95, 0.12), ZoneProps.SHADOW)
	glow.box(shrine.translated_local(Vector3(0, 1.55, -0.86)), Vector3(0.12, 0.2, 0.06), ZoneProps.FLAME_CORE)

	# Aldric's guard post: a brazier and the Watch's banner.
	var post := stand(Vector2(2.0, 8.4))
	small.column(post, 0.16, 0.34, 1.2, 5, Color(0.2, 0.2, 0.22))
	glow.cone(post.translated_local(Vector3(0, 1.2, 0)), 0.3, 0.8, 5, ZoneProps.FLAME)
	add_light(post * Vector3(0, 1.8, 0), ZoneProps.FLAME, 1.4, 9.0, true)
	ZoneProps.banner(small, stand(Vector2(0.4, 9.0), PI * 0.5), 4.2, 1.5, 2.0, ZoneProps.BANNER_GREEN)

	# Elara's stall, with her stock round it.
	var stall := stand(Vector2(5.2, 8.6))
	ZoneProps.stall(small, stall, 3.6, 2.6, ZoneProps.BANNER_GREEN.lerp(ZoneProps.CANVAS, 0.35))
	ZoneProps.barrel(small, stall.translated_local(Vector3(2.5, 0, 0.2)))
	ZoneProps.crate(small, stall.translated_local(Vector3(-2.5, 0, 0.5)))
	ZoneProps.crate(small, stall.translated_local(Vector3(-2.4, 0.8, 0.6)), 0.7)

	# Brom's shop: a stone front with a serving hatch, and his barrels.
	var shop := stand(Vector2(9.2, 15.0))
	ZoneProps.house(b, shop, 8.0, 7.0, 3.8, 3.0, 0, ZoneProps.ROOF_THATCH, glow)
	small.box(shop.translated_local(Vector3(-2.3, 1.0, -3.65)), Vector3(2.0, 0.14, 0.7), ZoneProps.TIMBER_PALE)
	for i in 3:
		ZoneProps.barrel(small, stand(Vector2(7.2 + i * 1.0, 9.2 + (i % 2) * 0.7)))
	add_smoke(shop * Vector3(2.1, 7.6, 1.3), 1.5)

	# Thalia's bank: the stoutest house in town, pillars at its door.
	var bank := stand(Vector2(19.5, 14.0))
	ZoneProps.house(b, bank, 10.0, 8.5, 5.4, 3.0, 0, ZoneProps.ROOF_SLATE, glow)
	for sx in [-1.0, 1.0]:
		b.column(bank.translated_local(Vector3(sx * 1.6, 0, -4.9)), 0.4, 0.34, 4.2, 6, ZoneProps.STONE_PALE)
	b.box(bank.translated_local(Vector3(0, 4.2, -4.9)), Vector3(4.6, 0.5, 1.2), ZoneProps.STONE_PALE)
	small.box(stand(Vector2(11.0, 8.0)), Vector3(1.6, 1.0, 0.8), ZoneProps.TIMBER, ZoneProps.TIMBER_PALE)

	# The well, south of where a new arrival stands.
	var well := stand(Vector2(3.0, -9.0))
	small.column(well, 1.4, 1.4, 0.9, 8, ZoneProps.STONE_DARK, ZoneProps.SHADOW)
	for sx in [-1.0, 1.0]:
		small.box(well.translated_local(Vector3(sx * 1.3, 0, 0)), Vector3(0.18, 2.6, 0.18), ZoneProps.TIMBER)
	small.gable(well.translated_local(Vector3(0, 2.6, 0)), Vector3(3.4, 0.9, 2.0), ZoneProps.ROOF_THATCH)

	# The inn across the square, a stable, and the day's clutter.
	ZoneProps.house(b, stand(Vector2(-22.0, -21.0), PI), 13.0, 9.0, 6.4, 3.6, 2, ZoneProps.ROOF_TILE, glow)
	ZoneProps.shed(b, stand(Vector2(27.0, -20.0), PI * 0.5), 9.0, 6.0, 2.8, 2.0, ZoneProps.ROOF_THATCH)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for cluster in [Vector2(-15, -12), Vector2(22, -12), Vector2(-14, 7), Vector2(24, 4), Vector2(-28, -14)]:
		for i in rng.randi_range(2, 4):
			var at: Vector2 = cluster + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
			if rng.randf() < 0.5:
				ZoneProps.barrel(small, stand(at))
			else:
				ZoneProps.crate(small, stand(at, rng.randf() * TAU), rng.randf_range(0.7, 1.1))
	add_smoke(on_ground(Vector2(-18.7, -22.6), 11.0), 1.7)

	add_piece(b, "Square")
	add_piece(small, "SquareDetail", 420.0)
	add_glow(glow, "SquareGlow", 2.0, 700.0)


# --- Outside the walls -----------------------------------------------------

func _build_farms() -> void:
	var b := LowPoly.new(41)
	for field in ZoneLayout.FIELDS:
		var r: Rect2 = (field["rect"] as Rect2).grow(2.0)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			ZoneProps.fence(b, on_ground(corners[i]), on_ground(corners[(i + 1) % 4]))
		# A stook of sheaves at one corner.
		b.cone(stand(r.position + Vector2(5, 5)), 1.6, 2.6, 6, ZoneProps.ROOF_THATCH)
		b.cone(stand(r.end - Vector2(6, 4)), 1.3, 2.2, 6, ZoneProps.ROOF_THATCH)
	# A scarecrow in the first strip.
	var crow := stand((ZoneLayout.FIELDS[0]["rect"] as Rect2).get_center(), 0.6)
	b.box(crow, Vector3(0.12, 2.2, 0.12), ZoneProps.TIMBER)
	b.box(crow.translated_local(Vector3(0, 1.5, 0)), Vector3(1.8, 0.1, 0.1), ZoneProps.TIMBER)
	b.blob(crow.translated_local(Vector3(0, 2.35, 0)), Vector3(0.28, 0.3, 0.28), 0.15, ZoneProps.CANVAS)
	b.sheet(crow * Vector3(-0.8, 1.55, 0.02), crow * Vector3(0.8, 1.55, 0.02), crow * Vector3(0.5, 0.7, 0.05), crow * Vector3(-0.5, 0.7, 0.05), ZoneProps.HIDE_DARK)
	add_piece(b, "Farms", 700.0)

	var barn := LowPoly.new(42)
	ZoneProps.house(barn, stand(Vector2(-205, -82), -PI * 0.5), 14.0, 9.0, 5.0, 4.4, 1, ZoneProps.ROOF_THATCH)
	ZoneProps.shed(barn, stand(Vector2(-192, -100)), 7.0, 5.0, 2.6, 1.8, ZoneProps.ROOF_THATCH)
	add_piece(barn, "Barn", 2500.0)


func _build_mill() -> void:
	var at := ZoneLayout.MILL
	var b := LowPoly.new(51)
	var base := stand(at)
	b.column(base, 3.6, 2.5, 11.0, 8, ZoneProps.PLASTER.darkened(0.05))
	b.column(base, 3.9, 3.7, 1.6, 8, ZoneProps.STONE_DARK)
	b.cone(base.translated_local(Vector3(0, 11.0, 0)), 3.1, 3.4, 8, ZoneProps.ROOF_THATCH.darkened(0.15))
	b.box(base.translated_local(Vector3(0, 0, 3.55)), Vector3(1.3, 2.2, 0.2), ZoneProps.TIMBER)
	add_piece(b, "Mill", 3000.0)

	# The sails: four latticed arms round a hub, facing the road to the west.
	var sails := LowPoly.new(52)
	sails.column(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.5)), 0.35, 0.3, 1.4, 6, ZoneProps.TIMBER)
	for i in 4:
		var arm := Transform3D(Basis(Vector3(0, 0, 1), i * PI * 0.5), Vector3.ZERO)
		sails.box(arm * LowPoly.at(Vector3(0, 0.3, 0.4)), Vector3(0.22, 8.2, 0.16), ZoneProps.TIMBER)
		sails.sheet(arm * Vector3(0.15, 1.6, 0.42), arm * Vector3(1.9, 1.6, 0.42), arm * Vector3(1.9, 8.2, 0.42), arm * Vector3(0.15, 8.2, 0.42), ZoneProps.CANVAS)
	_mill_blades = sails.instance("MillSails", 3000.0)
	_mill_blades.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), on_ground(at, 10.6) + Vector3(-3.4, 0, 0))
	add_child(_mill_blades)
