# The rock generators: one Geometry Nodes group per rock kind, built by code.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, 6 m apart):
#
#   blender --background --factory-startup --python tools/blender/gen_rocks.py -- boulder <out.blend>
#
# The .blend can be opened in Blender: each variant's modifier shows the sliders
# and the Seed. The game never reads it; export_scenery.py makes the .glb files.
#
# A boulder is one convex solid (a convex hull), so the obstacle bake's solid
# for it is the rock itself. It carries "part" (0), "Col" (a flat placeholder
# colour, lighter on faces that look up) and "UVMap".
#
# Size and origin follow the placeholder boulder in scripts/zone/zone_flora.gd
# (about 2.5 x 2.1 x 1.7 m, its lowest point 0.3 m under the origin), because
# ZoneFlora's scale range, sink and tumble assume them.

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

# Placeholder colour, ZoneFlora's STONE.
STONE = (0.47, 0.46, 0.44, 1.0)
# Cut planes are unrolled into the group (a node group has no loop that a
# slider can size without a repeat zone); the Cuts slider turns them on.
MAX_CUTS = 8


def build_boulder():
    """A fractured block. Random points are scattered over a shape between a
    ball and a box (Squareness), pushed in and out a little (Lumpiness), cut
    by up to eight random planes and a flat base, then wrapped in a convex
    hull. Every point a plane cut off lands on that plane, so each cut becomes
    a flat face with hard edges: broken stone rather than a smooth pebble.

    The shape is made in a unit space (a ball of radius 1) and stretched to
    Length, Width and Height last; stretching keeps a flat face flat."""
    g = sn.Graph("PD Boulder")
    seed = g.slider("Seed", "INT", 1)
    length = g.slider("Length", "FLOAT", 2.5, 0.3, 12.0)
    width = g.slider("Width", "FLOAT", 2.1, 0.3, 12.0)
    height = g.slider("Height", "FLOAT", 1.7, 0.2, 12.0)
    bury = g.slider("Bury", "FLOAT", 0.3, 0.0, 3.0)
    points = g.slider("Points", "INT", 36, 8, 80)
    squareness = g.slider("Squareness", "FLOAT", 0.4, 0.0, 1.0)
    lumpiness = g.slider("Lumpiness", "FLOAT", 0.12, 0.0, 0.5)
    cuts = g.slider("Cuts", "INT", 3, 0, MAX_CUTS)
    cut_depth = g.slider("Cut Depth", "FLOAT", 0.3, 0.0, 0.8)
    cut_tilt = g.slider("Cut Tilt", "FLOAT", 0.0, -1.0, 1.0)
    base_cut = g.slider("Base Cut", "FLOAT", 0.4, 0.0, 0.9)
    shade = g.slider("Shade", "FLOAT", 0.18, 0.0, 0.5)

    g.section("Scatter the points (ball to box)")
    # Each point starts at a random place in the unit cube; Squareness mixes
    # its direction pushed onto the unit ball with the same pushed onto the
    # cube's surface. Lumpiness moves it in or out along that line.
    cloud = g.node("GeometryNodePoints")
    g.link(points, cloud.inputs["Count"])
    raw = g.random("FLOAT_VECTOR", (-1.0, -1.0, -1.0), (1.0, 1.0, 1.0), seed, 1)
    ball = g.vmath("NORMALIZE", raw)
    ax, ay, az = g.xyz(g.vmath("ABSOLUTE", raw))
    reach = g.math("MAXIMUM", g.math("MAXIMUM", ax, ay), g.math("MAXIMUM", az, 0.0001))
    box = g.vmath("DIVIDE", raw, g.vec(reach, reach, reach))
    mixed = g.vmath("ADD", ball, g.vmath("SCALE", g.vmath("SUBTRACT", box, ball), scale=squareness))
    lump = g.math("ADD", 1.0, g.random("FLOAT", g.math("MULTIPLY", lumpiness, -1.0), lumpiness, seed, 2))
    p = g.vmath("SCALE", mixed, scale=lump)

    g.section("Cut planes")
    # Cut i, when i < Cuts: a plane at a random facing, Cut Depth (give or take
    # half of it) in from the unit ball's surface. A point beyond the plane is
    # moved onto it along the plane's normal. No plane faces down (the
    # underside is the base's); Cut Tilt leans the facings up (towards 1) or
    # level, onto the sides (towards -1).
    for i in range(MAX_CUTS):
        facing = g.random("FLOAT_VECTOR", (-1.0, -1.0, -1.0), (1.0, 1.0, 1.0), seed, 100 + i, fixed=True)
        fx, fy, fz = g.xyz(facing)
        fz = g.math("MAXIMUM", g.math("ADD", fz, cut_tilt), 0.0)
        normal = g.vmath("NORMALIZE", g.vec(fx, fy, fz))
        depth = g.math("MULTIPLY", cut_depth, g.random("FLOAT", 0.5, 1.5, seed, 200 + i, fixed=True))
        plane = g.math("SUBTRACT", 1.0, depth)
        on = g.math("LESS_THAN", float(i), cuts)
        beyond = g.math("MULTIPLY", g.math("MAXIMUM", g.math("SUBTRACT", g.dot(p, normal), plane), 0.0), on)
        p = g.vmath("SUBTRACT", p, g.vmath("SCALE", normal, scale=beyond))

    g.section("Flat base")
    # Last, so no cut can tilt it: points under the base line come up to it,
    # and the stone sits on a flat underside (out of sight once ZoneFlora
    # sinks it).
    px, py, pz = g.xyz(p)
    floor = g.math("SUBTRACT", base_cut, 1.0)
    p = g.vec(px, py, g.math("MAXIMUM", pz, floor))

    g.section("Stretch and wrap")
    stretched = g.vmath("MULTIPLY", p, g.vec(g.math("MULTIPLY", length, 0.5),
                                             g.math("MULTIPLY", width, 0.5),
                                             g.math("MULTIPLY", height, 0.5)))
    g.link(stretched, cloud.inputs["Position"])
    hull = g.node("GeometryNodeConvexHull")
    g.link(cloud.outputs["Points"], hull.inputs["Geometry"])

    g.section("Stand it (lowest point Bury under the origin)")
    lowest = g.node("GeometryNodeAttributeStatistic", data_type="FLOAT", domain="POINT")
    g.link(hull.outputs["Convex Hull"], lowest.inputs["Geometry"])
    g.link(g.xyz(g.position())[2], lowest.inputs["Attribute"])
    lift = g.math("MULTIPLY", g.math("ADD", lowest.outputs["Min"], bury), -1.0)
    stand = g.node("GeometryNodeSetPosition")
    g.link(hull.outputs["Convex Hull"], stand.inputs["Geometry"])
    g.link(g.vec(z=lift), stand.inputs["Offset"])
    flat = g.node("GeometryNodeSetShadeSmooth")
    g.link(stand.outputs["Geometry"], flat.inputs["Mesh"])
    flat.inputs["Shade Smooth"].default_value = False
    rock = flat.outputs["Mesh"]

    g.section("UVs and placeholder colour")
    # Every sharp edge is a seam, so each flat face unwraps as its own island
    # (ready for the texture pass). The placeholder colour is lighter on faces
    # that look up and darker on faces that look down, as LowPoly's blobs are.
    angle = g.node("GeometryNodeInputMeshEdgeAngle").outputs["Unsigned Angle"]
    unwrap = g.node("GeometryNodeUVUnwrap")
    g.link(g.math("GREATER_THAN", angle, 0.35), unwrap.inputs["Seam"])
    rock = g.store(rock, "UVMap", "FLOAT2", "CORNER", unwrap.outputs["UV"])
    rock = g.store(rock, "part", "INT", "POINT", 0)
    up = g.xyz(g.node("GeometryNodeInputNormal").outputs["Normal"])[2]
    tone = g.math("ADD", 1.0, g.math("MULTIPLY", up, shade))
    rock = g.store(rock, "Col", "FLOAT_COLOR", "CORNER", g.vmath("SCALE", g.vec(*STONE[:3]), scale=tone))
    return g.finish(rock)


BUILDERS = {"boulder": build_boulder}
SPACING = {"boulder": 6.0}

# Run as a script it builds a kind; export_scenery.py imports BUILDERS instead.
if __name__ == "__main__":
    sn.build_main(BUILDERS, SPACING, "gen_rocks.py")
