"""Ship parts kit: hulls with sockets and repair spots, plus swappable parts.

Mesh names end in a material role so Godot can recolor any part without knowing its shape:
  _paint (owner's main color), _trim (accent color), _glass, _metal, _glow, _dark.
Hulls are empties named hull_<id>. Their children include socket_<slot> empties, where parts snap on,
and spot_<n> empties, which mark places on the skin where faults can appear.
Parts are empties named part_<id>, modeled in ship space (nose +Y, up +Z) around the socket origin.
Left fins extend toward -X; Godot mirrors them for the right side.
"""

import math

from mathutils import Matrix, Vector

from kit_common import (box_bm, empty, lathe_bm, mesh_obj, slab_bm, sphere_bm, transform_bm,
                        tube_bm)


def egg(length, radius, bluntness=0.8, steps=24, nose_point=0.0):
    """Profile for a rounded body from tail (-length/2) to nose (+length/2)."""
    pts = []
    for i in range(steps + 1):
        u = -1 + 2 * i / steps
        r = radius * max(1 - u * u, 0) ** (bluntness / 2)
        if u > 0:
            r *= 1 - nose_point * u * u
        pts.append((u * length / 2, max(r, 0.001)))
    return pts


def profile_radius(profile, t):
    for (t0, r0), (t1, r1) in zip(profile, profile[1:]):
        if t0 <= t <= t1:
            return r0 + (r1 - r0) * (t - t0) / (t1 - t0)
    return profile[-1][1]


def on_surface(profile, squash, lift, t, angle_deg, out=0.02):
    """A point on a lathe body's skin at length `t` and angle around it (90 = top, -90 = belly)."""
    a = math.radians(angle_deg)
    r = profile_radius(profile, t) + out
    return (math.cos(a) * r * squash[0], t, math.sin(a) * r * squash[1] + (lift(t) if lift else 0))


def sockets(hull, spec):
    for slot, (loc, scale) in spec.items():
        empty(f"socket_{slot}", hull, loc, scale)


def spots(hull, points):
    for i, p in enumerate(points, 1):
        empty(f"spot_{i}", hull, p)


def band(name, profile, squash, lift, t0, t1, parent, grow=0.04):
    sub = [(t, r + grow) for t, r in profile if t0 <= t <= t1]
    return mesh_obj(name, lathe_bm(sub, squash=squash, lift=lift), parent)


# ---------------------------------------------------------------- hulls

def hull_moth():
    """Odessa's Pocket Moth: a stubby, friendly hauler with a cargo belly and portholes."""
    h = empty("hull_moth")
    prof = egg(4.2, 1.15, bluntness=0.7)
    sq = (1.15, 0.9)

    def lift(t):
        return 0.08 * t

    mesh_obj("body_paint", lathe_bm(prof, squash=sq, lift=lift), h)
    band("band_trim", prof, sq, lift, -0.35, 0.35, h)
    belly = box_bm((1.5, 2.4, 0.5), bevel=0.18)
    mesh_obj("belly_dark", transform_bm(belly, lambda v: v + Vector((0, -0.2, -0.85))), h)
    for side in (-1, 1):
        for i, t in enumerate((-0.9, 0.0, 0.9)):
            p = Vector(on_surface(prof, sq, lift, t, 90 - side * 70, out=-0.03))
            port = sphere_bm(0.17, 16, 8, lambda v: Vector((v.x * 0.5, v.y, v.z)))
            name = f"port{'lr'[side > 0]}{i}"
            mesh_obj(f"{name}_glass", transform_bm(port, lambda v, p=p, s=side: Vector((v.x * s, v.y, v.z)) + p), h)
    sockets(h, {
        "engine": ((0, -2.0, 0.0), 1.1),
        "fin_l": ((-1.15, -0.5, -0.1), 1.0),
        "fin_r": ((1.15, -0.5, -0.1), 1.0),
        "cockpit": ((0, 0.9, 0.78), 1.0),
        "lights": ((0, 2.08, 0.1), 1.0),
        "top": ((0, -0.9, 0.92), 0.9),
    })
    spots(h, [on_surface(prof, sq, lift, t, a) for t, a in
              ((1.2, 20), (0.2, -20), (-1.0, 40), (-0.4, 140), (0.6, 160), (-1.5, 90))])
    return h


