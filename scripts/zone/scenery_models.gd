class_name SceneryModels
extends RefCounted

# The scenery models made in Blender (tools/blender/, exported by
# export_scenery.py): one mesh and one list of solids per variant of a kind,
# in assets/models/scenery/<model>/<model>_<n>.glb and .solids.json. ZoneFlora
# draws the meshes; the obstacle bake reads the solids. Each is loaded once and
# kept.
#
# A model's mesh is drawn with LowPoly's shared material (set on the drawing
# node), so its vertex colours read as the placeholder palette and a planted
# thing's tint still applies.

const ROOT := "res://assets/models/scenery"

static var _meshes: Dictionary = {}
static var _volumes: Dictionary = {}
static var _bounds: Dictionary = {}


static func path(model: String, variant: int, extension: String) -> String:
	return "%s/%s/%s_%d%s" % [ROOT, model, model, variant, extension]


# The variant's mesh, or null (with an error) when its .glb is missing.
static func mesh(model: String, variant: int) -> Mesh:
	var key := "%s_%d" % [model, variant]
	if not _meshes.has(key):
		_meshes[key] = _load_mesh(path(model, variant, ".glb"))
	return _meshes[key]


static func _load_mesh(glb: String) -> Mesh:
	var packed := load(glb) as PackedScene
	if packed == null:
		push_error("SceneryModels: cannot load %s" % glb)
		return null
	var root := packed.instantiate()
	var found: Mesh = null
	var stack: Array[Node] = [root]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			found = (n as MeshInstance3D).mesh
		stack.append_array(n.get_children())
	root.free()
	if found == null:
		push_error("SceneryModels: %s holds no mesh" % glb)
	return found


# The variant's solids as LowPoly.volumes() gives them: one entry per piece,
# [its corners (PackedVector3Array, in the model's own space), its sight scale].
static func volumes(model: String, variant: int) -> Array:
	var key := "%s_%d" % [model, variant]
	if not _volumes.has(key):
		_volumes[key] = _load_volumes(path(model, variant, ".solids.json"))
	return _volumes[key]


static func _load_volumes(file: String) -> Array:
	var text := FileAccess.get_file_as_string(file)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary) or not (data as Dictionary).has("solids"):
		push_error("SceneryModels: cannot read %s" % file)
		return []
	var out: Array = []
	for solid in data["solids"]:
		var corners := PackedVector3Array()
		for c in solid["corners"]:
			corners.append(Vector3(c[0], c[1], c[2]))
		out.append([corners, float(solid["sight_scale"])])
	return out


# The box round the variant's mesh at and above `from_height` (metres, in the
# model's own space): a tree's crown, for the far stand-in drawn in its place.
# The whole mesh when nothing reaches that high.
static func bounds_above(model: String, variant: int, from_height: float) -> AABB:
	var key := "%s_%d_%s" % [model, variant, from_height]
	if not _bounds.has(key):
		var m := mesh(model, variant)
		var box := AABB()
		var started := false
		if m != null:
			for s in m.get_surface_count():
				for v in m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					if v.y < from_height:
						continue
					if started:
						box = box.expand(v)
					else:
						box = AABB(v, Vector3.ZERO)
						started = true
		_bounds[key] = box if started else (m.get_aabb() if m != null else AABB())
	return _bounds[key]
