"""Render the tablet's field-guide illustrations in the portraits' comic ink.

Run: Blender -b --python blender/illustrations.py -- [name ...]
Writes godot_web_game/assets/illustrations/<name>.png (800x450).

Each plate is a small diorama of a place the story talks about: Quietwater Dock, a drum garden cut
open to show the park curving overhead inside it, Bramble and its rings, and the Lumen Reach light.
"""

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import portraits as P  # noqa: E402
from kit_common import box_bm, clear_scene, empty, lathe_bm, mesh_obj, sphere_bm, transform_bm, tube_bm  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "illustrations"
SIZE = (800, 450)
SPACE = P.hexc("140f26")
## The drum cutaway's open side, in degrees around its axis (180 faces the camera, 90 is the top).
GAP = 150


def paint(name, hexcolor):
    return P.comic_material(name, P.hexc(hexcolor))


def glow(name, hexcolor):
    return P.flat_material(name, P.hexc(hexcolor))


def stars(root, count=160, spread=40.0, depth=30.0):
    rng = random.Random(4)
    mat = glow("star", "fff6e0")
    for i in range(count):
        s = sphere_bm(rng.uniform(0.02, 0.06), 6, 3)
        at = Vector((rng.uniform(-spread, spread), depth + rng.uniform(0, 10), rng.uniform(-spread * 0.6, spread * 0.6)))
        P.dress(mesh_obj(f"star{i}", transform_bm(s, lambda v, a=at: v + a), root), mat)


def banded_planet(root, center, radius, colors, rings=True):
    """A gas giant in latitude bands, with optional rings: Bramble."""
    n = len(colors) * 2
    for i in range(n):
        z0 = -1 + 2 * i / n
        z1 = -1 + 2 * (i + 1) / n
        prof = [(z * radius, max(math.sqrt(max(1 - z * z, 0)) * radius, 0.001)) for z in
                (z0 + (z1 - z0) * k / 6 for k in range(7))]
        band = lathe_bm(prof, segments=48, axis="z")
        P.dress(mesh_obj(f"band{i}", transform_bm(band, lambda v: v + center), root), paint(f"band{i}", colors[i % len(colors)]))
    if rings:
        for k, (r0, r1, col) in enumerate(((1.35, 1.7, "f2dcb3"), (1.78, 2.1, "c9b8d8"))):
            ring = lathe_bm([(0.0, r0 * radius), (0.0, r1 * radius)], segments=64, axis="z")
            obj = mesh_obj(f"ring{k}", transform_bm(ring, lambda v: v + center), root)
            obj.rotation_euler = (math.radians(14), math.radians(-8), 0)
            P.dress(obj, paint(f"ring{k}", col))


def tree(root, name, base, up, height, crown):
    side = up.orthogonal().normalized()
    trunk = [base, base + up * height * 0.6]
    P.dress(mesh_obj(f"{name}trunk", tube_bm(trunk, [height * 0.07, height * 0.05], 8), root), paint(f"{name}bark", "7a5040"))
    top = base + up * height * 0.85
    ball = sphere_bm(height * 0.35, 16, 8)
    P.dress(mesh_obj(f"{name}crown", transform_bm(ball, lambda v, t=top: v + t), root), paint(f"{name}leaf", crown))


# ---------------------------------------------------------------- plates

