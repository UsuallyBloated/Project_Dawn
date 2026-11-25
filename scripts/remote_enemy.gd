extends "res://scripts/remote_entity.gd"
class_name RemoteEnemy

# Visual stand-in for a server-spawned enemy. Render-only: no AI, no
# physics, no local HP. Position / HP / target / death state arrive as
# server broadcasts via RemoteEnemyManager.
#
# The snapshot interpolation, the buff countdown, is_dead and the hp_changed /
# died signals come from RemoteEntity (scripts/remote_entity.gd).
#
# Targeting / Combat compatibility: this node exposes the interface the
# combat and spell code reaches for on a target (is_dead, mob_name,
# set_targeted, take_damage, get_spell_resist, flash_spell_hit, hp / max_hp,
# hp_changed). It joins the `enemies` group so Targeting.click_target
# and Combat.set_target pick it up without a type switch. `take_damage`
# is a no-op: the server applies every hit.

signal target_changed(target_id: int)

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

@onready var _name_label: Label3D = $NameLabel
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _target_indicator: MeshInstance3D = $TargetIndicator

var _hit_tween: Tween = null
var _base_color: Color

# Spell batch step 5: the server fans a status snapshot under this mob's id
# whenever what is on it changes (DoTs, mez, root, snare, slow). Mirrors
# RemotePet's buff surface so the HUD target frame's icon row reads it
# uniformly; durations count down locally between snapshots.

func apply_buff_snapshot(names: PackedStringArray, durations: PackedFloat32Array) -> void:
	buff_names = names.duplicate()
	buff_durations = durations.duplicate()
	buffs_changed.emit()

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

# ── Target interface ──────────────────────────────────────────────────

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

# ── CC no-op stubs ────────────────────────────────────────────────────────────
# The spell paths call these directly on Combat.current_target
# (spells.gd: root/snare/apply_attack_slow/silence). Without these stubs the call aborts the WHOLE surrounding function
# with a runtime error that never reaches debug.log (engine errors are
# invisible to DebugLog), so everything after the CC line silently didn't
# happen. The server has no enemy-CC model yet, so the honest behaviour online
# is: the call lands, nothing visible happens, and the caller's remaining work
# (damage text, stealth breaks, cast bookkeeping) completes. Same precedent as
# get_spell_resist above. When server-side enemy CC lands, these become the
# application points for replicated CC state.
func root(_duration: float) -> void:
	pass

func snare(_amount: float, _duration: float) -> void:
	pass

func apply_attack_slow(_amount: float, _duration: float) -> void:
	pass

func silence(_duration: float) -> void:
	pass

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
