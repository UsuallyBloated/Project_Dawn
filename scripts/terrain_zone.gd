class_name TerrainZone
extends Node3D

@export_group("Grid")
@export var grid_w: int = 64
@export var grid_d: int = 64
@export var cell_sz: float = 2.0

@export_group("Sculpt")
@export var brush_radius: float = 6.0
@export var drag_sensitivity: float = 0.05

const PICK_PX := 24.0

var _heights := PackedFloat32Array()
var _mesh_inst: MeshInstance3D
var _body: StaticBody3D
var _col: CollisionShape3D
var _handles: MultiMeshInstance3D

var _edit_mode := false
var _drag_vtx := -1


func _ready() -> void:
	_build_nodes()
	_heights.resize((grid_w + 1) * (grid_d + 1))
	_heights.fill(0.0)
	_build_handles()
	_rebuild_mesh(true)


func _build_nodes() -> void:
	_mesh_inst = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.55, 0.25)
	mat.roughness = 0.9
	_mesh_inst.material_override = mat
	add_child(_mesh_inst)

	_body = StaticBody3D.new()
	add_child(_body)
	_col = CollisionShape3D.new()
	_body.add_child(_col)

	_handles = MultiMeshInstance3D.new()
	_handles.visible = false
	add_child(_handles)


func _vi(x: int, z: int) -> int:
	return z * (grid_w + 1) + x


func _lpos(x: int, z: int) -> Vector3:
	return Vector3(
		x * cell_sz - grid_w * cell_sz * 0.5,
		_heights[_vi(x, z)],
		z * cell_sz - grid_d * cell_sz * 0.5
	)


func _build_handles() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.radial_segments = 6
	sm.rings = 3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.YELLOW
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = (grid_w + 1) * (grid_d + 1)

	_handles.multimesh = mm
	_handles.material_override = mat
	_sync_handles()


func _sync_handles() -> void:
	if not _handles.multimesh:
		return
	for z in range(grid_d + 1):
		for x in range(grid_w + 1):
			var idx := _vi(x, z)
			_handles.multimesh.set_instance_transform(idx, Transform3D(Basis(), _lpos(x, z)))


func _rebuild_mesh(update_col: bool = false) -> void:
	var hw := grid_w * cell_sz * 0.5
	var hd := grid_d * cell_sz * 0.5
	var count := (grid_w + 1) * (grid_d + 1)

	var verts := PackedVector3Array()
	verts.resize(count)
	var uvs := PackedVector2Array()
	uvs.resize(count)
	var indices := PackedInt32Array()
	indices.resize(grid_w * grid_d * 6)

	for z in range(grid_d + 1):
		for x in range(grid_w + 1):
			var i := _vi(x, z)
			verts[i] = Vector3(x * cell_sz - hw, _heights[i], z * cell_sz - hd)
			uvs[i] = Vector2(float(x) / grid_w, float(z) / grid_d)

	var ti := 0
	for z in range(grid_d):
		for x in range(grid_w):
			var a := _vi(x, z)
			var b := _vi(x, z + 1)
			var c := _vi(x + 1, z)
			var d := _vi(x + 1, z + 1)
			indices[ti] = a;     ti += 1
			indices[ti] = b;     ti += 1
			indices[ti] = c;     ti += 1
			indices[ti] = c;     ti += 1
			indices[ti] = b;     ti += 1
			indices[ti] = d;     ti += 1

	var norms := _calc_normals(verts, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var amesh := ArrayMesh.new()
	amesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_inst.mesh = amesh

	if update_col:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(amesh.get_faces())
		_col.shape = shape


func _calc_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(verts.size())
	n.fill(Vector3.ZERO)
	for i in range(0, indices.size(), 3):
		var fn := (verts[indices[i + 1]] - verts[indices[i]]).cross(
				   verts[indices[i + 2]] - verts[indices[i]])
		n[indices[i]]     += fn
		n[indices[i + 1]] += fn
		n[indices[i + 2]] += fn
	for i in range(n.size()):
		n[i] = n[i].normalized() if n[i].length_squared() > 0.0 else Vector3.UP
	return n


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4:
			_edit_mode = !_edit_mode
			_handles.visible = _edit_mode
			get_viewport().set_input_as_handled()
			return

	if not _edit_mode:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pick_vertex(event.position)
		else:
			if _drag_vtx >= 0:
				_rebuild_mesh(true)
			_drag_vtx = -1
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _drag_vtx >= 0:
		_do_drag(-event.relative.y * drag_sensitivity)
		get_viewport().set_input_as_handled()


func _pick_vertex(mouse_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	_drag_vtx = -1
	var best := PICK_PX
	for z in range(grid_d + 1):
		for x in range(grid_w + 1):
			var wp := global_position + _lpos(x, z)
			if cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var d := sp.distance_to(mouse_pos)
			if d < best:
				best = d
				_drag_vtx = _vi(x, z)


func _do_drag(dh: float) -> void:
	var sel_x := _drag_vtx % (grid_w + 1)
	var sel_z := _drag_vtx / (grid_w + 1)
	var sel_flat := Vector2(sel_x * cell_sz, sel_z * cell_sz)

	for z in range(grid_d + 1):
		for x in range(grid_w + 1):
			var dist := sel_flat.distance_to(Vector2(x * cell_sz, z * cell_sz))
			if dist > brush_radius:
				continue
			var w := 1.0 - smoothstep(0.0, brush_radius, dist)
			_heights[_vi(x, z)] += dh * w

	_rebuild_mesh(false)
	_sync_handles()


func save_heights(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return
	f.store_32(grid_w)
	f.store_32(grid_d)
	for h in _heights:
		f.store_float(h)


func load_heights(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	if f.get_32() != grid_w or f.get_32() != grid_d:
		push_warning("TerrainZone: grid size mismatch")
		return
	for i in range(_heights.size()):
		_heights[i] = f.get_float()
	_rebuild_mesh(true)
	_sync_handles()
