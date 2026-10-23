"""Render tea, cake and book icons in the portraits' comic-ink look.

Run: Blender -b --python blender/props.py
Writes godot_web_game/assets/props/<id>.png.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import portraits  # noqa: E402
from kit_common import box_bm, clear_scene, empty, lathe_bm, mesh_obj, sphere_bm, transform_bm, tube_bm  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "props"
GLASS = (0.82, 0.92, 0.95)

TEAS = {
    "tea_steady_leaf": (0.45, 0.75, 0.4),
    "tea_bright_ember": (0.98, 0.55, 0.2),
    "tea_drift_bloom": (0.72, 0.55, 0.92),
}


def tea(root, color):
    toon, flat = portraits.comic_material, portraits.flat_material
    cup = lathe_bm([(0.0, 0.0), (0.0, 0.55), (0.9, 0.7), (0.92, 0.66), (0.08, 0.5), (0.08, 0.0)], axis="z")
    portraits.dress(mesh_obj("cup", cup, root), toon("glass", GLASS))
    liquid = lathe_bm([(0.06, 0.0), (0.06, 0.5), (0.72, 0.64), (0.72, 0.0)], axis="z")
    portraits.dress(mesh_obj("tea", liquid, root), toon("tea", color))
    saucer = lathe_bm([(-0.05, 0.0), (-0.05, 0.95), (0.05, 1.0), (0.0, 0.0)], axis="z")
    portraits.dress(mesh_obj("saucer", saucer, root), toon("saucer", (0.95, 0.92, 0.86)))
    handle = [(0.6 + 0.25 * math.sin(math.pi * i / 10), 0, 0.15 + 0.4 * i / 10) for i in range(11)]
    portraits.dress(mesh_obj("handle", tube_bm(handle, [0.06] * 11, 8), root), toon("glass2", GLASS))
    for i, x in enumerate((-0.25, 0.2)):
        steam = [(x + 0.08 * math.sin(i + j * 1.1), 0, 0.85 + 0.12 * j) for j in range(7)]
        portraits.dress(mesh_obj(f"steam{i}", tube_bm(steam, [0.035] * 7, 6), root),
                        flat("steam", (0.96, 0.97, 1.0)))


def cake_seed(root):
    """Odessa's seed cake: a round loaf speckled with seeds."""
    toon = portraits.comic_material
    body = lathe_bm([(0.0, 0.85), (0.45, 0.85), (0.6, 0.7), (0.65, 0.0)], axis="z")
    portraits.dress(mesh_obj("cake", body, root), toon("crumb", (0.86, 0.66, 0.38)))
    for i in range(14):
        a, r = i * 2.4, 0.15 + 0.045 * i
        seed = sphere_bm(0.05, 8, 4, lambda v: Vector((v.x * 1.6, v.y, v.z * 0.6)))
        portraits.dress(mesh_obj(f"seed{i}", transform_bm(seed, lambda v, a=a, r=r: v + Vector(
            (math.cos(a) * r, math.sin(a) * r, 0.63))), root), toon("seed", (0.35, 0.25, 0.18)))


def cake_moon_plum(root):
    """Moon-plum tart: a shallow crust with a glossy violet top and a cream swirl."""
    toon = portraits.comic_material
    crust = lathe_bm([(0.0, 0.0), (0.0, 0.9), (0.35, 1.0), (0.42, 0.92), (0.3, 0.8), (0.3, 0.0)], axis="z")
    portraits.dress(mesh_obj("crust", crust, root), toon("crust", (0.92, 0.72, 0.42)))
    fill = lathe_bm([(0.0, 0.82), (0.36, 0.8), (0.36, 0.0)], axis="z")
    portraits.dress(mesh_obj("fill", fill, root), toon("plum", (0.52, 0.25, 0.6)))
    swirl = [(0.25 * math.cos(t) * (1 - t / 12), 0.25 * math.sin(t) * (1 - t / 12), 0.42 + 0.025 * t)
             for t in (i * 0.5 for i in range(20))]
    portraits.dress(mesh_obj("cream", tube_bm(swirl, [0.08] * 20, 10), root), toon("cream", (0.98, 0.95, 0.9)))


def cake_nebula_roll(root):
    """Nebula roll: a swiss roll sliced to show a blue-pink spiral."""
    toon = portraits.comic_material
    roll = lathe_bm([(-0.5, 0.0), (-0.5, 0.7), (0.5, 0.7), (0.5, 0.0)], axis="y")
    portraits.dress(mesh_obj("roll", transform_bm(roll, lambda v: v + Vector((0, 0, 0.7))), root),
                    toon("sponge", (0.95, 0.75, 0.82)))
    spiral = [(0.6 * (t / 14) * math.cos(t), -0.51, 0.7 + 0.6 * (t / 14) * math.sin(t))
              for t in (i * 0.35 for i in range(41))]
    portraits.dress(mesh_obj("spiral", tube_bm(spiral, [0.06] * 41, 8), root), toon("jam", (0.35, 0.45, 0.9)))
    for i in range(5):
        star = sphere_bm(0.05, 8, 4)
        portraits.dress(mesh_obj(f"sprinkle{i}", transform_bm(star, lambda v, i=i: v + Vector(
            (-0.35 + 0.18 * i, 0.1 * (i % 2), 1.4))), root), portraits.flat_material("star", (1.0, 0.95, 0.6)))


def book(root):
    toon = portraits.comic_material
    cover = box_bm((1.3, 1.7, 0.28), bevel=0.06)
    portraits.dress(mesh_obj("cover", transform_bm(cover, lambda v: v + Vector((0, 0, 0.14))), root),
                    toon("cover", (0.25, 0.5, 0.55)))
    pages = box_bm((1.2, 1.6, 0.22), bevel=0.02)
    portraits.dress(mesh_obj("pages", transform_bm(pages, lambda v: v + Vector((0.06, 0, 0.14))), root),
                    toon("pages", (0.97, 0.94, 0.85)))
    band = box_bm((1.32, 0.18, 0.3), bevel=0.02)
    portraits.dress(mesh_obj("band", transform_bm(band, lambda v: v + Vector((0, 0.45, 0.14))), root),
                    toon("band", (0.95, 0.75, 0.3)))


PROPS = {**{k: (lambda root, c=c: tea(root, c)) for k, c in TEAS.items()},
         "cake_seed": cake_seed, "cake_moon_plum": cake_moon_plum, "cake_nebula_roll": cake_nebula_roll,
         "book": book}


def render(name, build):
    clear_scene()
    scene = bpy.context.scene
    for style in list(bpy.data.linestyles):
        bpy.data.linestyles.remove(style)
    root = empty("prop")
    build(root)
    portraits.setup_render(scene)
    scene.render.resolution_x = scene.render.resolution_y = 256
    cam = scene.camera
    cam.data.ortho_scale = 2.6
    target = Vector((0, 0, 0.5))
    cam.location = target + Vector((0, -6.0, 4.0))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(OUT_DIR / f"{name}.png")
    bpy.ops.render.render(write_still=True)


OUT_DIR.mkdir(parents=True, exist_ok=True)
# Icons render at 256 square, so fewer halftone cells keep the dots print-sized.
portraits.CELLS = (37, 37)
for name, build in PROPS.items():
    render(name, build)
