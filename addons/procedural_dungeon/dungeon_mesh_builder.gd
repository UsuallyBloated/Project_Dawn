class_name DungeonMeshBuilder
extends RefCounted

# Texture tiling scale — 1 unit of UV per this many world units
const TEX_SCALE = 4.0

# Builds a Node3D containing three MeshInstance3D children:
#   "Floors"   — floor geometry
#   "Ceilings" — ceiling geometry
#   "Walls"    — wall geometry
# Separate nodes so you can assign different materials in Godot.
static func build(layout: DungeonLayout, y_offset: float = 0.0) -> Node3D:
	var root = Node3D.new()
	root.name = "DungeonMesh"

	var floor_st   = SurfaceTool.new()
	var ceiling_st = SurfaceTool.new()
	var wall_st    = SurfaceTool.new()

	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ceiling_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cs = layout.cell_size
	var h  = layout.room_height
	var y0 = y_offset        # floor surface Y
	var y1 = y_offset + h    # ceiling surface Y

	for cy in layout.grid_height:
		for cx in layout.grid_width:
			var cell = layout.get_cell(cx, cy)
			if not layout.is_passable(cx, cy):
				continue

			var wx = cx * cs
			var wz = cy * cs

			var is_stair_bottom = cell == DungeonLayout.CELL_STAIR_BOTTOM
			var is_stair_top    = cell == DungeonLayout.CELL_STAIR_TOP

			# Floor — omit for CELL_STAIR_TOP (hole in floor above shaft)
			if not is_stair_top:
				_quad(floor_st,
					Vector3(wx,      y0, wz),
					Vector3(wx,      y0, wz + cs),
					Vector3(wx + cs, y0, wz + cs),
					Vector3(wx + cs, y0, wz),
					Vector3.UP, wx, wz, cs, cs, false)

			# Ceiling — omit for CELL_STAIR_BOTTOM (shaft open to floor above)
			if not is_stair_bottom:
				_quad(ceiling_st,
					Vector3(wx,      y1, wz + cs),
					Vector3(wx,      y1, wz),
					Vector3(wx + cs, y1, wz),
					Vector3(wx + cs, y1, wz + cs),
					Vector3.DOWN, wx, wz, cs, cs, false)

			# North wall (z-)
			if not layout.is_passable(cx, cy - 1):
				_quad(wall_st,
					Vector3(wx,      y0, wz),
					Vector3(wx + cs, y0, wz),
					Vector3(wx + cs, y1, wz),
					Vector3(wx,      y1, wz),
					Vector3(0, 0, 1), wx, y0, cs, h, true)

			# South wall (z+)
			if not layout.is_passable(cx, cy + 1):
				_quad(wall_st,
					Vector3(wx + cs, y0, wz + cs),
					Vector3(wx,      y0, wz + cs),
					Vector3(wx,      y1, wz + cs),
					Vector3(wx + cs, y1, wz + cs),
					Vector3(0, 0, -1), wx, y0, cs, h, true)

			# East wall (x+)
			if not layout.is_passable(cx + 1, cy):
				_quad(wall_st,
					Vector3(wx + cs, y0, wz + cs),
					Vector3(wx + cs, y0, wz),
					Vector3(wx + cs, y1, wz),
					Vector3(wx + cs, y1, wz + cs),
					Vector3(-1, 0, 0), wz, y0, cs, h, true)

			# West wall (x-)
			if not layout.is_passable(cx - 1, cy):
				_quad(wall_st,
					Vector3(wx, y0, wz),
					Vector3(wx, y0, wz + cs),
					Vector3(wx, y1, wz + cs),
					Vector3(wx, y1, wz),
					Vector3(1, 0, 0), wz, y0, cs, h, true)

	root.add_child(_make_mesh_instance(floor_st,   "Floors"))
	root.add_child(_make_mesh_instance(ceiling_st, "Ceilings"))
	root.add_child(_make_mesh_instance(wall_st,    "Walls"))

	return root


# Emits two triangles for a quad. v0→v1→v2→v3 in CCW order when viewed
# from the normal direction.
# u_origin/v_origin: world-space anchor for UV tiling.
# u_size/v_size:     extent of this quad in world units.
# is_wall:           true → UV along the span axis rather than XZ plane.
static func _quad(
		st: SurfaceTool,
		v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
		normal: Vector3,
		u_origin: float, v_origin: float,
		u_size: float, v_size: float,
		is_wall: bool) -> void:

	var verts = [v0, v1, v2, v3]
	var uvs   = [
		Vector2(u_origin / TEX_SCALE,            v_origin / TEX_SCALE),
		Vector2((u_origin + u_size) / TEX_SCALE, v_origin / TEX_SCALE),
		Vector2((u_origin + u_size) / TEX_SCALE, (v_origin + v_size) / TEX_SCALE),
		Vector2(u_origin / TEX_SCALE,            (v_origin + v_size) / TEX_SCALE),
	]

	# Floors/ceilings need reversed winding to face inward; walls use original.
	var tris = [[0, 2, 1], [0, 3, 2]] if not is_wall else [[0, 1, 2], [0, 2, 3]]
	for tri in tris:
		for i in tri:
			st.set_normal(normal)
			st.set_uv(uvs[i])
			st.add_vertex(verts[i])


static func _make_mesh_instance(st: SurfaceTool, node_name: String) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = node_name
	# generate_tangents requires normals already set and UVs present
	st.generate_tangents()
	mi.mesh = st.commit()
	# Assign a default grey material so it's visible without a texture
	var mat = StandardMaterial3D.new()
	match node_name:
		"Floors":
			mat.albedo_color = Color(0.35, 0.32, 0.28)
		"Ceilings":
			mat.albedo_color = Color(0.22, 0.20, 0.18)
		"Walls":
			mat.albedo_color = Color(0.45, 0.40, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.create_trimesh_collision()
	return mi
