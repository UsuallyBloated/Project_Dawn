class_name ZoneObstacleOutlines
extends MeshInstance3D

# A dev view of the zone's obstacle data (zone_obstacles.gd): every prism near
# the camera drawn as a wire outline over the scenery it was baked from, so a
# boundary that does not sit on its tree, rock or wall is seen at a glance.
#   red   stands in a body's way (and may block sight too)
#   blue  blocks a line of sight only (a crown, a roof, a lintel)
# Each is drawn from its base to its top; for walking a red one is a column of
# any height. Toggled from the Test Panel; draws nothing a player needs.

const NODE_NAME := "ObstacleOutlines"
# How far from the camera prisms are drawn, and how often the list is redrawn.
const REACH := 70.0
const REFRESH_SECS := 0.5
const WALK_COLOR := Color(1.0, 0.25, 0.2)
const SIGHT_COLOR := Color(0.3, 0.7, 1.0)

var _obstacles: ZoneObstacles
var _lines := ImmediateMesh.new()
var _since := REFRESH_SECS


# Shows the outlines under `world`, or removes them if they are showing.
# Returns whether they are showing now.
static func toggle(world: Node) -> bool:
	var existing := world.get_node_or_null(NODE_NAME)
	if existing != null:
		existing.queue_free()
		return false
	var view := ZoneObstacleOutlines.new()
	view.name = NODE_NAME
	world.add_child(view)
	return true


func _ready() -> void:
	_obstacles = ZoneObstacles.shared()
	mesh = _lines
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	# Drawn over everything: an outline inside a wall is still an outline.
	mat.no_depth_test = true
	material_override = mat


func _process(delta: float) -> void:
	_since += delta
	if _since < REFRESH_SECS or _obstacles == null:
		return
	_since = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_redraw(camera.global_position)


func _redraw(centre: Vector3) -> void:
	_lines.clear_surfaces()
	var near := _obstacles.prisms_near(centre.x - REACH, centre.z - REACH, centre.x + REACH, centre.z + REACH)
	if near.is_empty():
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in near:
		var color := WALK_COLOR if _obstacles.flags_of(i) & ZoneObstacles.FLAG_WALK else SIGHT_COLOR
		var corners := _obstacles.corners_of(i)
		var base := _obstacles.base_of(i)
		var top := _obstacles.top_of(i)
		for k in corners.size():
			var a := corners[k]
			var b := corners[(k + 1) % corners.size()]
			_line(Vector3(a.x, base, a.y), Vector3(b.x, base, b.y), color)
			_line(Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), color)
			_line(Vector3(a.x, base, a.y), Vector3(a.x, top, a.y), color)
	_lines.surface_end()


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(to_local(a))
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(to_local(b))
