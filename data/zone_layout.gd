@tool
class_name ZoneLayout
extends RefCounted

# Where things are in the starting zone, apart from the heights
# (data/terrain_features.toml): the roads, the farms, the woods, the stony and
# bony ground, and the sites the set pieces stand on. One home for the map,
# read by three things: tools/author_terrain.gd paints the ground texture from
# it, scripts/zone/zone_flora.gd scatters trees and stones from it, and
# scripts/zone/zone_town.gd and zone_landmarks.gd build the town and the camps'
# dressing on it. Coordinates are Vector2(x east, z north) in metres, from the
# composition sketches (docs/design/starting_area_comp_sketches.html).
#
# All of it is scenery: nothing here collides or reaches the server. The
# server's camps are in its zone_camps.toml; the author's report warns when a
# SITES entry has drifted away from the camp it dresses.

const ZONE_SIZE := 4000.0
# The town wall's line: a square this far from the origin on each side.
const TOWN_HALF := 90.0

# --- The edge ------------------------------------------------------------------

# The walkable world: two basins the mountains close round, joined only by the
# pass through the Greywood ridge. Each basin's points are the corners of its
# edge, rounded by basin_outline(); its first and last points are the two sides
# of the pass's mouth, so each closes along the ridge's foot. Everything outside
# both (and off the ridge itself) is mountain: tools/author_terrain.gd raises
# it, and no scenery is scattered there. Scenery reads inside().
const BASINS := [
	{"name": "the town's basin", "points": [
		Vector2(30, 790), Vector2(1180, 790), Vector2(1290, 790), Vector2(1430, 740), Vector2(1580, 575),
		# The Wraith Gate plateau, its east side under the mountains.
		Vector2(1850, 400), Vector2(1890, 0), Vector2(1865, -420), Vector2(1740, -580),
		# The east arm, the road's door at its end.
		Vector2(1810, -700), Vector2(1900, -830), Vector2(1900, -975),
		Vector2(1660, -1010), Vector2(1420, -900), Vector2(1220, -940),
		# The mountains between the east arm and the war camp's vale.
		Vector2(900, -960), Vector2(600, -1080), Vector2(530, -1300), Vector2(570, -1600), Vector2(410, -1800),
		# The war camp's vale, the south door at its foot.
		Vector2(80, -1870), Vector2(-300, -1800), Vector2(-420, -1560), Vector2(-360, -1250), Vector2(-520, -1020),
		Vector2(-800, -830), Vector2(-1120, -740), Vector2(-1500, -770), Vector2(-1780, -610),
		# The barrow hills, running up into the range.
		Vector2(-1900, -280), Vector2(-1900, 260), Vector2(-1770, 580),
		Vector2(-1500, 740), Vector2(-1290, 790), Vector2(-1180, 790), Vector2(-30, 790)]},
	{"name": "the Greywood", "points": [
		Vector2(-30, 1010), Vector2(-1180, 1010), Vector2(-1290, 1010),
		Vector2(-1330, 1200), Vector2(-1180, 1400), Vector2(-900, 1500), Vector2(-600, 1520),
		Vector2(-330, 1520), Vector2(-170, 1600),
		# The north arm, the road's door at its end.
		Vector2(-140, 1890), Vector2(140, 1890),
		Vector2(165, 1600), Vector2(330, 1500), Vector2(700, 1470), Vector2(1000, 1450),
		Vector2(1220, 1330), Vector2(1330, 1180),
		Vector2(1290, 1010), Vector2(1180, 1010), Vector2(30, 1010)]},
]
# Where the roads leave the zone, each against the mountains at the end of an
# arm (ten metres in from the edge, where the face begins): ways to zones that
# do not exist yet, shut for now.
const NORTH_DOOR := Vector2(0, 1880)
const EAST_DOOR := Vector2(1890, -902)
const SOUTH_DOOR := Vector2(98, -1838)
# Where the barrow track stops: a shoulder of the western hills with the
# Sunken Barrow's pit below it and the Ossuary on the crest above.
const OVERLOOK := Vector2(-1370, 250)

# --- Roads ---------------------------------------------------------------------

