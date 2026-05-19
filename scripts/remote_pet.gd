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
signal died

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

func apply_health_update(new_hp: float, new_max_hp: float) -> void:
	hp = new_hp
	max_hp = new_max_hp
	hp_changed.emit(hp, max_hp)

func apply_death() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
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
