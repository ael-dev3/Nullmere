"""The Beacon, the hold's fire on a height, lit to warn its House and its
allies; its three levels the tiers of one file, each within a work's slot
and facing +z:
1. a tower of four timber legs braced in two stages, a ladder to its
   platform, an iron basket of fire on it, a woodpile and a horn hung on a
   post at its foot, a cairn to mark the way up;
2. a taller tower on a footing of stone, its platform roofed in slate over
   the fire, a gallery round it, and the beacon-keeper's hut at its foot
   with its door and window lit, a low wall of field stones before it;
3. a round tower of stone with a stair winding round its outside,
   battlements, and a great brazier on its crown under a ring of iron;
   the keeper's house of stone below, the alarm bell on its frame.
Close: scree about the height, the braces crossed on each face, the
footing's dressed stones, courses girdling the stone tower, the axe in
its block, the water butt kept against sparks.
Its fire leaps in the night.

    python Art/blender/beacon.py Art/models/beacon.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3]

ground_stone = material("plain_stone_dark", (0.36, 0.35, 0.34))
stone = material("plain_stone", (0.52, 0.51, 0.49))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
rough = material("plain_stone_rock", (0.4, 0.4, 0.42))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
slate = material("plain_slate", (0.23, 0.24, 0.28))
linen = material("plain_linen", (0.7, 0.67, 0.6))
horn_white = material("plain_bone", (0.8, 0.78, 0.7))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
bronze = material("metal_bronze", (0.55, 0.43, 0.26), roughness=0.4, metallic=0.7)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))
fire = material("glow_fire", (1.0, 0.68, 0.32))

CORNERS = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
# Where each level's fire burns: its foot, and how big it is.
FIRES = {1: ((0.0, 0.35, 0.0), 0.03), 2: ((0.0, 0.47, 0.0), 0.03), 3: ((0.0, 0.62, 0.0), 0.042)}
STONE_HEIGHT, STONE_RADIUS = 0.56, 0.085

rig = work_rig([("beacon fire@%d" % level, foot, (0, 1, 0)) for level, (foot, _) in FIRES.items()])
ground(pad(tagged("pad", []), 0.29, ground_stone, sides=12), rig)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


def flame(level):
    """The fire itself, its own part to leap: a body of flame over the
    coals and tongues licking up about it."""
    (x, y, z), size = FIRES[level]
    pieces = [rings("flame", [(size * 0.9, y), (size, y + size * 0.3), (size * 0.6, y + size * 0.9), (size * 0.25, y + size * 1.5),
                              (0.0, y + size * 2.1)], 7, fire)]
    for index in range(5):
        angle = index * 1.26 + 0.3
        px, _, pz = on_ring(size * 0.58, y, angle)
        tongue = rings("tongue", [(size * 0.32, 0.0), (size * 0.16, size * 0.75), (0.0, size * (1.2 + 0.25 * (index % 2)))], 4, window,
                       twist=angle)
        # Each leans out a little from the heart of the fire.
        posed(tongue, (x + px, y, z + pz), (-math.sin(angle), 0, -math.cos(angle)), 0.22)
        pieces.append(tongue)
    obj = join(tagged("fire", level_tags([level])), pieces)
    on(obj, rig, "beacon fire@%d" % level)


def basket(centre, radius):
    """An iron fire basket, open to the sky: a bowl, its bars splayed out
    and up, the coals in it."""
    x, y, z = centre
    pieces = [rings("basket", [(radius * 0.4, y - 0.02), (radius, y + 0.01), (radius * 1.05, y + 0.05)], 8, iron, caps=(True, False),
                    centre=(x, z))]
    for index in range(8):
        angle = index / 8 * 2 * math.pi
        dx, _, dz = on_ring(radius, 0, angle)
        pieces.append(rod("bar", (x + dx * 0.95, y + 0.01, z + dz * 0.95), (x + dx * 1.12, y + 0.075, z + dz * 1.12), 0.0035, iron, sides=4))
    pieces.append(rings("coals", [(radius * 0.9, y + 0.015), (radius * 0.7, y + 0.035), (0.0, y + 0.04)], 8, dark, centre=(x, z)))
    return pieces


def timber_tower(height, footing, roofed):
    """A tower of four timber legs braced in stages, its platform and its
    railed gallery, a ladder up to it, the fire basket on top; on a footing
    of stone and roofed in slate at the second level."""
    base, top = 0.09, 0.055
    far, fine = [], []
    if footing:
        far.append(block("footing", (-0.12, 0.0, -0.12), (0.12, 0.05, 0.12), stone))
        # Its dressed stones on the faces that look down the hill.
        for index in range(4):
            u = -0.11 + index * 0.073
            fine.append(block("dressed stone", (u - 0.03, 0.004, 0.12), (u + 0.03, 0.046, 0.123), pale_stone))
            for side in (-1, 1):
                fine.append(block("dressed stone", (side * 0.1215 - 0.0015, 0.004, u - 0.03), (side * 0.1215 + 0.0015, 0.046, u + 0.03), pale_stone))
    foot = 0.05 if footing else 0.0
    for sx, sz in CORNERS:
        far.append(rod("leg", (sx * base, foot - 0.02, sz * base), (sx * top, height, sz * top), 0.011, timber, sides=6))
    # Braces in stages: rails round, and crossed struts on each face.
    stages = 3 if roofed else 2
    for stage in range(stages + 1):
        t = stage / stages
        y, r = foot + (height - foot) * t, base + (top - base) * t
        for index in range(4):
            (ax, az), (cx, cz) = CORNERS[index], CORNERS[(index + 1) % 4]
            far.append(lath("rail", (ax * r, y, az * r), (cx * r, y, cz * r), 0.007, 0.007, dark))
            if stage < stages:
                t2 = (stage + 1) / stages
                y2, r2 = foot + (height - foot) * t2, base + (top - base) * t2
                fine.append(lath("strut", (ax * r, y, az * r), (cx * r2, y2, cz * r2), 0.004, 0.004, dark))
                fine.append(lath("strut", (cx * r, y, cz * r), (ax * r2, y2, az * r2), 0.004, 0.004, dark))
    # The platform and the gallery's rail round it.
    far.append(block("platform", (-0.075, height, -0.075), (0.075, height + 0.012, 0.075), pale))
    for index in range(4):
        (ax, az), (cx, cz) = CORNERS[index], CORNERS[(index + 1) % 4]
        far.append(lath("gallery rail", (ax * 0.072, height + 0.05, az * 0.072), (cx * 0.072, height + 0.05, cz * 0.072), 0.005, 0.005, timber))
        far.append(rod("gallery post", (ax * 0.072, height, az * 0.072), (ax * 0.072, height + 0.05, az * 0.072), 0.004, timber, sides=4))
        fine.append(lath("gallery board", (ax * 0.072, height + 0.026, az * 0.072), (cx * 0.072, height + 0.026, cz * 0.072), 0.003, 0.003,
                         timber))
    far += ladder("ladder", (0.02, foot, 0.13), (0.02, height, 0.075), 0.04, int(height / 0.035), pale)
    far += basket((0.0, height + 0.03, 0.0), 0.045)
    if roofed:
        for sx, sz in CORNERS:
            far.append(rod("roof post", (sx * 0.07, height, sz * 0.07), (sx * 0.07, height + 0.17, sz * 0.07), 0.006, dark, sides=4))
        far.append(hip_roof("roof", (0, 0), 0.2, 0.2, height + 0.17, 0.09, slate, overhang=0.01, thickness=0.008))
        far.append(rod("finial", (0, height + 0.255, 0), (0, height + 0.31, 0), 0.004, iron, sides=4))
        flag(tagged("pennant", ["2"]), (0, height + 0.305, 0), 0.06, 0.035, banner, turn=0.4, tail=True)
    return far, fine


def stone_tower():
    """The round stone tower of the third level: coursed, a stair winding
    round its outside on its corbels, battlements, slit windows lit, and
    the great brazier on its crown under a ring of iron on four arms."""
    height, radius = STONE_HEIGHT, STONE_RADIUS

    def wall(y):
        """The tower's face at a height: it narrows as it rises."""
        return radius * (1 - 0.08 * max(0.0, y - 0.06) / (height - 0.06))

    far = [rings("tower", [(radius + 0.025, -0.06), (radius + 0.02, 0.04), (radius, 0.06), (radius * 0.92, height)], 12, stone),
           rings("parapet", [(radius * 0.92, height), (radius * 1.12, height + 0.012), (radius * 1.12, height + 0.03), (radius * 0.9, height + 0.03)],
                 12, pale_stone)]
    for index in range(8):
        angle = 2 * math.pi * index / 8
        mx, my, mz = on_ring(radius * 1.06, height + 0.03, angle)
        far.append(block("merlon", (mx - 0.013, my, mz - 0.009), (mx + 0.013, my + 0.035, mz + 0.009), stone, turn=-angle - math.pi / 2))
    fine = []
    y = 0.1
    while y < height - 0.02:
        r = wall(y)
        fine.append(rings("course", [(r - 0.001, y), (r + 0.003, y + 0.004), (r - 0.001, y + 0.008)], 12, pale_stone, caps=(False, False)))
        y += 0.09
    # Slit windows lit, a door at the foot.
    for index, y in enumerate((0.16, 0.3, 0.42)):
        angle = index * 2.2 + 0.4
        far.append(lit("slit", on_ring(wall(y) - 0.004, y, angle), 0.01, 0.035, angle + math.pi / 2, window))
    far.append(block("door", (-0.02, 0.01, radius + 0.012), (0.02, 0.09, radius + 0.032), dark))
    fine.append(block("lintel", (-0.026, 0.09, radius + 0.014), (0.026, 0.1, radius + 0.034), pale_stone))
    # The stair winding round its outside: treads jutting from the wall.
    steps = 22
    for index in range(steps):
        t = index / steps
        angle = math.pi * 0.6 + t * math.pi * 2.2
        y = 0.06 + t * (height - 0.1)
        out = wall(y) + 0.018
        sx, sz = out * math.cos(angle), out * math.sin(angle)
        far.append(block("tread", (sx - 0.02, y - 0.004, sz - 0.011), (sx + 0.02, y + 0.004, sz + 0.011), pale_stone, turn=angle))
        if index % 3 == 0:
            cx, cz = (out - 0.01) * math.cos(angle), (out - 0.01) * math.sin(angle)
            fine.append(block("corbel", (cx - 0.008, y - 0.016, cz - 0.006), (cx + 0.008, y - 0.004, cz + 0.006), stone, turn=angle))
    # The great brazier under its ring of iron on four arms.
    far += basket((0.0, height + 0.04, 0.0), 0.06)
    for index in range(4):
        angle = index / 4 * 2 * math.pi + math.pi / 4
        px, pz = 0.07 * math.cos(angle), 0.07 * math.sin(angle)
        far.append(rod("arm", (px, height + 0.03, pz), (px * 0.6, height + 0.2, pz * 0.6), 0.004, iron, sides=4))
    far.append(rings("crown ring", [(0.044, height + 0.196), (0.048, height + 0.2), (0.044, height + 0.204)], 10, iron, caps=(False, False)))
    return far, fine


