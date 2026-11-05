"""What every building made in Blender shares: the shapes buildings are made
of, laid out in the world's own axes and measures, and how a building is
written out, with no skeleton, its pieces tagged for the variants they are
drawn for and its fine work last.

Points are given as the world takes them: y up, the front toward +z, in the
world's units (a hold's keep stands some 0.6 tall). Each is made at ten
times that in Blender (z up, the front toward -y), and the game reads the
file back at a tenth (Art.buildingScale in Sources/NullmereModels/Art/Art.swift).
"""
import math
import os
import re

import bpy
import bmesh
from mathutils import Matrix, Vector

from common import *

UNIT = 10.0


def at(x, y, z):
    """A point in the world's axes and units, in Blender's."""
    return Vector((x * UNIT, -z * UNIT, y * UNIT))


def mesh_object(name, build, mat, smooth=False):
    """An object of a mesh `build(bm)` makes, in one material."""
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    bm = bmesh.new()
    build(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if mat:
        mesh.materials.append(mat)
    return obj


def block(name, low, high, mat, chamfer=0.0, turn=0.0, about=None):
    """A block from one corner to the other (the world's axes), its edges
    cut back by `chamfer` (world units) if given, turned `turn` radians
    about the upright through `about` (its middle, if not given)."""
    lo, hi = at(*low), at(*high)
    a = Vector((min(lo.x, hi.x), min(lo.y, hi.y), min(lo.z, hi.z)))
    b = Vector((max(lo.x, hi.x), max(lo.y, hi.y), max(lo.z, hi.z)))
    pivot = at(*about) if about is not None else (a + b) / 2

    def build(bm):
        corners = [bm.verts.new((x, y, z)) for z in (a.z, b.z) for y in (a.y, b.y) for x in (a.x, b.x)]
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            bm.faces.new([corners[i] for i in f])
        if chamfer > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=chamfer * UNIT, segments=1, affect="EDGES", clamp_overlap=True)
        if turn:
            rotation = Matrix.Translation(pivot) @ Matrix.Rotation(-turn, 4, "Z") @ Matrix.Translation(-pivot)
            bmesh.ops.transform(bm, matrix=rotation, verts=bm.verts)
    return mesh_object(name, build, mat)


def rings(name, sections, sides, mat, caps=(True, True), twist=0.0, centre=(0.0, 0.0), smooth=False, squash=1.0):
    """A body turned about an upright: each section (radius, height) a ring
    of `sides` (in the world's units), a turn of `twist` radians; `centre`
    the upright's x and z; `squash` its depth against its breadth."""
    cx, cz = centre

    def build(bm):
        made = []
        for radius, height in sections:
            ring = []
            for s in range(sides):
                angle = twist + 2 * math.pi * s / sides
                ring.append(bm.verts.new(at(cx + radius * math.cos(angle), height, cz + radius * squash * math.sin(angle))))
            made.append(ring)
        for lower, upper in zip(made, made[1:]):
            for s in range(sides):
                n = (s + 1) % sides
                if lower[s].co == lower[n].co:
                    bm.faces.new((lower[s], upper[n], upper[s]))
                elif upper[s].co == upper[n].co:
                    bm.faces.new((lower[s], lower[n], upper[s]))
                else:
                    bm.faces.new((lower[s], lower[n], upper[n], upper[s]))
        if caps[0] and sections[0][0] > 0:
            bm.faces.new(list(reversed(made[0])))
        if caps[1] and sections[-1][0] > 0:
            bm.faces.new(made[-1])
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return mesh_object(name, build, mat, smooth)


