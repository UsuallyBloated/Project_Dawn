@tool
class_name ZoneLandmarks
extends ZoneDressing

# The zone's set pieces outside the town: what stands at each camp and at the
# places the composition sketches name (the pass, the Sunken Barrow's ward
# stones and door, the Ossuary on its crest, the Wraith Gate's arch, the
# Broken Crypt, the gnolls' and bandits' camps, the graves, the dens). Each
# is built from the prop kit (zone_props.gd) on the ground at its place in
# data/zone_layout.gd, so a set piece follows its SITES entry.
#
# Placeholder shapes, scenery only (see zone_dressing.gd): they tell a player
# where they are and what lives there, they collide with nothing, and the
# mobs themselves are the server's (zone_camps.toml).

# How far a camp's dressing is drawn, and a landmark meant to be seen from
# across the zone (0: always).
const CAMP_RANGE := 1100.0
const LANDMARK_RANGE := 0.0

const MOSSY_STONE := Color(0.40, 0.43, 0.37)
const BONE_STONE := Color(0.80, 0.77, 0.67)
const DIRT := Color(0.36, 0.29, 0.20)
const SICK := Color(0.62, 0.66, 0.26)
const WEB := Color(0.66, 0.68, 0.67)
const WRAITH_LIGHT := Color(0.45, 0.92, 1.0)
const BARROW_LIGHT := Color(0.62, 1.0, 0.38)


func _build() -> void:
	_build_pass()
	_build_barrow()
	_build_ossuary()
	_build_wraith_gate()
	_build_crypt()
	_build_raider_camp()
	_build_war_camp()
	_build_bandit_outpost()
	_build_bonepile()
	_build_graves()
	_build_dens()
	_build_festering_mound()
	_build_spider_copse()
	_build_road_ends()
	_build_milestones()


func _site(site_name: String) -> Vector2:
	return ZoneLayout.SITES[site_name]


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# A point `radius` from `center` at `angle` (0 is east, a quarter turn north).
static func _around(center: Vector2, radius: float, angle: float) -> Vector2:
	return center + Vector2(cos(angle), sin(angle)) * radius


# The yaw that turns a prop's front (-z) from `from` towards `to`.
static func _facing(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)


# A campfire with its light and smoke.
func _fire(b: LowPoly, glow: LowPoly, at: Vector2, size: float = 1.0) -> void:
	ZoneProps.campfire(b, glow, stand(at), size)
	add_light(on_ground(at, 1.2 * size), ZoneProps.FLAME, 2.0 * size, 14.0 * size, true)
	add_smoke(on_ground(at, 1.6 * size), 1.3 * size)


# A ring (or an arc) of palisade stakes round `center`, leaning out a little.
func _palisade(b: LowPoly, center: Vector2, radius: float, from_angle: float, to_angle: float, height: float, rng: RandomNumberGenerator) -> void:
	var count := maxi(2, int(absf(to_angle - from_angle) * radius / 1.5))
	for i in count + 1:
		var a := lerpf(from_angle, to_angle, float(i) / count)
		var at := _around(center, radius + rng.randf_range(-0.25, 0.25), a)
		ZoneProps.stake(b, stand(at, _facing(at, center) + PI), height * rng.randf_range(0.85, 1.12), rng.randf_range(0.05, 0.2))


# --- The pass ------------------------------------------------------------

# Four braziers on stone piers at the pass's mouths, and the two old stones
# that mark the way north.
func _build_pass() -> void:
	var b := LowPoly.new(101)
	var glow := LowPoly.new(102)
	var half := ZoneLayout.PASS_HALF_WIDTH - 4.0
	for z in [ZoneLayout.PASS_SOUTH_Z - 6.0, ZoneLayout.PASS_NORTH_Z + 6.0]:
		for sx in [-1.0, 1.0]:
			var at := Vector2(ZoneLayout.PASS_X + sx * half, z)
			b.box(stand(at), Vector3(2.0, 4.2, 2.0), ZoneProps.STONE_DARK)
			b.column(stand(at, 0.0, 4.2), 0.5, 0.9, 0.7, 6, Color(0.2, 0.2, 0.22))
			glow.cone(stand(at, 0.0, 4.9), 0.7, 1.7, 5, ZoneProps.FLAME)
			add_light(on_ground(at, 6.0), ZoneProps.FLAME, 3.0, 26.0, true)
	for sx in [-1.0, 1.0]:
		var at := Vector2(ZoneLayout.PASS_X + sx * (half + 10.0), ZoneLayout.PASS_SOUTH_Z - 34.0)
		ZoneProps.standing_stone(b, stand(at, sx * 0.4), 3.0, 11.0, sx * 0.05)
	ZoneProps.signpost(b, stand(Vector2(ZoneLayout.PASS_X + 9.0, ZoneLayout.PASS_SOUTH_Z - 46.0), 0.3))
	add_piece(b, "Pass", 2600.0)
	add_glow(glow, "PassFires", 3.0, 2600.0)