def woodpile(at_point):
    """Cut wood stacked for the fire, the axe in the block beside it."""
    x0, _, z0 = at_point
    far = []
    for row in range(3):
        for index in range(4 - row):
            z = z0 - 0.03 + index * 0.02 + row * 0.01
            y = 0.012 + row * 0.018
            far.append(log("log", (x0 - 0.04, y, z), (x0 + 0.04, y, z), 0.009))
    fine = [rings("block", [(0.016, 0.0), (0.016, 0.03)], 6, timber, centre=(x0 + 0.06, z0 + 0.03)),
            lath("axe haft", (x0 + 0.06, 0.03, z0 + 0.03), (x0 + 0.08, 0.06, z0 + 0.04), 0.004, 0.004, pale),
            block("axe head", (x0 + 0.054, 0.027, z0 + 0.026), (x0 + 0.066, 0.036, z0 + 0.034), iron, turn=0.46)]
    return far, fine


def horn(at_point):
    """A horn of warning hung by its cord from a post."""
    x0, _, z0 = at_point
    pieces = [rod("horn post", (x0, 0, z0), (x0, 0.13, z0), 0.006, dark, sides=4),
              lath("horn arm", (x0, 0.12, z0), (x0 + 0.03, 0.12, z0), 0.005, 0.005, dark),
              rod("horn cord", (x0 + 0.028, 0.12, z0), (x0 + 0.03, 0.105, z0), 0.0012, linen, sides=3)]
    body = rings("horn", [(0.004, -0.03), (0.008, 0.0), (0.016, 0.025)], 6, horn_white, caps=(True, False))
    pieces.append(posed(body, (x0 + 0.03, 0.095, z0), (0, 0, 1), 1.2))
    return pieces


