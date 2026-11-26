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
	# Whole frames, so the stop falls on a frame and `t` carries no float drift.
	for frame in range(300):
		t = frame * DT
		flying = t < stop_at - DT * 0.5
		if flying:
			body.x += SPEED * DT
			truth_x += SPEED * DT
		if t >= next_send:
			next_send += TICK
			seq += 1
			var dir_x := 1.0 if flying else 0.0
			# As player.gd records it: one server tick along the direction sent,
			# since the echoing Position is fanned after the tick that took it.
			recon.record(seq, body + Vector3(dir_x * SPEED * TICK, 0.0, 0.0), dir_x * SPEED)
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
			body += recon.observe(p[1], Vector3(p[2], 0.0, 0.0))
		body += recon.step(DT)
		var err: float = absf(body.x - truth_x)
		if t > 0.5:
			worst_error = maxf(worst_error, err)
		if t > 4.5:
			settled_error = err
	_check(recon.snaps == 0, "no snap through 3 s at 100 m/s with 100 ms of latency (%d)" % recon.snaps)
	_check(worst_error < SPEED * TICK * 3.0,
		"the body never strays more than three ticks of travel from its own track (worst %.2f m)" % worst_error)
	_check(settled_error < 1.0, "after the stop the body settles within a metre (%.2f m)" % settled_error)

	# The server holds the body (a plate edge the client flew past): the same
	# stream, with the server's x capped at the edge. The body must come to
	# rest at the edge, not oscillate (the review's finding: with the
	# predictions still in flight unmoved, every Position inside one round
	# trip re-measured the same error and re-applied it).
	var r_edge := FlyReconciler.new()
	var edge_body := Vector3.ZERO
	var edge_x := 150.0
	var e_t := 0.0
	var e_seq := 0
	var e_next_send := 0.0
	var e_moves: Array = []
	var e_positions: Array = []
	var e_server := 0.0
	var e_dir := 0.0
	var e_seq_taken := 0
	var e_next_tick := 0.013
	var e_worst_past := 0.0
	var e_settled := -1.0
	for frame in range(360):
		e_t = frame * DT
		if frame < 240:
			edge_body.x += SPEED * DT
		if e_t >= e_next_send:
			e_next_send += TICK
			e_seq += 1
			var d := 1.0 if frame < 240 else 0.0
			r_edge.record(e_seq, edge_body + Vector3(d * SPEED * TICK, 0.0, 0.0), d * SPEED)
			e_moves.append([e_t + LATENCY, e_seq, d])
		while e_next_tick <= e_t:
			var taken: Array = []
			for m in e_moves:
				if m[0] <= e_next_tick:
					taken.append(m)
			for m in taken:
				e_moves.erase(m)
				e_seq_taken = m[1]
				e_dir = m[2]
			e_server = minf(e_server + e_dir * SPEED * TICK, edge_x)
			e_positions.append([e_next_tick + LATENCY, e_seq_taken, e_server])
			e_next_tick += TICK
		var delivered: Array = []
		for p in e_positions:
			if p[0] <= e_t:
				delivered.append(p)
		for p in delivered:
			e_positions.erase(p)
			edge_body += r_edge.observe(p[1], Vector3(p[2], 0.0, 0.0))
		edge_body += r_edge.step(DT)
		if e_t > 2.0:
			e_worst_past = maxf(e_worst_past, edge_body.x - edge_x)
		if e_t > 5.5:
			e_settled = absf(edge_body.x - edge_x)
	# While the key is held into the edge the body is pulled back as fast as it
	# flies on: a round trip of travel before the first correction, the dead
	# band, and the blend's equilibrium (it closes 63% a tick against 5 m a
	# tick of flying). In the game the client clamps to the same plate, so this
	# only happens where the two grounds disagree.
	_check(e_worst_past < SPEED * (LATENCY + 4.0 * TICK),
		"held at an edge, the body overshoots by at most a round trip plus the bands (%.1f m)" % e_worst_past)
	_check(e_settled < 0.1, "and comes to rest at the edge once the key is released (%.3f m off)" % e_settled)
	_check(r_edge.snaps <= 1, "with at most one snap (%d)" % r_edge.snaps)

	# A real divergence past the snap band is applied whole, and the
	# predictions still waiting move with it, so the next echo measures none.
	var r2 := FlyReconciler.new()
	r2.record(10, Vector3(300.0, 20.0, 0.0), 100.0)
	r2.record(11, Vector3(305.0, 20.0, 0.0), 100.0)
	var snap := r2.observe(10, Vector3(200.0, 20.0, 0.0))
	_check(snap.is_equal_approx(Vector3(-100.0, 0.0, 0.0)), "a 100 m divergence is applied whole (%s)" % snap)
	_check(r2.snaps == 1 and r2.step(DT) == Vector3.ZERO, "and nothing is left to blend")
	_check(r2.observe(11, Vector3(205.0, 20.0, 0.0)) == Vector3.ZERO and r2.snaps == 1,
		"the next echo, measured against the shifted prediction, snaps nothing")

	# A moderate error (between the bands) blends out over the next frames and
	# lands within a hair of the whole correction.
	var r3 := FlyReconciler.new()
	r3.record(1, Vector3(0.0, 50.0, 0.0), 25.0)
	var at_once := r3.observe(1, Vector3(0.0, 40.0, 0.0))
	var total := Vector3.ZERO
	for _i in range(60):
		total += r3.step(DT)
	_check(at_once == Vector3.ZERO and absf(total.y + 10.0) < 0.05,
		"a 10 m error at 25 m/s blends out in under a second (%.2f of -10)" % total.y)

	# A tick of jitter is ignored; a sequence never recorded is ignored.
	var r4 := FlyReconciler.new()
	r4.record(1, Vector3(10.0, 0.0, 0.0), 25.0)
	_check(r4.observe(1, Vector3(11.0, 0.0, 0.0)) == Vector3.ZERO and r4.step(DT) == Vector3.ZERO,
		"an error inside the dead band changes nothing")
	_check(r4.observe(99, Vector3(500.0, 0.0, 0.0)) == Vector3.ZERO,
		"a sequence never recorded changes nothing")

	_glide()


