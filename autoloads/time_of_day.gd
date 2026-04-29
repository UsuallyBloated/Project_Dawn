extends Node

signal hour_changed(hour: int)

# One full day = DAY_DURATION real seconds. Default: 20 minutes.
const DAY_DURATION := 1200.0
const START_HOUR   := 8.0    # start at 8 AM

var time_of_day: float = START_HOUR / 24.0  # normalized 0..1

var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null
var _sky_material: PhysicalSkyMaterial = null
var _environment: Environment = null
var _last_hour: int = -1

func _ready() -> void:
	call_deferred("_find_world_nodes")
	ZoneLoader.zone_ready.connect(_find_world_nodes)

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
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = Color(0.65, 0.72, 1.0)
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	get_tree().current_scene.add_child(_moon)

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / DAY_DURATION, 1.0)
	_apply()

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
	var night_t   := _night_factor()
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

func _night_factor() -> float:
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
