# The tree generators: one Geometry Nodes group per tree kind, built by code.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, SPACING apart):
#
#   blender --background --factory-startup --python tools/blender/gen_trees.py -- <kind> <out.blend>
#
# where <kind> is pine, broadleaf, dark_tree or dead_tree.
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
#   pass) and "UVMap". Part -1 is decoration with no solid (a dark tree's web).

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
DARK_LEAF = (0.14, 0.20, 0.15, 1.0)
DEAD_WOOD = (0.37, 0.33, 0.29, 1.0)
# ZoneFlora draws the dark tree's trunk as DEAD_WOOD darkened by a quarter.
DARK_BARK = (0.28, 0.25, 0.22, 1.0)
WEB = (0.62, 0.64, 0.63, 1.0)
# The golden angle, radians: branches turning by it round a trunk never line up.
GOLDEN_ANGLE = 2.39996


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
    cone = sn.cone_standing(g, skirt_points, tier_radius, 0.0, tier_height)
    tier, bottom, tier_uv = cone.outputs["Mesh"], cone.outputs["Bottom"], cone.outputs["UV Map"]
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
    cone = sn.cone_standing(g, trunk_sides, trunk_radius, g.math("MULTIPLY", trunk_radius, 0.45), trunk_depth)
    trunk, trunk_uv = cone.outputs["Mesh"], cone.outputs["UV Map"]
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
    trunk = sn.with_uv(g, sn.cone_standing(g, trunk_sides, trunk_radius,
                                           g.math("MULTIPLY", trunk_radius, 0.7),
                                           g.math("ADD", fork_height, 0.3)))
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
    seg = sn.with_uv(g, sn.cone_standing(g, 5, 1.0, 0.6, 1.0))
    inner = sn.instance_on(g, sn.at(g, roots, fork), seg, sn.facing(g, out),
                         g.vec(root_r, root_r, g.math("ADD", inner_len, 0.15)))
    inner = sn.dressed(g, inner, g.math("ADD", index, 1.0), BARK)
    outer_r = g.math("MULTIPLY", root_r, 0.6)
    outer = sn.instance_on(g, sn.at(g, roots, mid), seg, sn.facing(g, out2),
                         g.vec(outer_r, outer_r, outer_len))
    outer = sn.dressed(g, outer, g.math("ADD", g.math("ADD", index, limbs), 1.0), BARK)

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
    ends = sn.instance_on(g, sn.at(g, roots, end_at), clump, spin,
                        g.vec(size, size, g.math("MULTIPLY", size, clump_squash)))
    ends = sn.dressed(g, ends, g.math("ADD", index, first_clump), green)
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
    g.link(sn.at(g, roots, inner_at), mids.inputs["Points"])
    g.link(keep.outputs[0], mids.inputs["Selection"])
    g.link(clump, mids.inputs["Instance"])
    g.link(spin, mids.inputs["Rotation"])
    g.link(g.vec(inner_size, inner_size, g.math("MULTIPLY", inner_size, clump_squash)), mids.inputs["Scale"])
    mids = sn.dressed(g, mids.outputs["Instances"],
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


def _out(g, tilt, heading):
    """The unit direction `tilt` radians from straight up, turned `heading`
    round the vertical."""
    return g.vec(g.math("MULTIPLY", g.math("SINE", tilt), g.math("COSINE", heading)),
                 g.math("MULTIPLY", g.math("SINE", tilt), g.math("SINE", heading)),
                 g.math("COSINE", tilt))


def build_dark_tree():
    """A gnarled tree of the dark woods: a thick trunk flaring at its foot,
    made of stacked segments that each wander off the last (Twist) while the
    whole leans over (Lean); crooked limbs leaving its top, each reaching out
    and then sagging (Limb Sag) under a flat clump of dark leaves whose rim
    hangs down (Droop), so the canopy is a low, sagging roof held up by
    visible limbs. Web strings a sheet of spider web between two limbs, as the
    placeholder had.

    Part numbers: the trunk segments from 0, then each limb's inner and outer
    segment, then the clumps (the centre clump last); the web is -1,
    decoration with no solid."""
    g = sn.Graph("PD Dark Tree")
    seed = g.slider("Seed", "INT", 1)
    height = g.slider("Trunk Height", "FLOAT", 4.4, 2.2, 14.0)
    trunk_radius = g.slider("Trunk Radius", "FLOAT", 0.7, 0.05, 3.0)
    trunk_sides = g.slider("Trunk Sides", "INT", 6, 4, 10)
    segments = g.slider("Segments", "INT", 4, 2, 6)
    twist = g.slider("Twist", "FLOAT", 0.35, 0.0, 1.0)
    lean = g.slider("Lean", "FLOAT", 1.2, 0.0, 5.0)
    flare = g.slider("Root Flare", "FLOAT", 0.5, 0.0, 1.5)
    limbs = g.slider("Limbs", "INT", 6, 2, 8)
    limb_length = g.slider("Limb Length", "FLOAT", 3.2, 0.5, 10.0)
    limb_tilt = g.slider("Limb Tilt", "FLOAT", 1.1, 0.3, 1.5)
    limb_sag = g.slider("Limb Sag", "FLOAT", 0.5, 0.0, 1.5)
    canopy = g.slider("Clump Size", "FLOAT", 1.7, 0.3, 8.0)
    squash = g.slider("Clump Squash", "FLOAT", 0.5, 0.2, 1.2)
    droop = g.slider("Droop", "FLOAT", 0.5, 0.0, 1.5)
    clump_jag = g.slider("Clump Jag", "FLOAT", 0.2, 0.0, 0.4)
    centre_clump = g.slider("Centre Clump", "BOOL", True)
    web = g.slider("Web", "BOOL", False)
    web_drop = g.slider("Web Drop", "FLOAT", 1.6, 0.3, 4.0)
    facet = g.slider("Facet Jitter", "FLOAT", 0.05, 0.0, 0.4)

    g.section("Trunk (a chain of segments)")
    # Segment i rises Trunk Height / Segments and steps sideways: the lean,
    # growing with height so the top sits about Lean off the foot, plus a
    # random wander of up to Twist of its rise. Each segment starts where the
    # ones below it end (their steps added up).
    pts = sn.line(g, segments)
    i = g.index()
    rise = g.math("DIVIDE", height, segments)
    t = g.math("DIVIDE", g.math("ADD", i, 0.5), segments)
    slope = g.math("MULTIPLY", g.math("DIVIDE", lean, height), g.math("MULTIPLY", t, 2.0))
    wx, wy, _wz = g.xyz(g.random("FLOAT_VECTOR", (-1.0, -1.0, 0.0), (1.0, 1.0, 0.0), seed, 41))
    step = g.vmath("SCALE", g.vec(g.math("ADD", slope, g.math("MULTIPLY", wx, twist)),
                                  g.math("MULTIPLY", wy, twist), 1.0), scale=rise)
    acc = g.node("GeometryNodeAccumulateField", data_type="FLOAT_VECTOR", domain="POINT")
    g.link(step, sn.enabled(acc.inputs, "Value"))
    start = sn.enabled(acc.outputs, "Trailing")
    top = sn.statistic(g, pts, step, "Sum")
    seg = sn.with_uv(g, sn.cone_standing(g, trunk_sides, 1.0, 0.85, 1.0))
    r_seg = g.math("MULTIPLY", trunk_radius, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", 0.45, g.math("DIVIDE", i, segments))))
    # Each segment runs a little past its end, so the bends show no gap.
    seg_len = g.math("ADD", g.math("SQRT", g.dot(step, step)), g.math("MULTIPLY", trunk_radius, 0.3))
    trunk = sn.instance_on(g, sn.at(g, pts, start), seg, sn.facing(g, step), g.vec(r_seg, r_seg, seg_len))
    trunk = sn.dressed(g, trunk, i, DARK_BARK)
    # The foot flares: corners in the lowest 1.5 m are pushed out from the
    # trunk's axis by up to Root Flare of their distance.
    px, py, pz = g.xyz(g.position())
    widen = g.math("ADD", 1.0, g.math("MULTIPLY", flare, g.math("MAXIMUM", g.math("SUBTRACT", 1.0, g.math("DIVIDE", pz, 1.5)), 0.0)))
    trunk = sn.at(g, trunk, g.vec(g.math("MULTIPLY", px, widen), g.math("MULTIPLY", py, widen), pz))

    g.section("Limbs (reach out, then sag)")
    # A limb leaves the trunk's top Limb Tilt from straight up, then its
    # outer part turns down by Limb Sag (and aside a little, at random).
    roots = sn.line(g, limbs)
    j = g.index()
    heading = g.math("ADD", g.math("MULTIPLY", g.math("DIVIDE", j, limbs), math.tau),
                     g.random("FLOAT", -0.4, 0.4, seed, 42))
    out = _out(g, g.math("MULTIPLY", limb_tilt, g.random("FLOAT", 0.85, 1.1, seed, 43)), heading)
    kink = g.random("FLOAT_VECTOR", (-0.35, -0.35, -0.2), (0.35, 0.35, 0.2), seed, 53)
    out2 = g.vmath("NORMALIZE", g.vmath("SUBTRACT", g.vmath("ADD", out, kink), g.vec(z=limb_sag)))
    reach = g.math("MULTIPLY", limb_length, g.random("FLOAT", 0.75, 1.2, seed, 44))
    inner_len = g.math("MULTIPLY", reach, 0.6)
    outer_len = g.math("MULTIPLY", reach, 0.4)
    root = g.vmath("SUBTRACT", top, g.vec(z=g.math("MULTIPLY", trunk_radius, 0.3)))
    mid = g.vmath("ADD", root, g.vmath("SCALE", out, scale=inner_len))
    tip = g.vmath("ADD", mid, g.vmath("SCALE", out2, scale=outer_len))
    limb_r = g.math("MULTIPLY", trunk_radius, 0.42)
    stick = sn.with_uv(g, sn.cone_standing(g, 5, 1.0, 0.6, 1.0))
    inner = sn.instance_on(g, sn.at(g, roots, root), stick, sn.facing(g, out),
                           g.vec(limb_r, limb_r, g.math("ADD", inner_len, 0.15)))
    inner = sn.dressed(g, inner, g.math("ADD", j, segments), DARK_BARK)
    outer_r = g.math("MULTIPLY", limb_r, 0.6)
    outer = sn.instance_on(g, sn.at(g, roots, mid), stick, sn.facing(g, out2), g.vec(outer_r, outer_r, outer_len))
    outer = sn.dressed(g, outer, g.math("ADD", g.math("ADD", j, segments), limbs), DARK_BARK)

    g.section("Canopy (drooping clumps)")
    # A clump is an icosphere whose rim is pulled down by Droop (in units of
    # the clump's own height), then squashed flat by Clump Squash.
    ico = g.node("GeometryNodeMeshIcoSphere")
    ico.inputs["Radius"].default_value = 1.0
    ico.inputs["Subdivisions"].default_value = 1
    clump = sn.with_uv(g, ico)
    cx, cy, _cz = g.xyz(g.position())
    rim = g.math("ADD", g.math("MULTIPLY", cx, cx), g.math("MULTIPLY", cy, cy))
    clump = sn.offset(g, clump, g.vec(z=g.math("MULTIPLY", g.math("MULTIPLY", droop, rim), -1.0)))
    size = g.math("MULTIPLY", canopy, g.random("FLOAT", 0.8, 1.15, seed, 45))
    ox, oy, _oz = g.xyz(out2)
    clump_at = g.vmath("ADD", tip, g.vec(g.math("MULTIPLY", ox, g.math("MULTIPLY", size, 0.2)),
                                         g.math("MULTIPLY", oy, g.math("MULTIPLY", size, 0.2)),
                                         g.math("MULTIPLY", g.math("MULTIPLY", size, squash), 0.3)))
    spin = g.vec(g.random("FLOAT", -0.12, 0.12, seed, 46), g.random("FLOAT", -0.12, 0.12, seed, 47),
                 g.random("FLOAT", 0.0, math.tau, seed, 48))
    shade = g.vmath("SCALE", g.vec(*DARK_LEAF[:3]), scale=g.random("FLOAT", 0.85, 1.2, seed, 49))
    ends = sn.instance_on(g, sn.at(g, roots, clump_at), clump, spin,
                          g.vec(size, size, g.math("MULTIPLY", size, squash)))
    first_clump = g.math("ADD", segments, g.math("MULTIPLY", limbs, 2.0))
    ends = sn.dressed(g, ends, g.math("ADD", j, first_clump), shade)
    # The centre clump caps the trunk, half again as big as the rest.
    big = g.math("MULTIPLY", canopy, 1.5)
    centre_at = g.vmath("ADD", top, g.vec(z=g.math("MULTIPLY", g.math("MULTIPLY", big, squash), 0.5)))
    centre = sn.instance_on(g, sn.at(g, sn.one_point(g), centre_at), clump,
                            g.vec(z=g.random("FLOAT", 0.0, math.tau, seed, 50, fixed=True)),
                            g.vec(big, big, g.math("MULTIPLY", big, squash)), selection=centre_clump)
    centre = sn.dressed(g, centre, g.math("ADD", first_clump, limbs),
                        g.vmath("SCALE", g.vec(*DARK_LEAF[:3]), scale=0.92))
    leaves = sn.jitter(g, sn.join(g, ends, centre), g.math("MULTIPLY", clump_jag, canopy), seed, 51)

    g.section("Web")
    # A sheet hanging between the bends of limbs 0 and 1, Web Drop deep; both
    # faces drawn so it shows from either side.
    a = sn.sample(g, roots, mid, 0)
    b = sn.sample(g, roots, mid, 1)
    grid = g.node("GeometryNodeMeshGrid")
    for name, v in (("Size X", 1.0), ("Size Y", 1.0), ("Vertices X", 2), ("Vertices Y", 2)):
        grid.inputs[name].default_value = v
    sheet = sn.with_uv(g, grid)
    gx, gy, _gz = g.xyz(g.position())
    u = g.math("ADD", gx, 0.5)
    down = g.math("MULTIPLY", g.math("ADD", gy, 0.5), web_drop)
    corner = g.vmath("SUBTRACT", g.vmath("ADD", a, g.vmath("SCALE", g.vmath("SUBTRACT", b, a), scale=u)),
                     g.vec(z=down))
    sheet = sn.at(g, sheet, corner)
    back = g.node("GeometryNodeFlipFaces")
    g.link(sheet, back.inputs["Mesh"])
    sheet = sn.join(g, sheet, back.outputs["Mesh"])
    sheet = g.store(sheet, "part", "INT", "POINT", -1)
    sheet = g.store(sheet, "Col", "FLOAT_COLOR", "POINT", WEB)
    sheet = sn.switch(g, web, sheet)

    g.section("Facets")
    tree = sn.jitter(g, sn.join(g, leaves, outer, inner, trunk, sheet), facet, seed, 52)
    return g.finish(sn.keep_colour(g, sn.flat_shaded(g, tree)))


def build_dead_tree():
    """A bare dead tree: a tapering trunk, branches leaving it between Branch
    Low and near the top (turning round it by the golden angle, shorter as
    they climb), and Twigs forking off each branch. Snapped breaks the top off:
    a blunt trunk with a jagged end.

    Every branch and twig works out its own place from its number, and a twig
    repeats its branch's random draws (the same ID) to find where it grows,
    so nothing is hand placed. Part numbers: 0 the trunk, 1.. the branches,
    then the twigs."""
    g = sn.Graph("PD Dead Tree")
    seed = g.slider("Seed", "INT", 1)
    height = g.slider("Height", "FLOAT", 5.6, 2.5, 25.0)
    trunk_radius = g.slider("Trunk Radius", "FLOAT", 0.34, 0.05, 3.0)
    trunk_sides = g.slider("Trunk Sides", "INT", 5, 4, 10)
    branches = g.slider("Branches", "INT", 4, 0, 8)
    branch_low = g.slider("Branch Low", "FLOAT", 0.45, 0.2, 0.9)
    branch_length = g.slider("Branch Length", "FLOAT", 2.4, 0.3, 12.0)
    branch_tilt = g.slider("Branch Tilt", "FLOAT", 0.9, 0.2, 1.3)
    twigs = g.slider("Twigs", "INT", 2, 0, 4)
    twig_length = g.slider("Twig Length", "FLOAT", 0.45, 0.1, 0.9)
    snapped = g.slider("Snapped", "BOOL", False)
    snap_jag = g.slider("Snap Jag", "FLOAT", 0.4, 0.0, 1.5)
    lean = g.slider("Lean", "FLOAT", 0.4, 0.0, 4.0)
    facet = g.slider("Facet Jitter", "FLOAT", 0.04, 0.0, 0.3)

    g.section("Trunk")
    # A whole trunk narrows to a quarter of its foot; a snapped one stays
    # thick to its broken end, whose rim is pulled down unevenly.
    top_ratio = g.math("ADD", 0.25, g.math("MULTIPLY", snapped, 0.35))
    cone = sn.cone_standing(g, trunk_sides, trunk_radius, g.math("MULTIPLY", trunk_radius, top_ratio), height)
    trunk = sn.with_uv(g, cone)
    break_by = g.math("MULTIPLY", g.random("FLOAT", g.math("MULTIPLY", snap_jag, -1.0), 0.0, seed, 60), snapped)
    trunk = sn.offset(g, trunk, g.vec(z=break_by), selection=cone.outputs["Top"])
    trunk = g.store(trunk, "part", "INT", "POINT", 0)
    trunk = g.store(trunk, "Col", "FLOAT_COLOR", "POINT", DEAD_WOOD)

    def branch(ix):
        """Branch number `ix` (a field): its root, direction, length and
        radius. Every draw uses `ix` as its ID, so a twig asking about its
        branch gets the same answers the branch got."""
        n = g.math("MAXIMUM", g.math("SUBTRACT", branches, 1.0), 1.0)
        frac = g.math("ADD", g.math("ADD", branch_low,
                                    g.math("MULTIPLY", g.math("SUBTRACT", 0.92, branch_low), g.math("DIVIDE", ix, n))),
                      g.random("FLOAT", -0.05, 0.05, seed, 61, id=ix))
        # No branch leaves the trunk below 2.4 m: the crown starts above a head.
        h = g.math("MAXIMUM", g.math("MULTIPLY", height, frac), 2.4)
        heading = g.math("ADD", g.math("MULTIPLY", ix, GOLDEN_ANGLE), g.random("FLOAT", -0.5, 0.5, seed, 62, id=ix))
        out = _out(g, g.math("MULTIPLY", branch_tilt, g.random("FLOAT", 0.8, 1.2, seed, 63, id=ix)), heading)
        length = g.math("MULTIPLY", g.math("MULTIPLY", branch_length, g.math("SUBTRACT", 1.15, g.math("MULTIPLY", frac, 0.5))),
                        g.random("FLOAT", 0.8, 1.2, seed, 64, id=ix))
        taper = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", g.math("SUBTRACT", 1.0, top_ratio), g.math("DIVIDE", h, height)))
        radius = g.math("MULTIPLY", g.math("MULTIPLY", trunk_radius, taper), 0.5)
        return g.vec(z=h), out, length, radius

    g.section("Branches")
    roots = sn.line(g, branches)
    i = g.index()
    root, out, length, radius = branch(i)
    stick = sn.with_uv(g, sn.cone_standing(g, 4, 1.0, 0.3, 1.0))
    wood = g.vmath("SCALE", g.vec(*DEAD_WOOD[:3]), scale=g.random("FLOAT", 0.9, 1.1, seed, 65))
    limb = sn.instance_on(g, sn.at(g, roots, root), stick, sn.facing(g, out), g.vec(radius, radius, length))
    limb = sn.dressed(g, limb, g.math("ADD", i, 1.0), wood)

    g.section("Twigs")
    # Twig k of a branch grows from between 45% and 90% along it, turned off
    # the branch at random and a little up.
    per = g.math("MAXIMUM", twigs, 1.0)
    shoots = sn.line(g, g.math("MULTIPLY", branches, twigs))
    tix = g.index()
    parent = g.math("FLOOR", g.math("DIVIDE", tix, per))
    k = g.math("SUBTRACT", tix, g.math("MULTIPLY", parent, per))
    p_root, p_out, p_len, p_rad = branch(parent)
    f = g.math("ADD", g.math("ADD", 0.45, g.math("MULTIPLY", 0.45, g.math("DIVIDE", g.math("ADD", k, 0.5), per))),
               g.random("FLOAT", -0.08, 0.08, seed, 71))
    start = g.vmath("ADD", p_root, g.vmath("SCALE", p_out, scale=g.math("MULTIPLY", p_len, f)))
    turn = g.random("FLOAT_VECTOR", (-1.0, -1.0, -1.0), (1.0, 1.0, 1.0), seed, 72)
    t_out = g.vmath("NORMALIZE", g.vmath("ADD", g.vmath("ADD", p_out, g.vmath("SCALE", turn, scale=0.9)),
                                         g.vec(z=0.35)))
    t_len = g.math("MULTIPLY", g.math("MULTIPLY", p_len, twig_length), g.random("FLOAT", 0.7, 1.2, seed, 73))
    t_rad = g.math("MULTIPLY", p_rad, g.math("MULTIPLY", g.math("SUBTRACT", 1.0, g.math("MULTIPLY", f, 0.7)), 0.7))
    twig = sn.instance_on(g, sn.at(g, shoots, start), stick, sn.facing(g, t_out), g.vec(t_rad, t_rad, t_len))
    twig = sn.dressed(g, twig, g.math("ADD", g.math("ADD", tix, branches), 1.0),
                      g.vmath("SCALE", g.vec(*DEAD_WOOD[:3]), scale=g.random("FLOAT", 0.95, 1.15, seed, 74)))

    g.section("Lean and facets")
    tree = sn.join(g, twig, limb, trunk)
    z = g.xyz(g.position())[2]
    reach = g.math("ADD", height, branch_length)
    bend = g.math("DIVIDE", g.math("MULTIPLY", lean, g.math("MULTIPLY", z, z)), g.math("MULTIPLY", reach, reach))
    tree = sn.offset(g, tree, g.vec(bend, 0.0, 0.0))
    tree = sn.jitter(g, tree, facet, seed, 75)
    return g.finish(sn.flat_shaded(g, tree))


BUILDERS = {"pine": build_pine, "broadleaf": build_broadleaf, "dark_tree": build_dark_tree,
            "dead_tree": build_dead_tree}
# Room between variants in the built .blend (a broadleaf's crown is wide).
SPACING = {"pine": 14.0, "broadleaf": 24.0, "dark_tree": 22.0, "dead_tree": 16.0}

sn.build_main(BUILDERS, SPACING, "gen_trees.py")
