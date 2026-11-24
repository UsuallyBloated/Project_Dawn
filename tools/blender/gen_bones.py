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
# A pile is a kit of pieces: a spine lying along the ground, ribs curling up
# from it in pairs (a beast's ribcage), a skull past the spine's end, and long
# bones scattered round. Sizes follow the placeholder in
# scripts/zone/zone_flora.gd (a ribcage about 2.4 m long and 1.1 m wide, a
# skull at one end). Every straight piece is its own solid ("part"; the
# numbers are distinct, not consecutive: the spine 0, the rib segments from 1,
# the skull 200 and 201, the long bones from 300). "Col" is a flat
# placeholder colour; "UVMap" is laid out for the texture pass.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

# Placeholder colour, ZoneFlora's BONE.
BONE = (0.84, 0.81, 0.70, 1.0)
# Each rib is drawn as this many straight segments along its curve.
RIB_SEGMENTS = 3
SKULL_PART = 200
LONG_BONE_PART = 300


def _bone_colour(g, seed, offset_number, lo, hi):
    return g.vmath("SCALE", g.vec(*BONE[:3]), scale=g.random("FLOAT", lo, hi, seed, offset_number))


def build_bones():
    """Ribs curl up from the spine and back in at the top, like a basket:
    rib point at angle a is (side x Width x sin a, y, Height x (1 - cos a)),
    run from 0 to Rib Curl. The ribcage narrows toward both ends; Disorder
    knocks each rib out of line (a carcass picked over and fallen in); Sink
    lowers the whole cage into the ground."""
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
    skull_on = g.slider("Skull", "BOOL", True)
    skull_size = g.slider("Skull Size", "FLOAT", 0.35, 0.1, 1.5)
    long_bones = g.slider("Long Bones", "INT", 0, 0, 8)
    long_bone_length = g.slider("Long Bone Length", "FLOAT", 0.9, 0.2, 3.0)
    scatter = g.slider("Scatter", "FLOAT", 1.2, 0.2, 5.0)
    facet = g.slider("Facet Jitter", "FLOAT", 0.015, 0.0, 0.1)

    spine_r = g.math("MULTIPLY", rib_thickness, 1.5)
    spine_z = g.math("SUBTRACT", spine_r, sink)
    half = g.math("MULTIPLY", length, 0.5)

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

    def rib_point(step):
        a = g.math("MULTIPLY", curl, g.math("DIVIDE", step, float(RIB_SEGMENTS)))
        rise = g.math("SUBTRACT", 1.0, g.math("COSINE", a))
        return g.vec(g.math("MULTIPLY", g.math("MULTIPLY", side, w), g.math("SINE", a)),
                     g.math("ADD", y, g.math("MULTIPLY", slump, rise)),
                     g.math("ADD", g.math("MULTIPLY", h, rise), spine_z))

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

    g.section("Spine")
    # It lies along the cage, 0.3 m past it at each end.
    spine_len = g.math("ADD", length, 0.6)
    spine_mesh = sn.with_uv(g, sn.cone_standing(g, 5, spine_r, g.math("MULTIPLY", spine_r, 0.75), spine_len))
    tail = g.vec(0.0, g.math("SUBTRACT", g.math("MULTIPLY", half, -1.0), 0.3), spine_z)
    spine = sn.instance_on(g, sn.at(g, sn.one_point(g), tail), spine_mesh, sn.facing(g, g.vec(y=1.0)),
                           g.vec(1.0, 1.0, 1.0))
    spine = sn.dressed(g, spine, 0, BONE)
    spine = sn.switch(g, spine_on, spine)

    g.section("Skull")
    # A cranium past the spine's head (or alone at the middle when there is
    # no cage), with a snout pointing on and down, turned a little at random.
    has_body = g.math("MAXIMUM", g.math("GREATER_THAN", pairs, 0.0), spine_on)
    skull_y = g.math("MULTIPLY", has_body, g.math("ADD", half, g.math("ADD", 0.3, g.math("MULTIPLY", skull_size, 0.8))))
    turn = g.random("FLOAT", -0.6, 0.6, seed, 124, fixed=True)
    face = g.vec(g.math("SINE", turn), g.math("COSINE", turn), -0.35)
    cranium_at = g.vec(0.0, skull_y, g.math("SUBTRACT", g.math("MULTIPLY", skull_size, 0.7), g.math("MULTIPLY", sink, 0.5)))
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
