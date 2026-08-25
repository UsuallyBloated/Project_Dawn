extends CharacterBody3D
class_name PlayerCharacter

const SPEED = 5.0
const CROUCH_SPEED = 2.5
const GRAVITY = -20.0
const JUMP_VELOCITY = 7.0
const MOUSE_SENSITIVITY = 0.003
# Pixels the cursor must travel with the left button held before a click turns
# into a camera-orbit drag. Below this, a left press is a target-select click.
const CAMERA_DRAG_THRESHOLD = 6.0
# How fast (per second) the camera swings back behind the body after a left-drag
# look-around, once you steer or move. exp-based so it's framerate-stable.
const CAM_YAW_RECENTER_RATE = 12.0
const THIRD_PERSON_DISTANCE = 3.0
const ZOOM_STEP = 0.5
const ZOOM_MIN = 0.0   # 0 lets the wheel scroll all the way into first person
const ZOOM_MAX = 10.0
# F9 view cycle: first-person → close → far. Below FIRST_PERSON_HIDE_DIST the
# own capsule is hidden so the camera (parked at head height) isn't inside it.
const VIEW_PRESETS := [0.0, THIRD_PERSON_DISTANCE, 7.0]
const FIRST_PERSON_HIDE_DIST = 0.6
const STAND_HEIGHT = 2.0
const CROUCH_HEIGHT = 1.0
const STAND_CAMERA_Y = 1.6
const CROUCH_CAMERA_Y = 0.7
const FALL_DAMAGE_THRESHOLD := 9.0  # m/s downward; below this landing is safe
const FALL_DAMAGE_MULT := 5         # HP lost per m/s above threshold

# Track 2 — server-authoritative movement reconciliation.
# When a Position broadcast arrives:
#   - Filter to own player ID; ignore others (Track 3 handles those).
#   - Drop out-of-order packets (channel 1 is Unreliable).
#   - First broadcast: snap unconditionally — server's DB-loaded spawn may
#     differ from world.tscn's local spawn point.
#   - Else: snap if horizontal divergence > SERVER_SNAP_THRESHOLD, otherwise
#     update _server_pos_target and lerp toward it each physics tick.
# Server has no Y-axis physics in slice 2 (no gravity, no jumping). Reconcile
# X/Z only; Y stays under local control until server-side physics lands.
const SERVER_SNAP_THRESHOLD := 1.0  # metres
# Time-based smoothing rate. Per-frame factor is computed as
# `1.0 - exp(-RATE * delta)` so closure speed is consistent across framerates.
# 17.3 /sec ≈ 95% convergence in ~167ms (matches the original 0.25-per-frame
# feel at 60 fps, but stays stable when frame rate dips).
const SERVER_LERP_RATE := 17.3

# Must match MAX_MOVE_SPEED in server crates/projectdawn-server/src/world/mod.rs.
# The server reads Move.direction as a unit vector and integrates `direction *
# MAX_MOVE_SPEED * dt` per tick, so we scale outgoing direction by
# (current_speed / SERVER_MAX_MOVE_SPEED) to make server-side movement match
# whatever the client is locally predicting (base 5 m/s, crouch 2.5, with
# speed-buff multipliers). Server clamps direction length to 1.0, so any
# buff pushing local speed above the cap gets capped on the wire too.
const SERVER_MAX_MOVE_SPEED := 7.5

# Throttle Move sends to the server's 20 Hz tick rate. The server applies a
# fixed TICK_DT (50ms) of integration per accepted Move, so sending faster
# than server-tick scales effective server speed by (client_send_rate /
# server_tick_rate). At 60 fps unthrottled that runs the server 3× ahead of
# the client and looks like rubber-banding. 50ms == one server tick.
const MOVE_SEND_INTERVAL := 0.05

enum PlayerState { STANDING, CROUCHING, SITTING }

var state := PlayerState.STANDING
var is_crouching: bool:
	get: return state == PlayerState.CROUCHING

