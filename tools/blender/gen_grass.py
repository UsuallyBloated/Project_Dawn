# The grass generator: a tuft of blades, built by code as a Geometry Nodes
# group.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, SPACING apart):
#
#   blender --background --factory-startup --python tools/blender/gen_grass.py -- grass <out.blend>
#
# The .blend can be opened in Blender: each variant's modifier shows the sliders
# and the Seed. The game never reads it; export_scenery.py makes the .glb files.
#
# Grass blocks nothing and hides nobody (0.3 to 0.6 m), so every corner is part
# -1, decoration with no solid. A blade is a flat strip, drawn on both faces
# (a back-facing copy) so it shows from either side whatever the material's
# culling. "Col" is darker at the root and lighter at the tip; "UVMap" runs up
# each blade for the texture pass.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

GRASS_GREEN = (0.32, 0.45, 0.18, 1.0)
STRAW = (0.62, 0.58, 0.32, 1.0)
# Rows of corners up a blade (the strip is ROWS - 1 quads, the top one closing
# to a point).
ROWS = 4


def build_grass():
    """Blades fan out of one point, each tilted out from upright (Spread),
    turned evenly round the tuft, and curling over toward its tip (Curl, a
    share of its height). The first Stalks blades are seed stalks: half again
    as tall, thinner and straw-coloured. Dry moves every blade toward straw."""
    g = sn.Graph("PD Grass")
    seed = g.slider("Seed", "INT", 1)
    height = g.slider("Height", "FLOAT", 0.45, 0.1, 1.5)
    height_var = g.slider("Height Variation", "FLOAT", 0.3, 0.0, 0.8)
    blades = g.slider("Blades", "INT", 7, 3, 12)
    width = g.slider("Blade Width", "FLOAT", 0.05, 0.01, 0.2)
    spread = g.slider("Spread", "FLOAT", 0.45, 0.0, 1.2)
    curl = g.slider("Curl", "FLOAT", 0.15, 0.0, 0.6)
    stalks = g.slider("Stalks", "INT", 0, 0, 4)
    dry = g.slider("Dry", "FLOAT", 0.0, 0.0, 1.0)

    g.section("One blade (unit height and width)")
    # A strip from a grid: x across the blade, t from 0 at the root to 1 at
    # the tip. It narrows to a point and bends toward -y by Curl x t squared.
    # The two corners at the tip meet, so they are merged into one.
    grid = g.node("GeometryNodeMeshGrid")
    for name, v in (("Size X", 1.0), ("Size Y", 1.0), ("Vertices X", 2), ("Vertices Y", ROWS)):
        grid.inputs[name].default_value = v
    blade = sn.with_uv(g, grid)
    gx, gy, _gz = g.xyz(g.position())
    t = g.math("ADD", gy, 0.5)
    blade = g.store(blade, "tip", "FLOAT", "POINT", t)
    blade = sn.at(g, blade, g.vec(g.math("MULTIPLY", gx, g.math("SUBTRACT", 1.0, t)),
                                  g.math("MULTIPLY", g.math("MULTIPLY", curl, g.math("MULTIPLY", t, t)), -1.0),
                                  t))
    merge = g.node("GeometryNodeMergeByDistance")
    g.link(blade, merge.inputs["Geometry"])
    blade = merge.outputs["Geometry"]
    back = g.node("GeometryNodeFlipFaces")
    g.link(blade, back.inputs["Mesh"])
    blade = sn.join(g, blade, back.outputs["Mesh"])

    g.section("The tuft")
    # Blade i leans out toward heading h: rotated about x by its tilt (which
    # leans +z toward -y, the way it curls), then about z by h.
    pts = sn.line(g, blades)
    i = g.index()
    is_stalk = g.math("LESS_THAN", i, stalks)
    heading = g.math("ADD", g.math("MULTIPLY", g.math("DIVIDE", i, blades), math.tau),
                     g.random("FLOAT", -0.5, 0.5, seed, 141))
    tilt = g.math("MULTIPLY", spread, g.random("FLOAT", 0.3, 1.0, seed, 142))
    tilt = g.math("MULTIPLY", tilt, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", is_stalk, 0.6)))
    neg_v = g.math("MULTIPLY", height_var, -1.0)
    h = g.math("MULTIPLY", height, g.math("ADD", 1.0, g.random("FLOAT", neg_v, height_var, seed, 143)))
    h = g.math("MULTIPLY", h, g.math("ADD", 1.0, g.math("MULTIPLY", is_stalk, 0.5)))
    w = g.math("MULTIPLY", width, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", is_stalk, 0.5)))
    base = g.random("FLOAT_VECTOR", (-0.04, -0.04, 0.0), (0.04, 0.04, 0.0), seed, 144)
    tuft = sn.instance_on(g, sn.at(g, pts, base), blade, g.vec(tilt, 0.0, heading), g.vec(w, h, h))
    green = g.vmath("SCALE", g.vec(*GRASS_GREEN[:3]), scale=g.random("FLOAT", 0.85, 1.15, seed, 145))
    straw = g.vec(*STRAW[:3])
    tone = g.math("MAXIMUM", dry, is_stalk)
    colour = g.vmath("ADD", green, g.vmath("SCALE", g.vmath("SUBTRACT", straw, green), scale=tone))
    tuft = sn.dressed(g, tuft, -1, colour)

    g.section("Shade root to tip")
    read = g.node("GeometryNodeInputNamedAttribute", data_type="FLOAT_COLOR")
    read.inputs["Name"].default_value = "Col"
    tip = g.node("GeometryNodeInputNamedAttribute", data_type="FLOAT")
    tip.inputs["Name"].default_value = "tip"
    shade = g.math("ADD", 0.65, g.math("MULTIPLY", sn.enabled(tip.outputs, "Attribute"), 0.5))
    tuft = g.store(tuft, "Col", "FLOAT_COLOR", "POINT",
                   g.vmath("SCALE", sn.enabled(read.outputs, "Attribute"), scale=shade))
    remove = g.node("GeometryNodeRemoveAttribute")
    g.link(tuft, remove.inputs["Geometry"])
    remove.inputs["Name"].default_value = "tip"
    return g.finish(sn.flat_shaded(g, remove.outputs["Geometry"]))


BUILDERS = {"grass": build_grass}
SPACING = {"grass": 1.2}

sn.build_main(BUILDERS, SPACING, "gen_grass.py")
