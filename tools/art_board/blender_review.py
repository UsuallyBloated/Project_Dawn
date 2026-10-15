"""Render front and side views of character .blend files, and report what is in each.

Runs inside Blender, in the background, never saving anything:

  blender --background --factory-startup --disable-autoexec --python tools/art_board/blender_review.py -- <out dir> <file.blend> [more.blend ...]

For each file: the visible meshes (modelling scaffolds such as *_Framework and 2D_Model_*
reference planes left out, as the game hides them), their world bounds, vertex and face counts
after modifiers, modifiers, materials and armatures, and two orthographic renders on a plain
light-grey background with even studio light (the look of a model sheet). Writes
<name>_front.png, <name>_side.png and a summary.json into the out dir. The .blend files are
only read: nothing here calls a save, and embedded scripts stay disabled (--disable-autoexec).
"""

import json
import math
import os
import sys
import traceback

import bpy
from mathutils import Vector

SCAFFOLD_WORDS = ("framework", "2d_model", "reference", "ref_plane", "refplane", "blueprint")
RES_X, RES_Y = 600, 900
BACKGROUND = (0.83, 0.83, 0.81)


def is_scaffold(obj) -> bool:
    name = obj.name.lower()
    return any(word in name for word in SCAFFOLD_WORDS)


def visible_meshes():
    shown, skipped = [], []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if is_scaffold(obj) or obj.hide_render or not obj.visible_get():
            skipped.append(obj.name)
            continue
        shown.append(obj)
    return shown, skipped


def evaluated_geometry(objs):
    """World bounds and counts from the meshes as drawn, modifiers (mirror etc.) applied."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lo, hi = [1e18] * 3, [-1e18] * 3
    verts = faces = 0
    for obj in objs:
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        try:
            matrix = ev.matrix_world
            for v in mesh.vertices:
                p = matrix @ v.co
                for i in range(3):
                    lo[i], hi[i] = min(lo[i], p[i]), max(hi[i], p[i])
            verts += len(mesh.vertices)
            faces += len(mesh.polygons)
        finally:
            ev.to_mesh_clear()
    return Vector(lo), Vector(hi), verts, faces


def setup_render(scene, hide_names):
    for obj in scene.objects:
        if obj.name in hide_names:
            obj.hide_render = True  # in memory only; the file is never saved
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = RES_X, RES_Y
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = False
    shading.show_cavity = True
    if scene.world is None:
        scene.world = bpy.data.worlds.new("review_world")
    scene.world.color = BACKGROUND
    scene.render.image_settings.file_format = "PNG"


def camera_for(scene, lo, hi, view):
    center = (lo + hi) / 2
    size = hi - lo
    data = bpy.data.cameras.new(f"review_cam_{view}")
    data.type = "ORTHO"
    aspect = RES_X / RES_Y
    data.ortho_scale = max(size.z * 1.12, (size.x if view == "front" else size.y) * 1.12 / aspect)
    cam = bpy.data.objects.new(f"review_cam_{view}", data)
    scene.collection.objects.link(cam)
    distance = max(size) * 3 + 2
    if view == "front":  # Blender's front view looks along +Y
        cam.location = (center.x, center.y - distance, center.z)
        cam.rotation_euler = (math.radians(90), 0, 0)
    else:  # right side, looking along -X
        cam.location = (center.x + distance, center.y, center.z)
        cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    data.clip_end = distance * 3
    scene.camera = cam
    return cam


def review(path: str, out_dir: str) -> dict:
    bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
    scene = bpy.context.scene
    name = os.path.splitext(os.path.basename(path))[0]
    shown, skipped = visible_meshes()
    report = {"file": path, "scene": scene.name, "unit_scale": scene.unit_settings.scale_length,
              "meshes": [o.name for o in shown], "left_out": skipped,
              "armatures": [o.name for o in scene.objects if o.type == "ARMATURE"],
              "materials": sorted({s.material.name for o in shown for s in o.material_slots if s.material}),
              "modifiers": sorted({f"{m.type}" for o in shown for m in o.modifiers}),
              "shape_keys": sorted({o.name for o in shown if o.data.shape_keys})}
    if not shown:
        report["error"] = "no visible mesh"
        return report
    lo, hi, report["vertices"], report["faces"] = evaluated_geometry(shown)
    report["bounds_min"], report["bounds_max"] = [round(v, 4) for v in lo], [round(v, 4) for v in hi]
    report["height_m"] = round((hi.z - lo.z) * scene.unit_settings.scale_length, 4)
    report["width_m"] = round((hi.x - lo.x) * scene.unit_settings.scale_length, 4)
    report["depth_m"] = round((hi.y - lo.y) * scene.unit_settings.scale_length, 4)
    setup_render(scene, set(skipped))
    report["renders"] = []
    for view in ("front", "side"):
        camera_for(scene, lo, hi, view)
        out = os.path.join(out_dir, f"{name}_{view}.png")
        scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        report["renders"].append(os.path.basename(out))
    return report


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(args) < 2:
        print("usage: ... -- <out dir> <file.blend> [more.blend ...]")
        return
    out_dir, files = args[0], args[1:]
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for path in files:
        try:
            results.append(review(path, out_dir))
            print(f"REVIEWED {path}")
        except Exception as exc:  # one broken file must not stop the rest
            results.append({"file": path, "error": f"{type(exc).__name__}: {exc}"})
            print(f"FAILED {path}: {exc}")
            traceback.print_exc()
    with open(os.path.join(out_dir, "summary.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, indent=1)


main()
