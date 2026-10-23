"""Render character portrait sheets: one comic-inked alien bust per expression, transparent background.

Run: Blender -b --python blender/portraits.py -- [character ...]
Writes godot_web_game/assets/portraits/<character>_<expression>.png.

The look is a comic panel: Freestyle brush lines that swell, taper and wobble, halftone dots through
the midtones and hatching in the deepest shadows. Shading is done in screen space, so it stays
print-sized whatever the shape. Faces look toward -Y (the camera), +Z is up. Expressions only move
brows, eyes and mouth, so every character gets the full set from one description.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from kit_common import box_bm, clear_scene, empty, lathe_bm, mesh_obj, sphere_bm, transform_bm, tube_bm  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "portraits"
SIZE = (512, 640)
# Halftone and hatch spacing, in cells across and down the frame (about 7 pixels each).
CELLS = (74, 92)

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


def hexc(h):
    """sRGB hex to the linear values Blender's emission expects, so colors land exactly as picked."""
    return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))


INK = hexc("1a0f24")

CHARACTERS = {
    # A three-eyed grandmother with pom-tipped antennae, ear frills and round glasses.
    "odessa": {"build": "odessa", "skin": hexc("ff5a5f"), "jacket": hexc("ffc300"), "accent": hexc("00c2b8"),
               "iris": hexc("2b0f54"), "head": (1.02, 0.88, 0.86)},
    # A racer with an axolotl's grin and feathery gill fronds, goggles pushed up.
    "ilse": {"build": "ilse", "skin": hexc("5ec8f2"), "jacket": hexc("e63946"), "accent": hexc("ff70a6"),
             "trim": hexc("fff4e0"), "iris": hexc("14213d"), "head": (1.0, 0.85, 0.8)},
    # A gourd-headed, one-eyed yacht owner with a monocle, gold crest and curled tentacle mustache.
    "crake": {"build": "crake", "skin": hexc("9be22d"), "jacket": hexc("7b2cbf"), "accent": hexc("ffb703"),
              "stache": hexc("4f8a10"), "iris": hexc("ff2e63"), "head": (0.68, 0.72, 1.22)},
    # A maintenance robot with a face screen.
    "brindle": {"build": "robot", "shell": hexc("3fb8af"), "jacket": hexc("ff8c1a"), "accent": hexc("4a4e69"),
                "glow": hexc("9dffd9"), "screen": hexc("10232b")},
    # Pip Arkwright: a small, nervous new pilot with huge eyes, floppy ears and a flight scarf.
    "pip": {"build": "alien", "skin": hexc("c9a7f2"), "jacket": hexc("2a9d8f"), "accent": hexc("ffd166"),
            "trim": hexc("f4a6b8"), "iris": hexc("1d3557"), "head": (0.92, 0.84, 0.86), "jowl": 0.1,
            "eyes": {"count": 2, "r": 0.2, "spacing": 0.33, "z": 0.06}, "mouth_z": -0.38,
            "extras": ["floppy_ears", "scarf", "freckles"]},
    # Tam and Juniper Okafor: Moothe siblings who run a noodle cart, horned and soft-eared.
    "tam": {"build": "alien", "skin": hexc("d9a066"), "jacket": hexc("f4f1ea"), "accent": hexc("c8433f"),
            "trim": hexc("8a5a3c"), "iris": hexc("2b1d14"), "head": (1.08, 0.88, 0.92), "jowl": 0.2,
            "eyes": {"count": 2, "r": 0.13, "spacing": 0.36, "z": 0.1}, "mouth_z": -0.4,
            "extras": ["horns", "cow_ears", "chef_hat"]},
    "juniper": {"build": "alien", "skin": hexc("b8805a"), "jacket": hexc("e9c46a"), "accent": hexc("2a9d8f"),
                "trim": hexc("8a5a3c"), "iris": hexc("2b1d14"), "head": (1.0, 0.86, 0.94), "jowl": 0.12,
                "eyes": {"count": 2, "r": 0.14, "spacing": 0.34, "z": 0.1}, "mouth_z": -0.4,
                "extras": ["horns", "cow_ears", "headscarf"]},
    # Dr. Sol Yaneva: a tall, leafy botanist who is at least partly a plant, with round spectacles.
    "yaneva": {"build": "alien", "skin": hexc("7fb069"), "jacket": hexc("f4f1ea"), "accent": hexc("6b4226"),
               "trim": hexc("e48aa0"), "iris": hexc("3a2410"), "head": (0.78, 0.8, 1.2), "taper": 0.12,
               "eyes": {"count": 2, "r": 0.12, "spacing": 0.28, "z": 0.2}, "mouth_z": -0.45,
               "extras": ["leaves", "spectacles"]},
    # Halloran, who ran the shop before you: a weathered tinkerer with goggles pushed up and a white beard.
    "halloran": {"build": "alien", "skin": hexc("8fa3b8"), "jacket": hexc("6b4226"), "accent": hexc("e8a33d"),
                 "trim": hexc("f4f1ea"), "iris": hexc("2b1d14"), "head": (1.0, 0.86, 0.96), "jowl": 0.15,
                 "eyes": {"count": 2, "r": 0.12, "spacing": 0.33, "z": 0.1}, "mouth_z": -0.32,
                 "extras": ["goggles", "beard"]},
    # Captain Mabe Rook, of the long-haul freighter Unquiet Margin.
    "rook": {"build": "alien", "skin": hexc("3f8f8f"), "jacket": hexc("1d3557"), "accent": hexc("e8b931"),
             "trim": hexc("c8433f"), "iris": hexc("f2c14e"), "head": (0.8, 0.82, 1.15), "taper": 0.15,
             "eyes": {"count": 2, "r": 0.13, "spacing": 0.28, "z": 0.18}, "mouth_z": -0.45,
             "extras": ["captain_cap"]},
    # Professor Ondine Ashgrove, of the Ringward Engineering Academy.
    "ashgrove": {"build": "alien", "skin": hexc("e48aa0"), "jacket": hexc("264653"), "accent": hexc("c9a24b"),
                 "trim": hexc("4a3428"), "iris": hexc("14213d"), "head": (1.04, 0.86, 0.9), "jowl": 0.05,
                 "eyes": {"count": 2, "r": 0.12, "spacing": 0.32, "z": 0.1}, "mouth_z": -0.38,
                 "extras": ["spectacles", "bun"]},
    # Nan Tallow, who runs a salvage yard on a little moon and raised you in it.
    "tallow": {"build": "alien", "skin": hexc("9be22d"), "jacket": hexc("8a5a3c"), "accent": hexc("e63946"),
               "trim": hexc("f4a261"), "iris": hexc("2b1d14"), "head": (1.1, 0.88, 0.86), "jowl": 0.22,
               "eyes": {"count": 2, "r": 0.15, "spacing": 0.36, "z": 0.08}, "mouth_z": -0.36,
               "extras": ["antennae", "freckles", "headscarf"]},
    # Sprocket, the shop cat Halloran left behind: a moody tuxedo with a green collar and a gold tag.
    "sprocket": {"build": "cat", "skin": hexc("3b3742"), "jacket": hexc("2f9e5b"), "stache": hexc("e8b931"),
                "accent": hexc("f4f1ea"), "trim": hexc("f4a6b8"), "iris": hexc("b7e24a"), "head": (1.08, 0.86, 0.84)},
}


