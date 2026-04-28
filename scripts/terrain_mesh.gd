@tool
extends Node3D
class_name TerrainMesh

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
	mat.albedo_color = Color(0.22, 0.42, 0.12, 1)
	mat.roughness = 0.9

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := grid_size * cell_size * 0.5

	for z in range(grid_size + 1):
		for x in range(grid_size + 1):
			var wx := -half + x * cell_size
			var wz := -half + z * cell_size
			st.set_uv(Vector2(wx, wz) * 0.02)
			st.add_vertex(Vector3(wx, get_height(x, z), wz))

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
