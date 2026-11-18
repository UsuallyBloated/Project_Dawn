extends SceneTree

# Obstacle rule check: replays the server's own answers through the client's
# copy of the rule. The server moves every body past the zone's trees, rocks
# and walls with `world/obstacles.rs`; the client predicts the same step with
# scripts/zone/zone_obstacles.gd so the body it draws stops where the server
# stops it. Two copies of one rule in two languages drift unless something
# holds them: the server's tests write `data/obstacle_rule_fixtures.txt` (a
# small scenery of its own, and what the rule answered for 600 steps, 150
# placements and 400 sight lines over it), and this check builds the same
# scenery here, asks the GDScript rule the same questions, and fails on any
# answer that differs.
#
# Run from the client repo root:
#   godot --headless --path . -s tools/check_obstacle_rule.gd
#   godot --headless --path . -s tools/check_obstacle_rule.gd -- <path to obstacle_rule_fixtures.txt>
#
# Exit code 1 on any difference, 2 when the fixtures cannot be read, 0 otherwise.

const DEFAULT_FIXTURES := "F:/Projects/server/crates/projectdawn-server/data/obstacle_rule_fixtures.txt"
# How far a position may differ, metres. The two sides do the same sums, one
# in 32-bit floats throughout and one partly in doubles; the fixtures keep
# only cases whose answer does not hang on that.
const TOLERANCE := 0.0005
# How many of each kind the file must hold, so an emptied file cannot pass.
const MIN_CASES := {"step": 500, "clear": 100, "sight": 300}


func _initialize() -> void:
	var path := DEFAULT_FIXTURES
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		path = args[0]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("Cannot read %s (error %d)." % [path, FileAccess.get_open_error()])
		quit(2)
		return
	var lines := f.get_as_text().replace("\r\n", "\n").split("\n", false)
	f.close()

	var floats := PackedFloat32Array()
	var prisms := 0
	var cases: Array = []
	for line in lines:
		if line.begins_with("#"):
			continue
		var t := line.split(" ", false)
		if t[0] == "prism":
			var corners := PackedVector2Array()
			for k in int(t[5]):
				corners.append(Vector2(float(t[6 + 2 * k]), float(t[7 + 2 * k])))
			floats.append_array(ZoneObstacles.encode_prism(int(t[1]), float(t[2]), float(t[3]), float(t[4]), corners))
			prisms += 1
		else:
			cases.append(t)
	var problem: Array = []
	var obstacles := ZoneObstacles.from_bytes(ZoneObstacles.encode_file(prisms, floats), problem)
	if obstacles == null:
		printerr("The fixtures' scenery does not load: %s" % ", ".join(problem))
		quit(2)
		return

	var counts := {"step": 0, "clear": 0, "sight": 0}
	var wrong := 0
	for t in cases:
		var kind: String = t[0]
		counts[kind] = int(counts.get(kind, 0)) + 1
		var said := ""
		match kind:
			"step":
				var got := obstacles.resolve(Vector2(float(t[1]), float(t[2])), Vector2(float(t[3]), float(t[4])), float(t[5]))
				var want := Vector2(float(t[7]), float(t[8]))
				if got.distance_to(want) > TOLERANCE or obstacles.last_deflected != (t[9] == "1"):
					said = "ends at (%f, %f) deflected=%s" % [got.x, got.y, obstacles.last_deflected]
			"clear":
				var got := obstacles.clear_of(Vector2(float(t[1]), float(t[2])), float(t[3]))
				if got.distance_to(Vector2(float(t[5]), float(t[6]))) > TOLERANCE:
					said = "is put at (%f, %f)" % [got.x, got.y]
			"sight":
				var blocked := obstacles.sight_blocked(Vector3(float(t[1]), float(t[2]), float(t[3])), Vector3(float(t[4]), float(t[5]), float(t[6])))
				if blocked != (t[8] == "1"):
					said = "blocked=%s" % blocked
			_:
				said = "is a kind of case this check does not know"
		if said != "":
			wrong += 1
			if wrong <= 12:
				print("DIFFERS  %s  (the client's rule: %s)" % [" ".join(t), said])

	var fails := wrong
	for kind in MIN_CASES:
		if int(counts[kind]) < int(MIN_CASES[kind]):
			print("FAIL  the fixtures hold %d %s cases (at least %d expected)" % [counts[kind], kind, MIN_CASES[kind]])
			fails += 1
	print("%d prisms; %d steps, %d placements, %d sight lines replayed; %d differ" % [
		prisms, counts["step"], counts["clear"], counts["sight"], wrong])
	quit(1 if fails > 0 else 0)
