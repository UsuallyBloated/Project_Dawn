extends "res://scripts/remote_entity.gd"
class_name RemotePlayer

# Visual stand-in for another player whose state lives on the server. No
# input handling, no physics integration — RemoteEntity's position-interpolation
# buffer fed by Net.world_position broadcasts via RemotePlayerManager,
# plus a cache of the peer's latest resources / cast / buffs (delivered
# the same way) that the HUD reads when the local player targets this peer.

signal mp_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
# Track 4 sub-task 2 cast bar. cast_started fires when a fresh CastStart
# arrives (or a late-joiner seed mid-cast). cast_ended fires on Complete /
# Fail and on the defensive duration-elapsed timeout in _process.
signal cast_started(spell_name: String, duration: float)
signal cast_ended

# Track 22.H — fires when the server's EntityTarget broadcast for
# this peer lands. ToT HUD subscribes so it can resolve what tracked
# remote players are attacking. Mirror of RemoteEnemy.target_changed.
signal target_changed(target_id: int)

# Network identity — set by RemotePlayerManager *before* add_child fires
# _ready, so _ready can read them.
var char_id: int = -1
var player_name: String = ""
var race: String = ""
var player_class: String = ""
var level: int = 1

# Track 22.H — server-fanned current target id (0 = no target).
var target_id: int = 0

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
var mob_name: String = ""

# Cast state cache. cast_spell_name is "" when not casting; cast_start_time
# is in seconds (Time.get_unix_time_from_system clock). HUD reads these
# directly to render the cast bar and subscribes to cast_started /
# cast_ended for show/hide.
var cast_spell_name: String = ""
var cast_duration: float = 0.0
var cast_start_time: float = 0.0

# The hop a relayed jump plays on this body: the local player's own jump
# arc (player.gd's JUMP_VELOCITY and GRAVITY, kept in step by hand), drawn
# as an offset on the visual and the nameplate, never on the body's
# position, which stays the server's interpolated ground track. 0.7 s in
# the air, 1.2 m at the apex.
const JUMP_VELOCITY := 7.0
const GRAVITY := -20.0
const JUMP_AIRTIME := -2.0 * JUMP_VELOCITY / GRAVITY
var _jump_t := -1.0
var _visual_base_y := 0.0
var _label_base_y := 0.0

@onready var name_label: Label3D = $NameLabel

func _ready() -> void:
	if name_label:
		name_label.text = player_name
	mob_name = player_name
	# Show this peer with their race model so a gnome reads as a gnome to
	# everyone, not just to themselves. race is set pre-add by the manager.
	RaceModel.apply($Visual, race)
	_visual_base_y = $Visual.position.y
	if name_label:
		_label_base_y = name_label.position.y
	# Same group enemies use for "the local target can be set to this" —
	# Targeting.click_target / Combat.set_target branch on the group.
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

# Track 22.H — server-fanned EntityTarget for this peer. ToT HUD
# subscribes via target_changed; refreshes on any transition
# (including transitions to 0 = no target).
func apply_target_change(new_target_id: int) -> void:
	if new_target_id == target_id:
		return
	target_id = new_target_id
	target_changed.emit(new_target_id)

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
	died.emit(self)
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

## The jump relay's cue: play the hop from the start (a second cue mid-air
## restarts it, which is what a real double-tap looks like too). A corpse
## does not jump.
func play_jump() -> void:
	if is_dead:
		return
	_jump_t = 0.0

func _advance_jump(delta: float) -> void:
	if _jump_t < 0.0:
		return
	_jump_t += delta
	var lift := 0.0
	if _jump_t >= JUMP_AIRTIME:
		_jump_t = -1.0
	else:
		lift = JUMP_VELOCITY * _jump_t + 0.5 * GRAVITY * _jump_t * _jump_t
	$Visual.position.y = _visual_base_y + lift
	if name_label:
		name_label.position.y = _label_base_y + lift

func _process(delta: float) -> void:
	_advance_jump(delta)
	super(delta)
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