def hull_kettle():
    """The player's Kettle: a round teakettle of a ship with a carry handle and a lid knob."""
    h = empty("hull_kettle")
    prof = egg(3.4, 1.3, bluntness=0.55)
    sq = (1.0, 0.95)
    mesh_obj("body_paint", lathe_bm(prof, squash=sq), h)
    band("band_trim", prof, sq, None, -0.25, 0.25, h)
    handle = []
    for i in range(17):
        y = -0.9 + 1.4 * i / 16
        skin = on_surface(prof, sq, None, y, 90, out=-0.1)[2]
        handle.append((0, y, skin + 0.6 * math.sin(math.pi * i / 16)))
    mesh_obj("handle_metal", tube_bm(handle, [0.09] * 17, 12), h)
    knob = sphere_bm(0.18, 16, 8, lambda v: Vector((v.x, v.y, v.z * 0.7)))
    mesh_obj("knob_trim", transform_bm(knob, lambda v: v + Vector((0, -0.2, 1.3))), h)
    spout = [(0, 1.1 + 0.14 * i, -0.45 + 0.012 * i * i) for i in range(10)]
    mesh_obj("spout_paint", tube_bm(spout, [0.3 - 0.016 * i for i in range(10)], 16), h)
    mesh_obj("spoutrim_trim", lathe_bm([(0.0, 0.17), (-0.06, 0.17)], axis="y"), h).location = spout[-1]
    sockets(h, {
        "engine": ((0, -1.7, 0.0), 1.0),
        "fin_l": ((-1.25, -0.4, -0.15), 0.9),
        "fin_r": ((1.25, -0.4, -0.15), 0.9),
        "cockpit": ((0, 1.0, 0.82), 0.85),
        "lights": (on_surface(prof, sq, None, 1.3, 55, out=0.05), 0.8),
        "top": ((0, -1.25, 0.95), 0.8),
    })
    spots(h, [on_surface(prof, sq, None, t, a) for t, a in
              ((1.0, 30), (0.0, -30), (-0.9, 150), (0.4, 200), (-1.2, 60), (0.8, 120))])
    return h


def hull_heron():
    """Ilse's Heron: a long, slender racer with a needle nose and a spine stripe."""
    h = empty("hull_heron")
    prof = egg(5.2, 0.62, bluntness=0.45, nose_point=0.35)
    sq = (1.35, 0.7)

    def lift(t):
        return 0.04 * t + (0.08 * (t - 1.5) if t > 1.5 else 0)

    mesh_obj("body_paint", lathe_bm(prof, squash=sq, lift=lift), h)
    spine = [on_surface(prof, sq, lift, -2.3 + 4.4 * i / 20, 90, out=0.0) for i in range(21)]
    mesh_obj("spine_trim", tube_bm(spine, [0.06] * 21, 10), h)
    keel = box_bm((0.25, 2.6, 0.18), bevel=0.06)
    mesh_obj("keel_dark", transform_bm(keel, lambda v: v + Vector((0, -0.4, -0.45))), h)
    sockets(h, {
        "engine": ((0, -2.55, 0.0), 0.9),
        "fin_l": ((-0.8, -0.9, -0.05), 1.05),
        "fin_r": ((0.8, -0.9, -0.05), 1.05),
        "cockpit": ((0, 0.3, 0.42), 0.8),
        "lights": ((0, 2.62, 0.2), 0.7),
        "top": ((0, -1.4, 0.45), 0.7),
    })
    spots(h, [on_surface(prof, sq, lift, t, a) for t, a in
              ((1.6, 40), (0.4, -40), (-1.4, 30), (-0.6, 150), (0.9, 160), (-2.0, 90))])
    return h