# Each road's points are its corners; road_points() rounds them into a curve.
# A road passes its camps at a distance (where a traveller sees them from it)
# and never runs into one; the author's report measures each against the camps.
const ROADS := [
	{"name": "the east road", "width": 7.0, "points": [
		# Past the raiders' wagon wreck, south of the Spider Copse, then along
		# under the Wraith Gate cliff and round the plateau's ramp to the door.
		Vector2(90, 0), Vector2(280, 10), Vector2(470, -30), Vector2(680, -150), Vector2(900, -290),
		Vector2(1120, -300), Vector2(1300, -400), Vector2(1390, -640), Vector2(1620, -760), EAST_DOOR]},
	{"name": "the north road", "width": 6.0, "points": [
		# East of Bat Hollow, straight through the pass (it is 60 m wide), then
		# east round the Broken Crypt's bowl and up the arm to the door.
		Vector2(0, 90), Vector2(70, 250), Vector2(100, 430), Vector2(50, 610), Vector2(0, 730), Vector2(0, 770),
		Vector2(0, 1030), Vector2(40, 1046), Vector2(150, 1070), Vector2(265, 1160), Vector2(305, 1260),
		Vector2(245, 1420), Vector2(100, 1540), Vector2(0, 1660), NORTH_DOOR]},
	{"name": "the barrow track", "width": 4.0, "points": [
		# Out by the farm lane, north of the bone fields, up the hills to the overlook.
		Vector2(-90, 0), Vector2(-170, -38), Vector2(-260, -50), Vector2(-450, -34), Vector2(-640, 60), Vector2(-800, 200),
		Vector2(-960, 290), Vector2(-1130, 330), Vector2(-1270, 300), OVERLOOK]},
	{"name": "the south road", "width": 5.0, "points": [
		# By the mill, west of Rotfang's rocks, then round the foot of the war
		# camp's shelf (the gnolls look down on it) to the door.
		Vector2(0, -90), Vector2(-30, -250), Vector2(40, -400), Vector2(-70, -560), Vector2(-170, -740),
		Vector2(-170, -880), Vector2(-40, -1050), Vector2(150, -1180), Vector2(310, -1320), Vector2(370, -1500),
		Vector2(310, -1650), Vector2(190, -1740), Vector2(115, -1800), SOUTH_DOOR]},
]

# --- Ground colours (the paint texture) -------------------------------------------

const COLOR_ROAD := Color(0.56, 0.47, 0.34)
const COLOR_TOWN_GROUND := Color(0.55, 0.49, 0.39)
const COLOR_COBBLE := Color(0.52, 0.50, 0.47)
const COLOR_FIELD_GOLD := Color(0.66, 0.57, 0.28)
const COLOR_FIELD_GREEN := Color(0.40, 0.49, 0.20)
const COLOR_FURROW := Color(0.38, 0.29, 0.19)
const COLOR_FOREST_FLOOR := Color(0.10, 0.17, 0.09)
const COLOR_DRY_GRASS := Color(0.50, 0.48, 0.28)
const COLOR_BONE_DUST := Color(0.60, 0.56, 0.46)
const COLOR_CAMP_DIRT := Color(0.44, 0.37, 0.27)
const COLOR_SICK_GROUND := Color(0.34, 0.39, 0.20)
const COLOR_BARROW_EARTH := Color(0.27, 0.25, 0.21)
const COLOR_PLATEAU_STONE := Color(0.45, 0.43, 0.41)
# The mountains outside the edge: bare rock from the foot up.
const COLOR_MOUNTAIN_ROCK := Color(0.40, 0.39, 0.37)

# The farm strips west of the walls: Rect2(x, z, width, depth), furrows along x.
const FIELDS := [
	{"rect": Rect2(-400, 6, 90, 60), "color": COLOR_FIELD_GOLD},
	{"rect": Rect2(-330, -120, 90, 60), "color": COLOR_FIELD_GREEN},
	{"rect": Rect2(-260, 12, 90, 60), "color": COLOR_FIELD_GREEN},
	{"rect": Rect2(-420, -190, 90, 60), "color": COLOR_FIELD_GOLD},
	{"rect": Rect2(-300, -210, 90, 60), "color": COLOR_FIELD_GOLD},
]

