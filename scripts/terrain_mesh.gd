@tool
extends Node3D
class_name TerrainMesh

# The zone's ground: a grid of heights (authored from data/terrain_features.toml
# by tools/author_terrain.gd) built into meshes and trimesh colliders at load,
# in the editor and at runtime. The scene stores the heights alone; the ground
# is built from them in chunks of CHUNK_CELLS cells a side, so a 4 km zone is a
# hundred small meshes and colliders the engine can cull, never one mesh baked
# into the scene file (at 4 km that was 55 MB of text). The server samples the
# same triangles from the terrain.toml tools/export_terrain.gd writes, so the
# triangle order here is part of the contract (tools/check_terrain_lockstep.gd
# builds this node and holds its colliders to the heights).

# A chunk is this many cells a side (the last row and column take what is left).
const CHUNK_CELLS := 40
# Physics layers 1 (bodies, so everything stands on it) and 2 (terrain, which
# the sight check's ray asks for alone: Spells._target_out_of_sight).
const COLLISION_LAYERS := 3
const TERRAIN_SHADER := preload("res://assets/materials/terrain.gdshader")
const VISUAL_NODE := "TerrainVisual"
const BODY_NODE := "TerrainBody"
# The detail noise the shader mottles the ground with: a small seamless tile.
const DETAIL_NOISE_SIZE := 256
const DETAIL_NOISE_SEED := 847

@export var grid_size: int = 20:
	set(v):
		grid_size = v
		if heights.size() != (grid_size + 1) * (grid_size + 1):
			_init_heights()
		_rebuild_if_built()

@export var cell_size: float = 20.0:
	set(v):
		cell_size = v
		_rebuild_if_built()

@export var heights: PackedFloat32Array = PackedFloat32Array()

# The zone's ground paint (roads, farms, forest floor), laid over the whole
# plate by the shader. Written by tools/author_terrain.gd; none is fine.
@export var paint: Texture2D:
	set(v):
		paint = v
		_apply_paint()

var _visual: Node3D
var _body: StaticBody3D
var _material: ShaderMaterial
var _built := false
# The index list for a chunk of a given size, built once per size.
var _index_cache: Dictionary = {}


func _ready() -> void:
	rebuild()


# Builds every chunk from the heights. Safe to call outside the tree (the
# tools do): the children are plain nodes under this one.
func rebuild() -> void:
	if heights.size() != (grid_size + 1) * (grid_size + 1):
		_init_heights()
	_ensure_children()
	for child in _visual.get_children():
		_visual.remove_child(child)
		child.free()
	for child in _body.get_children():
		_body.remove_child(child)
		child.free()
	var chunks := chunk_count()
	for cz in chunks:
		for cx in chunks:
			_build_chunk(cx, cz)
	_built = true


func _rebuild_if_built() -> void:
	if _built:
		rebuild()


func chunk_count() -> int:
	return int(ceil(float(grid_size) / CHUNK_CELLS))


func _ensure_children() -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = TERRAIN_SHADER
		_material.set_shader_parameter("detail_noise", _detail_noise())
		_apply_paint()
	_material.set_shader_parameter("zone_size", grid_size * cell_size)
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = VISUAL_NODE
		add_child(_visual)
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = BODY_NODE
		_body.collision_layer = COLLISION_LAYERS
		add_child(_body)


func _apply_paint() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("paint", paint)
	_material.set_shader_parameter("paint_strength", 1.0 if paint != null else 0.0)


static func _detail_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = DETAIL_NOISE_SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = DETAIL_NOISE_SIZE
	tex.height = DETAIL_NOISE_SIZE
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex


func _init_heights() -> void:
	heights = PackedFloat32Array()
	heights.resize((grid_size + 1) * (grid_size + 1))


func get_height(x: int, z: int) -> float:
	if heights.is_empty():
		return 0.0
	var i := z * (grid_size + 1) + x
	if i < 0 or i >= heights.size():
		return 0.0
	return heights[i]


func set_height(x: int, z: int, h: float) -> void:
	if heights.is_empty():
		heights.resize((grid_size + 1) * (grid_size + 1))
	var i := z * (grid_size + 1) + x
	if i >= 0 and i < heights.size():
		heights[i] = h
		_rebuild_if_built()


func get_vertex_world_pos(x: int, z: int) -> Vector3:
	var half := grid_size * cell_size * 0.5
	return global_position + Vector3(-half + x * cell_size, get_height(x, z), -half + z * cell_size)


# The ground's height at a point local to this node: the plane of the triangle
# the point is in (each cell split from (x1, z0) to (x0, z1), as the collider
# and the server's world/terrain.rs::ground have it), never under 0, and 0 past
# the grid's edge. What the zone's dressing stands its trees and stones on.
func height_at(x: float, z: float) -> float:
	var extent := grid_size * cell_size
	var lx := x + extent * 0.5
	var lz := z + extent * 0.5
	if not (lx >= 0.0 and lx <= extent and lz >= 0.0 and lz <= extent):
		return 0.0
	var fx := lx / cell_size
	var fz := lz / cell_size
	var cx := mini(int(fx), grid_size - 1)
	var cz := mini(int(fz), grid_size - 1)
	var u := fx - cx
	var v := fz - cz
	var row := grid_size + 1
	var i := cz * row + cx
	var h: float
	if u + v <= 1.0:
		var h00 := heights[i]
		h = h00 + u * (heights[i + 1] - h00) + v * (heights[i + row] - h00)
	else:
		var h11 := heights[i + row + 1]
		h = h11 + (1.0 - u) * (heights[i + row] - h11) + (1.0 - v) * (heights[i + 1] - h11)
	return maxf(h, 0.0)