def hull_bucket():
    """Brindle's Bucket: a boxy salvage tug held together by mismatched patch panels."""
    h = empty("hull_bucket")
    mesh_obj("body_paint", box_bm((1.7, 3.4, 1.3), bevel=0.22), h)
    for i, (x, y, z, sx, sy) in enumerate(((0.86, 0.5, 0.1, 0.06, 0.9), (-0.86, -0.6, -0.15, 0.06, 0.7),
                                           (0.0, -0.9, 0.66, 0.8, 0.7))):
        size = (sx, sy, 0.5) if i < 2 else (sx, sy, 0.05)
        panel = box_bm(size, bevel=0.02)
        mesh_obj(f"patch{i}_trim", transform_bm(panel, lambda v, o=(x, y, z): v + Vector(o)), h)
    antenna = [(0.5, -1.2, 0.65 + 0.12 * i) for i in range(8)]
    mesh_obj("antenna_metal", tube_bm(antenna, [0.04] * 8, 8), h)
    tip = sphere_bm(0.08, 12, 6)
    mesh_obj("antennatip_glow", transform_bm(tip, lambda v: v + Vector((0.5, -1.2, 1.55))), h)
    sockets(h, {
        "engine": ((0, -1.72, 0.0), 1.05),
        "fin_l": ((-0.86, -0.6, -0.3), 0.95),
        "fin_r": ((0.86, -0.6, -0.3), 0.95),
        "cockpit": ((0, 0.9, 0.66), 0.95),
        "lights": ((0, 1.72, 0.15), 1.0),
        "top": ((-0.3, -0.2, 0.68), 0.8),
    })
    spots(h, [(0.88, 1.0, 0.3), (-0.88, 0.3, 0.2), (0.0, 1.0, 0.67), (0.88, -1.2, -0.3), (-0.5, -1.0, 0.67),
              (0.0, 1.72, -0.3)])
    return h


def disc_height(profile, x, y):
    """Height of the top skin of a disc lathed around Z, at (x, y)."""
    r = math.hypot(x, y)
    top = sorted(((rad, z) for z, rad in profile if z >= 0), key=lambda p: p[0])
    for (r0, z0), (r1, z1) in zip(top, top[1:]):
        if r0 <= r <= r1:
            return z0 + (z1 - z0) * (r - r0) / (r1 - r0)
    return top[0][1]


def hull_saucer():
    """A classic flying saucer: a wide disc with rim lights and a glowing ring underneath."""
    h = empty("hull_saucer")
    prof = [(-0.35, 0.3), (-0.3, 1.2), (-0.12, 1.9), (0.0, 2.05), (0.1, 1.9), (0.26, 1.2), (0.36, 0.6),
            (0.4, 0.001)]
    mesh_obj("body_paint", lathe_bm(prof, segments=48, axis="z"), h)
    mesh_obj("rim_trim", lathe_bm([(0.05, 2.1), (-0.05, 2.1)], segments=48, axis="z"), h)
    mesh_obj("beam_glow", lathe_bm([(-0.36, 0.75), (-0.4, 0.55)], segments=32, axis="z"), h)
    for i in range(10):
        a = 2 * math.pi * i / 10
        lamp = sphere_bm(0.08, 10, 5)
        mesh_obj(f"rimlight{i}_glow", transform_bm(lamp, lambda v, a=a: v + Vector((math.cos(a) * 2.13,
                                                                                     math.sin(a) * 2.13, 0))), h)
    sockets(h, {
        "engine": ((0, -2.0, 0.0), 0.9),
        "fin_l": ((-1.55, -1.1, 0.0), 0.7),
        "fin_r": ((1.55, -1.1, 0.0), 0.7),
        "cockpit": ((0, 0.25, 0.36), 1.0),
        "lights": ((0, 2.08, 0.0), 0.8),
        "top": ((0, -1.0, 0.28), 0.7),
    })
    spots(h, [(x, y, disc_height(prof, x, y) + 0.02) for x, y in
              ((1.2, 0.6), (-1.0, 1.0), (0.8, -1.2), (-1.4, -0.5), (1.6, 0.3), (-0.6, -1.5))])
    return h