# --- The Sunken Barrow ---------------------------------------------------

# The ward stones round the pit's rim, some fallen; the barrow's door in the
# pit's west wall, with the sick light behind it; bones on the pit's floor.
func _build_barrow() -> void:
	var b := LowPoly.new(111)
	var glow := LowPoly.new(112)
	var rng := _rng(111)
	var pit := _site("The Sunken Barrow")
	var stones := 16
	for i in stones:
		var at := _around(pit, 214.0 + rng.randf_range(-6, 6), i * TAU / stones + rng.randf_range(-0.08, 0.08))
		var fallen := i % 4 == 2
		ZoneProps.standing_stone(b, stand(at, rng.randf() * TAU, 0.6 if fallen else 0.0), 2.4, rng.randf_range(7.0, 9.5),
			1.45 if fallen else rng.randf_range(-0.12, 0.22), ZoneProps.STONE_DARK.lightened(0.08))
	add_piece(b, "WardStones", LANDMARK_RANGE)

	var door := LowPoly.new(113)
	var mouth := ZoneLayout.BARROW_MOUTH
	# The door looks east, across the pit's floor.
	var xf := stand(mouth, -PI * 0.5)
	# Big enough to be the thing the eye goes to from the pit's far rim, 300 m off.
	for sx in [-1.0, 1.0]:
		door.box(xf.translated_local(Vector3(sx * 6.4, 0, 0)), Vector3(3.2, 13.0, 4.0), ZoneProps.STONE_DARK)
	door.box(xf.translated_local(Vector3(0, 13.0, 0)), Vector3(19.0, 3.0, 4.8), ZoneProps.STONE_DARK.lightened(0.05))
	door.box(xf.translated_local(Vector3(0, 0, 3.0)), Vector3(10.0, 12.8, 2.0), ZoneProps.SHADOW)
	for i in 9:
		door.blob(xf.translated_local(Vector3(rng.randf_range(-13, 13), rng.randf_range(4, 14), rng.randf_range(6, 16))),
			Vector3(rng.randf_range(5, 9), rng.randf_range(3, 6), rng.randf_range(5, 9)), 0.25, ZoneLayout.COLOR_BARROW_EARTH.lightened(0.1))
	glow.sheet(xf * Vector3(-4.6, 0.3, 1.8), xf * Vector3(4.6, 0.3, 1.8), xf * Vector3(4.6, 12.2, 1.8), xf * Vector3(-4.6, 12.2, 1.8), BARROW_LIGHT)
	add_light(xf * Vector3(0, 6.0, -6.0), BARROW_LIGHT, 6.0, 60.0)
	for i in 9:
		var at := pit + Vector2(rng.randf_range(-70, 40), rng.randf_range(-55, 55))
		door.blob(stand(at, rng.randf() * TAU, 0.2), Vector3(1.6, 0.5, 1.4), 0.3, ZoneProps.BONE)
		door.cone(stand(at + Vector2(0.4, 0.3), rng.randf() * TAU, 0.3), 0.12, 1.3, 4, ZoneProps.BONE)
	add_piece(door, "BarrowDoor", 1400.0)
	add_glow(glow, "BarrowLight", 2.2, 1400.0)


# --- The Ossuary ---------------------------------------------------------

# Bone-pale spires on the western hills' crest, tall enough to be picked out
# from the town's east road at sunset.
func _build_ossuary() -> void:
	var b := LowPoly.new(121)
	var rng := _rng(121)
	var at := ZoneLayout.OSSUARY_RUIN
	ZoneProps.spire(b, stand(at), 3.4, 46.0, BONE_STONE)
	var ring := 9
	for i in ring:
		var p := _around(at, 24.0 + rng.randf_range(-3, 3), i * TAU / ring + rng.randf_range(-0.1, 0.1))
		ZoneProps.spire(b, stand(p, rng.randf() * TAU), rng.randf_range(1.6, 2.5), rng.randf_range(20.0, 36.0), BONE_STONE, i % 3 == 1)
	for i in 3:
		var p := _around(at, 13.0, i * TAU / 3.0 + 0.5)
		ZoneProps.arch(b, stand(p, i * TAU / 3.0 + 0.5), 9.0, 6.0, 1.6, 1.8, BONE_STONE.darkened(0.06), 7)
	b.column(stand(at), 30.0, 28.0, 0.9, 12, BONE_STONE.darkened(0.18))
	for i in 12:
		var p := _around(at, rng.randf_range(8, 40), rng.randf() * TAU)
		b.blob(stand(p, rng.randf() * TAU, 0.3), Vector3(1.3, 0.9, 1.1) * rng.randf_range(0.7, 1.6), 0.25, BONE_STONE)
	add_piece(b, "Ossuary", LANDMARK_RANGE)