var is_camera_active := false
# Left-drag camera orbit (EQ left-mouse look-around): swing the camera around
# the body without turning the body. Engaged only after the cursor drags past
# CAMERA_DRAG_THRESHOLD, so a plain left-click still selects a target.
var is_look_active := false
# Sticky mouselook (EQ F12): a latched equivalent of holding the right button,
# so you can steer with the mouse hands-free. Suspended while a text field is
# focused so the cursor frees up for typing; re-engages when you close it.
var _mouselook_toggled := false
var _lmb_was_down := false
var _lmb_tracking := false          # left press began over the 3D world (eligible to click/drag)
var _lmb_dragged := false           # this hold crossed the drag threshold
var _lmb_press_screen: Vector2i = Vector2i.ZERO
# Right-button tap detection, mirroring the left-button set above. A right TAP
# (released under the drag threshold) is the world-interact verb — mine, loot,
# talk, bank — while a right DRAG stays the camera. Motion is accumulated from
# relative mouse events because the cursor is parked while captured, so screen
# positions can't measure a drag the way the left button's do.
var _rmb_was_down := false
var _rmb_tap_candidate := false     # press began over the 3D world, single-button
var _rmb_motion := 0.0              # relative motion accumulated during the hold
var _rmb_press_vp: Vector2 = Vector2.ZERO   # viewport pos at press, for the interact ray
# Camera pitch (both drag modes) and yaw offset behind the body (left-drag
# only). Held as explicit Euler components so re-centering can't accumulate roll.
var _cam_pitch: float = 0.0
var _cam_yaw: float = 0.0
# Autorun (EQ `\`): latched run-forward, cancelled by tapping back or re-pressing.
var _autorun := false
# F9 view-cycle index into VIEW_PRESETS; starts at close third-person (3.0).
var _view_index := 1
# Cursor position when camera mode last engaged, in screen coordinates.
# MOUSE_MODE_CAPTURED parks the cursor at the window centre and Godot's
# Input.warp_mouse + Viewport.get_mouse_position pair applies different
# transforms (canvas vs window), causing a small constant offset on
# round-trip. DisplayServer's get/warp pair is in raw screen coords —
# no transforms — so the restore lands exactly where the capture happened.
var _cursor_before_camera: Vector2i = Vector2i.ZERO
var _is_local := false
var _heading_train_accum: float = 0.0
var _was_on_floor: bool = true
var _peak_fall_speed: float = 0.0

# Track 2 — server-authoritative movement state.
var _server_pos_target: Vector3 = Vector3.ZERO
var _last_server_seq: int = -1
var _received_first_pos: bool = false
var _move_send_accum: float = 0.0

signal state_changed(new_state: int)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual: MeshInstance3D = $Visual

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

	# Swap the capsule for the local player's race model (no-op for races
	# without a custom model). Remote peers do the same from their own race.
	RaceModel.apply(visual, PlayerStats.race)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_arm.spring_length = THIRD_PERSON_DISTANCE
	# Seed pitch/yaw from whatever the scene authored so the first drag doesn't snap.
	_cam_pitch = camera_pivot.rotation.x
	_cam_yaw = camera_pivot.rotation.y
	add_to_group("player")
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)
	ChatWindowManager.visible = true
	PlayerDeath.set_respawn_point(global_position)
	PlayerDeath.register_player(self)
	Targeting.register_camera(camera)
	Targeting.register_player(self)
	Combat.register_player(self)
	Regen.register_player(self)
	Net.world_position.connect(_on_world_position)

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
	# Mouse motion stays in `_input` so click-drag keeps working even when the
	# cursor crosses over UI panels. Right-drag turns the body; left-drag swings
	# the camera around a stationary body. Pitch is shared by both.
	if event is InputEventMouseMotion and (is_camera_active or is_look_active):
		var rel: Vector2 = event.relative
		if is_camera_active:
			_rmb_motion += rel.length()
		_cam_pitch = clamp(_cam_pitch - rel.y * MOUSE_SENSITIVITY, -PI / 2.0, PI / 2.0)
		if is_camera_active:
			rotate_y(-rel.x * MOUSE_SENSITIVITY)   # steer: camera follows, locked behind
		else:
			_cam_yaw -= rel.x * MOUSE_SENSITIVITY   # orbit: camera only, body unchanged
		_apply_camera_pivot()
		get_viewport().set_input_as_handled()

