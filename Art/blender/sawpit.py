"""The Sawpit, where the House's timber is sawn into boards, its five levels
the tiers of one file, each within a work's slot and facing +z:
1. a pit dug in the clearing, a log on trestles across it and the pit-saw
   rocking through it; logs waiting on their chocks, a chopping block with
   its axe;
2. the pit under an open shed of planks, boards stacked to dry on their
   sticks, the beetle and wedges by the logs;
3. a saw-house of timber under thatch, its frame saw driven by a horse
   walking a gin beside it, boards stacked by its door;
4. the saw-house on a stone footing under slate, a drying shed open on its
   sides, a timber wain loaded with planks, the saw-doctor's bench;
5. a sawmill of two storeys with a louvre on its ridge and a hoist beam
   over its loft door, a log pond for seasoning, the House's banner.
A dry-stone wall along the yard's front rises a course at each of the
first three levels; from the third a post-and-rail fence closes its back,
a gap left for the gate.
Close: sawdust trodden into the clearing and heaped under the saws, the
dogs holding the log, chips about the block, the sticks between the
boards, battens down the shed's roof and up the saw-house's front and
back, its rafters, courses and bargeboards, the louvre's vents, a lamp
hung in the shed.
The pit-saw rocks in its cut; from the third level the horse walks the
gin round and the frame saw's sash rises and falls; at the fifth a board
swings on the hoist.

    python Art/blender/sawpit.py Art/models/sawpit.glb
"""
import math
import os
import random
import sys

