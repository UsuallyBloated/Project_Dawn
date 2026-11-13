class_name LowPoly
extends RefCounted

# A builder for the zone's placeholder scenery: flat-shaded, vertex-coloured
# meshes made of a few plain solids (boxes, gabled roofs, tapered columns,
# lumpy spheres). The low-poly look with no art files: each solid is added
# through a Transform3D, so a wall, a tent or a tree is a dozen calls, and one
# builder commits to one mesh however many solids went in. Scenery only:
# nothing built here collides (the server knows the ground, not what stands on
# it, so a wall the client stopped at the server would walk through).
#
# Usage: var b := LowPoly.new(); b.box(...); b.cone(...); var mesh := b.mesh()

const GLOW_SHADER := preload("res://assets/materials/glow.gdshader")

static var _solid_material: StandardMaterial3D
static var _glow_materials: Dictionary = {}

var _st := SurfaceTool.new()
var _count := 0
# Each solid's colour is nudged by up to this much, so a wall of boxes is not
# one flat tone. Seeded, so the scenery is the same on every client.
var _rng := RandomNumberGenerator.new()
var jitter := 0.06


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Smooth group -1: every triangle gets its own normal in generate_normals.
	_st.set_smooth_group(-1)


func is_empty() -> bool:
	return _count == 0


# The built mesh, with the shared opaque material (or a glowing one).
func mesh(glow_energy: float = 0.0) -> ArrayMesh:
	_st.generate_normals()
	var out := _st.commit()
	out.surface_set_material(0, glow_material(glow_energy) if glow_energy > 0.0 else solid_material())
	return out


