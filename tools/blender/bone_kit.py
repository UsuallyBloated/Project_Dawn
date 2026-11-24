# The bone kit: the pieces every bone generator builds from (gen_bones.py for
# beast piles, gen_skeleton.py for humanoid skeletons).
#
# A piece is a unit mesh along +Z from the origin, stretched between two
# points. A skull is built in its own frame (+Y the way the face looks, +Z
# the crown) and placed by the generator. Every piece carries a "part" number
# (one solid each for the obstacle bake) and a flat placeholder "Col"; small
# details on a bigger piece (eye sockets, teeth, the brow) are part -1, drawn
# with no solid of their own.
#
# Runs inside Blender (bpy), through scenery_nodes.

import math

import scenery_nodes as sn

BONE = (0.84, 0.81, 0.70, 1.0)
HORN = (0.40, 0.36, 0.30, 1.0)
SOCKET = (0.22, 0.19, 0.16, 1.0)

# Skull part numbers (a generator adds its own base).
CRANIUM, MUZZLE, JAW = 0, 1, 2
HORN_PARTS = 10   # 10.. horn segments
ANTLER_PARTS = 30  # 30.. antler beam and tines


def tone(g, colour, scale):
    """`colour` (an RGBA tuple or a socket) lightened or darkened by `scale`."""
    base = g.vec(*colour[:3]) if isinstance(colour, tuple) else colour
    return g.vmath("SCALE", base, scale=scale)


def shaft(g, sides=4):
    """A unit long bone: a column whose middle ring is pinched in, so it reads
    as a shaft with knobbed ends."""
    mesh = sn.with_uv(g, sn.cone_standing(g, sides, 1.0, 1.0, 1.0, side_segments=2))
    x, y, z = g.xyz(g.position())
    pinch = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", g.math("COMPARE", z, 0.5, 0.01), 0.45))
    return sn.at(g, mesh, g.vec(g.math("MULTIPLY", x, pinch), g.math("MULTIPLY", y, pinch), z))


def taper(g, sides, top, fill="NGON"):
    """A unit tapered column: radius 1 at the root to `top` at the tip."""
    return sn.with_uv(g, sn.cone_standing(g, sides, 1.0, top, 1.0, fill=fill))


def ball(g):
    ico = g.node("GeometryNodeMeshIcoSphere")
    ico.inputs["Radius"].default_value = 1.0
    ico.inputs["Subdivisions"].default_value = 1
    return sn.with_uv(g, ico)


def piece(g, mesh, a, b, r, part, colour, overlap=0.0):
    """`mesh` stretched from point a to point b (single values), `r` thick,
    running `overlap` past each end so joints show no gap."""
    run = g.vmath("SUBTRACT", b, a)
    d = g.vmath("NORMALIZE", run)
    length = g.math("ADD", g.math("SQRT", g.dot(run, run)), g.math("MULTIPLY", overlap, 2.0))
    start = g.vmath("SUBTRACT", a, g.vmath("SCALE", d, scale=overlap))
    inst = sn.instance_on(g, sn.at(g, sn.one_point(g), start), mesh, sn.facing(g, d), g.vec(r, r, length))
    return sn.dressed(g, inst, part, colour)


def blob(g, centre, radii, part, colour, spin=0.0):
    """A squashed icosphere at `centre` with radii (x, y, z)."""
    inst = sn.instance_on(g, sn.at(g, sn.one_point(g), centre), ball(g), g.vec(z=spin), radii)
    return sn.dressed(g, inst, part, colour)


def vertebra_chain(g, count, point, tangent, size, part_base, colour, fins=None, fin_up=None):
    """`count` vertebrae: number v sits at point(s) for s = (v + 0.5) / count,
    turned along tangent(s), size(s) thick, with a gap to the next. With
    `fins` (a bool socket) each carries a fin raked from `fin_up` toward its
    tail. Each vertebra (with its fin) is one part, from `part_base`."""
    knots = sn.line(g, count)
    v = g.index()
    s = g.math("DIVIDE", g.math("ADD", v, 0.5), count)
    where = point(s)
    along = g.vmath("NORMALIZE", tangent(s))
    vr = size(s)
    gap = g.math("DIVIDE", g.math("SQRT", g.dot(tangent(s), tangent(s))), count)
    body_len = g.math("MULTIPLY", gap, 0.62)
    body_at = g.vmath("SUBTRACT", where, g.vmath("SCALE", along, scale=g.math("MULTIPLY", body_len, 0.5)))
    wide = g.math("MULTIPLY", vr, 1.3)
    bodies = sn.instance_on(g, sn.at(g, knots, body_at), taper(g, 4, 0.9), sn.facing(g, along),
                            g.vec(wide, wide, body_len))
    part = g.math("ADD", v, float(part_base))
    out = sn.dressed(g, bodies, part, colour)
    if fins is not None:
        rake = g.vmath("NORMALIZE", g.vmath("SUBTRACT", fin_up, g.vmath("SCALE", along, scale=0.35)))
        fin_r = g.math("MULTIPLY", vr, 0.55)
        finned = sn.instance_on(g, sn.at(g, knots, where), taper(g, 3, 0.0), sn.facing(g, rake),
                                g.vec(fin_r, fin_r, g.math("MULTIPLY", vr, 2.4)), selection=fins)
        out = sn.join(g, out, sn.dressed(g, finned, part, colour))
    return out


