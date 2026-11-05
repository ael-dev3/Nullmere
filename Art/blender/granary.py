"""The Granary, where the House's grain is threshed, dried and kept, its five
levels the tiers of one file, each within a work's slot and facing +z:
1. a granary of wattle and daub raised on staddle stones against the rats,
   under thatch, sacks heaped at its steps, sheaves stooked;
2. a timber barn beside it, its loft door and the sack hoist over it, a
   threshing floor of beaten earth before its doors;
3. the barn rebuilt in stone under slate on a footing, a round grain bin
   hooped in iron under a cone, a winnowing floor of flags;
4. a row of tall bins, drying racks hung with sheaves, a wain waiting to be
   loaded;
5. a great tithe barn, buttressed, a louvre on its ridge, the House's
   banners at its doors, a dovecote on its post.
Close: wattle under the daub, the doors' boards and hinges, battens, hoops,
ladders, flails, the grain spread on the floor and chaff about the yard.
The sack hoist swings at the loft door as the grain goes up.

    python Art/blender/granary.py Art/models/granary.glb
"""
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
stone = material("plain_stone", (0.52, 0.51, 0.49))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
white = material("plain_stone_white", (0.84, 0.84, 0.82))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
slate = material("plain_slate", (0.23, 0.24, 0.28))
daub = material("plain_daub", (0.61, 0.56, 0.47))
weld = material("plain_weld", (0.55, 0.49, 0.27))
canvas = material("plain_canvas", (0.6, 0.55, 0.45))
linen = material("plain_linen", (0.7, 0.67, 0.6))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))

HOISTS = {1: (0.0, 0.17, 0.035), 2: (-0.06, 0.17, -0.007), 3: (-0.05, 0.18, -0.017), 4: (-0.07, 0.19, -0.017), 5: (-0.05, 0.23, -0.002)}
rig = work_rig([("sack hoist@%d" % level, pivot, (0, 1, 0)) for level, pivot in HOISTS.items()])
ground(pad(tagged("pad", []), 0.31, yard), rig)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


def staddle_granary(at_point, thatched):
    """A little granary on mushroom-capped staddle stones, its walls of
    wattle under daub, its door at the top of three steps."""
    x0, _, z0 = at_point
    far, fine = [], []
    for dx, dz in ((-0.06, -0.05), (0.06, -0.05), (-0.06, 0.05), (0.06, 0.05), (0.0, -0.05), (0.0, 0.05)):
        far.append(rings("staddle", [(0.012, 0.0), (0.008, 0.035), (0.0, 0.036)], 6, stone, centre=(x0 + dx, z0 + dz)))
        far.append(rings("cap", [(0.0, 0.035), (0.02, 0.036), (0.018, 0.046), (0.0, 0.047)], 6, pale_stone, centre=(x0 + dx, z0 + dz)))
    body, close = hall("granary", 0.15, 0.12, 0.09, daub, thatch if thatched else slate, dark, pitch=0.75)
    for obj in body + close:
        placed(obj, (x0, 0.047, z0))
    far += body
    fine += close
    far.append(block("door", (x0 - 0.0175, 0.06, z0 + 0.06), (x0 + 0.0175, 0.12, z0 + 0.064), dark))
    for step in range(3):
        y = 0.012 + step * 0.014
        z = z0 + 0.085 - step * 0.012
        far.append(block("step", (x0 - 0.025, y - 0.004, z - 0.007), (x0 + 0.025, y + 0.004, z + 0.007), grey))
    for x in (-0.06, -0.03, 0.0, 0.03, 0.06):
        fine.append(block("wattle", (x0 + x - 0.0015, 0.05, z0 + 0.06), (x0 + x + 0.0015, 0.13, z0 + 0.062), dark))
    return far, fine