def hip_roof(name, centre, width, depth, base, height, mat, overhang=0.0, thickness=0.0):
    """A roof of four slopes over a footprint `width` by `depth` about
    `centre` (x, z), its eaves `overhang` beyond it at `base`, rising
    `height` to a ridge (to a point, if square); `thickness` beneath its
    eaves, if any."""
    cx, cz = centre
    w, d = width / 2 + overhang, depth / 2 + overhang
    ridge = max(0.0, (width - depth) / 2)

    def build(bm):
        eaves = [bm.verts.new(at(cx + x, base, cz + z)) for x, z in ((-w, -d), (w, -d), (w, d), (-w, d))]
        top = [bm.verts.new(at(cx - ridge, base + height, cz)), bm.verts.new(at(cx + ridge, base + height, cz))]
        if ridge > 0:
            bm.faces.new((eaves[0], eaves[1], top[1], top[0]))
            bm.faces.new((eaves[1], eaves[2], top[1]))
            bm.faces.new((eaves[2], eaves[3], top[0], top[1]))
            bm.faces.new((eaves[3], eaves[0], top[0]))
        else:
            peak = top[0]
            bm.verts.remove(top[1])
            for i in range(4):
                bm.faces.new((eaves[i], eaves[(i + 1) % 4], peak))
        if thickness > 0:
            under = [bm.verts.new(at(cx + x, base - thickness, cz + z)) for x, z in ((-w, -d), (w, -d), (w, d), (-w, d))]
            for i in range(4):
                bm.faces.new((under[i], under[(i + 1) % 4], eaves[(i + 1) % 4], eaves[i]))
            bm.faces.new(list(reversed(under)))
        else:
            bm.faces.new(list(reversed(eaves)))
    return mesh_object(name, build, mat)


def gable_roof(name, centre, span, length, base, height, mat, overhang=0.0, along="z", thickness=0.0):
    """A roof of two slopes, its ridge running `along` x or z for `length`
    over a span of `span`, from eaves at `base` (overhanging both ways) up
    `height`."""
    cx, cz = centre
    s, l = span / 2 + overhang, length / 2 + overhang

    def p(across, up, run):
        return at(cx + across, up, cz + run) if along == "z" else at(cx + run, up, cz + across)

    def build(bm):
        e = [bm.verts.new(p(x, base, z)) for x, z in ((-s, -l), (s, -l), (s, l), (-s, l))]
        r = [bm.verts.new(p(0, base + height, z)) for z in (-l, l)]
        bm.faces.new((e[0], e[3], r[1], r[0]))
        bm.faces.new((e[1], r[0], r[1], e[2]))
        bm.faces.new((e[0], r[0], e[1]))
        bm.faces.new((e[2], r[1], e[3]))
        if thickness > 0:
            u = [bm.verts.new(p(x, base - thickness, z)) for x, z in ((-s, -l), (s, -l), (s, l), (-s, l))]
            for i in range(4):
                bm.faces.new((u[i], u[(i + 1) % 4], e[(i + 1) % 4], e[i]))
            bm.faces.new(list(reversed(u)))
        else:
            bm.faces.new((e[0], e[1], e[2], e[3]))
    return mesh_object(name, build, mat)


def slab(name, outline, mat, thickness, normal=(0, 0, 1)):
    """A flat piece cut to `outline` (points in the world's axes, in one
    plane), made `thickness` thick along `normal`."""
    n = Vector(normal).normalized()
    shift = Vector((n.x, -n.z, n.y)) * thickness * UNIT / 2

    def build(bm):
        front = [bm.verts.new(at(*q) + shift) for q in outline]
        back = [bm.verts.new(at(*q) - shift) for q in outline]
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            bm.faces.new((back[i], back[j], front[j], front[i]))
    return mesh_object(name, build, mat)


def rod(name, a, b, radius, mat, sides=6, caps=(True, True), smooth=False):
    """A round rod from one point to another (the world's)."""
    return loft(name, [(tuple(at(*a)), radius * UNIT, radius * UNIT, {}), (tuple(at(*b)), radius * UNIT, radius * UNIT, {})],
                segments=sides, mat=mat, caps=caps, smooth=smooth)


def lath(name, a, b, width, depth, mat):
    """A square timber from one point to another (the world's)."""
    return loft(name, [(tuple(at(*a)), width * UNIT / 2, depth * UNIT / 2, {}), (tuple(at(*b)), width * UNIT / 2, depth * UNIT / 2, {})],
                segments=4, mat=mat, caps=(True, True), smooth=False)


