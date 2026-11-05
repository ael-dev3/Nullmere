"""The Infirmary, where the House's fallen companies are carried and healed,
its five levels the tiers of one file, each within a work's slot and facing
+z (Sources/NullmereModels/Infirmary.swift is the design it was ported from):
1. a long tent of canvas on its poles and guy ropes, cots within seen
   through its open end, the healers' flag on its front pole, their fire in
   the open under a kettle hung from its tripod;
2. a timber ward under thatch, its chimney smoking, a garden of herbs in
   raised beds before it;
3. the ward rebuilt in white stone under slate on a footing, a round
   bath-house of stone beside it with its copper, a lantern walk to the
   door;
4. a cloister: the ward and a second wing about a court, the wing's walk
   roofed on pillars, a physic garden at its heart, beds laid out to air;
5. the great hospice, buttressed, its hall crowned with a dome on a drum
   lit by windows (raised clear of the ridge) and a lantern of moonsalt,
   the healers' bell in its cote.
At every level the well and its windlass, a bucket on the rope, and the
yard's dry-stone wall round its front, a course higher as it grows, its
ends stepped and stopping short of the wing.
Close: petals fallen about the yard, the roofs' courses, gable boards,
vents and rafters, the chimney's cap, the healers' sign over the door, the
bath-house's bands, roof ring and finial, the lanterns' caps, the drum's
cornice.
The well's windlass turns as water is drawn for the ward.

    python Art/blender/infirmary.py Art/models/infirmary.glb
"""
import math
import os
import sys

import bpy
import bmesh

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

yard = material("plain_earth_yard", (0.31, 0.29, 0.25))
loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
white = material("plain_stone_white", (0.84, 0.84, 0.82))
rough = material("plain_stone_rock", (0.4, 0.4, 0.42))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
linen = material("plain_linen", (0.7, 0.67, 0.6))
# Not among the buildings' shared colours: the herbs' moss green, the
# paler green of every other bed (moss a third of the way to weld), and the
# water in the well and the copper (sea wool's grey-blue).
moss = material("plain_moss", (0.21, 0.26, 0.22))
herb = material("plain_moss_weld", (0.312, 0.329, 0.235))
water = material("plain_seawool", (0.27, 0.33, 0.38))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
bronze = material("metal_bronze", (0.55, 0.43, 0.26), roughness=0.4, metallic=0.7)
window = material("glow_candle", (1.0, 0.8, 0.52))
fire = material("glow_fire", (1.0, 0.68, 0.32))
# The hospice's lantern of moonsalt, lit; the healers' flag of linen.
moonlight = material("glow_moonsalt", (0.88, 0.91, 0.95))
pennant = material("cloth_linen", (0.7, 0.67, 0.6))

# The well, at every level, and its windlass's drum, turning about the x
# axis.
WELL = (0.2, 0.0, 0.12)
DRUM = (WELL[0], 0.085, WELL[2])
rig = work_rig([("well windlass@%d" % level, DRUM, (1, 0, 0)) for level in LEVELS])
ground(pad(tagged("pad", []), 0.31, yard), rig)

# Where each level's ward smokes: the middle of its chimney stack's top,
# exactly where the game sends its smoke up (Infirmary.chimney(level)).
CHIMNEYS = {2: (0.05, 0.22, -0.135), 3: (0.05, 0.22, -0.135), 4: (0.08, 0.22, -0.175), 5: (0.09, 0.24, -0.16)}

# Where the cloister's wing stands at the fourth and fifth levels.
WING = {4: (-0.19, 0.0, 0.04), 5: (-0.2, 0.0, 0.05)}


def footprint(level):
    """The wing's footing on the ground (x0, z0, x1, z1), the yard's wall
    stopping short of it: its lip kept narrow on the side away from the
    court and at its front end, so its corner stays within the pad."""
    x, _, z = WING[level]
    return (x - 0.051, z - 0.112, x + 0.057, z + 0.106)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