def drum_gardens(root):
    """A drum cut away on the near side: grass and trees curving all the way round inside, a sun-line
    down the middle, misters, and the dock's hull plating outside."""
    stars(root)
    banded_planet(root, Vector((14, 30, 6)), 7.0, ["3f8f8f", "6b5a9e", "f2dcb3"], rings=False)
    radius, length = 3.0, 9.0
    arc = 270
    for layer, (r, col) in enumerate(((radius + 0.25, "8e9298"), (radius, "6fae5c"))):
        verts = []
        for i in range(25):
            a = math.radians(GAP + 45 + arc * i / 24)
            verts.append((math.cos(a), math.sin(a)))
        for i in range(24):
            (c0, s0), (c1, s1) = verts[i], verts[i + 1]
            panel = box_bm((length, 0.12, 0.12))
            mid_a = math.atan2((s0 + s1) / 2, (c0 + c1) / 2)
            width = r * math.radians(arc / 24) * 1.05
            def place(v, a=mid_a, w=width, rr=r):
                v = Vector((v.x, v.y, v.z * w / 0.12))
                x, y, z = v.x, v.y, v.z
                return Vector((x, math.cos(a) * rr + y * math.cos(a) - z * math.sin(a),
                               math.sin(a) * rr + y * math.sin(a) + z * math.cos(a)))
            P.dress(mesh_obj(f"shell{layer}_{i}", transform_bm(panel, place), root),
                    paint(f"shell{layer}", col))
    for end in (-1, 1):
        rim = [Vector((end * length / 2, math.cos(a) * (radius + 0.3), math.sin(a) * (radius + 0.3)))
               for a in (math.radians(GAP + 45 + arc * i / 32) for i in range(33))]
        P.dress(mesh_obj(f"rim{end}", tube_bm(rim, [0.18] * 33, 8, cap=False), root), paint("rim", "e8a33d"))
    sun = [Vector((-length / 2, 0, 0)), Vector((length / 2, 0, 0))]
    P.dress(mesh_obj("sunline", tube_bm(sun, [0.12, 0.12], 12), root), glow("sun", "fff2b0"))
    rng = random.Random(7)
    colors = ["e48aa0", "8fae7e", "e8a33d", "7d3f6e"]
    for i in range(26):
        a = math.radians(rng.uniform(GAP + 60, GAP + 300))
        x = rng.uniform(-length / 2 + 0.6, length / 2 - 0.6)
        base = Vector((x, math.cos(a) * radius, math.sin(a) * radius))
        inward = Vector((0, -math.cos(a), -math.sin(a)))
        tree(root, f"t{i}", base, inward, rng.uniform(0.6, 1.1), colors[i % len(colors)])
    for i in range(10):
        a = math.radians(rng.uniform(GAP + 60, GAP + 300))
        at = Vector((rng.uniform(-4, 4), math.cos(a) * (radius - 0.6), math.sin(a) * (radius - 0.6)))
        puff = sphere_bm(0.25, 10, 5)
        P.dress(mesh_obj(f"mist{i}", transform_bm(puff, lambda v, t=at: v + t), root), glow("mist", "e9f6ff"))
    return {"target": Vector((0.5, 0, -0.6)), "from": Vector((-5.5, -10.5, 5.5)), "lens": 30}


def dock(root):
    """Quietwater Dock: a long spine of hangar bays and drums, ships coming and going, Bramble behind."""
    stars(root)
    banded_planet(root, Vector((38, 40, -2)), 12.0, ["3f8f8f", "6b5a9e", "f2dcb3", "e48aa0"], rings=False)
    spine = box_bm((14, 1.4, 1.2), bevel=0.2)
    P.dress(mesh_obj("spine", spine, root), paint("spine", "8e9298"))
    for i in range(6):
        bay = box_bm((1.6, 1.8, 1.4), bevel=0.15)
        P.dress(mesh_obj(f"bay{i}", transform_bm(bay, lambda v, k=i: v + Vector((-6 + k * 2.4, -0.9, -0.2))), root),
                paint("bay", "c9a24b"))
        door = box_bm((1.1, 0.1, 0.8))
        P.dress(mesh_obj(f"door{i}", transform_bm(door, lambda v, k=i: v + Vector((-6 + k * 2.4, -1.85, -0.25))), root),
                glow("door", "ffd27a"))
    for i, x in enumerate((-4.5, 1.5, 6.0)):
        drum = lathe_bm([(-1.4, 1.1), (1.4, 1.1)], segments=32, axis="y")
        P.dress(mesh_obj(f"drum{i}", transform_bm(drum, lambda v, xx=x: Vector((v.x + xx, v.y + 0.3, v.z + 2.2))), root),
                paint("drum", "6fae5c"))
        band = lathe_bm([(-0.25, 1.18), (0.25, 1.18)], segments=32, axis="y")
        P.dress(mesh_obj(f"drumband{i}", transform_bm(band, lambda v, xx=x: Vector((v.x + xx, v.y + 0.3, v.z + 2.2))), root),
                paint("drumband", "e8a33d"))
    rng = random.Random(3)
    for i in range(7):
        ship = sphere_bm(0.3, 16, 8, lambda v: Vector((v.x * 1.0, v.y * 2.2, v.z * 0.8)))
        at = Vector((rng.uniform(-8, 8), rng.uniform(-6, -2.5), rng.uniform(-2, 3)))
        P.dress(mesh_obj(f"ship{i}", transform_bm(ship, lambda v, a=at: v + a), root),
                paint(f"ship{i}", ["e63946", "ffc300", "00c2b8", "7b2cbf", "f4f1ea", "9be22d", "ff8c1a"][i]))
        trail = [at + Vector((0, 0.7, 0)), at + Vector((0, 2.2, 0))]
        P.dress(mesh_obj(f"trail{i}", tube_bm(trail, [0.08, 0.01], 6), root), glow("trail", "fff2b0"))
    return {"target": Vector((0.5, 0, 0.8)), "from": Vector((-6, -19, 6)), "lens": 32}