# ---------------------------------------------------------------- materials

def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


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


def _math(nt, op, a, b, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, x in enumerate((a, b)):
        if isinstance(x, (int, float)):
            n.inputs[i].default_value = x
        else:
            nt.links.new(x, n.inputs[i])
    return n.outputs[0]


def _screen(nt, angle):
    """Window coordinates in halftone cells, rotated so dots and hatching run on a diagonal."""
    coord = nt.nodes.new("ShaderNodeTexCoord")
    scale = nt.nodes.new("ShaderNodeVectorMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = (*CELLS, 0)
    nt.links.new(coord.outputs["Window"], scale.inputs[0])
    rot = nt.nodes.new("ShaderNodeVectorRotate")
    rot.rotation_type = "Z_AXIS"
    rot.inputs["Angle"].default_value = math.radians(angle)
    nt.links.new(scale.outputs[0], rot.inputs["Vector"])
    return rot.outputs[0]


def _mix(nt, factor, a, b):
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    for slot, v in (("A", a), ("B", b)):
        if isinstance(v, tuple):
            mix.inputs[slot].default_value = (*v, 1)
        else:
            nt.links.new(v, mix.inputs[slot])
    nt.links.new(factor, mix.inputs["Factor"])
    return mix.outputs["Result"]


def comic_material(name, color):
    """Flat color, halftone dots that grow as the light falls off, and ink hatching in deep shadow."""
    shade = lerp(tuple(ch * 0.45 for ch in color), (0.03, 0.0, 0.1), 0.3)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(diffuse.outputs[0], to_rgb.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(to_rgb.outputs[0], bw.inputs[0])
    light = bw.outputs[0]

    frac = nt.nodes.new("ShaderNodeVectorMath")
    frac.operation = "FRACTION"
    nt.links.new(_screen(nt, 45), frac.inputs[0])
    centered = nt.nodes.new("ShaderNodeVectorMath")
    centered.operation = "SUBTRACT"
    centered.inputs[1].default_value = (0.5, 0.5, 0)
    nt.links.new(frac.outputs[0], centered.inputs[0])
    length = nt.nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    nt.links.new(centered.outputs[0], length.inputs[0])
    radius = _math(nt, "MULTIPLY", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 0.75, light), 2.2, clamp=True), 0.62)
    dots = _math(nt, "LESS_THAN", length.outputs["Value"], radius)

    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(_screen(nt, -45), sep.inputs[0])
    width = _math(nt, "MULTIPLY", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 0.3, light), 3.0, clamp=True), 0.4)
    hatch = _math(nt, "LESS_THAN", _math(nt, "FRACT", sep.outputs[0], 0), width)

    result = _mix(nt, hatch, _mix(nt, dots, color, shade), INK)
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(result, emit.inputs["Color"])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    return m


def ink_lines(scene):
    """Freestyle brush: a slanted nib, tapered ends, two loose passes that overshoot a little."""
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    layer = scene.view_layers[0]
    layer.use_freestyle = True
    settings = layer.freestyle_settings
    settings.crease_angle = math.radians(135)
    lineset = settings.linesets[0] if settings.linesets else settings.linesets.new("ink")
    for attr in ("select_silhouette", "select_border", "select_crease", "select_contour", "select_external_contour"):
        setattr(lineset, attr, True)
    style = bpy.data.linestyles.new("ink")
    lineset.linestyle = style
    style.color = INK
    style.thickness = 4.0
    style.use_chaining = True
    style.chaining = "SKETCHY"
    style.rounds = 2
    style.geometry_modifiers.new("sample", "SAMPLING").sampling = 2.0
    wobble = style.geometry_modifiers.new("wobble", "PERLIN_NOISE_1D")
    wobble.frequency = 6.0
    wobble.amplitude = 1.5
    wobble.octaves = 2
    style.geometry_modifiers.new("overshoot", "BACKBONE_STRETCHER").backbone_length = 4.2
    nib = style.thickness_modifiers.new("nib", "CALLIGRAPHY")
    nib.orientation = 60
    nib.thickness_min = 1.5
    nib.thickness_max = 5.5
    taper = style.thickness_modifiers.new("taper", "ALONG_STROKE")
    taper.blend = "MULTIPLY"
    taper.mapping = "CURVE"
    curve = taper.curve.curves[0]
    curve.points[0].location = (0.0, 0.1)
    curve.points[1].location = (1.0, 0.1)
    curve.points.new(0.25, 1.0)
    curve.points.new(0.75, 1.0)
    taper.curve.update()


