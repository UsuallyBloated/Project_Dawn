@tool
class_name ZoneProps
extends RefCounted

# The zone's prop kit: each function adds one recognisable thing (a house, a
# stretch of wall, a tent, a campfire) to a LowPoly builder at a transform.
# zone_town.gd and zone_landmarks.gd place them; nothing here knows where
# anything is. Placeholder shapes, built to be replaced by authored models one
# function at a time: the sizes and colours follow the concept sheets in
# Project_Dawn_Source/concept_art/starting_area.

const STONE_WALL := Color(0.63, 0.58, 0.48)
const STONE_DARK := Color(0.44, 0.42, 0.39)
const STONE_PALE := Color(0.70, 0.68, 0.63)
const TIMBER := Color(0.34, 0.24, 0.16)
const TIMBER_PALE := Color(0.52, 0.40, 0.27)
const PLASTER := Color(0.76, 0.70, 0.56)
const ROOF_SLATE := Color(0.32, 0.33, 0.37)
const ROOF_THATCH := Color(0.62, 0.51, 0.30)
const ROOF_TILE := Color(0.50, 0.28, 0.20)
const HIDE := Color(0.56, 0.43, 0.29)
const HIDE_DARK := Color(0.38, 0.28, 0.19)
const BONE := Color(0.86, 0.83, 0.72)
const SHADOW := Color(0.08, 0.07, 0.06)
const BANNER_GREEN := Color(0.18, 0.47, 0.23)
const BANNER_RED := Color(0.56, 0.13, 0.11)
const CANVAS := Color(0.80, 0.74, 0.60)
const FLAME := Color(1.0, 0.62, 0.18)
const FLAME_CORE := Color(1.0, 0.86, 0.45)
const WINDOW_LIT := Color(1.0, 0.74, 0.36)

const ROOFS := [ROOF_SLATE, ROOF_THATCH, ROOF_TILE, ROOF_SLATE]


static func _up(xf: Transform3D, y: float) -> Transform3D:
	return xf.translated_local(Vector3(0, y, 0))


static func _off(xf: Transform3D, offset: Vector3, yaw: float = 0.0) -> Transform3D:
	return xf.translated_local(offset) * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)


# --- Buildings -----------------------------------------------------------

# A house `w` wide and `d` deep, its door in the middle of its -z side.
# style 0 is stone, 1 plaster in a timber frame, 2 stone below and plaster
# above. `glow` (if given) takes its lit windows.
static func house(b: LowPoly, xf: Transform3D, w: float, d: float, wall_h: float, roof_h: float, style: int, roof: Color, glow: LowPoly = null) -> void:
	var lower := STONE_WALL if style != 1 else PLASTER
	if style == 2:
		b.box(xf, Vector3(w, wall_h * 0.5, d), STONE_WALL)
		b.box(_up(xf, wall_h * 0.5), Vector3(w + 0.3, wall_h * 0.5, d + 0.3), PLASTER)
	else:
		b.box(xf, Vector3(w, wall_h, d), lower)
	if style != 0:
		# The frame: corner posts and a beam under the eaves.
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				b.box(_off(xf, Vector3(sx * (w * 0.5 + 0.02), 0, sz * (d * 0.5 + 0.02))), Vector3(0.34, wall_h, 0.34), TIMBER)
		b.box(_up(xf, wall_h - 0.3), Vector3(w + 0.36, 0.3, d + 0.36), TIMBER)
	b.gable(_up(xf, wall_h), Vector3(w + 1.2, roof_h, d + 1.2), roof, lower.darkened(0.08))
	b.box(_off(xf, Vector3(w * 0.26, wall_h + roof_h * 0.25, d * 0.18)), Vector3(0.9, roof_h * 0.75 + 0.9, 0.9), STONE_DARK)
	# The door, and a window either side of it.
	b.box(_off(xf, Vector3(0, 0, -d * 0.5 - 0.06)), Vector3(1.25, 2.15, 0.14), TIMBER.darkened(0.2))
	var panes := glow if glow != null else b
	for sx in [-1.0, 1.0]:
		panes.box(_off(xf, Vector3(sx * w * 0.3, 1.25, -d * 0.5 - 0.05)), Vector3(0.8, 0.9, 0.1), WINDOW_LIT if glow != null else SHADOW)


