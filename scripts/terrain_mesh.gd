@tool
extends Node3D
class_name TerrainMesh

# The zone's ground: a grid of heights (authored from data/terrain_features.toml
# by tools/author_terrain.gd) built into a mesh and a trimesh collider, in the
# editor and at runtime. The server samples the same triangles from the
# terrain.toml tools/export_terrain.gd writes, so the triangle order here is
# part of the contract (tools/check_terrain_lockstep.gd holds the collider to it).

# The height tint: the low ground's green to the high ground's grey-brown, over
# TINT_TOP metres. Knobs.
const LOW_COLOR := Color(0.22, 0.42, 0.12, 1)
const HIGH_COLOR := Color(0.45, 0.40, 0.32, 1)
const TINT_TOP := 30.0
# Physics layers 1 (bodies, so everything stands on it) and 2 (terrain, which
# the sight check's ray asks for alone: Spells._target_out_of_sight).
const COLLISION_LAYERS := 3

@export var grid_size: int = 20:
	set(v):
		grid_size = v
		if heights.size() != (grid_size + 1) * (grid_size + 1):
			_init_heights()
		_rebuild()

@export var cell_size: float = 20.0:
	set(v):
		cell_size = v
		_rebuild()

@export var heights: PackedFloat32Array = PackedFloat32Array()

# Flat shading: every triangle its own face normal (the low-poly look), in
# place of normals smoothed across shared vertices.
@export var flat_shaded: bool = true:
	set(v):
		flat_shaded = v
		_rebuild()

# Colour each vertex by its height (see LOW_COLOR / HIGH_COLOR).
@export var height_tint: bool = true:
	set(v):
		height_tint = v
		_rebuild()

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _col_shape: CollisionShape3D


func _ready() -> void:
	_ensure_children()
	if heights.size() != (grid_size + 1) * (grid_size + 1):
		_init_heights()
	_rebuild()


func _ensure_children() -> void:
	if has_node("TerrainVisual"):
		_mesh_instance = get_node("TerrainVisual")
	else:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "TerrainVisual"
		add_child(_mesh_instance)
		if Engine.is_editor_hint():
			_mesh_instance.owner = get_tree().edited_scene_root

	if has_node("TerrainBody"):
		_body = get_node("TerrainBody")
		_col_shape = _body.get_node("TerrainCol")
	else:
		_body = StaticBody3D.new()
		_body.name = "TerrainBody"
		_body.collision_layer = COLLISION_LAYERS
		add_child(_body)
		if Engine.is_editor_hint():
			_body.owner = get_tree().edited_scene_root
		_col_shape = CollisionShape3D.new()
		_col_shape.name = "TerrainCol"
		_body.add_child(_col_shape)
		if Engine.is_editor_hint():
			_col_shape.owner = get_tree().edited_scene_root


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
		_rebuild()


func get_vertex_world_pos(x: int, z: int) -> Vector3:
	var half := grid_size * cell_size * 0.5
	return global_position + Vector3(-half + x * cell_size, get_height(x, z), -half + z * cell_size)


func _rebuild() -> void:
	if _mesh_instance == null:
		return

	var mat := StandardMaterial3D.new()
	if height_tint:
		mat.vertex_color_use_as_albedo = true
	else:
		mat.albedo_color = LOW_COLOR
	mat.roughness = 0.9

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Smooth group -1 gives each triangle its own normal in generate_normals.
	st.set_smooth_group(-1 if flat_shaded else 0)

	# Each cell is two triangles, split from (x+1, z) to (x, z+1): the corners
	# (x, z), (x, z+1), (x+1, z) then (x+1, z), (x, z+1), (x+1, z+1). Shared
	# vertices with indices when smooth, three of its own per triangle when
	# flat; the collider gets the same triangles in the same order either way.
	if flat_shaded:
		for z in range(grid_size):
			for x in range(grid_size):
				for c in [Vector2i(x, z), Vector2i(x, z + 1), Vector2i(x + 1, z),
						Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1)]:
					_add_corner(st, c.x, c.y)
	else:
		for z in range(grid_size + 1):
			for x in range(grid_size + 1):
				_add_corner(st, x, z)
		for z in range(grid_size):
			for x in range(grid_size):
				var i := z * (grid_size + 1) + x
				st.add_index(i)
				st.add_index(i + grid_size + 1)
				st.add_index(i + 1)
				st.add_index(i + 1)
				st.add_index(i + grid_size + 1)
				st.add_index(i + grid_size + 2)

	st.generate_normals()
	var mesh_data := st.commit()
	mesh_data.surface_set_material(0, mat)
	_mesh_instance.mesh = mesh_data
	if _col_shape != null:
		_col_shape.shape = mesh_data.create_trimesh_shape()


func _add_corner(st: SurfaceTool, x: int, z: int) -> void:
	var half := grid_size * cell_size * 0.5
	var wx := -half + x * cell_size
	var wz := -half + z * cell_size
	var h := get_height(x, z)
	st.set_uv(Vector2(wx, wz) * 0.02)
	if height_tint:
		st.set_color(LOW_COLOR.lerp(HIGH_COLOR, clampf(h / TINT_TOP, 0.0, 1.0)))
	st.add_vertex(Vector3(wx, h, wz))
