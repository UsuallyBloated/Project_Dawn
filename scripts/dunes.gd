extends Node3D

const TERRAIN_SIZE := 800
const RESOLUTION := 120
const DUNE_HEIGHT := 14.0

func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.88, 0.62, 1)
	mat.roughness = 0.9

	var half := TERRAIN_SIZE / 2.0
	var step := float(TERRAIN_SIZE) / RESOLUTION

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(RESOLUTION + 1):
		for x in range(RESOLUTION + 1):
			var wx := -half + x * step
			var wz := -half + z * step
			# Fade dunes in beyond 30 units from spawn so the player never spawns inside terrain
			var dist := Vector2(wx, wz).length()
			var fade := clampf((dist - 30.0) / 30.0, 0.0, 1.0)
			var h := maxf(0.0, noise.get_noise_2d(wx, wz)) * DUNE_HEIGHT * fade
			st.set_uv(Vector2(wx, wz) * 0.05)
			st.add_vertex(Vector3(wx, h, wz))

	for z in range(RESOLUTION):
		for x in range(RESOLUTION):
			var i := z * (RESOLUTION + 1) + x
			st.add_index(i)
			st.add_index(i + RESOLUTION + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + RESOLUTION + 1)
			st.add_index(i + RESOLUTION + 2)

	st.generate_normals()
	var mesh_data := st.commit()
	mesh_data.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh_data
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	col.shape = mesh_data.create_trimesh_shape()
	body.add_child(col)
