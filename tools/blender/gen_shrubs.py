# The shrub generators (bush and scrub): one Geometry Nodes group per kind,
# built by code.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, SPACING apart):
#
#   blender --background --factory-startup --python tools/blender/gen_shrubs.py -- <bush|scrub> <out.blend>
#
# The .blend can be opened in Blender: each variant's modifier shows the sliders
# and the Seed. The game never reads it; export_scenery.py makes the .glb files.
#
# Sizes follow the placeholders in scripts/zone/zone_flora.gd (a bush about
# 2.3 m across and 1.5 m high, a scrub knee high with twigs to about 1 m),
# since ZoneFlora's scale ranges and sink assume them. Every solid piece
# carries its own "part" number (one solid each for the obstacle bake); part
# -1 is decoration with no solid (a bush's berries). "Col" is a flat
# placeholder colour until the texture pass; "UVMap" is laid out for it.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

# Placeholder colours, from ZoneFlora's palette.
BUSH_GREEN = (0.24, 0.35, 0.16, 1.0)
SCRUB = (0.43, 0.42, 0.22, 1.0)
BERRY = (0.55, 0.10, 0.12, 1.0)
GOLDEN_ANGLE = 2.39996


def _blob(g):
    """A unit icosphere (20 faces), the shrubs' leafy mass."""
    ico = g.node("GeometryNodeMeshIcoSphere")
    ico.inputs["Radius"].default_value = 1.0
    ico.inputs["Subdivisions"].default_value = 1
    return sn.with_uv(g, ico)


def _mix(g, a, b, t):
    """Colour a, moved toward colour b by t (0 to 1)."""
    va, vb = g.vec(*a[:3]), g.vec(*b[:3])
    return g.vmath("ADD", va, g.vmath("SCALE", g.vmath("SUBTRACT", vb, va), scale=t))


