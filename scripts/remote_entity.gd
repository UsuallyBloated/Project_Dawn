extends CharacterBody3D
class_name RemoteEntity

# RemoteEntity: what every server-driven body the client draws has in common
# (RemotePlayer, RemoteEnemy, RemotePet): the snapshot interpolation that renders
# it INTERP_LAG behind the server's Position stream, the buff countdown between
# BuffSnapshots, the death flag, and the two signals the HUD and Combat subscribe
# to on any target. Lifted out of the three scripts on 2026-11-18 (R3); each keeps
# its own identity, resources and rules, and overrides `_process` with a
# `super(delta)` when it has work of its own per frame.
#
# Why interpolation (not snap-or-lerp like the local player)? The local
# player has client-side prediction to lerp from. Remote bodies don't —
# we have no idea what the future will hold, so we render INTERP_LAG
# seconds in the past and interpolate between the two snapshots that
# straddle the render time. That guarantees a smooth path through every
# server-confirmed position, at the cost of a ~100 ms render delay.

# Every target exposes `hp_changed(current, maximum)` and `died(self)`, so
# hud.gd's target tracking and Combat's auto-attack disengage subscribe
# without a target-type switch. `died` is emitted from each type's
# `apply_death` when the server's EntityDied lands on it.
signal hp_changed(current: float, maximum: float)
signal died(entity)
# Replicated buff snapshot. Fires whenever the server's snapshot lands and
# whenever the local tick moves a duration. Subscribers (HUD target frame)
# re-render from `buff_names` / `buff_durations`.
signal buffs_changed

var is_dead: bool = false

# Buff snapshot — parallel arrays from the wire. Durations were the
# remaining time at the moment of the broadcast; we tick them down
# locally between snapshots so the target HUD shows a live countdown.
# Server fans a fresh snapshot when the set changes (apply / expire /
# strip / dispel), which re-anchors these values.
var buff_names: PackedStringArray = PackedStringArray()
var buff_durations: PackedFloat32Array = PackedFloat32Array()
# Infinite-duration sentinel from the server (Lich Form, Absorb pool).
# We skip these in the local tick so they don't drift away from
# "permanent" semantics.
const _BUFF_INF_SENTINEL := 999999.0

# Interpolation buffer of { time: float, pos: Vector3, yaw: float } dicts
# ordered by `time`. Kept short — only the two snapshots straddling
# (now - INTERP_LAG) actually matter; the rest is in-flight headroom.
const BUFFER_CAPACITY := 5
# Render INTERP_LAG seconds behind the latest snapshot so we always have
# two snapshots to lerp between. 100 ms = 2 server ticks at 20 Hz; per
# Track 3 handoff open question 2 (user-confirmed).
const INTERP_LAG := 0.1
var _snapshots: Array[Dictionary] = []
var _last_seq: int = -1

func on_position_update(pos: Vector3, yaw: float, sequence: int) -> void:
	# Position channel is Unreliable; drop reorders and dupes. Sequence is
	# the server's `last_move_seq` per sender — monotone within one
	# session, but resets to 0 if the same char rejoins.
	if sequence <= _last_seq:
		return
	_last_seq = sequence
	# Track 4 sub-task 5: while dead, freeze the corpse at the death
	# location. The dying client's respawn fires apply_health_update
	# (hp > 0) → _apply_respawn() clears the buffer, so the next
	# Position after that arrives in cold-start mode and snaps.
	if is_dead:
		return
	var now := Time.get_unix_time_from_system()
	_snapshots.append({"time": now, "pos": pos, "yaw": yaw})
	if _snapshots.size() > BUFFER_CAPACITY:
		_snapshots.pop_front()

func _process(delta: float) -> void:
	# Tick buff durations down so the target HUD shows a live countdown
	# between server snapshots (server only fans BuffSnapshot when the
	# set changes — apply / expire / strip — so otherwise values would
	# freeze at the last snapshotted remaining). Floor at 0; the next
	# snapshot will drop the entry. Skip infinite-duration sentinels.
	if buff_durations.is_empty():
		return
	var any_changed := false
	for i in buff_durations.size():
		var d: float = buff_durations[i]
		if d > 0.0 and d < _BUFF_INF_SENTINEL:
			buff_durations[i] = maxf(0.0, d - delta)
			any_changed = true
	if any_changed:
		buffs_changed.emit()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	if _snapshots.size() < 2:
		# Cold start: render at the only known position and facing. Two
		# snapshots arrive after at most one server tick (50 ms), so this
		# branch is the visual on entering AOI and nothing more.
		if _snapshots.size() == 1:
			global_position = _snapshots[0]["pos"]
			rotation.y = _snapshots[0]["yaw"]
		return

	var target_time := Time.get_unix_time_from_system() - INTERP_LAG
	# Default to the most recent snapshot pair; replace if an earlier pair
	# actually straddles target_time. Walking the buffer linearly is fine
	# at BUFFER_CAPACITY = 5.
	var a: Dictionary = _snapshots[_snapshots.size() - 2]
	var b: Dictionary = _snapshots[_snapshots.size() - 1]
	for i in range(_snapshots.size() - 1):
		if _snapshots[i]["time"] <= target_time and _snapshots[i + 1]["time"] >= target_time:
			a = _snapshots[i]
			b = _snapshots[i + 1]
			break

	var span: float = b["time"] - a["time"]
	if span <= 0.0:
		# Snapshots have identical timestamps — degenerate but harmless;
		# snap to the newer one.
		global_position = b["pos"]
		rotation.y = b["yaw"]
		return

	var t: float = clampf((target_time - a["time"]) / span, 0.0, 1.0)
	global_position = (a["pos"] as Vector3).lerp(b["pos"], t)
	rotation.y = lerp_angle(a["yaw"], b["yaw"], t)
