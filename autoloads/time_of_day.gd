extends Node

# The sky's clock: the sun and moon arcs, sky colours and fog all follow
# `time_of_day`. Online the SERVER owns the hour (world/clock.rs in the server
# repo). It sends the hour as we enter the world and about once a minute
# after; this clock keeps running at the same rate in between and uses each
# send only to stay in step, so every player sees the same sky. Until the
# first send arrives (the login screen, the Test Room) it is a free-running
# local clock starting at START_HOUR.

signal hour_changed(hour: int)

# One full day = DAY_DURATION real seconds (20 minutes). LOCKSTEP with the
# server's DAY_LENGTH_SECS in world/clock.rs: this clock runs at this rate
# between the server's sends, so if the two disagree the sky has to correct
# itself every minute.
const DAY_DURATION := 1200.0
const START_HOUR   := 8.0    # the local clock's start, before any server hour

# Following the server. An error up to SNAP_THRESHOLD is absorbed by running
# the clock fast or slow, so the sun never visibly steps; anything larger (the
# first send after login, a Test Panel slider drag) is a straight jump.
const SNAP_THRESHOLD := 1.0 / 24.0   # one game hour, as a fraction of a day
const CATCH_UP_RATE  := 3.0          # extra speed while behind: up to 4x
const SLOW_DOWN_RATE := 0.75         # speed shed while ahead: down to 0.25x, never backwards

var time_of_day: float = START_HOUR / 24.0  # normalized 0..1
# Holds the sky still. A dev tool (the Test Panel's Pause box): while set, the
# clock neither advances nor follows the server, and the Test Panel's slider
# sets the hour by writing `time_of_day` directly.
var paused: bool = false

# Signed fraction of a day still to absorb to match the server; positive
# means this clock is behind.
var _sync_error: float = 0.0

var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null
var _sky_material: PhysicalSkyMaterial = null
var _environment: Environment = null
var _last_hour: int = -1

func _ready() -> void:
	call_deferred("_find_world_nodes")
	ZoneLoader.zone_ready.connect(_find_world_nodes)
	Net.world_time_of_day.connect(_on_server_hour)

func _find_world_nodes() -> void:
	_sun = null
	_moon = null
	_sky_material = null
	_environment = null
	_sun = get_tree().get_first_node_in_group("sun")
	var env_node: WorldEnvironment = get_tree().get_first_node_in_group("world_environment")
	if env_node:
		_environment = env_node.environment
		if _environment and _environment.sky:
			_sky_material = _environment.sky.sky_material as PhysicalSkyMaterial
	_setup_moon()

func _setup_moon() -> void:
	_moon = get_tree().get_first_node_in_group("moon")
	if _moon != null:
		return
	# No scene yet (a headless run, or the instant between two scenes): the
	# next zone_ready comes back through here.
	var scene := get_tree().current_scene
	if scene == null:
		return
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = Color(0.65, 0.72, 1.0)
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	scene.add_child(_moon)

func _process(delta: float) -> void:
	# A paused clock still paints, so the Test Panel's slider moves the sky
	# while Pause holds it there (the only way to keep a hand-set hour online,
	# where an unpaused clock rejoins the server at the next send).
	if not paused:
		time_of_day = fmod(time_of_day + _step_for(delta), 1.0)
	_apply()
	_emit_hour_if_changed()

# How far the clock moves this frame: real time at the day's rate, plus or
# minus whatever part of the outstanding server correction fits.
func _step_for(delta: float) -> float:
	var step := delta / DAY_DURATION
	if _sync_error > 0.0:
		var extra := minf(_sync_error, step * CATCH_UP_RATE)
		_sync_error -= extra
		return step + extra
	if _sync_error < 0.0:
		var held := minf(-_sync_error, step * SLOW_DOWN_RATE)
		_sync_error += held
		return step - held
	return step

# The server's hour arrived. A small difference becomes a correction that
# `_step_for` works off over the next few seconds; a large one is a jump.
func _on_server_hour(hour: float) -> void:
	if not is_finite(hour):
		return
	if paused:
		_sync_error = 0.0
		return
	var target := fposmod(hour / 24.0, 1.0)
	# Shortest way round the clock, in [-0.5, 0.5): 23:50 to 00:10 is +20
	# minutes, not -23 hours 40.
	var error := fposmod(target - time_of_day + 0.5, 1.0) - 0.5
	if absf(error) > SNAP_THRESHOLD:
		time_of_day = target
		_sync_error = 0.0
		_apply()
		_emit_hour_if_changed()
	else:
		_sync_error = error

func _emit_hour_if_changed() -> void:
	var hour := int(time_of_day * 24.0)
	if hour != _last_hour:
		_last_hour = hour
		hour_changed.emit(hour)

func get_hour() -> int:
	return int(time_of_day * 24.0)

func get_time_string() -> String:
	var h := get_hour()
	var m := int(fmod(time_of_day * 24.0, 1.0) * 60.0)
	return "%02d:%02d" % [h, m]

func _apply() -> void:
	var night_t   := night_factor()
	var dawn_dusk := _dawn_dusk_factor()

	# Sun arc: rises at ~6 AM (x=0), peaks at noon (x=-90), sets at ~6 PM
	var sun_angle := 90.0 - time_of_day * 360.0
	if _sun != null:
		_sun.rotation_degrees.x = sun_angle
		_sun.light_energy = lerpf(1.2, 0.0, night_t)
		_sun.light_color = Color(
			1.0,
			lerpf(0.85, 0.55, dawn_dusk),
			lerpf(0.75, 0.30, dawn_dusk)
		).lerp(Color(0.1, 0.08, 0.15), night_t)

	# Moon: opposite the sun, fades in at night
	if _moon != null:
		_moon.rotation_degrees.x = sun_angle + 180.0
		_moon.light_energy = lerpf(0.0, 0.18, night_t)

	if _sky_material == null:
		return

	_sky_material.rayleigh_color = _lerp_dn(Color(0.26, 0.41, 0.80), Color(0.02, 0.02, 0.10), night_t)
	_sky_material.mie_color      = _lerp_dn(Color(0.90, 0.80, 0.65), Color(0.05, 0.05, 0.15), night_t)
	_sky_material.ground_color   = _lerp_dn(Color(0.50, 0.45, 0.35), Color(0.04, 0.04, 0.06), night_t)
	_sky_material.energy_multiplier = lerpf(1.0, 0.04, night_t)

	if _environment != null:
		var day_fog   := Color(0.88, 0.76, 0.52)
		var night_fog := Color(0.06, 0.06, 0.12)
		_environment.fog_light_color = _lerp_dn(day_fog, night_fog, night_t)

func night_factor() -> float:
	var hour := time_of_day * 24.0
	if hour < 5.0 or hour > 21.0:
		return 1.0
	if hour < 7.0:
		return 1.0 - smoothstep(5.0, 7.0, hour)
	if hour > 19.0:
		return smoothstep(19.0, 21.0, hour)
	return 0.0

func _dawn_dusk_factor() -> float:
	var hour := time_of_day * 24.0
	var dawn  := 1.0 - clampf(abs(hour - 6.5) / 1.5, 0.0, 1.0)
	var dusk  := 1.0 - clampf(abs(hour - 19.5) / 1.5, 0.0, 1.0)
	return maxf(dawn, dusk)

func _lerp_dn(day_color: Color, night_color: Color, t: float) -> Color:
	return day_color.lerp(night_color, t)