# Broad patches of coloured ground. "rect" (Rect2) or "center" + "radius";
# "feather" is how far the edge fades over, "strength" the patch's opacity,
# "mottle" how much noise breaks it up (0 none, 1 a lot).
const GROUND_PATCHES := [
	{"name": "the Greywood", "rect": Rect2(-1960, 950, 3920, 1010), "color": COLOR_FOREST_FLOOR,
		"feather": 60.0, "strength": 0.96, "mottle": 0.25},
	{"name": "the wood's edge", "rect": Rect2(-1300, 640, 2600, 150), "color": COLOR_FOREST_FLOOR,
		"feather": 70.0, "strength": 0.45, "mottle": 0.8},
	{"name": "the Spider Copse", "center": Vector2(1150, 40), "radius": 230.0, "color": COLOR_FOREST_FLOOR,
		"feather": 80.0, "strength": 0.85, "mottle": 0.4},
	{"name": "the Boar Thicket", "center": Vector2(-420, -340), "radius": 170.0, "color": COLOR_FOREST_FLOOR,
		"feather": 90.0, "strength": 0.5, "mottle": 0.7},
	{"name": "the Gnoll Flats", "rect": Rect2(360, -280, 680, 640), "color": COLOR_DRY_GRASS,
		"feather": 140.0, "strength": 0.8, "mottle": 0.5},
	{"name": "the southern steppe", "rect": Rect2(-700, -1900, 1500, 900), "color": COLOR_DRY_GRASS,
		"feather": 200.0, "strength": 0.6, "mottle": 0.6},
	{"name": "the bone fields", "rect": Rect2(-1220, -250, 380, 440), "color": COLOR_BONE_DUST,
		"feather": 90.0, "strength": 0.75, "mottle": 0.6},
	{"name": "the barrow's pit", "center": Vector2(-1480, -60), "radius": 210.0, "color": COLOR_BARROW_EARTH,
		"feather": 70.0, "strength": 0.85, "mottle": 0.3},
	{"name": "the festering mound", "center": Vector2(640, -620), "radius": 120.0, "color": COLOR_SICK_GROUND,
		"feather": 60.0, "strength": 0.85, "mottle": 0.4},
	{"name": "the plateau", "rect": Rect2(1450, -450, 480, 800), "color": COLOR_PLATEAU_STONE,
		"feather": 30.0, "strength": 0.7, "mottle": 0.5},
	{"name": "the town", "center": Vector2(0, 0), "radius": 132.0, "color": COLOR_TOWN_GROUND,
		"feather": 30.0, "strength": 0.9, "mottle": 0.2},
	{"name": "the square", "center": Vector2(3, 0), "radius": 24.0, "color": COLOR_COBBLE,
		"feather": 5.0, "strength": 0.9, "mottle": 0.5},
]

# --- Sites -------------------------------------------------------------------------

# Where each set piece stands. The camps' names are the first words of the
# server camps' `desc` lines in zone_camps.toml; the author's report measures
# each against its camp's spawns.
const SITES := {
	"Bonepile": Vector2(-220, 120),
	"Wolf Run": Vector2(280, -200),
	"Rat Warrens": Vector2(150, 120),
	"Shallow Graves": Vector2(400, 330),
	"Gnoll Raider Camp": Vector2(560, 70),
	"Boar Thicket": Vector2(-420, -340),
	"Bat Hollow": Vector2(-130, 540),
	"Sable's roost": Vector2(-180, 640),
	"Bandit Outpost": Vector2(-600, 640),
	"Rotfang's Den": Vector2(60, -800),
	"Festering Mound": Vector2(640, -620),
	"Spider Copse": Vector2(1120, 60),
	"The Crawler's burrow": Vector2(1210, -10),
	"The Broken Crypt": Vector2(20, 1250),
	"Gnoll War Camp": Vector2(20, -1500),
	"Greth's tent": Vector2(40, -1620),
	"The Sunken Barrow": Vector2(-1480, -60),
	"The Undying": Vector2(-1560, -60),
	"Ossuary": Vector2(-1740, 90),
	"Wraith Gate": Vector2(1570, -40),
}

