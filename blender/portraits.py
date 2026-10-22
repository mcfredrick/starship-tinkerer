"""Render character portrait sheets: one toon-shaded bust per expression, transparent background.

Run: Blender -b --python blender/portraits.py -- [character ...]
Writes godot_web_game/assets/portraits/<character>_<expression>.png.

Faces look toward -Y (the camera), +Z is up. Expressions only move brows, eyes and mouth, so every
character gets the full set from one description.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from kit_common import (box_bm, clear_scene, empty, lathe_bm, mesh_obj, sphere_bm,  # noqa: E402
                        transform_bm, tube_bm)

OUT_DIR = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "portraits"
SIZE = (512, 640)

# brow: (height, inner tilt; positive lifts the inner ends) per side, eye: openness 0..1 or "arc"
# for happily closed eyes, look: pupil offset, mouth: (smile -1..1, open 0..1, width scale).
EXPRESSIONS = {
    "neutral": {"brow": ((0.0, 0.0), (0.0, 0.0)), "eye": 1.0, "look": (0, 0), "mouth": (0.15, 0.0, 1.0)},
    "happy": {"brow": ((0.05, 0.1), (0.05, 0.1)), "eye": 0.85, "look": (0, 0), "mouth": (0.9, 0.15, 1.1)},
    "laughing": {"brow": ((0.1, 0.15), (0.1, 0.15)), "eye": "arc", "look": (0, 0), "mouth": (1.0, 0.55, 1.15)},
    "thoughtful": {"brow": ((0.1, -0.05), (-0.03, 0.05)), "eye": 0.8, "look": (0.06, 0.05),
                   "mouth": (-0.1, 0.0, 0.7)},
    "surprised": {"brow": ((0.16, 0.05), (0.16, 0.05)), "eye": 1.25, "look": (0, 0), "mouth": (0.0, 0.6, 0.6)},
    "sad": {"brow": ((0.04, 0.3), (0.04, 0.3)), "eye": 0.75, "look": (0, -0.04), "mouth": (-0.6, 0.0, 0.85)},
    "grumpy": {"brow": ((-0.06, -0.3), (-0.06, -0.3)), "eye": 0.7, "look": (0, 0), "mouth": (-0.35, 0.0, 0.8)},
}

CHARACTERS = {
    "odessa": {
        "skin": (0.55, 0.36, 0.25), "hair": (0.86, 0.85, 0.88), "iris": (0.25, 0.15, 0.08),
        "jacket": (0.85, 0.62, 0.22), "accent": (0.18, 0.55, 0.55), "head": (0.88, 0.84, 1.0),
        "hair_style": "bun", "glasses": True, "brow_color": (0.8, 0.8, 0.82),
    },
    "ilse": {
        "skin": (0.93, 0.72, 0.6), "hair": (0.82, 0.7, 0.42), "iris": (0.2, 0.45, 0.6),
        "jacket": (0.78, 0.18, 0.2), "accent": (0.95, 0.95, 0.92), "head": (0.82, 0.82, 1.05),
        "hair_style": "bob", "goggles": True, "brow_color": (0.75, 0.62, 0.35),
    },
    "brindle": {
        "robot": True, "shell": (0.42, 0.62, 0.62), "jacket": (0.95, 0.5, 0.15), "glow": (0.55, 1.0, 0.85),
        "screen": (0.06, 0.1, 0.12), "accent": (0.25, 0.27, 0.3),
    },
}


# ---------------------------------------------------------------- materials

def toon_material(name, color, shadow=0.62):
    """Two-band cel shading: diffuse light through a constant ramp, emitted so colors stay exact."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].color = (shadow, shadow, shadow * 1.05, 1)
    ramp.color_ramp.elements[1].position = 0.35
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["B"].default_value = (*color, 1)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(diffuse.outputs["BSDF"], to_rgb.inputs["Shader"])
    nt.links.new(to_rgb.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["A"])
    nt.links.new(mix.outputs["Result"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return m


def flat_material(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*color, 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return m


def outline_material():
    m = flat_material("outline", (0.05, 0.04, 0.06))
    m.use_backface_culling = True
    return m


OUTLINE = None


def dress(obj, material, line=0.018):
    """Assign a material and an inverted-hull outline (a flipped, back-face-culled shell)."""
    obj.data.materials.append(material)
    if line:
        obj.data.materials.append(OUTLINE)
        mod = obj.modifiers.new("outline", "SOLIDIFY")
        mod.thickness = line
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.material_offset = 1
    return obj


# ---------------------------------------------------------------- face helpers

def face_point(head, x, z, out=0.0):
    """Point on the front of an ellipsoid head of radii `head` at (x, z), pushed `out` along -Y."""
    rx, ry, rz = head
    k = max(1 - (x / rx) ** 2 - (z / rz) ** 2, 0.02)
    return Vector((x, -ry * math.sqrt(k) - out, z))


def build_eyes(c, e, mats, root, head, eye_z=0.08, spacing=0.31, eye_r=0.13):
    for side in (-1, 1):
        x = side * spacing
        base = face_point(head, x, eye_z, out=-0.04)
        tag = "lr"[side > 0]
        if e["eye"] == "arc":
            pts = [base + Vector((side * 0 + (i / 8 - 0.5) * 0.22, -0.06, 0.035 * math.sin(math.pi * i / 8)))
                   for i in range(9)]
            dress(mesh_obj(f"lid{tag}", tube_bm(pts, [0.022] * 9, 8), root), mats["line"], line=0)
            continue
        open_ = e["eye"]
        white = sphere_bm(eye_r, 24, 12, lambda v: Vector((v.x, v.y * 0.6, v.z * 1.15 * open_)))
        dress(mesh_obj(f"white{tag}", transform_bm(white, lambda v: v + base), root), mats["white"], line=0.012)
        lx, lz = e["look"]
        pupil_at = base + Vector((lx, -eye_r * 0.55, lz * open_))
        iris = sphere_bm(eye_r * 0.62, 16, 8, lambda v: Vector((v.x, v.y * 0.4, v.z * 1.1 * min(open_, 1.0))))
        dress(mesh_obj(f"iris{tag}", transform_bm(iris, lambda v: v + pupil_at), root), mats["iris"], line=0)
        glint = sphere_bm(eye_r * 0.18, 8, 4)
        dress(mesh_obj(f"glint{tag}", transform_bm(glint, lambda v: v + pupil_at + Vector((-0.03, -0.04, 0.04))),
                       root), mats["white"], line=0)


def build_brows(e, mats, root, head, brow_z=0.33, spacing=0.31):
    for side, (height, tilt) in zip((-1, 1), e["brow"]):
        pts = []
        for i in range(7):
            u = i / 6
            x = side * (spacing - 0.13 + 0.26 * u)
            inner = 1 - u
            z = brow_z + height + tilt * 0.35 * (inner - 0.5) + 0.03 * math.sin(math.pi * u)
            pts.append(face_point(head, x, z, out=0.02))
        dress(mesh_obj(f"brow{'lr'[side > 0]}", tube_bm(pts, [0.032] * 7, 8), root), mats["brow"], line=0)


def build_mouth(e, mats, root, head, mouth_z=-0.42):
    smile, open_, width = e["mouth"]
    w = 0.2 * width
    if open_ > 0:
        cavity = sphere_bm(1.0, 24, 12, lambda v: Vector((v.x * w * 0.9, v.y * 0.05,
                                                          v.z * 0.16 * open_ if v.z < 0 else v.z * 0.03)))
        at = face_point(head, 0, mouth_z - 0.04 * open_, out=-0.02)
        dress(mesh_obj("cavity", transform_bm(cavity, lambda v: v + at), root), mats["mouth"], line=0.012)
    pts = []
    for i in range(9):
        u = (i / 8) * 2 - 1
        z = mouth_z + smile * 0.07 * (u * u - 0.5)
        pts.append(face_point(head, u * w, z, out=0.015))
    dress(mesh_obj("lips", tube_bm(pts, [0.02] * 9, 8), root), mats["line"], line=0)


# ---------------------------------------------------------------- characters

def smooth(d, width=0.08):
    """0 below -width, 1 above +width, smooth in between: soft hairlines without jagged steps."""
    t = min(max((d + width) / (2 * width), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def hair_shell(v, head, puff, cover):
    """Scale a unit-sphere vertex onto the head, puffed out where hair covers and tucked in elsewhere."""
    k = 0.93 + (puff - 0.93) * cover
    return Vector((v.x * head[0] * k, v.y * head[1] * k, v.z * head[2] * k))


def human(c, e):
    head = c["head"]
    mats = {
        "skin": toon_material("skin", c["skin"]), "hair": toon_material("hair", c["hair"]),
        "jacket": toon_material("jacket", c["jacket"]), "accent": toon_material("accent", c["accent"]),
        "white": flat_material("white", (0.97, 0.96, 0.94)), "iris": flat_material("iris", c["iris"]),
        "brow": flat_material("brow", c["brow_color"]), "line": flat_material("line", (0.12, 0.06, 0.06)),
        "mouth": flat_material("mouth", (0.35, 0.08, 0.1)), "metal": toon_material("metal", (0.7, 0.68, 0.6)),
        "glass": flat_material("glass", (0.75, 0.9, 0.95)),
    }
    root = empty("portrait")
    dress(mesh_obj("head", sphere_bm(1.0, 48, 24, lambda v: Vector((v.x * head[0], v.y * head[1], v.z * head[2]))),
                   root), mats["skin"])
    nose = sphere_bm(0.11, 16, 8, lambda v: Vector((v.x, v.y * 1.2, v.z * 1.2)))
    dress(mesh_obj("nose", transform_bm(nose, lambda v: v + face_point(head, 0, -0.12, out=0.02)), root),
          mats["skin"], line=0.012)
    for side in (-1, 1):
        ear = sphere_bm(0.17, 16, 8, lambda v: Vector((v.x * 0.5, v.y * 0.8, v.z)))
        dress(mesh_obj(f"ear{'lr'[side > 0]}", transform_bm(ear, lambda v, s=side: v + Vector((s * head[0] * 0.98, 0.05, -0.02))),
                       root), mats["skin"])
    neck = lathe_bm([(-0.6, 0.3), (-1.15, 0.33)], axis="z")
    dress(mesh_obj("neck", neck, root), mats["skin"])
    bust = lathe_bm([(-0.95, 0.36), (-1.1, 0.55), (-1.35, 0.95), (-1.7, 1.1), (-2.3, 1.15)], axis="z",
                    squash=(1.35, 0.6))
    dress(mesh_obj("bust", bust, root), mats["jacket"])
    collar = lathe_bm([(-0.88, 0.37), (-0.98, 0.5), (-1.08, 0.52)], axis="z", squash=(1.1, 0.95))
    dress(mesh_obj("collar", collar, root), mats["accent"])

    if c["hair_style"] == "bun":
        def cap(v):
            cover = min(max(smooth(v.z - (0.45 - 0.15 * abs(v.x))), smooth(v.y + 0.2)), smooth(v.z + 0.15))
            return hair_shell(v, head, 1.07, cover)
        dress(mesh_obj("hair", sphere_bm(1.0, 64, 32, cap), root), mats["hair"])
        bun = sphere_bm(0.42, 24, 12)
        dress(mesh_obj("bun", transform_bm(bun, lambda v: v + Vector((0, 0.45, 0.95))), root), mats["hair"])
    else:
        def bob(v):
            cover = min(max(smooth(v.z - (0.42 + 0.22 * v.x)), smooth(v.y + 0.25)), smooth(v.z + 0.6))
            return hair_shell(v, head, 1.1, cover)
        dress(mesh_obj("hair", sphere_bm(1.0, 64, 32, bob), root), mats["hair"])

    build_eyes(c, e, mats, root, head)
    build_brows(e, mats, root, head)
    build_mouth(e, mats, root, head)
    blush = flat_material("blush", tuple(min(ch * 1.15 + 0.08, 1) for ch in (c["skin"][0] * 1.1, c["skin"][1] * 0.8,
                                                                               c["skin"][2] * 0.85)))
    for side in (-1, 1):
        cheek = sphere_bm(0.12, 16, 8, lambda v: Vector((v.x * 1.2, v.y * 0.15, v.z * 0.7)))
        at = face_point(head, side * 0.42, -0.2, out=0.0)
        dress(mesh_obj(f"cheek{'lr'[side > 0]}", transform_bm(cheek, lambda v, a=at: v + a), root), blush, line=0)

    if c.get("glasses"):
        for side in (-1, 1):
            center = face_point(head, side * 0.31, 0.08, out=0.1)
            ring = [center + Vector((math.cos(a) * 0.19, 0, math.sin(a) * 0.17))
                    for a in (2 * math.pi * i / 24 for i in range(25))]
            dress(mesh_obj(f"rim{'lr'[side > 0]}", tube_bm(ring, [0.022] * 25, 8, cap=False), root),
                  mats["metal"], line=0)
        bridge = [face_point(head, -0.12, 0.1, out=0.1), face_point(head, 0, 0.13, out=0.12),
                  face_point(head, 0.12, 0.1, out=0.1)]
        dress(mesh_obj("bridge", tube_bm(bridge, [0.018] * 3, 6), root), mats["metal"], line=0)
    if c.get("goggles"):
        strap = [Vector((math.cos(a) * head[0] * 1.13, math.sin(a) * head[1] * 1.13, 0.62))
                 for a in (math.pi * i / 16 for i in range(17))]
        dress(mesh_obj("strap", tube_bm(strap, [0.06] * 17, 8), root), mats["accent"], line=0.01)
        for side in (-1, 1):
            lens = lathe_bm([(0.1, 0.0), (0.1, 0.17), (-0.05, 0.19)], axis="y", squash=(1, 1))
            at = face_point(head, side * 0.3, 0.6, out=0.06)
            dress(mesh_obj(f"goggle{'lr'[side > 0]}", transform_bm(lens, lambda v, a=at: Vector((v.x, -v.y, v.z)) + a),
                           root), mats["glass"], line=0.014)
    return root


def robot(c, e):
    mats = {
        "shell": toon_material("shell", c["shell"]), "jacket": toon_material("vest", c["jacket"]),
        "accent": toon_material("accent", c["accent"]), "screen": flat_material("screen", c["screen"]),
        "glow": flat_material("glow", c["glow"]),
    }
    root = empty("portrait")
    dress(mesh_obj("head", box_bm((1.9, 1.5, 1.6), bevel=0.35, segments=4), root), mats["shell"])
    dress(mesh_obj("screen", transform_bm(box_bm((1.5, 0.1, 1.05), bevel=0.2, segments=3),
                                          lambda v: v + Vector((0, -0.72, -0.02))), root), mats["screen"], line=0.01)
    for side in (-1, 1):
        bolt = lathe_bm([(0.1, 0.3), (-0.1, 0.3)], axis="y")
        dress(mesh_obj(f"bolt{'lr'[side > 0]}", transform_bm(bolt, lambda v, s=side: Vector((v.y + s * 1.0, v.x, v.z))),
                       root), mats["accent"])
    antenna = [(0.3, 0.1, 0.8 + 0.08 * i) for i in range(6)]
    dress(mesh_obj("antenna", tube_bm(antenna, [0.04] * 6, 8), root), mats["accent"], line=0.01)
    dress(mesh_obj("bulb", transform_bm(sphere_bm(0.1, 12, 6), lambda v: v + Vector((0.3, 0.1, 1.28))), root),
          mats["glow"], line=0.01)
    neck = lathe_bm([(-0.75, 0.25), (-1.2, 0.28)], axis="z")
    dress(mesh_obj("neck", neck, root), mats["accent"])
    bust = lathe_bm([(-1.0, 0.4), (-1.15, 0.7), (-1.4, 1.05), (-1.8, 1.15), (-2.3, 1.15)], axis="z",
                    squash=(1.3, 0.65))
    dress(mesh_obj("vest", bust, root), mats["jacket"])

    # Eyes and brows are glowing shapes on the face screen.
    z0, y = 0.02, -0.79
    for side, (height, tilt) in zip((-1, 1), e["brow"]):
        x = side * 0.38
        tag = "lr"[side > 0]
        if e["eye"] == "arc":
            pts = [Vector((x + (i / 8 - 0.5) * 0.3, y, z0 + 0.06 * math.sin(math.pi * i / 8))) for i in range(9)]
            dress(mesh_obj(f"eye{tag}", tube_bm(pts, [0.04] * 9, 8), root), mats["glow"], line=0)
        else:
            open_ = e["eye"]
            lx, lz = e["look"]
            eye = sphere_bm(0.15, 16, 8, lambda v: Vector((v.x, v.y * 0.2, v.z * 1.2 * open_)))
            dress(mesh_obj(f"eye{tag}", transform_bm(eye, lambda v, p=(x + lx, y, z0 + lz): v + Vector(p)), root),
                  mats["glow"], line=0)
        pts = []
        for i in range(5):
            u = i / 4
            inner = 1 - u if side > 0 else u
            bx = x + (u - 0.5) * 0.3
            pts.append(Vector((bx, y, z0 + 0.3 + height + tilt * 0.3 * (inner - 0.5))))
        dress(mesh_obj(f"brow{tag}", tube_bm(pts, [0.03] * 5, 6), root), mats["glow"], line=0)
    smile, open_, width = e["mouth"]
    w = 0.22 * width
    pts = [Vector(((i / 8 * 2 - 1) * w, y, -0.28 + smile * 0.08 * (((i / 8 * 2 - 1) ** 2) - 0.5) - 0.05 * open_))
           for i in range(9)]
    dress(mesh_obj("mouth", tube_bm(pts, [0.03 + 0.05 * open_] * 9, 8), root), mats["glow"], line=0)
    return root


# ---------------------------------------------------------------- render

def setup_render(scene):
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("world")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    scene.collection.objects.link(sun)
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35))

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.9
    target = Vector((0, 0, -0.45))
    cam.location = target + Vector((1.6, -6.0, 0.9))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam


def render(name, expression, character):
    global OUTLINE
    clear_scene()
    scene = bpy.context.scene
    OUTLINE = outline_material()
    (robot if character.get("robot") else human)(character, EXPRESSIONS[expression])
    setup_render(scene)
    scene.render.filepath = str(OUT_DIR / f"{name}_{expression}.png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(CHARACTERS)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in names:
        for expression in EXPRESSIONS:
            render(name, expression, CHARACTERS[name])


if __name__ == "__main__":
    main()
