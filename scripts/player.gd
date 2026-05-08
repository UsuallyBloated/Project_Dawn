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
const FALL_DAMAGE_THRESHOLD := 9.0  # m/s downward; below this landing is safe
const FALL_DAMAGE_MULT := 5         # HP lost per m/s above threshold

enum PlayerState { STANDING, CROUCHING, SITTING }

var state := PlayerState.STANDING
var is_crouching: bool:
	get: return state == PlayerState.CROUCHING

var is_camera_active := false
var _is_local := false
var _heading_train_accum: float = 0.0
var _was_on_floor: bool = true
var _peak_fall_speed: float = 0.0

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
	CombatLog.visible = true
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

func _input(event: InputEvent) -> void:
	if not _is_local:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(spring_arm.spring_length - ZOOM_STEP, ZOOM_MIN)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(spring_arm.spring_length + ZOOM_STEP, ZOOM_MAX)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and is_camera_active:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI / 2.0, PI / 2.0)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("toggle_crouch"):
			if state == PlayerState.STANDING:
				_enter_state(PlayerState.CROUCHING)
			elif state == PlayerState.CROUCHING:
				_enter_state(PlayerState.STANDING)
		elif event.is_action("toggle_sit"):
			if state == PlayerState.STANDING:
				_enter_state(PlayerState.SITTING)
			elif state == PlayerState.SITTING:
				_enter_state(PlayerState.STANDING)

func _is_text_input_focused() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and (f is LineEdit or f is TextEdit)

func _physics_process(delta: float) -> void:
	# Poll hardware state so camera works even when UI panels consume the event.
	var want_cam := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if want_cam != is_camera_active:
		is_camera_active = want_cam
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if want_cam else Input.MOUSE_MODE_VISIBLE

	var chat_focused := _is_text_input_focused()

	if state == PlayerState.SITTING:
		var moving := not chat_focused and (
			Input.is_action_pressed("move_forward") or
			Input.is_action_pressed("move_left") or
			Input.is_action_pressed("move_backward") or
			Input.is_action_pressed("move_right") or
			Input.is_action_pressed("jump")
		)
		if moving:
			_enter_state(PlayerState.STANDING)
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			return

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		_on_land()
	_was_on_floor = now_on_floor

	if now_on_floor:
		_peak_fall_speed = 0.0
		if not chat_focused and Input.is_action_pressed("jump") and state != PlayerState.SITTING:
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.y += GRAVITY * delta
		_peak_fall_speed = maxf(_peak_fall_speed, -velocity.y)

	var direction := Vector3.ZERO
	if not chat_focused:
		if Input.is_action_pressed("move_forward"):
			direction -= transform.basis.z
		if Input.is_action_pressed("move_backward"):
			direction += transform.basis.z
		if Input.is_action_pressed("move_left"):
			direction -= transform.basis.x
		if Input.is_action_pressed("move_right"):
			direction += transform.basis.x

	var base_speed := CROUCH_SPEED if state == PlayerState.CROUCHING else SPEED
	var current_speed := base_speed * BuffManager.get_speed_mult()
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		_heading_train_accum += delta
		if _heading_train_accum >= 2.0:
			_heading_train_accum = 0.0
			SenseHeading.try_advance()
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)
		_heading_train_accum = 0.0

	if Net.is_app_ready():
		Net.send_movement(direction, false)

	move_and_slide()

func _on_land() -> void:
	if _peak_fall_speed <= FALL_DAMAGE_THRESHOLD:
		return
	# TODO: skip if BuffManager has levitate/feather fall active
	var dmg := maxi(1, int((_peak_fall_speed - FALL_DAMAGE_THRESHOLD) * FALL_DAMAGE_MULT))
	Combat.receive_player_damage(dmg, null, "Fall")
	CombatLog.add_line(
		"You hit the ground hard for %d damage." % dmg,
		CombatLog.MsgType.DAMAGE_IN)
	DamageNumbers.spawn_incoming(global_position, dmg)