func _apply_camera_pivot() -> void:
	camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

# Drives the three-state mouse rig (EQ-style): right-drag steers the body,
# left-drag orbits the camera, both buttons run forward. The F12 mouselook
# toggle latches the right-drag steer on hands-free. Polls hardware button
# state (not events) so it keeps working even when a UI panel eats the event.
# All gated so a drag that starts over UI never grabs the camera, and a plain
# left-click still falls through to target selection.
func _update_mouse_camera(chat_focused: bool) -> void:
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Latched mouselook acts like a held right button, but stands down while
	# typing so the mouse is free for the chat/UI underneath.
	var toggle_cam := _mouselook_toggled and not chat_focused

	# Right button (or the toggle) → body mouselook. Gate only fresh RMB presses
	# on UI; the toggle is an explicit command, so it engages regardless. While
	# held, let the cursor cross UI without dropping camera.
	var want_cam := rmb or toggle_cam
	if rmb and not toggle_cam and not is_camera_active:
		if get_viewport().gui_get_hovered_control() != null:
			want_cam = false
	is_camera_active = want_cam
	if is_camera_active:
		# RMB takes over from any in-progress left orbit.
		is_look_active = false
		_lmb_tracking = false

	# Right button edges: a TAP (no drag) is the world-interact verb; a drag is
	# the camera and is already handled above. The press position is recorded
	# before the capture block below parks the cursor, so the interact ray fires
	# from where the player actually clicked.
	if rmb and not _rmb_was_down:
		_rmb_press_vp = get_viewport().get_mouse_position()
		_rmb_motion = 0.0
		# Eligible only when: single-button (not the both-buttons run), not in
		# latched mouselook (no meaningful cursor), and not starting over UI.
		_rmb_tap_candidate = (
			not _mouselook_toggled and not lmb
			and get_viewport().gui_get_hovered_control() == null
		)
	elif not rmb and _rmb_was_down:
		if _rmb_tap_candidate and _rmb_motion <= CAMERA_DRAG_THRESHOLD:
			Targeting.interact_at(_rmb_press_vp)
		_rmb_tap_candidate = false
	_rmb_was_down = rmb

	# Left button edges: a click selects a target, a drag orbits the camera.
	if lmb and not _lmb_was_down:
		_lmb_press_screen = DisplayServer.mouse_get_position()
		var over_ui := get_viewport().gui_get_hovered_control() != null
		_lmb_tracking = not over_ui and not is_camera_active
		_lmb_dragged = false
	elif not lmb and _lmb_was_down:
		if is_look_active:
			is_look_active = false
		elif _lmb_tracking and not _lmb_dragged and not is_camera_active:
			Targeting.click_target(get_viewport().get_mouse_position())
		_lmb_tracking = false
		_lmb_dragged = false
	_lmb_was_down = lmb

	# Promote a held left press to an orbit once it drags past the threshold.
	if _lmb_tracking and not _lmb_dragged and not is_camera_active:
		var moved := Vector2(DisplayServer.mouse_get_position() - _lmb_press_screen).length()
		if moved > CAMERA_DRAG_THRESHOLD:
			_lmb_dragged = true
			is_look_active = true

	# Single owner of mouse_mode: capture while either drag is live, restore the
	# cursor (to where the drag began) when both end.
	var want_capture := is_camera_active or is_look_active
	if want_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_cursor_before_camera = DisplayServer.mouse_get_position()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not want_capture and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		DisplayServer.warp_mouse(_cursor_before_camera - get_window().position)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_local:
		return
	# Wheel zoom: skip when the cursor is over any UI Control. Godot's
	# ScrollContainer scrolls on wheel but doesn't mark the event handled,
	# so without this gate the camera would zoom while the chat / test
	# panel / character window scrolled. `gui_get_hovered_control` returns
	# non-null whenever the cursor is over an interactive Control (windows
	# and HUD widgets), null when over the 3D world.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if get_viewport().gui_get_hovered_control() != null:
				return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(spring_arm.spring_length - ZOOM_STEP, ZOOM_MIN)
			_update_view_visibility()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(spring_arm.spring_length + ZOOM_STEP, ZOOM_MAX)
			_update_view_visibility()
			get_viewport().set_input_as_handled()
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
		elif event.is_action("toggle_mouselook"):
			_mouselook_toggled = not _mouselook_toggled
		elif event.is_action("toggle_autorun"):
			_autorun = not _autorun
		elif event.is_action("cycle_view"):
			_view_index = (_view_index + 1) % VIEW_PRESETS.size()
			spring_arm.spring_length = VIEW_PRESETS[_view_index]
			_update_view_visibility()

