"""What every work made in Blender shares: its rig, the pieces its families
build from, and how a level's pieces are tagged.

A work's levels are the tiers of one file ("barn@3"). Its rig is a base
bone at its foot, to which its packed ground is skinned so the file
carries a skeleton, and a bone for each moving part at each level where it
stands ("sack hoist@3"), the game's importer keeping those of the level
asked for under their names without their tags. Its motion is one action,
"idle", keyed at every few frames of the idle's four seconds.
"""
import math
import random

import bpy
from mathutils import Matrix, Quaternion, Vector

from building import *
from common import *


def level_tags(levels):
    """The tags for pieces drawn at these levels."""
    return [str(level) for level in levels]


def work_rig(parts):
    """A work's rig: its base, and each moving part as (name, pivot, axis)
    in the world's axes and units, its bone from the pivot along the axis
    it turns about."""
    bones = [("base", tuple(at(0, 0, 0)), tuple(at(0, 0.1, 0)), None)]
    for name, pivot, axis in parts:
        head = Vector(at(*pivot))
        direction = Vector((axis[0], -axis[2], axis[1])).normalized()
        bones.append((name, tuple(head), tuple(head + direction * 0.2), "base"))
    return armature("Work", bones)


def ground(obj, rig):
    """The work's packed ground, skinned whole to its base."""
    group = obj.vertex_groups.new(name="base")
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    bind(obj, rig)
    return obj


def on(obj, rig, bone):
    """A piece carried by one of the work's moving parts."""
    hang(obj, rig, bone)
    return obj


def swing(u):
    """A swing's share at a share `u` of the idle: out, held, back past
    rest, and home (Machinery.Swing's in the game)."""
    keys = [(0.0, 0.0), (0.3, 1.0), (0.5, 1.0), (0.8, -0.4), (1.0, 0.0)]
    for (u0, a0), (u1, a1) in zip(keys, keys[1:]):
        if u0 <= u <= u1:
            t = (u - u0) / (u1 - u0)
            t = t * t * (3 - 2 * t)
            return a0 + (a1 - a0) * t
    return 0.0


def wheel_turns(turns):
    """A wheel's angle at a share `u` of the idle: `turns` whole turns
    round, at one even rate (Machinery.Wheel's)."""
    return lambda u: 2 * math.pi * turns * u


def leaping(u):
    """A flame's stretch at a share `u` of the idle: across, up, across
    (Machinery's flames)."""
    leap = 0.6 * math.sin(2 * math.pi * u * 5) + 0.4 * math.sin(2 * math.pi * (u * 7 + 0.3))
    return (1 + 0.08 * leap, 1 + 0.22 * leap, 1 + 0.08 * leap)


def idle(rig, turns=(), stretches=(), frames=120):
    """The work's idle, keyed at every frame of `frames`: each turning part
    as (bone, axis in the world's axes, angle(u)), each flame as (bone,
    stretch(u) across, up and across)."""
    rig.animation_data_create()
    act = bpy.data.actions.new("idle")
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    last = {}
    for frame in range(frames + 1):
        u = frame / frames
        for bone, axis, angle in turns:
            pb = rig.pose.bones[bone]
            rest = rig.data.bones[bone].matrix_local.to_3x3()
            turn = Matrix.Rotation(angle(u), 3, Vector((axis[0], -axis[2], axis[1])).normalized())
            q = (rest.inverted() @ turn @ rest).to_quaternion()
            # The same turn kept on the side of the last frame's, so a wheel
            # turned past a half goes on the short way round.
            if bone in last and q.dot(last[bone]) < 0:
                q = -q
            last[bone] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        for bone, stretch in stretches:
            pb = rig.pose.bones[bone]
            across, up, deep = stretch(u)
            # The bone stands upright: its own y is the world's up.
            pb.scale = Vector((across, up, deep))
            pb.keyframe_insert("scale", frame=frame)
    track = rig.animation_data.nla_tracks.new()
    track.name = "idle"
    strip = track.strips.new("idle", 0, act)
    strip.name = "idle"
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.scale = Vector((1, 1, 1))
    return act


# MARK: What works are built of

def on_ring(radius, y, angle, centre=(0.0, 0.0)):
    """A point `radius` out from an upright at `centre` (x, z), `angle`
    round it as the game's MeshBuilder.ring counts: from +x toward -z."""
    return (centre[0] + radius * math.cos(angle), y, centre[1] - radius * math.sin(angle))


def posed(obj, at_point, axis, angle):
    """A piece made about the origin, turned `angle` about an axis of the
    world's (as the game's rotations turn) and set down at a point."""
    turn = Matrix.Rotation(angle, 4, Vector((axis[0], -axis[2], axis[1])).normalized())
    obj.matrix_world = Matrix.Translation(at(*at_point)) @ turn
    apply_transforms(obj)
    return obj


