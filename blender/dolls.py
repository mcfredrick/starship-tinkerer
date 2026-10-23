"""Render the paper-doll layers that generated customers' portraits are assembled from.

Run: Blender -b --python blender/dolls.py
Writes godot_web_game/assets/dolls/<layer>.png.

Every layer uses the portraits' comic ink and framing but is painted white, so the game can tint it
by multiplying in a color: white takes the color, the halftone shade becomes a darker version of
it, and ink stays ink. The game stacks layers back to front:

  body_<outfit> (outfit color), trim_<outfit> (accent), extra_<extra>_<head> (accent),
  head_<head> (skin), stache (accent), eyes_<count>_<expression>, mouth_<expression>

Faces sit on the reference head, and every head shares its face area, so one set of eyes and
mouths fits all of them. Extras depend on the head's size, so they're rendered per head shape.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import portraits as P  # noqa: E402
from kit_common import box_bm, clear_scene, empty, lathe_bm, mesh_obj, slab_bm, sphere_bm, transform_bm, tube_bm  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "dolls"
WHITE = (1.0, 1.0, 1.0)
REF_HEAD = (1.0, 0.88, 0.88)
HEADS = {"round": (1.0, 0.88, 0.9), "wide": (1.22, 0.86, 0.8), "tall": (0.78, 0.8, 1.25), "bean": (0.9, 0.86, 1.08)}
OUTFITS = ("jacket", "sweater", "robe", "overalls")
EXTRAS = ("antennae", "frills", "gills", "crest", "horns", "ears")
EYE_COUNTS = (1, 2, 3, 4)


def paint():
    return P.comic_material("paint", WHITE)


def face_mats():
    return {
        "white": P.flat_material("white", (1, 1, 1)), "iris": P.flat_material("iris", P.hexc("1a1030")),
        "brow": P.flat_material("brow", P.INK), "line": P.flat_material("line", P.INK),
        "mouth": P.flat_material("mouth", P.hexc("6b0f2e")),
    }


# ---------------------------------------------------------------- layers

def body(outfit, trim_only):
    root = empty("doll")
    m = paint()
    if not trim_only:
        shape = lathe_bm([(-0.8, 0.5), (-1.0, 0.75), (-1.35, 1.0), (-1.7, 1.1), (-2.3, 1.15)], axis="z",
                         squash=(1.3, 0.62))
        P.dress(mesh_obj("bust", shape, root), m)
        return
    if outfit == "jacket":
        collar = lathe_bm([(-0.72, 0.5), (-0.82, 0.68), (-0.92, 0.72)], axis="z", squash=(1.12, 0.9))
        P.dress(mesh_obj("collar", collar, root), m)
    elif outfit == "sweater":
        neck = lathe_bm([(-0.55, 0.52), (-0.6, 0.6), (-0.95, 0.66), (-1.0, 0.6)], axis="z", squash=(1.1, 0.9))
        P.dress(mesh_obj("roll", neck, root), m)
        for i in range(5):
            rib = lathe_bm([(-0.62 - i * 0.07, 0.67), (-0.65 - i * 0.07, 0.67)], axis="z", squash=(1.1, 0.9))
            P.dress(mesh_obj(f"rib{i}", rib, root), m)
    elif outfit == "robe":
        for side in (-1, 1):
            lapel = slab_bm([(0.0, 0.0), (0.55, 0.2), (0.7, -0.9), (0.15, -1.2)], 0.08, 0.9)
            P.dress(mesh_obj(f"lapel{side}", transform_bm(lapel, lambda v, s=side: Vector(
                (s * (v.x + 0.05), -0.75 - v.z, v.y - 0.85))), root), m)
    else:
        bib = box_bm((0.8, 0.12, 0.7), bevel=0.08)
        P.dress(mesh_obj("bib", transform_bm(bib, lambda v: v + Vector((0, -0.72, -1.55))), root), m)
        for side in (-1, 1):
            strap = [(side * 0.32, -0.62, -1.25), (side * 0.42, -0.5, -0.95), (side * 0.55, -0.2, -0.82)]
            P.dress(mesh_obj(f"strap{side}", tube_bm(strap, [0.07] * 3, 8), root), m)
            button = sphere_bm(0.06, 10, 5)
            P.dress(mesh_obj(f"button{side}", transform_bm(button, lambda v, s=side: v + Vector((s * 0.3, -0.8, -1.25))),
                             root), m)


def head(shape):
    root = empty("doll")
    P.egg_head(HEADS[shape], {"skin": paint()}, root, taper_top=0.2 if shape == "bean" else 0.0,
               jowl=0.12 if shape in ("round", "wide") else 0.0)


def extra(name, shape):
    h = HEADS[shape]
    root = empty("doll")
    m = paint()
    if name == "antennae":
        for side in (-1, 1):
            pts = []
            for i in range(12):
                a = i / 11 * math.pi * 1.1
                pts.append(Vector((side * (0.28 + 0.4 * math.sin(a) * i / 11) * h[0], 0.1, h[2] * 0.8 + 0.75 * math.sin(a * 0.9))))
            P.dress(mesh_obj(f"stalk{side}", tube_bm(pts, [0.09 - 0.035 * i / 11 for i in range(12)], 8), root), m)
            P.dress(mesh_obj(f"pom{side}", transform_bm(sphere_bm(0.15, 16, 8), lambda v, p=pts[-1]: v + p), root), m)
    elif name == "frills":
        for side in (-1, 1):
            frill = sphere_bm(0.32, 16, 8, lambda v: Vector((v.x * 0.35, v.y * 0.5, v.z)))
            P.dress(mesh_obj(f"frill{side}", transform_bm(frill, lambda v, s=side: Vector(
                (v.x + s * h[0] * 1.0, v.y + 0.1, v.z + 0.05 + s * v.x * 0.8))), root), m)
    elif name == "gills":
        for side in (-1, 1):
            for k, (lift, reach, rise) in enumerate(((0.4, 0.38, 0.45), (0.12, 0.45, 0.25), (-0.16, 0.38, 0.08))):
                start = Vector((side * h[0] * 0.88, 0.15, lift * h[2] / 0.85))
                pts = [start + Vector((side * reach * u, 0.2 * u, rise * u + 0.08 * math.sin(math.pi * u))) for u in
                       (i / 7 for i in range(8))]
                P.dress(mesh_obj(f"gill{side}{k}", tube_bm(pts, [0.07 - 0.04 * i / 7 for i in range(8)], 8), root), m)
                for j in range(2, 8, 2):
                    tuft = sphere_bm(0.06, 10, 5, lambda v: Vector((v.x, v.y, v.z * 1.6)))
                    P.dress(mesh_obj(f"tuft{side}{k}{j}", transform_bm(tuft, lambda v, p=pts[j]: v + p + Vector((0, 0, 0.07))),
                                     root), m)
    elif name == "crest":
        crest = [Vector((0, 0.1 + 0.35 * i / 8, h[2] * 0.95 + 0.28 * math.sin(math.pi * i / 8) - 0.1 * i / 8)) for i in range(9)]
        P.dress(mesh_obj("crest", tube_bm(crest, [0.12 * math.sin(math.pi * (i + 1) / 10) for i in range(9)], 10), root), m)
    elif name == "horns":
        for side in (-1, 1):
            pts = [Vector((side * (h[0] * 0.5 + 0.35 * u + 0.15 * u * u), 0.05, h[2] * 0.75 + 0.55 * u - 0.1 * u * u))
                   for u in (i / 9 for i in range(10))]
            P.dress(mesh_obj(f"horn{side}", tube_bm(pts, [0.16 * (1 - i / 10) + 0.015 for i in range(10)], 10), root), m)
    elif name == "ears":
        for side in (-1, 1):
            ear = sphere_bm(0.42, 16, 8, lambda v: Vector((v.x * 0.9, v.y * 0.25, v.z * 1.25)))
            P.dress(mesh_obj(f"ear{side}", transform_bm(ear, lambda v, s=side: Vector(
                (v.x + s * h[0] * 1.15, v.y + 0.1, v.z + 0.15 - s * v.x * 0.3))), root), m)


def stache():
    root = empty("doll")
    m = paint()
    lip = P.face_point(REF_HEAD, 0, -0.22, out=0.08)
    for side in (-1, 1):
        pts = []
        for i in range(18):
            u = i / 17
            if u < 0.6:
                t = u / 0.6
                pts.append(lip + Vector((side * (0.04 + 0.45 * t), -0.04 * t, -0.08 * math.sin(math.pi * t))))
            else:
                a = (u - 0.6) / 0.4 * math.pi * 1.4
                pts.append(lip + Vector((side * (0.49 + 0.11 * math.sin(a)), -0.04, 0.11 - 0.11 * math.cos(a))))
        P.dress(mesh_obj(f"stache{side}", tube_bm(pts, [0.075 - 0.055 * (i / 17) ** 1.2 for i in range(18)], 12), root), m)


def eyes(count, expression):
    root = empty("doll")
    mats = face_mats()
    e = P.EXPRESSIONS[expression]
    if count == 1:
        P.build_eyes(e, mats, root, REF_HEAD, eye_z=0.12, eye_r=0.24, count=1)
        P.build_brows(e, mats, root, REF_HEAD, brow_z=0.45, spacing=0.13, length=0.2)
        return
    P.build_eyes(e, mats, root, REF_HEAD, eye_r=0.16 if count < 4 else 0.13, spacing=0.34)
    P.build_brows(e, mats, root, REF_HEAD, spacing=0.34)
    if count == 3:
        opened = 0.9 if e["eye"] != "arc" and e["eye"] > 1 else 0.3
        third = sphere_bm(0.085, 16, 8, lambda v: Vector((v.x, v.y * 0.5, v.z * opened)))
        P.dress(mesh_obj("third", transform_bm(third, lambda v: v + P.face_point(REF_HEAD, 0, 0.55, out=-0.02)), root),
                mats["iris"])
    elif count == 4:
        P.build_eyes(e, mats, empty("upper", root), REF_HEAD, eye_z=0.55, eye_r=0.085, spacing=0.2)


def mouth(expression):
    root = empty("doll")
    P.build_mouth(P.EXPRESSIONS[expression], face_mats(), root, REF_HEAD, mouth_z=-0.4)


# ---------------------------------------------------------------- render

def render(name, build):
    clear_scene()
    for style in list(bpy.data.linestyles):
        bpy.data.linestyles.remove(style)
    scene = bpy.context.scene
    build()
    P.setup_render(scene)
    scene.render.filepath = str(OUT_DIR / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def layers():
    for outfit in OUTFITS:
        yield f"body_{outfit}", lambda o=outfit: body(o, False)
        yield f"trim_{outfit}", lambda o=outfit: body(o, True)
    for shape in HEADS:
        yield f"head_{shape}", lambda s=shape: head(s)
        for name in EXTRAS:
            yield f"extra_{name}_{shape}", lambda n=name, s=shape: extra(n, s)
    yield "stache", stache
    for count in EYE_COUNTS:
        for expression in P.EXPRESSIONS:
            yield f"eyes_{count}_{expression}", lambda c=count, x=expression: eyes(c, x)
    for expression in P.EXPRESSIONS:
        yield f"mouth_{expression}", lambda x=expression: mouth(x)


def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, build in layers():
        if not only or any(name.startswith(o) for o in only):
            render(name, build)


if __name__ == "__main__":
    main()
