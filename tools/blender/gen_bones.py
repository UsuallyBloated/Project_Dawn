# The bones generator: a pile of old beast bones, built by code as a
# Geometry Nodes group from the pieces in bone_kit.py.
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
# ribcage), a skull past the spine's head (a muzzle, a jaw, eye sockets,
# teeth, and horns or antlers if asked), and long bones scattered round.
# Sizes follow the placeholder in scripts/zone/zone_flora.gd (a ribcage about
# 2.4 m long and 1.1 m wide, a skull at one end). Every piece is its own
# solid ("part"; the numbers are distinct, not consecutive: the rib segments
# from 1, the vertebrae from 100, the skull from 200, the long bones from
# 300), and the obstacle bake judges each piece on its own, so a body steps
# over the low ones. "Col" is a flat placeholder colour; "UVMap" is laid out
# for the texture pass.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bone_kit as bk  # noqa: E402
import scenery_nodes as sn  # noqa: E402

VERTEBRA_PART = 100
SKULL_PART = 200
LONG_BONE_PART = 300


def build_bones():
    """Ribs curl up from the spine and back in at the top, like a basket
    (bone_kit.rib_arcs). The ribcage narrows toward both ends; Disorder knocks
    each rib out of line (a carcass picked over and fallen in); Sink lowers
    the whole cage into the ground.

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
    snout = g.slider("Snout", "FLOAT", 0.8, 0.0, 1.5)
    brow = g.slider("Brow", "FLOAT", 0.25, 0.0, 1.0)
    jaw_open = g.slider("Jaw Open", "FLOAT", 0.15, 0.0, 0.6)
    horns = g.slider("Horns", "INT", 0, 0, 2)
    horn_length = g.slider("Horn Length", "FLOAT", 1.4, 0.2, 4.0)
    horn_curl = g.slider("Horn Curl", "FLOAT", 2.4, 0.2, 3.5)
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
    ribs = bk.rib_arcs(g, seed, pairs,
                       lambda along: g.math("SUBTRACT", g.math("MULTIPLY", length, along), half),
                       width, cage_height, curl, rib_thickness, disorder,
                       lambda y: bend(share(y)), lambda y: g.math("ADD", spine_z, neck(share(y))), bk.BONE)

    g.section("Spine (vertebrae)")
    # Vertebra size: 55% at the tail, full from 40% along, easing to 75% at
    # the neck. The curve's slope is worked out from bend and neck.
    def point(s):
        return g.vec(bend(s), g.math("ADD", y0, g.math("MULTIPLY", s, spine_len)), g.math("ADD", spine_z, neck(s)))

    def tangent(s):
        d_bend = g.math("MULTIPLY", spine_len, g.math("ADD",
            g.math("MULTIPLY", g.math("MULTIPLY", curvature, 0.2 * math.pi), g.math("COSINE", g.math("MULTIPLY", s, math.pi))),
            g.math("MULTIPLY", g.math("MULTIPLY", wave, 0.2 * math.pi), g.math("COSINE", g.math("MULTIPLY", s, 2.0 * math.pi)))))
        u = g.math("MAXIMUM", g.math("DIVIDE", g.math("SUBTRACT", s, 0.75), 0.25), 0.0)
        return g.vec(d_bend, spine_len, g.math("MULTIPLY", neck_rise, g.math("MULTIPLY", u, 8.0)))

    def size(s):
        grow = g.math("MINIMUM", g.math("DIVIDE", s, 0.4), 1.0)
        shrink = g.math("MULTIPLY", g.math("MAXIMUM", g.math("DIVIDE", g.math("SUBTRACT", s, 0.8), 0.2), 0.0), 0.25)
        return g.math("MULTIPLY", spine_r, g.math("SUBTRACT", g.math("ADD", 0.55, g.math("MULTIPLY", grow, 0.45)), shrink))

    spine = bk.vertebra_chain(g, vertebrae, point, tangent, size, VERTEBRA_PART,
                              bk.tone(g, bk.BONE, g.random("FLOAT", 0.94, 1.03, seed, 132)),
                              fins=fins, fin_up=g.vec(z=1.0))
    spine = sn.switch(g, spine_on, spine)

    g.section("Skull")
    # Past the spine's head (or alone at the middle when there is no cage),
    # turned a little at random, held up by the neck when there is a spine.
    s = g.math("MULTIPLY", skull_size, 2.2)
    has_body = g.math("MAXIMUM", g.math("GREATER_THAN", pairs, 0.0), spine_on)
    skull_y = g.math("MULTIPLY", has_body, g.math("ADD", half, g.math("ADD", 0.3, g.math("MULTIPLY", s, 0.45))))
    held = g.math("MULTIPLY", g.math("MULTIPLY", neck_rise, spine_on), has_body)
    skull_z = g.math("ADD", g.math("SUBTRACT", g.math("MULTIPLY", s, 0.5), g.math("MULTIPLY", sink, 0.5)), held)
    turn = g.random("FLOAT", -0.6, 0.6, seed, 124, fixed=True)
    head = bk.skull(g, s, snout, brow, jaw_open, horns, horn_length, horn_curl,
                    bk.tone(g, bk.BONE, 1.03), SKULL_PART)
    head = bk.placed(g, head, g.vec(z=g.math("MULTIPLY", turn, -1.0)), g.vec(0.0, skull_y, skull_z))
    head = sn.switch(g, skull_on, head)

    g.section("Long bones")
    # Each lies at a random place within Scatter of the middle, pointing any
    # way, nearly flat.
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
    longs = sn.instance_on(g, sn.at(g, lie, foot), bk.shaft(g), sn.facing(g, flat), g.vec(bone_r, bone_r, bone_len))
    longs = sn.dressed(g, longs, g.math("ADD", n, float(LONG_BONE_PART)),
                       bk.tone(g, bk.BONE, g.random("FLOAT", 0.85, 0.95, seed, 130)))

    g.section("Turn and facets")
    # Built with the spine along Y; turned a quarter round so it runs along X
    # (the game turns every pile at random anyway, and a side preview then
    # shows the cage from the side).
    pile = sn.join(g, ribs, spine, head, longs)
    px, py, pz = g.xyz(g.position())
    pile = sn.at(g, pile, g.vec(py, g.math("MULTIPLY", px, -1.0), pz))
    pile = sn.jitter(g, pile, facet, seed, 131)
    return g.finish(sn.keep_colour(g, sn.flat_shaded(g, pile)))


BUILDERS = {"bones": build_bones}
SPACING = {"bones": 6.0}

# Run as a script it builds a kind; export_scenery.py imports BUILDERS instead.
if __name__ == "__main__":
    sn.build_main(BUILDERS, SPACING, "gen_bones.py")