def barn(at_point, stone_built, width, height, depth=0.15, great=False):
    """A barn of timber or stone, gabled, its great doors and its loft door
    high in the gable over them."""
    x0, _, z0 = at_point
    wall = pale_stone if stone_built else timber
    roof = slate if (stone_built or great) else thatch
    body, close = hall("barn", width, depth, height, wall, roof, dark, pitch=0.75, footing=stone if (stone_built or great) else None)
    for obj in body + close:
        placed(obj, at_point)
    far, fine = list(body), list(close)
    door_w, door_h = (0.09, 0.12) if great else (0.08, 0.1)
    far.append(block("doors", (x0 - door_w / 2, 0.0, z0 + depth / 2), (x0 + door_w / 2, door_h, z0 + depth / 2 + 0.004), dark))
    loft = 0.04 if great else 0.035
    far.append(block("loft door", (x0 - loft / 2, height + 0.025 - loft / 2 + (0.005 if great else 0), z0 + depth / 2),
                     (x0 + loft / 2, height + 0.025 + loft / 2 + (0.005 if great else 0), z0 + depth / 2 + 0.004), dark))
    lights = [(-width * 0.36, height * 0.6, 0.018, 0.04), (width * 0.36, height * 0.6, 0.018, 0.04)] if great else \
        [(-width * 0.33, height * 0.65, 0.02, 0.026)]
    for x, y, w, h in lights:
        far.append(lit("window", (x0 + x, y, z0 + depth / 2 + 0.002), w, h, 0.0, window))
    for x in [-0.035 + 0.014 * k for k in range(6)]:
        fine.append(block("board", (x0 + x - 0.0015, 0.0, z0 + depth / 2 + 0.004), (x0 + x + 0.0015, door_h - 0.002, z0 + depth / 2 + 0.008), timber))
    for y in (0.025, 0.075):
        fine.append(block("hinge", (x0 - door_w / 2 + 0.001, y - 0.0025, z0 + depth / 2 + 0.006), (x0 + door_w / 2 - 0.001, y + 0.0025,
                                                                                                    z0 + depth / 2 + 0.01), iron))
    if not stone_built and not great:
        x = -width / 2 + 0.02
        while x < width / 2:
            fine.append(block("batten", (x0 + x - 0.002, 0.0, z0 - depth / 2 - 0.004), (x0 + x + 0.002, height, z0 - depth / 2 - 0.001), dark))
            x += 0.025
    return far, fine


def bins(xs, z, height):
    """Round grain bins under cones, hooped in iron, a ladder up each."""
    far, fine = [], []
    for x in xs:
        body, close = round_house("bin", 0.04, height, pale, slate, dark, dark, rise=0.05, sides=10)
        for obj in body + close:
            placed(obj, (x, 0, z))
        far += body
        fine += close
        y = 0.035
        while y < height:
            fine.append(rings("hoop", [(0.0405, y), (0.043, y + 0.002), (0.043, y + 0.006), (0.0405, y + 0.008)], 10, iron, centre=(x, z),
                              caps=(False, False)))
            y += 0.06
        fine += ladder("ladder", (x, 0, z + 0.045), (x, height, z + 0.042), 0.016, int(height / 0.03), dark)
    return far, fine


def threshing_floor(at_point, flagged):
    """The threshing floor before the doors, beaten earth or flags laid,
    the grain spread on it and two flails laid by."""
    x0, _, z0 = at_point
    far = [block("floor", (x0 - 0.085, 0.0, z0 - 0.045), (x0 + 0.085, 0.01, z0 + 0.045), pale_stone if flagged else earth)]
    fine = []
    if flagged:
        for x in (-0.07, -0.035, 0.0, 0.035, 0.07):
            for z in (-0.022, 0.022):
                fine.append(block("flag", (x0 + x - 0.016, 0.01, z0 + z - 0.02), (x0 + x + 0.016, 0.011, z0 + z + 0.02), stone))
    fine.append(rings("grain", [(0.0, 0.009), (0.04, 0.011), (0.03, 0.0145), (0.0, 0.0155)], 7, weld, centre=(x0 + 0.02, z0)))
    for z in (-0.03, 0.03):
        fine.append(rod("flail", (x0 - 0.07, 0.012, z0 + z), (x0 - 0.02, 0.012, z0 + z + 0.01), 0.003, pale, sides=4))
        fine.append(rod("swipple", (x0 - 0.02, 0.012, z0 + z + 0.01), (x0, 0.012, z0 + z + 0.02), 0.004, timber, sides=4))
    return far, fine