# MARK: Shapes

def box(name, centre, size, mat, turn=0.0):
    """A block `size` about `centre`, turned `turn` as block() turns."""
    x, y, z = centre
    sx, sy, sz = size
    return block(name, (x - sx / 2, y - sy / 2, z - sz / 2), (x + sx / 2, y + sy / 2, z + sz / 2), mat, turn=turn)


def ball(name, centre, radius, sides, bands, mat, squash=1.0, twist=0.0):
    """A faceted ball about `centre`, `bands` from pole to pole, its height
    `squash` times its breadth."""
    x, y, z = centre
    sections = []
    for band in range(bands + 1):
        angle = math.pi * band / bands - math.pi / 2
        r = 0.0 if band in (0, bands) else radius * math.cos(angle)
        sections.append((r, y + radius * squash * math.sin(angle)))
    return rings(name, sections, sides, mat, centre=(x, z), twist=twist)


def flat(name, centre, size, turn, mat):
    """A little square lying face up on the ground, turned `turn` from +x
    toward +z: its upper face alone, all that is ever seen of it."""
    x, y, z = centre
    c, s, h = math.cos(turn), math.sin(turn), size / 2
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new(at(x + u * c - v * s, y, z + u * s + v * c)) for u, v in ((-h, -h), (h, -h), (h, h), (-h, h))])
    face.normal_update()
    if face.normal.z < 0:
        face.normal_flip()
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    return obj


def watered(obj, height):
    """The piece's flat top at `height` made water."""
    obj.data.materials.append(water)
    index = len(obj.data.materials) - 1
    for poly in obj.data.polygons:
        if poly.normal.z > 0.99 and abs(poly.center.z - height * UNIT) < 1e-4:
            poly.material_index = index
    return obj


# MARK: What every level has

def well():
    """The well head of stone, its water dark within, the posts and the
    little slate roof of its windlass, the rope down from the drum to the
    bucket over the water."""
    x0, _, z0 = WELL
    head = rings("well head", [(0.03, -0.004), (0.03, 0.04), (0.034, 0.045), (0.022, 0.045), (0.022, 0.034)], 10, stone, caps=(False, True),
                 centre=(x0, z0))
    pieces = [watered(head, 0.034)]
    for dx in (-0.03, 0.03):
        pieces.append(rod("well post", (x0 + dx, 0.04, z0), (x0 + dx, 0.1, z0), 0.004, dark, sides=4))
    pieces.append(gable_roof("well roof", (x0, z0), 0.05, 0.075, 0.104, 0.03, slate, overhang=0.006, along="x", thickness=0.004))
    pieces.append(rod("well rope", (x0, 0.078, z0), (x0, 0.061, z0), 0.0012, linen, sides=3))
    pieces.append(rings("well bucket", [(0.0062, 0.05), (0.0075, 0.063)], 6, timber, centre=(x0, z0)))
    return pieces


def windlass(level):
    """The windlass's drum on its iron axle through the posts, its crank
    at the end: the level's own, turning on its bone."""
    x0, y0, z0 = DRUM
    pieces = [rod("drum", (x0 - 0.028, y0, z0), (x0 + 0.028, y0, z0), 0.008, timber, sides=8),
              rod("axle", (x0 - 0.036, y0, z0), (x0 + 0.04, y0, z0), 0.0022, iron, sides=4),
              lath("crank", (x0 + 0.038, y0 - 0.002, z0), (x0 + 0.038, y0 + 0.012, z0), 0.003, 0.003, iron),
              rod("crank handle", (x0 + 0.038, y0 + 0.012, z0), (x0 + 0.049, y0 + 0.012, z0), 0.0018, timber, sides=4)]
    on(join(tagged("windlass", level_tags([level])), pieces), rig, "well windlass@%d" % level)


