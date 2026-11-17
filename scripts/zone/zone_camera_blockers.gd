class_name ZoneCameraBlockers
extends StaticBody3D

# What the camera stops at: the zone's big solids (walls, towers, houses,
# tents, great rocks) as real shapes with their real tops, so the chase
# camera is pulled in front of a house instead of looking through it. Built
# once from the zone's obstacle data (zone_obstacles.gd) when a player enters
# the world.
#
# This is the one place the scenery becomes physics bodies, and they are on a
# layer of their own that only the camera's spring arm reads. The player's
# body does not read it: what stops a body is the obstacle rule the server
# runs too, never a physics shape (invariant L2;
# tools/check_obstacle_lockstep.gd holds the masks apart). Click rays do not
# read it either, so targeting is what it was. Trees are left out: a camera
# that jumped in at every trunk would be unusable in a wood.

const NODE_NAME := "CameraBlockers"
# Physics layer 5 ("camera_blockers" in project.godot), as a bit.
const LAYER := 16
# A solid blocks the camera when it is at least this big from above (square
# metres) and this tall: a house, a wall, a tent, a rock the size of a cart.
const MIN_AREA := 4.0
const MIN_HEIGHT := 2.5


# Builds the blockers under `world` unless they are there already. Returns
# how many solids block the camera (0 when the obstacle data did not load).
static func ensure(world: Node) -> int:
	if world == null:
		return 0
	var existing := world.get_node_or_null(NODE_NAME)
	if existing != null:
		return existing.get_child_count()
	var obstacles := ZoneObstacles.shared()
	if obstacles == null:
		return 0
	var body := ZoneCameraBlockers.new()
	body.name = NODE_NAME
	body.collision_layer = LAYER
	body.collision_mask = 0
	for i in obstacles.size():
		if not (obstacles.flags_of(i) & ZoneObstacles.FLAG_WALK):
			continue
		var base := obstacles.base_of(i)
		var top := obstacles.top_of(i)
		var corners := obstacles.corners_of(i)
		if top - base < MIN_HEIGHT or ZoneObstacleBake.area(corners) < MIN_AREA:
			continue
		var points := PackedVector3Array()
		for c in corners:
			points.append(Vector3(c.x, base, c.y))
			points.append(Vector3(c.x, top, c.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var holder := CollisionShape3D.new()
		holder.shape = shape
		body.add_child(holder)
	world.add_child(body)
	return body.get_child_count()
