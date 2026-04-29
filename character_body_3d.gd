extends CharacterBody3D
class_name PlayerCharacter

const SPEED = 5.0
const CROUCH_SPEED = 2.5
const GRAVITY = -20.0
const JUMP_VELOCITY = 7.0
const MOUSE_SENSITIVITY = 0.003
const THIRD_PERSON_DISTANCE = 3.0
const ZOOM_STEP = 0.5
const ZOOM_MIN = 0.5
const ZOOM_MAX = 10.0
const STAND_HEIGHT = 2.0
const CROUCH_HEIGHT = 1.0
const STAND_CAMERA_Y = 1.6
const CROUCH_CAMERA_Y = 0.7

enum PlayerState { STANDING, CROUCHING, SITTING }

var state := PlayerState.STANDING
var is_crouching: bool:
	get: return state == PlayerState.CROUCHING

var is_camera_active := false
var _is_local := false

signal state_changed(new_state: int)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	var peer_id := str(name).to_int() if str(name).is_valid_int() else 1
	set_multiplayer_authority(peer_id)
	_setup_sync()

	_is_local = is_multiplayer_authority()
	if not _is_local:
		camera.current = false
		set_physics_process(false)
		set_process_unhandled_input(false)
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_arm.spring_length = THIRD_PERSON_DISTANCE
	add_to_group("player")
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)
	PlayerDeath.set_respawn_point(global_position)
	PlayerDeath.register_player(self)
	Targeting.register_camera(camera)
	Targeting.register_player(self)
	Combat.register_player(self)
	Regen.register_player(self)

func _setup_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	sync.replication_config = config
	add_child(sync)

func _exit_tree() -> void:
	if not _is_local:
		return
	Combat.unregister_player()
	Regen.unregister_player()
	PlayerDeath.unregister_player()
	Targeting.unregister_player()

func _enter_state(new_state: PlayerState) -> void:
	state = new_state
	var shape := collision_shape.shape as CapsuleShape3D
	match state:
		PlayerState.CROUCHING:
			shape.height = CROUCH_HEIGHT
			collision_shape.position.y = CROUCH_HEIGHT / 2.0
			camera_pivot.position.y = CROUCH_CAMERA_Y
		_:
			shape.height = STAND_HEIGHT
			collision_shape.position.y = STAND_HEIGHT / 2.0
			camera_pivot.position.y = STAND_CAMERA_Y
	state_changed.emit(state)

func sit() -> void:
	if state != PlayerState.SITTING:
		_enter_state(PlayerState.SITTING)

func stand() -> void:
	if state != PlayerState.STANDING:
		_enter_state(PlayerState.STANDING)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_camera_active = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(spring_arm.spring_length - ZOOM_STEP, ZOOM_MIN)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(spring_arm.spring_length + ZOOM_STEP, ZOOM_MAX)

	if event is InputEventMouseMotion and is_camera_active:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI / 2.0, PI / 2.0)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			if state == PlayerState.STANDING:
				_enter_state(PlayerState.CROUCHING)
			elif state == PlayerState.CROUCHING:
				_enter_state(PlayerState.STANDING)
		elif event.keycode == KEY_Z:
			if state == PlayerState.STANDING:
				_enter_state(PlayerState.SITTING)
			elif state == PlayerState.SITTING:
				_enter_state(PlayerState.STANDING)

func _physics_process(delta: float) -> void:
	if state == PlayerState.SITTING:
		var moving := (
			Input.is_key_pressed(KEY_W) or
			Input.is_key_pressed(KEY_A) or
			Input.is_key_pressed(KEY_S) or
			Input.is_key_pressed(KEY_D) or
			Input.is_key_pressed(KEY_SPACE)
		)
		if moving:
			_enter_state(PlayerState.STANDING)
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			return

	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE) and state != PlayerState.SITTING:
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.y += GRAVITY * delta

	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += transform.basis.x

	var current_speed := CROUCH_SPEED if state == PlayerState.CROUCHING else SPEED
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()