# The eased flight (scripts/fly_glide.gd) through the same server model, in
# three dimensions, the client drawing at 144 frames a second: a takeoff, a
# turn, a boost, a climbing diagonal and a stop. The direction each Move
# carries is where the ease takes the body over the next tick, so the server
# runs the body's own track a tick late and the reconciler has next to nothing
# to do. A Move that carried the velocity at the moment it went out instead
# (the obvious way) leaves the server behind through every ramp; that run is
# measured too, as the yardstick.
# Fails with FlyGlide.plan replaced by the velocity of the moment (the
# comparison), and with flight back to an instant start (the first frame).
func _glide() -> void:
	# The ease itself: a gentle first frame, near full speed by a quarter of a
	# second, and a stop that glides speed / STOP_RATE.
	var first: Array = FlyGlide.advance(Vector3.ZERO, Vector3(SPEED, 0.0, 0.0), 1.0 / 144.0)
	_check(first[1].x < SPEED * 0.1, "the first frame of a takeoff is under a tenth of full speed (%.1f m/s)" % first[1].x)
	var quarter: Array = FlyGlide.advance(Vector3.ZERO, Vector3(SPEED, 0.0, 0.0), 0.25)
	_check(quarter[1].x >= SPEED * 0.94, "full speed is all but reached in a quarter second (%.1f m/s)" % quarter[1].x)
	var halt: Array = FlyGlide.advance(Vector3(SPEED, 0.0, 0.0), Vector3.ZERO, 5.0)
	_check(halt[1] == Vector3.ZERO and absf(halt[0].x - SPEED / FlyGlide.STOP_RATE) < 0.01,
		"a stop comes to rest after gliding speed / STOP_RATE (%.2f m)" % halt[0].x)
	# Frame by frame is the same as one step (the closed form composes).
	var v := Vector3.ZERO
	var walked := Vector3.ZERO
	for _i in range(36):
		var a: Array = FlyGlide.advance(v, Vector3(0.0, SPEED, SPEED), 1.0 / 144.0)
		walked += a[0]
		v = a[1]
	var whole: Array = FlyGlide.advance(Vector3.ZERO, Vector3(0.0, SPEED, SPEED), 36.0 / 144.0)
	_check(walked.distance_to(whole[0]) < 0.001, "36 frames fly exactly what one quarter second does (%.4f m apart)" % walked.distance_to(whole[0]))

	var planned := _glide_run(true)
	var naive := _glide_run(false)
	_check(planned["longest"] <= FLY_BOOST_LEN + 0.0001,
		"no Move's direction is longer than the boost (%.3f)" % planned["longest"])
	_check(planned["snaps"] == 0, "the eased flight never snaps (%d)" % planned["snaps"])
	_check(planned["worst"] < SPEED * TICK * 0.5,
		"the body never strays half a tick of travel from its own track (worst %.2f m)" % planned["worst"])
	_check(planned["settled"] < 0.1, "and settles on the server's spot after the stop (%.3f m off)" % planned["settled"])
	# The error each Position shows against its prediction before any
	# correction: what is left is the server's own tick jitter (a Move taken
	# for two ticks and the next for none), which a ramp makes uneven.
	_check(planned["raw_worst"] < SPEED * TICK,
		"no Position is a tick of travel off its prediction (worst %.2f m)" % planned["raw_worst"])
	_check(planned["raw_mean"] < naive["raw_mean"] * 0.6,
		"about half the error of sending the velocity of the moment (mean %.2f m against %.2f m)" % [planned["raw_mean"], naive["raw_mean"]])


