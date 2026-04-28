extends Node

signal hour_changed(hour: int)

# One full day = DAY_DURATION real seconds. Default: 20 minutes.
const DAY_DURATION := 1200.0
const START_HOUR   := 8.0    # start at 8 AM

var time_of_day: float = START_HOUR / 24.0  # normalized 0..1

var _sun: DirectionalLight3D = null
var _sky_material: PhysicalSkyMaterial = null
var _environment: Environment = null
var _last_hour: int = -1

func _ready() -> void:
	call_deferred("_find_world_nodes")

func _find_world_nodes() -> void:
	_sun = get_tree().get_first_node_in_group("sun")
	var env_node: WorldEnvironment = get_tree().get_first_node_in_group("world_environment")
	if env_node:
		_environment = env_node.environment
		if _environment and _environment.sky:
			_sky_material = _environment.sky.sky_material as PhysicalSkyMaterial

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
	# Sun angle: rises at ~6 (90°), peaks at noon (0°), sets at ~18 (-90°)
	var sun_angle := (time_of_day * 360.0) - 90.0
	if _sun != null:
		_sun.rotation_degrees.x = sun_angle

	# Sky colour shifts: dawn/dusk orange, noon blue, night dark
	if _sky_material == null:
		return

	var night_t := _night_factor()
	_sky_material.sky_top_color    = _lerp_day_night(Color(0.1, 0.2, 0.6), Color(0.01, 0.01, 0.05), night_t)
	_sky_material.sky_horizon_color = _lerp_day_night(Color(0.6, 0.7, 0.9), Color(0.05, 0.03, 0.08), night_t)
	_sky_material.ground_horizon_color = _lerp_day_night(Color(0.5, 0.45, 0.35), Color(0.02, 0.02, 0.04), night_t)

	if _sun != null:
		_sun.light_energy = lerpf(1.0, 0.02, night_t)
		var dawn_dusk := _dawn_dusk_factor()
		_sun.light_color = _lerp_day_night(
			Color(1.0, 0.85 - dawn_dusk * 0.3, 0.7 - dawn_dusk * 0.4),
			Color(0.1, 0.08, 0.15),
			night_t
		)

func _night_factor() -> float:
	# 0 = full day, 1 = full night
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

func _lerp_day_night(day_color: Color, night_color: Color, t: float) -> Color:
	return day_color.lerp(night_color, t)
