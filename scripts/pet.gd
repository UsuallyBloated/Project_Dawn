class_name Pet
extends CharacterBody3D

signal died(pet)
signal hp_changed(current: float, maximum: float)
signal hit_target(attacker_name: String, target_name: String, amount: int)

enum Mode { FOLLOW, ATTACK, GUARD, PASSIVE }
enum State { FOLLOWING, ATTACKING, GUARDING, DEAD }

const GRAVITY        := -20.0
const FOLLOW_DIST    := 3.0
const LEASH_DIST     := 35.0
const ATTACK_RANGE   := 1.8
const ATTACK_BUFFER  := 1.2
const GUARD_DIST     := 4.0
const GUARD_SCAN_RANGE := 12.0

@export var pet_name:        String = "Pet"
@export var level:           int    = 1
@export var max_hp:          float  = 100.0
@export var base_damage:     int    = 10
@export var move_speed:      float  = 4.0
@export var attack_interval: float  = 2.5

var hp: float
var mode: Mode = Mode.FOLLOW
var state: State = State.FOLLOWING

var is_dead: bool:
	get: return state == State.DEAD

var _attack_target = null
var _guard_target  = null
var _player: Node3D = null
var _attack_cooldown: float = 0.0

@onready var _name_label: Label3D = $NameLabel

func _ready() -> void:
	hp = max_hp
	add_to_group("pets")
	_player = get_tree().get_first_node_in_group("player")
	_name_label.text = pet_name

func setup_summoned(p_name: String, p_level: int, p_hp: float, p_damage: int) -> void:
	pet_name = p_name
	level    = p_level
	max_hp   = p_hp
	base_damage = p_damage

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	match state:
		State.FOLLOWING: _tick_follow()
		State.ATTACKING: _tick_attack(delta)
		State.GUARDING:  _tick_guard()
		State.DEAD:      pass

	move_and_slide()

# ── state ticks ───────────────────────────────────────────────────────────────

func _tick_follow() -> void:
	if not _player_valid():
		_player = get_tree().get_first_node_in_group("player")
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > LEASH_DIST:
		global_position = _player.global_position + _player.global_transform.basis.x * 2.0
		return
	if dist > FOLLOW_DIST:
		_move_toward(_player.global_position)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _tick_attack(delta: float) -> void:
	if not _target_valid():
		_clear_attack_target()
		state = State.GUARDING if mode == Mode.GUARD else State.FOLLOWING
		return
	var dist := global_position.distance_to(_attack_target.global_position)
	if dist > ATTACK_RANGE * ATTACK_BUFFER:
		_move_toward(_attack_target.global_position)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_toward(_attack_target.global_position)
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			_do_attack()

func _tick_guard() -> void:
	if not _guard_target_valid():
		_guard_target = null
		mode = Mode.FOLLOW
		state = State.FOLLOWING
		return

	var dist := global_position.distance_to(_guard_target.global_position)
	if dist > GUARD_DIST:
		_move_toward(_guard_target.global_position)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	var threat := _find_threat_near(_guard_target.global_position, GUARD_SCAN_RANGE)
	if threat != null:
		_clear_attack_target()
		_attack_target = threat
		if not threat.is_connected("died", _on_target_died):
			threat.died.connect(_on_target_died)
		state = State.ATTACKING

# ── combat ────────────────────────────────────────────────────────────────────

func _do_attack() -> void:
	if not _target_valid():
		return
	var target = _attack_target
	target.take_damage(base_damage)
	if is_instance_valid(target):
		DamageNumbers.spawn_damage(target.global_position, base_damage, false)
		hit_target.emit(pet_name, target.mob_name, base_damage)

# ── public API ────────────────────────────────────────────────────────────────

func set_attack_target(target) -> void:
	if mode == Mode.PASSIVE:
		return
	_clear_attack_target()
	_attack_target = target
	if target != null and is_instance_valid(target):
		state = State.ATTACKING
		if not target.is_connected("died", _on_target_died):
			target.died.connect(_on_target_died)
	else:
		state = State.GUARDING if mode == Mode.GUARD else State.FOLLOWING

func set_guard_target(target) -> void:
	if mode == Mode.PASSIVE:
		return
	_clear_attack_target()
	_guard_target = target
	mode = Mode.GUARD
	state = State.GUARDING

func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	match new_mode:
		Mode.FOLLOW, Mode.PASSIVE:
			_clear_attack_target()
			_guard_target = null
			state = State.FOLLOWING
		Mode.GUARD:
			pass  # use set_guard_target to enter guard mode with a target

func dismiss() -> void:
	state = State.DEAD
	queue_free()

func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()

func _die() -> void:
	state = State.DEAD
	died.emit(self)
	await get_tree().create_timer(2.0).timeout
	queue_free()

# ── helpers ───────────────────────────────────────────────────────────────────

func _find_threat_near(pos: Vector3, radius: float) -> Node:
	var nearest: Node = null
	var nearest_dist := radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.state in [Enemy.State.IDLE, Enemy.State.DEAD, Enemy.State.LEASH]:
			continue
		var d := pos.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest

func _clear_attack_target() -> void:
	if is_instance_valid(_attack_target) and _attack_target.is_connected("died", _on_target_died):
		_attack_target.died.disconnect(_on_target_died)
	_attack_target = null

func _on_target_died(_t) -> void:
	_attack_target = null
	state = State.GUARDING if mode == Mode.GUARD else State.FOLLOWING

func _guard_target_valid() -> bool:
	if _guard_target == null or not is_instance_valid(_guard_target):
		return false
	var dead = _guard_target.get("is_dead")
	return dead == null or not dead

func _player_valid() -> bool:
	return _player != null and is_instance_valid(_player)

func _target_valid() -> bool:
	return _attack_target != null and is_instance_valid(_attack_target) and not _attack_target.is_dead

func _move_toward(target_pos: Vector3) -> void:
	var dir := (target_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_toward(target_pos)

func _face_toward(target_pos: Vector3) -> void:
	var look_pos := Vector3(target_pos.x, global_position.y, target_pos.z)
	if look_pos.distance_to(global_position) > 0.01:
		look_at(look_pos, Vector3.UP)