def hut(at_point, stone_built):
    """The beacon-keeper's hut: timber under thatch at the second level,
    stone under slate at the third, on a low plinth; its door and a window
    lit, its chimney at the back."""
    x0, _, z0 = at_point
    body, close = hall("hut", 0.1, 0.12, 0.075, stone if stone_built else timber, slate if stone_built else thatch, dark, pitch=0.65)
    for obj in body + close:
        placed(obj, at_point, math.pi / 2)
    sill = 0.012 if stone_built else 0.0
    if stone_built:
        body.append(block("plinth", (x0 - 0.068, -0.06, z0 - 0.058), (x0 + 0.068, sill, z0 + 0.058), ground_stone))
    far = list(body) + [
        block("door", (x0 + 0.058, sill, z0 + 0.001), (x0 + 0.064, 0.0625, z0 + 0.029), dark),
        lit("window", (x0 + 0.061, 0.05, z0 - 0.03), 0.016, 0.018, math.pi / 2, window),
        block("chimney", (x0 - 0.04, 0.07, z0 + 0.025), (x0 - 0.018, 0.15, z0 + 0.047), ground_stone),
    ]
    fine = list(close) + [block("step", (x0 + 0.06, 0.0, z0 - 0.002), (x0 + 0.078, sill + 0.006, z0 + 0.032), pale_stone),
                          block("shutter", (x0 + 0.061, 0.04, z0 - 0.044), (x0 + 0.064, 0.06, z0 - 0.04), timber),
                          block("shutter", (x0 + 0.061, 0.04, z0 - 0.02), (x0 + 0.064, 0.06, z0 - 0.016), timber)]
    return far, fine