import bpy
import bmesh

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
earth = material("plain_earth", (0.24, 0.21, 0.18))
hole = material("plain_soot", (0.11, 0.1, 0.1))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
rock_grey = material("plain_stone_rock", (0.4, 0.4, 0.42))
slate = material("plain_slate", (0.23, 0.24, 0.28))
water = material("plain_water", (0.23, 0.24, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
bark = material("plain_timber_bark", (0.21, 0.17, 0.14))
linen = material("plain_linen", (0.7, 0.67, 0.6))
dun = material("plain_horse_dun", (0.52, 0.43, 0.31))
hair = material("plain_hair", (0.21, 0.17, 0.14))
harness = material("plain_leather_dark", (0.22, 0.16, 0.12))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.4, metallic=0.7)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
candle = material("glow_candle", (1.0, 0.8, 0.52))

# The packed ground's top: what lies on the ground is set down on it (the
# game's Sawpit laid its pit, chocks, sawdust, pond and track at nought,
# under the pad, where none of them showed).
G = 0.012
# How far what is laid flat on the ground stands proud of it.
FLAT = 0.0015

PITS = {1: (0.0, 0.0, -0.04), 2: (-0.03, 0.0, -0.06)}
HOUSE = (-0.06, 0.0, -0.1)
WIDTH, DEPTH = 0.24, 0.15
FRONT = HOUSE[2] + DEPTH / 2
# The frame saw stands before the saw door, the gin beside it.
DOOR = (HOUSE[0] + 0.05, 0.0, FRONT + 0.03)
GIN = (0.15, 0.0, 0.0)
HOIST = (HOUSE[0], 0.2, -0.026)


def pit_saw_pivot(level):
    x, _, z = PITS[level]
    return (x + 0.04, 0.135, z)


SASH_PIVOT = (DOOR[0], 0.15, DOOR[2] - 0.12)
HOIST_PIVOT = (HOIST[0], HOIST[1], HOIST[2] + 0.045)

parts = [("pit-saw@%d" % level, pit_saw_pivot(level), (0, 0, 1)) for level in (1, 2)]
for level in (3, 4, 5):
    parts += [("frame saw@%d" % level, SASH_PIVOT, (1, 0, 0)), ("gin@%d" % level, GIN, (0, 1, 0))]
parts.append(("hoist@5", HOIST_PIVOT, (1, 0, 0)))
rig = work_rig(parts)
ground(pad(tagged("pad", []), 0.31, loam), rig)

chance = random.Random(4243)


# MARK: Shapes the game's builder makes that the shared ones don't

def joined(name, pieces):
    """Pieces joined into one object so named."""
    if len(pieces) == 1:
        pieces[0].name = name
        return pieces[0]
    return join(name, pieces)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        joined(tagged(name, tags), list(far))
    if fine:
        joined(tagged(name + " close", tags) + "!fine", list(fine))


def moving(name, level, bone, pieces):
    """A level's moving part, its pieces joined and hung on its bone."""
    on(joined(tagged(name, level_tags([level])), pieces), rig, "%s@%d" % (bone, level))


def cbox(name, centre, size, mat, turn=0.0, chamfer=0.0):
    """A block about its middle, turned `turn` as the game turns a box (its
    own +x toward -z): MeshBuilder.box(center:size:turn:)."""
    (x, y, z), (w, h, d) = centre, size
    return block(name, (x - w / 2, y - h / 2, z - d / 2), (x + w / 2, y + h / 2, z + d / 2), mat, chamfer=chamfer, turn=-turn)


def beam(name, a, b, width, mat, depth=None):
    """A squared timber from one point to another, squared as the game
    squares one (MeshBuilder.beam): `width` across, level, if it lies, east
    to west if it stands, and `depth` through."""
    a, b = Vector(a), Vector(b)
    along = b - a
    length = along.length
    up = along / length
    reference = Vector((0, 0, 1)) if abs(up.y) > 0.95 else Vector((0, 1, 0))
    side = up.cross(reference).normalized()
    front = side.cross(up)
    d = width if depth is None else depth
    corners = [a + side * x + up * y + front * z for z in (-d / 2, d / 2) for y in (0.0, length) for x in (-width / 2, width / 2)]

    def build(bm):
        v = [bm.verts.new(at(*c)) for c in corners]
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            bm.faces.new([v[i] for i in f])
    return mesh_object(name, build, mat)


def limb(name, a, b, radius, mat, top=None, sides=4, caps=(False, False)):
    """A pole of `sides` faces from one point to another, narrowing to `top`,
    its ends left open for what it stands in to hide (MeshBuilder.limb)."""
    r0, r1 = radius * UNIT, (radius if top is None else top) * UNIT
    return loft(name, [(tuple(at(*a)), r0, r0, {}), (tuple(at(*b)), r1, r1, {})], segments=sides, mat=mat, caps=caps, smooth=False)


def heap(name, centre, size, seed, mat, sides=6, jitter=0.3):
    """A low heap of sawdust or earth sat on the ground at `centre`: the
    top of a rough lump `size` (its half-extents) across, up and through."""
    lot = random.Random(seed)
    cx, cy, cz = centre

    def build(bm):
        rim = []
        for side in range(sides):
            angle = 2 * math.pi * side / sides
            push = 1 + jitter * (2 * lot.random() - 1)
            rim.append(bm.verts.new(at(cx + math.cos(angle) * size[0] * push, cy - 0.0005, cz - math.sin(angle) * size[2] * push)))
        peak = bm.verts.new(at(cx, cy + size[1] * (1 + jitter * (2 * lot.random() - 1)), cz))
        for side in range(sides):
            bm.faces.new((rim[side], rim[(side + 1) % sides], peak))
    return mesh_object(name, build, mat)


def bottomless(obj):
    """A piece set down on what is under it, its underside (never seen)
    taken away."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    low = min(v.co.z for v in bm.verts)
    under = [f for f in bm.faces if f.normal.z < -0.99 and all(abs(v.co.z - low) < 1e-6 for v in f.verts)]
    bmesh.ops.delete(bm, geom=under, context="FACES_ONLY")
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def hoop(name, centre, radius, width, rim, spokes, sides=8):
    """A spoked wheel lying flat about an upright at `centre`: its rim a
    hoop `width` deep, two spokes crossing (the game's wheels were solid
    discs, their spokes hidden within)."""
    cx, cy, cz = centre
    inner = radius * 0.78
    low, high = cy - width / 2, cy + width / 2
    pieces = [rings(name, [(inner, low), (radius, low), (radius, high), (inner, high), (inner, low)], sides, rim, caps=(False, False),
                    centre=(cx, cz), twist=math.pi / sides)]
    reach, thick = inner + 0.002, width * 0.6
    pieces.append(block(name + " spoke", (cx - reach, cy - thick / 2, cz - 0.0025), (cx + reach, cy + thick / 2, cz + 0.0025), spokes))
    pieces.append(block(name + " spoke", (cx - 0.0025, cy - thick / 2, cz - reach), (cx + 0.0025, cy + thick / 2, cz + reach), spokes))
    return pieces


def cart_wheel(name, centre, radius, width, rim, spokes):
    """A spoked wheel standing on its axle along z (the game stood a wain's
    wheels across its way, on axles along x)."""
    pieces = hoop(name, (0.0, 0.0, 0.0), radius, width, rim, spokes)
    for obj in pieces:
        posed(obj, centre, (1, 0, 0), math.pi / 2)
    return pieces


def planks(name, at_point, length, layers, turn=0.0, depth=0.1):
    """A stack of sawn planks, each layer set over a little, pale and grey
    by turns (MeshBuilder.planks)."""
    pieces = []
    for layer in range(layers):
        y, shift = layer * 0.022, (layer % 2) * 0.01
        pieces.append(block(name, (-length / 2 + shift, y, -depth / 2), (length / 2 + shift, y + 0.02, depth / 2), pale if layer % 2 == 0 else grey))
    for obj in pieces:
        placed(obj, at_point, turn)
    return pieces


def sticks(at_point, layers, xs, turn=0.0):
    """The sticks laid between the layers of a stack of boards, for the air
    to dry them."""
    pieces = []
    for layer in range(1, layers):
        for x in xs:
            pieces.append(block("stick", (x - 0.003, layer * 0.022 - 0.003, -0.052), (x + 0.003, layer * 0.022 + 0.001, 0.052), dark))
    for obj in pieces:
        placed(obj, at_point, turn)
    return pieces


# MARK: What the yard holds

def boundary():
    """A dry-stone wall along the yard's front, a course higher at each of
    the first three levels, each stone laid along the wall a little askew
    (the game's turned its stones round the ring)."""
    for course in range(3):
        stones = []
        for index in range(18):
            angle = math.pi * (1.08 + 0.84 * index / 17) + (0.0 if course % 2 == 0 else 0.5 * 0.84 * math.pi / 18)
            centre = on_ring(0.295, 0.012 + course * 0.02, angle)
            shade = (stone, pale_stone, rock_grey)[(index + course) % 3]
            askew = 0.1 * (chance.random() - 0.5)
            stones.append(bottomless(cbox("stone", centre, (0.05, 0.019, 0.026), shade, turn=angle + math.pi / 2 + askew)))
        joined(tagged("wall", level_tags(range(course + 1, 6)) if course else []), stones)


def sawdust():
    """Sawdust trodden pale into the clearing."""
    heaps = []
    for index in range(7):
        centre = on_ring(0.08 + 0.025 * (index % 3), G, index * 2.1)
        heaps.append(heap("sawdust", centre, (0.022, 0.003, 0.018), 400 + index, pale))
    joined("sawdust!fine", heaps)


def fence(level):
    """A post-and-rail fence round the yard's back, a gap left for its gate."""
    posts = 4 + level
    gate = posts // 2
    pieces = []

    def foot(index):
        return on_ring(0.29, 0.0, math.pi * (0.15 + 0.7 * index / (posts - 1)))
    for index in range(posts):
        if index == gate:
            continue
        f = foot(index)
        pieces.append(limb("fence post", f, (f[0], 0.06, f[2]), 0.004, dark, caps=(False, True)))
        if index + 1 < posts and index + 1 != gate:
            n = foot(index + 1)
            for y in (0.025, 0.05):
                pieces.append(beam("rail", (f[0], y, f[2]), (n[0], y, n[2]), 0.004, timber))
    return pieces


def pit(level):
    """The saw pit: dug dark into the clearing, shored with planks, a log on
    trestles across it and the long saw standing through the log, which
    rocks in its cut (its own part); the dogs holding the log, near."""
    x0, _, z0 = PITS[level]
    far = [block("pit", (x0 - 0.13, -0.03, z0 - 0.04), (x0 + 0.13, G + FLAT, z0 + 0.04), hole)]
    for z in (-0.042, 0.042):
        far.append(block("shoring", (x0 - 0.135, 0.0, z0 + z - 0.004), (x0 + 0.135, G + 0.006, z0 + z + 0.004), dark))
    for x in (-0.135, 0.135):
        far.append(block("shoring", (x0 + x - 0.004, 0.0, z0 - 0.038), (x0 + x + 0.004, G + 0.006, z0 + 0.038), dark))
    for x in (-0.09, 0.09):
        for z in (-0.035, 0.035):
            far.append(limb("trestle leg", (x0 + x, 0.0, z0 + z), (x0 + x, 0.05, z0 + z), 0.005, dark))
        far.append(beam("trestle", (x0 + x, 0.05, z0 - 0.04), (x0 + x, 0.05, z0 + 0.04), 0.01, timber))
    far.append(log("pit log", (x0 - 0.15, 0.068, z0), (x0 + 0.15, 0.068, z0), 0.017, sides=7))
    saw = [block("pit-saw blade", (x0 + 0.034, -0.005, z0 - 0.001), (x0 + 0.046, 0.145, z0 + 0.001), steel),
           beam("tiller", (x0 + 0.02, 0.145, z0), (x0 + 0.06, 0.145, z0), 0.006, timber),
           beam("box handle", (x0 + 0.025, -0.005, z0), (x0 + 0.055, -0.005, z0), 0.006, timber)]
    moving("saw", level, "pit-saw", saw)
    fine = [rings("dog", [(0.0, 0.074), (0.004, 0.088)], 4, iron, centre=(x0 + x, z0)) for x in (-0.05, -0.03)]
    fine.append(heap("sawdust", (x0, G + FLAT, z0), (0.05, 0.008, 0.025), 411, pale))
    return far, fine


def logs(centre, count, turn=0.0):
    """Logs on their chocks, waiting for the saw: three to a row, two more
    laid in the hollows on them (the chocks only as long as the row)."""
    pieces = []
    rows = [(index, 0 if index < 3 else 1) for index in range(count)]
    bottom = [(index % 3 - 1) * 0.032 for index, row in rows if row == 0]
    middle, reach = (min(bottom) + max(bottom)) / 2, (max(bottom) - min(bottom)) / 2 + 0.017
    for x in (-0.05, 0.05):
        pieces.append(block("chock", (x - 0.006, 0.0, middle - reach), (x + 0.006, 0.012, middle + reach), dark))
    for index, row in rows:
        z = (index % 3 - 1) * 0.032 + row * 0.016
        y = 0.026 + row * 0.028
        pieces.append(log("log", (-0.08, y, z), (0.08, y, z), 0.015, sides=7))
    for obj in pieces:
        placed(obj, (centre[0], G, centre[2]), turn)
    return pieces


def chopping_block(centre):
    """A chopping block, an axe bitten into it, chips about it near."""
    x0, _, z0 = centre
    far = [rings("block", [(0.026, 0.0), (0.026, 0.04)], 7, bark, caps=(False, False), centre=(x0, z0)),
           rings("block top", [(0.026, 0.04), (0.0, 0.042)], 7, pale, caps=(False, False), centre=(x0, z0)),
           beam("axe haft", (x0, 0.045, z0), (x0 + 0.04, 0.09, z0 + 0.01), 0.005, timber),
           cbox("axe head", (x0 - 0.002, 0.046, z0), (0.022, 0.016, 0.004), steel)]
    fine = []
    for index in range(3):
        x, _, z = on_ring(0.045, 0.0, index * 1.4, (x0, z0))
        fine.append(cbox("chip", (x, G + 0.003, z), (0.02, 0.006, 0.008), pale, turn=index))
    return far, fine


def beetle(centre):
    """The beetle stood on its head, its haft on the ground, two iron wedges
    by it."""
    pieces = [rings("beetle", [(0.016, 0.0), (0.016, 0.045)], 6, dark, caps=(False, True)),
              beam("beetle haft", (0.0, 0.022, 0.0), (0.08, G + 0.003, 0.0), 0.006, timber)]
    for x in (0.03, 0.045):
        pieces.append(cbox("wedge", (x, G + 0.004, 0.03), (0.008, 0.008, 0.02), iron))
    for obj in pieces:
        placed(obj, centre, 0.4)
    return pieces


def open_shed(level):
    """An open shed of planks over the pit on six posts: tie beams across,
    battens down its front slope and a lamp hung under it, near."""
    x0, _, z0 = PITS[level]
    far, fine = [], []
    for x in (-0.15, 0.0, 0.15):
        for z in (-0.08, 0.08):
            far.append(limb("shed post", (x0 + x, 0.0, z0 + z), (x0 + x, 0.179, z0 + z), 0.007, dark))
        far.append(beam("tie beam", (x0 + x, 0.179, z0 - 0.09), (x0 + x, 0.179, z0 + 0.09), 0.01, timber))
    far.append(gable_roof("shed roof", (x0, z0), 0.2, 0.34, 0.19, 0.06, grey, overhang=0.01, along="x", thickness=0.006))
    # Battens down the front slope, lying on it.
    normal = Vector((0.0, 0.11, 0.06)).normalized()
    for index in range(9):
        x = x0 - 0.16 + 0.04 * index
        low = Vector((x, 0.19, z0 + 0.11)) + normal * 0.002
        high = Vector((x, 0.25, z0)) + normal * 0.002
        fine.append(beam("batten", tuple(low), tuple(high), 0.004, dark))
    fine.append(block("lamp", (x0 - 0.006, 0.152, z0 + 0.074), (x0 + 0.006, 0.168, z0 + 0.086), candle))
    fine.append(limb("lamp cord", (x0, 0.168, z0 + 0.08), (x0, 0.175, z0 + 0.08), 0.0012, linen, sides=3))
    return far, fine


def boards(centre, layers, turn):
    """Boards stacked to dry, a stick between each layer, near."""
    base = (centre[0], G, centre[2])
    return planks("boards", base, 0.13, layers, turn), sticks(base, layers, (-0.045, 0.045), turn)


def saw_house(level):
    """The saw-house: timber, or timber on stone, its saw door wide open on
    the frame saw, whose sash rises and falls on the log fed through (its
    own part); battens up its front and back, near. At the fifth level a
    second storey, a loft door and a louvre on the ridge."""
    stone_built, storeys = level >= 4, (2 if level == 5 else 1)
    height = 0.22 if storeys == 2 else 0.14
    x0, _, z0 = HOUSE
    body, close = hall("saw-house", WIDTH, DEPTH, height, timber, slate if stone_built else thatch, dark, pitch=0.7)
    for obj in body + close:
        placed(obj, HOUSE)
    far, fine = list(body), list(close)
    w, d = WIDTH / 2, DEPTH / 2
    if stone_built:
        far.append(block("footing", (x0 - w - 0.012, -0.08, z0 - d - 0.012), (x0 + w + 0.012, 0.04, z0 + d + 0.012), dark_stone, chamfer=0.004))
    far.append(block("saw door", (x0 + 0.015, 0.0, FRONT), (x0 + 0.085, 0.1, FRONT + 0.004), hole))
    far.append(lit("window", (x0 - 0.07, 0.08, FRONT + 0.002), 0.022, 0.026, 0.0, candle))
    openings = [(0.015, 0.085, 0.0, 0.1)]
    if storeys == 2:
        far.append(lit("loft window", (x0 - 0.07, 0.17, FRONT + 0.002), 0.02, 0.024, 0.0, candle))
        far.append(block("loft door", (x0 - 0.02, 0.14, FRONT), (x0 + 0.02, 0.19, FRONT + 0.004), dark))
        openings.append((-0.02, 0.02, 0.14, 0.19))
        ridge = height + DEPTH * 0.7
        far.append(block("louvre", (x0 - 0.018, ridge - 0.025, z0 - 0.018), (x0 + 0.018, ridge + 0.02, z0 + 0.018), grey))
        far.append(hip_roof("louvre roof", (x0, z0), 0.036, 0.036, ridge + 0.02, 0.022, slate, overhang=0.006, thickness=0.004))
        for z in (-0.018, 0.018):
            fine.append(block("louvre vent", (x0 - 0.012, ridge - 0.004, z0 + z - 0.001), (x0 + 0.012, ridge + 0.014, z0 + z + 0.001), dark))
    # Battens up the front, broken where a door opens, and up the back.
    foot = 0.04 if stone_built else 0.0
    for x in (-0.11, -0.05, 0.01, 0.07):
        runs = [(foot, height)]
        for left, right, low, high in openings:
            if left < x + 0.003 and x - 0.003 < right:
                runs = [(a, b) for start, end in runs for a, b in ((start, min(end, low)), (max(start, high), end)) if b - a > 0.004]
        for low, high in runs:
            fine.append(block("batten", (x0 + x - 0.003, low, FRONT), (x0 + x + 0.003, high, FRONT + 0.006), dark))
    back = HOUSE[2] - DEPTH / 2
    for x in (-0.09, -0.03, 0.03, 0.09):
        fine.append(block("batten", (x0 + x - 0.003, foot, back - 0.006), (x0 + x + 0.003, height, back), dark))
    # The frame saw: its frame on two posts before the door, the log fed
    # through on the ground, the sash with its blade riding between them.
    dx, _, dz = DOOR
    for x in (-0.03, 0.03):
        far.append(limb("frame post", (dx + x, 0.0, dz), (dx + x, 0.13, dz), 0.006, dark))
    far.append(beam("frame head", (dx - 0.035, 0.13, dz), (dx + 0.035, 0.13, dz), 0.008, dark))
    far.append(log("frame log", (dx, G + 0.016, dz - 0.05), (dx, G + 0.016, dz + 0.09), 0.016, sides=7))
    sash = [cbox("sash rail", (dx, 0.07, dz), (0.05, 0.008, 0.008), timber),
            cbox("sash rail", (dx, 0.115, dz), (0.05, 0.008, 0.008), timber),
            # The blade down into the log it saws (the game's stopped short of it).
            cbox("frame saw blade", (dx, 0.081, dz), (0.003, 0.072, 0.004), steel),
            # The pitman out to the gin, before the post it passes.
            beam("pitman", (dx + 0.02, 0.11, dz + 0.009), (dx + 0.1, 0.06, dz + 0.009), 0.005, dark)]
    moving("sash", level, "frame saw", sash)
    fine.append(heap("sawdust", (dx + 0.02, G, dz + 0.04), (0.03, 0.006, 0.022), 431, pale))
    return far, fine


def horse(at_point, turn):
    """A dun horse in harness, made facing -x as the game's are."""
    pieces = [loft("horse", [(tuple(at(-0.026, 0.05, 0.0)), 0.011 * UNIT, 0.012 * UNIT, {}),
                             (tuple(at(0.0, 0.051, 0.0)), 0.013 * UNIT, 0.014 * UNIT, {}),
                             (tuple(at(0.025, 0.052, 0.0)), 0.012 * UNIT, 0.013 * UNIT, {})], segments=6, mat=dun, smooth=False)]
    for x, z in ((-0.02, -0.007), (-0.02, 0.007), (0.019, -0.007), (0.019, 0.007)):
        pieces.append(limb("leg", (x, 0.045, z), (x, 0.0, z), 0.0035, dun))
    pieces.append(limb("neck", (-0.022, 0.056, 0.0), (-0.038, 0.078, 0.0), 0.0075, dun, top=0.0055))
    pieces.append(limb("head", (-0.035, 0.081, 0.0), (-0.057, 0.067, 0.0), 0.006, dun, top=0.004, caps=(False, True)))
    pieces.append(limb("tail", (0.026, 0.058, 0.0), (0.033, 0.028, 0.0), 0.003, hair, top=0.0015))
    pieces.append(cbox("saddle", (0.0, 0.066, 0.0), (0.02, 0.004, 0.03), harness))
    for obj in pieces:
        placed(obj, at_point, turn)
    return pieces


def gin(level):
    """The horse gin that drives the saw: an upright with its crown wheel
    and a sweep, the horse walking its trodden ring (its own part), the
    drive shaft out from the wheel to the saw-house."""
    gx, _, gz = GIN
    far = [rings("track", [(0.1, G + 0.0008), (0.085, G + 0.0016)], 14, earth, caps=(False, False), centre=(gx, gz)),
           beam("drive shaft", (gx - 0.028, 0.112, gz), (0.0, 0.112, gz - 0.03), 0.008, dark)]
    towards = (Vector((0.0, 0.112, gz - 0.03)) - Vector((gx - 0.028, 0.112, gz))).normalized()
    start = Vector((gx - 0.034, 0.112, gz)) - towards * 0.002
    far.append(rod("pinion", tuple(start), tuple(start + towards * 0.012), 0.008, timber, sides=6))
    works = [limb("upright", (gx, 0.0, gz), (gx, 0.122, gz), 0.01, dark, sides=6, caps=(False, True))]
    works += hoop("crown wheel", (gx, 0.1, gz), 0.035, 0.008, dark, timber)
    works.append(beam("sweep", (gx, 0.084, gz), (gx + 0.088, 0.07, gz), 0.01, timber))
    # Facing the way it walks as the gin turns (the game's walked backward).
    works += horse((gx + 0.092, G, gz), -math.pi / 2)
    moving("gin works", level, "gin", works)
    return far


def drying_shed(centre):
    """A drying shed open on its sides, boards racked under its roof on
    their sticks."""
    x0, _, z0 = centre
    far = [limb("shed post", (x0 + x, 0.0, z0 + z), (x0 + x, 0.13, z0 + z), 0.006, dark) for x in (-0.08, 0.08) for z in (-0.05, 0.05)]
    far.append(gable_roof("drying roof", (x0, z0), 0.12, 0.19, 0.13, 0.045, slate, overhang=0.008, along="x", thickness=0.006))
    base = (x0, G, z0)
    far += planks("racked boards", base, 0.15, 4)
    return far, sticks(base, 4, (-0.05, 0.05))


def wain(at_point, turn):
    """A timber wain loaded with planks: its bed, four wheels on their axles
    and its pole down to the ground."""
    pieces = [block("wain bed", (-0.06, 0.028, -0.03), (0.06, 0.036, 0.03), pale)]
    for x in (-0.04, 0.04):
        pieces.append(block("axle", (x - 0.003, 0.019, -0.037), (x + 0.003, 0.025, 0.037), dark))
        for z in (-0.034, 0.034):
            pieces += cart_wheel("wheel", (x, 0.022, z), 0.022, 0.005, dark, timber)
    pieces += planks("load", (0.0, 0.036, 0.0), 0.12, 2, depth=0.056)
    pieces.append(beam("wain pole", (0.06, 0.03, 0.0), (0.12, 0.003, 0.0), 0.005, dark))
    for obj in pieces:
        placed(obj, (at_point[0], G, at_point[2]), turn)
    return pieces


def hoist(level):
    """The hoist beam out over the loft door, a board slung on its rope
    swinging (its own part), hung higher than the game's, clear of the
    frame saw's head."""
    x, y, z = HOIST
    px, py, pz = HOIST_PIVOT
    far = [beam("hoist beam", (x, y, z - 0.03), (x, y, z + 0.05), 0.01, dark)]
    load = [limb("hoist rope", (px, py, pz), (px, py - 0.05, pz), 0.0015, linen, sides=3),
            cbox("hoisted board", (px, py - 0.055, pz), (0.08, 0.006, 0.02), pale)]
    moving("hoist load", level, "hoist", load)
    return far


def pond(centre):
    """A pond where logs season, two afloat in it."""
    x0, _, z0 = centre
    surface = G + FLAT
    far = [rings("pond", [(0.06, G - 0.001), (0.055, surface), (0.0, surface)], 10, water, caps=(False, False), centre=(x0, z0))]
    for index, z in enumerate((-0.025, 0.01)):
        far.append(log("floating log", (x0 - 0.035, surface + 0.002, z0 + z), (x0 + 0.035 - index * 0.01, surface + 0.002, z0 + z + 0.01), 0.008,
                       sides=6))
    return far


def bench(centre, turn):
    """The saw-doctor's bench: a trestle bench, a saw blade clamped in its
    vice for sharpening, a file laid by it."""
    pieces = [cbox("bench top", (0.0, 0.05, 0.0), (0.09, 0.008, 0.035), pale)]
    for x in (-0.035, 0.035):
        for z in (-0.013, 0.013):
            pieces.append(limb("bench leg", (x, 0.0, z), (x * 0.9, 0.048, z * 0.9), 0.003, dark))
    pieces.append(cbox("vice", (-0.03, 0.07, 0.0), (0.012, 0.03, 0.03), dark))
    pieces.append(cbox("blade", (0.005, 0.075, 0.0), (0.08, 0.016, 0.002), steel))
    pieces.append(cbox("file", (0.02, 0.056, 0.01), (0.03, 0.003, 0.004), iron))
    for obj in pieces:
        placed(obj, centre, turn)
    return pieces


def house_banner(level):
    """The House's banner on its pole above the sawmill's gable."""
    foot, height = (0.06, 0.28, -0.1), 0.12
    pole = limb("banner pole", foot, (foot[0], foot[1] + height, foot[2]), 0.009, dark, caps=(False, True))
    flag(tagged("banner", level_tags([level])), (foot[0], foot[1] + height - 0.01, foot[2]), 0.05, 0.07, banner, turn=math.pi / 2)
    return [pole]


# MARK: The levels
# Laid out as the game's Sawpit lays them, nudged where a piece ran into
# another, through the wall or off the ground: the logs kept off the
# saw-house and the shed's posts, the wain's pole inside the wall, and the
# bench, squeezed against the wall by the wain, set by the fence behind.

boundary()
sawdust()

far, fine = pit(1)
block_far, block_fine = chopping_block((0.18, 0.0, 0.14))
piece("sawpit", [1], far + logs((-0.15, 0.0, 0.115), 3) + block_far + logs((0.13, 0.0, -0.14), 2), fine + block_fine)

far, fine = pit(2)
shed, shed_close = open_shed(2)
stack, stack_close = boards((0.176, 0.0, 0.07), 4, 0.2)
block_far, block_fine = chopping_block((0.19, 0.0, -0.14))
piece("sawpit", [2], far + shed + stack + logs((-0.14, 0.0, 0.11), 4) + beetle((0.02, 0.0, 0.17)) + block_far,
      fine + shed_close + stack_close + block_fine)

far, fine = saw_house(3)
stack, stack_close = boards((-0.12, 0.0, 0.12), 4, 0.0)
block_far, block_fine = chopping_block((0.02, 0.0, 0.18))
piece("sawpit", [3], far + fence(3) + gin(3) + stack + logs((-0.237, 0.0, -0.02), 4, math.pi / 2) + block_far, fine + stack_close + block_fine)

far, fine = saw_house(4)
shed, shed_close = drying_shed((-0.12, 0.0, 0.13))
block_far, block_fine = chopping_block((-0.01, 0.0, 0.22))
piece("sawpit", [4], far + fence(4) + gin(4) + shed + wain((0.085, 0.0, 0.168), -0.15) + logs((-0.237, 0.0, -0.02), 4, math.pi / 2)
      + bench((0.13, 0.0, -0.17), -0.7) + block_far, fine + shed_close + block_fine)

far, fine = saw_house(5)
shed, shed_close = drying_shed((-0.145, 0.0, 0.105))
piece("sawpit", [5], far + fence(5) + gin(5) + hoist(5) + shed + wain((0.135, 0.0, 0.185), 0.6) + pond((-0.23, 0.0, -0.04))
      + bench((0.13, 0.0, -0.17), -0.7) + logs((-0.02, 0.0, 0.212), 5) + house_banner(5), fine + shed_close)

# Its saws at work: the pit-saw rocking in its cut, the horse walking the
# gin round, the frame saw's sash rising and falling, a board swinging on
# the hoist (Machinery's swings and wheel in the game).
turns = [("pit-saw@%d" % level, (0, 0, 1), lambda u: 0.12 * swing(u)) for level in (1, 2)]
for level in (3, 4, 5):
    turns += [("frame saw@%d" % level, (1, 0, 0), lambda u: 0.1 * swing(u)), ("gin@%d" % level, (0, 1, 0), wheel_turns(1))]
turns.append(("hoist@5", (1, 0, 0), lambda u: 0.15 * swing(u)))
idle(rig, turns=turns)

finish_building(out_path("Art/models/sawpit.glb"), [str(level) for level in LEVELS])