def sacks(at_point, count):
    out = []
    for index in range(count):
        angle = index * 1.9
        p = (at_point[0] + 0.025 * math.cos(angle), at_point[1] + (index // 3) * 0.022, at_point[2] + 0.025 * math.sin(angle))
        out.append(tied_sack("sack", p, 0.022, canvas))
    return out


def drying_rack(at_point):
    x0, _, z0 = at_point
    far = [rod("rack post", (x0 + x, 0, z0), (x0 + x, 0.12, z0), 0.004, dark, sides=4) for x in (-0.05, 0.05)]
    for y in (0.05, 0.1):
        far.append(lath("rack rail", (x0 - 0.055, y, z0), (x0 + 0.055, y, z0), 0.004, 0.004, timber))
        for x in (-0.04, -0.02, 0.0, 0.02, 0.04):
            far.append(rings("sheaf", [(0.008, y - 0.035), (0.0, y)], 5, weld, centre=(x0 + x, z0)))
    return far


def wain(at_point):
    """A wain waiting to be loaded: its bed, four wheels and shafts."""
    pieces = [block("bed", (-0.05, 0.03, -0.025), (0.05, 0.045, 0.025), timber)]
    for x in (-0.035, 0.035):
        for z in (-0.028, 0.028):
            pieces += wheel("wheel", (x, 0.02, z), 0.02, 0.006, 2, dark, axis="z")
    pieces.append(lath("shaft", (0.05, 0.035, -0.012), (0.11, 0.015, -0.012), 0.004, 0.004, dark))
    pieces.append(lath("shaft", (0.05, 0.035, 0.012), (0.11, 0.015, 0.012), 0.004, 0.004, dark))
    pieces.append(tied_sack("sack", (-0.02, 0.045, 0), 0.02, canvas))
    for obj in pieces:
        placed(obj, at_point, 0.3)
    return pieces


def dovecote(at_point):
    x0, _, z0 = at_point
    far = [rod("post", (x0, 0, z0), (x0, 0.12, z0), 0.008, dark, sides=6)]
    body, close = round_house("dovecote", 0.035, 0.05, white, slate, pale_stone, dark, rise=0.04, sides=8)
    for obj in body + close:
        placed(obj, (x0, 0.12, z0))
    far += body
    fine = list(close)
    for index in range(8):
        angle = index / 8 * 2 * math.pi
        for y in (0.135, 0.155):
            x, z = x0 + 0.0355 * math.cos(angle), z0 - 0.0355 * math.sin(angle)
            fine.append(block("hole", (x - 0.004, y - 0.0035, z - 0.002), (x + 0.004, y + 0.0035, z + 0.002), dark, turn=-angle, about=(x, y, z)))
    return far, fine


def stook(at_point, count):
    return stooks("stook", at_point, count, weld, thatch)


def hoist(level):
    """The sack hoist at the loft door: its arm out over the door and a sack
    on the rope."""
    x, y, z = HOISTS[level]
    pieces = [lath("hoist arm", (x, y, z), (x, y, z + 0.07), 0.008, 0.008, dark),
              rod("rope", (x, y - 0.004, z + 0.066), (x, y - 0.07, z + 0.066), 0.0018, linen, sides=3),
              tied_sack("hoist sack", (x, y - 0.095, z + 0.066), 0.02, canvas)]
    obj = join(tagged("hoist", level_tags([level])), pieces)
    on(obj, rig, "sack hoist@%d" % level)


# MARK: The levels

far, fine = staddle_granary((0, 0, -0.04), True)
piece("granary", [1], far + sacks((0.12, 0, 0.14), 4) + stook((-0.17, 0, 0.14), 3), fine)

far, fine = barn((-0.06, 0, -0.09), False, 0.24, 0.13)
more, close = staddle_granary((0.16, 0, -0.09), True)
floor, floor_close = threshing_floor((-0.06, 0, 0.12), False)
piece("granary", [2], far + more + floor + stook((0.19, 0, 0.16), 4), fine + close + floor_close)

far, fine = barn((-0.05, 0, -0.1), True, 0.26, 0.14)
more, close = bins([0.2], -0.1, 0.15)
floor, floor_close = threshing_floor((-0.05, 0, 0.12), True)
piece("granary", [3], far + more + floor + sacks((0.17, 0, 0.14), 7) + stook((-0.22, 0, 0.17), 2), fine + close + floor_close)

far, fine = barn((-0.07, 0, -0.1), True, 0.26, 0.15)
more, close = bins([0.17, 0.25], -0.12, 0.2)
floor, floor_close = threshing_floor((0.02, 0, 0.13), True)
piece("granary", [4], far + more + floor + drying_rack((0.2, 0, 0.1)) + wain((-0.12, 0, 0.17)), fine + close + floor_close)

# The great tithe barn: long and high, buttressed, a louvre on its ridge,
# the House's banners at its doors.
width, depth, height = 0.3, 0.17, 0.17
x0, z0 = -0.05, -0.1
far, fine = barn((x0, 0, z0), True, width, height, depth=depth, great=True)
for x in (-width / 2, -width / 6, width / 6, width / 2):
    for side in (-1, 1):
        far.append(block("buttress", (x0 + x - 0.011, -0.03, z0 + side * (depth / 2 + 0.014) - 0.013),
                         (x0 + x + 0.011, height * 0.8 + 0.03, z0 + side * (depth / 2 + 0.014) + 0.013), stone))
ridge = height + depth * 0.75
far.append(block("louvre", (x0 - 0.02, ridge, z0 - 0.02), (x0 + 0.02, ridge + 0.04, z0 + 0.02), grey))
far.append(hip_roof("louvre roof", (x0, z0), 0.05, 0.05, ridge + 0.04, 0.04, slate, overhang=0.006))
for x in (-0.06, 0.06):
    far.append(rod("banner rod", (x0 + x, height * 0.85, z0 + depth / 2 + 0.01), (x0 + x, height * 0.85, z0 + depth / 2 + 0.06), 0.003, iron,
                   sides=4))
    flag("banner %s@5" % ("L" if x > 0 else "R"), (x0 + x, height * 0.85, z0 + depth / 2 + 0.058), 0.035, 0.08, banner, turn=-math.pi / 2,
         tail=True)
more, close = bins([0.2, 0.27], -0.06, 0.22)
cote, cote_close = dovecote((0.2, 0, 0.16))
piece("granary", [5], far + more + cote + sacks((-0.06, 0, 0.18), 6), fine + close + cote_close)

for level in LEVELS:
    hoist(level)

# Chaff and straw strewn about the yard, at every level.
chaff = []
for index in range(16):
    angle = index * 2.39996
    r = 0.1 + 0.18 * ((index * 31) % 13) / 13
    x, z = r * math.cos(angle), r * math.sin(angle)
    chaff.append(lath("straw", (x, 0.013, z), (x + 0.02, 0.013, z + 0.006), 0.003, 0.002, weld if index % 2 == 0 else thatch))
join("chaff!fine", chaff)

# Its sack hoist swinging at the loft door as the grain goes up.
idle(rig, turns=[("sack hoist@%d" % level, (0, 1, 0), lambda u: 0.5 * swing(u)) for level in LEVELS])

finish_building(out_path("Art/models/granary.glb"), [str(level) for level in LEVELS])