def stone_clear(x, z, angle, boxes, margin=0.003):
    """Whether a wall stone laid at (x, z) along its arc at `angle` stands
    clear of every box (x0, z0, x1, z1) on the ground."""
    tx, tz = -math.sin(angle), -math.cos(angle)
    rx, rz = math.cos(angle), -math.sin(angle)
    for x0, z0, x1, z1 in boxes:
        for u in (-0.025, -0.0125, 0.0, 0.0125, 0.025):
            for v in (-0.013, 0.0, 0.013):
                px, pz = x + u * tx + v * rx, z + u * tz + v * rz
                if x0 - margin <= px <= x1 + margin and z0 - margin <= pz <= z1 + margin:
                    return False
    return True


def boundary(courses, clear=()):
    """A dry-stone wall round the front of the yard, `courses` high, each
    stone laid along its arc by hand (Lodge.boundary in the game); every
    stone of a course above resting on two below, so its ends step back.
    Where its west end comes to a building (`clear`) the whole wall stops
    short of it: no course begins before the last stone of any course that
    would stand in it."""
    count = 18

    def angle(course, index):
        return math.pi * (1.08 + 0.84 * index / (count - 1)) + (0.5 * 0.84 * math.pi / count if course % 2 else 0.0)

    first = 0
    for course in range(courses):
        for index in range(count):
            x, _, z = on_ring(0.295, 0.0, angle(course, index))
            if not stone_clear(x, z, angle(course, index), clear):
                first = max(first, index + 1)
    stones = []
    last = count - 1
    for course in range(courses):
        if course % 2:
            last -= 1
        elif course:
            first += 1
        for index in range(first, last + 1):
            a = angle(course, index)
            x, y, z = on_ring(0.295, 0.012 + course * 0.02, a)
            shade = (index + course) % 3
            stones.append(block("field stone", (x - 0.025, y - 0.0095, z - 0.013), (x + 0.025, y + 0.0095, z + 0.013),
                                (stone, pale_stone, rough)[shade], turn=-a - math.pi / 2))
    return stones


def petals():
    """Fallen petals of the physic garden about the yard."""
    pieces = []
    for index in range(16):
        angle = index * 2.39996
        r = 0.08 + 0.18 * ((index * 13) % 11) / 11
        pieces.append(flat("petal", (r * math.cos(angle), 0.0135, r * math.sin(angle)), 0.008, angle, linen if index % 3 == 0 else moss))
    return pieces


# MARK: The infirmary's buildings

def tent(at_point):
    """A long tent of canvas on three poles, its back laced shut, the cots
    within seen through its open front, the healers' linen flag on the
    front pole; near, its guy ropes pegged out ahead and behind."""
    x0, _, z0 = at_point
    w, d, h = 0.11, 0.2, 0.1
    front, back = z0 + d / 2, z0 - d / 2
    far = [slab("tent canvas", [(x0 - w, 0.0, back), (x0 - w, 0.0, front), (x0, h, front), (x0, h, back)], canvas, 0.004, normal=(-1, 1, 0)),
           slab("tent canvas", [(x0 + w, 0.0, front), (x0 + w, 0.0, back), (x0, h, back), (x0, h, front)], canvas, 0.004, normal=(1, 1, 0)),
           slab("tent back", [(x0 - w + 0.004, 0.0, back), (x0 + w - 0.004, 0.0, back), (x0, h - 0.004, back)], canvas, 0.004,
                normal=(0, 0, -1))]
    for z in (back, z0, front):
        far.append(rod("tent pole", (x0, 0.0, z), (x0, h + 0.01, z), 0.004, dark, sides=4))
    for index in range(3):
        z = z0 - 0.06 + index * 0.06
        for side in (-1, 1):
            cx = x0 + side * 0.05
            far.append(block("cot", (cx - 0.02, 0.008, z - 0.0125), (cx + 0.02, 0.02, z + 0.0125), timber))
            far.append(block("cot bedding", (cx - 0.018, 0.019, z - 0.011), (cx + 0.018, 0.026, z + 0.011), linen))
    flag(tagged("healers flag", ["1"]), (x0, h + 0.01, front), 0.03, 0.022, pennant, turn=0.4)
    fine = []
    for z, out in ((front, 1), (back, -1)):
        for side in (-1, 1):
            fine.append(rod("guy rope", (x0, h + 0.006, z), (x0 + side * 0.03, 0.012, z + out * 0.05), 0.0009, linen, sides=3))
            fine.append(rod("tent peg", (x0 + side * 0.03, 0.006, z + out * 0.05), (x0 + side * 0.03, 0.018, z + out * 0.05), 0.0018, timber,
                            sides=3))
    return far, fine