# --- The Wraith Gate -----------------------------------------------------

# The arch on the plateau, its opening filled with cold light and facing the
# cliff, so it is seen from the flats below.
func _build_wraith_gate() -> void:
	var b := LowPoly.new(131)
	var glow := LowPoly.new(132)
	var rng := _rng(131)
	var at := ZoneLayout.WRAITH_GATE_ARCH
	var span := 20.0
	var pier := 26.0
	# The arch runs north to south, so its opening faces west and east.
	var xf := stand(at, PI * 0.5)
	ZoneProps.arch(b, xf, span, pier, 6.0, 7.0, ZoneProps.STONE_DARK, 11)
	for step in 3:
		b.box(xf.translated_local(Vector3(0, 0, 0)), Vector3(span + 18.0 - step * 4.0, 0.6 * (step + 1), 16.0 - step * 3.0), ZoneProps.STONE_DARK.lightened(0.04 * step))
	for i in 6:
		var p := at + Vector2(rng.randf_range(-34, 34), rng.randf_range(-44, 44))
		if absf(p.y - at.y) < 18.0 and absf(p.x - at.x) < 8.0:
			continue
		ZoneProps.spire(b, stand(p, rng.randf() * TAU), 2.2, rng.randf_range(7.0, 18.0), ZoneProps.STONE_DARK.lightened(0.05), true)
	add_piece(b, "WraithGate", LANDMARK_RANGE)

	# The light: the opening's shape as a fan of triangles.
	var r := span * 0.5
	var lift := 1.8
	glow.sheet(xf * Vector3(-r, lift, 0), xf * Vector3(r, lift, 0), xf * Vector3(r, pier, 0), xf * Vector3(-r, pier, 0), WRAITH_LIGHT)
	var fan := 8
	for i in fan:
		var a0 := PI * i / fan
		var a1 := PI * (i + 1) / fan
		glow.tri(xf * Vector3(0, pier, 0), xf * Vector3(cos(a0) * r, pier + sin(a0) * r, 0), xf * Vector3(cos(a1) * r, pier + sin(a1) * r, 0), WRAITH_LIGHT)
	add_glow(glow, "WraithGateLight", 1.5, LANDMARK_RANGE)
	add_light(on_ground(at, 16.0), WRAITH_LIGHT, 6.0, 70.0)


# --- The Broken Crypt ----------------------------------------------------

# A roofless mausoleum in the wood's bowl: broken walls, toppled columns, a
# sarcophagus with its lid pushed off.
func _build_crypt() -> void:
	var b := LowPoly.new(141)
	var rng := _rng(141)
	var at := ZoneLayout.BROKEN_CRYPT
	var half := Vector2(11.0, 15.0)
	# The walls, as stretches of different heights with gaps between them.
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var c: Vector2 = corners[(side + 1) % 4]
		var pieces := 4
		for i in pieces:
			if rng.randf() < 0.22 or (side == 0 and i == 1):
				continue
			var p0 := at + a.lerp(c, float(i) / pieces)
			var p1 := at + a.lerp(c, float(i + 0.86) / pieces)
			ZoneProps.wall(b, on_ground(p0), on_ground(p1), rng.randf_range(1.6, 6.5), 1.3, MOSSY_STONE)
		b.column(stand(at + a), 1.1, 0.9, rng.randf_range(4.0, 8.0), 6, MOSSY_STONE.lightened(0.06))
	for i in 6:
		var p := at + Vector2(-6.0 if i % 2 == 0 else 6.0, -9.0 + (i / 2) * 9.0)
		if rng.randf() < 0.4:
			b.column(stand(p, rng.randf() * TAU, 0.5) * Transform3D(Basis(Vector3.RIGHT, 1.5), Vector3.ZERO), 0.7, 0.6, 5.0, 6, ZoneProps.STONE_PALE.darkened(0.15))
		else:
			b.column(stand(p), 0.7, 0.6, rng.randf_range(2.5, 6.0), 6, ZoneProps.STONE_PALE.darkened(0.15))
	b.box(stand(at), Vector3(1.6, 1.1, 3.2), ZoneProps.STONE_DARK)
	b.box(stand(at + Vector2(1.0, 0.4), 0.35, 0.7) * Transform3D(Basis(Vector3(0, 0, 1), -0.5), Vector3.ZERO), Vector3(1.8, 0.25, 3.4), ZoneProps.STONE_DARK.lightened(0.08))
	b.box(stand(at + Vector2(0, -19.0)), Vector3(4.0, 0.5, 3.0), MOSSY_STONE)
	b.box(stand(at + Vector2(0, -22.0)), Vector3(4.0, 0.25, 3.0), MOSSY_STONE)
	add_piece(b, "BrokenCrypt", 1800.0)


