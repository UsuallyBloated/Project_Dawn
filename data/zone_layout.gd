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
# Past this (the larger of |x| and |z|) the rim's faces begin: no scenery.
const RIM_START := 1925.0

# --- Roads ---------------------------------------------------------------------

# Each road's points are its corners; road_points() rounds them into a curve.
const ROADS := [
	{"name": "the east road", "width": 7.0, "points": [
		Vector2(90, 0), Vector2(500, -50), Vector2(1000, -190), Vector2(1380, -620),
		Vector2(1880, -900), Vector2(1940, -932)]},
	{"name": "the north road", "width": 6.0, "points": [
		Vector2(0, 90), Vector2(20, 420), Vector2(0, 760), Vector2(0, 1040),
		Vector2(10, 1220), Vector2(0, 1880), Vector2(0, 1940)]},
	{"name": "the barrow track", "width": 4.0, "points": [
		Vector2(-90, 0), Vector2(-600, -20), Vector2(-1100, -60), Vector2(-1340, -60)]},
	{"name": "the mill road", "width": 5.0, "points": [
		Vector2(0, -90), Vector2(20, -420), Vector2(70, -740), Vector2(20, -1420)]},
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
const EAST_ROAD_END := Vector2(1925, -924)
const NORTH_ROAD_END := Vector2(0, 1925)
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
	[WAGON_WRECK, 10.0], [EAST_ROAD_END, 26.0], [NORTH_ROAD_END, 22.0],
]
# Nor inside the town's walls and the fields' fences.
const TOWN_CLEARING := 150.0


# A road's corners rounded into a curve (Chaikin's corner cutting, twice), its
# two ends kept where they are.
static func road_points(road: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array(road["points"])
	for pass_no in 2:
		var next := PackedVector2Array()
		next.append(pts[0])
		for i in pts.size() - 1:
			next.append(pts[i].lerp(pts[i + 1], 0.25))
			next.append(pts[i].lerp(pts[i + 1], 0.75))
		next.append(pts[pts.size() - 1])
		pts = next
	return pts


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