def hull_manta():
    """A manta-ray yacht: a broad swept wing-body with curled head fins and a tail spike."""
    h = empty("hull_manta")

    def wing(v):
        x, y, z = v.x * 2.4, v.y * 2.0, v.z * 0.42
        y -= 0.55 * abs(v.x) ** 2
        return Vector((x, y, z * (1 - 0.65 * abs(v.x))))
    mesh_obj("body_paint", sphere_bm(1.0, 48, 24, wing), h)
    ridge = [(0, 1.4 - 0.2 * i, 0.38 + 0.06 * math.sin(math.pi * i / 14)) for i in range(15)]
    mesh_obj("ridge_trim", tube_bm(ridge, [0.08 - 0.003 * i for i in range(15)], 10), h)
    for side in (-1, 1):
        curl = []
        for i in range(12):
            a = i / 11 * math.pi * 1.2
            curl.append((side * (0.45 + 0.1 * math.sin(a)), 1.75 + 0.35 * math.sin(a), -0.1 + 0.3 * (1 - math.cos(a))))
        mesh_obj(f"lobe{'lr'[side > 0]}_trim", tube_bm(curl, [0.11 - 0.006 * i for i in range(12)], 10), h)
        eye = sphere_bm(0.09, 12, 6)
        mesh_obj(f"eye{'lr'[side > 0]}_glow", transform_bm(eye, lambda v, s=side: v + Vector((s * 0.55, 1.45, 0.18))), h)
    tail = [(0, -1.9 - 0.25 * i, 0.05 * i) for i in range(9)]
    mesh_obj("tail_metal", tube_bm(tail, [0.12 * (1 - i / 9) + 0.01 for i in range(9)], 8), h)
    sockets(h, {
        "engine": ((0, -1.75, 0.0), 0.95),
        "fin_l": ((-1.9, -1.4, 0.0), 0.75),
        "fin_r": ((1.9, -1.4, 0.0), 0.75),
        "cockpit": ((0, 0.7, 0.36), 0.9),
        "lights": ((0, 1.98, 0.0), 0.8),
        "top": ((0, -0.8, 0.36), 0.7),
    })
    spots(h, [(1.0, 0.6, 0.3), (-1.1, 0.1, 0.28), (0.5, -0.9, 0.36), (-1.6, -0.9, 0.15), (1.7, -0.6, 0.14),
              (-0.4, 1.1, 0.33)])
    return h


def hull_barge():
    """A long hauler: a bridge tower up front and a stack of cargo pods behind it."""
    h = empty("hull_barge")
    mesh_obj("body_paint", box_bm((1.5, 4.8, 0.9), bevel=0.2), h)
    mesh_obj("keel_dark", transform_bm(box_bm((1.1, 4.2, 0.3), bevel=0.1), lambda v: v + Vector((0, 0, -0.55))), h)
    for i in range(3):
        pod = box_bm((1.3, 0.95, 0.75), bevel=0.12)
        mesh_obj(f"pod{i}_trim", transform_bm(pod, lambda v, i=i: v + Vector((0, -1.75 + i * 1.05, 0.8))), h)
        strap = box_bm((1.36, 0.12, 0.8), bevel=0.03)
        mesh_obj(f"strap{i}_dark", transform_bm(strap, lambda v, i=i: v + Vector((0, -1.75 + i * 1.05, 0.8))), h)
    tower = box_bm((1.0, 0.8, 0.8), bevel=0.15)
    mesh_obj("tower_paint", transform_bm(tower, lambda v: v + Vector((0, 1.6, 0.8))), h)
    sockets(h, {
        "engine": ((0, -2.42, 0.0), 1.2),
        "fin_l": ((-0.76, -1.6, -0.1), 1.0),
        "fin_r": ((0.76, -1.6, -0.1), 1.0),
        "cockpit": ((0, 1.85, 1.15), 0.8),
        "lights": ((0, 2.42, 0.1), 1.0),
        "top": ((0, -1.75, 1.2), 0.8),
    })
    spots(h, [(0.77, 1.2, 0.1), (-0.77, 0.2, 0.0), (0.77, -1.0, 0.1), (0.0, 2.0, 0.46), (-0.77, -2.0, 0.0),
              (0.0, 0.95, 0.46)])
    return h


