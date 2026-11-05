"""The carters who haul a hold's timber from its sawpit and its stone from
its quarry, between the shafts of a handcart as a founder pulls his: plain
folk in wool and linen with a band of their House's colour at the waist,
each a variant of one file on the body every person on foot shares
(person.py):
- the timber carter, in a padded jerkin under a wool hood, logs laid along
  the cart, three below and two above, lashed down;
- the stone carter, in wool, bare-headed, dressed blocks on the cart, two
  below and one across them, a mallet laid by.

    python Art/blender/carters.py Art/models/carters.glb

Drawn as tall as the townsfolk (folk.py), hauling the founder's handcart
with a longer stride than theirs (Folk.cartStride in the game), its wheels
made as big as turn once a march period at that pace. The cart is the
rig's `extra` bone, at the root, its wheels the bones after the body's
(Cart, in Sources/NullmereModels/Gait.swift).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from carts import *
from common import *
from person import *

reset()
NAMES = "timber,stone"
BUILD = Build(girth=0.95, lean=True)
FOLK = 0.27 / 1.8
WALKING = gait_pace(0.27, 0.49)
RADIUS = WALKING / (2 * math.pi * FOLK)
AXLE = Vector((0, 1.116, RADIUS))
SPREAD = 0.486
BED_FRONT, BED_BACK = 0.594, 1.71
BED = RADIUS + 0.30
moved = {"extra": (tuple(AXLE), tuple(AXLE + Vector((0, 0, 0.1))), None)}
WHEELS = [("wheelL", (SPREAD, AXLE.y, AXLE.z), (SPREAD, AXLE.y, AXLE.z + 0.1), "extra"),
          ("wheelR", (-SPREAD, AXLE.y, AXLE.z), (-SPREAD, AXLE.y, AXLE.z + 0.1), "extra")]
man = Person("Carter", NAMES, BUILD, moved=moved, more_bones=WHEELS)
rig, p, g, a = man.rig, man.p, man.g, man.ax

pale = material("plain_timber_pale", (0.66, 0.54, 0.38))
dark = material("plain_timber_dark", (0.34, 0.24, 0.15))
bark = material("plain_timber_bark", (0.30, 0.22, 0.15))
rope = material("plain_rope", (0.70, 0.64, 0.50))
padded = material("plain_padded", (0.58, 0.50, 0.36))
dark_wool = material("plain_darkwool", (0.18, 0.17, 0.16))
dressed = material("plain_stone_dressed", (0.70, 0.68, 0.62))
grey = material("plain_stone_grey", (0.52, 0.51, 0.48))

# MARK: The carters

man.body(hands=[("", p.skin)], face=None, belt=False)
man.face("@timber")
man.face("@stone", beard=False)
man.coat("@timber", padded, p.wool, p.linen, hem=0.54)
man.coat("@stone", p.wool, dark_wool, p.linen, hem=0.54)
bind(loft("band", [((0, 0.0, 1.0), g(0.178), g(0.124), {"hips": 0.5, "torso": 0.5}),
                   ((0, 0.0, 0.955), g(0.182), g(0.127), {"hips": 1.0})],
          segments=man.far(8), mat=p.tunic, caps=(False, False)), rig)
man.hood("@timber", p.wool)
man.crown("hair", "@stone", p.hair, 0.005, 0.085, -0.10)

# MARK: The handcart, on the extra bone at the rig's root

handcart(rig, p, "handcart", (a(0.30), 0.0, 0.73), BED_FRONT, BED_BACK, BED, p.shaft, pale)
wheel_pair(rig, p, AXLE, SPREAD, "", p.shaft, rimmed=False, hub=dark, radius=RADIUS)
top = BED + 0.05

# The timber: logs along the bed, their tails over its end, three below and
# two above; close, their cut ends pale, the stubs of lopped branches, and
# the cords over them.
LOGS = [(-0.25, 0.10, 0.10), (0.0, 0.10, 0.105), (0.25, 0.10, 0.10), (-0.125, 0.285, 0.095), (0.125, 0.285, 0.098)]
y0, y1 = BED_FRONT + 0.04, BED_BACK + 0.24
logs = [loft("log", [((x, y0, top + z), r, r, {}), ((x, y1, top + z), r, r, {})], segments=5, mat=bark, caps=(True, True))
        for x, z, r in LOGS]
hang(join("logs@timber", logs), rig, "extra")
close = []
for x, z, r in LOGS:
    for y, dy in ((y0, -0.006), (y1, 0.006)):
        close.append(solid("end", "cylinder", mat=pale, vertices=8, radius=r * 0.94, depth=0.012, location=(x, y + dy, top + z),
                           rotation=(90, 0, 0)))
for x, z, r, y, s in ((-0.25, 0.10, 0.10, 1.2, 1), (0.125, 0.285, 0.098, 0.9, -1), (0.0, 0.10, 0.105, 1.55, 1)):
    close.append(solid("stub", "cone", mat=bark, vertices=5, radius1=0.022, depth=0.07, location=(x + s * (r + 0.02), y, top + z + 0.02),
                       rotation=(0, s * 70, 0)))
for y in (BED_FRONT + 0.30, BED_BACK - 0.22):
    close.append(beam("cord", Vector((-0.39, y, top)), Vector((-0.24, y, top + 0.40)), 0.022, rope))
    close.append(beam("cord", Vector((-0.24, y, top + 0.40)), Vector((0.24, y, top + 0.40)), 0.022, rope))
    close.append(beam("cord", Vector((0.24, y, top + 0.40)), Vector((0.39, y, top)), 0.022, rope))
hang(join("logs close@timber!fine", close), rig, "extra")

# The stone: two dressed blocks below and one across them; close, their
# arrises knocked back, rubble wedged between, and a mallet laid on top.
BLOCKS = [(-0.19, BED_FRONT + 0.52, 0.11, (0.31, 0.50, 0.22), dressed), (0.19, BED_FRONT + 0.56, 0.11, (0.30, 0.46, 0.22), grey),
          (0.0, BED_FRONT + 0.54, 0.31, (0.46, 0.32, 0.18), dressed)]
blocks = [solid("block", "box", mat=mat, location=(x, y, top + z), size=size) for x, y, z, size, mat in BLOCKS]
hang(join("blocks@stone", blocks), rig, "extra")
close = []
for x, y, z, (w, d, h), mat in BLOCKS:
    for sx in (-1, 1):
        close.append(beam("arris", Vector((x + sx * w / 2, y - d / 2 + 0.01, top + z + h / 2)),
                          Vector((x + sx * w / 2, y + d / 2 - 0.01, top + z + h / 2)), 0.03, mat))
close += [solid("rubble", "sphere", mat=grey, segments=5, rings=3, radius=(0.05, 0.045, 0.04), location=(0.0, BED_FRONT + 0.26, top + 0.04)),
          solid("rubble", "sphere", mat=dressed, segments=5, rings=3, radius=(0.04, 0.05, 0.035), location=(-0.33, BED_FRONT + 0.92, top + 0.03)),
          solid("rubble", "sphere", mat=grey, segments=5, rings=3, radius=(0.045, 0.04, 0.035), location=(0.32, BED_FRONT + 0.95, top + 0.03))]
mallet = [loft("haft", [((0.06, BED_FRONT + 0.40, top + 0.41), 0.012, 0.012, {}), ((0.06, BED_FRONT + 0.72, top + 0.41), 0.012, 0.012, {})],
               segments=4, mat=p.shaft, caps=(True, True)),
          solid("head", "box", mat=dark, location=(0.06, BED_FRONT + 0.74, top + 0.43), size=(0.14, 0.07, 0.08))]
hang(join("blocks close@stone!fine", close + mallet), rig, "extra")

# MARK: The clips: at the shafts, walking on with the cart, loading it

AT_SHAFTS = dict(hidden=["tool"], shown=["heldR", "heldL"])
CARRY = {"armR": (6, 0, 3), "forearmR": (-8, 0, 0), "armL": (6, 0, -3), "forearmL": (-8, 0, 0), "torso": (10, 0, 0), "head": (-8, 0, 0)}
IDLE = {f: merge(CARRY, {"head": (-8 + 3 * math.sin(4 * math.pi * f / 120), 0, 20 * math.sin(2 * math.pi * f / 120)),
                         "torso": (6 + 2 * math.sin(2 * math.pi * f / 60), 0, 0)})
        for f in range(0, 121, 10)}
keyed(rig, "idle", 120, IDLE, **AT_SHAFTS)
man.march(CARRY, lambda side: {"torso": (14, 0, 0)}, **AT_SHAFTS, reach=reach(WALKING, 0.27), more=rolling)
roll_evenly(rig, "march")


def smooth(t):
    return t * t * (3 - 2 * t)


def between(keys, f):
    """The share at frame `f` along keys [(frame, share)], eased."""
    for (f0, a0), (f1, a1) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            return a0 + (a1 - a0) * smooth((f - f0) / (f1 - f0))
    return keys[-1][1]


# Out of the shafts, a step to the side of the cart to load it: bent to
# lift a log or a block from the ground, then raised and turned to lay it
# on the bed behind.
ASIDE = {"hips": {"turn": (0, 0, 0), "shift": (0.56, -0.1, -0.03)}}


def loading(f):
    lift = between([(0, 0.0), (16, 0.0), (32, 1.0), (40, 1.0), (52, 0.0), (60, 0.0)], f)
    bend = between([(0, 1.0), (14, 1.0), (30, 0.0), (44, 0.0), (58, 1.0), (60, 1.0)], f)
    return merge(ASIDE, {"torso": (12 + 44 * bend, 0, 40 * lift), "head": (-10 - 10 * bend, 0, 16 * lift),
                         "hips": {"turn": (0, 0, 30 * lift), "shift": (0.56, -0.1, -0.03 - 0.12 * bend)},
                         "thighL": (-40 * bend, 0, 0), "shinL": (60 * bend, 0, 0), "thighR": (-30 * bend, 0, 0), "shinR": (52 * bend, 0, 0),
                         "armL": (-50 - 40 * lift, 0, -14 + 10 * lift), "forearmL": (-30 - 30 * lift, 0, 0),
                         "armR": (-50 - 40 * lift, 0, 14 - 10 * lift), "forearmR": (-30 - 30 * lift, 0, 0)})


keyed(rig, "gather", 60, {f: loading(f) for f in range(0, 61, 3)}, hidden=["heldR", "heldL"], shown=["tool"])


def brandishing(f):
    """Roused at the shafts: the right hand off its shaft, a fist shaken."""
    up = between([(0, 0.0), (8, 1.0), (37, 1.0), (45, 0.0)], f)
    shake = math.sin(2 * math.pi * f / 15) * up
    return merge(CARRY, {"armR": (6 - 150 * up, 0, 3 + 14 * up), "forearmR": (-8 - 40 * up + 20 * shake, 0, 0), "torso": (10 - 10 * up, 0, -6 * up),
                         "head": (-8 - 8 * up, 0, 0)})


keyed(rig, "attack", 45, {f: brandishing(f) for f in range(0, 46, 3)}, **AT_SHAFTS)


def flinching(share):
    """Struck: rocked back against the shafts, an arm thrown up."""
    return merge(CARRY, {"torso": (10 - 22 * share, 0, -10 * share), "head": (-8 - 10 * share, 0, 20 * share),
                         "hips": {"turn": (0, 0, -3 * share), "shift": (0, 0.04 * share, -0.02 * share)},
                         "thighR": (12 * share, 0, 0), "shinR": (14 * share, 0, 0), "thighL": (-10 * share, 0, 0), "shinL": (18 * share, 0, 0),
                         "armR": (6 - 70 * share, 0, 3 + 30 * share), "forearmR": (-8 - 80 * share, 0, 0)})


keyed(rig, "hit", 45, {0: flinching(0), 3: flinching(0.15), 6: flinching(1.0), 14: flinching(0.7), 25: flinching(0.25), 32: flinching(0.05),
                       36: flinching(0), 45: flinching(0)}, **AT_SHAFTS)
# Down: stumbling forward out of the shafts to fall on the face before the
# cart, which stands where it was let go.
FACE_DOWN = {"hips": {"turn": (88, 0, -4), "shift": (0, -0.14, -0.74)}, "torso": (6, 0, 0), "head": (-30, 0, 14),
             "thighL": (8, 0, 0), "shinL": (14, 0, 0), "thighR": (4, 0, 0), "shinR": (10, 0, 0), "footL": (20, 0, 0), "footR": (16, 0, 0),
             "armL": (-150, -20, 0), "forearmL": (-10, 0, 0), "armR": (-140, 20, 0), "forearmR": (-14, 0, 0)}
DEATH = {0: CARRY,
         6: merge(CARRY, {"torso": (24, 0, 0), "head": (6, 0, 0)}),
         11: merge(CARRY, {"torso": (30, 0, 0), "hips": {"turn": (8, 0, 0), "shift": (0, -0.03, -0.04)}, "thighL": (-20, 0, 0),
                           "shinL": (30, 0, 0), "thighR": (-14, 0, 0), "shinR": (24, 0, 0)}),
         22: {"hips": {"turn": (45, 0, -2), "shift": (0, -0.08, -0.38)}, "torso": (20, 0, 0), "head": (-10, 0, 8), "thighL": (-30, 0, 0),
              "shinL": (50, 0, 0), "thighR": (-24, 0, 0), "shinR": (44, 0, 0), "armL": (-70, -10, 0), "armR": (-66, 10, 0)},
         36: FACE_DOWN, 38: FACE_DOWN, 45: FACE_DOWN}
keyed(rig, "death", 45, DEATH, **AT_SHAFTS)

man.finish(out_path("Art/models/carters.glb"), [(1, name) for name in NAMES.split(",")])