# Hide the own capsule once the camera is close enough to sit inside it
# (first person / heavy zoom-in). Shared by the F9 cycle and the wheel zoom so
# both keep the mesh state consistent.
func _update_view_visibility() -> void:
	visual.visible = spring_arm.spring_length >= FIRST_PERSON_HIDE_DIST

func _is_text_input_focused() -> bool:
	# Main-viewport focus (chat input, vendor qty field, etc.).
	var f := get_viewport().gui_get_focus_owner()
	if f != null and (f is LineEdit or f is TextEdit):
		return true
	# Sub-windows (Window nodes like the hotbar's Social / Macro editor)
	# have their own viewports and their own focus owner. Without
	# recursing, typing in those windows leaks to the player's movement
	# inputs (spacebar → jump while editing a macro line).
	return _viewport_has_text_focus(get_tree().root)

func _viewport_has_text_focus(vp: Viewport) -> bool:
	var f := vp.gui_get_focus_owner()
	if f != null and (f is LineEdit or f is TextEdit):
		return true
	return _scan_for_text_window(vp)

# Track 16.0 bug 5 — the previous walk only iterated direct children of
# the root viewport, so a Window parented deep (CanvasLayer → Hotbar →
# Window) was never reached and spacebar still jumped the character
# while typing a macro. Recurse through the entire subtree, checking
# each Window's own focus owner.
func _scan_for_text_window(node: Node) -> bool:
	for child in node.get_children():
		if child is Window:
			var inner := (child as Window).gui_get_focus_owner()
			if inner != null and (inner is LineEdit or inner is TextEdit):
				return true
		if _scan_for_text_window(child):
			return true
	return false