def bell(at_point):
    """The beacon's alarm bell: two posts and a beam, the bell hung from
    it, its rope looped down."""
    x0, _, z0 = at_point
    pieces = [rod("bell post", (x0, 0, z0 + z), (x0, 0.1, z0 + z), 0.004, dark, sides=4) for z in (-0.026, 0.026)]
    pieces.append(lath("bell beam", (x0, 0.1, z0 - 0.034), (x0, 0.1, z0 + 0.034), 0.008, 0.008, dark))
    pieces.append(rings("bell", [(0.017, 0.058), (0.013, 0.07), (0.009, 0.092), (0.0, 0.096)], 7, bronze, centre=(x0, z0)))
    pieces.append(rod("bell rope", (x0 + 0.004, 0.06, z0), (x0 + 0.004, 0.035, z0 + 0.022), 0.0012, linen, sides=3))
    return pieces


def scree():
    """Loose stones about the height."""
    stones = []
    for index in range(10):
        angle = index * 2.39996
        r = 0.14 + 0.12 * ((index * 29) % 7) / 7
        stones.append(rock("scree", (r * math.cos(angle), 0.01, r * math.sin(angle)), (0.02, 0.012, 0.016), index + 101,
                           rough if index % 2 == 0 else ground_stone))
    return stones


