extends CharacterBody3D
class_name RemotePet

# Track 11 — visual stand-in for a server-spawned player-owned pet.
# Render-only: no AI, no physics, no local HP. Position / HP / death
# state arrive as server broadcasts via RemotePetManager.
#
# Mirrors RemoteEnemy's surface (snapshot-interp buffer, hp_changed
# signal, take_damage no-op) so the existing client code that treats
# pets uniformly across solo / launcher mode keeps working. The local
# Pet class stays untouched for the Test Room single-player flow;
# only launcher mode instantiates RemotePet.
#
# Pet ids land in PET_ID_BASE (3_000_000_000+); ongoing Position /
# HealthUpdate / EntityDied / EntityDespawn route through the
# manager by id partition.

signal hp_changed(current: float, maximum: float)
signal died(pet)

# Network identity. Set by RemotePetManager *before* add_child fires
# _ready, so _ready can read them.
var pet_id: int = -1
var owner_id: int = 0
var pet_name: String = ""
var level: int = 1
var hp: float = 0.0
var max_hp: float = 0.0

var is_dead: bool = false

# Snapshot interpolation buffer of { time, pos, yaw } dicts. Identical
# pattern to RemoteEnemy — see that file's header for rationale.
const BUFFER_CAPACITY := 5
const INTERP_LAG := 0.1
var _snapshots: Array[Dictionary] = []
var _last_seq: int = -1

@onready var _name_label: Label3D = $NameLabel
@onready var _mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	if _name_label:
		_name_label.text = "%s (%d)" % [pet_name, level] if level > 1 else pet_name
	add_to_group("remote_pets")
	_apply_allegiance()
	# Re-tint when group membership changes (someone joined / left) or
	# the local /pvp flag flips. Named methods (vs. lambdas) make the
	# signal connections survive any GDScript weakref quirks and show
	# up cleanly in the editor's signal panel.
	GroupManager.group_updated.connect(_on_group_state_changed)
	Net.pvp_toggled.connect(_on_pvp_toggled)
	# Defensive second pass after the current frame's pending signals
	# flush. Covers the spawn-vs-roster race where PetSpawn arrived
	# before the group roster (Round-6 playtest: group-mate's pet
	# stuck reading as HOSTILE-red until the pet died and respawned).
	call_deferred("_apply_allegiance")

func _on_group_state_changed(_membership_changed: bool) -> void:
	_apply_allegiance()

func _on_pvp_toggled(_on: bool) -> void:
	_apply_allegiance()

var _hit_tween: Tween = null
var _base_color: Color
var _material_cached: bool = false

# Friend/foe palette. Mesh albedo and nameplate modulate are tracked
# independently so own pet can read as "yours" via the blue nameplate
# while keeping a neutral grey capsule — keeps your own warder from
# visually competing with hostile targets in a crowded fight.
#   SELF     — own pet:  grey capsule, light-blue nameplate
#   GROUP    — group-mate's pet:  blue capsule + blue nameplate (both)
#   HOSTILE  — peer's pet, local /pvp on: red capsule + red nameplate
#   NEUTRAL  — anyone else: grey capsule + grey nameplate
# Peer PvP state isn't replicated; HOSTILE reflects *our* willingness
# to engage, not theirs. Matches Combat / Spells pre-check semantics.
enum Allegiance { SELF, GROUP, NEUTRAL, HOSTILE }

const COLOR_GROUP: Color   = Color(0.40, 0.65, 1.00)  # light blue
const COLOR_NEUTRAL: Color = Color(0.78, 0.78, 0.82)  # off-white grey
const COLOR_HOSTILE: Color = Color(0.95, 0.30, 0.30)  # red

func _classify_allegiance() -> int:
	if owner_id == Net.get_player_id():
		return Allegiance.SELF
	if GroupManager.is_member(owner_id):
		return Allegiance.GROUP
	if Net.is_local_pvp_on():
		return Allegiance.HOSTILE
	return Allegiance.NEUTRAL

# Public refresh entry so RemotePetManager can iterate every pet and
# re-tint after group / PvP state changes. Per-pet signal subscriptions
# in `_ready` are kept as a redundant path (some Godot 4 signal-vs-
# autoload timing edge case in the Round-7 playtest left pets stuck
# on the wrong color even after `group_updated` fired) — having a
# central re-tint loop guarantees the refresh even if the per-pet
# signal didn't deliver.
func refresh_allegiance() -> void:
	_apply_allegiance()

# Apply allegiance to mesh + nameplate. _base_color tracks mesh tint
# only so flash_spell_hit's tween returns to the capsule color, not the
# nameplate color. SELF splits the two — grey capsule, blue name — to
# distinguish own pet from a group-mate's all-blue pet at a glance.
func _apply_allegiance() -> void:
	if is_dead or _mesh == null:
		return
	var a := _classify_allegiance()
	var mesh_col: Color
	var name_col: Color
	match a:
		Allegiance.SELF:
			mesh_col = COLOR_NEUTRAL
			name_col = COLOR_GROUP
		Allegiance.GROUP:
			mesh_col = COLOR_GROUP
			name_col = COLOR_GROUP
		Allegiance.HOSTILE:
			mesh_col = COLOR_HOSTILE
			name_col = COLOR_HOSTILE
		_:
			mesh_col = COLOR_NEUTRAL
			name_col = COLOR_NEUTRAL
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat != null:
		if not _material_cached:
			mat = mat.duplicate() as StandardMaterial3D
			_mesh.set_surface_override_material(0, mat)
			_material_cached = true
		mat.albedo_color = mesh_col
		_base_color = mesh_col
	if _name_label:
		_name_label.modulate = name_col

# Compatibility shims for Combat.deal_spell_damage path. Pets don't yet
# have replicated resist values; 0.0 is the same fallback RemoteEnemy
# uses while the server doesn't fan resists.
func get_spell_resist(_damage_type: int) -> float:
	return 0.0

# Mirror of RemoteEnemy.flash_spell_hit — pure visual cue when the
# local player casts on this pet. Server fans the authoritative HP
# update separately.
func flash_spell_hit(color: Color) -> void:
	if is_dead or _mesh == null:
		return
	var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	if not _material_cached:
		mat = mat.duplicate() as StandardMaterial3D
		_mesh.set_surface_override_material(0, mat)
		_base_color = mat.albedo_color
		_material_cached = true
	if _hit_tween:
		_hit_tween.kill()
	mat.albedo_color = color
	_hit_tween = create_tween()
	_hit_tween.tween_property(mat, "albedo_color", _base_color, 0.25)

func apply_health_update(new_hp: float, new_max_hp: float) -> void:
	hp = new_hp
	max_hp = new_max_hp
	hp_changed.emit(hp, max_hp)

func apply_death() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
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
