# The humanoid skeleton generator: the bones of a fallen adventurer lying on
# their back, built by code as a Geometry Nodes group from the pieces in
# bone_kit.py.
#
# Run headless to build a .blend holding the group and one object per variant
# listed in scenery_variants.toml (laid out in a row, SPACING apart):
#
#   blender --background --factory-startup --python tools/blender/gen_skeleton.py -- skeleton <out.blend>
#
# The .blend can be opened in Blender: each variant's modifier shows the sliders
# and the Seed. The game never reads it; export_scenery.py makes the .glb files.
#
# One variant per playable race, at that race's height and build from
# docs/reference/creature_heights.md: head size, leg and arm length, shoulder
# and hip width, bone thickness, a muzzle, horns, a jutting brow, digitigrade
# legs and a tail are all sliders. The body lies along +Y (soles at 0, crown
# at Height) before it is centred and turned a quarter round (the game turns
# it at random anyway). Every piece is its own solid ("part"; distinct, not
# consecutive: ribs from 1, vertebrae from 100, the tail from 150, the skull
# from 200, everything else from 300), judged on its own by the obstacle
# bake, so a body steps over the low ones. "Col" is a flat placeholder colour;
# "UVMap" is laid out for the texture pass.

import itertools
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bone_kit as bk  # noqa: E402
import scenery_nodes as sn  # noqa: E402

VERTEBRA_PART = 100
TAIL_PART = 150
SKULL_PART = 200
FIRST_LIMB_PART = 300