def hearth(at_point, spin=0.0):
    """The healers' fire in the open in its ring of stones, a kettle hung
    over it on a chain from a tripod (turned `spin` to keep its legs clear
    of what stands near)."""
    x0, _, z0 = at_point
    far = []
    for index in range(6):
        angle = index / 6 * 2 * math.pi
        far.append(rock("hearth stone", (x0 + 0.025 * math.cos(angle), 0.012, z0 + 0.025 * math.sin(angle)), (0.012, 0.01, 0.012), index + 600,
                        dark_stone))
    far.append(rings("fire", [(0.015, 0.008), (0.0, 0.038)], 5, fire, centre=(x0, z0)))
    for angle in (0.3 + spin, 2.4 + spin, 4.5 + spin):
        far.append(rod("tripod leg", (x0 + 0.04 * math.cos(angle), 0.0, z0 + 0.04 * math.sin(angle)), (x0, 0.08, z0), 0.0025, dark, sides=4))
    far.append(rod("kettle chain", (x0, 0.081, z0), (x0, 0.059, z0), 0.001, iron, sides=3))
    far.append(rings("kettle", [(0.012, 0.035), (0.018, 0.045), (0.015, 0.06)], 8, iron, centre=(x0, z0)))
    return far


def ward(at_point, stone_built, width, flue):
    """The ward: a long hall, timber under thatch or white stone under
    slate on a footing of stone, its door, its windows lit and its stone
    chimney, the middle of its stack's top at `flue`; near, the chimney's
    cap and the healers' sign, a cross of linen over the door (on it, where
    the thatch comes down low)."""
    x0, _, z0 = at_point
    depth, height = 0.12, (0.12 if stone_built else 0.1)
    body, close = hall("ward", width, depth, height, white if stone_built else pale, slate if stone_built else thatch, dark, pitch=0.65,
                       eaves=0.01 if stone_built else 0.014)
    for obj in body + close:
        placed(obj, at_point)
    far, fine = list(body), list(close)
    front = z0 + depth / 2
    if stone_built:
        far.append(block("footing", (x0 - width / 2 - 0.012, -0.08, z0 - depth / 2 - 0.012), (x0 + width / 2 + 0.012, 0.04, front + 0.012), stone,
                         chamfer=0.004))
    # The door stands a little proud of the footing's face, as of the wall's.
    door = front + (0.016 if stone_built else 0.012)
    far.append(block("door", (x0 - 0.0175, 0.0075, front - 0.008), (x0 + 0.0175, 0.0825, door), dark))
    for k in range(8):
        x = -width / 2 + 0.035 + 0.05 * k
        if x >= width / 2 - 0.02:
            break
        if abs(x) > 0.03:
            far.append(lit("window", (x0 + x, height * 0.6, front + 0.002), 0.016, 0.028, 0.0, window))
    fx, top, fz = flue
    far.append(block("chimney", (fx - 0.015, height - 0.01, fz - 0.015), (fx + 0.015, top, fz + 0.015), dark_stone))
    fine.append(block("chimney cap", (fx - 0.019, top, fz - 0.019), (fx + 0.019, top + 0.01, fz + 0.019), stone))
    if stone_built:
        fine.append(block("sign", (x0 - 0.015, 0.089, front + 0.0035), (x0 + 0.015, 0.111, front + 0.0065), dark))
        cross = (x0, 0.1, front + 0.007)
    else:
        cross = (x0, 0.062, door + 0.0005)
    fine.append(box("sign cross", cross, (0.004, 0.016, 0.002), linen))
    fine.append(box("sign cross", cross, (0.016, 0.004, 0.002), linen))
    return far, fine