# --- The gnolls ----------------------------------------------------------

# The raiders' camp by the east road: hide tents round a fire, a skull totem,
# a line of stakes on the town's side, and the wagon they took.
func _build_raider_camp() -> void:
	var b := LowPoly.new(151)
	var glow := LowPoly.new(152)
	var rng := _rng(151)
	var at := _site("Gnoll Raider Camp")
	for offset in [Vector2(-10, 7), Vector2(9, 9), Vector2(-3, -11), Vector2(12, -5)]:
		var p: Vector2 = at + offset
		ZoneProps.tent(b, stand(p, _facing(p, at)), rng.randf_range(2.6, 3.4), rng.randf_range(3.4, 4.2))
	_fire(b, glow, at)
	ZoneProps.totem(b, stand(at + Vector2(4.5, 3.0), 0.4), 4.6)
	ZoneProps.totem(b, stand(at + Vector2(-14, -5), 1.9), 3.6)
	_palisade(b, at, 21.0, PI * 0.7, PI * 1.3, 2.6, rng)
	for i in 5:
		var p := at + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
		if p.distance_to(at) < 2.5:
			continue
		if i % 2 == 0:
			ZoneProps.barrel(b, stand(p))
		else:
			ZoneProps.crate(b, stand(p, rng.randf() * TAU))
	for i in 3:
		b.column(stand(at + Vector2(-2.6 + i * 2.4, 2.8), 0.3 + i, 0.25) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.22, 0.2, 1.8, 5, ZoneProps.TIMBER)
	add_piece(b, "GnollRaiderCamp", CAMP_RANGE)
	add_glow(glow, "GnollRaiderFire", 3.0, CAMP_RANGE)

	# The wagon, on its side by the road.
	var w := LowPoly.new(153)
	var wagon := stand(ZoneLayout.WAGON_WRECK, 0.7) * Transform3D(Basis(Vector3(0, 0, 1), 0.38), Vector3(0, 0.4, 0))
	w.box(wagon, Vector3(2.0, 0.9, 4.0), ZoneProps.TIMBER_PALE)
	w.box(wagon.translated_local(Vector3(0, 0, 3.0)), Vector3(0.14, 0.14, 2.4), ZoneProps.TIMBER)
	for wheel in [Vector3(1.15, 0.3, -1.3), Vector3(1.15, 0.3, 1.3)]:
		w.column(wagon.translated_local(wheel) * Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3.ZERO), 0.75, 0.75, 0.16, 8, ZoneProps.TIMBER)
	w.column(stand(ZoneLayout.WAGON_WRECK + Vector2(2.6, -1.2), 0.2, 0.08) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.75, 0.75, 0.16, 8, ZoneProps.TIMBER)
	ZoneProps.barrel(w, stand(ZoneLayout.WAGON_WRECK + Vector2(-2.4, 1.6)))
	ZoneProps.crate(w, stand(ZoneLayout.WAGON_WRECK + Vector2(-1.2, 2.9), 0.5))
	ZoneProps.crate(w, stand(ZoneLayout.WAGON_WRECK + Vector2(-3.0, -0.6), 1.1), 0.8)
	add_piece(w, "WagonWreck", 700.0)


