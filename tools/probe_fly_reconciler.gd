extends SceneTree
# Headless probe for the flight reconciler (scripts/fly_reconciler.gd): a
# scripted server stream at 100 m/s with 100 ms of latency and a tick of jitter
# produces no snap and a bounded error that settles after a stop; a real
# divergence past the snap band is applied whole; a sequence never recorded is
# ignored. The walking reconciler (player.gd's lerp-and-snap at 1 m) would snap
# on every one of these Positions. Exits 1 on any miss. Run:
#   godot --headless --path . -s tools/probe_fly_reconciler.gd

const SPEED := 100.0
const DT := 1.0 / 60.0
const TICK := 0.05
const LATENCY := 0.1

var _fails: int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    " + what)
	else:
		print("FAIL  " + what)
		_fails += 1

func _initialize() -> void:
	_run()
	print("")
	print("%d failed" % _fails if _fails > 0 else "all passed")
	quit(1 if _fails > 0 else 0)

func _run() -> void:
	var recon := FlyReconciler.new()
	# The client flies +x at SPEED, sending a Move every tick and recording its
	# body; the server integrates the same speed from each Move's arrival
	# (LATENCY later) and fans a Position echoing that Move's sequence at its
	# next tick, with up to a tick of jitter. The body's track is what the
	# corrections push around.
	var body := Vector3.ZERO
	var t := 0.0
	var seq := 0
	var next_send := 0.0
	var moves_in_flight: Array = []     # [arrive_at, seq, dir_x]
	var positions_in_flight: Array = [] # [deliver_at, seq, server_pos]
	# The server as it is: a 20 Hz tick (its phase unrelated to the client's)
	# that integrates the direction of the newest Move it has, once per tick,
	# and fans a Position echoing that Move's sequence; each way takes LATENCY.
	var server_pos := 0.0
	var server_dir := 0.0
	var server_seq := 0
	var next_tick := 0.013
	var worst_error := 0.0
	var flying := true
	var stop_at := 3.0
	var settled_error := -1.0
	# The track the body would run with no correction at all: what the
	# corrections are measured against (the server runs the same track a
	# latency late, starting and stopping late, so the two agree).
	var truth_x := 0.0
	while t < 5.0:
		if flying and t >= stop_at:
			flying = false
		if flying:
			body.x += SPEED * DT
			truth_x += SPEED * DT
		if t >= next_send:
			next_send += TICK
			seq += 1
			var dir_x := 1.0 if flying else 0.0
			# As player.gd records it: one server tick along the direction sent,
			# since the echoing Position is fanned after the tick that took it.
			recon.record(seq, body + Vector3(dir_x * SPEED * TICK, 0.0, 0.0))
			moves_in_flight.append([t + LATENCY, seq, dir_x])
		while next_tick <= t:
			var taken: Array = []
			for m in moves_in_flight:
				if m[0] <= next_tick:
					taken.append(m)
			for m in taken:
				moves_in_flight.erase(m)
				server_seq = m[1]
				server_dir = m[2]
			server_pos += server_dir * SPEED * TICK
			positions_in_flight.append([next_tick + LATENCY, server_seq, server_pos])
			next_tick += TICK
		var delivered: Array = []
		for p in positions_in_flight:
			if p[0] <= t:
				delivered.append(p)
		for p in delivered:
			positions_in_flight.erase(p)
			body += recon.observe(p[1], Vector3(p[2], 0.0, 0.0), SPEED)
		body += recon.step(DT)
		var err: float = absf(body.x - truth_x)
		if t > 0.5:
			worst_error = maxf(worst_error, err)
		if t > 4.5:
			settled_error = err
		t += DT
	_check(recon.snaps == 0, "no snap through 3 s at 100 m/s with 100 ms of latency (%d)" % recon.snaps)
	_check(worst_error < SPEED * TICK * 3.0,
		"the body never strays more than three ticks of travel from its own track (worst %.2f m)" % worst_error)
	_check(settled_error < 1.0, "after the stop the body settles within a metre (%.2f m)" % settled_error)

	# A real divergence (the server held the body at a plate edge the client
	# flew past) past the snap band is applied whole.
	var r2 := FlyReconciler.new()
	r2.record(10, Vector3(300.0, 20.0, 0.0))
	var snap := r2.observe(10, Vector3(200.0, 20.0, 0.0), 100.0)
	_check(snap.is_equal_approx(Vector3(-100.0, 0.0, 0.0)), "a 100 m divergence is applied whole (%s)" % snap)
	_check(r2.snaps == 1 and r2.step(DT) == Vector3.ZERO, "and nothing is left to blend")

	# A moderate error (between the bands) blends out over the next frames and
	# lands within a hair of the whole correction.
	var r3 := FlyReconciler.new()
	r3.record(1, Vector3(0.0, 50.0, 0.0))
	var at_once := r3.observe(1, Vector3(0.0, 40.0, 0.0), 25.0)
	var total := Vector3.ZERO
	for _i in range(60):
		total += r3.step(DT)
	_check(at_once == Vector3.ZERO and absf(total.y + 10.0) < 0.05,
		"a 10 m error at 25 m/s blends out in under a second (%.2f of -10)" % total.y)

	# A tick of jitter is ignored; a sequence never recorded is ignored.
	var r4 := FlyReconciler.new()
	r4.record(1, Vector3(10.0, 0.0, 0.0))
	_check(r4.observe(1, Vector3(11.0, 0.0, 0.0), 25.0) == Vector3.ZERO and r4.step(DT) == Vector3.ZERO,
		"an error inside the dead band changes nothing")
	_check(r4.observe(99, Vector3(500.0, 0.0, 0.0), 25.0) == Vector3.ZERO,
		"a sequence never recorded changes nothing")
