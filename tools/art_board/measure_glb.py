"""Measure a model's real height from its GLB, and compare it with the race's target.

The review loop's step 5 check: a model's height decides whether it fits next to the other
races, and a number judges that better than a picture. Reads the vertex data itself (standard
library only), applies every node's transform, and reports the world-space bounds of what the
game would draw.

Usage:
  python tools/art_board/measure_glb.py <model.glb> [--subject gnome/male] [--hide NAME ...] [--record]

  --subject  compares the height with creature_heights.md for that race (the part before "/")
  --hide     node names to leave out with everything under them (modelling scaffolds,
             reference planes), as race_model.gd's hide_nodes does in the game
  --record   writes the measured height into the subject's review.json (model.measured_height_m),
             which the Art Board shows on the card and uses in the lineup
"""

import json
import os
import struct
import sys

BOARD_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BOARD_DIR)

COMPONENT = {5120: ("b", 1, 127.0), 5121: ("B", 1, 255.0), 5122: ("h", 2, 32767.0),
             5123: ("H", 2, 65535.0), 5126: ("f", 4, None)}
TOLERANCE = 0.02  # same as the board: 2% outside the range still passes
# The low-poly budget for a character's bare body (user, 2026-10-15); equipment is extra. Same
# number as TRIANGLE_BUDGET in .claude/hooks/meshy_client.py, which asks Meshy for half as many
# four-sided polygons (each is drawn as two triangles).
BODY_TRIANGLE_BUDGET = 2000


class GlbError(Exception):
    pass


def load_glb(path: str) -> tuple:
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 12 or data[:4] != b"glTF":
        raise GlbError("not a binary glTF (.glb) file")
    length = struct.unpack_from("<I", data, 8)[0]
    off, js, binary = 12, None, b""
    while off + 8 <= min(length, len(data)):
        clen, ctype = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == b"JSON":
            js = json.loads(chunk)
        elif ctype == b"BIN\x00":
            binary = chunk
        off += 8 + clen
    if js is None:
        raise GlbError("no JSON chunk")
    used = set(js.get("extensionsUsed", []))
    if "KHR_draco_mesh_compression" in used or "EXT_meshopt_compression" in used:
        raise GlbError("compressed geometry (Draco / meshopt) is not supported; export without compression")
    return js, binary


def mat_mul(a: list, b: list) -> list:
    """Column-major 4x4 product a*b."""
    return [sum(a[r + 4 * k] * b[k + 4 * c] for k in range(4)) for c in range(4) for r in range(4)]


def local_matrix(node: dict) -> list:
    if "matrix" in node:
        return list(node["matrix"])
    tx, ty, tz = node.get("translation", [0, 0, 0])
    qx, qy, qz, qw = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    r = [1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy + qz * qw), 2 * (qx * qz - qy * qw),
         2 * (qx * qy - qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz + qx * qw),
         2 * (qx * qz + qy * qw), 2 * (qy * qz - qx * qw), 1 - 2 * (qx * qx + qy * qy)]
    return [r[0] * sx, r[1] * sx, r[2] * sx, 0, r[3] * sy, r[4] * sy, r[5] * sy, 0,
            r[6] * sz, r[7] * sz, r[8] * sz, 0, tx, ty, tz, 1]


def positions(js: dict, binary: bytes, index: int):
    acc = js["accessors"][index]
    if acc.get("type") != "VEC3" or acc.get("componentType") not in COMPONENT:
        raise GlbError("unexpected POSITION format")
    if "bufferView" not in acc:
        return  # an all-zero accessor contributes nothing worth measuring
    fmt, size, scale = COMPONENT[acc["componentType"]]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 3 * size)
    normalized = acc.get("normalized", False) and scale is not None
    for i in range(acc["count"]):
        x, y, z = struct.unpack_from("<3" + fmt, binary, start + i * stride)
        if normalized:
            x, y, z = (max(v / scale, -1.0) for v in (x, y, z))
        yield x, y, z


