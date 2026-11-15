extends RefCounted
class_name FlyReconciler

# The server-position correction a GM's body uses in flight
# (docs/design/handoff_gm_flight.md, C2). Walking keeps player.gd's lerp-and-snap,
# which compares the body with the newest Position: at a walk the two sit
# within a metre, so it works. In flight the server is always more than a metre
# behind the prediction (one tick alone is 2.5 m at 50 m/s), and that reconciler
# would snap the body back on every Position.
#
# So in flight the body remembers where it was when each Move went out, keyed
# by the Move's sequence (and the speed it flew at), and each own Position
# (which echoes the sequence of the last Move the server took) is compared with
# the prediction for THAT sequence. The difference is the real error, whatever
# the speed. An error inside a dead band (about one tick of travel, the
# server's own jitter: it integrates once per tick whatever arrives) is
# ignored; one past the snap band is applied whole; anything between is
# blended out over the next frames.
#
# Every correction applied to the body is folded into the predictions still
# waiting for their Position: they were recorded before the body moved, so
# without it the next Positions inside one round trip would re-measure the
# same error and re-apply it (a review finding, 2026-11-15: a 5 m error paid
# about twice over at 100 ms, a snap repeated whole on every echo).
# Pure (no nodes, no autoloads) so tools/probe_fly_reconciler.gd can replay a
# server stream through it.

# One server tick, the unit the bands are measured in.
const TICK_SECS := 0.05
# The error that is the server's own tick jitter: ignored.
const DEAD_BAND_TICKS := 1.5
# Past this much travel the body is simply put where the server has it.
const SNAP_BAND_TICKS := 8.0
# How fast a blended correction closes (per second; 95% in about 150 ms).
const BLEND_RATE := 20.0
# The bands' floors for a body holding still (no tick jitter, so a hair of
# dead band; and a stop lands the two sides within a frame or a tick of each
# other, which is blended out rather than snapped).
const STILL_DEAD_BAND := 0.05
const STILL_SNAP_BAND := 3.0
# How many predictions are kept: a sequence older than this has been answered.
const RING_SIZE := 64

# seq -> [predicted position, the speed flown at (m/s, boosted when boosting)]
var _predicted: Dictionary = {}
var _pending: Vector3 = Vector3.ZERO
var snaps: int = 0
var corrections: int = 0


# Remember where the body will be (one server tick along the direction sent,
# as player.gd computes it) as Move `seq` goes out, and the speed it flies at.
func record(seq: int, pos: Vector3, speed: float) -> void:
	_predicted[seq] = [pos, maxf(speed, 0.0)]
	if _predicted.size() > RING_SIZE:
		var oldest: int = seq
		for k in _predicted.keys():
			if k < oldest:
				oldest = k
		_predicted.erase(oldest)


# An own Position arrived echoing `seq`, with the server's position for it.
# Returns the correction to apply to the body at once (a snap, or zero); a
# blended correction is kept and paid out by `step`. Either way the body's
# predictions move with it.
func observe(seq: int, server_pos: Vector3) -> Vector3:
	if not _predicted.has(seq):
		return Vector3.ZERO
	var entry: Array = _predicted[seq]
	var error: Vector3 = server_pos - entry[0]
	var speed: float = entry[1]
	for k in _predicted.keys():
		if k <= seq:
			_predicted.erase(k)
	var tick_travel: float = speed * TICK_SECS
	var dist := error.length()
	if dist <= maxf(DEAD_BAND_TICKS * tick_travel, STILL_DEAD_BAND):
		_pending = Vector3.ZERO
		return Vector3.ZERO
	if dist > maxf(SNAP_BAND_TICKS * tick_travel, STILL_SNAP_BAND):
		_pending = Vector3.ZERO
		snaps += 1
		_shift_predictions(error)
		return error
	corrections += 1
	_pending = error
	return Vector3.ZERO


# The share of a pending correction to apply this frame.
func step(delta: float) -> Vector3:
	if _pending == Vector3.ZERO:
		return Vector3.ZERO
	var share: Vector3 = _pending * (1.0 - exp(-BLEND_RATE * delta))
	_pending -= share
	if _pending.length() < 0.001:
		_pending = Vector3.ZERO
	_shift_predictions(share)
	return share


# The body moved by `by` outside its own flight (a correction): every
# prediction still waiting for its Position moves with it.
func _shift_predictions(by: Vector3) -> void:
	for k in _predicted.keys():
		var entry: Array = _predicted[k]
		entry[0] = entry[0] + by


func reset() -> void:
	_predicted.clear()
	_pending = Vector3.ZERO
