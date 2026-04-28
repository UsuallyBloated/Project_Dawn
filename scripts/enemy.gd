extends CharacterBody3D

signal died(enemy)
signal hp_changed(current: float, maximum: float)

const AGGRO_RANGE := 10.0
const MELEE_RANGE := 1.8
const MOVE_SPEED := 2.5
const ATTACK_INTERVAL := 2.5
const GRAVITY := -20.0

@export var mob_name: String = "Skeleton"
@export var level: int = 1
@export var max_hp: float = 50.0
@export var xp_reward: int = 20
@export var base_damage: int = 5

var hp: float
var is_dead := false

enum State { IDLE, AGGRO, DEAD }
var state := State.IDLE

var _player: Node3D = null
var _attack_cooldown := 2.5

@onready var _target_indicator: MeshInstance3D = $TargetIndicator
@onready var _name_label: Label3D = $NameLabel

var _flash_tween: Tween = null

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_name_label.text = mob_name

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	match state:
		State.IDLE:
			_tick_idle()
		State.AGGRO:
			_tick_aggro(delta)

func _tick_idle() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) <= AGGRO_RANGE:
		state = State.AGGRO

func _tick_aggro(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		state = State.IDLE
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > AGGRO_RANGE * 2.0:
		state = State.IDLE
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if dist > MELEE_RANGE:
		var dir := (_player.global_position - global_position)
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		var look_pos := _player.global_position
		look_pos.y = global_position.y
		if look_pos.distance_to(global_position) > 0.01:
			look_at(look_pos, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_attack_cooldown = ATTACK_INTERVAL
			_attack_player()

	move_and_slide()

func _attack_player() -> void:
	PlayerStats.set_hp(PlayerStats.hp - base_damage)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if state == State.IDLE:
		state = State.AGGRO
	if hp <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	state = State.DEAD
	velocity = Vector3.ZERO
	PlayerStats.gain_xp(xp_reward)
	died.emit(self)
	await get_tree().create_timer(2.0).timeout
	queue_free()

func set_targeted(targeted: bool) -> void:
	_target_indicator.visible = targeted
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null
	if targeted:
		_flash_tween = create_tween().set_loops()
		_flash_tween.tween_property(_name_label, "modulate", Color(1.0, 0.9, 0.1, 1.0), 0.4)
		_flash_tween.tween_property(_name_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)
	else:
		_name_label.modulate = Color.WHITE