func _physics_process(delta: float) -> void:
	var chat_focused := _is_text_input_focused()
	_update_mouse_camera(chat_focused)
	# Death lock, client half. The server already refuses Move while you are dead,
	# but local prediction still ran here: the body lurched on each keypress and
	# was then yanked back by the server's authoritative position, which read as a
	# twitching corpse (playtest 2026-08-12). Stop predicting and stop sending;
	# the camera stays live so you can look around while awaiting respawn.
	if PlayerDeath.is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	# Both buttons held → run forward, steered by the right-button mouselook.
	var mouse_run := is_camera_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	# EQ rule: moving cancels your cast, client-side and immediately. Until now
	# NO deliberate cancel existed at all — the server's movement-during-cast
	# gate (>5 m) was the only thing that stopped a walking caster, and it
	# refuses the cast AFTER the mana was optimistically spent. Cancelling here
	# refunds instantly (Spells.cancel_cast) and matches what the corrected
	# server comment says the ideal client does.
	if Spells.is_casting() and not chat_focused and (mouse_run or _autorun or
			Input.is_action_pressed("move_forward") or
			Input.is_action_pressed("move_left") or
			Input.is_action_pressed("move_backward") or
			Input.is_action_pressed("move_right") or
			Input.is_action_pressed("jump")):
		Spells.cancel_cast()
		CombatLog.add_line("You stop casting.", CombatLog.MsgType.INFO)

	if state == PlayerState.SITTING:
		var moving := mouse_run or _autorun or (not chat_focused and (
			Input.is_action_pressed("move_forward") or
			Input.is_action_pressed("move_left") or
			Input.is_action_pressed("move_backward") or
			Input.is_action_pressed("move_right") or
			Input.is_action_pressed("jump")
		))
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
			_autorun = false   # tapping back cancels autorun (EQ behaviour)
		if Input.is_action_pressed("move_left"):
			direction -= transform.basis.x
		if Input.is_action_pressed("move_right"):
			direction += transform.basis.x
	# Mouse-run and autorun both work regardless of chat focus — they're latched
	# states / explicit gestures, not keys that could leak from typing.
	if mouse_run or _autorun:
		direction -= transform.basis.z

	var base_speed := CROUCH_SPEED if state == PlayerState.CROUCHING else SPEED
	# Track 22.C — mount overrides every other speed source. When
	# mounted, BuffManager.get_speed_mult() is ignored and the mount's
	# own multiplier applies. MountManager.get_effective_speed_mult
	# falls through to the BuffManager value when not mounted.
	# Encumbrance applies after the mount — an overloaded mount is
	# still overloaded (carry weight vs STR; see autoloads/encumbrance.gd).
	var current_speed := base_speed * MountManager.get_effective_speed_mult() \
			* Encumbrance.get_speed_mult()
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

	# Re-center the camera behind the body while steering or moving, then hold
	# wherever you leave it when you stop — so a left-drag glance-around relaxes
	# back to the chase view as soon as you run. An in-progress orbit is exempt.
	if not is_look_active and (is_camera_active or direction != Vector3.ZERO):
		var recenter := 1.0 - exp(-CAM_YAW_RECENTER_RATE * delta)
		_cam_yaw = lerp_angle(_cam_yaw, 0.0, recenter)
		_apply_camera_pivot()

	if Net.is_app_ready():
		# Throttle to server tick rate (20 Hz). Subtract instead of zeroing so
		# the average rate stays exact across variable frame times.
		_move_send_accum += delta
		if _move_send_accum >= MOVE_SEND_INTERVAL:
			_move_send_accum -= MOVE_SEND_INTERVAL
			# Scale unit direction to (current_speed / SERVER_MAX_MOVE_SPEED) so
			# the server's `direction * MAX_MOVE_SPEED` integration produces
			# current_speed.
			var server_dir := direction * (current_speed / SERVER_MAX_MOVE_SPEED)
			Net.send_movement(server_dir, false)

	move_and_slide()

	# Track 2 — blend horizontal position toward server truth. Local prediction
	# (move_and_slide above) and the lerp below run concurrently every frame; the
	# two equally-valid futures (predicted and authoritative) blend smoothly.
	# Skipped in local-save mode (Net stays idle, signal never fires, flag stays
	# false). Y is left untouched — slice 2 server has no Y physics.
	if Net.is_app_ready() and _received_first_pos:
		var blend := 1.0 - exp(-SERVER_LERP_RATE * delta)
		var blend_x := lerpf(global_position.x, _server_pos_target.x, blend)
		var blend_z := lerpf(global_position.z, _server_pos_target.z, blend)
		global_position = Vector3(blend_x, global_position.y, blend_z)

func _on_world_position(id: int, pos: Vector3, _vel: Vector3, _yaw: float, sequence: int) -> void:
	# Track 2 — own-player reconciliation only. Other-player replication is Track 3.
	if id != Net.get_player_id():
		return
	# Channel 1 is Unreliable; drop reorders and duplicate-sequence broadcasts.
	# Server uses last_move_seq for the Position broadcast field, so equal
	# sequences carry no new positional information.
	if sequence <= _last_server_seq and _received_first_pos:
		return
	_last_server_seq = sequence

	if not _received_first_pos:
		# First broadcast wins: server's DB-loaded spawn may differ from
		# world.tscn's local spawn. Snap unconditionally so scene-in is clean.
		_received_first_pos = true
		global_position = Vector3(pos.x, global_position.y, pos.z)
		_server_pos_target = global_position
		return

	var dx := pos.x - global_position.x
	var dz := pos.z - global_position.z
	var horiz := sqrt(dx * dx + dz * dz)
	if horiz > SERVER_SNAP_THRESHOLD:
		global_position = Vector3(pos.x, global_position.y, pos.z)
		_server_pos_target = global_position
	else:
		_server_pos_target = Vector3(pos.x, global_position.y, pos.z)

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
