# The tree generators: one Geometry Nodes group per tree kind, built by code.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, 14 m apart):
#
#   blender --background --factory-startup --python tools/blender/gen_trees.py -- pine <out.blend>
#
# The .blend can be opened in Blender: each variant's modifier shows the sliders
# and the Seed. The game never reads it; export_scenery.py makes the .glb files.
#
# Conventions every kind keeps (see docs: the scenery generator plan):
# - Origin at the base, metres, Blender's Z up (the glTF export turns it to Y).
# - Sizes match the placeholder shapes in scripts/zone/zone_flora.gd, since
#   ZoneFlora's scale ranges and sink assume them.
# - A tree's crown starts at 2.2 m or higher, so a body stops at the trunk.
# - Every part carries "part" (0 = trunk, 1.. = crown pieces, one solid each
#   for the obstacle bake), "Col" (a flat placeholder colour until the texture
#   pass) and "UVMap".

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

# Placeholder colours, from ZoneFlora's palette (linear values are set in Godot;
# these are the same sRGB numbers).
BARK = (0.33, 0.25, 0.18, 1.0)
PINE_GREEN = (0.14, 0.27, 0.17, 1.0)


def _store(g, geometry, name, data_type, domain, value):
    n = g.node("GeometryNodeStoreNamedAttribute", data_type=data_type, domain=domain)
    n.inputs["Name"].default_value = name
    g.link(geometry, n.inputs["Geometry"])
    sock = n.inputs["Value"]
    if isinstance(value, (int, float, tuple, list)):
        sock.default_value = value
    else:
        g.link(value, sock)
    return n.outputs["Geometry"]


def _cone_standing(g, vertices, radius_bottom, radius_top, depth):
    """A cone or tapered column with its base at the origin. Returns
    (mesh, bottom selection, uv map)."""
    cone = g.node("GeometryNodeMeshCone")
    for sock_name, v in (("Vertices", vertices), ("Radius Bottom", radius_bottom),
                         ("Radius Top", radius_top), ("Depth", depth)):
        if isinstance(v, (int, float)):
            cone.inputs[sock_name].default_value = v
        else:
            g.link(v, cone.inputs[sock_name])
    # Blender's Cone node already stands on its base (z from 0 to Depth).
    return cone.outputs["Mesh"], cone.outputs["Bottom"], cone.outputs["UV Map"]