def hull_snail():
    """A snail of a ship: a soft, low body under a big spiral shell, with eye stalks up front."""
    h = empty("hull_snail")
    prof = egg(4.0, 0.72, bluntness=0.6)
    sq = (1.15, 0.6)

    def lift(t):
        return -0.15 + 0.12 * max(t - 0.8, 0)
    mesh_obj("body_paint", lathe_bm(prof, squash=sq, lift=lift), h)
    # The shell: a tube coiling inward, with a dark groove along each face so the whorls read.
    coil = []
    for i in range(46):
        a = i * 0.3
        rad = 0.95 * math.exp(-0.075 * a)
        coil.append((0, -0.45 + rad * math.cos(a), 0.85 + rad * math.sin(a)))
    thick = [0.55 * math.exp(-0.075 * i * 0.3) for i in range(46)]
    mesh_obj("shell_trim", tube_bm(coil, thick, 18), h)
    for side in (-1, 1):
        groove = [(side * t * 0.97, y, z) for (_, y, z), t in zip(coil, thick)]
        mesh_obj(f"whorl{'lr'[side > 0]}_dark", tube_bm(groove, [0.07] * len(groove), 6), h)
    for side in (-1, 1):
        stalk = [(side * (0.18 + 0.08 * i / 7), 1.4 + 0.06 * i, 0.2 + 0.11 * i) for i in range(8)]
        mesh_obj(f"stalk{'lr'[side > 0]}_paint", tube_bm(stalk, [0.07] * 8, 8), h)
        tip = sphere_bm(0.13, 12, 6)
        mesh_obj(f"stalktip{'lr'[side > 0]}_glow", transform_bm(tip, lambda v, p=stalk[-1]: v + Vector(p)), h)
    sockets(h, {
        "engine": ((0, -1.95, -0.1), 0.9),
        "fin_l": ((-0.8, -0.4, -0.25), 0.8),
        "fin_r": ((0.8, -0.4, -0.25), 0.8),
        "cockpit": ((0, 1.1, 0.25), 0.8),
        "lights": ((0, 2.0, -0.05), 0.8),
        "top": ((0, -0.45, 1.85), 0.6),
    })
    spots(h, [on_surface(prof, sq, lift, t, a) for t, a in
              ((1.3, 30), (0.9, 150), (-1.4, 20), (-1.2, 160), (0.4, -40), (1.6, 90))])
    return h


def hull_ringdart():
    """A needle racer flying inside its own hoop wing."""
    h = empty("hull_ringdart")
    prof = egg(4.8, 0.48, bluntness=0.4, nose_point=0.5)
    mesh_obj("body_paint", lathe_bm(prof), h)
    band("band_trim", prof, (1.0, 1.0), None, -0.5, -0.2, h)
    hoop = [(math.cos(a) * 1.35, -0.9, math.sin(a) * 1.35) for a in (2 * math.pi * i / 40 for i in range(41))]
    mesh_obj("hoop_trim", tube_bm(hoop, [0.11] * 41, 10, cap=False), h)
    for i, a in enumerate((45, 135, 225, 315)):
        r = math.radians(a)
        strut = [(math.cos(r) * 0.4, -0.9, math.sin(r) * 0.4), (math.cos(r) * 1.3, -0.9, math.sin(r) * 1.3)]
        mesh_obj(f"strut{i}_metal", tube_bm(strut, [0.05, 0.04], 8), h)
    sockets(h, {
        "engine": ((0, -2.25, 0.0), 0.8),
        "fin_l": ((-1.35, -0.9, 0.0), 0.6),
        "fin_r": ((1.35, -0.9, 0.0), 0.6),
        "cockpit": ((0, 0.6, 0.38), 0.75),
        "lights": ((0, 2.38, 0.0), 0.6),
        "top": ((0, -0.9, 1.4), 0.6),
    })
    spots(h, [on_surface(prof, (1.0, 1.0), None, t, a) for t, a in
              ((1.2, 30), (0.4, 150), (-1.4, 60), (-0.4, -30), (1.6, 120), (-1.8, 200))])
    return h


# ---------------------------------------------------------------- parts

def part_engine_rattler():
    """Old, clanky stock drive: a ribbed can with a bent exhaust ring."""
    p = empty("part_engine_rattler")
    prof = [(0.1, 0.38), (0.0, 0.46), (-0.6, 0.46), (-1.0, 0.4), (-1.1, 0.34)]
    mesh_obj("can_metal", lathe_bm(prof), p)
    for i, t in enumerate((-0.2, -0.45, -0.7)):
        mesh_obj(f"rib{i}_dark", lathe_bm([(t + 0.05, 0.5), (t - 0.05, 0.5)]), p)
    mesh_obj("nozzle_glow", lathe_bm([(-1.08, 0.3), (-1.14, 0.2)]), p)
    return p


def part_engine_hush():
    """Hushdrive: a smooth, muffled teardrop that purrs instead of rattling."""
    p = empty("part_engine_hush")
    prof = [(0.1, 0.36), (-0.1, 0.48), (-0.6, 0.5), (-1.1, 0.36), (-1.35, 0.2)]
    mesh_obj("shell_paint", lathe_bm(prof), p)
    mesh_obj("wrap_trim", lathe_bm([(-0.45, 0.53), (-0.65, 0.53)]), p)
    mesh_obj("nozzle_glow", lathe_bm([(-1.33, 0.19), (-1.4, 0.12)]), p)
    return p