# A stretch of battlemented wall from `a` to `c` (both on the ground),
# `height` tall and `thick` through, its merlons on its left-hand edge.
static func wall(b: LowPoly, a: Vector3, c: Vector3, height: float, thick: float, color: Color = STONE_WALL) -> void:
	var along := c - a
	var length := Vector2(along.x, along.z).length()
	if length < 0.01:
		return
	var yaw := atan2(-along.z, along.x)
	var xf := LowPoly.at((a + c) * 0.5, yaw)
	b.box(xf, Vector3(length, height, thick), color, color.lightened(0.1))
	var merlons := maxi(1, int(length / 3.2))
	for i in merlons:
		var x := -length * 0.5 + (i + 0.5) * length / merlons
		b.box(_off(xf, Vector3(x, height, -thick * 0.32)), Vector3(1.5, 0.95, thick * 0.36), color.darkened(0.04))


# A square tower `w` wide: a shaft, a wider belt at its head, battlements, and
# a pointed roof `roof_h` high (0 for an open top).
static func tower(b: LowPoly, xf: Transform3D, w: float, height: float, roof_h: float, roof: Color = ROOF_SLATE, color: Color = STONE_WALL) -> void:
	b.box(xf, Vector3(w, height, w), color)
	b.box(_up(xf, height - 1.6), Vector3(w + 0.9, 1.6, w + 0.9), color.darkened(0.06))
	for i in 4:
		var side := Transform3D(Basis(Vector3.UP, i * PI * 0.5), Vector3.ZERO)
		for k in [-1.0, 0.0, 1.0]:
			b.box(xf * side * LowPoly.at(Vector3(k * w * 0.36, height, w * 0.5 + 0.2)), Vector3(w * 0.2, 1.0, 0.5), color)
	# Arrow slits.
	for i in 4:
		var side := Transform3D(Basis(Vector3.UP, i * PI * 0.5), Vector3.ZERO)
		b.box(xf * side * LowPoly.at(Vector3(0, height * 0.55, w * 0.5 + 0.03)), Vector3(0.35, 1.5, 0.08), SHADOW)
	if roof_h > 0.0:
		b.column(_off(_up(xf, height + 0.2), Vector3.ZERO, PI * 0.25), w * 0.74, 0.0, roof_h, 4, roof)


# A gatehouse across a wall: two piers and a lintel over an opening `opening`
# wide and `clear` high, the way through along its z. Its doors stand open.
static func gate(b: LowPoly, xf: Transform3D, opening: float, clear: float, depth: float) -> void:
	var pier_w := 3.4
	var top := clear + 3.0
	for sx in [-1.0, 1.0]:
		b.box(_off(xf, Vector3(sx * (opening + pier_w) * 0.5, 0, 0)), Vector3(pier_w, top + 1.2, depth), STONE_WALL)
		for k in [-0.3, 0.3]:
			b.box(_off(xf, Vector3(sx * (opening + pier_w) * 0.5 + k * pier_w, top + 1.2, -depth * 0.3)), Vector3(0.9, 0.9, depth * 0.3), STONE_WALL)
		# The arch's shoulders, so the opening reads as an arch.
		var inner: float = sx * opening * 0.5
		b.tri(xf * Vector3(inner, clear - 2.2, -depth * 0.5 - 0.02), xf * Vector3(inner, clear, -depth * 0.5 - 0.02),
			xf * Vector3(inner - sx * 2.2, clear, -depth * 0.5 - 0.02), STONE_WALL.darkened(0.12))
		b.tri(xf * Vector3(inner, clear - 2.2, depth * 0.5 + 0.02), xf * Vector3(inner, clear, depth * 0.5 + 0.02),
			xf * Vector3(inner - sx * 2.2, clear, depth * 0.5 + 0.02), STONE_WALL.darkened(0.12))
		# A door leaf, swung open against the pier.
		b.box(_off(xf, Vector3(sx * (opening * 0.5 - 0.12), 0, -depth * 0.5 - opening * 0.24), PI * 0.5), Vector3(opening * 0.48, clear - 0.4, 0.22), TIMBER)
	b.box(_up(xf, clear), Vector3(opening + 0.2, top - clear, depth), STONE_WALL.darkened(0.04))
	for k in [-0.33, 0.0, 0.33]:
		b.box(_off(xf, Vector3(k * opening, top, -depth * 0.3)), Vector3(1.4, 0.9, depth * 0.3), STONE_WALL)


