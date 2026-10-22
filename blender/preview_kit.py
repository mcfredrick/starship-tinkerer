"""Render every hull fitted with a set of parts, for checking kit geometry by eye.

Run: Blender -b --python blender/preview_kit.py -- out.png [--front]
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from kit_common import clear_scene  # noqa: E402
from ship_kit import build_kit  # noqa: E402

FITS = {
    "moth": ("engine_rattler", "fin_stub", "cockpit_bay", "lights_round", "gadget_bubble"),
    "kettle": ("engine_hush", "fin_swept", "cockpit_bubble", "lights_bar", "gadget_ribbon"),
    "heron": ("engine_sprint", "fin_wing", "cockpit_visor", "lights_bar", "gadget_ribbon"),
    "bucket": ("engine_rattler", "fin_stub", "cockpit_bubble", "lights_round", "gadget_bubble"),
}
SLOTS = ("engine", "fin_l", "cockpit", "lights", "top")
COLORS = {"paint": (0.9, 0.5, 0.3), "trim": (0.95, 0.85, 0.5), "glass": (0.4, 0.8, 0.9),
          "metal": (0.6, 0.6, 0.65), "glow": (1.0, 0.9, 0.4), "dark": (0.15, 0.15, 0.2)}

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
clear_scene()
build_kit()
scene = bpy.context.scene


def copy_tree(src, parent, matrix):
    for child in src.children:
        if child.type != "MESH":
            continue
        dup = child.copy()
        dup.parent = None
        scene.collection.objects.link(dup)
        dup.matrix_world = matrix @ child.matrix_local
        role = child.name.rsplit("_", 1)[-1]
        dup.color = (*COLORS[role], 1)


for i, (hull, parts) in enumerate(FITS.items()):
    h = bpy.data.objects[f"hull_{hull}"]
    offset = Matrix.Translation(Vector(((i - 1.5) * 4.5, 0, 0)))
    h.matrix_world = offset
    for child in h.children:
        if child.type == "MESH":
            child.color = (*COLORS[child.name.rsplit("_", 1)[-1]], 1)
    bpy.context.view_layer.update()
    for slot, part in zip(SLOTS, parts):
        sock = bpy.data.objects[f"hull_{hull}__socket_{slot}"]
        src = bpy.data.objects[f"part_{part}"]
        copy_tree(src, None, sock.matrix_world)
        if slot == "fin_l":
            mirror = bpy.data.objects[f"hull_{hull}__socket_fin_r"].matrix_world @ Matrix.Scale(-1, 4, (1, 0, 0))
            copy_tree(src, None, mirror)

for obj in [o for o in scene.objects if o.name.startswith("part_") and "." not in o.name]:
    bpy.data.objects.remove(obj)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
cam.location = (-9, 14, 7) if "--front" in args else (9, -14, 9)
cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 40
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.color_type = "OBJECT"
scene.display.shading.show_cavity = True
scene.display.shading.show_object_outline = True
scene.render.resolution_x, scene.render.resolution_y = 1600, 800
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
