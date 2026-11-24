# The bones generator: a pile of old bones, built by code as a Geometry Nodes
# group.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, SPACING apart):
#
#   blender --background --factory-startup --python tools/blender/gen_bones.py -- bones <out.blend>
#
# The .blend can be opened in Blender: each variant's modifier shows the sliders
# and the Seed. The game never reads it; export_scenery.py makes the .glb files.
#
# A pile is a kit of pieces: a spine of separate vertebrae lying along the
# ground in a gentle curve, ribs curling up from it in pairs (a beast's
# ribcage), a skull past the spine's head, and long bones scattered round.
# Sizes follow the placeholder in scripts/zone/zone_flora.gd (a ribcage about
# 2.4 m long and 1.1 m wide, a skull at one end). Every piece is its own solid
# ("part"; the numbers are distinct, not consecutive: the rib segments from 1,
# the vertebrae from 100, the skull 200 and 201, the long bones from 300).
# "Col" is a flat placeholder colour; "UVMap" is laid out for the texture
# pass.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

# Placeholder colour, ZoneFlora's BONE.
BONE = (0.84, 0.81, 0.70, 1.0)
# Each rib is drawn as this many straight segments along its curve.
RIB_SEGMENTS = 3
VERTEBRA_PART = 100
SKULL_PART = 200
LONG_BONE_PART = 300


def _bone_colour(g, seed, offset_number, lo, hi):
    return g.vmath("SCALE", g.vec(*BONE[:3]), scale=g.random("FLOAT", lo, hi, seed, offset_number))