def build_pine():
    """Stacked faceted cone tiers on a straight trunk. Each tier's skirt is a
    star: every other rim point drops and flares, so a tier reads as layered
    boughs from a distance with a handful of triangles."""
    g = sn.Graph("PD Pine")
    seed = g.slider("Seed", "INT", 1)
    height = g.slider("Height", "FLOAT", 8.0, 3.0, 30.0)
    crown_base = g.slider("Crown Base", "FLOAT", 2.3, 2.2, 10.0)
    tiers = g.slider("Tiers", "INT", 4, 2, 7)
    tier_height = g.slider("Tier Height", "FLOAT", 3.4, 0.5, 8.0)
    tier_radius = g.slider("Tier Radius", "FLOAT", 2.6, 0.3, 6.0)
    taper = g.slider("Taper", "FLOAT", 0.7, 0.0, 0.95)
    tier_jitter = g.slider("Tier Jitter", "FLOAT", 0.2, 0.0, 1.0)
    tier_tilt = g.slider("Tier Tilt", "FLOAT", 0.06, 0.0, 0.4)
    skirt_points = g.slider("Skirt Points", "INT", 8, 4, 16)
    skirt_droop = g.slider("Skirt Droop", "FLOAT", 0.45, 0.0, 2.0)
    skirt_flare = g.slider("Skirt Flare", "FLOAT", 0.15, 0.0, 0.6)
    trunk_radius = g.slider("Trunk Radius", "FLOAT", 0.3, 0.05, 1.0)
    lean = g.slider("Lean", "FLOAT", 0.0, 0.0, 2.0)
    facet = g.slider("Facet Jitter", "FLOAT", 0.05, 0.0, 0.3)

    # Where the tiers stand. The lowest skirt point sits at Crown Base, so the
    # first tier's base is a droop above it; the top tier ends at Height.
    base0 = g.math("ADD", crown_base, skirt_droop)
    steps = g.math("MAXIMUM", g.math("SUBTRACT", tiers, 1.0), 1.0)
    top_scale = g.math("SUBTRACT", 1.0, taper)
    spacing = g.math("DIVIDE", g.math("SUBTRACT", g.math("SUBTRACT", height, g.math("MULTIPLY", tier_height, top_scale)), base0), steps)

    # One tier, the star skirt pulled from its bottom rim.
    tier, bottom, tier_uv = _cone_standing(g, skirt_points, tier_radius, 0.0, tier_height)
    index = g.node("GeometryNodeInputIndex").outputs["Index"]
    every_other = g.math("COMPARE", g.math("FLOORED_MODULO", index, 2.0), 0.0, 0.01)
    star = g.node("FunctionNodeBooleanMath", operation="AND")
    g.link(bottom, star.inputs[0])
    g.link(every_other, star.inputs[1])
    pos = g.node("GeometryNodeInputPosition").outputs["Position"]
    sep = g.node("ShaderNodeSeparateXYZ")
    g.link(pos, sep.inputs[0])
    flare = g.vec(g.math("MULTIPLY", sep.outputs["X"], skirt_flare),
                  g.math("MULTIPLY", sep.outputs["Y"], skirt_flare),
                  g.math("MULTIPLY", skirt_droop, -1.0))
    pull = g.node("GeometryNodeSetPosition")
    g.link(tier, pull.inputs["Geometry"])
    g.link(star.outputs[0], pull.inputs["Selection"])
    g.link(flare, pull.inputs["Offset"])
    tier = _store(g, pull.outputs["Geometry"], "UVMap", "FLOAT2", "CORNER", tier_uv)

    # The tier points, nudged sideways a little each.
    line = g.node("GeometryNodeMeshLine")
    g.link(tiers, line.inputs["Count"])
    g.link(g.vec(z=base0), line.inputs["Start Location"])
    g.link(g.vec(z=spacing), line.inputs["Offset"])
    nudge = g.node("GeometryNodeSetPosition")
    g.link(line.outputs["Mesh"], nudge.inputs["Geometry"])
    neg_j = g.math("MULTIPLY", tier_jitter, -1.0)
    g.link(g.random("FLOAT_VECTOR", g.vec(neg_j, neg_j, 0.0), g.vec(tier_jitter, tier_jitter, 0.0), seed, 11),
           nudge.inputs["Offset"])

    neg_t = g.math("MULTIPLY", tier_tilt, -1.0)
    rotation = g.vec(g.random("FLOAT", neg_t, tier_tilt, seed, 12),
                     g.random("FLOAT", neg_t, tier_tilt, seed, 13),
                     g.random("FLOAT", 0.0, math.tau, seed, 14))
    shrink = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", taper, g.math("DIVIDE", index, steps)))
    inst = g.node("GeometryNodeInstanceOnPoints")
    g.link(nudge.outputs["Geometry"], inst.inputs["Points"])
    g.link(tier, inst.inputs["Instance"])
    g.link(rotation, inst.inputs["Rotation"])
    # A small tier high up is stretched tall enough to overlap the one below,
    # so no tier floats free of the tree.
    stretch = g.math("MAXIMUM", shrink, g.math("DIVIDE", g.math("MULTIPLY", spacing, 1.55), tier_height))
    g.link(g.vec(shrink, shrink, stretch), inst.inputs["Scale"])
    crown = _store(g, inst.outputs["Instances"], "part", "INT", "INSTANCE", g.math("ADD", index, 1.0))
    shade = g.math("ADD", 1.0, g.math("MULTIPLY", index, 0.12))
    crown = _store(g, crown, "Col", "FLOAT_COLOR", "INSTANCE",
                   g.vmath("SCALE", g.vec(*PINE_GREEN[:3]), scale=shade))
    realize = g.node("GeometryNodeRealizeInstances")
    g.link(crown, realize.inputs["Geometry"])

    # The trunk runs from the ground up into the second tier.
    trunk_depth = g.math("ADD", base0, g.math("ADD", spacing, g.math("MULTIPLY", tier_height, 0.3)))
    trunk, _bottom, trunk_uv = _cone_standing(g, 6, trunk_radius, g.math("MULTIPLY", trunk_radius, 0.45), trunk_depth)
    trunk = _store(g, trunk, "UVMap", "FLOAT2", "CORNER", trunk_uv)
    trunk = _store(g, trunk, "part", "INT", "POINT", 0)
    trunk = _store(g, trunk, "Col", "FLOAT_COLOR", "POINT", BARK)

    join = g.node("GeometryNodeJoinGeometry")
    g.link(realize.outputs["Geometry"], join.inputs[0])
    g.link(trunk, join.inputs[0])

    # A lean that grows with height, then a small per-corner jitter for facets.
    pos2 = g.node("GeometryNodeInputPosition").outputs["Position"]
    sep2 = g.node("ShaderNodeSeparateXYZ")
    g.link(pos2, sep2.inputs[0])
    z = sep2.outputs["Z"]
    bend = g.math("DIVIDE", g.math("MULTIPLY", lean, g.math("MULTIPLY", z, z)), g.math("MULTIPLY", height, height))
    leaned = g.node("GeometryNodeSetPosition")
    g.link(join.outputs[0], leaned.inputs["Geometry"])
    g.link(g.vec(bend, 0.0, 0.0), leaned.inputs["Offset"])
    neg_f = g.math("MULTIPLY", facet, -1.0)
    jit = g.node("GeometryNodeSetPosition")
    g.link(leaned.outputs["Geometry"], jit.inputs["Geometry"])
    g.link(g.random("FLOAT_VECTOR", g.vec(neg_f, neg_f, neg_f), g.vec(facet, facet, facet), seed, 15),
           jit.inputs["Offset"])
    flat = g.node("GeometryNodeSetShadeSmooth")
    g.link(jit.outputs["Geometry"], flat.inputs["Mesh"])
    flat.inputs["Shade Smooth"].default_value = False
    return g.finish(flat.outputs["Mesh"])


BUILDERS = {"pine": build_pine}


def main():
    args = sn.script_args()
    if len(args) != 2 or args[0] not in BUILDERS:
        raise SystemExit("usage: gen_trees.py -- <%s> <out.blend>" % "|".join(BUILDERS))
    kind, out = args
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    tree = BUILDERS[kind]()
    for i, row in enumerate(sn.variants(kind)):
        obj = sn.apply_variant(tree, "%s_%d" % (kind, row["variant"]), row, (i * 14.0, 0.0, 0.0))
        print("%s: %d triangles" % (obj.name, sn.triangles(obj)))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out))
    print("saved", out)


main()