def wing(level):
    """The level's second wing of the cloister in white stone under slate,
    turned to face the court, its windows lit; the walk before it roofed in
    slate on pillars."""
    at_point = WING[level]
    x0, _, z0 = at_point
    body, close = hall("wing", 0.2, 0.09, 0.1, white, slate, dark, pitch=0.65)
    for obj in body + close:
        placed(obj, at_point, math.pi / 2)
    far, fine = list(body), list(close)
    fx0, fz0, fx1, fz1 = footprint(level)
    far.append(block("footing", (fx0, -0.08, fz0), (fx1, 0.04, fz1), stone, chamfer=0.004))
    for z in (-0.06, 0.0, 0.06):
        far.append(lit("window", (x0 + 0.046, 0.06, z0 + z), 0.014, 0.024, math.pi / 2, window))
        far.append(rod("pillar", (x0 + 0.065, 0.0, z0 + z + 0.03), (x0 + 0.065, 0.081, z0 + z + 0.03), 0.004, pale_stone, sides=6))
    # The walk's roof stops a little short of the ward, clear of its windows.
    far.append(block("walk roof", (x0 + 0.045, 0.08, z0 - 0.094), (x0 + 0.075, 0.088, z0 + 0.1), slate))
    return far, fine


HERBS = ((-0.015, -0.01), (0.0, 0.008), (0.015, -0.006), (-0.008, 0.012), (0.012, 0.012))
# Each clump of a bed its own height and turn, so they grow unevenly.
GROWTH = ((1.0, 0.0), (1.3, 0.7), (0.85, 1.9), (1.15, 2.6), (0.95, 3.8))


def herbs(at_point, beds):
    """Raised beds of herbs, low timber borders full of loam and green."""
    x0, _, z0 = at_point
    far = []
    for index in range(beds):
        px = x0 + index * 0.07 - (beds - 1) * 0.035
        far.append(block("bed", (px - 0.03, 0.0, z0 - 0.025), (px + 0.03, 0.02, z0 + 0.025), dark))
        far.append(block("loam", (px - 0.026, 0.018, z0 - 0.021), (px + 0.026, 0.024, z0 + 0.021), loam))
        for (dx, dz), (squash, twist) in zip(HERBS, GROWTH):
            far.append(ball("herb", (px + dx, 0.022 + 0.008 * squash, z0 + dz), 0.008, 5, 2, moss if index % 2 == 0 else herb, squash=squash,
                            twist=twist + index))
    return far


def bath_house(at_point):
    """A round bath-house of pale stone under a cone of slate, its door to
    the court and its copper steaming beside it; near, the bands about its
    wall, the ring round its roof and its finial."""
    x0, _, z0 = at_point
    radius, height, rise, sides = 0.045, 0.07, 0.05, 10
    eave = radius * 1.18
    copper = rings("copper", [(0.016, 0.004), (0.02, 0.02), (0.018, 0.03), (0.015, 0.026)], 8, bronze, caps=(False, True),
                   centre=(x0 + 0.06, z0 - 0.04))
    far = [rings("bath-house", [(radius, -0.06), (radius, height)], sides, pale_stone, caps=(False, False), centre=(x0, z0)),
           rings("bath-house roof", [(eave, height - 0.006), (eave, height), (0.0, height + rise)], sides, slate, centre=(x0, z0)),
           block("bath-house door", (x0 + 0.036, 0.0075, z0 - 0.011), (x0 + 0.056, 0.0525, z0 + 0.011), dark),
           watered(copper, 0.026)]
    fine = []
    for y in (height * 0.3, height * 0.72):
        fine.append(rings("band", [(radius * 0.98, y), (radius * 1.05, y + 0.004), (radius * 1.05, y + 0.013), (radius * 0.98, y + 0.017)], sides,
                          pale_stone, caps=(False, False), centre=(x0, z0)))
    r, y = eave * 0.55, height + rise * 0.45
    fine.append(rings("roof ring", [(r * 0.97, y - 0.006), (r * 1.04, y), (r * 0.97, y + 0.008)], sides, slate, caps=(False, False),
                      centre=(x0, z0)))
    fine.append(rings("finial", [(0.006, height + rise - 0.012), (0.002, height + rise + 0.035)], 4, dark, centre=(x0, z0)))
    return far, fine