def dress(obj, material):
    obj.data.materials.append(material)
    return obj


def palette(c):
    mats = {key: comic_material(key, c[key]) for key in ("skin", "jacket", "accent", "trim", "stache", "shell")
            if key in c}
    mats.update({
        "white": flat_material("white", (1, 1, 1)), "iris": flat_material("iris", c.get("iris", INK)),
        "brow": flat_material("brow", INK), "line": flat_material("line", INK),
        "mouth": flat_material("mouth", hexc("6b0f2e")),
    })
    return mats


# ---------------------------------------------------------------- face helpers

def face_point(head, x, z, out=0.0):
    """Point on the front of an ellipsoid head of radii `head` at (x, z), pushed `out` along -Y."""
    rx, ry, rz = head
    k = max(1 - (x / rx) ** 2 - (z / rz) ** 2, 0.02)
    return Vector((x, -ry * math.sqrt(k) - out, z))


def ring(center, rx, rz, n=24):
    return [center + Vector((math.cos(a) * rx, 0, math.sin(a) * rz)) for a in (2 * math.pi * i / n for i in range(n + 1))]


def build_eyes(e, mats, root, head, eye_z=0.08, spacing=0.31, eye_r=0.13, count=2):
    sides = (0,) if count == 1 else (-1, 1)
    for side in sides:
        x = side * spacing
        base = face_point(head, x, eye_z, out=-0.04)
        tag = f"{side}"
        if e["eye"] == "arc":
            pts = [base + Vector(((i / 8 - 0.5) * eye_r * 1.7, -0.06, eye_r * 0.27 * math.sin(math.pi * i / 8)))
                   for i in range(9)]
            dress(mesh_obj(f"lid{tag}", tube_bm(pts, [0.022] * 9, 8), root), mats["line"])
            continue
        open_ = e["eye"]
        white = sphere_bm(eye_r, 24, 12, lambda v: Vector((v.x, v.y * 0.6, v.z * 1.15 * open_)))
        dress(mesh_obj(f"white{tag}", transform_bm(white, lambda v: v + base), root), mats["white"])
        lx, lz = e["look"]
        pupil_at = base + Vector((lx, -eye_r * 0.55, lz * open_))
        iris = sphere_bm(eye_r * 0.62, 16, 8, lambda v: Vector((v.x, v.y * 0.4, v.z * 1.1 * min(open_, 1.0))))
        dress(mesh_obj(f"iris{tag}", transform_bm(iris, lambda v: v + pupil_at), root), mats["iris"])
        glint = sphere_bm(eye_r * 0.18, 8, 4)
        dress(mesh_obj(f"glint{tag}", transform_bm(glint, lambda v: v + pupil_at + Vector((-0.03, -0.04, 0.04))),
                       root), mats["white"])


def build_brows(e, mats, root, head, brow_z=0.33, spacing=0.31, length=0.26):
    for side, (height, tilt) in zip((-1, 1), e["brow"]):
        pts = []
        for i in range(7):
            u = i / 6
            x = side * (spacing - length / 2 + length * u)
            inner = 1 - u
            z = brow_z + height + tilt * 0.35 * (inner - 0.5) + 0.03 * math.sin(math.pi * u)
            pts.append(face_point(head, x, z, out=0.02))
        dress(mesh_obj(f"brow{side}", tube_bm(pts, [0.032] * 7, 8), root), mats["brow"])


def build_mouth(e, mats, root, head, mouth_z=-0.42, wide=1.0):
    smile, open_, width = e["mouth"]
    w = 0.2 * width * wide
    if open_ > 0:
        cavity = sphere_bm(1.0, 24, 12, lambda v: Vector((v.x * w * 0.9, v.y * 0.05,
                                                          v.z * 0.16 * open_ if v.z < 0 else v.z * 0.03)))
        at = face_point(head, 0, mouth_z - 0.04 * open_, out=-0.02)
        dress(mesh_obj("cavity", transform_bm(cavity, lambda v: v + at), root), mats["mouth"])
    pts = []
    for i in range(9):
        u = (i / 8) * 2 - 1
        z = mouth_z + smile * 0.07 * (u * u - 0.5)
        pts.append(face_point(head, u * w, z, out=0.015))
    dress(mesh_obj("lips", tube_bm(pts, [0.02] * 9, 8), root), mats["line"])


def egg_head(head, mats, root, taper_top=0.0, jowl=0.0):
    """An ellipsoid head that can narrow toward the top (gourd) or widen toward the chin (jowls)."""
    def shape(v):
        widen = (1 - taper_top * max(v.z, 0)) * (1 + jowl * max(-v.z, 0))
        return Vector((v.x * head[0] * widen, v.y * head[1], v.z * head[2]))
    return dress(mesh_obj("head", sphere_bm(1.0, 48, 24, shape), root), mats["skin"])


def bust(mats, root, top=-0.8):
    body = lathe_bm([(top, 0.5), (top - 0.2, 0.75), (top - 0.55, 1.0), (top - 0.9, 1.1), (-2.3, 1.15)], axis="z",
                    squash=(1.3, 0.62))
    dress(mesh_obj("bust", body, root), mats["jacket"])
    collar = lathe_bm([(top + 0.08, 0.5), (top - 0.02, 0.68), (top - 0.12, 0.72)], axis="z", squash=(1.12, 0.9))
    dress(mesh_obj("collar", collar, root), mats["accent"])


