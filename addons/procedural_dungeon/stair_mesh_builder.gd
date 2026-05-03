class_name StairMeshBuilder
extends RefCounted

# Builds a ramp MeshInstance3D spanning from lower_y to lower_y + room_height
# over the stair shaft's XZ footprint.  The ramp travels in the +Z (shaft_gy)
# direction.  CULL_DISABLED so it's visible from both above and below.
static func build(stair: StairData, lower_y: float, room_height: float) -> Node3D:
	var root = Node3D.new()
	root.name = "Staircase_%d_%d" % [stair.from_floor, stair.to_floor]

	var cs = stair.cell_size
	var sw = stair.shaft_w * cs  # world width  (X)
	var sd = stair.shaft_d * cs  # world depth  (Z, direction of ascent)

	var ox = stair.shaft_gx * cs
	var oz = stair.shaft_gy * cs

	# Ramp surface corners
	var v0 = Vector3(ox,      lower_y,             oz)       # bottom-near-left
	var v1 = Vector3(ox + sw, lower_y,             oz)       # bottom-near-right
	var v2 = Vector3(ox + sw, lower_y + room_height, oz + sd) # top-far-right
	var v3 = Vector3(ox,      lower_y + room_height, oz + sd) # top-far-left

	# Surface normal perpendicular to slope, pointing "outward" (up-ish)
	var ramp_normal = Vector3(0.0, sd, -room_height).normalized()
	var tex_scale   = 4.0  # world units per UV tile, matching DungeonMeshBuilder

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# UVs tiled along ramp surface: U across width (X), V along slope length
	var slope_len = Vector2(0.0, room_height).length() + sd  # approximate arc length
	var uvs = [
		Vector2(ox / tex_scale,          0.0),
		Vector2((ox + sw) / tex_scale,   0.0),
		Vector2((ox + sw) / tex_scale,   slope_len / tex_scale),
		Vector2(ox / tex_scale,          slope_len / tex_scale),
	]
	var tris = [[0, 1, 2], [0, 2, 3]]
	for tri in tris:
		for i in tri:
			st.set_normal(ramp_normal)
			st.set_uv(uvs[i])
			st.add_vertex([v0, v1, v2, v3][i])

	var mi      = MeshInstance3D.new()
	mi.name     = "Ramp"
	st.generate_tangents()
	mi.mesh     = st.commit()

	var mat               = StandardMaterial3D.new()
	mat.albedo_color      = Color(0.40, 0.36, 0.30)
	mat.cull_mode         = BaseMaterial3D.CULL_DISABLED
	mi.material_override  = mat
	mi.create_trimesh_collision()

	root.add_child(mi)
	return root