def rock(name, centre, size, seed, mat, bands=3, sides=6, jitter=0.2):
    """A rough stone about `centre`, `size` its half-extents (the world's
    x, y, z), each point pushed in or out at random by up to `jitter` of
    its reach, the same stone for the same seed."""
    chance = random.Random(seed)

    def build(bm):
        rows = []
        for band in range(bands + 1):
            latitude = math.pi * band / bands - math.pi / 2
            pole = band in (0, bands)
            row = []
            for side in range(1 if pole else sides):
                longitude = 2 * math.pi * side / sides
                push = 1 + jitter * (2 * chance.random() - 1)
                d = (math.cos(latitude) * math.cos(longitude), math.sin(latitude), -math.cos(latitude) * math.sin(longitude))
                row.append(bm.verts.new(at(centre[0] + d[0] * size[0] * push, centre[1] + d[1] * size[1] * push,
                                           centre[2] + d[2] * size[2] * push)))
            rows.append(row)
        for lower, upper in zip(rows, rows[1:]):
            for side in range(sides):
                n = (side + 1) % sides
                if len(lower) == 1:
                    bm.faces.new((lower[0], upper[n], upper[side]))
                elif len(upper) == 1:
                    bm.faces.new((lower[side], lower[n], upper[0]))
                else:
                    bm.faces.new((lower[side], lower[n], upper[n], upper[side]))
    return mesh_object(name, build, mat)


def log(name, a, b, radius, sides=5):
    """A log in its bark, its sawn ends pale."""
    obj = rod(name, a, b, radius, material("plain_timber_bark", (0.25, 0.2, 0.15)), sides=sides)
    obj.data.materials.append(material("plain_timber_pale", (0.45, 0.37, 0.28)))
    axis = (at(*b) - at(*a)).normalized()
    for poly in obj.data.polygons:
        if abs(poly.normal.dot(axis)) > 0.9:
            poly.material_index = 1
    return obj


def pad(name, radius, mat, sides=12):
    """Packed ground a work stands on, sunk deep enough to sit on a slope."""
    return rings(name, [(radius, -0.14), (radius, 0.0), (radius * 0.95, 0.012)], sides, mat, twist=math.pi / sides)


def placed(obj, at_point, turn=0.0):
    """A piece made about the origin, set down at a point and turned."""
    obj.location = at(*at_point)
    obj.rotation_euler = (0.0, 0.0, turn)
    apply_transforms(obj)
    return obj


def hall(name, width, depth, height, wall, roof, frame, pitch=0.55, footing=None, overhang=0.022, eaves=0.01):
    """A building with a gable roof, its ridge along x, about the origin:
    its walls on a footing of stone, if any, its frame dark against walls
    and roof (posts at the corners, boards along the eaves, a beam along
    the ridge). Returns its far pieces and its fine work: two courses
    across each slope, boards up the gables and the rafters' ends."""
    w, d, rise = width / 2, depth / 2, depth * pitch
    far = []
    if footing is not None:
        far.append(block("footing", (-w - 0.012, -0.08, -d - 0.012), (w + 0.012, 0.04, d + 0.012), footing))
    far.append(block("walls", (-w, -0.04, -d), (w, height, d), wall))
    far.append(gable_roof("roof", (0, 0), depth, width, height, rise, roof, overhang=overhang, along="x", thickness=eaves))
    for x in (-w, w):
        for z in (-d, d):
            far.append(block("post", (x - 0.007, -0.02, z - 0.007), (x + 0.007, height + 0.02, z + 0.007), frame))
    for z in (-d - 0.02, d + 0.02):
        far.append(block("eave board", (-w - 0.022, height - 0.001, z - 0.004), (w + 0.022, height + 0.009, z + 0.004), frame))
    far.append(block("ridge", (-w - 0.025, height + rise - 0.002, -0.007), (w + 0.025, height + rise + 0.01, 0.007), frame))
    fine = []
    eave, end = d + overhang, w + overhang
    for t in (0.3, 0.62):
        for side in (1, -1):
            z = side * eave * (1 - t)
            fine.append(lath("course", (-end, height + rise * t + 0.004, z), (end, height + rise * t + 0.004, z), 0.008, 0.008, frame))
    for x in (-end + 0.003, end - 0.003):
        for side in (1, -1):
            fine.append(lath("bargeboard", (x, height + rise * 0.05, side * eave * 0.95), (x, height + rise + 0.006, 0), 0.012, 0.012, frame))
        fine.append(block("vent", (x - 0.003, height + rise * 0.38 - 0.011, -0.013), (x + 0.003, height + rise * 0.38 + 0.011, 0.013), frame))
    rafters = max(int(round(width / 0.06)), 2)
    for index in range(rafters + 1):
        x = -w + width * index / rafters
        for side in (1, -1):
            fine.append(lath("rafter", (x, height - 0.006, side * (d - 0.004)), (x, height + 0.006, side * (d + 0.02)), 0.008, 0.008, frame))
    return far, fine


