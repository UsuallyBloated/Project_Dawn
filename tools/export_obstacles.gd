extends SceneTree

# Obstacle exporter (docs/design/obstacle_collision.md): builds
# scenes/world.tscn's ground and scenery headless, bakes every solid into the
# zone's obstacle data (scripts/zone/zone_obstacle_bake.gd), and writes the
# same bytes twice: the client's data/zone_obstacles.bin and the server's
# data/obstacles.bin. The server moves every body, so the two files must be
# one file; tools/check_obstacle_lockstep.gd (in check_all.ps1) fails when
# they are not, or when the scenery has changed since they were written.
#
# Run from the client repo root after any change to the scenery or the ground:
#   godot --headless --path . -s tools/export_obstacles.gd
#   godot --headless --path . -s tools/export_obstacles.gd -- <path to the server's obstacles.bin>
#
# Commit both files, each in its own repo, with the change that moved them.
# On a feature branch pass the server worktree's path: the default is the
# deploy checkout.

const DEFAULT_SERVER_OUTPUT := "F:/Projects/server/crates/projectdawn-server/data/obstacles.bin"
const WORLD_SCENE := "res://scenes/world.tscn"
# Nodes of the world scene that are not scenery and need a running game.
const SKIP_NODES := ["HUD", "Hotbar", "LevelUpPopup", "Players"]


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var server_path := DEFAULT_SERVER_OUTPUT
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		server_path = args[0]

	var world := build_world(root)
	if world == null:
		printerr("Cannot load %s." % WORLD_SCENE)
		quit(2)
		return
	await process_frame
	var started := Time.get_ticks_msec()
	var baked := ZoneObstacleBake.bake(world)
	if baked.has("error"):
		printerr("Cannot bake the obstacles: %s" % baked["error"])
		quit(2)
		return
	var bytes: PackedByteArray = baked["bytes"]
	# Read the file back as the game will, so a file the loader refuses is
	# never written.
	var problem: Array = []
	var loaded := ZoneObstacles.from_bytes(bytes, problem)
	if loaded == null:
		printerr("The baked data does not load: %s" % ", ".join(problem))
		quit(2)
		return
	for path in [ProjectSettings.globalize_path(ZoneObstacles.FILE_PATH), server_path]:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			printerr("Cannot open %s for writing (error %d)." % [path, FileAccess.get_open_error()])
			quit(2)
			return
		f.store_buffer(bytes)
		f.close()
		print("Wrote %s" % path)
	print("%d prisms (%d stand in a body's way, %d block sight), %d bytes, hash %s, baked in %d ms" % [
		baked["count"], baked["walk"], baked["sight"], bytes.size(), loaded.hash_hex(), Time.get_ticks_msec() - started])
	var sources: Dictionary = baked["sources"]
	var names := sources.keys()
	names.sort()
	for source in names:
		print("  %-12s %d" % [source, sources[source]])
	quit(0)


# The world scene with its scenery built and nothing that needs a running
# game, added under `parent`; null when the scene cannot be loaded. Static so
# the lockstep check builds the same thing.
static func build_world(parent: Node) -> Node:
	var packed := load(WORLD_SCENE) as PackedScene
	if packed == null:
		return null
	var world := packed.instantiate()
	world.set_script(null)
	for skip in SKIP_NODES:
		var node := world.get_node_or_null(skip)
		if node != null:
			world.remove_child(node)
			node.free()
	parent.add_child(world)
	return world
