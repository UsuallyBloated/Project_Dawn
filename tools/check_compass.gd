extends SceneTree

# Compass check: the world must be the map, not its mirror image. The zone is
# authored on a map (data/zone_layout.gd, data/terrain_features.toml, the comp
# sketches): north up, east right. Godot is right-handed, so a world that put
# north at +Z would stand east on the LEFT of anyone facing north; that was
# the zone until 2026-11-14 ("the compass is mirrored", the To-Do entry).
#
# What it holds, from the built world and the server's files:
#   NORTH   the Greywood ridge (found in the scene's ground, not in the map)
#           is where /sense says North.
#   EAST    from the town, facing the ridge, the server's Gnoll Raider Camp is
#           on the right, and /sense says East facing it.
#   MAP     data/zone_layout.gd's map reaches the world the same way round:
#           its north is towards the ridge, its east on the right, a map
#           facing turns to the same direction on the ground, and the raiders'
#           set piece stands at the server's camp.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_compass.gd
#   godot --headless --path . -s tools/check_compass.gd -- <server data dir>
#
# Exit code 1 on any FAIL, 2 when a file cannot be read, 0 otherwise.

const DEFAULT_SERVER_DATA := "F:/Projects/server/crates/projectdawn-server/data"
const WORLD_SCENE := "res://scenes/world.tscn"
const Exporter := preload("res://tools/export_terrain.gd")
const Author := preload("res://tools/author_terrain.gd")
# The ridge is looked for along this line of x, between these distances from the
# town on either side (it runs the zone's width about 900 m from the town).
const RIDGE_SEARCH_X := [-900.0, -500.0, 500.0, 900.0]
const RIDGE_SEARCH_FROM := 600.0
const RIDGE_SEARCH_TO := 1150.0
const RIDGE_MIN_HEIGHT := 45.0
const RAIDER_CAMP := "Gnoll Raider Camp"

var _fails := 0
var _data_dir := DEFAULT_SERVER_DATA


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		_data_dir = a
	# The autoloads join the tree after _initialize; /sense is one of them.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var terrain := Exporter.read_scene(WORLD_SCENE)
	if terrain.has("error"):
		printerr("Cannot read the terrain from %s: %s" % [WORLD_SCENE, terrain["error"]])
		quit(2)
		return
	var camps := Author.parse_camps(_data_dir.path_join("zone_camps.toml"))
	var raiders := Vector2.ZERO
	var raider_spawns := 0
	for c in camps:
		if c["name"] == RAIDER_CAMP:
			raiders += c["pos"]
			raider_spawns += 1
	if raider_spawns == 0:
		printerr("No %s in %s (pass the server's data dir after --)." % [RAIDER_CAMP, _data_dir])
		quit(2)
		return
	raiders /= raider_spawns
	var sense := root.get_node_or_null("SenseHeading")
	if sense == null:
		printerr("The SenseHeading autoload is not in the tree.")
		quit(2)
		return
	sense.set("_skill", SenseHeadingDefinitions.get_cap(int(sense.get("_level"))))

	# NORTH: which side of the town the ridge stands on, read from the ground.
	var side := _ridge_side(terrain)
	if side == 0:
		_check(false, "NORTH the Greywood ridge was not found in the scene's ground")
		print("%d failure(s)" % _fails)
		quit(1)
		return
	var to_ridge := Vector3(0, 0, side)
	_check(_sense_facing(sense, to_ridge) == "North", "NORTH /sense says North facing the ridge (it says %s)" % _sense_facing(sense, to_ridge))

	# EAST: the raiders' camp is on the right of a body facing the ridge.
	var to_camp := Vector3(raiders.x, 0, raiders.y).normalized()
	var right := to_ridge.cross(Vector3.UP)
	_check(to_camp.dot(right) > 0.5, "EAST the %s (%.0f, %.0f) is on the right facing the ridge" % [RAIDER_CAMP, raiders.x, raiders.y])
	_check(_sense_facing(sense, to_camp) == "East", "EAST /sense says East facing the %s (it says %s)" % [RAIDER_CAMP, _sense_facing(sense, to_camp)])

	# MAP: the authoring frame reaches the world the same way round.
	var north := ZoneLayout.to_world(Vector2(0, 1))
	var east := ZoneLayout.to_world(Vector2(1, 0))
	_check(north.dot(to_ridge) > 0.999, "MAP the map's north is towards the ridge")
	_check(east.dot(right) > 0.999, "MAP the map's east is on the right facing north")
	var p := Vector2(123.5, -456.25)
	_check(ZoneLayout.to_map(ZoneLayout.to_world(p, 7.0)).is_equal_approx(p) and ZoneLayout.to_map_xz(ZoneLayout.to_world_xz(p)).is_equal_approx(p), "MAP a map point comes back from the world unchanged")
	var turned := 0
	for i in 16:
		var d := Vector2.from_angle(i * TAU / 16.0 + 0.1)
		var world_yaw := ZoneLayout.yaw_to_world(atan2(-d.x, -d.y))
		var faces := Vector3(-sin(world_yaw), 0, -cos(world_yaw))
		if faces.dot(ZoneLayout.to_world(d).normalized()) > 0.9999:
			turned += 1
	_check(turned == 16, "MAP a thing turned to a map direction faces that direction in the world (%d of 16)" % turned)
	var site := ZoneLayout.to_world_xz(ZoneLayout.SITES[RAIDER_CAMP])
	_check(site.distance_to(raiders) <= Author.SITE_DRIFT_M, "MAP the %s's dressing stands at its camp (%.0f m off)" % [RAIDER_CAMP, site.distance_to(raiders)])

	print("%d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)


# +1 when the ridge is at +Z of the town, -1 at -Z, 0 when neither side has it:
# the side whose highest ground along the search lines is the ridge's height.
func _ridge_side(terrain: Dictionary) -> int:
	# For each side, the lowest of the search lines' highest points: the ridge
	# is high on every line, a lone hill on one.
	var best := {1: INF, -1: INF}
	for s in [1, -1]:
		for x in RIDGE_SEARCH_X:
			var d := RIDGE_SEARCH_FROM
			var peak := 0.0
			while d <= RIDGE_SEARCH_TO:
				peak = maxf(peak, Exporter.ground_at(terrain, x, s * d))
				d += 10.0
			best[s] = minf(best[s], peak)
	var north_high: bool = best[1] >= RIDGE_MIN_HEIGHT
	var south_high: bool = best[-1] >= RIDGE_MIN_HEIGHT
	if north_high == south_high:
		return 0
	return 1 if north_high else -1


# What /sense prints, as a direction word, for a body facing `dir` (world).
# A body turned rotation.y faces (-sin y, 0, -cos y).
func _sense_facing(sense: Node, dir: Vector3) -> String:
	var line: String = sense.call("query", atan2(-dir.x, -dir.z))
	return line.trim_prefix("You are facing ").trim_suffix(".")
