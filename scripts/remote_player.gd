extends CharacterBody3D
class_name RemotePlayer

# Visual stand-in for another player whose state lives on the server. No
# input handling, no physics integration — just a position-interpolation
# buffer fed by Net.world_position broadcasts via RemotePlayerManager.
#
# Why interpolation (not snap-or-lerp like the local player)? The local
# player has client-side prediction to lerp from. Remote players don't —
# we have no idea what the future will hold, so we render INTERP_LAG
# seconds in the past and interpolate between the two snapshots that
# straddle the render time. That guarantees a smooth path through every
# server-confirmed position, at the cost of a ~100 ms render delay.

# Network identity — set by RemotePlayerManager *before* add_child fires
# _ready, so _ready can read them.
var char_id: int = -1
var player_name: String = ""
var race: String = ""
var player_class: String = ""
var level: int = 1

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

@onready var name_label: Label3D = $NameLabel

func _ready() -> void:
	if name_label:
		name_label.text = player_name

func on_position_update(pos: Vector3, yaw: float, sequence: int) -> void:
	# Position channel is Unreliable; drop reorders and dupes. Sequence is
	# the server's `last_move_seq` per sender — monotone within one
	# session, but resets to 0 if the same char rejoins.
	if sequence <= _last_seq:
		return
	_last_seq = sequence
	var now := Time.get_unix_time_from_system()
	_snapshots.append({"time": now, "pos": pos, "yaw": yaw})
	if _snapshots.size() > BUFFER_CAPACITY:
		_snapshots.pop_front()

func _physics_process(_delta: float) -> void:
	if _snapshots.size() < 2:
		# Cold start: render at the only known position. Two snapshots
		# arrive after at most one server tick (50 ms), so this branch
		# is the visual on entering AOI and nothing more.
		if _snapshots.size() == 1:
			global_position = _snapshots[0]["pos"]
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