# ---------------------------------------------------------------- characters

def odessa(c, e):
    head = c["head"]
    mats = palette(c)
    root = empty("portrait")
    egg_head(head, mats, root, jowl=0.15)
    for side in (-1, 1):
        pts = []
        for i in range(12):
            a = i / 11 * math.pi * 1.1
            pts.append(Vector((side * (0.3 + 0.45 * math.sin(a) * i / 11), 0.1, 0.75 + 0.75 * math.sin(a * 0.9))))
        dress(mesh_obj(f"antenna{side}", tube_bm(pts, [0.1 - 0.04 * i / 11 for i in range(12)], 8), root), mats["skin"])
        dress(mesh_obj(f"pom{side}", transform_bm(sphere_bm(0.15, 16, 8), lambda v, p=pts[-1]: v + p), root),
              mats["accent"])
        frill = sphere_bm(0.3, 16, 8, lambda v: Vector((v.x * 0.35, v.y * 0.5, v.z)))
        dress(mesh_obj(f"frill{side}", transform_bm(frill, lambda v, s=side: Vector((v.x + s * 1.02, v.y + 0.1,
                                                                                   v.z + 0.05 + s * v.x * 0.8))),
                       root), mats["accent"])
    build_eyes(e, mats, root, head, eye_r=0.16, spacing=0.34)
    # The third eye only opens when she's surprised.
    third_open = 0.9 if e["eye"] != "arc" and e["eye"] > 1 else 0.25
    third = sphere_bm(0.08, 16, 8, lambda v: Vector((v.x, v.y * 0.5, v.z * third_open)))
    dress(mesh_obj("third", transform_bm(third, lambda v: v + face_point(head, 0, 0.5, out=-0.02)), root), mats["iris"])
    build_brows(e, mats, root, head, spacing=0.34)
    build_mouth(e, mats, root, head, mouth_z=-0.36)
    for side in (-1, 1):
        rim = ring(face_point(head, side * 0.34, 0.08, out=0.12), 0.22, 0.2)
        dress(mesh_obj(f"rim{side}", tube_bm(rim, [0.026] * len(rim), 8, cap=False), root), mats["accent"])
    bridge = [face_point(head, -0.13, 0.1, out=0.12), face_point(head, 0, 0.14, out=0.14),
              face_point(head, 0.13, 0.1, out=0.12)]
    dress(mesh_obj("bridge", tube_bm(bridge, [0.02] * 3, 6), root), mats["accent"])
    bust(mats, root)


def ilse(c, e):
    head = c["head"]
    mats = palette(c)
    root = empty("portrait")
    egg_head(head, mats, root)
    # Three feathery gill fronds a side, fanned back like a swept wing.
    for side in (-1, 1):
        for k, (lift, reach, rise) in enumerate(((0.4, 0.38, 0.45), (0.12, 0.45, 0.25), (-0.16, 0.38, 0.08))):
            start = Vector((side * head[0] * 0.88, 0.15, lift))
            pts = [start + Vector((side * reach * u, 0.2 * u, rise * u + 0.08 * math.sin(math.pi * u))) for u in
                   (i / 7 for i in range(8))]
            dress(mesh_obj(f"gill{side}{k}", tube_bm(pts, [0.07 - 0.04 * i / 7 for i in range(8)], 8), root),
                  mats["accent"])
            for j in range(2, 8, 2):
                tuft = sphere_bm(0.06, 10, 5, lambda v: Vector((v.x, v.y, v.z * 1.6)))
                dress(mesh_obj(f"tuft{side}{k}{j}", transform_bm(tuft, lambda v, p=pts[j]: v + p + Vector((0, 0, 0.07))),
                               root), mats["accent"])
    build_eyes(e, mats, root, head, eye_r=0.13, spacing=0.42, eye_z=0.12)
    build_brows(e, mats, root, head, spacing=0.42, brow_z=0.34, length=0.22)
    build_mouth(e, mats, root, head, mouth_z=-0.3, wide=1.6)
    strap = [Vector((math.cos(a) * head[0] * 1.06, math.sin(a) * head[1] * 1.06, 0.55))
             for a in (math.pi * i / 16 for i in range(17))]
    dress(mesh_obj("strap", tube_bm(strap, [0.06] * 17, 8), root), mats["jacket"])
    for side in (-1, 1):
        lens = lathe_bm([(0.12, 0.0), (0.12, 0.17), (-0.04, 0.19)], axis="y")
        at = face_point(head, side * 0.3, 0.55, out=0.06)
        dress(mesh_obj(f"goggle{side}", transform_bm(lens, lambda v, a=at: Vector((v.x, -v.y, v.z)) + a), root),
              mats["jacket"])
    bust(mats, root, top=-0.72)
    stripe = lathe_bm([(-1.05, 0.83), (-1.18, 0.92)], axis="z", squash=(1.32, 0.64))
    dress(mesh_obj("stripe", stripe, root), mats["trim"])