def build_skeleton():
    """Proportions are shares of Height, the human ones from the usual
    figure-drawing canon (a head about 1/7.5 of the height, the hip joint a
    little above half, an arm about 0.44): Head, Leg (the hip joint's height),
    Arm, Shoulders and Hips move them per race. Build thickens every bone
    (Dwarf, Ogre) or thins it (Elf, Fae); Chest widens and deepens the
    ribcage. Snout grows a muzzle (and then the skull lies on its jaw, muzzle
    along the body, instead of face up); Horns and Brow come from the skull
    kit. Digitigrade legs stand on the toes: a long foot bone continues the
    leg. Tail adds tail vertebrae. Arm Spread and Leg Spread open the limbs
    out from the body; Disorder knocks every joint a little out of line."""
    g = sn.Graph("PD Skeleton")
    seed = g.slider("Seed", "INT", 1)
    height = g.slider("Height", "FLOAT", 1.78, 0.4, 3.2)
    head = g.slider("Head", "FLOAT", 0.133, 0.08, 0.3)
    leg = g.slider("Leg", "FLOAT", 0.52, 0.3, 0.62)
    arm = g.slider("Arm", "FLOAT", 0.44, 0.3, 0.62)
    shoulders = g.slider("Shoulders", "FLOAT", 0.24, 0.15, 0.4)
    hips = g.slider("Hips", "FLOAT", 0.19, 0.1, 0.35)
    build = g.slider("Build", "FLOAT", 1.0, 0.5, 2.0)
    chest = g.slider("Chest", "FLOAT", 1.0, 0.6, 1.6)
    rib_pairs = g.slider("Rib Pairs", "INT", 6, 3, 10)
    vertebrae = g.slider("Vertebrae", "INT", 14, 6, 24)
    snout = g.slider("Snout", "FLOAT", 0.0, 0.0, 1.5)
    brow = g.slider("Brow", "FLOAT", 0.1, 0.0, 1.0)
    jaw_open = g.slider("Jaw Open", "FLOAT", 0.1, 0.0, 0.6)
    horns = g.slider("Horns", "INT", 0, 0, 2)
    horn_length = g.slider("Horn Length", "FLOAT", 0.9, 0.2, 4.0)
    horn_curl = g.slider("Horn Curl", "FLOAT", 2.4, 0.2, 3.5)
    digitigrade = g.slider("Digitigrade", "BOOL", False)
    tail = g.slider("Tail", "INT", 0, 0, 24)
    tail_length = g.slider("Tail Length", "FLOAT", 0.35, 0.05, 1.0)
    arm_spread = g.slider("Arm Spread", "FLOAT", 0.45, 0.0, 1.6)
    leg_spread = g.slider("Leg Spread", "FLOAT", 0.15, 0.0, 0.8)
    disorder = g.slider("Disorder", "FLOAT", 0.25, 0.0, 1.0)
    sink = g.slider("Sink", "FLOAT", 0.0, 0.0, 0.3)
    facet = g.slider("Facet Jitter", "FLOAT", 0.006, 0.0, 0.05)

    M = lambda a, b: g.math("MULTIPLY", a, b)  # noqa: E731
    A = lambda a, b: g.math("ADD", a, b)  # noqa: E731
    S = lambda a, b: g.math("SUBTRACT", a, b)  # noqa: E731
    V = g.vec

    def h(f):
        """A share of the height, in metres."""
        return M(height, f)

    def thick(f):
        """A bone radius: a share of the height, times Build."""
        return M(h(f), build)

    part = itertools.count(FIRST_LIMB_PART)
    pieces = []
    offset_number = itertools.count(400)

    def jolt(span):
        """A random angle up to Disorder x span either way (one draw)."""
        neg = M(M(disorder, span), -1.0)
        return g.random("FLOAT", neg, M(disorder, span), seed, next(offset_number), fixed=True)

    def bone(a, b, r, mesh=None, colour=bk.BONE):
        pieces.append(bk.piece(g, mesh if mesh is not None else bk.shaft(g), a, b, r, next(part), colour,
                               overlap=M(r, 0.3)))

    def flat_dir(angle, side):
        """Along the ground, `angle` from straight toward the feet, out to `side`."""
        return V(M(side, g.math("SINE", angle)), M(g.math("COSINE", angle), -1.0), 0.0)

    def onward(p, d, length, z=None):
        out = g.vmath("ADD", p, g.vmath("SCALE", d, scale=length))
        if z is None:
            return out
        x, y, _z = g.xyz(out)
        return V(x, y, z)

    lie = lambda r: S(r, sink)  # noqa: E731  # a bone lying on the ground rests on its own radius

    neck_top = S(height, h(head))
    shoulder_y = S(neck_top, h(0.05))
    hip_y = h(leg)

    g.section("Skull")
    # A flat face lies face up, crown toward Height; a muzzle lies on its jaw
    # with the muzzle running on along the body.
    s = g.math("DIVIDE", h(head), 0.95)
    skull_geo = bk.skull(g, s, snout, brow, jaw_open, horns, horn_length, horn_curl, bk.tone(g, bk.BONE, 1.03),
                         SKULL_PART)
    tilt = jolt(0.3)
    face_up = bk.placed(g, skull_geo, V(-math.pi / 2, math.pi, tilt),
                        V(0.0, S(height, M(s, 0.45)), lie(M(s, 0.49))))
    muzzled = bk.placed(g, skull_geo, V(0.0, 0.0, tilt), V(0.0, A(neck_top, M(s, 0.5)), lie(M(s, 0.55))))
    is_muzzled = g.math("GREATER_THAN", snout, 0.3)
    not_muzzled = g.node("FunctionNodeBooleanMath", operation="NOT")
    g.link(is_muzzled, not_muzzled.inputs[0])
    pieces.append(sn.switch(g, not_muzzled.outputs[0], face_up))
    pieces.append(sn.switch(g, is_muzzled, muzzled))

    g.section("Spine")
    # From the top of the pelvis to the neck; the lower back thicker, the neck
    # thinner. Lying on its back, a spine's fins point into the ground, so
    # none are drawn.
    spine_r = thick(0.017)
    spine_from = A(hip_y, h(0.03))
    spine_span = S(neck_top, spine_from)
    sway = M(disorder, h(0.02))

    def point(t):
        return V(M(sway, g.math("SINE", M(t, 2.0 * math.pi))), A(spine_from, M(t, spine_span)), lie(size(t)))

    def tangent(t):
        return V(M(M(sway, 2.0 * math.pi), g.math("COSINE", M(t, 2.0 * math.pi))), spine_span, 0.0)

    def size(t):
        lumbar = M(g.math("MAXIMUM", S(1.0, g.math("DIVIDE", t, 0.35)), 0.0), 0.2)
        cervical = M(g.math("MAXIMUM", g.math("DIVIDE", S(t, 0.78), 0.22), 0.0), 0.35)
        return M(spine_r, S(A(1.0, lumbar), cervical))

    pieces.append(bk.vertebra_chain(g, vertebrae, point, tangent, size, VERTEBRA_PART,
                                    bk.tone(g, bk.BONE, 0.97)))

    g.section("Ribcage")
    rib_top = S(shoulder_y, h(0.025))
    rib_span = M(h(0.2), chest)
    rib_w = M(h(0.085), chest)
    rib_h = M(h(0.072), chest)
    rib_r = thick(0.008)
    pieces.append(bk.rib_arcs(g, seed, rib_pairs, lambda along: S(rib_top, M(along, rib_span)),
                              rib_w, rib_h, 2.5, rib_r, M(disorder, 0.3),
                              lambda y: 0.0, lambda y: lie(spine_r), bk.BONE, part_base=1, slump=-0.35, sides=3))
    top_z = M(rib_h, 1.75)
    bone(V(0.0, S(rib_top, h(0.01)), top_z), V(0.0, S(rib_top, M(rib_span, 0.6)), M(rib_h, 1.6)), thick(0.012),
         mesh=bk.taper(g, 4, 0.7))

    g.section("Shoulders and arms")
    sw = M(h(shoulders), 0.5)
    for side in (-1.0, 1.0):
        joint = V(M(side, sw), S(shoulder_y, h(0.015)), lie(thick(0.022)))
        # Collarbone from the top of the breastbone; shoulder blade flat
        # under the back.
        bone(V(M(side, h(0.02)), rib_top, M(rib_h, 1.6)), joint, thick(0.009))
        pieces.append(bk.blob(g, V(M(side, M(sw, 0.6)), S(shoulder_y, h(0.07)), lie(thick(0.012))),
                              V(h(0.05), h(0.065), thick(0.012)), next(part), bk.tone(g, bk.BONE, 0.95),
                              spin=M(side, 0.3)))
        length = h(arm)
        up_angle = A(arm_spread, jolt(0.3))
        upper = flat_dir(up_angle, side)
        elbow = onward(joint, upper, M(length, 0.42))
        bone(joint, elbow, thick(0.02))
        fore = flat_dir(A(up_angle, A(M(side, -0.15), jolt(0.6))), side)
        wrist = onward(elbow, fore, M(length, 0.34))
        # Two forearm bones side by side.
        across = V(M(g.math("COSINE", up_angle), side * 1.0), g.math("SINE", up_angle), 0.0)
        for offset in (-1.0, 1.0):
            nudge = g.vmath("SCALE", across, scale=M(h(0.008), offset))
            bone(g.vmath("ADD", elbow, nudge), g.vmath("ADD", wrist, nudge), thick(0.011))
        # The hand: a palm and three fingers fanning out.
        hand_len = M(length, 0.24)
        hand = flat_dir(A(up_angle, jolt(0.4)), side)
        knuckles = onward(wrist, hand, M(hand_len, 0.4))
        bone(wrist, knuckles, thick(0.02), mesh=bk.taper(g, 4, 0.8))
        for spread in (-0.3, 0.0, 0.3):
            finger = flat_dir(A(A(up_angle, jolt(0.3)), spread * side), side)
            bone(knuckles, onward(knuckles, finger, M(hand_len, 0.55)), thick(0.006), mesh=bk.taper(g, 3, 0.3))

    g.section("Pelvis and legs")
    # The pelvis: a sacrum on the spine, two flared hip wings, and the pubic
    # bar across the front.
    bone(V(0.0, A(hip_y, h(0.06)), lie(thick(0.03))), V(0.0, S(hip_y, h(0.03)), lie(thick(0.025))), thick(0.03),
         mesh=bk.taper(g, 4, 0.5))
    hip_x = M(h(hips), 0.4)
    for side in (-1.0, 1.0):
        pieces.append(bk.blob(g, V(M(side, M(h(hips), 0.32)), A(hip_y, h(0.04)), lie(thick(0.025))),
                              V(M(h(0.05), build), h(0.055), thick(0.022)), next(part), bk.BONE, spin=M(side, 0.4)))
    bone(V(M(hip_x, -0.6), S(hip_y, h(0.02)), h(0.05)), V(M(hip_x, 0.6), S(hip_y, h(0.02)), h(0.05)), thick(0.012))
    for side in (-1.0, 1.0):
        joint = V(M(side, hip_x), hip_y, lie(thick(0.024)))
        spread_a = A(leg_spread, jolt(0.15))
        reach = S(hip_y, h(0.04))
        # Plantigrade: thigh and shin share the leg, the foot falls outward
        # off the heel. Digitigrade: thigh, shin and a long foot bone, bent
        # back and forth, standing on the toes.
        plant_knee = onward(joint, flat_dir(spread_a, side), M(reach, 0.5))
        plant_ankle = onward(plant_knee, flat_dir(A(spread_a, jolt(0.3)), side), M(reach, 0.5))
        digi_knee = onward(joint, flat_dir(spread_a, side), M(reach, 0.4))
        digi_hock = onward(digi_knee, flat_dir(A(spread_a, M(side, -0.25)), side), M(reach, 0.36))
        digi_toe = onward(digi_hock, flat_dir(A(spread_a, M(side, 0.2)), side), M(reach, 0.24))

        def legs(knee, ankle):
            out = []
            n0 = len(pieces)
            bone(joint, knee, thick(0.023))
            bone(knee, ankle, thick(0.019))
            # The fibula beside the shin.
            beside = V(h(0.012 * side), 0.0, 0.0)
            bone(g.vmath("ADD", knee, beside), g.vmath("ADD", ankle, beside), thick(0.008))
            out.extend(pieces[n0:])
            del pieces[n0:]
            return out

        plant = legs(plant_knee, plant_ankle)
        n0 = len(pieces)
        foot = g.vmath("NORMALIZE", V(side * 0.6, -0.25, 0.75))
        bone(plant_ankle, onward(plant_ankle, foot, h(0.14)), thick(0.02), mesh=bk.taper(g, 4, 0.5))
        plant.extend(pieces[n0:])
        del pieces[n0:]
        digi = legs(digi_knee, digi_hock)
        n0 = len(pieces)
        bone(digi_hock, digi_toe, thick(0.016))
        toe = g.vmath("NORMALIZE", V(side * 0.5, -0.3, 0.8))
        bone(digi_toe, onward(digi_toe, toe, h(0.05)), thick(0.014), mesh=bk.taper(g, 4, 0.4))
        digi.extend(pieces[n0:])
        del pieces[n0:]
        not_digi = g.node("FunctionNodeBooleanMath", operation="NOT")
        g.link(digitigrade, not_digi.inputs[0])
        pieces.append(sn.switch(g, not_digi.outputs[0], sn.join(g, *plant)))
        pieces.append(sn.switch(g, digitigrade, sn.join(g, *digi)))

    g.section("Tail")
    # From under the sacrum toward the feet, curving to one side, thinning to
    # a third.
    tail_from = S(hip_y, h(0.05))
    tail_len = h(tail_length)
    swing = M(M(tail_len, 0.25), g.random("FLOAT", -1.0, 1.0, seed, 140, fixed=True))
    tail_r = thick(0.014)

    def t_point(t):
        return V(M(swing, g.math("SINE", M(t, math.pi))), S(tail_from, M(t, tail_len)), lie(t_size(t)))

    def t_tangent(t):
        return V(M(M(swing, math.pi), g.math("COSINE", M(t, math.pi))), M(tail_len, -1.0), 0.0)

    def t_size(t):
        return M(tail_r, S(1.0, M(t, 0.65)))

    pieces.append(bk.vertebra_chain(g, tail, t_point, t_tangent, t_size, TAIL_PART, bk.tone(g, bk.BONE, 0.97)))

    g.section("Centre, turn and facets")
    # Centred on the middle of the body, then turned a quarter round so the
    # body runs along X (a side preview then shows it lying).
    body = sn.join(g, *pieces)
    px, py, pz = g.xyz(g.position())
    body = sn.at(g, body, V(S(py, M(height, 0.5)), M(px, -1.0), pz))
    body = sn.jitter(g, body, facet, seed, 141)
    return g.finish(sn.keep_colour(g, sn.flat_shaded(g, body)))


BUILDERS = {"skeleton": build_skeleton}
SPACING = {"skeleton": 4.0}

sn.build_main(BUILDERS, SPACING, "gen_skeleton.py")