# A banner on a pole: the pole's foot at the transform, the cloth streaming
# along +x from its head.
static func banner(b: LowPoly, xf: Transform3D, pole: float, length: float, drop: float, color: Color) -> void:
	b.column(xf, 0.09, 0.06, pole, 4, TIMBER)
	var top := pole - 0.15
	var steps := 3
	for i in steps:
		var x0 := length * i / steps
		var x1 := length * (i + 1) / steps
		var sag0 := 0.25 * sin(i * 1.3)
		var sag1 := 0.25 * sin((i + 1) * 1.3)
		var taper := 1.0 - 0.35 * float(i + 1) / steps
		var taper0 := 1.0 - 0.35 * float(i) / steps
		b.sheet(xf * Vector3(x0, top, sag0), xf * Vector3(x1, top, sag1),
			xf * Vector3(x1, top - drop * taper, sag1), xf * Vector3(x0, top - drop * taper0, sag0), color)


# An open-sided shed: four posts under a gabled roof.
static func shed(b: LowPoly, xf: Transform3D, w: float, d: float, post_h: float, roof_h: float, roof: Color) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(_off(xf, Vector3(sx * w * 0.45, 0, sz * d * 0.45)), Vector3(0.3, post_h, 0.3), TIMBER)
	b.gable(_up(xf, post_h), Vector3(w + 0.8, roof_h, d + 0.8), roof, TIMBER_PALE)


# A market stall: a table, four poles and a striped awning sloping to the front (-z).
static func stall(b: LowPoly, xf: Transform3D, w: float, d: float, awning: Color) -> void:
	b.box(_off(xf, Vector3(0, 0, 0)), Vector3(w, 0.95, d * 0.5), TIMBER_PALE, TIMBER_PALE.lightened(0.1))
	for sx in [-1.0, 1.0]:
		b.box(_off(xf, Vector3(sx * w * 0.5, 0, d * 0.45)), Vector3(0.14, 2.9, 0.14), TIMBER)
		b.box(_off(xf, Vector3(sx * w * 0.5, 0, -d * 0.45)), Vector3(0.14, 2.3, 0.14), TIMBER)
	var stripes := 4
	for i in stripes:
		var x0 := -w * 0.55 + w * 1.1 * i / stripes
		var x1 := -w * 0.55 + w * 1.1 * (i + 1) / stripes
		b.sheet(xf * Vector3(x0, 2.95, d * 0.5), xf * Vector3(x1, 2.95, d * 0.5),
			xf * Vector3(x1, 2.3, -d * 0.6), xf * Vector3(x0, 2.3, -d * 0.6), awning if i % 2 == 0 else CANVAS)


# --- Small things --------------------------------------------------------

static func barrel(b: LowPoly, xf: Transform3D, s: float = 1.0) -> void:
	b.column(xf, 0.38 * s, 0.44 * s, 0.5 * s, 7, TIMBER_PALE)
	b.column(_up(xf, 0.5 * s), 0.44 * s, 0.36 * s, 0.5 * s, 7, TIMBER_PALE, TIMBER)


static func crate(b: LowPoly, xf: Transform3D, s: float = 1.0) -> void:
	b.box(xf, Vector3(0.9, 0.8, 0.9) * s, TIMBER_PALE)


# A signpost: a post and two boards pointing different ways.
static func signpost(b: LowPoly, xf: Transform3D) -> void:
	b.box(xf, Vector3(0.18, 2.6, 0.18), TIMBER)
	b.box(_off(xf, Vector3(0.55, 2.0, 0), 0.0), Vector3(1.3, 0.34, 0.08), TIMBER_PALE)
	b.box(_off(xf, Vector3(-0.2, 1.5, 0.5), PI * 0.5), Vector3(1.2, 0.3, 0.08), TIMBER_PALE)