def build_bush():
    """A low mound of leafy blobs: one big blob in the middle and the rest
    round it (Spread), each smaller, squashed and turned at random, every
    corner pushed a little (Jag) so none is a clean ball. Berries dots a few
    red berries over the outside.

    Part numbers: 0 the middle blob, 1.. the ring; berries are -1."""
    g = sn.Graph("PD Bush")
    seed = g.slider("Seed", "INT", 1)
    size = g.slider("Size", "FLOAT", 1.15, 0.3, 4.0)
    height = g.slider("Height", "FLOAT", 0.85, 0.3, 3.0)
    blobs = g.slider("Blobs", "INT", 4, 1, 8)
    spread = g.slider("Spread", "FLOAT", 0.85, 0.0, 2.0)
    jag = g.slider("Jag", "FLOAT", 0.15, 0.0, 0.4)
    berries = g.slider("Berries", "INT", 0, 0, 12)
    facet = g.slider("Facet Jitter", "FLOAT", 0.03, 0.0, 0.2)

    g.section("Blobs")
    # Blob 0 is the middle one at full size; blob i sits Spread of the size
    # out, turned evenly round the middle, at half to three quarters the size.
    pts = sn.line(g, blobs)
    i = g.index()
    is_main = g.math("COMPARE", i, 0.0, 0.01)
    ring = g.math("MAXIMUM", g.math("SUBTRACT", blobs, 1.0), 1.0)
    heading = g.math("ADD", g.math("MULTIPLY", g.math("DIVIDE", g.math("SUBTRACT", i, 1.0), ring), math.tau),
                     g.random("FLOAT", -0.4, 0.4, seed, 81))
    away = g.math("MULTIPLY", g.math("MULTIPLY", g.math("MULTIPLY", size, spread), g.random("FLOAT", 0.7, 1.1, seed, 82)),
                  g.math("SUBTRACT", 1.0, is_main))
    share = g.random("FLOAT", 0.5, 0.75, seed, 83)
    share = g.math("ADD", share, g.math("MULTIPLY", is_main, g.math("SUBTRACT", 1.0, share)))
    w = g.math("MULTIPLY", size, share)
    h = g.math("MULTIPLY", height, share)
    centre = g.vec(g.math("MULTIPLY", away, g.math("COSINE", heading)),
                   g.math("MULTIPLY", away, g.math("SINE", heading)),
                   g.math("MULTIPLY", h, 0.82))
    spin = g.vec(g.random("FLOAT", -0.15, 0.15, seed, 84), g.random("FLOAT", -0.15, 0.15, seed, 85),
                 g.random("FLOAT", 0.0, math.tau, seed, 86))
    green = g.vmath("SCALE", g.vec(*BUSH_GREEN[:3]), scale=g.random("FLOAT", 0.88, 1.15, seed, 87))
    bush = sn.instance_on(g, sn.at(g, pts, centre), _blob(g), spin,
                          g.vec(w, g.math("MULTIPLY", w, g.random("FLOAT", 0.85, 1.0, seed, 88)), h))
    bush = sn.dressed(g, bush, i, green)
    bush = sn.jitter(g, bush, g.math("MULTIPLY", jag, size), seed, 89)

    g.section("Berries")
    # Each berry sits on a corner of the bush picked at random, pushed a
    # little out from the bush's middle so it shows.
    corners = g.node("GeometryNodeAttributeDomainSize", component="MESH")
    g.link(bush, corners.inputs["Geometry"])
    pick = g.random("INT", 0, g.math("SUBTRACT", corners.outputs["Point Count"], 1.0), seed, 90)
    on = sn.sample(g, bush, g.position(), pick)
    outward = g.vmath("NORMALIZE", g.vmath("SUBTRACT", on, g.vec(z=g.math("MULTIPLY", height, 0.5))))
    berry_pts = sn.at(g, sn.line(g, berries), g.vmath("ADD", on, g.vmath("SCALE", outward, scale=0.04)))
    berry = sn.with_uv(g, sn.cone_standing(g, 3, 0.11, 0.0, 0.15))
    berry_rot = g.vec(g.random("FLOAT", 0.0, math.tau, seed, 91), g.random("FLOAT", 0.0, math.tau, seed, 92), 0.0)
    fruit = sn.instance_on(g, berry_pts, berry, berry_rot, g.vec(1.0, 1.0, 1.0))
    fruit = sn.dressed(g, fruit, -1, BERRY)

    g.section("Facets")
    shrub = sn.jitter(g, sn.join(g, bush, fruit), facet, seed, 93)
    return g.finish(sn.keep_colour(g, sn.flat_shaded(g, shrub)))