# The war camp on its shelf: a stake wall with a gate to the north, tents
# and totems round a great fire, lookouts at the gate; and Greth's tent in
# its own ring behind.
func _build_war_camp() -> void:
	var b := LowPoly.new(161)
	var glow := LowPoly.new(162)
	var rng := _rng(161)
	var at := _site("Gnoll War Camp")
	# The gate is the gap at the ring's north (a quarter turn).
	_palisade(b, at, 62.0, PI * 0.5 + 0.11, PI * 2.5 - 0.11, 4.2, rng)
	for sx in [-1.0, 1.0]:
		var gate_at := _around(at, 62.0, PI * 0.5 + sx * 0.13)
		ZoneProps.lookout(b, stand(gate_at + Vector2(sx * 3.0, -4.0)), 6.0)
		ZoneProps.banner(b, stand(gate_at, PI * 0.5), 7.5, 2.2, 3.4, ZoneProps.BANNER_RED)
	for i in 9:
		var p := _around(at, rng.randf_range(24, 46), i * TAU / 9.0 + rng.randf_range(-0.15, 0.15))
		ZoneProps.tent(b, stand(p, _facing(p, at)), rng.randf_range(2.8, 3.8), rng.randf_range(3.6, 4.6), ZoneProps.HIDE if i % 3 != 0 else ZoneProps.HIDE_DARK)
	_fire(b, glow, at, 1.8)
	for i in 4:
		var p := _around(at, 9.0, i * TAU / 4.0 + 0.6)
		ZoneProps.totem(b, stand(p, _facing(p, at)), rng.randf_range(4.2, 5.6))
	for i in 10:
		var p := _around(at, rng.randf_range(12, 50), rng.randf() * TAU)
		if i % 3 == 0:
			ZoneProps.barrel(b, stand(p))
		else:
			ZoneProps.crate(b, stand(p, rng.randf() * TAU), rng.randf_range(0.8, 1.2))
	add_piece(b, "GnollWarCamp", 2600.0)

	var g := LowPoly.new(163)
	var greth := _site("Greth's tent")
	ZoneProps.tent(g, stand(greth + Vector2(0, -7), _facing(greth + Vector2(0, -7), greth)), 6.0, 7.5, ZoneProps.HIDE_DARK)
	_palisade(g, greth, 17.0, PI * 0.5 + 0.5, PI * 2.5 - 0.5, 3.6, rng)
	for sx in [-1.0, 1.0]:
		ZoneProps.totem(g, stand(greth + Vector2(sx * 6.0, 2.0), 0.0), 5.6)
		ZoneProps.banner(g, stand(greth + Vector2(sx * 9.0, -3.0), PI * 0.5), 6.5, 2.0, 3.0, ZoneProps.BANNER_RED)
	_fire(g, glow, greth + Vector2(0, 4.0), 1.2)
	add_piece(g, "GrethsTent", 1600.0)
	add_glow(glow, "GnollWarFires", 3.0, 2600.0)


# --- The bandits ---------------------------------------------------------

# The outpost on its knoll: a lookout, a stake wall towards the roads, two
# lean-tos and canvas tents round a fire.
func _build_bandit_outpost() -> void:
	var b := LowPoly.new(171)
	var glow := LowPoly.new(172)
	var rng := _rng(171)
	var at := _site("Bandit Outpost")
	ZoneProps.lookout(b, stand(at + Vector2(6, -8)), 7.5)
	_palisade(b, at, 24.0, -PI * 0.85, PI * 0.15, 3.4, rng)
	ZoneProps.shed(b, stand(at + Vector2(-11, 6), 0.4), 5.0, 3.6, 2.2, 1.4, ZoneProps.ROOF_THATCH)
	ZoneProps.shed(b, stand(at + Vector2(10, 9), -0.7), 5.0, 3.6, 2.2, 1.4, ZoneProps.ROOF_THATCH)
	for offset in [Vector2(-6, -10), Vector2(-14, -3)]:
		var p: Vector2 = at + offset
		ZoneProps.tent(b, stand(p, _facing(p, at)), 2.6, 3.2, ZoneProps.CANVAS.darkened(0.15))
	_fire(b, glow, at)
	ZoneProps.banner(b, stand(at + Vector2(9, -11), 0.3), 9.5, 2.4, 3.0, Color(0.16, 0.14, 0.14))
	for i in 6:
		var p := at + Vector2(rng.randf_range(-9, 9), rng.randf_range(-8, 8))
		if p.distance_to(at) < 2.5:
			continue
		if i % 2 == 0:
			ZoneProps.crate(b, stand(p, rng.randf() * TAU))
		else:
			ZoneProps.barrel(b, stand(p))
	add_piece(b, "BanditOutpost", 1600.0)
	add_glow(glow, "BanditFire", 3.0, CAMP_RANGE)


# --- The restless dead ---------------------------------------------------

