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
# by the Move's sequence, and each own Position (which echoes the sequence of
# the last Move the server took) is compared with the prediction for THAT
# sequence. The difference is the real error, whatever the speed. An error
# inside a dead band (about one tick of travel, the server's own jitter: it
# integrates once per tick whatever arrives) is ignored; one past the snap
# band is applied whole; anything between is blended out over the next frames.
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
# How many predictions are kept: a sequence older than this has been answered.
const RING_SIZE := 64

var _predicted: Dictionary = {}
var _pending: Vector3 = Vector3.ZERO
var snaps: int = 0
var corrections: int = 0


# Remember where the body is as Move `seq` goes out.
func record(seq: int, pos: Vector3) -> void:
	_predicted[seq] = pos
	if _predicted.size() > RING_SIZE:
		var oldest: int = seq
		for k in _predicted.keys():
			if k < oldest:
				oldest = k
		_predicted.erase(oldest)


# An own Position arrived echoing `seq`, with the server's position for it, while
# the body flies at `speed` m/s (the boosted speed when boosting). Returns the
# correction to apply to the body at once (a snap, or zero); a blended
# correction is kept and paid out by `step`.
func observe(seq: int, server_pos: Vector3, speed: float) -> Vector3:
	if not _predicted.has(seq):
		return Vector3.ZERO
	var error: Vector3 = server_pos - _predicted[seq]
	for k in _predicted.keys():
		if k <= seq:
			_predicted.erase(k)
	var tick_travel: float = maxf(speed, 1.0) * TICK_SECS
	var dist := error.length()
	if dist <= DEAD_BAND_TICKS * tick_travel:
		_pending = Vector3.ZERO
		return Vector3.ZERO
	if dist > SNAP_BAND_TICKS * tick_travel:
		_pending = Vector3.ZERO
		snaps += 1
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
	return share


func reset() -> void:
	_predicted.clear()
	_pending = Vector3.ZERO
