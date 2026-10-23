"""Sprocket the shop cat (a tuxedo with a green collar and gold tag), in two poses, exported for Godot.

Run: Blender -b --python blender/cat.py
Writes godot_web_game/assets/props/cat.glb with two roots, cat_sit and cat_sleep.

Mesh names end in a material role (_fur, _cream, _pink, _eye, _ink, _collar, _tag) that Godot colors.
In cat_sit, the head and tail are their own empties (cat_sit__head, cat_sit__tail) so Godot can
turn the head and swish the tail. Nose +Y (Godot -Z), up +Z.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from kit_common import clear_scene, empty, lathe_bm, mesh_obj, sphere_bm, transform_bm, tube_bm  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "props" / "cat.glb"


def ellipsoid(r, at, segments=24, rings=12):
    return sphere_bm(1.0, segments, rings, lambda v: Vector((v.x * r[0], v.y * r[1], v.z * r[2])) + Vector(at))


def head(parent, at, sleepy=False):
    h = empty("head", parent, at)
    mesh_obj("skull_fur", ellipsoid((0.36, 0.32, 0.3), (0, 0, 0)), h)
    mesh_obj("blaze_cream", ellipsoid((0.06, 0.04, 0.12), (0, 0.29, 0.06)), h)
    for side in (-1, 1):
        ear = lathe_bm([(0.0, 0.13), (0.24, 0.005)], axis="z", squash=(1.0, 0.5))
        mesh_obj(f"ear{side}_fur", transform_bm(ear, lambda v, s=side: Vector((v.x + s * 0.2, v.y + 0.02, v.z + 0.18))), h)
        mesh_obj(f"cheek{side}_cream", ellipsoid((0.1, 0.06, 0.08), (side * 0.08, 0.29, -0.08)), h)
        if sleepy:
            lid = [(side * 0.13 + (i / 6 - 0.5) * 0.12, 0.3, 0.04 - 0.02 * math.sin(math.pi * i / 6)) for i in range(7)]
            mesh_obj(f"lid{side}_ink", tube_bm(lid, [0.012] * 7, 6), h)
        else:
            mesh_obj(f"eye{side}_eye", ellipsoid((0.07, 0.03, 0.065), (side * 0.13, 0.29, 0.05)), h)
            mesh_obj(f"pupil{side}_ink", ellipsoid((0.015, 0.02, 0.055), (side * 0.13, 0.315, 0.05)), h)
    mesh_obj("nose_pink", ellipsoid((0.035, 0.025, 0.025), (0, 0.33, -0.03)), h)
    return h


def sitting():
    root = empty("cat_sit")
    mesh_obj("body_fur", ellipsoid((0.42, 0.38, 0.5), (0, 0, 0.5)), root)
    mesh_obj("chest_cream", ellipsoid((0.24, 0.16, 0.36), (0, 0.27, 0.55)), root)
    collar = [(math.cos(a) * 0.33, 0.05 + math.sin(a) * 0.31, 0.86) for a in (2 * math.pi * i / 24 for i in range(25))]
    mesh_obj("collar_collar", tube_bm(collar, [0.05] * 25, 8, cap=False), root)
    tag = lathe_bm([(0.025, 0.075), (-0.025, 0.075)])
    mesh_obj("tag_tag", transform_bm(tag, lambda v: v + Vector((0, 0.42, 0.74))), root)
    for side in (-1, 1):
        mesh_obj(f"haunch{side}_fur", ellipsoid((0.2, 0.32, 0.22), (side * 0.3, -0.08, 0.22)), root)
        mesh_obj(f"paw{side}_cream", ellipsoid((0.09, 0.13, 0.07), (side * 0.13, 0.33, 0.06)), root)
    head(root, (0, 0.12, 1.05))
    tail = empty("tail", root, (0, -0.35, 0.12))
    curl = [(0.6 * math.sin(a) * 0.9, -0.15 * math.cos(a), 0.02 + 0.05 * a) for a in (i * 0.18 for i in range(14))]
    mesh_obj("tail_fur", tube_bm(curl, [0.08 - 0.003 * i for i in range(14)], 10), tail)
    return root


def sleeping():
    """Curled up asleep: a round loaf of a body, head tucked down on the front paws, tail wrapped
    around the front, white paws and chest peeking out, collar and tag still on."""
    root = empty("cat_sleep")
    mesh_obj("body_fur", ellipsoid((0.5, 0.46, 0.3), (0, -0.05, 0.28)), root)
    mesh_obj("hip_fur", ellipsoid((0.3, 0.3, 0.26), (0.2, -0.22, 0.3)), root)
    for side in (-1, 1):
        mesh_obj(f"paw{side}_cream", ellipsoid((0.08, 0.13, 0.06), (side * 0.1, 0.42, 0.07)), root)
    mesh_obj("chest_cream", ellipsoid((0.18, 0.08, 0.13), (0, 0.33, 0.2)), root)
    h = head(root, (-0.02, 0.4, 0.4), sleepy=True)
    h.rotation_euler = (math.radians(-18), 0, math.radians(12))
    h.scale = (0.9, 0.9, 0.9)
    collar = [(math.cos(a) * 0.24, 0.3 + math.sin(a) * 0.14, 0.27 + 0.05 * math.sin(a)) for a in (2 * math.pi * i / 20 for i in range(21))]
    mesh_obj("collar_collar", tube_bm(collar, [0.035] * 21, 8, cap=False), root)
    tag = lathe_bm([(0.02, 0.05), (-0.02, 0.05)])
    mesh_obj("tag_tag", transform_bm(tag, lambda v: v + Vector((0.06, 0.45, 0.19))), root)
    # The tail sweeps from the hip around the right side and across the front, over the paws.
    tail = []
    for i in range(16):
        a = math.radians(-100 + i * 15)
        r = 0.6 + 0.04 * math.sin(i / 3)
        tail.append((math.cos(a) * r, math.sin(a) * r * 0.95, 0.13 + 0.04 * math.sin(math.pi * i / 15)))
    mesh_obj("tail_fur", tube_bm(tail, [0.085 - 0.002 * i for i in range(16)], 10), root)
    return root


def main():
    clear_scene()
    sitting()
    sleeping().location = (3, 0, 0)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_yup=True, export_apply=False,
                              export_materials="NONE")
    print("exported", OUT)


if __name__ == "__main__":
    main()