def lantern_walk(z):
    """Lanterns on iron posts either side of the walk to the door; near,
    their caps."""
    far, fine = [], []
    for x in (-0.06, 0.06):
        far.append(rod("lantern post", (x, 0.0, z), (x, 0.1, z), 0.003, iron, sides=4))
        far.append(rings("lantern", [(0.0, 0.09), (0.008, 0.096), (0.008, 0.108), (0.0, 0.112)], 6, window, centre=(x, z)))
        fine.append(rings("lantern cap", [(0.0095, 0.108), (0.0, 0.118)], 6, iron, centre=(x, z)))
    return far, fine


def airing_beds(at_point):
    """Beds carried out to air on trestles in the sun."""
    x0, _, z0 = at_point
    far = []
    for index in range(3):
        px = x0 + index * 0.05 - 0.05
        for dz in (-0.02, 0.02):
            far.append(rod("trestle", (px, 0.0, z0 + dz), (px, 0.027, z0 + dz), 0.003, dark, sides=4))
        far.append(block("airing bed", (px - 0.0175, 0.026, z0 - 0.0275), (px + 0.0175, 0.034, z0 + 0.0275), linen))
    return far


# The hospice's drum rises clear of its ridge, for its dome to crown it.
DRUM_TOP = 0.21


def hospice(at_point):
    """The great hospice: the ward in white stone, buttressed behind, its
    hall crowned with a dome of slate on a drum lit by windows and a lantern
    of moonsalt; near, the drum's cornice."""
    x0, _, z0 = at_point
    far, fine = ward(at_point, True, 0.3, CHIMNEYS[5])
    cx = x0 - 0.04
    top = DRUM_TOP
    far.append(rings("drum", [(0.055, 0.12), (0.055, top)], 12, white, caps=(False, False), centre=(cx, z0)))
    far.append(rings("dome", [(0.058, top), (0.052, top + 0.03), (0.035, top + 0.06), (0.0, top + 0.075)], 12, slate, centre=(cx, z0)))
    far.append(rings("dome lantern", [(0.0, top + 0.075), (0.012, top + 0.08), (0.01, top + 0.1), (0.0, top + 0.11)], 6, moonlight,
                     centre=(cx, z0)))
    fine.append(rings("cornice", [(0.0545, top - 0.011), (0.0605, top - 0.005), (0.0545, top)], 12, pale_stone, caps=(False, False),
                      centre=(cx, z0)))
    # The drum's windows, lit, on the flats that look out on the diagonals.
    for k in range(4):
        angle = math.pi / 4 + k * math.pi / 2
        reach = 0.055 * math.cos(math.pi / 12)
        far.append(lit("drum window", (cx + reach * math.cos(angle), top - 0.045, z0 + reach * math.sin(angle)), 0.014, 0.03, math.pi / 2 - angle,
                       window, depth=0.008))
    # The buttresses against its back wall, their tops weathered.
    back = z0 - 0.06
    for x in (-0.15, -0.05, 0.05, 0.15):
        far.append(slab("buttress", [(x0 + x, -0.01, back - 0.022), (x0 + x, -0.01, back + 0.002), (x0 + x, 0.11, back + 0.002),
                                     (x0 + x, 0.082, back - 0.022)], stone, 0.018, normal=(1, 0, 0)))
    return far, fine


