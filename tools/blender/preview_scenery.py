# Renders a generator's variants side by side for review (workbench, read-only:
# the .blend is never saved). A 1.8 m column stands at the left for scale.
#
#   blender --background <kind>.blend --python tools/blender/preview_scenery.py -- <out.png> [high] [rows=N]
#
# "high" looks down from 40 degrees, the angle that shows a tier poking out.
# "rows=N" stacks the row of variants into N rows, one above the other, so a
# dozen small rocks are not specks (the stacked rows float; it is a preview).
#
# Prints each variant's bounds, so the base sitting at 0 and the crown base can
# be checked without opening Blender.

import math
import os
import sys

import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_nodes as sn  # noqa: E402

HUMAN_HEIGHT = 1.8


def _stack(variants, rows):
    """Lays the variants out in `rows` rows, the first row at the top."""
    dg = bpy.context.evaluated_depsgraph_get()
    tallest = max(o.evaluated_get(dg).dimensions.z for o in variants)
    per_row = -(-len(variants) // rows)
    spacing = variants[1].location.x - variants[0].location.x if len(variants) > 1 else 0.0
    for i, obj in enumerate(variants):
        row, col = divmod(i, per_row)
        obj.location = (col * spacing, 0.0, (rows - 1 - row) * tallest * 1.5)
    bpy.context.view_layer.update()


def main():
    args = sn.script_args()
    options = args[1:]
    rows = 1
    for opt in options:
        if opt.startswith("rows="):
            rows = int(opt[5:])
        elif opt != "high":
            raise SystemExit("usage: preview_scenery.py -- <out.png> [high] [rows=N]")
    if not args:
        raise SystemExit("usage: preview_scenery.py -- <out.png> [high] [rows=N]")
    high = "high" in options
    out = os.path.abspath(args[0])
    scene = bpy.context.scene
    variants = [o for o in scene.objects if o.type == "MESH"]
    variants.sort(key=lambda o: o.location.x)
    if rows > 1:
        _stack(variants, rows)

    # The placeholder colours drawn as they are stored ("Col").
    for obj in variants:
        obj.data.color_attributes.render_color_index = -1
        obj.data.attributes.default_color_name = "Col"
        obj.data.attributes.active_color_name = "Col"

    dg = bpy.context.evaluated_depsgraph_get()
    lo = mathutils.Vector((math.inf,) * 3)
    hi = mathutils.Vector((-math.inf,) * 3)
    for obj in variants:
        ev = obj.evaluated_get(dg)
        pts = [ev.matrix_world @ mathutils.Vector(c) for c in ev.bound_box]
        a = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        b = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        print("%s: base %.2f, top %.2f, width %.2f x %.2f, %d triangles"
              % (obj.name, a.z - obj.location.z, b.z - obj.location.z, b.x - a.x, b.y - a.y, sn.triangles(obj)))
        lo = mathutils.Vector(map(min, lo, a))
        hi = mathutils.Vector(map(max, hi, b))

    # A 1.8 m figure to the left of the row.
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=HUMAN_HEIGHT,
                                        location=(lo.x - 1.5, 0.0, HUMAN_HEIGHT / 2))
    bpy.context.active_object.color = (0.8, 0.35, 0.3, 1.0)
    lo.x -= 2.0

    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "VERTEX"
    shading.show_cavity = False
    scene.render.resolution_x = 1800
    # Tall enough for what is shown: the row's height plus a margin, at the
    # scale the width sets.
    tall = (hi.z - lo.z + 2.0) * 1.25
    scene.render.resolution_y = max(500, min(1400, round(1800 * tall / ((hi.x - lo.x) * 1.08))))
    world = bpy.data.worlds.new("pv") if scene.world is None else scene.world
    scene.world = world
    world.color = (0.75, 0.78, 0.8)

    mid = (lo + hi) / 2
    width = hi.x - lo.x
    cam_data = bpy.data.cameras.new("pv")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = width * 1.08
    cam = bpy.data.objects.new("pv", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (mid.x, -60.0, mid.z + (50.0 if high else 6.0))
    cam.rotation_euler = (mathutils.Vector((mid.x, 0.0, mid.z)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.clip_end = 500.0
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("rendered", out)


main()
