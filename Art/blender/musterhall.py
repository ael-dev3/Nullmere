"""The Muster Hall, where the House's companies are raised and drilled, its
five levels the tiers of one file, each within a work's slot and facing +z:
1. a drill yard staked about, pells to strike at, a rack of spears and
   shields, and the drill-master's tent on its ridge pole;
2. a timber barracks under thatch, archery butts at the yard's end;
3. the barracks rebuilt in stone under slate on a footing, the armoury of
   dark stone beside them, its door iron-bound;
4. a drill tower over the yard where the drill-master calls, a parade
   ground flagged, the House's standard on its staff;
5. a gatehouse of two round towers before the hall flying the House's
   banners, the war drum on its stand, standards either side.
Close: the yard scuffed by feet and hooves, the rope strung from stake to
stake, the pells hacked, arrows in the butts, the barracks' roof courses,
gable boards and rafters' ends, the armoury door's bands, the drill tower's
ladder, the parade ground's joints, the towers' string courses and the
drum's hoops.
At every level a quintain spins on its post as the companies ride at it;
at the fifth the drumstick beats the drill.

    python Art/blender/musterhall.py Art/models/musterhall.glb
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
earth = material("plain_earth", (0.24, 0.21, 0.18))
straw = material("plain_thatch_straw", (0.62, 0.55, 0.36))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
slate = material("plain_slate", (0.23, 0.24, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
linen = material("plain_linen", (0.7, 0.67, 0.6))
madder = material("plain_madder", (0.44, 0.24, 0.19))
leather = material("plain_leather", (0.36, 0.25, 0.17))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.35, metallic=0.8)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.4, metallic=0.8)
painted = material("house_roof", (0.78, 0.78, 0.78))
banner = material("cloth_banner", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))

# The quintain's post and the pivot its arm spins on, the same at every
# level; the war drum of the fifth and the pivot its stick beats from.
QUINTAIN = (0.12, 0.0, 0.13)
PIVOT = (0.12, 0.12, 0.13)
DRUM = (0.2, 0.0, -0.04)
BEAT = (0.25, 0.12, -0.04)
# The stick is made raised this far above where it lies on the drumhead, so
# its swing (0.4 at full) brings its head down onto the skin, not into it.
RAISED = 0.368

rig = work_rig([("quintain@%d" % level, PIVOT, (0, 1, 0)) for level in LEVELS] + [("drumstick@5", BEAT, (0, 0, 1))])
ground(pad("pad", 0.31, yard, sides=12), rig)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


def box(name, centre, size, mat, turn=0.0, chamfer=0.0):
    """The game's box(center:size:turn:): `size` about `centre`, turned
    `turn` as the game turns (block's turn runs the other way)."""
    low = tuple(c - s / 2 for c, s in zip(centre, size))
    high = tuple(c + s / 2 for c, s in zip(centre, size))
    return block(name, low, high, mat, chamfer=chamfer, turn=-turn, about=centre)


def ball(name, centre, radius, mat, sides=6):
    """A small faceted ball: a finial, a beater's head."""
    x, y, z = centre
    return rings(name, [(0.0, y - radius), (radius * 0.866, y - radius / 2), (radius * 0.866, y + radius / 2), (0.0, y + radius)], sides,
                 mat, centre=(x, z))


# MARK: At every level

def scuffs():
    """The yard scuffed by feet and hooves, each mark laid out from its
    middle."""
    marks = []
    for index in range(16):
        angle = index * 2.39996
        r = 0.05 + 0.2 * ((index * 19) % 11) / 11
        x, z = r * math.cos(angle), r * math.sin(angle)
        marks.append(block("scuff", (x - 0.008, 0.0115, z - 0.004), (x + 0.008, 0.0135, z + 0.004), earth if index % 2 == 0 else straw,
                           turn=angle, about=(x, 0.0125, z)))
    return marks


def stakes(height):
    """Sharpened stakes round the back of the yard, a flat of each turned
    out from it, and a rope run from stake to stake."""
    far, fine = [], []
    last = None
    for index in range(20):
        angle = math.pi * (0.15 + 0.7 * index / 19)
        x, _, z = on_ring(0.3, 0.0, angle)
        twist = math.pi / 4 - angle
        far.append(rings("stake", [(0.006, -0.02), (0.006, height)], 4, timber, caps=(False, False), twist=twist, centre=(x, z)))
        far.append(rings("stake point", [(0.006, height), (0.0, height + 0.012)], 4, pale, caps=(False, False), twist=twist, centre=(x, z)))
        if last is not None:
            fine.append(rod("rope", (last[0], height * 0.7, last[1]), (x, height * 0.7, z), 0.001, linen, sides=3, caps=(False, False)))
        last = (x, z)
    return far, fine


def quintain_arm(level):
    """The quintain's arm, spinning on its post when it is struck: the
    House's shield hung on its front at one end, a sandbag on a rope at
    the other."""
    px, py, pz = PIVOT
    pieces = [block("quintain arm", (px - 0.07, py - 0.003, pz - 0.003), (px + 0.07, py + 0.003, pz + 0.003), timber)]
    shield = rings("quintain shield", [(0.0, 0.0), (0.02, 0.002), (0.02, 0.006), (0.0, 0.008)], 8, painted, twist=math.pi / 8)
    pieces.append(posed(shield, (px - 0.07, py - 0.02, pz + 0.003), (1, 0, 0), math.pi / 2))
    pieces.append(rod("quintain rope", (px + 0.07, py, pz), (px + 0.07, py - 0.036, pz), 0.0015, linen, sides=4, caps=(False, False)))
    pieces.append(tied_sack("quintain sandbag", (px + 0.07, py - 0.064, pz), 0.012, canvas))
    on(join(tagged("quintain arm", level_tags([level])), pieces), rig, "quintain@%d" % level)


# MARK: The yard's gear

def pells(xs, z):
    """Pells, posts to strike at with sword and spear, hacked and scarred."""
    far, fine = [], []
    for x in xs:
        far.append(rings("pell", [(0.012, 0.0), (0.011, 0.09), (0.008, 0.1)], 6, grey, caps=(False, True), centre=(x, z)))
        for y in (0.04, 0.07):
            fine.append(box("hack", (x + 0.011, y, z), (0.003, 0.006, 0.01), pale, turn=0.4))
    return far, fine


def rack(at_point):
    """A rack of spears leant on its rail, the House's shields stood
    against them."""
    x0, _, z0 = at_point
    lean = math.atan2(0.016, 0.17)
    far = [rod("rack post", (x0, 0.0, z0 + dz), (x0, 0.11, z0 + dz), 0.004, dark, sides=4, caps=(False, True)) for dz in (-0.05, 0.05)]
    far.append(block("rack rail", (x0 - 0.0025, 0.0975, z0 - 0.055), (x0 + 0.0025, 0.1025, z0 + 0.055), timber))
    for index in range(6):
        dz = -0.04 + 0.016 * index
        top = (x0 - 0.004, 0.17, z0 + dz)
        far.append(rod("spear", (x0 + 0.012, 0.0, z0 + dz), top, 0.0022, pale, sides=4, caps=(False, False)))
        far.append(posed(rings("spearhead", [(0.004, 0.0), (0.0, 0.018)], 4, steel), top, (0, 0, 1), lean))
        if index % 2 == 0:
            shield = rings("shield", [(0.0, 0.0), (0.016, 0.002), (0.016, 0.006), (0.0, 0.008)], 8, painted, twist=math.pi / 8)
            far.append(posed(shield, (x0 + 0.016, 0.0258, z0 + dz), (0, 0, 1), math.pi / 2))
    return far


def tent(at_point):
    """The drill-master's tent: its canvas over a ridge pole on two poles,
    its back closed and its door flaps either side of the way in, guyed
    fore and aft, a pennant on its front pole."""
    x0, _, z0 = at_point
    w, d, h = 0.08, 0.11, 0.08
    back, front = z0 - d / 2, z0 + d / 2
    far = [slab("tent canvas", [(x0 - w, 0.0, back), (x0 - w, 0.0, front), (x0, h, front), (x0, h, back)], canvas, 0.004, normal=(-1, 1, 0)),
           slab("tent canvas", [(x0 + w, 0.0, front), (x0 + w, 0.0, back), (x0, h, back), (x0, h, front)], canvas, 0.004, normal=(1, 1, 0)),
           slab("tent back", [(x0 - w + 0.004, 0.0, back + 0.002), (x0 + w - 0.004, 0.0, back + 0.002), (x0, h - 0.004, back + 0.002)], canvas,
                0.003, normal=(0, 0, 1))]
    for side in (-1, 1):
        far.append(slab("tent flap", [(x0 + side * (w - 0.004), 0.0, front - 0.002), (x0 + side * 0.022, 0.0, front - 0.002),
                                      (x0, h - 0.004, front - 0.002)], canvas, 0.003, normal=(0, 0, 1)))
    far.append(rod("ridge pole", (x0, h + 0.002, back - 0.006), (x0, h + 0.002, front + 0.006), 0.0025, dark, sides=4))
    far.append(rod("tent pole", (x0, 0.0, front + 0.004), (x0, h + 0.02, front + 0.004), 0.003, dark, sides=4, caps=(False, True)))
    far.append(rod("tent pole", (x0, 0.0, back - 0.004), (x0, h + 0.006, back - 0.004), 0.003, dark, sides=4, caps=(False, True)))
    flag("tent pennant@1", (x0, h + 0.02, front + 0.004), 0.03, 0.02, banner, turn=0.3)
    fine = [rod("guy rope", (x0, h + 0.012, front + 0.004), (x0, 0.012, front + 0.05), 0.0009, linen, sides=3, caps=(False, False)),
            rod("guy rope", (x0, h + 0.004, back - 0.004), (x0, 0.012, back - 0.046), 0.0009, linen, sides=3, caps=(False, False))]
    return far, fine


def butts(at_point):
    """Archery butts: a straw boss on its frame facing the yard, a ring
    painted on it, arrows in it."""
    x0, _, z0 = at_point
    tilt = math.pi / 2 - 0.15
    far = [rod("butt leg", (x0 - 0.01, 0.0, z0 + dz), (x0 + 0.005, 0.08, z0 + dz), 0.003, dark, sides=4, caps=(False, True)) for dz in (-0.03, 0.03)]
    boss = rings("boss", [(0.0, -0.01), (0.035, -0.008), (0.035, 0.008), (0.0, 0.01)], 10, straw)
    far.append(posed(boss, (x0, 0.05, z0), (0, 0, 1), tilt))
    mark = rings("butt mark", [(0.0, 0.0), (0.02, 0.001), (0.02, 0.002), (0.0, 0.003)], 10, madder)
    fine = [posed(mark, (x0 + 0.012, 0.05, z0), (0, 0, 1), tilt)]
    for dz, dy in ((0.008, 0.004), (-0.012, 0.01), (0.004, -0.01)):
        fine.append(rod("arrow", (x0 + 0.01, 0.05 + dy, z0 + dz), (x0 + 0.05, 0.055 + dy, z0 + dz), 0.0012, pale, sides=3, caps=(False, False)))
    return far, fine


def parade_ground(at_point):
    """The parade ground: flags laid in a broad rectangle a little proud
    of the yard, their joints near."""
    x0, _, z0 = at_point
    far = [block("parade ground", (x0 - 0.11, 0.004, z0 - 0.05), (x0 + 0.11, 0.017, z0 + 0.05), pale_stone)]
    fine = [block("joint", (x0 + x - 0.001, 0.0165, z0 - 0.05), (x0 + x + 0.001, 0.0178, z0 + 0.05), stone) for x in (-0.1, -0.06, -0.02, 0.02, 0.06, 0.1)]
    fine.append(block("joint", (x0 - 0.11, 0.0165, z0 - 0.001), (x0 + 0.11, 0.0178, z0 + 0.001), stone))
    return far, fine


def standard(at_point, name):
    """The House's standard on its tall staff, in a socket of stone, a gilt
    knop atop it."""
    x0, _, z0 = at_point
    far = [block("standard foot", (x0 - 0.015, -0.01, z0 - 0.015), (x0 + 0.015, 0.02, z0 + 0.015), stone, chamfer=0.003),
           rod("standard staff", (x0, 0.0, z0), (x0, 0.3, z0), 0.004, dark, sides=6, caps=(False, True))]
    flag(name, (x0, 0.295, z0), 0.07, 0.05, banner, turn=0.2, tail=True)
    return far, [ball("finial", (x0, 0.305, z0), 0.007, gold)]


# MARK: The buildings

def barracks(at_point, stone_built, width):
    """The barracks: a long hall, its door and windows lit, timber under
    thatch, or stone under slate on a footing with a step up to its door."""
    x0, _, z0 = at_point
    depth, height = 0.12, (0.11 if stone_built else 0.09)
    body, close = hall("barracks", width, depth, height, stone if stone_built else timber, slate if stone_built else thatch, dark,
                       pitch=0.65)
    if stone_built:
        body.append(block("footing", (-width / 2 - 0.012, -0.08, -depth / 2 - 0.012), (width / 2 + 0.012, 0.04, depth / 2 + 0.012), dark_stone,
                          chamfer=0.004))
    for obj in body + close:
        placed(obj, at_point)
    front = z0 + depth / 2
    far, fine = list(body), list(close)
    far.append(lit("door", (x0, 0.045, front + 0.002), 0.035, 0.075, 0.0, dark, depth=0.012))
    if stone_built:
        far.append(block("step", (x0 - 0.026, -0.01, front + 0.012), (x0 + 0.026, 0.026, front + 0.027), pale_stone))
    index = 0
    while -width / 2 + 0.035 + 0.05 * index < width / 2 - 0.02:
        x = -width / 2 + 0.035 + 0.05 * index
        if abs(x) > 0.03:
            far.append(lit("window", (x0 + x, height * 0.6, front + 0.002), 0.016, 0.024, 0.0, window))
        index += 1
    fine.append(box("lintel", (x0, 0.088, front + 0.006), (0.05, 0.01, 0.008), pale_stone if stone_built else dark))
    return far, fine


def armoury(at_point):
    """The armoury: a small house of dark stone on a footing, its ridge
    running back, its door iron-bound looking into the yard, a step up to
    it."""
    x0, _, z0 = at_point
    body, close = hall("armoury", 0.09, 0.1, 0.09, dark_stone, slate, dark, pitch=0.7)
    body.append(block("armoury footing", (-0.057, -0.08, -0.062), (0.057, 0.04, 0.062), stone, chamfer=0.004))
    for obj in body + close:
        placed(obj, at_point, math.pi / 2)
    far, fine = list(body), list(close)
    far.append(lit("armoury door", (x0 - 0.051, 0.0425, z0), 0.03, 0.065, -math.pi / 2, iron, depth=0.02))
    far.append(block("armoury step", (x0 - 0.077, -0.01, z0 - 0.021), (x0 - 0.062, 0.026, z0 + 0.021), pale_stone))
    for y in (0.05, 0.068):
        fine.append(block("door band", (x0 - 0.0625, y - 0.002, z0 - 0.015), (x0 - 0.0605, y + 0.002, z0 + 0.015), steel))
    return far, fine


def drill_tower(at_point):
    """The drill tower: four timber legs on a foot of stone, the platform
    where the drill-master calls railed about, its breastwork to the
    yard, roofed in slate, a ladder up its side."""
    x0, _, z0 = at_point
    far = [block("tower foot", (x0 - 0.04, -0.02, z0 - 0.04), (x0 + 0.04, 0.06, z0 + 0.04), stone, chamfer=0.004)]
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        far.append(rod("tower leg", (x0 + sx * 0.03, 0.06, z0 + sz * 0.03), (x0 + sx * 0.03, 0.27, z0 + sz * 0.03), 0.006, dark, sides=4,
                       caps=(False, False)))
    far.append(box("tower platform", (x0, 0.2, z0), (0.085, 0.01, 0.085), pale))
    far.append(block("tower breastwork", (x0 - 0.04, 0.205, z0 + 0.036), (x0 + 0.04, 0.2425, z0 + 0.04), timber))
    far.append(block("tower rail", (x0 - 0.04, 0.236, z0 - 0.036), (x0 - 0.036, 0.242, z0 + 0.036), timber))
    far.append(block("tower rail", (x0 - 0.036, 0.236, z0 - 0.04), (x0 + 0.036, 0.242, z0 - 0.036), timber))
    far.append(hip_roof("tower roof", (x0, z0), 0.1, 0.1, 0.27, 0.05, slate, overhang=0.008, thickness=0.008))
    return far, ladder("tower ladder", (x0 + 0.066, 0.012, z0), (x0 + 0.047, 0.215, z0), 0.025, 5, pale)


def gatehouse(at_point):
    """The gatehouse of the fifth level: two round towers under slate,
    their banners flown from the finials, lit windows looking back over
    the yard, the gate between them under a walk with its merlons."""
    x0, _, z0 = at_point
    far, fine = [], []
    for side, x in (("west", -0.08), ("east", 0.08)):
        body, close = round_house("gate tower", 0.04, 0.2, stone, slate, pale_stone, dark, rise=0.07, sides=10)
        # The finial is the banner's pole, seen from afar.
        body.append(close.pop())
        for obj in body + close:
            placed(obj, (x0 + x, 0.0, z0))
        far += body
        fine += close
        far.append(lit("tower window", (x0 + x, 0.13, z0 - 0.04), 0.01, 0.026, math.pi, window))
        flag("tower banner %s@5" % side, (x0 + x, 0.3, z0), 0.04, 0.03, banner, turn=math.pi if x > 0 else 0.0)
    far.append(block("gate walk", (x0 - 0.05, 0.1, z0 - 0.025), (x0 + 0.05, 0.16, z0 + 0.025), stone, chamfer=0.003))
    far.append(merlons("gate merlons", (x0 - 0.05, 0.16, z0 + 0.02), (x0 + 0.05, 0.16, z0 + 0.02), 4, (0.015, 0.02, 0.01), stone))
    for sx in (-1, 1):
        far.append(block("gate jamb", (x0 + min(sx * 0.023, sx * 0.045), -0.01, z0 - 0.02), (x0 + max(sx * 0.023, sx * 0.045), 0.1, z0 + 0.02),
                         stone))
    far.append(lit("gate", (x0, 0.05, z0 + 0.026), 0.05, 0.1, 0.0, dark, depth=0.02))
    return far, fine


def drum():
    """The war drum on its stand, its skin of linen, hooped."""
    x0, _, z0 = DRUM
    far = [rod("drum leg", (x0 + dx, 0.0, z0 + dz), (x0, 0.062, z0), 0.003, dark, sides=4, caps=(False, False))
           for dx, dz in ((-0.03, -0.03), (0.03, -0.03), (0.0, 0.035))]
    far.append(rings("drum", [(0.035, 0.06), (0.038, 0.08), (0.035, 0.1)], 12, madder, caps=(True, False), centre=(x0, z0)))
    far.append(rings("drumhead", [(0.035, 0.0995), (0.0355, 0.101)], 12, linen, caps=(False, True), centre=(x0, z0)))
    fine = [rings("drum hoop", [(0.0372, 0.06), (0.0372, 0.0665), (0.0357, 0.0675)], 12, timber, caps=(False, False), centre=(x0, z0)),
            rings("drum hoop", [(0.0355, 0.0935), (0.0372, 0.0945), (0.0372, 0.1015), (0.0355, 0.1015)], 12, timber, caps=(False, False),
                  centre=(x0, z0))]
    return far, fine


def drumstick():
    """The drumstick on its post beside the drum, beating the drill: made
    raised, it comes down on the skin at the height of its swing."""
    px, py, pz = BEAT
    stick = [rod("beater", (0.0, 0.0, 0.0), (-0.045, -0.01, 0.0), 0.0025, pale, sides=4, caps=(True, False)),
             ball("beater head", (-0.047, -0.011, 0.0), 0.006, leather)]
    obj = posed(join(tagged("drumstick beater", ["5"]), stick), BEAT, (0, 0, 1), -RAISED)
    on(obj, rig, "drumstick@5")
    return [rod("drumstick post", (px, 0.0, pz), (px, py - 0.002, pz), 0.003, dark, sides=4, caps=(False, True))]


# MARK: The levels

far, fine = pells([-0.08, -0.02], 0.12)
more, close = tent((-0.08, 0, -0.15))
piece("musterhall", [1], far + rack((-0.2, 0, 0.08)) + more, fine + close)

far, fine = barracks((-0.04, 0, -0.14), False, 0.26)
more, close = pells([-0.12, -0.06], 0.14)
butt, butt_close = butts((-0.22, 0, 0.06))
piece("musterhall", [2], far + more + butt + rack((0.21, 0, -0.04)), fine + close + butt_close)

far, fine = barracks((-0.04, 0, -0.14), True, 0.27)
house, house_close = armoury((0.2, 0, -0.08))
more, close = pells([-0.14, -0.08, -0.02], 0.15)
butt, butt_close = butts((-0.22, 0, 0.05))
piece("musterhall", [3], far + house + more + butt, fine + house_close + close + butt_close)

far, fine = barracks((-0.06, 0, -0.14), True, 0.24)
tower, tower_close = drill_tower((0.19, 0, -0.13))
ground_far, ground_close = parade_ground((-0.06, 0, 0.1))
staff, staff_close = standard((-0.21, 0, 0.17), "standard banner@4")
butt, butt_close = butts((-0.24, 0, 0.0))
more, close = pells([0.0, 0.05], 0.22)
piece("musterhall", [4], far + tower + ground_far + staff + butt + rack((0.22, 0, 0.04)) + more,
      fine + tower_close + ground_close + staff_close + butt_close + close)

far, fine = barracks((0.0, 0, -0.17), True, 0.24)
gate, gate_close = gatehouse((-0.06, 0, 0.02))
ground_far, ground_close = parade_ground((-0.06, 0, 0.17))
beat, beat_close = drum()
more, close = pells([0.18, 0.23], 0.05)
staff, staff_close = standard((0.12, 0, 0.24), "standard banner east@5")
other, other_close = standard((-0.22, 0, 0.17), "standard banner west@5")
piece("musterhall", [5], far + gate + ground_far + beat + drumstick() + rack((-0.22, 0, -0.02)) + more + staff + other,
      fine + gate_close + ground_close + beat_close + close + staff_close + other_close)

far, fine = stakes(0.05)
piece("stakes", [1, 2], far, fine)
far, fine = stakes(0.06)
piece("stakes", [3, 4, 5], far, fine)

# The quintain's post, and its pin, at every level; each level's arm on its
# own part.
rings("quintain post", [(0.0065, -0.02), (0.0065, 0.117)], 6, dark, caps=(False, True), centre=(QUINTAIN[0], QUINTAIN[2]))
join("yard close!fine", scuffs() + [rings("quintain pin", [(0.0022, PIVOT[1] - 0.003), (0.0022, PIVOT[1] + 0.0045)], 6, iron, caps=(False, True),
                                          centre=(PIVOT[0], PIVOT[2]))])
for level in LEVELS:
    quintain_arm(level)

# The quintain spinning on its post as it is struck, at every level; at the
# fifth the drumstick beating the drill.
idle(rig, turns=[("quintain@%d" % level, (0, 1, 0), lambda u: 1.2 * swing(u)) for level in LEVELS] +
     [("drumstick@5", (0, 0, 1), lambda u: 0.4 * swing(u))])

finish_building(out_path("Art/models/musterhall.glb"), [str(level) for level in LEVELS])