def bell_cote(at_point):
    """The healers' bell in its stone cote, hung from a timber headstock
    under its little roof."""
    x0, _, z0 = at_point
    far = [block("cote pier", (x0 + x - 0.006, 0.0, z0 - 0.015), (x0 + x + 0.006, 0.16, z0 + 0.015), pale_stone) for x in (-0.022, 0.022)]
    far.append(gable_roof("cote roof", (x0, z0), 0.04, 0.06, 0.164, 0.025, slate, overhang=0.006, along="x", thickness=0.004))
    far.append(lath("headstock", (x0 - 0.017, 0.152, z0), (x0 + 0.017, 0.152, z0), 0.006, 0.007, dark))
    far.append(rod("bell hanger", (x0, 0.143, z0), (x0, 0.15, z0), 0.002, iron, sides=4))
    far.append(rings("bell", [(0.0155, 0.115), (0.013, 0.125), (0.008, 0.143), (0.0, 0.145)], 8, bronze, centre=(x0, z0)))
    return far


# MARK: The levels

join("well", well())
join("petals!fine", petals())
for level in LEVELS:
    windlass(level)

# 1. The tent, the fire under its kettle, a bed of herbs.
far, fine = tent((-0.04, 0.0, -0.08))
piece("infirmary", [1], far + hearth((-0.17, 0.0, 0.14)) + herbs((0.02, 0.0, 0.17), 1) + boundary(1), fine)

# 2. The timber ward under thatch, its garden of herbs, the fire kept (drawn
# in a little from the yard's wall, its tripod turned clear of it).
far, fine = ward((-0.04, 0.0, -0.1), False, 0.26, CHIMNEYS[2])
piece("infirmary", [2], far + herbs((-0.06, 0.0, 0.13), 3) + hearth((-0.2, 0.0, 0.145), math.pi / 3) + boundary(2), fine)

# 3. The ward in stone, the bath-house, the lantern walk.
far, fine = ward((-0.04, 0.0, -0.1), True, 0.26, CHIMNEYS[3])
more, close = bath_house((-0.21, 0.0, 0.08))
lamps, lamp_close = lantern_walk(0.06)
piece("infirmary", [3], far + more + lamps + herbs((0.04, 0.0, 0.17), 2) + boundary(3), fine + close + lamp_close)

# 4. The cloister: the ward and its wing about the physic garden, beds airing.
far, fine = ward((-0.02, 0.0, -0.14), True, 0.28, CHIMNEYS[4])
more, close = wing(4)
piece("infirmary", [4], far + more + herbs((0.0, 0.0, 0.06), 3) + airing_beds((0.05, 0.0, 0.2)) + boundary(3, [footprint(4)]), fine + close)

# 5. The great hospice under its dome, the wing, the bell in its cote, the
# lantern walk, the beds airing (drawn in clear of the yard's wall) and the
# fire (moved out from between the wing and the wall).
far, fine = hospice((-0.02, 0.0, -0.12))
more, close = wing(5)
lamps, lamp_close = lantern_walk(0.18)
piece("infirmary", [5], far + more + herbs((0.0, 0.0, 0.08), 3) + bell_cote((0.2, 0.0, -0.08)) + lamps + airing_beds((0.06, 0.0, 0.222))
      + hearth((-0.115, 0.0, 0.2)) + boundary(3, [footprint(5)]), fine + close + lamp_close)

# The well's windlass turning as water is drawn, once each idle.
idle(rig, turns=[("well windlass@%d" % level, (1, 0, 0), wheel_turns(1)) for level in LEVELS])

finish_building(out_path("Art/models/infirmary.glb"), [str(level) for level in LEVELS])