# The Bonepile: heaps of bone with ribs standing out of them.
func _build_bonepile() -> void:
	var b := LowPoly.new(181)
	var rng := _rng(181)
	var at := _site("Bonepile")
	for offset in [Vector2(0, 0), Vector2(-14, 12), Vector2(10, 18), Vector2(8, -16), Vector2(-18, -6), Vector2(3, -62)]:
		var p: Vector2 = at + offset
		var s := rng.randf_range(0.8, 1.5)
		b.blob(stand(p, rng.randf() * TAU, 0.3 * s), Vector3(3.2, 1.3, 2.8) * s, 0.3, ZoneProps.BONE.darkened(0.08))
		for i in 6:
			var r := p + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5)) * s
			b.cone(stand(r, rng.randf() * TAU, 0.4) * Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)), Vector3.ZERO), 0.14, rng.randf_range(1.4, 2.6) * s, 4, ZoneProps.BONE)
		b.blob(stand(p + Vector2(2.4, 1.0) * s, rng.randf() * TAU, 0.5), Vector3(0.4, 0.38, 0.46), 0.12, ZoneProps.BONE)
	add_piece(b, "Bonepile", CAMP_RANGE)


# Shallow Graves: leaning markers, a low broken wall, a lych gate.
func _build_graves() -> void:
	var b := LowPoly.new(191)
	var rng := _rng(191)
	var at := _site("Shallow Graves")
	for i in 30:
		var p := _around(at, rng.randf_range(5, 40), rng.randf() * TAU)
		ZoneProps.grave(b, stand(p, rng.randf_range(-0.3, 0.3)), rng.randf_range(-0.3, 0.3))
	var corners := [Vector2(-44, -44), Vector2(44, -44), Vector2(44, 44), Vector2(-44, 44)]
	for side in 4:
		for i in 5:
			if rng.randf() < 0.35 or (side == 0 and i == 2):
				continue
			var a: Vector2 = at + (corners[side] as Vector2).lerp(corners[(side + 1) % 4], i / 5.0)
			var c: Vector2 = at + (corners[side] as Vector2).lerp(corners[(side + 1) % 4], (i + 0.8) / 5.0)
			b.box(LowPoly.at((on_ground(a) + on_ground(c)) * 0.5, atan2(-(c.y - a.y), c.x - a.x)), Vector3(a.distance_to(c), rng.randf_range(0.6, 1.3), 0.7), MOSSY_STONE)
	var gate := at + Vector2(0, -44)
	for sx in [-1.0, 1.0]:
		b.box(stand(gate + Vector2(sx * 2.2, 0)), Vector3(0.4, 3.4, 0.4), ZoneProps.TIMBER)
	b.gable(stand(gate, PI * 0.5, 3.4), Vector3(2.2, 0.9, 5.6), ZoneProps.ROOF_SLATE)
	add_piece(b, "ShallowGraves", CAMP_RANGE)


# --- Dens ----------------------------------------------------------------