# How steep the ground is at a point local to this node, as rise over run (the
# tangent of its angle): the slope of the triangle the point is in, 0 past the
# grid's edge. The scatter keeps trees off anything near a face.
func slope_at(x: float, z: float) -> float:
	var extent := grid_size * cell_size
	var lx := x + extent * 0.5
	var lz := z + extent * 0.5
	if not (lx >= 0.0 and lx <= extent and lz >= 0.0 and lz <= extent):
		return 0.0
	var fx := lx / cell_size
	var fz := lz / cell_size
	var cx := mini(int(fx), grid_size - 1)
	var cz := mini(int(fz), grid_size - 1)
	var row := grid_size + 1
	var i := cz * row + cx
	var d: Vector2
	if (fx - cx) + (fz - cz) <= 1.0:
		d = Vector2(heights[i + 1] - heights[i], heights[i + row] - heights[i])
	else:
		d = Vector2(heights[i + row + 1] - heights[i + row], heights[i + row + 1] - heights[i + 1])
	return d.length() / cell_size


# Every collider triangle, three corners each, local to this node: what the
# lockstep and sight checks hold to the heights and to the server's rule.
func collider_faces() -> PackedVector3Array:
	var out := PackedVector3Array()
	if _body == null:
		return out
	for child in _body.get_children():
		var shape := (child as CollisionShape3D).shape as ConcavePolygonShape3D
		if shape != null:
			out.append_array(shape.get_faces())
	return out


# One chunk: the cells from (cx, cz) * CHUNK_CELLS, as a mesh that shares its
# vertices and a collider of the same triangles in the same order.
func _build_chunk(cx: int, cz: int) -> void:
	var x0 := cx * CHUNK_CELLS
	var z0 := cz * CHUNK_CELLS
	var nx := mini(CHUNK_CELLS, grid_size - x0)
	var nz := mini(CHUNK_CELLS, grid_size - z0)
	if nx <= 0 or nz <= 0:
		return
	var half := grid_size * cell_size * 0.5
	var row := grid_size + 1
	var last := grid_size

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize((nx + 1) * (nz + 1))
	normals.resize(verts.size())
	var i := 0
	for z in range(z0, z0 + nz + 1):
		var wz := -half + z * cell_size
		var base := z * row
		var zn := maxi(z - 1, 0) * row
		var zp := mini(z + 1, last) * row
		for x in range(x0, x0 + nx + 1):
			verts[i] = Vector3(-half + x * cell_size, heights[base + x], wz)
			# A smooth normal from the neighbours' heights: the shadow pass's
			# bias wants one; the lit colour uses the shader's flat normal.
			normals[i] = Vector3(
				heights[base + maxi(x - 1, 0)] - heights[base + mini(x + 1, last)],
				2.0 * cell_size,
				heights[zn + x] - heights[zp + x]).normalized()
			i += 1

	var indices := _chunk_indices(nx, nz)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	var instance := MeshInstance3D.new()
	instance.name = "Chunk_%d_%d" % [cx, cz]
	instance.mesh = mesh
	_visual.add_child(instance)

	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for k in indices.size():
		faces[k] = verts[indices[k]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.name = "Col_%d_%d" % [cx, cz]
	col.shape = shape
	_body.add_child(col)


# The triangles of an nx by nz chunk as indices into its (nx + 1) by (nz + 1)
# vertices. Each cell is two triangles, split from (x+1, z) to (x, z+1): the
# corners (x, z), (x+1, z), (x, z+1) then (x+1, z), (x+1, z+1), (x, z+1). The
# corner order is the winding: clockwise seen from above, which is Godot's
# front face, so the top is drawn and a body stands on it. The other order
# faces every triangle down: the ground is culled from above and a one-sided
# collider lets a body sink into it (tools/check_terrain_lockstep.gd and
# tools/probe_terrain_stand.gd).
func _chunk_indices(nx: int, nz: int) -> PackedInt32Array:
	var key := Vector2i(nx, nz)
	if _index_cache.has(key):
		return _index_cache[key]
	var indices := PackedInt32Array()
	indices.resize(nx * nz * 6)
	var k := 0
	var row := nx + 1
	for z in nz:
		for x in nx:
			var i := z * row + x
			indices[k] = i
			indices[k + 1] = i + 1
			indices[k + 2] = i + row
			indices[k + 3] = i + 1
			indices[k + 4] = i + row + 1
			indices[k + 5] = i + row
			k += 6
	_index_cache[key] = indices
	return indices