def bramble(root):
    """Bramble with its rings, and Quietwater a speck of light at the rings' edge."""
    stars(root, 220)
    banded_planet(root, Vector((0, 0, 0)), 4.0, ["3f8f8f", "6b5a9e", "f2dcb3", "3f8f8f", "e48aa0", "6b5a9e"])
    speck = sphere_bm(0.12, 8, 4)
    P.dress(mesh_obj("quietwater", transform_bm(speck, lambda v: v + Vector((7.4, -1.5, 1.2))), root), glow("dock", "ffd27a"))
    halo = [Vector((7.4 + math.cos(a) * 0.35, -1.5, 1.2 + math.sin(a) * 0.35)) for a in (2 * math.pi * i / 16 for i in range(17))]
    P.dress(mesh_obj("halo", tube_bm(halo, [0.03] * 17, 6, cap=False), root), glow("halo", "ffd27a"))
    return {"target": Vector((1.5, 0, 0)), "from": Vector((-4, -17, 5)), "lens": 35}


def lumen(root):
    """The Lumen Reach light: a striped tower on a floe in a drifting ice field, beam sweeping."""
    stars(root)
    ice = paint("ice", "dcefff")
    floe = lathe_bm([(-0.5, 2.6), (0.0, 3.0)], segments=32, axis="z")
    P.dress(mesh_obj("floe", floe, root), ice)
    rng = random.Random(9)
    for i in range(18):
        chunk = box_bm((rng.uniform(0.6, 1.6), rng.uniform(0.6, 1.6), rng.uniform(0.15, 0.4)), bevel=0.05)
        at = Vector((rng.uniform(-12, 12), rng.uniform(-2, 14), rng.uniform(-1.2, -0.3)))
        if at.length < 4:
            continue
        P.dress(mesh_obj(f"ice{i}", transform_bm(chunk, lambda v, a=at: v + a), root), ice)
    for k in range(6):
        band = lathe_bm([(k * 0.8, 0.75 - k * 0.06), ((k + 1) * 0.8, 0.75 - (k + 1) * 0.06)], segments=32, axis="z")
        P.dress(mesh_obj(f"tower{k}", band, root), paint(f"stripe{k % 2}", ["c8433f", "f4ecdc"][k % 2]))
    lamp = lathe_bm([(4.8, 0.4), (5.5, 0.4)], segments=24, axis="z")
    P.dress(mesh_obj("lamp", lamp, root), glow("lamp", "ffe08a"))
    cap = lathe_bm([(5.5, 0.55), (6.1, 0.05)], segments=24, axis="z")
    P.dress(mesh_obj("cap", cap, root), paint("cap", "c8433f"))
    beam = lathe_bm([(0.0, 0.25), (14.0, 2.6)], segments=24, axis="y")
    obj = mesh_obj("beam", transform_bm(beam, lambda v: Vector((v.x, v.y, v.z + 5.15))), root)
    obj.rotation_euler = (0, 0, math.radians(-125))
    P.dress(obj, glow("beam", "ffe7a0"))
    whale = sphere_bm(1.0, 24, 12, lambda v: Vector((v.x * 3.2, v.y * 1.1, v.z * 1.0)))
    P.dress(mesh_obj("whale", transform_bm(whale, lambda v: v + Vector((6.5, 6.0, 4.5))), root), paint("whale", "7f9fd6"))
    for k in range(5):
        spot = sphere_bm(0.12, 8, 4)
        P.dress(mesh_obj(f"spot{k}", transform_bm(spot, lambda v, kk=k: v + Vector((4.6 + kk * 0.9, 4.95, 4.9))), root),
                glow("spot", "9fffe0"))
    return {"target": Vector((1.5, 3, 2.6)), "from": Vector((-6, -13, 3.5)), "lens": 30}


PLATES = {"guide_gardens": drum_gardens, "guide_dock": dock, "guide_bramble": bramble, "guide_lumen": lumen}


def render(name, build):
    clear_scene()
    for style in list(bpy.data.linestyles):
        bpy.data.linestyles.remove(style)
    scene = bpy.context.scene
    # Halftone cells about 7 pixels across, set before any material is made.
    P.CELLS = (SIZE[0] / 7, SIZE[1] / 7)
    root = empty("plate")
    shot = build(root)
    P.setup_render(scene)
    scene.render.film_transparent = False
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (*SPACE, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    cam = scene.camera
    cam.data.type = "PERSP"
    cam.data.lens = shot["lens"]
    cam.location = shot["from"]
    cam.rotation_euler = (shot["target"] - shot["from"]).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(OUT_DIR / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, build in PLATES.items():
        if not only or name in only:
            render(name, build)


if __name__ == "__main__":
    main()
