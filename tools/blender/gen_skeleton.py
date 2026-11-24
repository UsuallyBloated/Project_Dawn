# The humanoid skeleton generator: the bones of a fallen adventurer, built by
# code as a Geometry Nodes group from the pieces in bone_kit.py.
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
# legs and a tail are all sliders, and so is the pose (on the back, curled on
# a side, face down, slumped sitting, and everything between).
#
# Every piece is its own solid ("part"; distinct, not consecutive: ribs from
# 1, vertebrae from 100, the tail from 150, the skull from 200, everything
# else from 300), judged on its own by the obstacle bake, so a body steps over
# the low ones. "Col" is a flat placeholder colour; "UVMap" is laid out for
# the texture pass.

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
    """The skeleton is built in a body frame: lying on its back along +Y
    (soles at 0, crown at Height), +Z the way its chest faces. Proportions
    are shares of Height, the human ones from the usual figure-drawing canon
    (a head about 1/7.5 of the height, the hip joint a little above half, an
    arm about 0.44): Head, Leg (the hip joint's height), Arm, Shoulders and
    Hips move them per race. Build thickens every bone; Chest widens and
    deepens the ribcage. Snout grows a muzzle (and then the skull rests on
    its jaw, muzzle along the body, instead of face up); Horns and Brow come
    from the skull kit. Digitigrade legs stand on the toes: a long foot bone
    continues the leg. Tail adds tail vertebrae.

    The pose, in four steps:
    - Limbs bend in 3D: Hip Bend raises the thighs toward the chest, Knee
      Bend folds the shins back; Arm Spread opens the arms out from the body
      (pi points them past the head), Arm Lift raises them toward the chest,
      Elbow Bend folds the forearms forward. Asymmetry opens one arm and
      closes the other; Stride draws one thigh up and lets the other lie out
      (for a body on its side: on its back or front a raised thigh would
      lift a foot, or the whole body, off the ground).
    - Curl bends the body forward at the waist over Curl Span of the torso
      (half pi sits it up; more slumps it over its legs; with a long span the
      whole back rounds, as when curled up).
    - Roll turns the whole body about its own length: 0 on its back, half
      pi on its side, pi face down. Head Roll turns the skull the same way
      on its own.
    - The body drops until its lowest bone rests on the ground; Sink then
      lowers it into the ground."""
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
    tail_curl = g.slider("Tail Curl", "FLOAT", 0.25, -1.0, 1.0)
    arm_spread = g.slider("Arm Spread", "FLOAT", 0.45, 0.0, 3.1)
    arm_lift = g.slider("Arm Lift", "FLOAT", 0.0, -0.5, 1.6)
    elbow_bend = g.slider("Elbow Bend", "FLOAT", 0.15, 0.0, 2.4)
    leg_spread = g.slider("Leg Spread", "FLOAT", 0.15, 0.0, 0.8)
    hip_bend = g.slider("Hip Bend", "FLOAT", 0.0, -0.3, 2.0)
    knee_bend = g.slider("Knee Bend", "FLOAT", 0.1, 0.0, 2.6)
    asymmetry = g.slider("Asymmetry", "FLOAT", 0.0, -1.5, 1.5)
    stride = g.slider("Stride", "FLOAT", 0.0, -1.5, 1.5)
    curl = g.slider("Curl", "FLOAT", 0.0, 0.0, 2.6)
    curl_span = g.slider("Curl Span", "FLOAT", 0.3, 0.1, 1.0)
    roll = g.slider("Roll", "FLOAT", 0.0, -3.2, 3.2)
    head_roll = g.slider("Head Roll", "FLOAT", 0.0, -3.2, 3.2)
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

    def limb_dir(spread, lift, side):
        """A limb's way in the body frame: `spread` radians out from straight
        toward the feet (to `side`), then `lift` radians up toward the chest."""
        return V(M(M(side, g.math("SINE", spread)), g.math("COSINE", lift)),
                 M(M(g.math("COSINE", spread), g.math("COSINE", lift)), -1.0),
                 g.math("SINE", lift))

    def onward(p, d, length):
        return g.vmath("ADD", p, g.vmath("SCALE", d, scale=length))

    def lie(r):
        """The height a bone lying on the ground (in the body frame) rests at."""
        return r

    neck_top = S(height, h(head))
    shoulder_y = S(neck_top, h(0.05))
    hip_y = h(leg)

    g.section("Skull")
    # A flat face lies face up, crown toward Height; a muzzle rests on its jaw
    # with the muzzle running on along the body. Head Roll turns either about
    # the body's length.
    s = g.math("DIVIDE", h(head), 0.95)
    skull_geo = bk.skull(g, s, snout, brow, jaw_open, horns, horn_length, horn_curl, bk.tone(g, bk.BONE, 1.03),
                         SKULL_PART)
    tilt = jolt(0.3)
    face_up = bk.placed(g, skull_geo, V(-math.pi / 2, A(math.pi, head_roll), tilt),
                        V(0.0, S(height, M(s, 0.45)), lie(M(s, 0.49))))
    muzzled = bk.placed(g, skull_geo, V(0.0, head_roll, tilt), V(0.0, A(neck_top, M(s, 0.5)), lie(M(s, 0.55))))
    is_muzzled = g.math("GREATER_THAN", snout, 0.3)
    not_muzzled = g.node("FunctionNodeBooleanMath", operation="NOT")
    g.link(is_muzzled, not_muzzled.inputs[0])
    pieces.append(sn.switch(g, not_muzzled.outputs[0], face_up))
    pieces.append(sn.switch(g, is_muzzled, muzzled))

    g.section("Spine")
    # From the top of the pelvis to the neck; the lower back thicker, the neck
    # thinner. A spine's fins point into the back, so none are drawn.
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
    bone(V(0.0, S(rib_top, h(0.01)), M(rib_h, 1.75)), V(0.0, S(rib_top, M(rib_span, 0.6)), M(rib_h, 1.6)),
         thick(0.012), mesh=bk.taper(g, 4, 0.7))

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
        # Asymmetry opens one arm and closes the other.
        spread = A(A(arm_spread, M(asymmetry, side)), jolt(0.3))
        lift = A(arm_lift, jolt(0.2))
        elbow = onward(joint, limb_dir(spread, lift, side), M(length, 0.42))
        bone(joint, elbow, thick(0.02))
        fore_spread = A(spread, jolt(0.5))
        fore_lift = A(lift, A(elbow_bend, jolt(0.3)))
        wrist = onward(elbow, limb_dir(fore_spread, fore_lift, side), M(length, 0.34))
        # Two forearm bones side by side, a little apart across the arm.
        across = V(M(g.math("COSINE", fore_spread), side), g.math("SINE", fore_spread), 0.0)
        for offset in (-1.0, 1.0):
            nudge = g.vmath("SCALE", across, scale=M(h(0.008), offset))
            bone(g.vmath("ADD", elbow, nudge), g.vmath("ADD", wrist, nudge), thick(0.011))
        # The hand: a palm and three fingers fanning out.
        hand_len = M(length, 0.24)
        knuckles = onward(wrist, limb_dir(A(fore_spread, jolt(0.4)), fore_lift, side), M(hand_len, 0.4))
        bone(wrist, knuckles, thick(0.02), mesh=bk.taper(g, 4, 0.8))
        for fan in (-0.3, 0.0, 0.3):
            finger = limb_dir(A(A(fore_spread, jolt(0.3)), fan * side), A(fore_lift, jolt(0.4)), side)
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
    not_digi = g.node("FunctionNodeBooleanMath", operation="NOT")
    g.link(digitigrade, not_digi.inputs[0])
    for side in (-1.0, 1.0):
        joint = V(M(side, hip_x), hip_y, lie(thick(0.024)))
        spread = A(leg_spread, jolt(0.15))
        # Stride draws one knee up and lets the other leg lie out.
        thigh_lift = A(A(hip_bend, M(stride, side * 0.5)), jolt(0.15))
        shin_lift = A(S(thigh_lift, knee_bend), jolt(0.2))
        reach = S(hip_y, h(0.04))

        def leg_bones(knee, ankle):
            """Thigh, shin and the fibula beside it, as one list of pieces."""
            n0 = len(pieces)
            bone(joint, knee, thick(0.023))
            bone(knee, ankle, thick(0.019))
            beside = V(h(0.012 * side), 0.0, 0.0)
            bone(g.vmath("ADD", knee, beside), g.vmath("ADD", ankle, beside), thick(0.008))
            out = pieces[n0:]
            del pieces[n0:]
            return out

        # Plantigrade: thigh and shin share the leg; the foot leaves the
        # ankle a quarter turn up from the shin, splayed outward.
        knee = onward(joint, limb_dir(spread, thigh_lift, side), M(reach, 0.5))
        ankle = onward(knee, limb_dir(A(spread, jolt(0.3)), shin_lift, side), M(reach, 0.5))
        plant = leg_bones(knee, ankle)
        n0 = len(pieces)
        bone(ankle, onward(ankle, limb_dir(A(spread, 0.5), A(shin_lift, math.pi / 2), side), h(0.14)), thick(0.02),
             mesh=bk.taper(g, 4, 0.5))
        plant.extend(pieces[n0:])
        del pieces[n0:]
        # Digitigrade: thigh, shin and a long foot bone, bent back and forth,
        # standing on the toes.
        d_knee = onward(joint, limb_dir(spread, thigh_lift, side), M(reach, 0.4))
        d_hock = onward(d_knee, limb_dir(S(spread, 0.25), S(shin_lift, 0.3), side), M(reach, 0.36))
        digi = leg_bones(d_knee, d_hock)
        n0 = len(pieces)
        d_toe = onward(d_hock, limb_dir(A(spread, 0.2), A(shin_lift, 0.3), side), M(reach, 0.24))
        bone(d_hock, d_toe, thick(0.016))
        bone(d_toe, onward(d_toe, limb_dir(A(spread, 0.4), A(shin_lift, 1.3), side), h(0.05)), thick(0.014),
             mesh=bk.taper(g, 4, 0.4))
        digi.extend(pieces[n0:])
        del pieces[n0:]
        pieces.append(sn.switch(g, not_digi.outputs[0], sn.join(g, *plant)))
        pieces.append(sn.switch(g, digitigrade, sn.join(g, *digi)))

    g.section("Tail")
    # From under the sacrum toward the feet, curving to one side by Tail
    # Curl, thinning to a third.
    tail_from = S(hip_y, h(0.05))
    tail_len = h(tail_length)
    swing = M(tail_len, tail_curl)
    tail_r = thick(0.014)

    def t_point(t):
        return V(M(swing, g.math("SINE", M(t, math.pi * 0.75))), S(tail_from, M(t, tail_len)), lie(t_size(t)))

    def t_tangent(t):
        return V(M(M(swing, math.pi * 0.75), g.math("COSINE", M(t, math.pi * 0.75))), M(tail_len, -1.0), 0.0)

    def t_size(t):
        return M(tail_r, S(1.0, M(t, 0.65)))

    pieces.append(bk.vertebra_chain(g, tail, t_point, t_tangent, t_size, TAIL_PART, bk.tone(g, bk.BONE, 0.97)))

    g.section("Curl at the waist")
    # A bend toward the chest (+Z), starting at the hip joints: over the
    # first Curl Span of the torso the body follows an arc turning through
    # Curl radians; above that it carries straight on. A point d above the
    # hips and z off the back goes to the arc of radius R - z (R = span /
    # Curl) at angle Curl x d / span, plus whatever of d is past the span
    # along the arc's end. Below the hips nothing moves.
    body = sn.join(g, *pieces)
    px, py, pz = g.xyz(g.position())
    span = M(S(neck_top, hip_y), curl_span)
    bend = g.math("MAXIMUM", curl, 0.001)
    radius = g.math("DIVIDE", span, bend)
    d = g.math("MAXIMUM", S(py, hip_y), 0.0)
    d_arc = g.math("MINIMUM", d, span)
    beyond = S(d, d_arc)
    angle = M(bend, g.math("DIVIDE", d_arc, span))
    r = S(radius, pz)
    cos_a, sin_a = g.math("COSINE", angle), g.math("SINE", angle)
    curled_y = A(A(hip_y, M(r, sin_a)), M(beyond, cos_a))
    curled_z = A(S(radius, M(r, cos_a)), M(beyond, sin_a))
    above = g.math("GREATER_THAN", py, hip_y)
    body = sn.at(g, body, V(px, A(py, M(above, S(curled_y, py))), A(pz, M(above, S(curled_z, pz)))))

    g.section("Roll, drop to the ground, centre")
    body = bk.placed(g, body, V(0.0, roll, 0.0), V(0.0, 0.0, 0.0))
    low = sn.statistic(g, body, g.position(), "Min")
    high = sn.statistic(g, body, g.position(), "Max")
    lx, ly, lz = g.xyz(low)
    hx, hy, _hz = g.xyz(high)
    # Lowest bone on the ground (then Sink), the footprint's middle on the
    # origin, then a quarter turn so a side preview shows it lying lengthwise.
    body = sn.offset(g, body, V(M(A(lx, hx), -0.5), M(A(ly, hy), -0.5), M(A(lz, sink), -1.0)))
    qx, qy, qz = g.xyz(g.position())
    body = sn.at(g, body, V(qy, M(qx, -1.0), qz))
    body = sn.jitter(g, body, facet, seed, 141)
    return g.finish(sn.keep_colour(g, sn.flat_shaded(g, body)))


BUILDERS = {"skeleton": build_skeleton}
SPACING = {"skeleton": 4.0}

# Run as a script it builds a kind; export_scenery.py imports BUILDERS instead.
if __name__ == "__main__":
    sn.build_main(BUILDERS, SPACING, "gen_skeleton.py")
