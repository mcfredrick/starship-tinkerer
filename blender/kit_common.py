"""Mesh-building helpers shared by the ship kit, portraits and props.

Runs inside Blender's Python. Blender space: +Y is forward (ship noses), +Z is up.
"""

import math

import bmesh
import bpy
from mathutils import Vector


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj, parent=None):
    bpy.context.scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def child_name(name, parent):
    """Prefix children with their part so every name in the kit is unique (no Blender .001 suffixes)."""
    return f"{parent.name}__{name}" if parent else name


def empty(name, parent=None, loc=(0, 0, 0), scale=1.0):
    e = bpy.data.objects.new(child_name(name, parent), None)
    e.empty_display_size = 0.2
    e.location = loc
    e.scale = (scale, scale, scale)
    return link(e, parent)


def mesh_obj(name, bm, parent=None, smooth=True, loc=(0, 0, 0)):
    name = child_name(name, parent)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.shade_smooth()
    obj = link(bpy.data.objects.new(name, me), parent)
    obj.location = loc
    return obj


def new_bm():
    bm = bmesh.new()
    bm.loops.layers.uv.new()
    return bm


def _finish(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    return bm


def lathe_bm(profile, segments=32, squash=(1.0, 1.0), lift=None, axis="y"):
    """Revolve `profile` [(t, radius), ...] around an axis, closing both ends with a fan.

    `squash` scales the cross-section (x, z); `lift(t)` shifts each ring vertically, which bends
    noses up or tails down without extra geometry.
    """
    bm = new_bm()
    uv = bm.loops.layers.uv.active
    rings = []
    for t, r in profile:
        r = max(r, 0.001)
        dz = lift(t) if lift else 0.0
        ring = []
        for s in range(segments):
            a = 2 * math.pi * s / segments
            x, z = math.cos(a) * r * squash[0], math.sin(a) * r * squash[1] + dz
            ring.append(bm.verts.new((x, t, z) if axis == "y" else (x, z, t)))
        rings.append(ring)
    n = len(rings)
    for i in range(n - 1):
        for s in range(segments):
            s2 = (s + 1) % segments
            f = bm.faces.new((rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]))
            for loop, (u, v) in zip(f.loops, ((s, i), (s + 1, i), (s + 1, i + 1), (s, i + 1))):
                loop[uv].uv = (u / segments, v / (n - 1))
    for ring, (t, _) in ((rings[0], profile[0]), (rings[-1], profile[-1])):
        center = Vector((0, 0, 0))
        for v in ring:
            center += v.co
        hub = bm.verts.new(center / len(ring))
        for s in range(segments):
            bm.faces.new((ring[s], ring[(s + 1) % segments], hub))
    return _finish(bm)


def tube_bm(points, radii, segments=16, cap=True):
    """Sweep a circle along `points` with a radius per point (handles, pipes, antennae, brows)."""
    bm = new_bm()
    uv = bm.loops.layers.uv.active
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        tangent = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
        side = tangent.cross(ref).normalized()
        normal = side.cross(tangent)
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * s / segments)
                                        + normal * math.sin(2 * math.pi * s / segments)) * radii[i])
                      for s in range(segments)])
    for i in range(len(rings) - 1):
        for s in range(segments):
            s2 = (s + 1) % segments
            f = bm.faces.new((rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]))
            for loop, (u, v) in zip(f.loops, ((s, i), (s + 1, i), (s + 1, i + 1), (s, i + 1))):
                loop[uv].uv = (u / segments, v / (len(rings) - 1))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return _finish(bm)


def sphere_bm(radius=1.0, segments=32, rings=16, shape=None):
    """UV sphere; `shape(v)` returns a new position for each vertex."""
    bm = new_bm()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius, calc_uvs=True)
    if shape:
        for v in bm.verts:
            v.co = shape(v.co.copy())
    return _finish(bm)


def box_bm(size, bevel=0.0, segments=3):
    """Box centered on the origin with optional rounded edges, so toon bands catch the corners."""
    bm = new_bm()
    bmesh.ops.create_cube(bm, size=1.0, calc_uvs=True)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segments, affect="EDGES",
                        profile=0.5)
    return _finish(bm)


def slab_bm(outline, thickness, taper=1.0):
    """Extrude a 2D outline [(x, y), ...] in the XY plane to a flat plate (fins, wings, ears).

    `taper` shrinks the top face toward the outline's centroid for a beveled edge look.
    """
    bm = new_bm()
    cx = sum(p[0] for p in outline) / len(outline)
    cy = sum(p[1] for p in outline) / len(outline)
    bottom = [bm.verts.new((x, y, -thickness / 2)) for x, y in outline]
    top = [bm.verts.new((cx + (x - cx) * taper, cy + (y - cy) * taper, thickness / 2)) for x, y in outline]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    uv = bm.loops.layers.uv.active
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co.x, loop.vert.co.y)
    return _finish(bm)


def transform_bm(bm, fn):
    for v in bm.verts:
        v.co = fn(v.co.copy())
    return _finish(bm)