const FLY_BOOST_LEN := 2.0
const FRAME := 1.0 / 144.0

# The keys held at time t: [direction (unit or zero), boost].
func _keys_at(t: float) -> Array:
	if t < 0.8:
		return [Vector3(1.0, 0.0, 0.0), 1.0]
	if t < 1.6:
		return [Vector3(0.0, 0.0, 1.0), 1.0]
	if t < 2.4:
		return [Vector3(0.0, 0.0, 1.0), FLY_BOOST_LEN]
	if t < 3.2:
		return [Vector3(1.0, 1.0, 0.0).normalized(), 1.0]
	return [Vector3.ZERO, 1.0]

func _glide_run(planned: bool) -> Dictionary:
	var recon := FlyReconciler.new()
	var body := Vector3(0.0, 50.0, 0.0)
	var truth := body
	var vel := Vector3.ZERO
	var accum := 0.0
	var seq := 0
	var moves: Array = []      # [arrive_at, seq, dir]
	var positions: Array = []  # [deliver_at, seq, pos]
	var server_pos := body
	var server_dir := Vector3.ZERO
	var server_seq := 0
	var next_tick := 0.013
	var worst := 0.0
	var settled := -1.0
	var longest := 0.0
	var pred_truth := {}  # seq -> where the uncorrected track predicts the server
	var raw_sum := 0.0
	var raw_n := 0
	var raw_worst := 0.0
	for frame in range(int(5.0 / FRAME)):
		var t := frame * FRAME
		var keys := _keys_at(t)
		var target: Vector3 = keys[0] * SPEED * keys[1]
		var flown: Array = FlyGlide.advance(vel, target, FRAME)
		vel = flown[1]
		body += flown[0]
		truth += flown[0]
		accum += FRAME
		if accum >= TICK:
			accum -= TICK
			seq += 1
			var d: Vector3
			if planned:
				d = FlyGlide.plan(vel, target, SPEED, TICK, FLY_BOOST_LEN)
			else:
				d = (vel / SPEED).limit_length(FLY_BOOST_LEN)
			longest = maxf(longest, d.length())
			recon.record(seq, body + d * SPEED * TICK, maxf(vel.length(), target.length()))
			pred_truth[seq] = truth + d * SPEED * TICK
			moves.append([t + LATENCY, seq, d])
		while next_tick <= t:
			var taken: Array = []
			for m in moves:
				if m[0] <= next_tick:
					taken.append(m)
			for m in taken:
				moves.erase(m)
				server_seq = m[1]
				server_dir = m[2]
			server_pos += server_dir * SPEED * TICK
			positions.append([next_tick + LATENCY, server_seq, server_pos])
			next_tick += TICK
		var delivered: Array = []
		for q in positions:
			if q[0] <= t:
				delivered.append(q)
		for q in delivered:
			positions.erase(q)
			if pred_truth.has(q[1]):
				var raw: float = q[2].distance_to(pred_truth[q[1]])
				pred_truth.erase(q[1])
				raw_sum += raw
				raw_n += 1
				raw_worst = maxf(raw_worst, raw)
			body += recon.observe(q[1], q[2])
		body += recon.step(FRAME)
		var err := body.distance_to(truth)
		worst = maxf(worst, err)
		if t > 4.5:
			settled = body.distance_to(server_pos)
	return {"worst": worst, "settled": settled, "snaps": recon.snaps, "longest": longest,
		"raw_mean": raw_sum / maxf(raw_n, 1), "raw_worst": raw_worst}
