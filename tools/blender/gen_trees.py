# The tree generators: one Geometry Nodes group per tree kind, built by code.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, SPACING apart):
#
#   blender --background --factory-startup --python tools/blender/gen_trees.py -- <pine|broadleaf> <out.blend>
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
LEAF_GREEN = (0.28, 0.40, 0.17, 1.0)


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
    boughs from a distance with a handful of triangles.

    Each tier starts a fixed share (Overlap) of the way up the one below, so a
    tier's tip always ends inside the next tier; the sideways nudges and tilts
    shrink with the tiers, so no tip pokes out beside the next. Only the top
    tier, with nothing above it, stretches into a spire."""
    g = sn.Graph("PD Pine")
    seed = g.slider("Seed", "INT", 1)
    height = g.slider("Height", "FLOAT", 12.0, 3.0, 40.0)
    crown_base = g.slider("Crown Base", "FLOAT", 3.0, 2.2, 15.0)
    tiers = g.slider("Tiers", "INT", 4, 2, 7)
    overlap = g.slider("Overlap", "FLOAT", 0.55, 0.3, 0.75)
    spire = g.slider("Spire", "FLOAT", 0.5, 0.0, 1.5)
    tier_radius = g.slider("Tier Radius", "FLOAT", 3.6, 0.3, 14.0)
    taper = g.slider("Taper", "FLOAT", 0.7, 0.0, 0.95)
    tier_jitter = g.slider("Tier Jitter", "FLOAT", 0.12, 0.0, 0.5)
    tier_tilt = g.slider("Tier Tilt", "FLOAT", 0.04, 0.0, 0.2)
    skirt_points = g.slider("Skirt Points", "INT", 8, 4, 16)
    skirt_droop = g.slider("Skirt Droop", "FLOAT", 0.6, 0.0, 3.0)
    skirt_flare = g.slider("Skirt Flare", "FLOAT", 0.15, 0.0, 0.6)
    trunk_radius = g.slider("Trunk Radius", "FLOAT", 0.6, 0.05, 3.0)
    trunk_sides = g.slider("Trunk Sides", "INT", 7, 4, 12)
    trunk_variation = g.slider("Trunk Variation", "FLOAT", 0.2, 0.0, 0.6)
    lean = g.slider("Lean", "FLOAT", 0.0, 0.0, 2.0)
    facet = g.slider("Facet Jitter", "FLOAT", 0.05, 0.0, 0.3)

    g.section("Tier size (solved from Height)")
    # Tier i has scale s_i = 1 - Taper * i / (n - 1) and stands Overlap of the
    # way up tier i - 1. The tier height TH is whatever makes the top tier,
    # spire included, end at Height:
    #   top = base0 + Overlap * TH * sum(s_0..s_n-2) + TH * s_last * (1 + Spire)
    # where sum(s_0..s_n-2) = (n - 1) - Taper * (n - 2) / 2.
    base0 = g.math("ADD", crown_base, skirt_droop)
    steps = g.math("MAXIMUM", g.math("SUBTRACT", tiers, 1.0), 1.0)
    s_last = g.math("SUBTRACT", 1.0, taper)
    lower_sum = g.math("SUBTRACT", steps, g.math("MULTIPLY", taper, g.math("MULTIPLY", g.math("SUBTRACT", tiers, 2.0), 0.5)))
    span = g.math("ADD", g.math("MULTIPLY", overlap, lower_sum), g.math("MULTIPLY", s_last, g.math("ADD", spire, 1.0)))
    tier_height = g.math("DIVIDE", g.math("SUBTRACT", height, base0), span)

    g.section("One tier (cone with a star skirt)")
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
    tier = g.store(pull.outputs["Geometry"], "UVMap", "FLOAT2", "CORNER", tier_uv)

    g.section("Where the tiers stand")
    # The tier points: z_i = base0 + Overlap * TH * (i - Taper * i (i - 1) / (2 (n - 1))),
    # each nudged sideways by up to Tier Jitter times its own scale.
    shrink = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", taper, g.math("DIVIDE", index, steps)))
    climbed = g.math("SUBTRACT", index, g.math("DIVIDE", g.math("MULTIPLY", taper, g.math("MULTIPLY", index, g.math("SUBTRACT", index, 1.0))), g.math("MULTIPLY", steps, 2.0)))
    tier_z = g.math("ADD", base0, g.math("MULTIPLY", g.math("MULTIPLY", overlap, tier_height), climbed))
    line = g.node("GeometryNodeMeshLine")
    g.link(tiers, line.inputs["Count"])
    place = g.node("GeometryNodeSetPosition")
    g.link(line.outputs["Mesh"], place.inputs["Geometry"])
    nudge_xy = g.random("FLOAT_VECTOR", (-1.0, -1.0, 0.0), (1.0, 1.0, 0.0), seed, 11)
    nudge = g.vmath("SCALE", nudge_xy, scale=g.math("MULTIPLY", tier_jitter, shrink))
    g.link(g.vmath("ADD", nudge, g.vec(z=tier_z)), place.inputs["Position"])

    g.section("Crown (a tier on every point)")
    tilt = g.math("MULTIPLY", tier_tilt, shrink)
    neg_t = g.math("MULTIPLY", tilt, -1.0)
    rotation = g.vec(g.random("FLOAT", neg_t, tilt, seed, 12),
                     g.random("FLOAT", neg_t, tilt, seed, 13),
                     g.random("FLOAT", 0.0, math.tau, seed, 14))
    is_top = g.math("COMPARE", index, steps, 0.01)
    tall = g.math("MULTIPLY", shrink, g.math("ADD", 1.0, g.math("MULTIPLY", spire, is_top)))
    inst = g.node("GeometryNodeInstanceOnPoints")
    g.link(place.outputs["Geometry"], inst.inputs["Points"])
    g.link(tier, inst.inputs["Instance"])
    g.link(rotation, inst.inputs["Rotation"])
    g.link(g.vec(shrink, shrink, tall), inst.inputs["Scale"])
    crown = g.store(inst.outputs["Instances"], "part", "INT", "INSTANCE", g.math("ADD", index, 1.0))
    shade = g.math("ADD", 1.0, g.math("MULTIPLY", index, 0.12))
    crown = g.store(crown, "Col", "FLOAT_COLOR", "INSTANCE",
                   g.vmath("SCALE", g.vec(*PINE_GREEN[:3]), scale=shade))
    realize = g.node("GeometryNodeRealizeInstances")
    g.link(crown, realize.inputs["Geometry"])

    g.section("Trunk")
    # The trunk runs from the ground into the second tier. Its thickness is
    # Trunk Radius, give or take up to Trunk Variation of it per seed.
    trunk_depth = g.math("ADD", base0, g.math("MULTIPLY", tier_height, g.math("ADD", overlap, 0.3)))
    trunk, _bottom, trunk_uv = _cone_standing(g, trunk_sides, trunk_radius, g.math("MULTIPLY", trunk_radius, 0.45), trunk_depth)
    girth = g.math("ADD", 1.0, g.random("FLOAT", g.math("MULTIPLY", trunk_variation, -1.0), trunk_variation, seed, 16, fixed=True))
    tpos = g.node("GeometryNodeInputPosition").outputs["Position"]
    thick = g.node("GeometryNodeSetPosition")
    g.link(trunk, thick.inputs["Geometry"])
    g.link(g.vmath("MULTIPLY", tpos, g.vec(girth, girth, 1.0)), thick.inputs["Position"])
    trunk = g.store(thick.outputs["Geometry"], "UVMap", "FLOAT2", "CORNER", trunk_uv)
    trunk = g.store(trunk, "part", "INT", "POINT", 0)
    trunk = g.store(trunk, "Col", "FLOAT_COLOR", "POINT", BARK)

    g.section("Lean and facets")
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


def _instance_on(g, points, mesh, rotation, scale):
    inst = g.node("GeometryNodeInstanceOnPoints")
    g.link(points, inst.inputs["Points"])
    g.link(mesh, inst.inputs["Instance"])
    g.link(rotation, inst.inputs["Rotation"])
    g.link(scale, inst.inputs["Scale"])
    return inst.outputs["Instances"]


def _at(g, geometry, position):
    """The geometry with every point moved to `position` (a field)."""
    n = g.node("GeometryNodeSetPosition")
    g.link(geometry, n.inputs["Geometry"])
    g.link(position, n.inputs["Position"])
    return n.outputs["Geometry"]


def _facing(g, vector):
    """A rotation that turns +Z onto `vector`."""
    n = g.node("FunctionNodeAlignRotationToVector")
    n.axis = "Z"
    g.link(vector, n.inputs["Vector"])
    return n.outputs["Rotation"]


def _dressed(g, instances, part, colour):
    """Instances with their part numbers and placeholder colour, realized."""
    instances = g.store(instances, "part", "INT", "INSTANCE", part)
    instances = g.store(instances, "Col", "FLOAT_COLOR", "INSTANCE", colour)
    realize = g.node("GeometryNodeRealizeInstances")
    g.link(instances, realize.inputs["Geometry"])
    return realize.outputs["Geometry"]


def build_broadleaf():
    """A deciduous tree: a trunk that forks into crooked limbs, each limb two
    tapered segments with a kink between them, and a faceted clump of leaves
    at the end of every limb and (with Inner Clumps) another halfway out.
    Limb 0 is the leader: it rises nearly straight (Leader) and carries the
    biggest clump, which makes the crown's top.

    Everything is placed in the limb's own direction, worked out per limb from
    the Seed, so a variant is a handful of numbers and nothing is hand placed.
    Part numbers: 0 the trunk, then each limb's inner and outer segment, then
    the end clumps, then the inner clumps (one solid each for the bake)."""
    g = sn.Graph("PD Broadleaf")
    seed = g.slider("Seed", "INT", 1)
    fork_height = g.slider("Fork Height", "FLOAT", 3.6, 2.2, 12.0)
    trunk_radius = g.slider("Trunk Radius", "FLOAT", 0.45, 0.05, 3.0)
    trunk_sides = g.slider("Trunk Sides", "INT", 6, 4, 12)
    limbs = g.slider("Limbs", "INT", 4, 2, 7)
    limb_length = g.slider("Limb Length", "FLOAT", 3.2, 0.5, 15.0)
    limb_thickness = g.slider("Limb Thickness", "FLOAT", 0.7, 0.2, 1.0)
    spread = g.slider("Spread", "FLOAT", 0.85, 0.1, 1.5)
    leader = g.slider("Leader", "FLOAT", 0.15, 0.0, 1.0)
    crook = g.slider("Crook", "FLOAT", 0.35, 0.0, 1.0)
    upturn = g.slider("Upturn", "FLOAT", 0.35, -0.5, 1.5)
    clump_size = g.slider("Clump Size", "FLOAT", 2.2, 0.3, 10.0)
    clump_squash = g.slider("Clump Squash", "FLOAT", 0.75, 0.3, 1.5)
    clump_jag = g.slider("Clump Jag", "FLOAT", 0.14, 0.0, 0.4)
    clump_detail = g.slider("Clump Detail", "INT", 1, 1, 2)
    inner_clumps = g.slider("Inner Clumps", "BOOL", True)
    lean = g.slider("Lean", "FLOAT", 0.0, 0.0, 3.0)
    facet = g.slider("Facet Jitter", "FLOAT", 0.06, 0.0, 0.4)

    g.section("Trunk")
    trunk, _bottom, trunk_uv = _cone_standing(g, trunk_sides, trunk_radius,
                                              g.math("MULTIPLY", trunk_radius, 0.7),
                                              g.math("ADD", fork_height, 0.3))
    trunk = g.store(trunk, "UVMap", "FLOAT2", "CORNER", trunk_uv)
    trunk = g.store(trunk, "part", "INT", "POINT", 0)
    trunk = g.store(trunk, "Col", "FLOAT_COLOR", "POINT", BARK)

    g.section("Limb directions")
    # Limb i leaves the fork at a tilt from straight up and a heading round the
    # trunk. Limbs 1.. share the circle evenly, each nudged; limb 0 is the
    # leader, tilted only Leader of the Spread.
    index = g.node("GeometryNodeInputIndex").outputs["Index"]
    others = g.math("MAXIMUM", g.math("SUBTRACT", limbs, 1.0), 1.0)
    is_leader = g.math("COMPARE", index, 0.0, 0.01)
    heading = g.math("ADD",
                     g.math("MULTIPLY", g.math("DIVIDE", g.math("SUBTRACT", index, 1.0), others), math.tau),
                     g.random("FLOAT", -0.45, 0.45, seed, 21))
    share = g.math("ADD", 1.0, g.math("MULTIPLY", is_leader, g.math("SUBTRACT", leader, 1.0)))
    tilt = g.math("MULTIPLY", g.math("MULTIPLY", spread, share), g.random("FLOAT", 0.8, 1.15, seed, 22))
    out = g.vec(g.math("MULTIPLY", g.math("SINE", tilt), g.math("COSINE", heading)),
                g.math("MULTIPLY", g.math("SINE", tilt), g.math("SINE", heading)),
                g.math("COSINE", tilt))
    # The outer segment turns off the inner one by up to Crook, and up by Upturn.
    kink = g.random("FLOAT_VECTOR", (-1.0, -1.0, -1.0), (1.0, 1.0, 1.0), seed, 23)
    out2 = g.vmath("NORMALIZE", g.vmath("ADD", g.vmath("ADD", out, g.vmath("SCALE", kink, scale=crook)),
                                         g.vec(z=upturn)))
    reach = g.math("MULTIPLY", limb_length, g.random("FLOAT", 0.8, 1.2, seed, 24))
    inner_len = g.math("MULTIPLY", reach, 0.55)
    outer_len = g.math("MULTIPLY", reach, 0.45)
    fork = g.vec(z=fork_height)
    mid = g.vmath("ADD", fork, g.vmath("SCALE", out, scale=inner_len))
    tip = g.vmath("ADD", mid, g.vmath("SCALE", out2, scale=outer_len))
    root_r = g.math("MULTIPLY", g.math("MULTIPLY", trunk_radius, 0.7), limb_thickness)
    line = g.node("GeometryNodeMeshLine")
    g.link(limbs, line.inputs["Count"])
    roots = line.outputs["Mesh"]

    g.section("Limbs (two tapered segments each)")
    # A unit segment (radius 1 to 0.6, length 1) is stretched onto each limb.
    seg, _sb, seg_uv = _cone_standing(g, 5, 1.0, 0.6, 1.0)
    seg = g.store(seg, "UVMap", "FLOAT2", "CORNER", seg_uv)
    inner = _instance_on(g, _at(g, roots, fork), seg, _facing(g, out),
                         g.vec(root_r, root_r, g.math("ADD", inner_len, 0.15)))
    inner = _dressed(g, inner, g.math("ADD", index, 1.0), BARK)
    outer_r = g.math("MULTIPLY", root_r, 0.6)
    outer = _instance_on(g, _at(g, roots, mid), seg, _facing(g, out2),
                         g.vec(outer_r, outer_r, outer_len))
    outer = _dressed(g, outer, g.math("ADD", g.math("ADD", index, limbs), 1.0), BARK)

    g.section("Leaf clumps")
    # A clump is an icosphere squashed by Clump Squash, turned at random and
    # sized per limb; the leader's is the largest. Each clump's green is a
    # little lighter or darker than the next.
    ico = g.node("GeometryNodeMeshIcoSphere")
    ico.inputs["Radius"].default_value = 1.0
    g.link(clump_detail, ico.inputs["Subdivisions"])
    clump = g.store(ico.outputs["Mesh"], "UVMap", "FLOAT2", "CORNER", ico.outputs["UV Map"])
    size = g.math("MULTIPLY", g.math("MULTIPLY", clump_size, g.random("FLOAT", 0.8, 1.15, seed, 25)),
                  g.math("ADD", 1.0, g.math("MULTIPLY", is_leader, 0.2)))
    spin = g.vec(g.random("FLOAT", -0.3, 0.3, seed, 26), g.random("FLOAT", -0.3, 0.3, seed, 27),
                 g.random("FLOAT", 0.0, math.tau, seed, 28))
    green = g.vmath("SCALE", g.vec(*LEAF_GREEN[:3]), scale=g.random("FLOAT", 0.85, 1.15, seed, 29))
    first_clump = g.math("ADD", g.math("MULTIPLY", limbs, 2.0), 1.0)
    # The clump sits a little past the tip, so the limb ends inside it.
    end_at = g.vmath("ADD", tip, g.vmath("SCALE", out2, scale=g.math("MULTIPLY", size, 0.3)))
    ends = _instance_on(g, _at(g, roots, end_at), clump, spin,
                        g.vec(size, size, g.math("MULTIPLY", size, clump_squash)))
    ends = _dressed(g, ends, g.math("ADD", index, first_clump), green)
    # Inner clumps: smaller, at the kink, pushed outward and up a little.
    inner_size = g.math("MULTIPLY", size, 0.7)
    inner_at = g.vmath("ADD", mid, g.vmath("ADD", g.vmath("SCALE", out, scale=g.math("MULTIPLY", inner_size, 0.4)),
                                           g.vec(z=g.math("MULTIPLY", inner_size, 0.35))))
    not_leader = g.node("FunctionNodeBooleanMath", operation="NOT")
    g.link(is_leader, not_leader.inputs[0])
    keep = g.node("FunctionNodeBooleanMath", operation="AND")
    g.link(inner_clumps, keep.inputs[0])
    g.link(not_leader.outputs[0], keep.inputs[1])
    mids = g.node("GeometryNodeInstanceOnPoints")
    g.link(_at(g, roots, inner_at), mids.inputs["Points"])
    g.link(keep.outputs[0], mids.inputs["Selection"])
    g.link(clump, mids.inputs["Instance"])
    g.link(spin, mids.inputs["Rotation"])
    g.link(g.vec(inner_size, inner_size, g.math("MULTIPLY", inner_size, clump_squash)), mids.inputs["Scale"])
    mids = _dressed(g, mids.outputs["Instances"],
                    g.math("ADD", index, g.math("ADD", first_clump, limbs)),
                    g.vmath("SCALE", green, scale=0.9))

    # Every leaf corner is pushed a random way by up to Clump Jag of the clump
    # size, so no two clumps are the same shape and none is a smooth ball.
    leaves = g.node("GeometryNodeJoinGeometry")
    g.link(mids, leaves.inputs[0])
    g.link(ends, leaves.inputs[0])
    reach_j = g.math("MULTIPLY", clump_jag, clump_size)
    neg_j = g.math("MULTIPLY", reach_j, -1.0)
    jag = g.node("GeometryNodeSetPosition")
    g.link(leaves.outputs[0], jag.inputs["Geometry"])
    g.link(g.random("FLOAT_VECTOR", g.vec(neg_j, neg_j, neg_j), g.vec(reach_j, reach_j, reach_j), seed, 31),
           jag.inputs["Offset"])

    g.section("Lean and facets")
    join = g.node("GeometryNodeJoinGeometry")
    for piece in (jag.outputs["Geometry"], outer, inner, trunk):
        g.link(piece, join.inputs[0])
    z = g.xyz(g.position())[2]
    top = g.math("ADD", fork_height, g.math("ADD", limb_length, clump_size))
    bend = g.math("DIVIDE", g.math("MULTIPLY", lean, g.math("MULTIPLY", z, z)), g.math("MULTIPLY", top, top))
    leaned = g.node("GeometryNodeSetPosition")
    g.link(join.outputs[0], leaned.inputs["Geometry"])
    g.link(g.vec(bend, 0.0, 0.0), leaned.inputs["Offset"])
    neg_f = g.math("MULTIPLY", facet, -1.0)
    jit = g.node("GeometryNodeSetPosition")
    g.link(leaned.outputs["Geometry"], jit.inputs["Geometry"])
    g.link(g.random("FLOAT_VECTOR", g.vec(neg_f, neg_f, neg_f), g.vec(facet, facet, facet), seed, 30),
           jit.inputs["Offset"])
    flat = g.node("GeometryNodeSetShadeSmooth")
    g.link(jit.outputs["Geometry"], flat.inputs["Mesh"])
    flat.inputs["Shade Smooth"].default_value = False
    return g.finish(flat.outputs["Mesh"])


BUILDERS = {"pine": build_pine, "broadleaf": build_broadleaf}
# Room between variants in the built .blend (a broadleaf's crown is wide).
SPACING = {"pine": 14.0, "broadleaf": 24.0}


def main():
    args = sn.script_args()
    if len(args) != 2 or args[0] not in BUILDERS:
        raise SystemExit("usage: gen_trees.py -- <%s> <out.blend>" % "|".join(BUILDERS))
    kind, out = args
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    tree = BUILDERS[kind]()
    for i, row in enumerate(sn.variants(kind)):
        obj = sn.apply_variant(tree, "%s_%d" % (kind, row["variant"]), row, (i * SPACING[kind], 0.0, 0.0))
        print("%s: %d triangles" % (obj.name, sn.triangles(obj)))
    # Saved with the first variant selected and active, so Blender's Geometry
    # Nodes workspace opens on its node group.
    first = bpy.data.objects["%s_%d" % (kind, sn.variants(kind)[0]["variant"])]
    first.select_set(True)
    bpy.context.view_layer.objects.active = first
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out))
    print("saved", out)


main()
