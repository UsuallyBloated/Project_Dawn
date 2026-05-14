extends CharacterBody3D
class_name RemotePlayer

# Visual stand-in for another player whose state lives on the server. No
# input handling, no physics integration — just a position-interpolation
# buffer fed by Net.world_position broadcasts via RemotePlayerManager,
# plus a cache of the peer's latest resources / cast / buffs (delivered
# the same way) that the HUD reads when the local player targets this peer.
#
# Why interpolation (not snap-or-lerp like the local player)? The local
# player has client-side prediction to lerp from. Remote players don't —
# we have no idea what the future will hold, so we render INTERP_LAG
# seconds in the past and interpolate between the two snapshots that
# straddle the render time. That guarantees a smooth path through every
# server-confirmed position, at the cost of a ~100 ms render delay.

# Mirrors the per-resource signals that enemy.gd emits so hud.gd's existing
# target-tracking can subscribe via the same `hp_changed(current, maximum)`
# pattern without a target-type switch.
signal hp_changed(current: float, maximum: float)
signal mp_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
# Track 4 sub-task 2 cast bar. cast_started fires when a fresh CastStart
# arrives (or a late-joiner seed mid-cast). cast_ended fires on Complete /
# Fail and on the defensive duration-elapsed timeout in _process.
signal cast_started(spell_name: String, duration: float)
signal cast_ended
# Track 4 sub-task 3 — replicated buff snapshot. Fires whenever the peer's
# buff list mutates server-side. Subscribers (HUD target frame) re-render
# from `buff_names` / `buff_durations`.
signal buffs_changed

# Network identity — set by RemotePlayerManager *before* add_child fires
# _ready, so _ready can read them.
var char_id: int = -1
var player_name: String = ""
var race: String = ""
var player_class: String = ""
var level: int = 1

# Replicated resource cache. Starts at "not yet known" — the HUD treats
# zero max as "no data" and the bars stay hidden until a ResourceUpdate
# fan-out fills them in (Track 4 sub-task 1).
var hp: float = 0.0
var max_hp: float = 0.0
var mp: float = 0.0
var max_mp: float = 0.0
var stamina: float = 0.0
var max_stamina: float = 0.0

# Targeting compatibility: HUD / combat code expects `mob_name` on whatever
# the local target points at. RemotePlayer exposes player_name through the
# same field name so the existing target-frame code reads cleanly. Set in
# _ready since both fields are populated by RemotePlayerManager pre-add.
# Track 4 leaves PvP off — `is_dead` stays false; sub-task 5 wires death.
var mob_name: String = ""
var is_dead: bool = false

# Cast state cache. cast_spell_name is "" when not casting; cast_start_time
# is in seconds (Time.get_unix_time_from_system clock). HUD reads these
# directly to render the cast bar and subscribes to cast_started /
# cast_ended for show/hide.
var cast_spell_name: String = ""
var cast_duration: float = 0.0
var cast_start_time: float = 0.0

# Buff snapshot — parallel arrays from the wire. Durations were the
# remaining time at the moment of the broadcast; we don't tick them down
# locally (HUD displays the value as-is). A fresh snapshot on every
# BuffManager.buffs_changed keeps the display close enough to accurate
# without per-frame countdown bookkeeping.
var buff_names: PackedStringArray = PackedStringArray()
var buff_durations: PackedFloat32Array = PackedFloat32Array()

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
	mob_name = player_name
	# Same group enemies use for "the local target can be set to this" —
	# Targeting._click_target / Combat.set_target branch on the group.
	add_to_group("remote_players")

func set_targeted(_active: bool) -> void:
	# Visual hook — enemies tint their material here. Track 4 leaves remote
	# players un-tinted; the existing target-frame UI is feedback enough.
	# Method exists so combat.set_target's `has_method("set_targeted")` call
	# doesn't no-op confusingly when targeting a peer.
	pass

# Track 6 sub-task 3b: stubs so Combat.deal_spell_damage doesn't crash
# when the target is a peer (the spell path calls these on
# current_target). Server is authoritative on spell damage — no resist
# math on the client. flash_spell_hit's color tint is a visual nice-to-
# have that can land later; for now spell hits show via the floating
# damage number from RemotePlayerManager._on_hit.
func get_spell_resist(_damage_type: int) -> float:
	return 0.0

