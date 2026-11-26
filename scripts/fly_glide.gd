extends RefCounted
class_name FlyGlide

# The ease a GM's body flies with (docs/design/handoff_gm_flight.md): its
# velocity closes on the one the keys ask for exponentially, so a takeoff, a
# stop, a turn or a boost takes a fraction of a second instead of a frame.
#
# The server stays exact without knowing any of this. It flies each Move's
# direction for one tick at the flier's speed (a direction shorter than 1 flies
# proportionally slower), so as each Move goes out the client works out where
# its own ease will carry it over the next tick (`plan`) and sends that as the
# direction. The ease composes exactly frame by frame (`advance` is the closed
# form, not a step), so while the keys hold still the body and the server run
# the same track a tick apart; a key changed mid-tick costs what it always has,
# a fraction of a tick, inside the reconciler's dead band. The direction sent is
# a weighted mean of the velocities flown, never longer than the boosted speed,
# so it is always a Move the server takes as it is.
# Pure (no nodes) so tools/probe_fly_reconciler.gd can replay it.

# How fast the velocity closes on a moving target, per second (95% in 0.25 s).
const ACCEL_RATE := 12.0
# How fast it closes on rest when no key is held (95% in 0.2 s).
const STOP_RATE := 15.0
# Within this of the target (m/s) the velocity is the target.
const SETTLE := 0.01


static func rate_for(target: Vector3) -> float:
	return STOP_RATE if target == Vector3.ZERO else ACCEL_RATE


# Fly `dt` seconds from velocity `vel` toward `target`: [displacement, the
# velocity at the end]. Exact for any dt: v(t) = target + (vel - target)e^(-rt).
static func advance(vel: Vector3, target: Vector3, dt: float) -> Array:
	var rate := rate_for(target)
	var decay := exp(-rate * dt)
	var gap := vel - target
	var disp := target * dt + gap * ((1.0 - decay) / rate)
	var end := target + gap * decay
	if (end - target).length() < SETTLE:
		end = target
	return [disp, end]


# The direction to send so the server's tick flies where the body will over the
# next `tick` seconds: the displacement over `speed * tick`.
static func plan(vel: Vector3, target: Vector3, speed: float, tick: float, max_len: float) -> Vector3:
	if speed <= 0.0:
		return Vector3.ZERO
	var disp: Vector3 = advance(vel, target, tick)[0]
	return (disp / (speed * tick)).limit_length(max_len)