def build_bones():
    """Ribs curl up from the spine and back in at the top, like a basket:
    rib point at angle a is (side x Width x sin a, y, Height x (1 - cos a)),
    run from 0 to Rib Curl. The ribcage narrows toward both ends; Disorder
    knocks each rib out of line (a carcass picked over and fallen in); Sink
    lowers the whole cage into the ground.

    The spine bows sideways (Curvature) and snakes (Wave), and its neck lifts
    toward the skull (Neck Rise); the ribs and the skull follow it. Each
    vertebra is a short block with a fin on its back (Fins), largest at the
    middle of the back and smaller toward the tail and the neck."""
    g = sn.Graph("PD Bones")
    seed = g.slider("Seed", "INT", 1)
    pairs = g.slider("Rib Pairs", "INT", 4, 0, 8)
    length = g.slider("Cage Length", "FLOAT", 2.4, 0.4, 8.0)
    width = g.slider("Cage Width", "FLOAT", 0.6, 0.1, 3.0)
    cage_height = g.slider("Cage Height", "FLOAT", 0.55, 0.1, 3.0)
    curl = g.slider("Rib Curl", "FLOAT", 2.3, 1.0, 2.9)
    rib_thickness = g.slider("Rib Thickness", "FLOAT", 0.06, 0.01, 0.3)
    disorder = g.slider("Disorder", "FLOAT", 0.15, 0.0, 0.8)
    sink = g.slider("Sink", "FLOAT", 0.0, 0.0, 0.6)
    spine_on = g.slider("Spine", "BOOL", True)
    vertebrae = g.slider("Vertebrae", "INT", 12, 3, 30)
    curvature = g.slider("Curvature", "FLOAT", 0.3, -1.0, 1.0)
    wave = g.slider("Wave", "FLOAT", 0.0, -1.0, 1.0)
    neck_rise = g.slider("Neck Rise", "FLOAT", 0.12, 0.0, 1.0)
    fins = g.slider("Fins", "BOOL", True)
    skull_on = g.slider("Skull", "BOOL", True)
    skull_size = g.slider("Skull Size", "FLOAT", 0.35, 0.1, 1.5)
    long_bones = g.slider("Long Bones", "INT", 0, 0, 8)
    long_bone_length = g.slider("Long Bone Length", "FLOAT", 0.9, 0.2, 3.0)
    scatter = g.slider("Scatter", "FLOAT", 1.2, 0.2, 5.0)
    facet = g.slider("Facet Jitter", "FLOAT", 0.015, 0.0, 0.1)

    spine_r = g.math("MULTIPLY", rib_thickness, 1.5)
    spine_z = g.math("SUBTRACT", spine_r, sink)
    half = g.math("MULTIPLY", length, 0.5)
    # The spine runs from the tail at y0 to the head at y0 + its length, 0.3 m
    # past the cage at each end; s is the share of the way along it.
    spine_len = g.math("ADD", length, 0.6)
    y0 = g.math("SUBTRACT", g.math("MULTIPLY", half, -1.0), 0.3)

    def share(y):
        return g.math("DIVIDE", g.math("SUBTRACT", y, y0), spine_len)

    def bend(s):
        """How far the spine sits to the side at s (zero at both ends)."""
        bow = g.math("MULTIPLY", g.math("MULTIPLY", curvature, 0.2), g.math("SINE", g.math("MULTIPLY", s, math.pi)))
        snake = g.math("MULTIPLY", g.math("MULTIPLY", wave, 0.1), g.math("SINE", g.math("MULTIPLY", s, 2.0 * math.pi)))
        return g.math("MULTIPLY", spine_len, g.math("ADD", bow, snake))

    def neck(s):
        """How far the spine rises at s: nothing until three quarters along."""
        u = g.math("MAXIMUM", g.math("DIVIDE", g.math("SUBTRACT", s, 0.75), 0.25), 0.0)
        return g.math("MULTIPLY", neck_rise, g.math("MULTIPLY", u, u))

    g.section("Ribs")
    # Point i: rib pair k = i / (2 x segments), side s (left or right),
    # segment j along the rib. A rib's draws use its own number as the ID, so
    # its three segments agree on its size and place.
    pts = sn.line(g, g.math("MULTIPLY", pairs, 2.0 * RIB_SEGMENTS))
    i = g.index()
    rib = g.math("FLOOR", g.math("DIVIDE", i, float(RIB_SEGMENTS)))
    k = g.math("FLOOR", g.math("DIVIDE", rib, 2.0))
    side = g.math("SUBTRACT", g.math("MULTIPLY", g.math("SUBTRACT", rib, g.math("MULTIPLY", k, 2.0)), 2.0), 1.0)
    j = g.math("SUBTRACT", i, g.math("MULTIPLY", rib, float(RIB_SEGMENTS)))
    along = g.math("DIVIDE", g.math("ADD", k, 0.5), g.math("MAXIMUM", pairs, 1.0))
    # Ribs shrink toward both ends of the cage (to 55% at the very ends).
    middling = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", 0.45, g.math("ABSOLUTE", g.math("SUBTRACT", g.math("MULTIPLY", along, 2.0), 1.0))))
    neg_d = g.math("MULTIPLY", disorder, -1.0)
    knock = g.math("ADD", 1.0, g.random("FLOAT", neg_d, disorder, seed, 120, id=rib))
    w = g.math("MULTIPLY", g.math("MULTIPLY", width, middling), knock)
    h = g.math("MULTIPLY", g.math("MULTIPLY", cage_height, middling), knock)
    y = g.math("ADD", g.math("SUBTRACT", g.math("MULTIPLY", length, along), half),
               g.math("MULTIPLY", g.random("FLOAT", neg_d, disorder, seed, 121, id=rib),
                      g.math("DIVIDE", length, g.math("MAXIMUM", pairs, 1.0))))
    # A fallen rib leans along the spine by up to Disorder of its height.
    slump = g.math("MULTIPLY", g.random("FLOAT", neg_d, disorder, seed, 122, id=rib), h)

    # Each rib grows from where the curved spine is at its y.
    rib_x = bend(share(y))
    rib_z = g.math("ADD", spine_z, neck(share(y)))

    def rib_point(step):
        a = g.math("MULTIPLY", curl, g.math("DIVIDE", step, float(RIB_SEGMENTS)))
        rise = g.math("SUBTRACT", 1.0, g.math("COSINE", a))
        return g.vec(g.math("ADD", rib_x, g.math("MULTIPLY", g.math("MULTIPLY", side, w), g.math("SINE", a))),
                     g.math("ADD", y, g.math("MULTIPLY", slump, rise)),
                     g.math("ADD", g.math("MULTIPLY", h, rise), rib_z))

    a_pt = rib_point(j)
    b_pt = rib_point(g.math("ADD", j, 1.0))
    run = g.vmath("SUBTRACT", b_pt, a_pt)
    dir_ = g.vmath("NORMALIZE", run)
    seg_r = g.math("MULTIPLY", rib_thickness, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", 0.15, j)))
    seg_len = g.math("ADD", g.math("SQRT", g.dot(run, run)), seg_r)
    # Open-ended segments: the ends are inside the spine or the next segment.
    piece = sn.with_uv(g, sn.cone_standing(g, 4, 1.0, 0.85, 1.0, fill="NONE"))
    start = g.vmath("SUBTRACT", a_pt, g.vmath("SCALE", dir_, scale=g.math("MULTIPLY", seg_r, 0.5)))
    ribs = sn.instance_on(g, sn.at(g, pts, start), piece, sn.facing(g, dir_), g.vec(seg_r, seg_r, seg_len))
    ribs = sn.dressed(g, ribs, g.math("ADD", i, 1.0), _bone_colour(g, seed, 123, 0.92, 1.02))

    g.section("Spine (vertebrae)")
    # Vertebra v sits at s = (v + 0.5) / Vertebrae on the curve, turned along
    # it (the curve's slope, worked out from bend and neck), with a gap to the
    # next. Size: 55% at the tail, full from 40% along, easing to 75% at the
    # neck.
    knots = sn.line(g, vertebrae)
    v = g.index()
    s = g.math("DIVIDE", g.math("ADD", v, 0.5), vertebrae)
    where = g.vec(bend(s), g.math("ADD", y0, g.math("MULTIPLY", s, spine_len)), g.math("ADD", spine_z, neck(s)))
    d_bend = g.math("MULTIPLY", spine_len, g.math("ADD",
        g.math("MULTIPLY", g.math("MULTIPLY", curvature, 0.2 * math.pi), g.math("COSINE", g.math("MULTIPLY", s, math.pi))),
        g.math("MULTIPLY", g.math("MULTIPLY", wave, 0.2 * math.pi), g.math("COSINE", g.math("MULTIPLY", s, 2.0 * math.pi)))))
    u = g.math("MAXIMUM", g.math("DIVIDE", g.math("SUBTRACT", s, 0.75), 0.25), 0.0)
    d_neck = g.math("MULTIPLY", neck_rise, g.math("MULTIPLY", u, 8.0))
    along = g.vmath("NORMALIZE", g.vec(d_bend, spine_len, d_neck))
    grow = g.math("MINIMUM", g.math("DIVIDE", s, 0.4), 1.0)
    shrink = g.math("MULTIPLY", g.math("MAXIMUM", g.math("DIVIDE", g.math("SUBTRACT", s, 0.8), 0.2), 0.0), 0.25)
    vr = g.math("MULTIPLY", spine_r, g.math("SUBTRACT", g.math("ADD", 0.55, g.math("MULTIPLY", grow, 0.45)), shrink))
    body_len = g.math("MULTIPLY", g.math("DIVIDE", spine_len, vertebrae), 0.62)
    body_mesh = sn.with_uv(g, sn.cone_standing(g, 4, 1.0, 0.9, 1.0))
    body_at = g.vmath("SUBTRACT", where, g.vmath("SCALE", along, scale=g.math("MULTIPLY", body_len, 0.5)))
    wide = g.math("MULTIPLY", vr, 1.3)
    bodies = sn.instance_on(g, sn.at(g, knots, body_at), body_mesh, sn.facing(g, along), g.vec(wide, wide, body_len))
    # The fin stands on the vertebra's back, raked toward the tail.
    fin_mesh = sn.with_uv(g, sn.cone_standing(g, 3, 1.0, 0.0, 1.0))
    rake = g.vmath("NORMALIZE", g.vmath("SUBTRACT", g.vec(z=1.0), g.vmath("SCALE", along, scale=0.35)))
    fin_r = g.math("MULTIPLY", vr, 0.55)
    finned = sn.instance_on(g, sn.at(g, knots, where), fin_mesh, sn.facing(g, rake),
                            g.vec(fin_r, fin_r, g.math("MULTIPLY", vr, 2.4)), selection=fins)
    vertebra_part = g.math("ADD", v, float(VERTEBRA_PART))
    vertebra_tone = _bone_colour(g, seed, 132, 0.94, 1.03)
    spine = sn.join(g, sn.dressed(g, bodies, vertebra_part, vertebra_tone),
                    sn.dressed(g, finned, vertebra_part, vertebra_tone))
    spine = sn.switch(g, spine_on, spine)

    g.section("Skull")
    # A cranium past the spine's head (or alone at the middle when there is
    # no cage), with a snout pointing on and down, turned a little at random.
    has_body = g.math("MAXIMUM", g.math("GREATER_THAN", pairs, 0.0), spine_on)
    skull_y = g.math("MULTIPLY", has_body, g.math("ADD", half, g.math("ADD", 0.3, g.math("MULTIPLY", skull_size, 0.8))))
    turn = g.random("FLOAT", -0.6, 0.6, seed, 124, fixed=True)
    face = g.vec(g.math("SINE", turn), g.math("COSINE", turn), -0.35)
    # A skull on a spine is held up by its neck.
    held = g.math("MULTIPLY", g.math("MULTIPLY", neck_rise, spine_on), has_body)
    cranium_at = g.vec(0.0, skull_y, g.math("ADD", g.math("SUBTRACT", g.math("MULTIPLY", skull_size, 0.7),
                                                                g.math("MULTIPLY", sink, 0.5)), held))
    ico = g.node("GeometryNodeMeshIcoSphere")
    ico.inputs["Radius"].default_value = 1.0
    ico.inputs["Subdivisions"].default_value = 1
    cranium = sn.instance_on(g, sn.at(g, sn.one_point(g), cranium_at), sn.with_uv(g, ico),
                             g.vec(0.0, 0.0, g.math("MULTIPLY", turn, -1.0)),
                             g.vec(g.math("MULTIPLY", skull_size, 0.85), g.math("MULTIPLY", skull_size, 1.1),
                                   g.math("MULTIPLY", skull_size, 0.8)))
    cranium = sn.dressed(g, cranium, SKULL_PART, g.vmath("SCALE", g.vec(*BONE[:3]), scale=1.03))
    snout_mesh = sn.with_uv(g, sn.cone_standing(g, 4, 0.5, 0.3, 1.0))
    snout_at = g.vmath("ADD", cranium_at, g.vmath("SCALE", g.vmath("NORMALIZE", face), scale=g.math("MULTIPLY", skull_size, 0.7)))
    snout = sn.instance_on(g, sn.at(g, sn.one_point(g), snout_at), snout_mesh, sn.facing(g, face),
                           g.vec(skull_size, skull_size, skull_size))
    snout = sn.dressed(g, snout, SKULL_PART + 1, BONE)
    skull = sn.switch(g, skull_on, sn.join(g, cranium, snout))

    g.section("Long bones")
    # Each lies at a random place within Scatter of the middle, pointing any
    # way, nearly flat. A bone is a column whose middle ring is pinched in,
    # so it reads as a shaft with knobbed ends.
    shaft = sn.cone_standing(g, 4, 1.0, 1.0, 1.0, side_segments=2)
    sx, sy, sz = g.xyz(g.position())
    pinch = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", g.math("COMPARE", sz, 0.5, 0.01), 0.45))
    shaft_mesh = sn.at(g, sn.with_uv(g, shaft),
                       g.vec(g.math("MULTIPLY", sx, pinch), g.math("MULTIPLY", sy, pinch), sz))
    lie = sn.line(g, long_bones)
    n = g.index()
    spot_a = g.random("FLOAT", 0.0, math.tau, seed, 125)
    spot_r = g.math("MULTIPLY", scatter, g.math("SQRT", g.random("FLOAT", 0.05, 1.0, seed, 126)))
    heading = g.random("FLOAT", 0.0, math.tau, seed, 127)
    flat = g.vmath("NORMALIZE", g.vec(g.math("COSINE", heading), g.math("SINE", heading),
                                      g.random("FLOAT", -0.15, 0.15, seed, 128)))
    bone_len = g.math("MULTIPLY", long_bone_length, g.random("FLOAT", 0.6, 1.1, seed, 129))
    bone_r = g.math("MULTIPLY", bone_len, 0.08)
    centre = g.vec(g.math("MULTIPLY", spot_r, g.math("COSINE", spot_a)),
                   g.math("MULTIPLY", spot_r, g.math("SINE", spot_a)),
                   g.math("SUBTRACT", bone_r, g.math("MULTIPLY", sink, 0.5)))
    foot = g.vmath("SUBTRACT", centre, g.vmath("SCALE", flat, scale=g.math("MULTIPLY", bone_len, 0.5)))
    longs = sn.instance_on(g, sn.at(g, lie, foot), shaft_mesh, sn.facing(g, flat), g.vec(bone_r, bone_r, bone_len))
    longs = sn.dressed(g, longs, g.math("ADD", n, float(LONG_BONE_PART)), _bone_colour(g, seed, 130, 0.85, 0.95))

    g.section("Turn and facets")
    # Built with the spine along Y; turned a quarter round so it runs along X
    # (the game turns every pile at random anyway, and a side preview then
    # shows the cage from the side).
    pile = sn.join(g, ribs, spine, skull, longs)
    px, py, pz = g.xyz(g.position())
    pile = sn.at(g, pile, g.vec(py, g.math("MULTIPLY", px, -1.0), pz))
    pile = sn.jitter(g, pile, facet, seed, 131)
    return g.finish(sn.keep_colour(g, sn.flat_shaded(g, pile)))


BUILDERS = {"bones": build_bones}
SPACING = {"bones": 6.0}

sn.build_main(BUILDERS, SPACING, "gen_bones.py")