def part_engine_sprint():
    """Twin-nozzle racing drive, loud and proud."""
    p = empty("part_engine_sprint")
    for side in (-1, 1):
        prof = [(0.15, 0.25), (0.0, 0.33), (-0.8, 0.33), (-1.15, 0.38), (-1.25, 0.36)]
        mesh_obj(f"can{'lr'[side > 0]}_metal",
                 transform_bm(lathe_bm(prof), lambda v, s=side: v + Vector((s * 0.34, 0, 0))), p)
        mesh_obj(f"nozzle{'lr'[side > 0]}_glow",
                 transform_bm(lathe_bm([(-1.23, 0.3), (-1.3, 0.22)]), lambda v, s=side: v + Vector((s * 0.34, 0, 0))), p)
    brace = box_bm((0.5, 0.5, 0.18), bevel=0.05)
    mesh_obj("brace_trim", transform_bm(brace, lambda v: v + Vector((0, -0.4, 0.22))), p)
    return p


def part_fin_stub():
    p = empty("part_fin_stub")
    mesh_obj("fin_paint", slab_bm([(0, 0.4), (-0.9, 0.1), (-0.9, -0.3), (0, -0.5)], 0.1, 0.9), p)
    return p


def part_fin_swept():
    p = empty("part_fin_swept")
    mesh_obj("fin_paint", slab_bm([(0, 0.6), (-1.3, -0.4), (-1.35, -0.8), (0, -0.6)], 0.09, 0.9), p)
    tip = tube_bm([(-1.3, -0.35, 0), (-1.38, -0.85, 0)], [0.06, 0.06], 8)
    mesh_obj("tip_trim", tip, p)
    return p


def part_fin_wing():
    """Broad wing with an endplate: lots of grip, lots of drag."""
    p = empty("part_fin_wing")
    mesh_obj("fin_paint", slab_bm([(0, 0.7), (-1.6, 0.3), (-1.6, -0.5), (0, -0.7)], 0.1, 0.92), p)
    plate = slab_bm([(0.0, 0.4), (-0.4, 0.5), (-0.5, -0.5), (0.0, -0.6)], 0.06, 0.9)
    mesh_obj("plate_trim", transform_bm(plate, lambda v: Vector((-1.6, v.y, -v.x))), p)
    return p


def part_cockpit_bubble():
    p = empty("part_cockpit_bubble")
    dome = sphere_bm(0.5, 24, 12, lambda v: Vector((v.x, v.y * 1.2, max(v.z, 0.0))))
    mesh_obj("dome_glass", dome, p)
    mesh_obj("ring_trim", lathe_bm([(0.04, 0.0), (0.04, 0.52), (-0.04, 0.52), (-0.04, 0.0)], axis="z",
                                   squash=(1.0, 1.2)), p)
    return p


def part_cockpit_visor():
    """Low, streamlined racing canopy."""
    p = empty("part_cockpit_visor")
    prof = [(0.75, 0.02), (0.5, 0.2), (0.0, 0.3), (-0.6, 0.25), (-0.8, 0.05)]
    mesh_obj("canopy_glass", lathe_bm(prof, squash=(1.0, 0.8), lift=lambda t: 0.12), p)
    return p


def part_cockpit_bay():
    """Wide picture-window cabin, for showing grandkids the view."""
    p = empty("part_cockpit_bay")
    shell = box_bm((1.2, 1.3, 0.55), bevel=0.2)
    mesh_obj("cabin_paint", transform_bm(shell, lambda v: v + Vector((0, -0.1, 0.2))), p)
    window = box_bm((1.24, 0.9, 0.3), bevel=0.12)
    mesh_obj("window_glass", transform_bm(window, lambda v: v + Vector((0, 0.05, 0.25))), p)
    return p


def part_lights_round():
    p = empty("part_lights_round")
    for side in (-1, 1):
        cup = sphere_bm(0.16, 16, 8, lambda v: Vector((v.x, max(v.y, -0.05), v.z)))
        mesh_obj(f"cup{'lr'[side > 0]}_trim", transform_bm(cup, lambda v, s=side: v + Vector((s * 0.3, 0, 0))), p)
        lamp = sphere_bm(0.11, 12, 6)
        mesh_obj(f"lamp{'lr'[side > 0]}_glow", transform_bm(lamp, lambda v, s=side: v + Vector((s * 0.3, 0.06, 0))), p)
    return p


