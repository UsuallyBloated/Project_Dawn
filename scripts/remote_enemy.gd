extends CharacterBody3D
class_name RemoteEnemy

# Visual stand-in for a server-spawned enemy. Render-only: no AI, no
# physics, no local HP. Position / HP / target / death state arrive as
# server broadcasts via RemoteEnemyManager.
#
# Snapshot-interpolation pattern is identical to RemotePlayer
# (BUFFER_CAPACITY = 5, INTERP_LAG = 100 ms). The local Enemy class
# stays untouched for the Test Room single-player flow; only the
# launcher-mode world.tscn ever instantiates RemoteEnemy.
#
# Targeting / Combat compatibility: this node mirrors the public
# interface that `enemy.gd` exposes (is_dead, mob_name, set_targeted,
# take_damage, get_spell_resist, flash_spell_hit, hp / max_hp,
# hp_changed). It joins the `enemies` group so Targeting._click_target
# and Combat.set_target pick it up without a type switch. `take_damage`
# is a no-op while sub-task 3 (player → server Attack intent) is
# unwritten — the existing local-damage path keeps calling it harmlessly
# and the auto-attack cycle just costs a few timer fires per minute.

signal hp_changed(current: float, maximum: float)
signal target_changed(target_id: int)
# Emitted by `apply_death` when the server's EntityDied lands on this
# enemy. Combat.set_target subscribes so auto-attack disengages on kill;
# without this signal a remote enemy's death wouldn't reach the
# `_on_target_died` handler and auto-attack would stay toggled on
# against the corpse.
signal died(enemy)

# Network identity. Set by RemoteEnemyManager *before* add_child fires
# _ready, so _ready can read them.
var enemy_id: int = -1
var mob_name: String = ""
var level: int = 1
var hp: float = 0.0
var max_hp: float = 0.0

# Server-driven target (player char_id or another enemy id, or 0 = no
# target). Sub-task 2D will render a "this mob is targeting you"
# indicator on the HUD when target_id == own player id.
var target_id: int = 0

var is_dead: bool = false

# Snapshot interpolation buffer of { time, pos, yaw } dicts. Identical
# pattern to RemotePlayer — see that file's header for rationale.
const BUFFER_CAPACITY := 5
const INTERP_LAG := 0.1
var _snapshots: Array[Dictionary] = []
var _last_seq: int = -1

@onready var _name_label: Label3D = $NameLabel
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _target_indicator: MeshInstance3D = $TargetIndicator

var _hit_tween: Tween = null
var _base_color: Color

func _ready() -> void:
	if _name_label:
		_name_label.text = "%s (%d)" % [mob_name, level] if level > 1 else mob_name
	add_to_group("enemies")
	add_to_group("remote_enemies")
	# Material is shared between scene instances; duplicate so per-enemy
	# flashes don't bleed across nodes.
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat = mat.duplicate() as StandardMaterial3D
		_mesh.set_surface_override_material(0, mat)
		_base_color = mat.albedo_color

func apply_health_update(new_hp: float, new_max_hp: float) -> void:
	hp = new_hp
	max_hp = new_max_hp
	hp_changed.emit(hp, max_hp)

func apply_target_change(new_target_id: int) -> void:
	if new_target_id == target_id:
		return
	target_id = new_target_id
	target_changed.emit(new_target_id)

func apply_death() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	if _target_indicator:
		_target_indicator.visible = false
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", PI * 0.5, 0.5)
	if _name_label:
		var faded := Color(0.6, 0.6, 0.6, 1.0)
		tw.parallel().tween_property(_name_label, "modulate", faded, 0.5)

func on_position_update(pos: Vector3, yaw: float, sequence: int) -> void:
	if sequence <= _last_seq:
		return
	_last_seq = sequence
	if is_dead:
		return
	var now := Time.get_unix_time_from_system()
	_snapshots.append({"time": now, "pos": pos, "yaw": yaw})
	if _snapshots.size() > BUFFER_CAPACITY:
		_snapshots.pop_front()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	if _snapshots.size() < 2:
		if _snapshots.size() == 1:
			global_position = _snapshots[0]["pos"]
			rotation.y = _snapshots[0]["yaw"]
		return
	var target_time := Time.get_unix_time_from_system() - INTERP_LAG
	var a: Dictionary = _snapshots[_snapshots.size() - 2]
	var b: Dictionary = _snapshots[_snapshots.size() - 1]
	for i in range(_snapshots.size() - 1):
		if _snapshots[i]["time"] <= target_time and _snapshots[i + 1]["time"] >= target_time:
			a = _snapshots[i]
			b = _snapshots[i + 1]
			break
	var span: float = b["time"] - a["time"]
	if span <= 0.0:
		global_position = b["pos"]
		rotation.y = b["yaw"]
		return
	var t: float = clampf((target_time - a["time"]) / span, 0.0, 1.0)
	global_position = (a["pos"] as Vector3).lerp(b["pos"], t)
	rotation.y = lerp_angle(a["yaw"], b["yaw"], t)

# ── Enemy-compatible interface ────────────────────────────────────────

func set_targeted(active: bool) -> void:
	if _target_indicator:
		_target_indicator.visible = active

# Local damage application is a no-op for server-authoritative enemies.
# Sub-task 3 will replace the calling code path with an Attack intent
# sent to the server; for now the existing combat.gd keeps swinging at
# the target and nothing happens until that lands.
func take_damage(_amount: int) -> void:
	pass

# Resists are 0 in sub-task 2 (the server doesn't replicate them yet
# and AoE damage application is also a no-op until sub-task 3). Stub
# exists so combat.deal_aoe_spell_damage doesn't crash with
# "method not found" when it sweeps the `enemies` group.
func get_spell_resist(_damage_type: int) -> float:
	return 0.0

func flash_spell_hit(color: Color) -> void:
	# Pure visual feedback when the local player casts on this mob.
	# Authoritative outcome arrives separately via fan-out; this is just
	# the immediate "I cast something" cue and is safe to keep client-local.
	if is_dead:
		return
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	if _hit_tween:
		_hit_tween.kill()
	mat.albedo_color = color
	_hit_tween = create_tween()
	_hit_tween.tween_property(mat, "albedo_color", _base_color, 0.25)