# The beasts' places: the rats' burrows, the wolves' rocks, the bats' cave
# mouth and Sable's crag, and the standing rocks of Rotfang's den.
func _build_dens() -> void:
	var b := LowPoly.new(201)
	var rng := _rng(201)

	var rats := _site("Rat Warrens")
	for i in 7:
		var p := _around(rats, rng.randf_range(3, 16), rng.randf() * TAU)
		b.blob(stand(p, rng.randf() * TAU, 0.2), Vector3(2.3, 1.0, 2.1), 0.25, DIRT)
		b.blob(stand(p + Vector2(1.1, 0.5), 0.0, 0.45), Vector3(0.7, 0.55, 0.5), 0.1, ZoneProps.SHADOW)
	b.box(stand(rats + Vector2(-6, 18), 0.3, 0.05), Vector3(2.6, 0.18, 3.2), ZoneProps.TIMBER)
	ZoneProps.crate(b, stand(rats + Vector2(-3, 16), 0.9), 0.9)
	ZoneProps.barrel(b, stand(rats + Vector2(-8.5, 15.5)), 0.9)

	var wolves := _site("Wolf Run")
	for offset in [Vector2(0, 0), Vector2(5, 3), Vector2(-4, 4), Vector2(1, -5)]:
		b.blob(stand(wolves + offset, rng.randf() * TAU, 1.2), Vector3(3.6, 2.6, 3.0) * rng.randf_range(0.8, 1.3), 0.28, ZoneProps.STONE_DARK.lightened(0.08))
	b.blob(stand(wolves + Vector2(1, 1.5), 0.0, 0.8), Vector3(1.4, 1.1, 1.2), 0.1, ZoneProps.SHADOW)

	var bats := _site("Bat Hollow")
	for offset in [Vector2(-7, 2), Vector2(7, 2), Vector2(0, 7), Vector2(-4, 8), Vector2(5, 8)]:
		b.blob(stand(bats + offset, rng.randf() * TAU, 2.6), Vector3(6.0, 5.0, 5.0) * rng.randf_range(0.8, 1.2), 0.3, ZoneProps.STONE_DARK)
	b.blob(stand(bats + Vector2(0, 9), 0.0, 6.5), Vector3(8.5, 3.0, 5.5), 0.25, ZoneProps.STONE_DARK.lightened(0.05))
	b.blob(stand(bats + Vector2(0, 3.2), 0.0, 2.2), Vector3(3.6, 3.0, 2.4), 0.1, ZoneProps.SHADOW)

	var roost := _site("Sable's roost")
	b.column(stand(roost + Vector2(0, 9)), 5.0, 1.6, 19.0, 6, ZoneProps.STONE_DARK)
	b.column(stand(roost + Vector2(6, 12), 0.7), 3.0, 0.9, 11.0, 5, ZoneProps.STONE_DARK.lightened(0.06))
	b.column(stand(roost + Vector2(0, 9), 0.0, 19.0), 0.3, 0.1, 4.0, 4, ZoneProps.TIMBER.darkened(0.3))
	b.column(stand(roost + Vector2(0, 9), 0.0, 21.0) * LowPoly.leaning(Vector3.ZERO, 0.6, 1.1), 0.1, 0.03, 2.4, 3, ZoneProps.TIMBER.darkened(0.3))

	var den := _site("Rotfang's Den")
	for i in 8:
		var p := _around(den, rng.randf_range(12, 19), i * TAU / 8.0 + rng.randf_range(-0.2, 0.2))
		ZoneProps.standing_stone(b, stand(p, rng.randf() * TAU), rng.randf_range(2.2, 3.4), rng.randf_range(5.0, 10.0), rng.randf_range(-0.15, 0.2))
	var lair := den + Vector2(-12, -36)
	for offset in [Vector2(-4, -3), Vector2(4, -3), Vector2(0, -6)]:
		b.blob(stand(lair + offset, rng.randf() * TAU, 1.6), Vector3(4.5, 3.4, 4.0), 0.28, ZoneProps.STONE_DARK)
	b.blob(stand(lair + Vector2(0, -2.6), 0.0, 1.0), Vector3(1.8, 1.4, 1.4), 0.1, ZoneProps.SHADOW)
	for i in 6:
		var p := lair + Vector2(rng.randf_range(-7, 7), rng.randf_range(2, 9))
		b.cone(stand(p, rng.randf() * TAU, 0.1) * Transform3D(Basis(Vector3.RIGHT, 1.3), Vector3.ZERO), 0.1, 1.2, 4, ZoneProps.BONE)
	add_piece(b, "Dens", 1500.0)


# The Festering Mound: pale swellings on sick ground, under a faint light.
func _build_festering_mound() -> void:
	var b := LowPoly.new(211)
	var rng := _rng(211)
	var at := _site("Festering Mound")
	for i in 18:
		var p := _around(at, rng.randf_range(2, 34), rng.randf() * TAU)
		var s := rng.randf_range(0.6, 2.0)
		b.blob(stand(p, rng.randf() * TAU, 0.35 * s), Vector3(1.0, 0.8, 1.0) * s, 0.2, SICK.lerp(ZoneLayout.COLOR_SICK_GROUND, rng.randf() * 0.5))
	for i in 5:
		var p := _around(at, rng.randf_range(8, 30), rng.randf() * TAU)
		b.column(stand(p, rng.randf() * TAU) * Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), Vector3.ZERO), 0.4, 0.22, rng.randf_range(1.5, 3.2), 5, ZoneProps.TIMBER.darkened(0.35))
	add_piece(b, "FesteringMound", CAMP_RANGE)
	add_light(on_ground(at, 3.0), BARROW_LIGHT, 1.3, 30.0)