def part_lights_bar():
    p = empty("part_lights_bar")
    housing = box_bm((0.9, 0.16, 0.16), bevel=0.06)
    mesh_obj("housing_dark", housing, p)
    mesh_obj("bar_glow", transform_bm(box_bm((0.8, 0.06, 0.08), bevel=0.03), lambda v: v + Vector((0, 0.07, 0))), p)
    return p


def part_gadget_ribbon():
    """Slipstream ribbon launcher: leaves a shimmering ribbon that boosts whoever follows it."""
    p = empty("part_gadget_ribbon")
    spool = lathe_bm([(0.2, 0.0), (0.2, 0.22), (-0.2, 0.22), (-0.2, 0.0)], axis="z")
    mesh_obj("spool_trim", transform_bm(spool, lambda v: Vector((v.z, v.y, v.x + 0.22))), p)
    ribbon = [(0, -0.1 - 0.12 * i, 0.3 + 0.08 * math.sin(i * 1.3)) for i in range(8)]
    mesh_obj("ribbon_glow", tube_bm(ribbon, [0.05] * 8, 6), p)
    return p


def part_gadget_bubble():
    """Bubble shield emitter: a little dish that pops a protective bubble."""
    p = empty("part_gadget_bubble")
    mesh_obj("stem_metal", tube_bm([(0, 0, 0), (0, 0, 0.3)], [0.06, 0.06], 8), p)
    dish = lathe_bm([(0.32, 0.03), (0.3, 0.25), (0.26, 0.3)], axis="z")
    mesh_obj("dish_trim", dish, p)
    orb = sphere_bm(0.1, 12, 6)
    mesh_obj("orb_glow", transform_bm(orb, lambda v: v + Vector((0, 0, 0.45))), p)
    return p


def part_engine_ring():
    """Halo drive: a short can pushing through a ring of light."""
    p = empty("part_engine_ring")
    mesh_obj("can_metal", lathe_bm([(0.1, 0.3), (0.0, 0.38), (-0.5, 0.38), (-0.7, 0.3)]), p)
    halo = [(math.cos(a) * 0.62, -0.95, math.sin(a) * 0.62) for a in (2 * math.pi * i / 32 for i in range(33))]
    mesh_obj("halo_glow", tube_bm(halo, [0.07] * 33, 8, cap=False), p)
    for i, a in enumerate((0, 120, 240)):
        r = math.radians(a)
        arm = [(math.cos(r) * 0.3, -0.6, math.sin(r) * 0.3), (math.cos(r) * 0.6, -0.95, math.sin(r) * 0.6)]
        mesh_obj(f"arm{i}_trim", tube_bm(arm, [0.04, 0.04], 6), p)
    mesh_obj("nozzle_glow", lathe_bm([(-0.68, 0.26), (-0.75, 0.18)]), p)
    return p


def part_fin_feather():
    """Three broad feathered vanes fanned out like a bird's wing."""
    p = empty("part_fin_feather")
    for i, (sweep, length) in enumerate(((0.45, 1.2), (0.05, 1.45), (-0.35, 1.15))):
        vane = slab_bm([(0, 0.22), (-length * 0.7, 0.28 + sweep), (-length, sweep + 0.05), (-length * 0.9, sweep - 0.18),
                        (0, -0.18)], 0.07, 0.85)
        mesh_obj(f"vane{i}_paint", transform_bm(vane, lambda v, i=i: v + Vector((0, -i * 0.16, 0.04 * (1 - i)))), p)
        tip = slab_bm([(-length * 0.75, 0.24 + sweep), (-length, sweep + 0.05), (-length * 0.9, sweep - 0.18),
                       (-length * 0.68, sweep - 0.08)], 0.08, 0.9)
        mesh_obj(f"tip{i}_trim", transform_bm(tip, lambda v, i=i: v + Vector((0, -i * 0.16, 0.04 * (1 - i)))), p)
    return p


