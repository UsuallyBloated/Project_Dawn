# Exports the scenery variants for the game: one .glb (what is drawn) and one
# .solids.json (what stands in a body's way) per row of scenery_variants.toml,
# built fresh from the generators' code so an export always matches the
# scripts in git.
#
#   blender --background --factory-startup --python tools/blender/export_scenery.py -- <kind|all> [out_dir]
#
# out_dir defaults to assets/models/scenery; each kind gets its own folder
# (assets/models/scenery/pine/pine_1.glb, pine_1.solids.json, ...). A kind's
# old exports are removed first, so a dropped variant leaves nothing behind.
#
# The .glb is the variant's mesh with its placeholder colour ("Col", as the
# vertex colour) and its UVs, no material (the game draws scenery with
# LowPoly.solid_material()). Proxy pieces (a one-piece trunk's solids) are
# left out of it.
#
# The .solids.json is what LowPoly.volumes() records for the game's own
# shapes, so ZoneObstacleBake can use it as it is: one entry per solid piece
# (every "part" of 0 or more, proxies included, part -1 left out) with the
# corners of the piece's convex hull in Godot's space (metres, Y up, rounded
# to the millimetre) and its sight scale: how much of its outline blocks a
# line of sight, the mean of its width up its height over its widest (1 for
# a box, 0.5 for a cone).
#
# A variant over its kind's triangle limit (MAX_TRIANGLES) is refused.

import importlib
import json
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_OUT = os.path.join(REPO, "assets", "models", "scenery")

# Which generator builds each kind.
SOURCES = {
    "pine": "gen_trees", "broadleaf": "gen_trees", "dark_tree": "gen_trees", "dead_tree": "gen_trees",
    "boulder": "gen_rocks", "bush": "gen_shrubs", "scrub": "gen_shrubs",
    "bones": "gen_bones", "skeleton": "gen_skeleton", "grass": "gen_grass",
}
# The most triangles a variant of each kind may have (the user approved
# every variant as it stands; the limits leave a little room and stop a
# slider tweak from quietly doubling a forest's cost).
MAX_TRIANGLES = {
    "pine": 800, "broadleaf": 800, "dark_tree": 800, "dead_tree": 800,
    "boulder": 200, "bush": 200, "scrub": 200,
    "bones": 800, "skeleton": 1300, "grass": 350,
}
SNAP = 3  # decimal places: millimetres


def godot(v):
    """A Blender point (Z up) in Godot's space (Y up), as the glTF export
    turns it."""
    return (v[0], v[2], -v[1])


def snapped(x):
    r = round(x, SNAP)
    return 0.0 if r == 0.0 else r


def set_slider(obj, name, value):
    """Sets a slider if the variant's group has one by that name."""
    mod = obj.modifiers["Generator"]
    for s in mod.node_group.interface.items_tree:
        if getattr(s, "in_out", None) == "INPUT" and s.name == name:
            getattr(mod.properties.inputs, s.identifier).value = value
            return True
    return False


def evaluated_mesh(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    return bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)


