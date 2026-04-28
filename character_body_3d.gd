extends CharacterBody3D

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

var is_crouching := false
var is_camera_active := false
var _tab_target_index := 0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_arm.spring_length = THIRD_PERSON_DISTANCE
	add_to_group("player")
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)

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

	if event is InputEventKey and event.keycode == KEY_X and event.pressed and not event.echo:
		_toggle_crouch()

	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		_cycle_target()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_click_target(event.position)

func _click_target(mouse_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state
	var origin := camera.project_ray_origin(mouse_pos)
	var end := origin + camera.project_ray_normal(mouse_pos) * 100.0
	var params := PhysicsRayQueryParameters3D.create(origin, end)
	var result := space.intersect_ray(params)
	if result.is_empty():
		Combat.set_target(null)
		return
	var body = result["collider"]
	if body.is_in_group("enemies") and not body.is_dead:
		Combat.set_target(body)
	else:
		Combat.set_target(null)

func _cycle_target() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	if enemies.is_empty():
		Combat.set_target(null)
		return
	enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	if Combat.current_target == null or not enemies.has(Combat.current_target):
		_tab_target_index = 0
	else:
		_tab_target_index = (enemies.find(Combat.current_target) + 1) % enemies.size()
	Combat.set_target(enemies[_tab_target_index])

func _toggle_crouch() -> void:
	is_crouching = !is_crouching
	var shape := collision_shape.shape as CapsuleShape3D
	if is_crouching:
		shape.height = CROUCH_HEIGHT
		collision_shape.position.y = CROUCH_HEIGHT / 2.0
		camera_pivot.position.y = CROUCH_CAMERA_Y
	else:
		shape.height = STAND_HEIGHT
		collision_shape.position.y = STAND_HEIGHT / 2.0
		camera_pivot.position.y = STAND_CAMERA_Y

func _physics_process(delta: float) -> void:
	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
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

	var current_speed := CROUCH_SPEED if is_crouching else SPEED
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()
