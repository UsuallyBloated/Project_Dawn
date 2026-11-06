"""The Art Board's two jobs inside Blender, run in the background and never saving anything.

  blender --background --factory-startup --disable-autoexec --python blender_board.py -- scan <file.blend> <out.json>
      Which bodies the file holds: mesh counts per collection, sorted into male, female and
      untagged by the collection's name ("GnomeMale", "Halfling_male", "OgreFemale"). Modelling
      scaffolds (height bars, reference planes, rig widgets) and Exported* collections are left out.

  blender --background --factory-startup --disable-autoexec --python blender_board.py -- render <model.glb> <out.png> <pixel height>
      A front view of an exported model on a transparent background, framed tight so the image's
      height is exactly the model's height (the board's lineup scales it to metres).

The board starts these itself (art_board.py's background worker) and caches the results, so a
.blend is opened again only after it has been saved.
"""
import json
import math
import sys

import bpy
from mathutils import Vector

SCAFFOLD_WORDS = ("framework", "2d_model", "reference", "ref_plane", "refplane", "blueprint", "wgt")


def sex_of(names: list) -> str:
    joined = " ".join(n.lower() for n in names)
    if "female" in joined:
        return "female"
    if "male" in joined:
        return "male"
    return ""


def scan(blend: str, out: str) -> None:
    bpy.ops.wm.open_mainfile(filepath=blend, load_ui=False)
    parents = {}
    for coll in bpy.data.collections:
        for child in coll.children:
            parents[child.name] = coll.name

    def chain(name: str) -> list:
        names = []
        while name:
            names.append(name)
            name = parents.get(name)
        return names

    result = {"male": 0, "female": 0, "untagged": 0, "collections": {}}
    for obj in bpy.data.objects:
        if obj.type != "MESH" or any(w in obj.name.lower() for w in SCAFFOLD_WORDS):
            continue
        names = []
        for coll in obj.users_collection:
            names += chain(coll.name)
        if any("export" in n.lower() for n in names):
            continue
        sex = sex_of(names) or "untagged"
        result[sex] += 1
        key = obj.users_collection[0].name if obj.users_collection else "Scene Collection"
        result["collections"][key] = result["collections"].get(key, 0) + 1
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f)


def render(glb: str, out: str, px_height: int) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    deps = bpy.context.evaluated_depsgraph_get()
    pts = []
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            ev = obj.evaluated_get(deps)
            pts += [ev.matrix_world @ v.co for v in ev.data.vertices]
    if not pts:
        raise SystemExit("no mesh in " + glb)
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    height, width = hi.z - lo.z, hi.x - lo.x
    centre = (lo + hi) / 2

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_y = px_height
    scene.render.resolution_x = max(8, math.ceil(px_height * width / height))
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "SINGLE"
    shading.single_color = (0.82, 0.8, 0.76)
    shading.show_shadows = False
    scene.view_settings.view_transform = "Standard"

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    # an orthographic camera's scale spans the image's longer side
    cam.data.ortho_scale = max(height, width)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # glTF's forward (+Z) arrives in Blender as -Y, so the front camera sits on -Y
    cam.location = centre + Vector((0, -10, 0))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


args = sys.argv[sys.argv.index("--") + 1:]
if args[0] == "scan":
    scan(args[1], args[2])
elif args[0] == "render":
    render(args[1], args[2], int(args[3]))
else:
    raise SystemExit("unknown job " + args[0])