def rib_arcs(g, seed, pairs, y_of, width, height, curl, thickness, disorder, base_x, base_z, colour,
             part_base=1, slump=0.0, segments=3, sides=4, seed_base=120):
    """Ribs in pairs, curling up from a spine and back in at the top: rib
    point at angle a is (side x width x sin a, y, height x (1 - cos a)), run
    from 0 to `curl`. `y_of(along)` places pair k (along = (k + 0.5) /
    pairs); ribs shrink toward both ends of the cage. `base_x(y)` and
    `base_z(y)` are where the spine is at y. `slump` (a share of the rib's
    height) leans every rib along the spine; Disorder knocks each one out of
    line on top. Each segment is one part, from `part_base`."""
    pts = sn.line(g, g.math("MULTIPLY", pairs, 2.0 * segments))
    i = g.index()
    rib = g.math("FLOOR", g.math("DIVIDE", i, float(segments)))
    k = g.math("FLOOR", g.math("DIVIDE", rib, 2.0))
    side = g.math("SUBTRACT", g.math("MULTIPLY", g.math("SUBTRACT", rib, g.math("MULTIPLY", k, 2.0)), 2.0), 1.0)
    j = g.math("SUBTRACT", i, g.math("MULTIPLY", rib, float(segments)))
    along = g.math("DIVIDE", g.math("ADD", k, 0.5), g.math("MAXIMUM", pairs, 1.0))
    middling = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", 0.45, g.math("ABSOLUTE", g.math("SUBTRACT", g.math("MULTIPLY", along, 2.0), 1.0))))
    neg_d = g.math("MULTIPLY", disorder, -1.0)
    knock = g.math("ADD", 1.0, g.random("FLOAT", neg_d, disorder, seed, seed_base, id=rib))
    w = g.math("MULTIPLY", g.math("MULTIPLY", width, middling), knock)
    h = g.math("MULTIPLY", g.math("MULTIPLY", height, middling), knock)
    y = g.math("ADD", y_of(along), g.math("MULTIPLY", g.random("FLOAT", neg_d, disorder, seed, seed_base + 1, id=rib),
                                            g.math("MULTIPLY", thickness, 3.0)))
    lean = g.math("MULTIPLY", g.math("ADD", slump, g.random("FLOAT", neg_d, disorder, seed, seed_base + 2, id=rib)), h)
    rx = base_x(y)
    rz = base_z(y)

    def rib_point(step):
        a = g.math("MULTIPLY", curl, g.math("DIVIDE", step, float(segments)))
        rise = g.math("SUBTRACT", 1.0, g.math("COSINE", a))
        return g.vec(g.math("ADD", rx, g.math("MULTIPLY", g.math("MULTIPLY", side, w), g.math("SINE", a))),
                     g.math("ADD", y, g.math("MULTIPLY", lean, rise)),
                     g.math("ADD", g.math("MULTIPLY", h, rise), rz))

    a_pt = rib_point(j)
    run = g.vmath("SUBTRACT", rib_point(g.math("ADD", j, 1.0)), a_pt)
    d = g.vmath("NORMALIZE", run)
    seg_r = g.math("MULTIPLY", thickness, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", 0.15, j)))
    seg_len = g.math("ADD", g.math("SQRT", g.dot(run, run)), seg_r)
    start = g.vmath("SUBTRACT", a_pt, g.vmath("SCALE", d, scale=g.math("MULTIPLY", seg_r, 0.5)))
    # Open-ended segments: their ends are inside the spine or the next one.
    ribs = sn.instance_on(g, sn.at(g, pts, start), taper(g, sides, 0.85, fill="NONE"), sn.facing(g, d),
                          g.vec(seg_r, seg_r, seg_len))
    return sn.dressed(g, ribs, g.math("ADD", i, float(part_base)), tone(g, colour, g.random("FLOAT", 0.92, 1.02, seed, seed_base + 3)))


def _p(g, s, x, y, z):
    """The point (x, y, z) in units of the skull size `s`."""
    def one(v):
        return v if not isinstance(v, (int, float)) else float(v)
    return g.vec(g.math("MULTIPLY", s, one(x)), g.math("MULTIPLY", s, one(y)), g.math("MULTIPLY", s, one(z)))


def skull(g, s, snout, brow, jaw_open, horns, horn_length, horn_curl, colour, part_base):
    """A skull `s` long, in its own frame: +Y the way it faces, +Z its crown,
    its cranium's middle at the origin.

    A rounded cranium; a face that runs forward into a muzzle as Snout goes
    from 0 (a flat human face) to 1 (a long beast's muzzle); a lower jaw
    under it, dropped open by Jaw Open (a share of its length); dark eye
    sockets, set further back and apart on a muzzle; a brow ridge that juts
    with Brow; teeth along a muzzle. Horns 1 grows a pair of curving horns
    (Horn Curl, radians of curl), 2 a pair of antlers with tines."""
    sock = g.math("MULTIPLY", snout, 0.25)
    cranium = blob(g, _p(g, s, 0.0, -0.05, 0.05), g.vec(g.math("MULTIPLY", s, 0.36), g.math("MULTIPLY", s, 0.44),
                                                          g.math("MULTIPLY", s, 0.4)), part_base + CRANIUM, colour)
    # The face: from under the cranium's front to the muzzle's end.
    reach = g.math("ADD", 0.38, g.math("MULTIPLY", snout, 0.95))
    face_a = _p(g, s, 0.0, 0.12, -0.18)
    face_b = _p(g, s, 0.0, reach, g.math("SUBTRACT", -0.22, g.math("MULTIPLY", snout, 0.08)))
    face_r = g.math("MULTIPLY", s, g.math("SUBTRACT", 0.2, g.math("MULTIPLY", snout, 0.04)))
    face = piece(g, taper(g, 4, 0.45), face_a, face_b, face_r, part_base + MUZZLE, colour)
    # The lower jaw hangs from under the cranium to just short of the face's
    # end, dropped open by Jaw Open.
    jaw_len = g.math("MULTIPLY", reach, 0.85)
    jaw_a = _p(g, s, 0.0, 0.0, -0.36)
    jaw_b = _p(g, s, 0.0, jaw_len, g.math("SUBTRACT", g.math("SUBTRACT", -0.42, g.math("MULTIPLY", snout, 0.05)),
                                                       g.math("MULTIPLY", jaw_open, jaw_len)))
    jaw = piece(g, taper(g, 4, 0.55), jaw_a, jaw_b, g.math("MULTIPLY", s, 0.12), part_base + JAW,
                tone(g, colour, 0.95))
    # Eye sockets: dark points sunk into the cranium's front, further back
    # and apart on a beast.
    sockets = []
    for side in (-1.0, 1.0):
        at = _p(g, s, g.math("MULTIPLY", side, g.math("ADD", 0.17, g.math("MULTIPLY", snout, 0.1))),
                g.math("SUBTRACT", 0.33, sock), g.math("ADD", -0.02, g.math("MULTIPLY", snout, 0.08)))
        inward = g.vec(g.math("MULTIPLY", side, -0.4), -1.0, 0.0)
        sockets.append(sn.dressed(g, sn.instance_on(g, sn.at(g, sn.one_point(g), at), taper(g, 3, 0.0),
                                                    sn.facing(g, inward),
                                                    g.vec(g.math("MULTIPLY", s, 0.1), g.math("MULTIPLY", s, 0.1),
                                                          g.math("MULTIPLY", s, 0.12))), -1, SOCKET))
    # The brow: a bar across the cranium's front, thicker and further out
    # with Brow.
    brow_y = g.math("SUBTRACT", g.math("ADD", 0.34, g.math("MULTIPLY", brow, 0.06)), sock)
    brow_r = g.math("MULTIPLY", s, g.math("ADD", 0.03, g.math("MULTIPLY", brow, 0.06)))
    ridge = piece(g, taper(g, 4, 1.0), _p(g, s, -0.24, brow_y, 0.1), _p(g, s, 0.24, brow_y, 0.1), brow_r, -1, colour)
    # Teeth: three a side under a muzzle (none on a flat face).
    teeth = []
    for k in range(3):
        f = 0.45 + 0.17 * k
        for side in (-1.0, 1.0):
            root = _p(g, s, side * 0.08, g.math("MULTIPLY", reach, f),
                      g.math("SUBTRACT", -0.3, g.math("MULTIPLY", snout, 0.08)))
            tooth = sn.instance_on(g, sn.at(g, sn.one_point(g), root), taper(g, 3, 0.0), sn.facing(g, g.vec(z=-1.0)),
                                   g.vec(g.math("MULTIPLY", s, 0.035), g.math("MULTIPLY", s, 0.035),
                                         g.math("MULTIPLY", s, 0.1)), selection=g.math("GREATER_THAN", snout, 0.3))
            teeth.append(sn.dressed(g, tooth, -1, tone(g, BONE, 1.05)))

    parts = [cranium, face, jaw, ridge] + sockets + teeth

    # Horns: four tapering segments a side along an arc that leaves the
    # cranium outward, then curls up and forward: point at angle a is
    # base + R x (side x sin a, 0.75 (1 - cos a), 0.7 (1 - cos a)), with R
    # chosen so the arc is Horn Length long.
    curl = g.math("MAXIMUM", horn_curl, 0.2)
    radius = g.math("DIVIDE", g.math("MULTIPLY", horn_length, s), curl)
    horn_pieces = []
    for side_i, side in enumerate((-1.0, 1.0)):
        base = _p(g, s, side * 0.3, -0.05, 0.3)

        def arc(a):
            rise = g.math("SUBTRACT", 1.0, g.math("COSINE", a))
            return g.vmath("ADD", base, g.vmath("SCALE", g.vec(g.math("MULTIPLY", side, g.math("SINE", a)),
                                                               g.math("MULTIPLY", rise, 0.75),
                                                               g.math("MULTIPLY", rise, 0.7)), scale=radius))
        for j in range(4):
            a0 = g.math("MULTIPLY", curl, j / 4.0)
            a1 = g.math("MULTIPLY", curl, (j + 1) / 4.0)
            r = g.math("MULTIPLY", s, 0.15 * (1.0 - 0.72 * j / 4.0))
            mesh = taper(g, 5, 0.0 if j == 3 else 0.75)
            horn_pieces.append(piece(g, mesh, arc(a0), arc(a1), r, part_base + HORN_PARTS + side_i * 4 + j, HORN,
                                     overlap=g.math("MULTIPLY", r, 0.3)))
    # Antlers: a beam rising up, out and back from the crown in three
    # segments, along base + L x (side 0.45 t, -0.35 t + 0.3 t^2, 0.9 t - 0.15 t^2),
    # with tines growing forward and up from it.
    antler_pieces = []
    beam_len = g.math("MULTIPLY", horn_length, s)
    for side_i, side in enumerate((-1.0, 1.0)):
        base = _p(g, s, side * 0.16, -0.12, 0.36)

        def beam(t):
            return g.vmath("ADD", base, g.vmath("SCALE", g.vec(side * 0.45 * t, -0.35 * t + 0.3 * t * t,
                                                               0.9 * t - 0.15 * t * t), scale=beam_len))
        for j in range(3):
            r = g.math("MULTIPLY", s, 0.07 * (1.0 - 0.5 * j / 3.0))
            antler_pieces.append(piece(g, taper(g, 4, 0.0 if j == 2 else 0.8), beam(j / 3.0), beam((j + 1) / 3.0), r,
                                       part_base + ANTLER_PARTS + side_i * 8 + j, tone(g, BONE, 0.9),
                                       overlap=g.math("MULTIPLY", r, 0.3)))
        for n, t in enumerate((0.12, 0.45, 0.75)):
            root = beam(t)
            tip = g.vmath("ADD", root, g.vmath("SCALE", g.vmath("NORMALIZE", g.vec(side * 0.15, 0.75, 0.65)),
                                               scale=g.math("MULTIPLY", beam_len, 0.32 * (1.0 - 0.3 * t))))
            r = g.math("MULTIPLY", s, 0.04)
            antler_pieces.append(piece(g, taper(g, 3, 0.0), root, tip, r,
                                       part_base + ANTLER_PARTS + side_i * 8 + 3 + n, tone(g, BONE, 0.9)))
    horned = sn.switch(g, g.math("COMPARE", horns, 1.0, 0.01), sn.join(g, *horn_pieces))
    antlered = sn.switch(g, g.math("COMPARE", horns, 2.0, 0.01), sn.join(g, *antler_pieces))
    return sn.join(g, *parts, horned, antlered)


def placed(g, geometry, rotation, translation):
    """The geometry turned by `rotation` (Euler radians, a vector) about the
    origin, then moved by `translation`."""
    n = g.node("GeometryNodeTransform")
    g.link(geometry, n.inputs["Geometry"])
    g.link(rotation, n.inputs["Rotation"])
    g.link(translation, n.inputs["Translation"])
    return n.outputs["Geometry"]