def merlons(name, a, b, count, size, mat, chamfer=0.0):
    """Merlons along a wall's top from `a` to `b` (the world's), `count` of
    them `size` (along, up, through) with gaps between."""
    a, b = Vector(a), Vector(b)
    along = b - a
    turn = math.atan2(along.z, along.x)
    pieces = []
    for index in range(count):
        middle = a + along * ((index + 0.5) / count)
        low = (middle.x - size[0] / 2, middle.y, middle.z - size[2] / 2)
        high = (middle.x + size[0] / 2, middle.y + size[1], middle.z + size[2] / 2)
        pieces.append(block("merlon", low, high, mat, chamfer=chamfer, turn=-turn, about=tuple(middle)))
    return join(name, pieces)


def flag(name, top, width, height, mat, turn=0.0, tail=False, thickness=0.004):
    """A flag hung from its pole at `top` (the world's), flying `width` out
    along `turn` radians from +x (about the upright, toward -z), `height`
    deep, swallow-tailed if `tail`; still at the pole and free at its end."""
    c, s = math.cos(turn), math.sin(turn)
    outline = [(0, 0), (width, 0), (width, -height)] if not tail else [(0, 0), (width, 0), (width * 0.72, -height / 2), (width, -height)]
    outline = outline + [(0, -height)]
    points = [(top[0] + u * c, top[1] + v, top[2] - u * s) for u, v in outline]
    obj = slab(name, points, mat, thickness, normal=(s, 0, c))
    base = at(*top)
    sway(obj, lambda q: max(0.0, min(1.0, (Vector((q.x - base.x, q.y - base.y, 0)).length) / (width * UNIT))))
    return obj


def lit(name, centre, width, height, facing, mat, depth=0.024):
    """A lit pane `width` by `height` about `centre` (the world's), facing
    `facing` radians round from +z."""
    c, s = math.cos(facing), math.sin(facing)
    x, y, z = centre
    half_w, half_h, half_d = width / 2, height / 2, depth / 2
    corners = []
    for du, dv, dn in ((-half_w, -half_h, -half_d), (half_w, -half_h, -half_d), (half_w, half_h, -half_d), (-half_w, half_h, -half_d),
                       (-half_w, -half_h, half_d), (half_w, -half_h, half_d), (half_w, half_h, half_d), (-half_w, half_h, half_d)):
        corners.append((x + du * c + dn * s, y + dv, z - du * s + dn * c))

    def build(bm):
        v = [bm.verts.new(at(*q)) for q in corners]
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            bm.faces.new([v[i] for i in f])
    return mesh_object(name, build, mat)


def faced(centre, facing, u, v, n):
    """The point `u` across, `v` up and `n` out from `centre` on a face
    looking `facing` radians round from +z."""
    c, s = math.cos(facing), math.sin(facing)
    return (centre[0] + u * c + n * s, centre[1] + v, centre[2] - u * s + n * c)


def tagged(name, tags):
    """A piece's name with the variants it is drawn for."""
    return name + ("@" + ",".join(tags) if tags else "")


def finish_building(path, variants):
    """Every mesh cleaned, each variant's triangles far and near told, and
    the building written out."""
    from person import drawn, triangles
    doubled = [obj.name for obj in bpy.context.scene.objects if obj.type == "MESH" and re.search(r"\.\d{3}$", obj.name)]
    if doubled:
        raise ValueError("pieces named twice: %s" % ", ".join(sorted(doubled)))
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            clean(obj)
    for variant in variants:
        coarse = fine = 0
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH" or not drawn(obj.name, 1, variant):
                continue
            if obj.name.endswith("!fine"):
                fine += triangles(obj)
            else:
                coarse += triangles(obj)
        print("%s: %d triangles far, %d near" % (variant, coarse, coarse + fine))
        if os.environ.get("NULLMERE_PIECES") == variant:
            for obj in sorted((o for o in bpy.context.scene.objects if o.type == "MESH" and drawn(o.name, 1, variant)),
                              key=lambda o: -triangles(o)):
                print("    %4d %s" % (triangles(obj), obj.name))
    export(path)
