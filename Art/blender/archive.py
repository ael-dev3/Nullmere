"""The Archive, where the House's scholars keep its records and read the sky;
its five levels the tiers of one file, each within a work's slot and facing
+z:
1. a scholar's cell of timber under thatch, a lectern and chests of scrolls
   before it, a sundial on its stone, a weathervane on its ridge;
2. a long library hall of timber under slate, writing desks under an awning
   before it, the weathervane turning on its ridge;
3. the library rebuilt in pale stone, its tall windows lit, a scriptorium
   wing turned to face the court, an armillary sphere turning on its plinth;
4. an observatory tower beside it under a dome, its shutter open on the sky;
5. a domed reading hall at the heart behind its portico, the observatory
   crowned with the great armillary, lanterns along the cloister walk.
A dry-stone wall rises course by course along the front of the yard, and
leaves lie fallen in the court.
Close: the roofs' courses, bargeboards and rafters, the carved lintel over
the library's door and the hoods over its windows, the iron bands on the
chests, pages and ink on the desks, the tower's string courses, the
cardinal arms under the vane.
The weathervane, and then the armillary, turns once through the idle.

    python Art/blender/archive.py Art/models/archive.glb
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

yard = material("plain_earth_yard", (0.31, 0.29, 0.25))
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
linen = material("plain_linen", (0.7, 0.67, 0.6))
weld = material("plain_weld", (0.55, 0.49, 0.27))
madder = material("plain_madder", (0.44, 0.24, 0.19))
sea_wool = material("plain_seawool", (0.27, 0.33, 0.38))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
bronze = material("metal_bronze", (0.55, 0.43, 0.26), roughness=0.4, metallic=0.7)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.35, metallic=0.8)
glow = material("glow_candle", (1.0, 0.8, 0.52))

UP = (0, 1, 0)
# The weathervane on the ridge at each of the first two levels: where it
# stands (x, z), the foot of its mast in the ridge, and the pivot it turns on.
VANES = {1: (-0.05, -0.08, 0.16, 0.21), 2: (-0.03, -0.12, 0.185, 0.25)}
# The armillary at each later level: the foot it stands on, its radius, and
# whether on a plinth in the court (or on the observatory's dome).
ARMILLARIES = {3: ((0.12, 0.0, 0.12), 0.06, True), 4: ((0.07, 0.0, 0.14), 0.06, True), 5: ((0.19, 0.44, -0.1), 0.07, False)}
# The library's windows along its front, either side of its door, as the
# game's stride in Float lays them out (at 0.28 it keeps the one at 0.03).
WINDOWS = {0.28: (-0.105, -0.06, 0.03, 0.075), 0.24: (-0.085, -0.04, 0.05, 0.095)}


def armillary_centre(level):
    (x, y, z), radius, plinth = ARMILLARIES[level]
    return (x, y + (0.1 + radius if plinth else radius), z)


rig = work_rig([("archive vane@%d" % level, (x, pivot, z), UP) for level, (x, z, _, pivot) in VANES.items()] +
               [("armillary@%d" % level, armillary_centre(level), UP) for level in ARMILLARIES])
ground(pad(tagged("pad", []), 0.31, yard), rig)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


def boxed(name, centre, size, mat, turn=0.0, chamfer=0.0):
    """A block `size` across about its centre, turned `turn` as the game's
    box(turn:) turns (so the other way to block's own)."""
    (x, y, z), (w, h, d) = centre, size
    return block(name, (x - w / 2, y - h / 2, z - d / 2), (x + w / 2, y + h / 2, z + d / 2), mat, chamfer=chamfer, turn=-turn)


def door(centre, width, height):
    """A door: a dark slab set into a wall facing +z."""
    return boxed("door", centre, (width, height, 0.02), dark)


def building(name, at_point, width, depth, height, wall, roof, pitch, turn=0.0, footing=None, eaves=0.01):
    """A hall with its gable roof and frame, on a chamfered footing of
    stone if it has one, set down at a point and turned (as the game turns)."""
    far, fine = hall(name, width, depth, height, wall, roof, dark, pitch=pitch, eaves=eaves)
    if footing is not None:
        far.append(block(name + " footing", (-width / 2 - 0.012, -0.08, -depth / 2 - 0.012), (width / 2 + 0.012, 0.04, depth / 2 + 0.012),
                         footing, chamfer=0.004))
    for obj in far + fine:
        placed(obj, at_point, turn)
    return far, fine


# MARK: The halls

def cell(at_point):
    """A scholar's cell: timber under thatch, its door and a lit window."""
    x0, _, z0 = at_point
    far, fine = building("cell", at_point, 0.16, 0.12, 0.09, timber, thatch, 0.7, eaves=0.014)
    far.append(door((x0 - 0.03, 0.04, z0 + 0.062), 0.03, 0.065))
    far.append(lit("window", (x0 + 0.04, 0.055, z0 + 0.062), 0.022, 0.026, 0.0, glow))
    return far, fine


def library(at_point, stone_built, width):
    """The long library hall: timber or pale stone (on its footing), its
    tall windows lit, its door under a carved lintel of bronze; the stone
    one's windows hooded."""
    x0, _, z0 = at_point
    depth, height = 0.12, (0.13 if stone_built else 0.1)
    # The timber hall's eaves a little thinner, clear of its lintel.
    far, fine = building("library", at_point, width, depth, height, pale_stone if stone_built else pale, slate, 0.7,
                         footing=stone if stone_built else None, eaves=0.01 if stone_built else 0.006)
    front = z0 + depth / 2
    if stone_built:
        # The door from the top of the footing, a step up to it before.
        far.append(door((x0, 0.0625, front + 0.002), 0.035, 0.045))
        far.append(block("step", (x0 - 0.026, -0.01, front + 0.01), (x0 + 0.026, 0.026, front + 0.03), pale_stone, chamfer=0.002))
    else:
        # Its head a little lower than the game's, its lintel clear of the eaves.
        far.append(door((x0, 0.0425, front + 0.002), 0.035, 0.075))
    # The lintel on the door's head.
    head, lintel = (0.085, 0.012) if stone_built else (0.08, 0.01)
    fine.append(boxed("lintel", (x0, head + lintel / 2, front + 0.006), (0.05, lintel, 0.008), bronze))
    for x in WINDOWS[width]:
        far.append(lit("window", (x0 + x, height * 0.55, front + 0.002), 0.014, 0.05 if stone_built else 0.03, 0.0, glow))
        if stone_built:
            fine.append(boxed("hood", (x0 + x, height * 0.55 + 0.03, front + 0.005), (0.02, 0.006, 0.008), stone))
    return far, fine


def scriptorium(at_point):
    """The scriptorium wing turned to face the court, its windows lit."""
    x0, _, z0 = at_point
    far, fine = building("scriptorium", at_point, 0.18, 0.09, 0.1, pale_stone, slate, 0.65, turn=math.pi / 2, footing=stone)
    for z in (-0.05, 0.0, 0.05):
        far.append(lit("window", (x0 + 0.046, 0.06, z0 + z), 0.014, 0.034, math.pi / 2, glow))
    return far, fine


def observatory(at_point, height):
    """The observatory tower under its dome, the dark slit of its shutter
    open on the sky; near, string courses girdling it."""
    x0, _, z0 = at_point
    centre = (x0, z0)

    def wall(y):
        """The tower's face at a height: it narrows as it rises."""
        return 0.065 - 0.005 * (y + 0.06) / (height + 0.06)

    far = [rings("tower", [(0.065, -0.06), (0.06, height)], 12, pale_stone, caps=(False, False), centre=centre)]
    for index, y in enumerate((0.08, 0.16, height - 0.06)):
        angle = index * 2.1 + 0.4
        far.append(lit("window", on_ring(0.061, y, angle, centre), 0.012, 0.03, angle + math.pi / 2, glow))
    # The dome (Works.dome's), its eaves closed beneath where it overhangs.
    radius = 0.07
    profile = [(0.06, height)] + [(radius * 1.05 * math.cos(k / 3 * math.pi / 2), height + radius * math.sin(k / 3 * math.pi / 2))
                                  for k in range(3)] + [(0.0, height + radius)]
    far.append(rings("dome", profile, 12, slate, caps=(False, False), centre=centre))
    far.append(block("shutter", (x0 - 0.018, height + radius * 0.2, z0 + radius * 0.75), (x0 + 0.018, height + radius * 1.02, z0 + radius * 1.02),
                     dark))
    fine = []
    k = 0
    while 0.06 + 0.07 * k < height:
        y = 0.06 + 0.07 * k
        fine.append(rings("string course", [(wall(y) - 0.001, y), (wall(y) + 0.004, y + 0.004), (wall(y + 0.008) - 0.001, y + 0.008)], 12, stone,
                          caps=(False, False), centre=centre))
        k += 1
    return far, fine


def reading_hall(at_point):
    """The domed reading hall of the fifth level: a round hall of pale stone
    under a great dome with a lantern lit on its crown, a portico of
    columns before it on its step."""
    x0, _, z0 = at_point
    centre = (x0, z0)
    far = [rings("drum", [(0.11, -0.06), (0.11, 0.14)], 16, pale_stone, caps=(False, False), centre=centre),
           rings("cornice", [(0.118, 0.14), (0.118, 0.155)], 16, stone, centre=centre),
           rings("great dome", [(0.115, 0.155), (0.1, 0.2), (0.07, 0.24), (0.03, 0.26), (0.0, 0.262)], 16, slate, caps=(False, False),
                 centre=centre),
           rings("lantern", [(0.0, 0.26), (0.018, 0.265), (0.016, 0.29), (0.0, 0.3)], 8, glow, centre=centre)]
    for index in range(8):
        angle = index / 8 * 2 * math.pi + math.pi / 8
        far.append(lit("window", on_ring(0.111, 0.09, angle, centre), 0.014, 0.05, angle + math.pi / 2, glow))
    # The portico: its columns on a step, under the entablature and its roof.
    far.append(block("step", (x0 - 0.094, -0.02, z0 + 0.104), (x0 + 0.094, 0.018, z0 + 0.153), pale_stone, chamfer=0.003))
    for index in range(5):
        x = -0.07 + 0.035 * index
        far.append(rings("column", [(0.009, 0.016), (0.007, 0.026), (0.007, 0.11), (0.009, 0.12)], 6, white, caps=(False, False),
                         centre=(x0 + x, z0 + 0.13)))
    far.append(block("entablature", (x0 - 0.085, 0.12, z0 + 0.115), (x0 + 0.085, 0.135, z0 + 0.145), white, chamfer=0.003))
    far.append(gable_roof("portico roof", (x0, z0 + 0.13), 0.03, 0.17, 0.135, 0.025, slate, overhang=0.006, along="x", thickness=0.005))
    far.append(door((x0, 0.045, z0 + 0.111), 0.035, 0.08))
    return far


# MARK: The court

def lectern(at_point):
    """A lectern on its foot, a great book open on it."""
    x0, _, z0 = at_point
    pieces = [boxed("lectern foot", (x0, 0.012, z0), (0.022, 0.006, 0.022), dark),
              rod("lectern post", (x0, 0.0, z0), (x0, 0.064, z0), 0.004, dark, sides=4)]
    top = [boxed("lectern board", (0.0, 0.0, 0.0), (0.04, 0.004, 0.03), timber)]
    for side in (-1, 1):
        leaf = boxed("page", (0.0, 0.0, 0.0), (0.0175, 0.004, 0.026), linen)
        posed(leaf, (side * 0.009, 0.004, 0.0), (0, 0, 1), side * 0.12)
        top.append(leaf)
    for obj in top:
        posed(obj, (x0, 0.065, z0), (1, 0, 0), 0.5)
    return pieces + top


def chests(at_point, count):
    """Chests of scrolls in a row, iron-bound."""
    far, fine = [], []
    for index in range(count):
        x, z = at_point[0] + index * 0.04 - (count - 1) * 0.02, at_point[2]
        far.append(block("chest", (x - 0.017, 0.0, z - 0.013), (x + 0.017, 0.024, z + 0.013), dark))
        far.append(block("chest lid", (x - 0.018, 0.024, z - 0.014), (x + 0.018, 0.03, z + 0.014), timber))
        for dx in (-0.01, 0.01):
            fine.append(block("chest band", (x + dx - 0.0015, 0.0, z - 0.0146), (x + dx + 0.0015, 0.0306, z + 0.0146), iron))
    return far, fine


def sundial(at_point):
    """A sundial on its stone, its gnomon of bronze."""
    x0, _, z0 = at_point
    return [rings("sundial", [(0.018, 0.0), (0.014, 0.04), (0.024, 0.045), (0.024, 0.05), (0.0, 0.051)], 10, pale_stone, caps=(False, True),
                  centre=(x0, z0)),
            slab("gnomon", [(x0, 0.05, z0 - 0.012), (x0, 0.05, z0 + 0.012), (x0, 0.07, z0 - 0.012)], bronze, 0.002, normal=(1, 0, 0))]


def awning(at_point):
    """Writing desks under an awning on four posts, pages and ink on them."""
    x0, _, z0 = at_point

    def cloth(z):
        """The middle of the awning over a point: high at the back, low at the front."""
        return 0.09 - 0.01 * (z + 0.04) / 0.085

    far, fine = [], []
    for x in (-0.08, 0.08):
        for z in (-0.03, 0.03):
            far.append(rod("awning post", (x0 + x, 0.0, z0 + z), (x0 + x, cloth(z) - 0.0012, z0 + z), 0.003, dark, sides=4))
    far.append(slab("awning", [(x0 - 0.09, 0.09, z0 - 0.04), (x0 + 0.09, 0.09, z0 - 0.04), (x0 + 0.09, 0.08, z0 + 0.045),
                               (x0 - 0.09, 0.08, z0 + 0.045)], sea_wool, 0.003, normal=(0, 1, 0.1)))
    for x in (-0.05, 0.0, 0.05):
        far.append(boxed("desk", (x0 + x, 0.03, z0), (0.035, 0.004, 0.025), timber))
        for dx in (-0.014, 0.014):
            far.append(rod("desk leg", (x0 + x + dx, 0.0, z0), (x0 + x + dx, 0.03, z0), 0.002, dark, sides=4))
        fine.append(boxed("page", (x0 + x, 0.033, z0), (0.02, 0.002, 0.016), linen))
        fine.append(rings("ink", [(0.0025, 0.031), (0.0025, 0.0365)], 4, dark_stone, caps=(False, True), twist=math.pi / 4,
                          centre=(x0 + x + 0.0135, z0 - 0.007)))
    return far, fine


def lanterns():
    """Lanterns on iron posts along the cloister walk, hooded in iron."""
    far = []
    for x in (-0.22, -0.15, 0.04, 0.11):
        far.append(rod("lantern post", (x, 0.0, 0.2), (x, 0.08, 0.2), 0.003, iron, sides=4))
        far.append(rings("lantern light", [(0.0, 0.077), (0.007, 0.082), (0.007, 0.091), (0.0, 0.095)], 6, glow, centre=(x, 0.2)))
        far.append(rings("lantern hood", [(0.0095, 0.091), (0.0, 0.101)], 6, iron, centre=(x, 0.2)))
    return far


def arc_stone(name, inner, outer, a0, a1, low, high, mat):
    """A stone laid along a ring from one angle to another (as on_ring
    counts), cut to it: its inner and outer faces chords, its ends square."""
    def build(bm):
        v = [bm.verts.new(at(*on_ring(r, y, a))) for y in (low, high) for a in (a0, a1) for r in (inner, outer)]
        for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            bm.faces.new([v[i] for i in f])
    return mesh_object(name, build, mat)


def boundary(course):
    """One course of the dry-stone wall along the front of the yard
    (Lodge.boundary's): eighteen stones along its arc, a hairline between
    each, every other course's joints over the middles of the stones below
    (so it begins and ends with a half stone); the first course bedded in
    the ground, each after laid on the one below."""
    step = 0.84 * math.pi / 17
    start, end = 1.08 * math.pi - step / 2, 1.92 * math.pi + step / 2
    if course % 2:
        cuts = [start] + [start + step * (k + 0.5) for k in range(18)] + [end]
    else:
        cuts = [start + step * k for k in range(19)]
    y = 0.012 + course * 0.02
    low, high = (-0.01 if course == 0 else y - 0.0108), y + 0.0095
    joint = 0.0012 / 0.295
    return [arc_stone("field stone", 0.282, 0.308, a0 + joint / 2, a1 - joint / 2, low, high, (stone, pale_stone, rough)[(index + course) % 3])
            for index, (a0, a1) in enumerate(zip(cuts, cuts[1:]))]


def leaves():
    """Leaves fallen in the court."""
    out = []
    for index in range(16):
        angle = index * 2.39996
        r = 0.08 + 0.18 * ((index * 29) % 11) / 11
        out.append(boxed("leaf", (r * math.cos(angle), 0.0125, r * math.sin(angle)), (0.008, 0.002, 0.006), weld if index % 2 == 0 else madder,
                         turn=angle))
    return out


# MARK: What turns

def vane(level):
    """The weathervane on the ridge: its iron mast and the cardinal arms
    under it, and the vane turning in the night wind (its own part), a sail
    of bronze on an arrow."""
    x, z, foot, pivot = VANES[level]
    far = [rod("vane mast", (x, foot, z), (x, pivot + 0.003, z), 0.002, iron, sides=4)]
    fine = [rod("cardinal arm", (x - 0.016, pivot - 0.016, z), (x + 0.016, pivot - 0.016, z), 0.0012, iron, sides=4),
            rod("cardinal arm", (x, pivot - 0.016, z - 0.016), (x, pivot - 0.016, z + 0.016), 0.0012, iron, sides=4)]
    pieces = [slab("vane sail", [(x - 0.02, pivot, z), (x + 0.02, pivot, z), (x + 0.012, pivot + 0.014, z)], bronze, 0.002, normal=(0, 0, 1)),
              rod("vane arrow", (x - 0.025, pivot, z), (x + 0.025, pivot, z), 0.0015, iron, sides=4),
              slab("vane head", [(x - 0.025, pivot - 0.005, z), (x - 0.025, pivot + 0.005, z), (x - 0.035, pivot, z)], iron, 0.002, normal=(0, 0, 1))]
    on(join(tagged("vane", level_tags([level])), pieces), rig, "archive vane@%d" % level)
    return far, fine


def armillary(level):
    """The armillary sphere, three rings of the heavens crossed about a
    golden earth (Works.armillary's), turning on its axle (its own part);
    the axle standing on its plinth in the court, or on a mount on the
    observatory's dome."""
    (x, y, z), radius, plinth = ARMILLARIES[level]
    cx, cy, cz = armillary_centre(level)
    far = []
    if plinth:
        far.append(rings("plinth", [(0.03, 0.0), (0.024, 0.02), (0.018, 0.08), (0.026, 0.09), (0.026, 0.1)], 8, pale_stone, caps=(False, True),
                         centre=(x, z)))
        low = y + 0.095
    else:
        far.append(rings("armillary mount", [(0.014, y - 0.016), (0.006, y - 0.002)], 8, bronze, caps=(False, True), centre=(x, z)))
        low = y - 0.004
    far.append(rod("armillary axle", (cx, low, cz), (cx, cy + radius * 0.92 + 0.006, cz), 0.0022, bronze, sides=6))
    hoops = []
    for index, turns in enumerate(((), (((1, 0, 0), math.pi / 2),), (((1, 0, 0), 0.4), ((0, 0, 1), math.pi / 2)))):
        r = radius * (1 - 0.08 * index)
        hoop = rings("armillary ring", [(r * 0.9, -0.006), (r, -0.006), (r, 0.006), (r * 0.9, 0.006), (r * 0.9, -0.006)], 12,
                     gold if index == 0 else bronze, caps=(False, False))
        for axis, angle in turns:
            posed(hoop, (0.0, 0.0, 0.0), axis, angle)
        hoops.append(placed(hoop, (cx, cy, cz)))
    s = radius * 0.22
    hoops.append(rings("armillary earth", [(0.0, cy - s), (s * 0.87, cy - s / 2), (s * 0.87, cy + s / 2), (0.0, cy + s)], 6, gold,
                       centre=(cx, cz)))
    on(join(tagged("armillary rings", level_tags([level])), hoops), rig, "armillary@%d" % level)
    return far


# MARK: The levels

far, fine = cell((-0.05, 0.0, -0.08))
more, close = chests((-0.15, 0.0, 0.13), 2)
mast, arms = vane(1)
piece("archive", [1], far + more + mast + lectern((0.06, 0.0, 0.12)) + sundial((0.18, 0.0, 0.04)), fine + close + arms)

far, fine = library((-0.03, 0.0, -0.12), False, 0.28)
desks, desks_close = awning((-0.04, 0.0, 0.1))
# Drawn a little in from the game's (-0.2, 0.15), clear of the wall's curve.
more, close = chests((-0.183, 0.0, 0.128), 3)
mast, arms = vane(2)
piece("archive", [2], far + desks + more + mast + sundial((0.2, 0.0, 0.12)), fine + desks_close + close + arms)

far, fine = library((-0.04, 0.0, -0.13), True, 0.28)
wing, wing_close = scriptorium((-0.21, 0.0, 0.06))
desks, desks_close = awning((-0.02, 0.0, 0.17))
piece("archive", [3], far + wing + desks + armillary(3), fine + wing_close + desks_close)

far, fine = library((-0.07, 0.0, -0.13), True, 0.24)
tower, tower_close = observatory((0.18, 0.0, -0.1), 0.28)
wing, wing_close = scriptorium((-0.2, 0.0, 0.055))
piece("archive", [4], far + tower + wing + armillary(4), fine + tower_close + wing_close)

tower, tower_close = observatory((0.19, 0.0, -0.1), 0.36)
more, close = chests((0.14, 0.0, 0.18), 3)
piece("archive", [5], reading_hall((-0.06, 0.0, -0.08)) + tower + armillary(5) + lanterns() + more + sundial((0.2, 0.0, 0.08)) +
      lectern((-0.21, 0.0, 0.1)) + lectern((-0.18, 0.0, 0.15)), tower_close + close)

# The dry-stone wall, a course more at each of the first three levels.
join("boundary", boundary(0))
join(tagged("boundary", level_tags([2, 3, 4, 5])), boundary(1))
join(tagged("boundary", level_tags([3, 4, 5])), boundary(2))
join("leaves!fine", leaves())

# The vane, and then the armillary, turning once through the idle.
idle(rig, turns=[("archive vane@%d" % level, UP, wheel_turns(1)) for level in VANES] +
     [("armillary@%d" % level, UP, wheel_turns(1)) for level in ARMILLARIES])

finish_building(out_path("Art/models/archive.glb"), [str(level) for level in LEVELS])