def round_house(name, radius, height, wall, roof, band, finial, rise=None, sides=8):
    """A round bin or tower under a cone, about the origin: its fine work,
    two bands about its wall, a ring round its roof and a finial."""
    rise = rise if rise is not None else radius * 1.5
    far = [rings("wall", [(radius, -0.06), (radius, height)], sides, wall),
           rings("roof", [(radius * 1.18, height), (0.0, height + rise)], sides, roof)]
    fine = []
    for y in (height * 0.3, height * 0.72):
        fine.append(rings("band", [(radius * 0.98, y), (radius * 1.05, y + 0.004), (radius * 1.05, y + 0.013), (radius * 0.98, y + 0.017)],
                          sides, band, caps=(False, False)))
    r, y = radius * 1.18 * 0.55, height + rise * 0.45
    fine.append(rings("roof ring", [(r * 0.97, y - 0.006), (r * 1.04, y), (r * 0.97, y + 0.008)], sides, roof, caps=(False, False)))
    fine.append(rings("finial", [(0.006, height + rise - 0.012), (0.002, height + rise + 0.035)], 4, finial))
    return far, fine


def tied_sack(name, at_point, size, mat):
    """A sack tied at its neck, sat up, `size` times one a hand high."""
    s = size / 0.022 * 0.022
    profile = [(0.0, 0.0), (0.022, 0.004), (0.027, 0.02), (0.021, 0.036), (0.008, 0.044), (0.011, 0.05), (0.0, 0.052)]
    return rings(name, [(r * s / 0.022 * 1.0, at_point[1] + y * s / 0.022) for r, y in profile], 6, mat, centre=(at_point[0], at_point[2]))


def ladder(name, a, b, width, rungs, mat):
    """A ladder from its foot `a` to its head `b`."""
    a, b = Vector(a), Vector(b)
    along = b - a
    side = Vector((along.z, 0, -along.x))
    side = side.normalized() * (width / 2) if side.length > 1e-6 else Vector((width / 2, 0, 0))
    pieces = [lath("stile", tuple(a + side), tuple(b + side), 0.004, 0.004, mat), lath("stile", tuple(a - side), tuple(b - side), 0.004, 0.004, mat)]
    for index in range(1, rungs + 1):
        p = a + along * (index / (rungs + 1))
        pieces.append(lath("rung", tuple(p - side), tuple(p + side), 0.003, 0.003, mat))
    return pieces


def wheel(name, centre, radius, width, spokes, mat, axis="z"):
    """A wheel on its axle along `axis` (x or z), its rim and spokes."""
    cx, cy, cz = centre
    pieces = []
    rim = []
    sides = 10
    for k in range(sides):
        a0, a1 = 2 * math.pi * k / sides, 2 * math.pi * (k + 1) / sides
        if axis == "z":
            p = (cx + radius * math.cos(a0), cy + radius * math.sin(a0), cz)
            q = (cx + radius * math.cos(a1), cy + radius * math.sin(a1), cz)
        else:
            p = (cx, cy + radius * math.sin(a0), cz + radius * math.cos(a0))
            q = (cx, cy + radius * math.sin(a1), cz + radius * math.cos(a1))
        rim.append(lath("felloe", p, q, width, width, mat))
    pieces += rim
    for k in range(spokes):
        a = math.pi * k / spokes
        if axis == "z":
            p = (cx + radius * math.cos(a), cy + radius * math.sin(a), cz)
            q = (cx - radius * math.cos(a), cy - radius * math.sin(a), cz)
        else:
            p = (cx, cy + radius * math.sin(a), cz + radius * math.cos(a))
            q = (cx, cy - radius * math.sin(a), cz - radius * math.cos(a))
        pieces.append(lath("spoke", p, q, width * 0.6, width * 0.6, mat))
    return pieces


def stooks(name, at_point, count, sheaf, band):
    """Sheaves stooked in a row."""
    pieces = []
    for index in range(count):
        x = at_point[0] + index * 0.035 - (count - 1) * 0.0175
        pieces.append(rings("sheaf", [(0.016, at_point[1]), (0.0, at_point[1] + 0.05)], 6, sheaf, centre=(x, at_point[2])))
        pieces.append(rings("tie", [(0.014, at_point[1] + 0.03), (0.016, at_point[1] + 0.032), (0.014, at_point[1] + 0.034)], 6, band,
                            centre=(x, at_point[2]), caps=(False, False)))
    return pieces
