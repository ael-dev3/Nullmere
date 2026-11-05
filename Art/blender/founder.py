"""The founder: a settler going out to raise a new hold, short and stocky
on the body every person on foot shares (person.py), in a linen smock and a
wool skirt under a wool hood and a canvas mantle, between the shafts of the
handcart he pulls behind him: its bed and rails on two wheels, a prop at
its tail, and its load, a barrel, a cask and a sack lashed under the
House's canvas.

    python Art/blender/founder.py Art/models/founder.glb

The cart is the rig's `extra` bone, at the root, so it stands where he let
it go when he falls; its wheels are the bones after the body's, as the game
names them (Cart, in Sources/NullmereModels/Gait.swift). Drawn as short as
a Mangonel's crewman, his wheels and his stride the same as that engine's,
to hold the ground at the pace every company on foot keeps.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from carts import *
from common import *
from person import *

reset()
BUILD = Build(girth=1.12, shoulders=0.94, lean=True)
AXLE = Vector((0, 1.116, WHEEL))
BED_FRONT, BED_BACK = 0.594, 1.71
BED = WHEEL + 0.30
moved = {"extra": (tuple(AXLE), tuple(AXLE + Vector((0, 0, 0.1))), None)}
WHEELS = [("wheelL", (0.486, AXLE.y, AXLE.z), (0.486, AXLE.y, AXLE.z + 0.1), "extra"),
          ("wheelR", (-0.486, AXLE.y, AXLE.z), (-0.486, AXLE.y, AXLE.z + 0.1), "extra")]
man = Person("Founder", "", BUILD, moved=moved, more_bones=WHEELS)
rig, p, g, a = man.rig, man.p, man.g, man.ax

canvas = material("plain_canvas", (0.74, 0.70, 0.60))
pale = material("plain_timber_pale", (0.66, 0.54, 0.38))
dark = material("plain_timber_dark", (0.34, 0.24, 0.15))
rope = material("plain_rope", (0.70, 0.64, 0.50))
sack = material("plain_sack", (0.62, 0.54, 0.40))

# MARK: The settler

man.body(hands=[("", p.skin)], face="")
man.coat("", p.linen, p.wool, p.linen, hem=0.62)
man.hood("", p.wool)
man.mantle("", canvas)
man.mattock()

# MARK: The handcart, on the extra bone at the rig's root

handcart(rig, p, "handcart", (a(0.30), 0.0, 0.73), BED_FRONT, BED_BACK, BED, p.shaft, pale)

# Its load: a barrel and a cask stood up, a sack, and the House's canvas
# drawn over the rest.
top = BED + 0.05
load = [solid("barrel", "cylinder", mat=p.shaft, vertices=6, radius=0.144, depth=0.38, location=(0.0, BED_FRONT + 0.25, top + 0.19)),
        solid("cask", "cylinder", mat=p.shaft, vertices=6, radius=0.135, depth=0.34, location=(0.216, BED_FRONT + 0.52, top + 0.17)),
        solid("sack", "sphere", mat=sack, segments=5, rings=3, radius=(0.16, 0.15, 0.14), location=(-0.19, BED_FRONT + 0.50, top + 0.13))]
hang(join("load", load), rig, "extra")
cover = loft("canvas", [((0, BED_FRONT + 0.72, top), 0.40, 0.42, {}), ((0, BED_FRONT + 0.74, top + 0.25), 0.38, 0.38, {}),
                        ((0, BED_FRONT + 0.76, top + 0.43), 0.24, 0.24, {})], segments=6, mat=p.tunic, caps=(False, True))
hang(cover, rig, "extra")
# Near: hoops round the barrel and cask, the cords lashing the canvas, the
# sack's neck tied.
close = []
for x, y, r, h in ((0.0, BED_FRONT + 0.25, 0.148, 0.38), (0.216, BED_FRONT + 0.52, 0.139, 0.34)):
    for dz in (0.07, h - 0.07):
        close.append(loft("hoop", [((x, y, top + dz - 0.012), r, r, {}), ((x, y, top + dz + 0.012), r, r, {})], segments=10, mat=p.iron,
                          caps=(False, False)))
for dy in (-0.18, 0.18):
    y = BED_FRONT + 0.74 + dy
    close.append(beam("cord", Vector((-0.42, y, top + 0.02)), Vector((0, y, top + 0.44)), 0.022, rope))
    close.append(beam("cord", Vector((0, y, top + 0.44)), Vector((0.42, y, top + 0.02)), 0.022, rope))
close.append(solid("neck", "cylinder", mat=rope, vertices=8, radius=0.04, depth=0.06, location=(-0.19, BED_FRONT + 0.50, top + 0.28)))
hang(join("load close!fine", close), rig, "extra")
wheel_pair(rig, p, AXLE, 0.486, "", p.shaft, rimmed=False, hub=dark)

# MARK: The clips

AT_SHAFTS = dict(hidden=["tool"], shown=["heldR", "heldL"])
# His hands at his sides on the shafts, leaning into them.
CARRY = {"armR": (6, 0, 3), "forearmR": (-8, 0, 0), "armL": (6, 0, -3), "forearmL": (-8, 0, 0), "torso": (10, 0, 0), "head": (-8, 0, 0)}

IDLE = {f: merge(CARRY, {"head": (-8, 0, 18 * math.sin(2 * math.pi * f / 120)), "torso": (6 + 2 * math.sin(2 * math.pi * f / 60), 0, 0)})
        for f in range(0, 121, 10)}
keyed(rig, "idle", 120, IDLE, **AT_SHAFTS)
man.march(CARRY, lambda side: {"torso": (14, 0, 0)}, **AT_SHAFTS, reach=REACH, more=rolling)
roll_evenly(rig, "march")

# Out of the shafts, a step to the side of the cart: to strike, a mattock
# swung high overhead and down, twice; to gather, worked at the ground.
ASIDE = {"hips": {"turn": (0, 0, 0), "shift": (0.56, -0.1, -0.03)}}


def overhead(lift, strike):
    return merge(ASIDE, {"armR": (-40 - 135 * lift + 10 * strike, 0, 9), "armL": (-40 - 135 * lift + 10 * strike, 0, -20),
                         "forearmR": (-20, 0, 0), "forearmL": (-28, 0, 0), "tool": (70 + 50 * lift, 0, 0),
                         "torso": (6 - 16 * lift + 18 * strike, 0, 0), "head": (2 + 4 * strike, 0, 0),
                         "thighL": (-14, 0, 0), "shinL": (17, 0, 0), "thighR": (9, 0, 0), "shinR": (11, 0, 0)})


attack = {}
for half in (0, 22.5):
    attack[half + 0] = overhead(0, 0)
    attack[half + 9] = overhead(1, 0)
    attack[half + 12.5] = overhead(0, 1)
    attack[half + 17] = overhead(0, 1)
attack[45] = overhead(0, 0)
keyed(rig, "attack", 45, attack, hidden=["heldR", "heldL"], shown=["tool"])


def flinching(share):
    """Struck: rocked back against the shafts, an arm thrown up."""
    return merge(CARRY, {"torso": (10 - 22 * share, 0, -10 * share), "head": (-8 - 10 * share, 0, 20 * share),
                         "hips": {"turn": (0, 0, -3 * share), "shift": (0, 0.04 * share, -0.02 * share)},
                         "thighR": (12 * share, 0, 0), "shinR": (14 * share, 0, 0), "thighL": (-10 * share, 0, 0), "shinL": (18 * share, 0, 0),
                         "armR": (6 - 70 * share, 0, 3 + 30 * share), "forearmR": (-8 - 80 * share, 0, 0)})


keyed(rig, "hit", 45, {0: flinching(0), 3: flinching(0.15), 6: flinching(1.0), 14: flinching(0.7), 25: flinching(0.25), 32: flinching(0.05),
                       36: flinching(0), 45: flinching(0)}, **AT_SHAFTS)
# Down: he stumbles forward out of the shafts and falls on his face before
# his cart, which stands where he let it go.
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
man.gather(hidden=["heldR", "heldL"], shown=["tool"], more=lambda frame: ASIDE)

man.finish(out_path("Art/models/founder.glb"), [(1, None)])
