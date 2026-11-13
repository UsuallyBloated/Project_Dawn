extends SceneTree

# Zone camera: renders scenes/world.tscn's scenery from a list of viewpoints
# and saves one PNG each, so the zone can be looked at (and compared with the
# composition sketches) without logging in. It opens a window, since the
# headless renderer draws nothing. The world's own script, HUD and players are
# left out: only the sky, the sun, the ground, the NPCs and the dressing load.
#
# Run from the client repo root (no --headless):
#   godot --path . -s tools/shoot_zone.gd -- <output dir> [hour] [shot name ...]
#   godot --path . -s tools/shoot_zone.gd -- <output dir> 12 "0,400,600:0,0,1200"
#
# hour is the time of day (0 to 24, default 17: late afternoon, the comps'
# light). With no shot names every viewpoint in SHOTS is taken. A shot is
# [name, eye, look-at]; eye heights are metres above the ground there.

const WORLD_SCENE := "res://scenes/world.tscn"
const SIZE := Vector2i(1600, 900)
const SKIP_NODES := ["HUD", "Hotbar", "LevelUpPopup", "Players"]
# Frames to let the sky, the shadows and the noise texture settle per shot.
const SETTLE_FRAMES := 12

const SHOTS := [
	# The four composition sketches.
	["a_town_from_east_road", Vector3(330, 2.0, -34), Vector3(60, 14, 0)],
	["b_the_pass", Vector3(8, 2.0, 640), Vector3(0, 30, 900)],
	["c_sunken_barrow", Vector3(-1290, 3.0, -40), Vector3(-1560, -30, -60)],
	["d_wraith_gate", Vector3(1210, 2.0, -60), Vector3(1640, 70, -40)],
	# The town.
	["town_square", Vector3(-26, 1.8, -14), Vector3(30, 6, 24)],
	["town_from_above", Vector3(-150, 110, -170), Vector3(0, 0, 0)],
	["town_west_farms", Vector3(-470, 3.0, -60), Vector3(-90, 8, 0)],
	# Camps and set pieces.
	["gnoll_raider_camp", Vector3(500, 3.0, 20), Vector3(565, 3, 72)],
	["east_road_and_flats", Vector3(420, 14.0, -90), Vector3(900, 0, -120)],
	["bonepile", Vector3(-180, 2.0, 90), Vector3(-222, 1, 128)],
	["bandit_outpost", Vector3(-520, 2.0, 560), Vector3(-600, 8, 640)],
	["bat_hollow", Vector3(-60, 3.0, 470), Vector3(-140, -2, 560)],
	["spider_copse", Vector3(1010, 2.0, 0), Vector3(1140, 8, 50)],
	["broken_crypt", Vector3(10, 4.0, 1130), Vector3(20, 2, 1262)],
	["greywood_road", Vector3(4, 1.8, 1070), Vector3(8, 6, 1400)],
	["gnoll_war_camp", Vector3(-70, 4.0, -1400), Vector3(30, 2, -1540)],
	["ossuary", Vector3(-1640, 3.0, 20), Vector3(-1765, 14, 105)],
	["wraith_gate_top", Vector3(1560, 2.0, -130), Vector3(1640, 14, -40)],
	["mill", Vector3(-10, 2.0, -350), Vector3(60, 8, -420)],
	["rotfang_den", Vector3(10, 2.0, -720), Vector3(52, 0, -820)],
	["festering_mound", Vector3(570, 2.0, -560), Vector3(640, 2, -620)],
	# The whole plate.
	["overview_from_south", Vector3(0, 900, -2600), Vector3(0, 0, 100)],
	["overview_top", Vector3(0, 3600, -1), Vector3(0, 0, 0)],
	["west_from_town_wall", Vector3(-100, 14, 0), Vector3(-1500, 60, 0)],
	["north_from_town_wall", Vector3(0, 14, 100), Vector3(0, 40, 900)],
]


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --path . -s tools/shoot_zone.gd -- <output dir> [hour] [shot name ...]")
		quit(2)
		return
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var hour := 17.0
	var wanted: Array[String] = []
	var shots: Array = SHOTS.duplicate()
	for i in range(1, args.size()):
		if args[i].is_valid_float():
			hour = float(args[i])
		elif args[i].contains(":"):
			# A viewpoint of the caller's own: "x,y,z:x,y,z" (eye, then look-at).
			var ends: PackedStringArray = args[i].split(":")
			var e: PackedFloat64Array = ends[0].split_floats(",")
			var t: PackedFloat64Array = ends[1].split_floats(",")
			var custom_name := "custom_%d" % i
			shots.append([custom_name, Vector3(e[0], e[1], e[2]), Vector3(t[0], t[1], t[2])])
			wanted.append(custom_name)
		else:
			wanted.append(args[i])

	root.size = SIZE
	DisplayServer.window_set_size(SIZE)
	var packed := load(WORLD_SCENE) as PackedScene
	var world := packed.instantiate()
	world.set_script(null)
	for skip in SKIP_NODES:
		var node := world.get_node_or_null(skip)
		if node != null:
			world.remove_child(node)
			node.free()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.far = 9000.0
	camera.fov = 62.0
	root.add_child(camera)
	camera.make_current()
	await process_frame

	# The sky and the sun follow the game's own clock.
	var clock := root.get_node_or_null("TimeOfDay")
	if clock != null:
		clock.paused = true
		clock.time_of_day = hour / 24.0
		clock._find_world_nodes()
		clock._apply()

	var terrain := world.get_node_or_null("TerrainMesh")
	var taken := 0
	for shot in shots:
		var shot_name: String = shot[0]
		if not wanted.is_empty() and not wanted.has(shot_name):
			continue
		var eye: Vector3 = shot[1]
		var target: Vector3 = shot[2]
		if terrain != null:
			eye.y += terrain.height_at(eye.x, eye.z)
			target.y += terrain.height_at(target.x, target.z)
		camera.global_position = eye
		camera.look_at(target, Vector3.UP if absf((target - eye).normalized().y) < 0.99 else Vector3.BACK)
		for i in SETTLE_FRAMES:
			await process_frame
		var image := root.get_texture().get_image()
		var path := out_dir.path_join(shot_name + ".png")
		image.save_png(path)
		print("shot %s" % path)
		taken += 1
	print("%d shot(s)." % taken)
	quit(0 if taken > 0 else 1)
