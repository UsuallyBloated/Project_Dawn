"""What an exported character GLB carries, read from the file itself (standard library only).

The Art Board's race cards use it to tell which steps of the modelling workflow a model has
reached: its height and triangle count (with measure_glb.py), which way it faces, whether its
UVs are a real unwrap, whether it carries a texture, and whether it carries a skeleton.

  python tools/art_board/glb_checks.py <model.glb>    prints the findings
"""

import os
import struct
import sys

import measure_glb as mg

COMPONENTS = {5120: ("b", 1, 127.0), 5121: ("B", 1, 255.0), 5122: ("h", 2, 32767.0),
              5123: ("H", 2, 65535.0), 5125: ("I", 4, None), 5126: ("f", 4, None)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
# How deep the unwrap's pieces may pile up on average. Stacking mirrored halves on purpose (a
# common way to save texture) piles two deep; a body whose parts each still fill the whole square
# piles once per part (the hand-built blockouts read about 11 deep).
MAX_STACK_DEPTH = 2.2
OVERLAP_GRID = 256


def accessor(js: dict, binary: bytes, index: int) -> list:
    """Every element of one accessor, as tuples (normalised integers become 0-1 floats)."""
    acc = js["accessors"][index]
    if "bufferView" not in acc:
        return [(0.0,) * WIDTHS[acc["type"]]] * acc["count"]
    fmt, size, scale = COMPONENTS[acc["componentType"]]
    width = WIDTHS[acc["type"]]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", size * width)
    norm = acc.get("normalized", False) and scale is not None
    out = []
    for i in range(acc["count"]):
        vals = struct.unpack_from("<" + fmt * width, binary, start + i * stride)
        out.append(tuple(max(v / scale, -1.0) for v in vals) if norm else vals)
    return out


def _world_matrices(js: dict) -> list:
    """(node index, world matrix) for every node that holds a mesh."""
    nodes, found = js.get("nodes", []), []

    def walk(idx, parent):
        world = mg.mat_mul(parent, mg.local_matrix(nodes[idx]))
        if "mesh" in nodes[idx]:
            found.append((idx, world))
        for child in nodes[idx].get("children", []):
            walk(child, world)

    identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    scenes = js.get("scenes") or [{"nodes": list(range(len(nodes)))}]
    for root in scenes[js.get("scene", 0)].get("nodes", []):
        walk(root, identity)
    return found


def _image_size(js: dict, binary: bytes, image_index: int) -> str:
    img = js.get("images", [])[image_index]
    if "bufferView" not in img:
        return "external file"
    view = js["bufferViews"][img["bufferView"]]
    head = binary[view.get("byteOffset", 0): view.get("byteOffset", 0) + 32]
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", head[16:24])
        return f"{w} x {h}"
    return img.get("mimeType", "image")


def check(path: str) -> dict:
    """Findings for one GLB: size, triangles, facing, uv, texture, rig."""
    js, binary = mg.load_glb(path)
    size = mg.measure(path, set())
    out = {"height": size["height"], "width": size["width"], "triangles": size["triangles"]}

    tris_world, tris_uv, keyed = [], [], []
    materials = set()
    for node_idx, world in _world_matrices(js):
        mesh = js["meshes"][js["nodes"][node_idx]["mesh"]]
        for prim in mesh.get("primitives", []):
            if prim.get("mode", 4) != 4 or "POSITION" not in prim.get("attributes", {}):
                continue
            if "material" in prim:
                materials.add(prim["material"])
            pos = [(world[0] * x + world[4] * y + world[8] * z + world[12],
                    world[1] * x + world[5] * y + world[9] * z + world[13],
                    world[2] * x + world[6] * y + world[10] * z + world[14])
                   for x, y, z in accessor(js, binary, prim["attributes"]["POSITION"])]
            uvs = accessor(js, binary, prim["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in prim["attributes"] else None
            idx = [i[0] for i in accessor(js, binary, prim["indices"])] if "indices" in prim else list(range(len(pos)))
            for t in range(0, len(idx) - 2, 3):
                a, b, c = idx[t], idx[t + 1], idx[t + 2]
                tris_world.append((pos[a], pos[b], pos[c]))
                if uvs is not None:
                    tris_uv.append((uvs[a], uvs[b], uvs[c]))
                    # a corner is one point of the unwrap: same place on the body, same place in the square
                    keyed.append(tuple((round(pos[v][0], 5), round(pos[v][1], 5), round(pos[v][2], 5),
                                        round(uvs[v][0], 5), round(uvs[v][1], 5)) for v in (a, b, c)))

    out["facing"] = _facing(tris_world)
    out["uv"] = _uv_findings(tris_uv, keyed) if tris_uv else None

    texture = None
    for m in sorted(materials):
        base = js.get("materials", [])[m].get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if base is not None:
            source = js.get("textures", [])[base["index"]].get("source")
            texture = _image_size(js, binary, source) if source is not None else "texture"
            break
    out["texture"] = texture

    skins = js.get("skins", [])
    out["rig"] = {"bones": max(len(s.get("joints", [])) for s in skins),
                  "animations": len(js.get("animations", []))} if skins else None
    return out


def _facing(tris: list) -> str:
    """'front' when the toes point along +Z (glTF forward, Blender's Front view), 'back' when
    they point the other way, '' when the feet do not say."""
    pts = [p for t in tris for p in t]
    if not pts:
        return ""
    ys = [p[1] for p in pts]
    lo, h = min(ys), max(ys) - min(ys)

    def mean_z(a, b):
        zs = [p[2] for p in pts if lo + a * h <= p[1] <= lo + b * h]
        return sum(zs) / len(zs) if zs else None

    toes, ankles = mean_z(0.0, 0.03), mean_z(0.06, 0.12)
    if toes is None or ankles is None or abs(toes - ankles) < 0.005 * h:
        return ""
    return "front" if toes > ankles else "back"


def _uv_findings(tris_uv: list, keyed: list) -> dict:
    area, outside = 0.0, 0
    for (a, b, c) in tris_uv:
        area += abs((b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])) / 2
        outside += sum(1 for p in (a, b, c) if p[0] < -1e-3 or p[0] > 1.001 or p[1] < -1e-3 or p[1] > 1.001)

    # pieces as Blender counts UV islands: two faces belong together only when they share a whole
    # edge whose ends sit at the same places in the square (sharing one corner is not enough)
    parent = list(range(len(keyed)))

    def find(t):
        while parent[t] != t:
            parent[t] = parent[parent[t]]
            t = parent[t]
        return t

    by_edge = {}
    for t, corners in enumerate(keyed):
        for i in range(3):
            edge = tuple(sorted((corners[i], corners[(i + 1) % 3])))
            other = by_edge.setdefault(edge, t)
            if other != t:
                parent[find(t)] = find(other)
    pieces = len({find(t) for t in range(len(keyed))})

    n, cover = OVERLAP_GRID, {}
    for a, b, c in tris_uv:
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        for i in range(max(0, int(min(a[0], b[0], c[0]) * n)), min(n, int(max(a[0], b[0], c[0]) * n) + 1)):
            for j in range(max(0, int(min(a[1], b[1], c[1]) * n)), min(n, int(max(a[1], b[1], c[1]) * n) + 1)):
                px, py = (i + 0.5) / n, (j + 0.5) / n
                w1 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / den
                w2 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / den
                if w1 >= 0 and w2 >= 0 and w1 + w2 <= 1:
                    cover[(i, j)] = cover.get((i, j), 0) + 1
    overlap = sum(1 for v in cover.values() if v > 1) / len(cover) if cover else 0.0
    used = len(cover) / (n * n)
    depth = area / used if used else 0.0
    unwrapped = outside == 0 and used > 0.01 and depth <= MAX_STACK_DEPTH
    return {"pieces": pieces, "triangles": len(tris_uv), "area": area, "used": used, "depth": depth,
            "overlap": overlap, "outside": outside, "unwrapped": unwrapped}


def main(argv: list) -> int:
    if not argv:
        print(__doc__)
        return 0
    r = check(argv[0])
    print(f"{os.path.basename(argv[0])}: {r['height']:.3f} m tall, {r['triangles']} triangles, faces {r['facing'] or 'unclear'}")
    uv = r["uv"]
    if uv:
        print(f"  UVs: {uv['pieces']} pieces, square {uv['used']:.0%} used, {uv['overlap']:.1%} overlapping, "
              f"{uv['depth']:.1f} deep on average, {uv['outside']} corners outside -> "
              + ("unwrapped" if uv["unwrapped"] else "not a real unwrap"))
    else:
        print("  UVs: none")
    print(f"  texture: {r['texture'] or 'none'}; rig: "
          + (f"{r['rig']['bones']} bones, {r['rig']['animations']} animations" if r["rig"] else "none"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