def hull(points):
    """The corners of a set of points' convex hull (all of them if the points
    are too flat to wrap)."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    try:
        result = bmesh.ops.convex_hull(bm, input=bm.verts)
        kept = [v.co.copy() for v in result["geom"] if isinstance(v, bmesh.types.BMVert)]
    except (RuntimeError, ValueError):
        kept = []
    bm.free()
    return [tuple(v) for v in kept] if len(kept) >= 4 else list(points)


def sight_scale(points):
    """The mean of a piece's width up its height over its widest. Its width
    at each height its corners stand at is how far its farthest corner there
    is from its middle (seen from above); between those heights the width is
    taken to change evenly."""
    cx = sum(p[0] for p in points) / len(points)
    cz = sum(p[2] for p in points) / len(points)
    levels = {}
    for x, y, z in points:
        key = round(y, SNAP)
        reach = ((x - cx) ** 2 + (z - cz) ** 2) ** 0.5
        levels[key] = max(levels.get(key, 0.0), reach)
    heights = sorted(levels)
    widest = max(levels.values())
    if len(heights) < 2 or widest <= 0.0:
        return 1.0
    area = sum((levels[a] + levels[b]) * 0.5 * (b - a) for a, b in zip(heights, heights[1:]))
    return round(min(area / ((heights[-1] - heights[0]) * widest), 1.0), SNAP)


def solids_of(mesh):
    """One entry per solid piece: [part, sight scale, hull corners]."""
    part = mesh.attributes["part"].data
    by_part = {}
    for v, p in zip(mesh.vertices, part):
        if p.value >= 0:
            by_part.setdefault(p.value, []).append(godot(v.co))
    out = []
    for p in sorted(by_part):
        pts = sorted({tuple(snapped(c) for c in pt) for pt in by_part[p]})
        corners = sorted({tuple(snapped(c) for c in pt) for pt in hull(pts)})
        out.append((p, sight_scale(pts), corners))
    return out


def write_solids(path, kind, variant, source, triangles, solids):
    lines = ['{', '  "kind": %s,' % json.dumps(kind), '  "variant": %d,' % variant,
             '  "source": %s,' % json.dumps("tools/blender/%s.py" % source),
             '  "triangles": %d,' % triangles, '  "solids": [']
    for n, (p, scale, corners) in enumerate(solids):
        pts = ", ".join("[%s, %s, %s]" % tuple(repr(c) for c in pt) for pt in corners)
        tail = "," if n < len(solids) - 1 else ""
        lines.append('    {"part": %d, "sight_scale": %s, "corners": [%s]}%s' % (p, repr(scale), pts, tail))
    lines += ['  ]', '}', '']
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def write_glb(path, name, mesh):
    """`mesh` as a .glb holding one object, with "Col" as its vertex colour."""
    for attr in ("part", "proxy"):
        if attr in mesh.attributes:
            mesh.attributes.remove(mesh.attributes[attr])
    mesh.attributes.default_color_name = "Col"
    mesh.attributes.active_color_name = "Col"
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="NONE", export_vertex_color="NAME",
                              export_vertex_color_name="Col", export_attributes=False, export_extras=False,
                              export_texcoords=True, export_normals=True, export_tangents=False)
    bpy.data.objects.remove(obj)


def export_kind(kind, out_dir):
    source = SOURCES[kind]
    module = importlib.import_module(source)
    folder = os.path.join(out_dir, kind)
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.startswith(kind + "_") and (f.endswith(".glb") or f.endswith(".solids.json")):
            os.remove(os.path.join(folder, f))
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    group = module.BUILDERS[kind]()
    for row in sn.variants(kind):
        name = "%s_%d" % (kind, row["variant"])
        obj = sn.apply_variant(group, name, row, (0.0, 0.0, 0.0))
        triangles = sn.triangles(obj)
        if triangles > MAX_TRIANGLES[kind]:
            raise SystemExit("%s: %d triangles, over the %s limit of %d"
                             % (name, triangles, kind, MAX_TRIANGLES[kind]))
        # The solids, with a one-piece trunk's proxies shown...
        has_solids_slider = set_slider(obj, "Solids", True)
        solid_mesh = evaluated_mesh(obj)
        solids = solids_of(solid_mesh)
        bpy.data.meshes.remove(solid_mesh)
        # ...and what is drawn, without them.
        if has_solids_slider:
            set_slider(obj, "Solids", False)
        drawn = evaluated_mesh(obj)
        write_glb(os.path.join(folder, name + ".glb"), name, drawn)
        write_solids(os.path.join(folder, name + ".solids.json"), kind, row["variant"], source, triangles, solids)
        print("exported %s: %d triangles, %d solids" % (name, triangles, len(solids)))
        bpy.data.objects.remove(obj)


def main():
    args = sn.script_args()
    if not args or (args[0] != "all" and args[0] not in SOURCES):
        raise SystemExit("usage: export_scenery.py -- <%s|all> [out_dir]" % "|".join(SOURCES))
    out_dir = os.path.abspath(args[1]) if len(args) > 1 else DEFAULT_OUT
    for kind in (SOURCES if args[0] == "all" else [args[0]]):
        export_kind(kind, out_dir)


main()