def build_scrub():
    """Dry scrub: stiff twigs fanning out of a low mound, turning round it by
    the golden angle, with a few small leafy clumps on twig tips. Dryness
    moves the leaves from green to straw.

    Part numbers: 0 the mound, 1.. the twigs, then the clumps."""
    g = sn.Graph("PD Scrub")
    seed = g.slider("Seed", "INT", 1)
    size = g.slider("Size", "FLOAT", 0.55, 0.2, 3.0)
    mound_height = g.slider("Mound Height", "FLOAT", 0.35, 0.1, 1.5)
    twigs = g.slider("Twigs", "INT", 7, 0, 14)
    twig_length = g.slider("Twig Length", "FLOAT", 1.1, 0.2, 3.0)
    twig_thickness = g.slider("Twig Thickness", "FLOAT", 0.045, 0.01, 0.15)
    spread = g.slider("Spread", "FLOAT", 0.9, 0.1, 1.4)
    clumps = g.slider("Clumps", "INT", 3, 0, 8)
    clump_size = g.slider("Clump Size", "FLOAT", 0.35, 0.05, 1.2)
    dryness = g.slider("Dryness", "FLOAT", 0.7, 0.0, 1.0)
    jag = g.slider("Jag", "FLOAT", 0.08, 0.0, 0.3)
    facet = g.slider("Facet Jitter", "FLOAT", 0.02, 0.0, 0.1)

    leaf = _mix(g, BUSH_GREEN, SCRUB, dryness)

    g.section("Mound")
    mound = sn.instance_on(g, sn.at(g, sn.one_point(g), g.vec(z=g.math("MULTIPLY", mound_height, 0.35))), _blob(g),
                           g.vec(z=g.random("FLOAT", 0.0, math.tau, seed, 100, fixed=True)),
                           g.vec(size, g.math("MULTIPLY", size, 0.85), mound_height))
    mound = sn.dressed(g, mound, 0, g.vmath("SCALE", leaf, scale=0.9))

    g.section("Twigs")
    # Twig i leaves the mound's middle Spread from straight up (give or take),
    # turned the golden angle from the last.
    pts = sn.line(g, twigs)
    i = g.index()
    heading = g.math("ADD", g.math("MULTIPLY", i, GOLDEN_ANGLE), g.random("FLOAT", -0.4, 0.4, seed, 101))
    tilt = g.math("MULTIPLY", spread, g.random("FLOAT", 0.45, 1.15, seed, 102))
    out = g.vec(g.math("MULTIPLY", g.math("SINE", tilt), g.math("COSINE", heading)),
                g.math("MULTIPLY", g.math("SINE", tilt), g.math("SINE", heading)),
                g.math("COSINE", tilt))
    length = g.math("MULTIPLY", twig_length, g.random("FLOAT", 0.7, 1.2, seed, 103))
    root = g.vec(z=g.math("MULTIPLY", mound_height, 0.3))
    tip = g.vmath("ADD", root, g.vmath("SCALE", out, scale=length))
    r = g.math("MULTIPLY", twig_thickness, g.random("FLOAT", 0.8, 1.2, seed, 104))
    stick = sn.with_uv(g, sn.cone_standing(g, 3, 1.0, 0.0, 1.0))
    wood = g.vmath("SCALE", g.vec(*SCRUB[:3]), scale=g.random("FLOAT", 0.72, 0.85, seed, 105))
    sticks = sn.instance_on(g, sn.at(g, pts, root), stick, sn.facing(g, out), g.vec(r, r, length))
    sticks = sn.dressed(g, sticks, g.math("ADD", i, 1.0), wood)

    g.section("Clumps")
    # The first Clumps twigs carry a small clump just short of their tips.
    s = g.math("MULTIPLY", clump_size, g.random("FLOAT", 0.7, 1.2, seed, 106))
    at_tip = g.vmath("SUBTRACT", tip, g.vmath("SCALE", out, scale=g.math("MULTIPLY", s, 0.3)))
    spin = g.vec(g.random("FLOAT", -0.3, 0.3, seed, 107), g.random("FLOAT", -0.3, 0.3, seed, 108),
                 g.random("FLOAT", 0.0, math.tau, seed, 109))
    carry = g.math("LESS_THAN", i, clumps)
    tufts = sn.instance_on(g, sn.at(g, pts, at_tip), _blob(g), spin, g.vec(s, s, g.math("MULTIPLY", s, 0.7)),
                           selection=carry)
    tufts = sn.dressed(g, tufts, g.math("ADD", g.math("ADD", i, twigs), 1.0),
                       g.vmath("SCALE", leaf, scale=g.random("FLOAT", 0.9, 1.12, seed, 110)))

    g.section("Jag and facets")
    leafy = sn.jitter(g, sn.join(g, mound, tufts), g.math("MULTIPLY", jag, size), seed, 111)
    shrub = sn.jitter(g, sn.join(g, leafy, sticks), facet, seed, 112)
    return g.finish(sn.keep_colour(g, sn.flat_shaded(g, shrub)))


BUILDERS = {"bush": build_bush, "scrub": build_scrub}
SPACING = {"bush": 4.5, "scrub": 4.0}

# Run as a script it builds a kind; export_scenery.py imports BUILDERS instead.
if __name__ == "__main__":
    sn.build_main(BUILDERS, SPACING, "gen_shrubs.py")
