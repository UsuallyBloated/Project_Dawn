extends CharacterBody3D

const SPEED = 5.0
const CROUCH_SPEED = 2.5
const GRAVITY = -20.0
const JUMP_VELOCITY = 7.0
const MOUSE_SENSITIVITY = 0.003
const THIRD_PERSON_DISTANCE = 3.0
const ZOOM_STEP = 0.5
const STAND_HEIGHT = 2.0
const CROUCH_HEIGHT = 1.0
const STAND_CAMERA_Y = 1.6
const CROUCH_CAMERA_Y = 0.7

var is_crouching := false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.spring_length = THIRD_PERSON_DISTANCE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI / 2.0, PI / 2.0)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(spring_arm.spring_length - ZOOM_STEP, 0.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = THIRD_PERSON_DISTANCE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventKey and event.keycode == KEY_X and event.pressed and not event.echo:
		_toggle_crouch()

func _toggle_crouch() -> void:
	is_crouching = !is_crouching
	var shape := collision_shape.shape as CapsuleShape3D
	if is_crouching:
		shape.height = CROUCH_HEIGHT
		position.y -= (STAND_HEIGHT - CROUCH_HEIGHT) / 2.0
		camera_pivot.position.y = CROUCH_CAMERA_Y
	else:
		shape.height = STAND_HEIGHT
		position.y += (STAND_HEIGHT - CROUCH_HEIGHT) / 2.0
		camera_pivot.position.y = STAND_CAMERA_Y

func _physics_process(delta: float) -> void:
	if is_on_floor() and Input.is_key_pressed(KEY_SPACE):
		velocity.y = JUMP_VELOCITY

	if not is_on_floor():
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

	var current_speed := CROUCH_SPEED if is_crouching else SPEED
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()
