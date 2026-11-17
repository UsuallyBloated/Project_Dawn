extends SceneTree

# Obstacle lockstep check: the zone's obstacle data is one file held three
# times, and all three must be the same bytes.
#
#   SCENERY  what the scenery bakes to now (scripts/zone/zone_obstacle_bake.gd)
#            is the client's data/zone_obstacles.bin: nobody moved a wall or
#            the ground without exporting.
#   SERVER   the client's file is the server's data/obstacles.bin: the body
#            the client draws stops where the server stops it.
#   SAME     a second bake gives the same bytes: every machine exports the
#            same file.
#   LOADS    the file loads as the game loads it.
#   EXPORT   export_presets.cfg ships the file (it is no Godot resource, so
#            an export leaves it out unless the include filter names it).
#
# The server moves every player, so a client holding different obstacles
# shows a body stopping at things the server walks it through, and the next
# correction pulls it through them (invariant L2).
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_obstacle_lockstep.gd
#   godot --headless --path . -s tools/check_obstacle_lockstep.gd -- <path to the server's obstacles.bin>
#
# Fix a FAIL with tools/export_obstacles.gd and commit both files.
# Exit code 1 on any FAIL, 2 when a file or the scene cannot be read, 0 otherwise.

const Exporter := preload("res://tools/export_obstacles.gd")
const EXPORT_PRESETS := "res://export_presets.cfg"

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var server_path: String = Exporter.DEFAULT_SERVER_OUTPUT
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		server_path = args[0]

	var held := FileAccess.get_file_as_bytes(ZoneObstacles.FILE_PATH)
	if held.is_empty():
		printerr("Cannot read %s: run tools/export_obstacles.gd." % ZoneObstacles.FILE_PATH)
		quit(2)
		return
	var served := FileAccess.get_file_as_bytes(server_path)
	if served.is_empty():
		printerr("Cannot read the server's file at %s." % server_path)
		quit(2)
		return
	var world := Exporter.build_world(root)
	if world == null:
		printerr("Cannot load %s." % Exporter.WORLD_SCENE)
		quit(2)
		return
	await process_frame

	var first := ZoneObstacleBake.bake(world)
	if first.has("error"):
		printerr("Cannot bake the obstacles: %s" % first["error"])
		quit(2)
		return
	var baked: PackedByteArray = first["bytes"]
	_check(baked == held, "SCENERY the scenery bakes to the client's file (%d prisms, %d bytes)%s" % [
		first["count"], baked.size(), "" if baked == held else ": the scenery or the ground changed since the last export"])
	_check(held == served, "SERVER the client's file is the server's (%s)%s" % [
		server_path, "" if held == served else ": the two repos hold different exports"])
	var second: PackedByteArray = ZoneObstacleBake.bake(world)["bytes"]
	_check(second == baked, "SAME a second bake gives the same bytes")

	var problem: Array = []
	var loaded := ZoneObstacles.load_file(ZoneObstacles.FILE_PATH, problem)
	_check(loaded != null, "LOADS the file loads%s" % ("" if loaded != null else ": " + ", ".join(problem)))
	if loaded != null:
		print("      %d prisms, hash %s (the server's boot line prints the same twelve digits)" % [loaded.size(), loaded.hash_hex()])

	var presets := FileAccess.get_file_as_string(EXPORT_PRESETS)
	var file_name := ZoneObstacles.FILE_PATH.get_file()
	var shipped := 0
	var preset_count := 0
	for line in presets.split("\n"):
		if line.begins_with("include_filter="):
			preset_count += 1
			if line.contains(file_name) or line.contains("*.bin"):
				shipped += 1
	_check(preset_count > 0 and shipped == preset_count, "EXPORT every export preset's include filter ships %s (%d of %d)" % [file_name, shipped, preset_count])

	print("%d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