# The worn ground under a camp: [radius, colour]. Wildlife camps have none.
const SITE_GROUND := {
	"Bonepile": [34.0, COLOR_BONE_DUST],
	"Rat Warrens": [30.0, COLOR_CAMP_DIRT],
	"Shallow Graves": [44.0, COLOR_BARROW_EARTH],
	"Gnoll Raider Camp": [40.0, COLOR_CAMP_DIRT],
	"Bandit Outpost": [40.0, COLOR_CAMP_DIRT],
	"Rotfang's Den": [26.0, COLOR_CAMP_DIRT],
	"The Broken Crypt": [70.0, COLOR_PLATEAU_STONE],
	"Gnoll War Camp": [80.0, COLOR_CAMP_DIRT],
	"Greth's tent": [34.0, COLOR_CAMP_DIRT],
	"Ossuary": [70.0, COLOR_BONE_DUST],
	"Wraith Gate": [60.0, COLOR_BARROW_EARTH],
}

# Set pieces that are no camp.
const MILL := Vector2(60, -420)
# The arch stands at the cliff's lip (the cliff is the plateau's west edge, x = 1450),
# so it is seen from the flats below, as the composition sketch has it.
const WRAITH_GATE_ARCH := Vector2(1506, -40)
const BARROW_MOUTH := Vector2(-1612, -60)
const OSSUARY_RUIN := Vector2(-1765, 105)
const BROKEN_CRYPT := Vector2(20, 1262)
const WAGON_WRECK := Vector2(470, -30)
# The pass through the ridge: its floor's half width and where it runs.
const PASS_X := 0.0
const PASS_HALF_WIDTH := 30.0
const PASS_SOUTH_Z := 790.0
const PASS_NORTH_Z := 1010.0

# --- Flora --------------------------------------------------------------------------

# Scatter regions. "rect" or "center" + "radius"; "per_hectare" is the number
# of things per 10,000 square metres; "kinds" weights what grows (the names are
# zone_flora.gd's). A region's "clumping" (0 to 1) thins it by noise, so a wood
# has glades and a plain has stands.
const SCATTER := [
	{"name": "the Greywood", "rect": Rect2(-1920, 965, 3840, 955), "per_hectare": 105.0, "clumping": 0.3,
		"kinds": {"pine": 6.0, "tall_pine": 2.5, "dead_tree": 0.3, "bush": 0.6, "boulder": 0.2}},
	{"name": "the wood's edge", "rect": Rect2(-1300, 640, 2600, 140), "per_hectare": 10.0, "clumping": 0.7,
		"kinds": {"pine": 3.0, "broadleaf": 2.0, "bush": 2.0}},
	{"name": "the Spider Copse", "center": Vector2(1150, 40), "radius": 215.0, "per_hectare": 48.0, "clumping": 0.2,
		"kinds": {"dark_tree": 6.0, "dead_tree": 1.0, "bush": 1.0}},
	{"name": "the Boar Thicket", "center": Vector2(-420, -340), "radius": 155.0, "per_hectare": 70.0, "clumping": 0.5,
		"kinds": {"bush": 7.0, "broadleaf": 1.6, "boulder": 0.3}},
	{"name": "the Gnoll Flats", "rect": Rect2(380, -260, 640, 600), "per_hectare": 13.0, "clumping": 0.6,
		"kinds": {"boulder": 5.0, "scrub": 5.0, "dead_tree": 0.25}},
	{"name": "the bone fields", "rect": Rect2(-1200, -230, 340, 400), "per_hectare": 20.0, "clumping": 0.4,
		"kinds": {"bones": 6.0, "dead_tree": 1.2, "boulder": 0.8}},
	{"name": "the western hills", "center": Vector2(-1550, 0), "radius": 660.0, "per_hectare": 5.0, "clumping": 0.7,
		"kinds": {"boulder": 4.0, "pine": 1.0, "scrub": 2.0, "dead_tree": 0.5}},
	{"name": "the plateau", "rect": Rect2(1470, -430, 440, 760), "per_hectare": 5.0, "clumping": 0.5,
		"kinds": {"boulder": 4.0, "dead_tree": 1.0}},
	{"name": "the southern steppe", "rect": Rect2(-700, -1900, 1500, 900), "per_hectare": 5.0, "clumping": 0.7,
		"kinds": {"scrub": 5.0, "boulder": 2.0, "broadleaf": 0.4}},
	{"name": "the plain", "rect": Rect2(-1920, -1920, 3840, 2880), "per_hectare": 2.4, "clumping": 0.75,
		"kinds": {"broadleaf": 3.0, "bush": 4.0, "boulder": 1.2, "pine": 0.4}},
]

