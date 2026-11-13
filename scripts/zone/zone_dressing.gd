@tool
class_name ZoneDressing
extends Node3D

# The shared half of the zone's set pieces (zone_town.gd, zone_landmarks.gd):
# where the ground is, how a built LowPoly mesh becomes a node, and the three
# things that are not meshes: a fire's light, its flicker and a column of
# smoke. Everything a subclass builds is scenery: it stands on the
# TerrainMesh's ground, collides with nothing, and the server knows none of it.

const SMOKE_COLOR := Color(0.62, 0.60, 0.57, 0.30)
# Lights are dropped past this distance, fading over the stretch before it.
const LIGHT_FADE_BEGIN := 140.0
const LIGHT_FADE_LENGTH := 50.0

@export var terrain_path := NodePath("../TerrainMesh")

var _terrain: TerrainMesh
# [light, base energy, phase] for every flickering light.
var _flames: Array = []
var _smoke_mesh: QuadMesh
var _clock := 0.0


func _ready() -> void:
	# In the editor the pieces are built to be looked at, and hold still.
	if Engine.is_editor_hint():
		set_process(false)
	_terrain = get_node_or_null(terrain_path) as TerrainMesh
	if _terrain == null:
		push_warning("%s: no TerrainMesh at %s; nothing built." % [name, terrain_path])
		return
	var started := Time.get_ticks_msec()
	_build()
	# The log autoload is looked up, never named: this script is also compiled
	# by tools that run before the autoloads exist, and in the editor, where
	# they never do.
	var debug_log := get_node_or_null("/root/DebugLog")
	if debug_log != null:
		debug_log.info("%s: %d pieces, %d ms" % [name, get_child_count(), Time.get_ticks_msec() - started])


# The subclass builds its pieces here.
func _build() -> void:
	pass


func _process(delta: float) -> void:
	if _flames.is_empty():
		return
	_clock += delta
	for f in _flames:
		var light: OmniLight3D = f[0]
		var phase: float = f[2]
		light.light_energy = float(f[1]) * (0.82 + 0.18 * sin(_clock * 9.0 + phase) * sin(_clock * 5.3 + phase * 2.1))


# --- The ground ----------------------------------------------------------

# The ground's height at a map point.
func ground(p: Vector2) -> float:
	return _terrain.height_at(p.x, p.y)


# A map point standing on the ground, `lift` metres up.
func on_ground(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, _terrain.height_at(p.x, p.y) + lift, p.y)


# A transform on the ground at a map point, turned `yaw` radians.
func stand(p: Vector2, yaw: float = 0.0, lift: float = 0.0) -> Transform3D:
	return LowPoly.at(on_ground(p, lift), yaw)


# --- Nodes ---------------------------------------------------------------

# Adds a builder's mesh as a child, seen out to `range_end` metres (0: always).
func add_piece(b: LowPoly, piece_name: String, range_end: float = 0.0) -> MeshInstance3D:
	if b.is_empty():
		return null
	var mi := b.instance(piece_name, range_end)
	add_child(mi)
	return mi


# Adds a builder's mesh as a glowing child (fire, magic, a lit window).
func add_glow(b: LowPoly, piece_name: String, energy: float, range_end: float = 0.0) -> MeshInstance3D:
	if b.is_empty():
		return null
	var mi := b.instance(piece_name, range_end, energy)
	add_child(mi)
	return mi


# A light with no shadow, dropped at a distance; `flicker` makes it a fire's.
func add_light(pos: Vector3, color: Color, energy: float, reach: float, flicker: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = LIGHT_FADE_BEGIN
	light.distance_fade_length = LIGHT_FADE_LENGTH
	add_child(light)
	if flicker:
		_flames.append([light, energy, pos.x * 0.37 + pos.z * 0.11])
	return light


# A slow column of smoke rising from `pos`, its puffs `size` metres across.
func add_smoke(pos: Vector3, size: float = 1.6) -> void:
	if _smoke_mesh == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(1, 1, 1, 1)
		# A soft round puff: white in the middle, clear at the rim.
		var puff := Gradient.new()
		puff.set_color(0, Color(1, 1, 1, 1))
		puff.set_color(1, Color(1, 1, 1, 0))
		var puff_texture := GradientTexture2D.new()
		puff_texture.gradient = puff
		puff_texture.fill = GradientTexture2D.FILL_RADIAL
		puff_texture.fill_from = Vector2(0.5, 0.5)
		puff_texture.fill_to = Vector2(0.5, 0.0)
		puff_texture.width = 64
		puff_texture.height = 64
		mat.albedo_texture = puff_texture
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.0))
	fade.add_point(0.15, SMOKE_COLOR)
	fade.set_color(fade.get_point_count() - 1, Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	var p := CPUParticles3D.new()
	p.position = pos
	p.mesh = _smoke_mesh
	p.amount = 12
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.direction = Vector3(0.25, 1.0, 0.1)
	p.spread = 7.0
	p.gravity = Vector3(0.12, 0.05, 0.0)
	p.initial_velocity_min = 0.9
	p.initial_velocity_max = 1.5
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.scale_amount_curve = grow
	p.color_ramp = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 900.0
	add_child(p)