def measure(path: str, hidden: set) -> dict:
    """World-space bounds of every drawn mesh, per node and in total."""
    js, binary = load_glb(path)
    nodes, meshes = js.get("nodes", []), js.get("meshes", [])
    per_node, found_hidden = [], set()

    def walk(idx, parent, hid):
        node = nodes[idx]
        name = node.get("name", f"node{idx}")
        world = mat_mul(parent, local_matrix(node))
        hid = hid or name in hidden
        if name in hidden:
            found_hidden.add(name)
        if "mesh" in node and not hid:
            lo, hi, count, tris = [1e18] * 3, [-1e18] * 3, 0, 0
            for prim in meshes[node["mesh"]].get("primitives", []):
                if "POSITION" not in prim.get("attributes", {}):
                    continue
                if prim.get("mode", 4) == 4:  # TRIANGLES; strips and fans are not used by our exports
                    counted = prim["indices"] if "indices" in prim else prim["attributes"]["POSITION"]
                    tris += js["accessors"][counted]["count"] // 3
                for x, y, z in positions(js, binary, prim["attributes"]["POSITION"]):
                    p = (world[0] * x + world[4] * y + world[8] * z + world[12],
                         world[1] * x + world[5] * y + world[9] * z + world[13],
                         world[2] * x + world[6] * y + world[10] * z + world[14])
                    for k in range(3):
                        lo[k], hi[k] = min(lo[k], p[k]), max(hi[k], p[k])
                    count += 1
            if count:
                per_node.append({"name": name, "min": lo, "max": hi, "vertices": count,
                                 "triangles": tris, "skinned": "skin" in node})
        for child in node.get("children", []):
            walk(child, world, hid)

    identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    scenes = js.get("scenes") or [{"nodes": list(range(len(nodes)))}]
    for root in scenes[js.get("scene", 0)].get("nodes", []):
        walk(root, identity, False)
    if not per_node:
        raise GlbError("no visible mesh found")
    lo = [min(n["min"][k] for n in per_node) for k in range(3)]
    hi = [max(n["max"][k] for n in per_node) for k in range(3)]
    return {"nodes": per_node, "min": lo, "max": hi, "height": hi[1] - lo[1],
            "triangles": sum(n["triangles"] for n in per_node),
            "width": hi[0] - lo[0], "depth": hi[2] - lo[2],
            "missing_hidden": sorted(hidden - found_hidden)}


def target_for(subject: str):
    import art_board  # the board owns the heights parser; one home for it
    return art_board.read_heights().get(subject.split("/")[0])


def record(subject: str, height: float) -> None:
    import art_board
    review = art_board.load_review(subject)
    model = review.get("model") or {}
    model["measured_height_m"] = round(height, 3)
    review["model"] = model
    art_board.record(review, f"Model measured at {height:.2f} m", "")
    art_board.save_review(subject, review)


def main(argv: list) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    path, subject, hidden, do_record = argv[0], None, set(), False
    i = 1
    while i < len(argv):
        if argv[i] == "--subject" and i + 1 < len(argv):
            subject, i = argv[i + 1], i + 2
        elif argv[i] == "--hide":
            i += 1
            while i < len(argv) and not argv[i].startswith("--"):
                hidden.add(argv[i])
                i += 1
        elif argv[i] == "--record":
            do_record, i = True, i + 1
        else:
            print(f"unknown argument: {argv[i]}")
            return 2
    try:
        m = measure(path, hidden)
    except (GlbError, OSError, KeyError, struct.error) as exc:
        print(f"Could not measure {path}: {exc}")
        return 1
    print(f"{os.path.basename(path)}: height {m['height']:.3f} m, width {m['width']:.3f} m, "
          f"depth {m['depth']:.3f} m (feet at y {m['min'][1]:.3f})")
    for n in m["nodes"]:
        print(f"  {n['name'][:40]:40} {n['max'][1] - n['min'][1]:6.3f} m tall, {n['vertices']} vertices, "
              f"{n['triangles']} triangles" + (" (skinned: bind pose)" if n["skinned"] else ""))
    over = m["triangles"] > BODY_TRIANGLE_BUDGET
    print(f"  {m['triangles']} triangles in all; bare-body budget {BODY_TRIANGLE_BUDGET} "
          + ("OVER" if over else "PASS"))
    if m["missing_hidden"]:
        print(f"  note: no node named {', '.join(m['missing_hidden'])} in this file")
    if subject:
        target = target_for(subject)
        if target:
            lo, hi = target
            ok = lo * (1 - TOLERANCE) <= m["height"] <= hi * (1 + TOLERANCE)
            print(f"  target for {subject}: {lo:.2f} to {hi:.2f} m (middle {(lo + hi) / 2:.3f}) "
                  f"{'PASS' if ok else 'OUTSIDE THE RANGE'}")
        else:
            print(f"  no height range for '{subject.split('/')[0]}' in creature_heights.md")
        if do_record:
            record(subject, m["height"])
            print(f"  recorded on {subject}'s card")
    elif do_record:
        print("--record needs --subject")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