# The Spider Copse: cocoons and web tents under the trees, and the Crawler's
# burrow, a webbed pit with its egg sacs.
func _build_spider_copse() -> void:
	var b := LowPoly.new(221)
	var rng := _rng(221)
	var at := _site("Spider Copse")
	for i in 16:
		var p := _around(at, rng.randf_range(6, 60), rng.randf() * TAU)
		b.blob(stand(p, rng.randf() * TAU, 0.9), Vector3(0.55, 1.2, 0.55) * rng.randf_range(0.8, 1.4), 0.15, WEB)
	for i in 12:
		var p := _around(at, rng.randf_range(8, 70), rng.randf() * TAU)
		var top := on_ground(p, rng.randf_range(4.0, 6.5))
		var turn := rng.randf() * TAU
		for k in 3:
			var a0 := turn + k * TAU / 3.0
			var a1 := turn + (k + 1) * TAU / 3.0
			b.sheet(top, on_ground(_around(p, 3.2, a0)), on_ground(_around(p, 3.2, (a0 + a1) * 0.5), 0.5), on_ground(_around(p, 3.2, a1)), WEB.darkened(0.05 * k))
	var burrow := _site("The Crawler's burrow")
	b.column(stand(burrow, 0.0, 0.05), 5.0, 5.0, 0.12, 9, ZoneProps.SHADOW, ZoneProps.SHADOW)
	for i in 9:
		var p := _around(burrow, 5.6, i * TAU / 9.0)
		b.blob(stand(p, rng.randf() * TAU, 0.5), Vector3(1.6, 1.1, 1.4) * rng.randf_range(0.8, 1.3), 0.25, ZoneProps.STONE_DARK)
		if i % 2 == 0:
			b.sheet(on_ground(p, 1.2), on_ground(_around(burrow, 5.6, (i + 1) * TAU / 9.0), 1.2), on_ground(burrow, 0.3), on_ground(burrow, 0.3), WEB)
	for i in 6:
		var p := _around(burrow, rng.randf_range(6.5, 10), rng.randf() * TAU)
		b.blob(stand(p, 0.0, 0.5), Vector3(0.7, 0.8, 0.7) * rng.randf_range(0.8, 1.3), 0.1, WEB.lightened(0.05))
	add_piece(b, "SpiderCopse", CAMP_RANGE)


# --- The roads -----------------------------------------------------------

# Where the roads leave the zone the way is shut: a rockslide across the
# east road with a cart under it, great fallen trees across the north road.
func _build_road_ends() -> void:
	var b := LowPoly.new(231)
	var rng := _rng(231)
	var east := ZoneLayout.EAST_ROAD_END
	for i in 16:
		var p := east + Vector2(rng.randf_range(-6, 12), rng.randf_range(-13, 13))
		var s := rng.randf_range(1.6, 4.6)
		b.blob(stand(p, rng.randf() * TAU, s * 0.5), Vector3(1.2, 0.9, 1.1) * s, 0.3, ZoneProps.STONE_DARK.lightened(0.06))
	b.box(stand(east + Vector2(-9, -2), 0.5) * Transform3D(Basis(Vector3(0, 0, 1), 0.25), Vector3(0, 0.3, 0)), Vector3(1.9, 0.8, 3.6), ZoneProps.TIMBER_PALE)
	ZoneProps.signpost(b, stand(east + Vector2(-14, 5), 2.2))
	var north := ZoneLayout.NORTH_ROAD_END
	for i in 4:
		var p := north + Vector2(rng.randf_range(-9, 9), rng.randf_range(-6, 3))
		b.column(stand(p, rng.randf() * TAU, 1.0) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + rng.randf_range(-0.1, 0.1)), Vector3.ZERO), 1.0, 0.7, rng.randf_range(12, 20), 6, ZoneProps.TIMBER.darkened(0.15))
	for i in 7:
		var p := north + Vector2(rng.randf_range(-12, 12), rng.randf_range(-4, 6))
		var s := rng.randf_range(1.2, 3.4)
		b.blob(stand(p, rng.randf() * TAU, s * 0.5), Vector3(1.2, 0.9, 1.1) * s, 0.3, ZoneProps.STONE_DARK)
	ZoneProps.signpost(b, stand(north + Vector2(5, -12), 0.4))
	add_piece(b, "RoadEnds", 1500.0)


# A stone every MILESTONE_GAP metres along each road, on its right-hand edge.
func _build_milestones() -> void:
	const MILESTONE_GAP := 250.0
	var b := LowPoly.new(241)
	for road in ZoneLayout.ROADS:
		var pts := ZoneLayout.road_points(road)
		var half: float = float(road["width"]) * 0.5 + 1.2
		var walked := MILESTONE_GAP * 0.5
		for i in pts.size() - 1:
			var a := pts[i]
			var c := pts[i + 1]
			var length := a.distance_to(c)
			while walked < length:
				var along := (c - a) / length
				var p := a + along * walked + Vector2(along.y, -along.x) * half
				if maxf(absf(p.x), absf(p.y)) < ZoneLayout.RIM_START and p.length() > ZoneLayout.TOWN_HALF + 20.0:
					b.column(stand(p, atan2(-along.y, along.x)), 0.42, 0.34, 1.15, 5, ZoneProps.STONE_PALE.darkened(0.1))
				walked += MILESTONE_GAP
			walked -= length
	add_piece(b, "Milestones", 500.0)