# A standing stone `w` wide and `h` tall, leaning `lean` radians.
static func standing_stone(b: LowPoly, xf: Transform3D, w: float, h: float, lean: float = 0.0, color: Color = STONE_DARK) -> void:
	b.column(xf * Transform3D(Basis(Vector3.RIGHT, lean), Vector3.ZERO), w * 0.62, w * 0.36, h, 5, color)


# A grave marker, leaning a little.
static func grave(b: LowPoly, xf: Transform3D, lean: float) -> void:
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, lean), Vector3.ZERO), Vector3(0.75, 1.15, 0.2), STONE_DARK.lightened(0.1))
	b.box(_off(xf, Vector3(0, 0, -1.1)), Vector3(0.9, 0.18, 1.9), Color(0.30, 0.25, 0.20))


# A fence of posts and two rails from `a` to `c` (both on the ground).
static func fence(b: LowPoly, a: Vector3, c: Vector3) -> void:
	var along := c - a
	var length := Vector2(along.x, along.z).length()
	if length < 0.5:
		return
	var posts := maxi(2, int(length / 3.0) + 1)
	for i in posts:
		b.box(LowPoly.at(a.lerp(c, float(i) / (posts - 1))), Vector3(0.14, 1.15, 0.14), TIMBER_PALE)
	var yaw := atan2(-along.z, along.x)
	for y in [0.45, 0.9]:
		b.box(LowPoly.at((a + c) * 0.5 + Vector3(0, y, 0), yaw), Vector3(length, 0.09, 0.07), TIMBER_PALE)


# --- Camps ---------------------------------------------------------------

# A hide tent: a cone of stitched skins on crossed poles, its mouth facing -z.
static func tent(b: LowPoly, xf: Transform3D, radius: float, height: float, color: Color = HIDE) -> void:
	b.column(xf, radius, 0.12, height, 7, color)
	# The mouth, and a patch of darker hide.
	b.tri(xf * Vector3(-radius * 0.34, 0.02, -radius * 0.93), xf * Vector3(radius * 0.34, 0.02, -radius * 0.93),
		xf * Vector3(0, height * 0.52, -radius * 0.5), SHADOW)
	b.tri(xf * Vector3(radius * 0.72, 0.3, radius * 0.72), xf * Vector3(radius * 0.2, 0.3, radius * 1.0),
		xf * Vector3(radius * 0.3, height * 0.5, radius * 0.48), HIDE_DARK)
	for k in 3:
		b.column(xf * LowPoly.leaning(Vector3(0, height * 0.82, 0), k * TAU / 3.0 + 0.4, 0.38), 0.05, 0.03, height * 0.36, 3, TIMBER)


# A campfire: a ring of stones and crossed logs in `b`, flames in `glow`.
static func campfire(b: LowPoly, glow: LowPoly, xf: Transform3D, s: float = 1.0) -> void:
	for i in 7:
		var a := i * TAU / 7.0
		b.blob(_off(xf, Vector3(cos(a) * 0.95 * s, 0.12, sin(a) * 0.95 * s)), Vector3(0.26, 0.2, 0.26) * s, 0.25, STONE_DARK)
	for i in 3:
		b.column(xf * LowPoly.leaning(Vector3(0, 0.1, 0), i * TAU / 3.0, 1.15), 0.1 * s, 0.08 * s, 0.95 * s, 4, TIMBER.darkened(0.3))
	glow.cone(_up(xf, 0.1), 0.42 * s, 1.25 * s, 5, FLAME)
	glow.cone(_off(xf, Vector3(0.15 * s, 0.1, 0.1 * s), 0.6), 0.24 * s, 0.85 * s, 4, FLAME_CORE)
	glow.cone(_off(xf, Vector3(-0.2 * s, 0.1, -0.12 * s), 1.4), 0.2 * s, 0.7 * s, 4, FLAME)