func flash_spell_hit(_color: Color) -> void:
	pass

func apply_health_update(new_hp: float, new_max_hp: float) -> void:
	# Track 4 sub-task 5: if we're currently in the death state and HP
	# just came back above zero, that's the respawn trigger. Stand the
	# body back up. The dying client's _respawn() sets HP first, then
	# the position snaps via the next Position broadcast.
	var was_dead := is_dead
	hp = new_hp
	max_hp = new_max_hp
	if was_dead and new_hp > 0.0:
		_apply_respawn()
	hp_changed.emit(hp, max_hp)

func apply_mana_update(new_mp: float, new_max_mp: float) -> void:
	mp = new_mp
	max_mp = new_max_mp
	mp_changed.emit(mp, max_mp)

func apply_stamina_update(new_stamina: float, new_max_stamina: float) -> void:
	stamina = new_stamina
	max_stamina = new_max_stamina
	stamina_changed.emit(stamina, max_stamina)

func apply_cast_start(spell_name: String, duration: float) -> void:
	cast_spell_name = spell_name
	cast_duration = maxf(duration, 0.0)
	cast_start_time = Time.get_unix_time_from_system()
	cast_started.emit(spell_name, duration)

func apply_cast_complete(_spell_name: String) -> void:
	if cast_spell_name == "":
		return
	cast_spell_name = ""
	cast_duration = 0.0
	cast_ended.emit()

func apply_cast_fail(_reason: String) -> void:
	if cast_spell_name == "":
		return
	cast_spell_name = ""
	cast_duration = 0.0
	cast_ended.emit()

func is_casting() -> bool:
	return cast_spell_name != ""

func cast_progress_ratio() -> float:
	# 0.0 → just started, 1.0 → full duration elapsed. Used by the HUD to
	# fill the cast bar between server messages.
	if cast_duration <= 0.0:
		return 0.0
	var elapsed := Time.get_unix_time_from_system() - cast_start_time
	return clampf(float(elapsed) / cast_duration, 0.0, 1.0)

func apply_buff_snapshot(names: PackedStringArray, durations: PackedFloat32Array) -> void:
	buff_names = names.duplicate()
	buff_durations = durations.duplicate()
	buffs_changed.emit()

# Track 4 sub-task 5: fall-over animation in place. We freeze the snapshot
# interpolation so the corpse doesn't keep walking, tween the body onto
# its side, and grey out the nameplate so it reads as dead at a glance.
# Stand-up is the inverse — kicked off when apply_health_update sees HP
# return above zero (i.e. the dying client's respawn() landed).
func apply_death() -> void:
	if is_dead:
		return
	is_dead = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", PI * 0.5, 0.5)
	if name_label:
		var faded := Color(0.6, 0.6, 0.6, 1.0)
		tw.parallel().tween_property(name_label, "modulate", faded, 0.5)

func _apply_respawn() -> void:
	is_dead = false
	# Drop the snapshot buffer — once the dying client teleports to bind
	# point, the position would lerp from the death spot to the new spot,
	# which looks like a slide-of-doom. Clearing forces the next Position
	# to snap (cold-start branch in _physics_process).
	_snapshots.clear()
	_last_seq = -1
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", 0.0, 0.3)
	if name_label:
		tw.parallel().tween_property(name_label, "modulate", Color.WHITE, 0.3)

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

func _process(_delta: float) -> void:
	# Defensive cast-bar auto-end: if the casting peer crashed before
	# sending CastComplete / CastFail, the cast bar would linger
	# indefinitely without this. 0.5 s grace so a slightly-late server
	# CastComplete doesn't get pre-empted.
	if cast_spell_name == "" or cast_duration <= 0.0:
		return
	var elapsed := Time.get_unix_time_from_system() - cast_start_time
	if elapsed >= cast_duration + 0.5:
		cast_spell_name = ""
		cast_duration = 0.0
		cast_ended.emit()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
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