# A MeshInstance3D holding the built mesh, seen out to `range_end` metres
# (0 for always).
func instance(node_name: String, range_end: float = 0.0, glow_energy: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh(glow_energy)
	mi.visibility_range_end = range_end
	if not shadows or glow_energy > 0.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func solid_material() -> StandardMaterial3D:
	if _solid_material == null:
		_solid_material = StandardMaterial3D.new()
		_solid_material.vertex_color_use_as_albedo = true
		# The colours in the scripts are the colours on screen (sRGB), not
		# linear light: without this every solid comes out pale.
		_solid_material.vertex_color_is_srgb = true
		_solid_material.roughness = 0.92
		_solid_material.metallic_specular = 0.15
		# Two-sided: a tent flap or a banner is one sheet, and no solid here
		# depends on which way its triangles were wound.
		_solid_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _solid_material


# An unlit material whose vertex colours are multiplied past white, so the
# world's glow picks them up: fire, the Wraith Gate's light, a lit window.
static func glow_material(energy: float) -> ShaderMaterial:
	var key := snappedf(energy, 0.1)
	if not _glow_materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = GLOW_SHADER
		m.set_shader_parameter("energy", key)
		_glow_materials[key] = m
	return _glow_materials[key]


func _shade(color: Color) -> Color:
	if jitter <= 0.0:
		return color
	var k := 1.0 + _rng.randf_range(-jitter, jitter)
	return Color(clampf(color.r * k, 0.0, 1.0), clampf(color.g * k, 0.0, 1.0), clampf(color.b * k, 0.0, 1.0), color.a)


func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_st.set_color(color)
	_st.add_vertex(a)
	_st.set_color(color)
	_st.add_vertex(b)
	_st.set_color(color)
	_st.add_vertex(c)
	_count += 1


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tri(a, b, c, color)
	tri(a, c, d, color)


# A box standing on its transform's origin: `size.x` by `size.z` on the
# ground, `size.y` tall. `top` colours its lid (a wall's walk, a table's top).
func box(xf: Transform3D, size: Vector3, color: Color, top: Variant = null) -> void:
	var c := _shade(color)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var p: Array[Vector3] = []
	for y in [0.0, size.y]:
		for corner in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
			p.append(xf * Vector3(corner.x, y, corner.y))
	for i in 4:
		var j := (i + 1) % 4
		# Each side a touch darker or lighter than its neighbour.
		quad(p[i], p[j], p[j + 4], p[i + 4], c.darkened(0.05 * (i % 2)))
	quad(p[4], p[5], p[6], p[7], _shade(top) if top != null else c.lightened(0.06))
	quad(p[3], p[2], p[1], p[0], c.darkened(0.2))


# A gabled roof on its transform's origin: `size.x` wide, `size.z` long, its
# ridge along z and `size.y` above the eaves.
func gable(xf: Transform3D, size: Vector3, color: Color, end_color: Variant = null) -> void:
	var c := _shade(color)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var a := xf * Vector3(-hx, 0, -hz)
	var b := xf * Vector3(hx, 0, -hz)
	var cc := xf * Vector3(hx, 0, hz)
	var d := xf * Vector3(-hx, 0, hz)
	var r0 := xf * Vector3(0, size.y, -hz)
	var r1 := xf * Vector3(0, size.y, hz)
	quad(a, r0, r1, d, c)
	quad(b, cc, r1, r0, c.darkened(0.1))
	var ends: Color = _shade(end_color) if end_color != null else c.darkened(0.15)
	tri(a, b, r0, ends)
	tri(cc, d, r1, ends)


# A column of `sides` sides standing on its transform's origin, `bottom` wide
# at its foot and `top` wide at its head (radii; 0 at the head makes a cone).
func column(xf: Transform3D, bottom: float, top: float, height: float, sides: int, color: Color, cap: Variant = null) -> void:
	var c := _shade(color)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := xf * Vector3(cos(a0) * bottom, 0, sin(a0) * bottom)
		var b1 := xf * Vector3(cos(a1) * bottom, 0, sin(a1) * bottom)
		var face := c.darkened(0.12 * absf(sin(a0 * 0.5 + 0.4)))
		if top <= 0.0:
			tri(b0, b1, xf * Vector3(0, height, 0), face)
		else:
			var t0 := xf * Vector3(cos(a0) * top, height, sin(a0) * top)
			var t1 := xf * Vector3(cos(a1) * top, height, sin(a1) * top)
			quad(b0, b1, t1, t0, face)
			tri(t0, t1, xf * Vector3(0, height, 0), _shade(cap) if cap != null else c.lightened(0.05))


func cone(xf: Transform3D, radius: float, height: float, sides: int, color: Color) -> void:
	column(xf, radius, 0.0, height, sides, color)


# A lumpy ball centred on its transform's origin: an icosahedron stretched to
# `radius` on each axis, every corner pushed in or out by up to `lump` of it.
# A boulder, a bush, a tree's crown.
func blob(xf: Transform3D, radius: Vector3, lump: float, color: Color, shade_by_height: float = 0.18) -> void:
	var c := _shade(color)
	var t := (1.0 + sqrt(5.0)) * 0.5
	var raw: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var pts: Array[Vector3] = []
	for v in raw:
		var n := v.normalized() * (1.0 + _rng.randf_range(-lump, lump))
		pts.append(xf * Vector3(n.x * radius.x, n.y * radius.y, n.z * radius.z))
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var up := xf.basis.y.normalized()
	for f in faces:
		var a := pts[f[0]]
		var b := pts[f[1]]
		var cc := pts[f[2]]
		# Faces that look up are lighter, faces that look down darker.
		var facing := (b - a).cross(cc - a).normalized().dot(up)
		tri(a, b, cc, c.lightened(shade_by_height * absf(facing)) if facing < 0.0 else c.darkened(shade_by_height * facing))


# A flat sheet between four corners (a banner, a tent flap, a web).
func sheet(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	quad(a, b, c, d, _shade(color))


# --- Transforms ----------------------------------------------------------

# A transform at `pos`, turned `yaw` radians about up.
static func at(pos: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


# A transform at `pos` whose up leans `tilt` radians towards the heading `yaw`.
static func leaning(pos: Vector3, yaw: float, tilt: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt), pos)