# A skull totem: a pole, a horned skull, a crossbar hung with red feathers.
static func totem(b: LowPoly, xf: Transform3D, height: float) -> void:
	b.column(xf, 0.14, 0.09, height, 5, TIMBER)
	b.blob(_up(xf, height + 0.2), Vector3(0.42, 0.46, 0.5), 0.12, BONE)
	for sx in [-1.0, 1.0]:
		b.cone(xf * LowPoly.leaning(Vector3(sx * 0.3, height + 0.35, 0), sx * PI * 0.5, 0.9), 0.1, 0.85, 4, BONE)
		b.sheet(xf * Vector3(sx * 0.75, height - 0.55, 0), xf * Vector3(sx * 0.95, height - 0.55, 0.05),
			xf * Vector3(sx * 0.9, height - 1.3, 0.1), xf * Vector3(sx * 0.72, height - 1.2, 0.0), BANNER_RED)
	b.box(_off(_up(xf, height - 0.6), Vector3.ZERO), Vector3(1.9, 0.1, 0.1), TIMBER)
	b.column(xf * LowPoly.leaning(Vector3(0.2, 0, 0.2), 0.8, 1.2), 0.05, 0.04, 1.2, 3, BONE)


# One sharpened stake of a palisade.
static func stake(b: LowPoly, xf: Transform3D, height: float, lean: float = 0.0) -> void:
	b.column(xf * Transform3D(Basis(Vector3.RIGHT, lean), Vector3.ZERO), 0.2, 0.17, height - 0.6, 5, TIMBER)
	b.cone(xf * Transform3D(Basis(Vector3.RIGHT, lean), Vector3.ZERO) * LowPoly.at(Vector3(0, height - 0.6, 0)), 0.17, 0.6, 5, TIMBER_PALE)


# A lookout: four legs, a railed platform and a small roof.
static func lookout(b: LowPoly, xf: Transform3D, height: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.column(xf * LowPoly.leaning(Vector3(sx * 1.5, 0, sz * 1.5), atan2(-sz, sx), 0.0), 0.14, 0.12, height, 4, TIMBER)
	b.box(_up(xf, height), Vector3(3.6, 0.2, 3.6), TIMBER_PALE)
	for i in 4:
		var side := Transform3D(Basis(Vector3.UP, i * PI * 0.5), Vector3.ZERO)
		b.box(xf * side * LowPoly.at(Vector3(0, height + 0.9, 1.75)), Vector3(3.6, 0.1, 0.1), TIMBER)
	b.column(_off(_up(xf, height + 2.2), Vector3.ZERO, PI * 0.25), 2.9, 0.0, 1.5, 4, ROOF_THATCH)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(_off(xf, Vector3(sx * 1.6, height, sz * 1.6)), Vector3(0.12, 2.3, 0.12), TIMBER)
	# The ladder.
	b.box(xf * LowPoly.leaning(Vector3(0, 0, -1.9), 0.0, 0.16), Vector3(0.7, height + 0.2, 0.08), TIMBER_PALE)


# --- Ruins ---------------------------------------------------------------

# A stone arch across x: two piers `span` apart (inside), `pier_h` to the
# spring of a round arch, `thick` in section and `depth` through.
static func arch(b: LowPoly, xf: Transform3D, span: float, pier_h: float, thick: float, depth: float, color: Color, stones: int = 9) -> void:
	var r := span * 0.5
	for sx in [-1.0, 1.0]:
		b.box(_off(xf, Vector3(sx * (r + thick * 0.5), 0, 0)), Vector3(thick, pier_h, depth), color)
		b.box(_off(xf, Vector3(sx * (r + thick * 0.5), 0, 0)), Vector3(thick * 1.3, pier_h * 0.08, depth * 1.2), color.darkened(0.08))
	var seg := PI * (r + thick * 0.5) / stones * 1.12
	for i in stones:
		var a := PI * (i + 0.5) / stones
		var base := Vector3(cos(a) * r, pier_h + sin(a) * r, 0)
		b.box(xf * Transform3D(Basis(Vector3(0, 0, 1), a - PI * 0.5), base), Vector3(seg, thick, depth), color.darkened(0.03 * (i % 2)))


# A tall thin spire, snapped off at a slant if `broken`.
static func spire(b: LowPoly, xf: Transform3D, radius: float, height: float, color: Color, broken: bool = false) -> void:
	if broken:
		b.column(xf, radius, radius * 0.55, height, 6, color, color.darkened(0.25))
	else:
		b.column(xf, radius, radius * 0.5, height * 0.62, 6, color)
		b.column(_up(xf, height * 0.62), radius * 0.5, 0.0, height * 0.38, 6, color.lightened(0.04))
