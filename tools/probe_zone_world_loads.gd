extends SceneTree
# Headless probe for the 4 km zone as the game loads it: scenes/world.tscn
# with its own script, HUD and player, no server. The world must come up, the
# player must stand in the town, and the player's own body must stand on the
# ground the TerrainMesh builds wherever it is put: in a chunk's middle, on the
# seam where four chunks meet, on the Wraith Gate plateau, on the western
# hills' crest and on the Sunken Barrow's floor. A body that falls through a
# seam, or stands on a ground the heights do not make, fails here. Exits 1 on
# any miss. Run:
#   godot --headless --path . -s tools/probe_zone_world_loads.gd

const WORLD_SCENE := "res://scenes/world.tscn"
# How far the body's height may be from the ground's under it.
const STAND_TOLERANCE := 0.08
# Where the body is dropped, and what the place is.
const DROPS := [
	[Vector2(60, 60), "a chunk's middle, in the town"],
	[Vector2(400, 400), "the seam where four chunks meet"],
	[Vector2(-400, 0), "a seam on the west road"],
	[Vector2(1700, 0), "the Wraith Gate plateau"],
	[Vector2(-1740, 90), "the western hills' crest"],
	[Vector2(-1480, -60), "the Sunken Barrow's floor"],
	[Vector2(0, 900), "the pass's floor"],
	[Vector2(20, -1500), "the war camp's shelf"],
]

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


# The autoloads join the tree after _initialize, so the probe runs on the
# first frame.
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _wait_physics(frames: int) -> void:
	for i in frames:
		await physics_frame


func _run() -> void:
	var started := Time.get_ticks_msec()
	var world: Node = (load(WORLD_SCENE) as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	print("The world loaded in %d ms." % (Time.get_ticks_msec() - started))

	var terrain := world.get_node_or_null("TerrainMesh")
	var player := world.get_node_or_null("Players/1") as CharacterBody3D
	_check(terrain != null and terrain.has_method("height_at"), "the world has its ground")
	_check(player != null, "the world spawned the local player")
	for dressing in ["Flora", "Town", "Landmarks"]:
		var node := world.get_node_or_null(dressing)
		_check(node != null and node.get_child_count() > 0, "the %s node is built" % dressing)
	if terrain == null or player == null:
		print("%d failure(s)" % _fails)
		quit(1)
		return

	# In the town first: the ground is at 0 there, so where the body settles
	# is how high its origin rides above its feet.
	await _wait_physics(90)
	var ride := player.global_position.y
	_check(player.is_on_floor(), "the player stands in the town (y = %.3f)" % ride)
	_check(absf(ride) < 1.5, "at the height of the town's ground")

	for drop in DROPS:
		var at: Vector2 = drop[0]
		var ground: float = terrain.height_at(at.x, at.y)
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(at.x, ground + ride + 2.0, at.y)
		await _wait_physics(100)
		var p := player.global_position
		var here: float = terrain.height_at(p.x, p.z)
		_check(player.is_on_floor() and absf(p.y - ride - here) <= STAND_TOLERANCE,
			"the body stands on %s (ground %.2f m, feet %.2f m)" % [drop[1], here, p.y - ride])

	print("%d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