def crake(c, e):
    head = c["head"]
    mats = palette(c)
    root = empty("portrait")
    egg_head(head, mats, root, taper_top=0.25)
    crest = [Vector((0, 0.1 + 0.35 * i / 8, 1.15 + 0.25 * math.sin(math.pi * i / 8) - 0.1 * i / 8)) for i in range(9)]
    dress(mesh_obj("crest", tube_bm(crest, [0.1 * math.sin(math.pi * (i + 1) / 10) for i in range(9)], 10), root),
          mats["accent"])
    build_eyes(e, mats, root, head, eye_z=0.25, eye_r=0.24, count=1)
    build_brows(e, mats, root, head, brow_z=0.58, spacing=0.13, length=0.2)
    center = face_point(head, 0, 0.25, out=0.12)
    monocle = ring(center, 0.32, 0.32)
    dress(mesh_obj("monocle", tube_bm(monocle, [0.035] * len(monocle), 8, cap=False), root), mats["accent"])
    chain = [center + Vector((0.32, 0.02, 0)), center + Vector((0.5, 0.1, -0.6)), center + Vector((0.55, 0.25, -1.3))]
    dress(mesh_obj("chain", tube_bm(chain, [0.015] * 3, 6), root), mats["accent"])
    # A handlebar of two tentacles: out along the lip, then curled up and in at the tips.
    lip = face_point(head, 0, -0.22, out=0.08)
    for side in (-1, 1):
        pts = []
        for i in range(18):
            u = i / 17
            if u < 0.6:
                t = u / 0.6
                pts.append(lip + Vector((side * (0.04 + 0.5 * t), -0.04 * t, -0.08 * math.sin(math.pi * t))))
            else:
                a = (u - 0.6) / 0.4 * math.pi * 1.4
                pts.append(lip + Vector((side * (0.54 + 0.12 * math.sin(a)), -0.04, 0.12 - 0.12 * math.cos(a))))
        radii = [0.085 - 0.06 * (i / 17) ** 1.2 for i in range(18)]
        dress(mesh_obj(f"stache{side}", tube_bm(pts, radii, 12), root), mats["stache"])
    build_mouth(e, mats, root, head, mouth_z=-0.48)
    bust(mats, root)
    for side in (-1, 1):
        wing = sphere_bm(0.16, 16, 8, lambda v: Vector((v.x * 1.1, v.y * 0.5, v.z * (0.6 + 0.4 * abs(v.x) / 0.16))))
        dress(mesh_obj(f"bow{side}", transform_bm(wing, lambda v, s=side: v + Vector((s * 0.17, -0.62, -0.86))), root),
              mats["accent"])
    knot = sphere_bm(0.07, 12, 6)
    dress(mesh_obj("knot", transform_bm(knot, lambda v: v + Vector((0, -0.66, -0.86))), root), mats["accent"])


def robot(c, e):
    mats = palette(c)
    mats["glow"] = flat_material("glow", c["glow"])
    mats["screen"] = flat_material("screen", c["screen"])
    mats["vest"] = mats["jacket"]
    root = empty("portrait")
    dress(mesh_obj("head", box_bm((1.9, 1.5, 1.6), bevel=0.35, segments=4), root), mats["shell"])
    dress(mesh_obj("screen", transform_bm(box_bm((1.5, 0.1, 1.05), bevel=0.2, segments=3),
                                          lambda v: v + Vector((0, -0.72, -0.02))), root), mats["screen"])
    for side in (-1, 1):
        bolt = lathe_bm([(0.1, 0.3), (-0.1, 0.3)], axis="y")
        dress(mesh_obj(f"bolt{side}", transform_bm(bolt, lambda v, s=side: Vector((v.y + s * 1.0, v.x, v.z))), root),
              mats["accent"])
    antenna = [(0.3, 0.1, 0.8 + 0.08 * i) for i in range(6)]
    dress(mesh_obj("antenna", tube_bm(antenna, [0.05] * 6, 8), root), mats["accent"])
    dress(mesh_obj("bulb", transform_bm(sphere_bm(0.12, 12, 6), lambda v: v + Vector((0.3, 0.1, 1.3))), root),
          mats["glow"])
    neck = lathe_bm([(-0.75, 0.25), (-1.2, 0.28)], axis="z")
    dress(mesh_obj("neck", neck, root), mats["accent"])
    vest = lathe_bm([(-1.0, 0.4), (-1.15, 0.7), (-1.4, 1.05), (-1.8, 1.15), (-2.3, 1.15)], axis="z", squash=(1.3, 0.65))
    dress(mesh_obj("vest", vest, root), mats["vest"])

    # Eyes and brows are glowing shapes on the face screen.
    z0, y = 0.02, -0.79
    for side, (height, tilt) in zip((-1, 1), e["brow"]):
        x = side * 0.38
        if e["eye"] == "arc":
            pts = [Vector((x + (i / 8 - 0.5) * 0.3, y, z0 + 0.06 * math.sin(math.pi * i / 8))) for i in range(9)]
            dress(mesh_obj(f"eye{side}", tube_bm(pts, [0.04] * 9, 8), root), mats["glow"])
        else:
            open_ = e["eye"]
            lx, lz = e["look"]
            eye = sphere_bm(0.15, 16, 8, lambda v: Vector((v.x, v.y * 0.2, v.z * 1.2 * open_)))
            dress(mesh_obj(f"eye{side}", transform_bm(eye, lambda v, p=(x + lx, y, z0 + lz): v + Vector(p)), root),
                  mats["glow"])
        pts = []
        for i in range(5):
            u = i / 4
            inner = 1 - u if side > 0 else u
            pts.append(Vector((x + (u - 0.5) * 0.3, y, z0 + 0.3 + height + tilt * 0.3 * (inner - 0.5))))
        dress(mesh_obj(f"brow{side}", tube_bm(pts, [0.03] * 5, 6), root), mats["glow"])
    smile, open_, width = e["mouth"]
    w = 0.22 * width
    pts = [Vector(((i / 8 * 2 - 1) * w, y, -0.28 + smile * 0.08 * (((i / 8 * 2 - 1) ** 2) - 0.5) - 0.05 * open_))
           for i in range(9)]
    dress(mesh_obj("mouth", tube_bm(pts, [0.03 + 0.05 * open_] * 9, 8), root), mats["glow"])