# Nothing is scattered this close to a site's middle (the mobs want to be seen)
# or to a road's edge. A site with a set piece wider than that names its own
# clearing in SITE_CLEARINGS; EXTRA_CLEARINGS are the set pieces that are no camp.
const SITE_CLEARING := 26.0
const ROAD_MARGIN := 3.0
const SITE_CLEARINGS := {
	"The Broken Crypt": 60.0,
	"Gnoll War Camp": 78.0,
	"Greth's tent": 30.0,
	"Gnoll Raider Camp": 40.0,
	"Bandit Outpost": 44.0,
	"Ossuary": 60.0,
	"Wraith Gate": 46.0,
	"Shallow Graves": 46.0,
	"The Sunken Barrow": 60.0,
	"Spider Copse": 12.0,
	"The Crawler's burrow": 14.0,
	"Boar Thicket": 8.0,
}
const EXTRA_CLEARINGS := [
	[MILL, 22.0], [WRAITH_GATE_ARCH, 40.0], [BARROW_MOUTH, 30.0], [OSSUARY_RUIN, 50.0],
	[WAGON_WRECK, 10.0], [EAST_DOOR, 26.0], [NORTH_DOOR, 22.0], [SOUTH_DOOR, 22.0], [OVERLOOK, 16.0],
]
# Nor inside the town's walls and the fields' fences.
const TOWN_CLEARING := 150.0

# How many times a basin's corners are cut into a curve.
const BASIN_ROUNDING := 3

static var _outlines: Array[PackedVector2Array] = []


# A basin's edge as a closed polygon: its corners rounded (Chaikin's corner
# cutting, its two ends kept, so the side along the ridge's foot stays straight).
static func basin_outline(basin: Dictionary) -> PackedVector2Array:
	return _cut_corners(PackedVector2Array(basin["points"]), BASIN_ROUNDING)


# Every basin's edge, rounded once and kept.
static func basin_outlines() -> Array[PackedVector2Array]:
	if _outlines.is_empty():
		for basin in BASINS:
			_outlines.append(basin_outline(basin))
	return _outlines


# Whether a point is on the walkable side of the edge: in a basin, or in the
# pass between them. (The ridge's crest is neither; nothing stands there.)
static func inside(p: Vector2) -> bool:
	if absf(p.x - PASS_X) <= PASS_HALF_WIDTH and p.y >= PASS_SOUTH_Z and p.y <= PASS_NORTH_Z:
		return true
	for outline in basin_outlines():
		if Geometry2D.is_point_in_polygon(p, outline):
			return true
	return false


# Whether a point and everything within `margin` of it is inside (tested at the
# point and eight points round it, which is enough for scenery).
static func well_inside(p: Vector2, margin: float) -> bool:
	if not inside(p):
		return false
	for i in 8:
		if not inside(p + Vector2.from_angle(i * TAU / 8.0) * margin):
			return false
	return true


static func _cut_corners(pts: PackedVector2Array, passes: int) -> PackedVector2Array:
	for pass_no in passes:
		var next := PackedVector2Array()
		next.append(pts[0])
		for i in pts.size() - 1:
			next.append(pts[i].lerp(pts[i + 1], 0.25))
			next.append(pts[i].lerp(pts[i + 1], 0.75))
		next.append(pts[pts.size() - 1])
		pts = next
	return pts


# A road's corners rounded into a curve (Chaikin's corner cutting, twice), its
# two ends kept where they are.
static func road_points(road: Dictionary) -> PackedVector2Array:
	return _cut_corners(PackedVector2Array(road["points"]), 2)


# The distance from a point to the nearest road's centre line, less that road's
# half width: negative on a road.
static func road_clearance(p: Vector2, curves: Array) -> float:
	var best := INF
	for c in curves:
		var pts: PackedVector2Array = c["points"]
		var half: float = c["half_width"]
		for i in pts.size() - 1:
			var a := pts[i]
			var ab := pts[i + 1] - a
			var len2 := ab.length_squared()
			var t := 0.0 if len2 == 0.0 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t) - half)
	return best


# Every road as {points, half_width}, rounded once: what road_clearance wants.
static func road_curves() -> Array:
	var out: Array = []
	for road in ROADS:
		out.append({"points": road_points(road), "half_width": float(road["width"]) * 0.5})
	return out