def cairn(at_point, base=5, middle=3):
    """A cairn of piled stones, a waymark for those climbing to the fire:
    `base` stones about its foot, `middle` on them and one on top."""
    x0, _, z0 = at_point
    stones = []
    for index in range(base + middle + 1):
        ring = 0 if index < base else (1 if index < base + middle else 2)
        angle = index * 1.9
        r = (0.03, 0.018, 0.0)[ring]
        stones.append(rock("cairn stone", (x0 + r * math.cos(angle), 0.012 + ring * 0.022, z0 + r * math.sin(angle)), (0.022, 0.016, 0.02),
                           index + 211, stone if index % 2 == 0 else rough))
    return stones


def boundary(courses):
    """A low wall of field stones along the front of the height, laid
    along its arc, course on course."""
    stones = []
    count = 15
    for index in range(count):
        for course in range(courses):
            angle = math.pi * (1.08 + 0.84 * index / (count - 1)) + (0.5 * 0.84 * math.pi / count if course % 2 else 0.0)
            x, y, z = on_ring(0.295, 0.012 + course * 0.02, angle)
            shade = (index + course) % 3
            stones.append(block("field stone", (x - 0.025, y - 0.0095, z - 0.013), (x + 0.025, y + 0.0095, z + 0.013),
                                (stone, pale_stone, rough)[shade], turn=-angle - math.pi / 2))
    return stones


def water_butt(at_point):
    """A butt of water kept by the fire against its sparks, hooped."""
    x0, _, z0 = at_point
    pieces = [rings("butt", [(0.018, 0.0), (0.021, 0.022), (0.018, 0.045)], 8, timber, centre=(x0, z0))]
    for y in (0.009, 0.036):
        pieces.append(rings("hoop", [(0.0195, y), (0.0215, y + 0.002), (0.0195, y + 0.004)], 8, iron, centre=(x0, z0), caps=(False, False)))
    return pieces


# MARK: The levels

far, fine = timber_tower(0.3, False, False)
wood, wood_close = woodpile((0.17, 0, 0.13))
piece("beacon", [1], far + wood + horn((-0.17, 0, 0.14)) + cairn((-0.16, 0, -0.15)), fine + wood_close + water_butt((0.08, 0, -0.14)))

far, fine = timber_tower(0.42, True, True)
wood, wood_close = woodpile((0.19, 0, 0.12))
more, more_close = woodpile((0.16, 0, -0.17))
house, house_close = hut((-0.18, 0, 0.1), False)
piece("beacon", [2], far + wood + more + house + horn((0.02, 0, 0.23)) + boundary(1),
      fine + wood_close + more_close + house_close + water_butt((0.11, 0, 0.18)))

far, fine = stone_tower()
house, house_close = hut((-0.19, 0, 0.1), True)
wood, wood_close = woodpile((0.17, 0, -0.16))
piece("beacon", [3], far + house + bell((0.18, 0, 0.13)) + wood + boundary(2) + cairn((-0.05, 0, -0.22), 4, 2),
      fine + house_close + wood_close + water_butt((0.12, 0, 0.05)))

for level in LEVELS:
    flame(level)

join("scree!fine", scree())

# Its fire leaping, every level's.
idle(rig, stretches=[("beacon fire@%d" % level, leaping) for level in LEVELS])

finish_building(out_path("Art/models/beacon.glb"), [str(level) for level in LEVELS])