def smooth(d, width=0.08):
    """0 below -width, 1 above +width, smooth in between: soft hairlines without jagged steps."""
    t = min(max((d + width) / (2 * width), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def alien(c, e):
    """A data-driven alien bust: head shape, eyes and a list of `extras` (ears, horns, hats, scarves,
    leaves, spectacles, freckles), so new cast members are mostly a dictionary."""
    head = c["head"]
    mats = palette(c)
    root = empty("portrait")
    egg_head(head, mats, root, taper_top=c.get("taper", 0.0), jowl=c.get("jowl", 0.0))
    ex = c.get("extras", [])
    eyes = c["eyes"]
    build_eyes(e, mats, root, head, eye_z=eyes["z"], spacing=eyes["spacing"], eye_r=eyes["r"], count=eyes["count"])
    build_brows(e, mats, root, head, brow_z=eyes["z"] + eyes["r"] + 0.14, spacing=eyes["spacing"])
    build_mouth(e, mats, root, head, mouth_z=c.get("mouth_z", -0.42))
    top = head[2]
    if "floppy_ears" in ex:
        for side in (-1, 1):
            pts = [Vector((side * (head[0] * 0.72 + 0.5 * u), 0.08, top * 0.62 + 0.2 * u - 0.75 * u * u)) for u in
                   (i / 9 for i in range(10))]
            dress(mesh_obj(f"ear{side}", tube_bm(pts, [0.15 * (1 - 0.25 * i / 9) for i in range(10)], 10), root), mats["skin"])
            tip = sphere_bm(0.11, 12, 6)
            dress(mesh_obj(f"eartip{side}", transform_bm(tip, lambda v, p=pts[-1]: v + p), root), mats["trim"])
    if "cow_ears" in ex:
        for side in (-1, 1):
            ear = sphere_bm(0.2, 16, 8, lambda v: Vector((v.x * 1.6, v.y * 0.35, v.z * 0.7)))
            dress(mesh_obj(f"cowear{side}", transform_bm(ear, lambda v, s=side: v + Vector((s * head[0] * 1.08, 0.05, top * 0.3))), root),
                  mats["skin"])
    if "horns" in ex:
        for side in (-1, 1):
            pts = [Vector((side * (head[0] * 0.45 + 0.25 * u), 0.05, top * 0.78 + 0.35 * u - 0.12 * u * u)) for u in
                   (i / 7 for i in range(8))]
            dress(mesh_obj(f"horn{side}", tube_bm(pts, [0.1 * (1 - i / 8) + 0.015 for i in range(8)], 10), root), mats["trim"])
    if "chef_hat" in ex:
        band = lathe_bm([(top * 0.88, head[0] * 0.62), (top * 1.12, head[0] * 0.62)], axis="z")
        dress(mesh_obj("hatband", band, root), mats["jacket"])
        puff = sphere_bm(0.55, 24, 12, lambda v: Vector((v.x * 1.1, v.y * 1.0, v.z * 0.75)))
        dress(mesh_obj("hatpuff", transform_bm(puff, lambda v: v + Vector((0, 0, top * 1.12 + 0.3))), root), mats["jacket"])
    if "headscarf" in ex:
        def scarf(v):
            cover = smooth(v.z - 0.35)
            return Vector((v.x * head[0], v.y * head[1], v.z * top)) * (1.0 + 0.07 * cover)
        cap = sphere_bm(1.0, 48, 24, lambda v: scarf(v) if v.z > 0.25 else scarf(Vector((v.x, v.y, 0.25))) * 0.98)
        dress(mesh_obj("headscarf", cap, root), mats["accent"])
        knot = sphere_bm(0.14, 12, 6)
        dress(mesh_obj("knot", transform_bm(knot, lambda v: v + Vector((head[0] * 0.55, 0.25, top * 0.7))), root), mats["accent"])
    if "leaves" in ex:
        for i, (x, tilt, size) in enumerate(((-0.3, -0.7, 0.6), (0.05, 0.1, 0.8), (0.35, 0.8, 0.55))):
            stem = [Vector((x * 0.6, 0.05, top * 0.95)), Vector((x, 0.05, top * 0.95 + size * 0.6))]
            dress(mesh_obj(f"stem{i}", tube_bm(stem, [0.03, 0.025], 6), root), mats["skin"])
            leaf = sphere_bm(size * 0.5, 16, 8, lambda v: Vector((v.x * 0.55, v.y * 0.12, v.z)))
            def place(v, x=x, tilt=tilt, size=size):
                c_, s_ = math.cos(tilt), math.sin(tilt)
                return Vector((v.x * c_ + v.z * s_ + x + s_ * size * 0.5, v.y + 0.05, -v.x * s_ + v.z * c_ + top * 0.95 + size * 0.6 + c_ * size * 0.45))
            dress(mesh_obj(f"leaf{i}", transform_bm(leaf, place), root), mats["skin"])
        bud = sphere_bm(0.1, 12, 6)
        dress(mesh_obj("bud", transform_bm(bud, lambda v: v + Vector((0.05, 0.05, top * 0.95 + 0.85))), root), mats["trim"])
    if "spectacles" in ex:
        for side in (-1, 1):
            rim = ring(face_point(head, side * eyes["spacing"], eyes["z"], out=0.1), eyes["r"] + 0.06, eyes["r"] + 0.05)
            dress(mesh_obj(f"rim{side}", tube_bm(rim, [0.022] * len(rim), 8, cap=False), root), mats["accent"])
        bridge = [face_point(head, -0.09, eyes["z"] + 0.02, out=0.11), face_point(head, 0.09, eyes["z"] + 0.02, out=0.11)]
        dress(mesh_obj("bridge", tube_bm(bridge, [0.018] * 2, 6), root), mats["accent"])
    if "freckles" in ex:
        for side in (-1, 1):
            for k, (dx, dz) in enumerate(((0.0, 0.0), (0.08, 0.04), (0.04, -0.06), (0.12, -0.02))):
                dot = sphere_bm(0.022, 8, 4, lambda v: Vector((v.x, v.y * 0.3, v.z)))
                at = face_point(head, side * (0.32 + dx), -0.2 + dz, out=0.0)
                dress(mesh_obj(f"freckle{side}{k}", transform_bm(dot, lambda v, a=at: v + a), root), mats["trim"])
    if "goggles" in ex:
        strap = [Vector((math.cos(a) * head[0] * 1.06, math.sin(a) * head[1] * 1.06, top * 0.62))
                 for a in (math.pi * i / 16 for i in range(17))]
        dress(mesh_obj("strap", tube_bm(strap, [0.06] * 17, 8), root), mats["jacket"])
        for side in (-1, 1):
            lens = lathe_bm([(0.12, 0.0), (0.12, 0.17), (-0.04, 0.19)], axis="y")
            at = face_point(head, side * 0.3, top * 0.62, out=0.06)
            dress(mesh_obj(f"goggle{side}", transform_bm(lens, lambda v, a=at: Vector((v.x, -v.y, v.z)) + a), root),
                  mats["accent"])
    if "beard" in ex:
        def beard(v):
            cover = smooth(-0.55 - v.z, 0.12) * smooth(-v.y - 0.1, 0.15)
            return Vector((v.x * head[0], v.y * head[1], v.z * top * (1.0 + 0.25 * cover))) * (1.0 + 0.1 * cover)
        shell = sphere_bm(1.0, 48, 24, lambda v: beard(v) if v.z < -0.5 and v.y < 0.2 else beard(Vector((v.x, v.y, -0.5))) * 0.97)
        dress(mesh_obj("beard", shell, root), mats["trim"])
    if "captain_cap" in ex:
        crown = lathe_bm([(top * 0.85, head[0] * 0.75), (top * 1.15, head[0] * 0.85), (top * 1.25, head[0] * 0.8)], axis="z")
        dress(mesh_obj("cap", crown, root), mats["jacket"])
        peak = sphere_bm(0.4, 16, 8, lambda v: Vector((v.x * 1.1, v.y * 0.9 - 0.35, v.z * 0.12)))
        dress(mesh_obj("peak", transform_bm(peak, lambda v: v + Vector((0, -0.25, top * 0.9))), root), mats["line"])
        badge = sphere_bm(0.08, 10, 5, lambda v: Vector((v.x, v.y * 0.3, v.z)))
        dress(mesh_obj("badge", transform_bm(badge, lambda v: v + face_point(head, 0, top * 0.9, out=0.2)), root), mats["accent"])
    if "bun" in ex:
        bun = sphere_bm(0.32, 16, 8)
        dress(mesh_obj("bun", transform_bm(bun, lambda v: v + Vector((0, 0.35, top * 0.95))), root), mats["trim"])
        cap = sphere_bm(1.0, 48, 24, lambda v: Vector((v.x * head[0], v.y * head[1], v.z * top)) * (1.06 if v.z > 0.45 else 0.98))
        dress(mesh_obj("hair", cap, root), mats["trim"])
    if "antennae" in ex:
        for side in (-1, 1):
            pts = [Vector((side * (0.25 + 0.3 * u), 0.1, top * 0.85 + 0.6 * u - 0.15 * u * u)) for u in (i / 9 for i in range(10))]
            dress(mesh_obj(f"antenna{side}", tube_bm(pts, [0.06] * 10, 8), root), mats["skin"])
            dress(mesh_obj(f"antennatip{side}", transform_bm(sphere_bm(0.11, 12, 6), lambda v, p=pts[-1]: v + p), root),
                  mats["accent"])
    bust(mats, root)
    if "scarf" in ex:
        loop = [Vector((math.cos(a) * 0.62, math.sin(a) * 0.5, -0.8 + 0.05 * math.sin(a))) for a in (2 * math.pi * i / 32 for i in range(33))]
        dress(mesh_obj("scarf", tube_bm(loop, [0.11] * 33, 10, cap=False), root), mats["accent"])
        tail = [Vector((0.3, -0.5, -0.85)), Vector((0.42, -0.55, -1.2)), Vector((0.38, -0.58, -1.55))]
        dress(mesh_obj("scarftail", tube_bm(tail, [0.1, 0.1, 0.09], 10), root), mats["accent"])


def cat(c, e):
    """A tuxedo cat: black with a white blaze, muzzle and chest, a green collar with a gold tag,
    slit-pupil eyes, and ears that tell you the mood (up when surprised, flat when grumpy, drooping
    when sad). The fur is a deep charcoal so the ink still reads against it."""
    head = c["head"]
    mats = palette(c)
    root = empty("portrait")
    egg_head(head, mats, root, jowl=0.18)
    blaze = sphere_bm(0.2, 16, 8, lambda v: Vector((v.x * 0.55, v.y * 0.25, v.z * 1.4)))
    dress(mesh_obj("blaze", transform_bm(blaze, lambda v: v + face_point(head, 0, 0.0, out=-0.03)), root), mats["accent"])
    tilt = {"grumpy": 1.15, "sad": 0.9, "surprised": -0.15}.get(_expression_name(e), 0.2)
    for side in (-1, 1):
        ear = lathe_bm([(0.0, 0.34), (0.55, 0.02)], axis="z", squash=(1.0, 0.45))
        inner = lathe_bm([(0.02, 0.22), (0.4, 0.02)], axis="z", squash=(1.0, 0.3))
        def place(v, s=side):
            v = Vector((v.x, v.y, v.z))
            a = s * tilt
            x, z = v.x * math.cos(a) - v.z * math.sin(a), v.x * math.sin(a) + v.z * math.cos(a)
            return Vector((x + s * head[0] * 0.55, v.y + 0.05, z + head[2] * 0.62))
        dress(mesh_obj(f"ear{side}", transform_bm(ear, place), root), mats["skin"])
        dress(mesh_obj(f"earin{side}", transform_bm(inner, lambda v, f=place: f(v) + Vector((0, -0.08, 0))), root),
              mats["trim"])
    for side in (-1, 1):
        cheek = sphere_bm(0.24, 16, 8, lambda v: Vector((v.x, v.y * 0.5, v.z * 0.75)))
        dress(mesh_obj(f"muzzle{side}", transform_bm(cheek, lambda v, s=side: v + face_point(head, s * 0.16, -0.3, out=0.02)),
                       root), mats["accent"])
        for k in range(3):
            start = face_point(head, side * 0.3, -0.27 + k * 0.07, out=0.06)
            whisker = [start, start + Vector((side * 0.45, -0.05, 0.06 - k * 0.07)),
                       start + Vector((side * 0.85, 0.0, 0.1 - k * 0.12))]
            dress(mesh_obj(f"whisker{side}{k}", tube_bm(whisker, [0.012, 0.01, 0.006], 5), root), mats["line"])
    nose = sphere_bm(0.07, 12, 6, lambda v: Vector((v.x * 1.3, v.y * 0.6, v.z * 0.8)))
    dress(mesh_obj("nose", transform_bm(nose, lambda v: v + face_point(head, 0, -0.2, out=0.12)), root), mats["trim"])
    for side in (-1, 1):
        x = side * 0.36
        base = face_point(head, x, 0.12, out=-0.02)
        if e["eye"] == "arc":
            pts = [base + Vector(((i / 8 - 0.5) * 0.3, -0.06, 0.05 * math.sin(math.pi * i / 8))) for i in range(9)]
            dress(mesh_obj(f"lid{side}", tube_bm(pts, [0.024] * 9, 8), root), mats["line"])
            continue
        open_ = e["eye"]
        iris = sphere_bm(0.16, 24, 12, lambda v: Vector((v.x * 1.1, v.y * 0.5, v.z * 0.95 * open_)))
        dress(mesh_obj(f"iris{side}", transform_bm(iris, lambda v: v + base), root), mats["iris"])
        lx, lz = e["look"]
        slit = sphere_bm(0.15, 12, 8, lambda v: Vector((v.x * 0.22, v.y * 0.3, v.z * 0.85 * min(open_, 1.0))))
        dress(mesh_obj(f"slit{side}", transform_bm(slit, lambda v: v + base + Vector((lx, -0.09, lz))), root), mats["line"])
        glint = sphere_bm(0.035, 8, 4)
        dress(mesh_obj(f"glint{side}", transform_bm(glint, lambda v: v + base + Vector((-0.05, -0.11, 0.06))), root),
              mats["white"])
    if _expression_name(e) in ("grumpy", "sad", "thoughtful"):
        build_brows(e, mats, root, head, brow_z=0.32, spacing=0.36, length=0.18)
    smile, open_, width = e["mouth"]
    for side in (-1, 1):
        pts = [face_point(head, side * (0.02 + 0.12 * u), -0.33 - 0.05 * math.sin(math.pi * u) + smile * 0.03 * u, out=0.1)
               for u in (i / 6 for i in range(7))]
        dress(mesh_obj(f"mouth{side}", tube_bm(pts, [0.016] * 7, 6), root), mats["line"])
    if open_ > 0.3:
        gape = sphere_bm(0.08, 12, 6, lambda v: Vector((v.x * 1.1, v.y * 0.3, v.z * open_ * 1.4)))
        dress(mesh_obj("gape", transform_bm(gape, lambda v: v + face_point(head, 0, -0.45, out=0.06)), root), mats["mouth"])
    body = lathe_bm([(-0.7, 0.55), (-0.95, 0.85), (-1.3, 1.05), (-1.7, 1.12), (-2.3, 1.15)], axis="z", squash=(1.25, 0.65))
    dress(mesh_obj("body", body, root), mats["skin"])
    shirt = sphere_bm(0.5, 20, 10, lambda v: Vector((v.x * 0.9, v.y * 0.3, v.z * 1.15)))
    dress(mesh_obj("shirt", transform_bm(shirt, lambda v: v + Vector((0, -0.68, -1.55))), root), mats["accent"])
    collar = [Vector((math.cos(a) * 0.7, math.sin(a) * 0.55 - 0.06, -0.98 + 0.05 * math.sin(a)))
              for a in (2 * math.pi * i / 32 for i in range(33))]
    dress(mesh_obj("collar", tube_bm(collar, [0.085] * 33, 10, cap=False), root), mats["jacket"])
    loop = [Vector((0, -0.66 - 0.08 * i, -1.03 - 0.05 * i)) for i in range(3)]
    dress(mesh_obj("loop", tube_bm(loop, [0.025] * 3, 6), root), mats["stache"])
    tag = lathe_bm([(0.03, 0.14), (-0.03, 0.14)], axis="y")
    dress(mesh_obj("tag", transform_bm(tag, lambda v: v + Vector((0, -0.9, -1.24))), root), mats["stache"])


def _expression_name(e):
    return next(name for name, spec in EXPRESSIONS.items() if spec is e)


BUILDERS = {"odessa": odessa, "ilse": ilse, "crake": crake, "robot": robot, "cat": cat, "alien": alien}


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
    cam.data.ortho_scale = 4.3
    target = Vector((0, 0, -0.35))
    cam.location = target + Vector((0, -6.0, 0.35))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    ink_lines(scene)


def render(name, expression, character):
    clear_scene()
    for style in list(bpy.data.linestyles):
        bpy.data.linestyles.remove(style)
    scene = bpy.context.scene
    BUILDERS[character["build"]](character, EXPRESSIONS[expression])
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