def part_cockpit_eye():
    """A single great eyeball of a canopy that watches the road ahead."""
    p = empty("part_cockpit_eye")
    mesh_obj("eye_glass", sphere_bm(0.48, 24, 12, lambda v: Vector((v.x, v.y, v.z * 0.95 + 0.2))), p)
    iris = sphere_bm(0.22, 16, 8, lambda v: Vector((v.x, v.y * 0.25, v.z)))
    mesh_obj("iris_dark", transform_bm(iris, lambda v: v + Vector((0, 0.42, 0.28))), p)
    lid = sphere_bm(0.53, 24, 12, lambda v: Vector((v.x, v.y, max(v.z, 0.18) + 0.2)))
    mesh_obj("lid_paint", transform_bm(lid, lambda v: v + Vector((0, -0.06, 0.02))), p)
    return p


def part_lights_stalks():
    """Two lamps on wobbly stalks, like a curious bug's feelers."""
    p = empty("part_lights_stalks")
    for side in (-1, 1):
        stalk = [(side * (0.15 + 0.05 * i), 0.06 * i, 0.08 * i - 0.02 * i * i / 6) for i in range(7)]
        mesh_obj(f"stalk{'lr'[side > 0]}_metal", tube_bm(stalk, [0.035] * 7, 6), p)
        lamp = sphere_bm(0.12, 12, 6)
        mesh_obj(f"lamp{'lr'[side > 0]}_glow", transform_bm(lamp, lambda v, q=stalk[-1]: v + Vector(q)), p)
    return p


def part_gadget_magnet():
    """Tow magnet: a big red horseshoe magnet on a swivel, pointing forward."""
    p = empty("part_gadget_magnet")
    mesh_obj("post_metal", tube_bm([(0, 0, 0), (0, 0, 0.25)], [0.07, 0.07], 8), p)
    shoe = [(0.22 * math.cos(a), 0.05, 0.42 + 0.22 * math.sin(a)) for a in (math.pi + math.pi * i / 12 for i in range(13))]
    shoe = [(x, -0.1, z) for x, _, z in shoe]
    arm = [(0.22, -0.1, 0.42), (0.22, 0.25, 0.42)]
    mesh_obj("shoe_trim", tube_bm(shoe, [0.08] * 13, 10), p)
    for side in (-1, 1):
        mesh_obj(f"arm{side}_trim", tube_bm([(side * 0.22, -0.1, 0.42), (side * 0.22, 0.22, 0.42)], [0.08, 0.08], 10), p)
        mesh_obj(f"tip{side}_metal", tube_bm([(side * 0.22, 0.22, 0.42), (side * 0.22, 0.32, 0.42)], [0.085, 0.085], 10), p)
    return grow(p, 1.7)


def part_gadget_horn():
    """Foghorn: a brass trumpet bell on a stalk, aimed forward."""
    p = empty("part_gadget_horn")
    mesh_obj("stem_metal", tube_bm([(0, 0, 0), (0, 0, 0.3)], [0.06, 0.06], 8), p)
    bell = lathe_bm([(-0.25, 0.05), (0.0, 0.06), (0.2, 0.1), (0.32, 0.2), (0.38, 0.3)])
    mesh_obj("bell_trim", transform_bm(bell, lambda v: v + Vector((0, 0, 0.36))), p)
    mesh_obj("mouth_dark", transform_bm(lathe_bm([(0.37, 0.27), (0.36, 0.001)]), lambda v: v + Vector((0, 0, 0.36))), p)
    return grow(p, 1.8)


def grow(part, factor):
    """Scale a part's meshes about its socket, for gadgets that need to read from the chase camera."""
    for child in part.children:
        child.data.transform(Matrix.Scale(factor, 4))
    return part


HULLS = (hull_moth, hull_kettle, hull_heron, hull_bucket, hull_saucer, hull_manta, hull_barge, hull_snail,
         hull_ringdart)
PARTS = (part_engine_rattler, part_engine_hush, part_engine_sprint, part_fin_stub, part_fin_swept,
         part_fin_wing, part_cockpit_bubble, part_cockpit_visor, part_cockpit_bay, part_lights_round,
         part_lights_bar, part_gadget_ribbon, part_gadget_bubble, part_engine_ring, part_fin_feather,
         part_cockpit_eye, part_lights_stalks, part_gadget_magnet, part_gadget_horn)


def build_kit():
    for build in HULLS + PARTS:
        build()
