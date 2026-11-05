"""The hollow: the first thing that walks out of the far country, tall and
thin under a shroud and a dark hood, a blank pale mask where a face should
be and two cold eyes in it, rags hanging from its arms, a crooked staff of
dead wood in its hand with a bone charm alight at its head. It glides
slowly, stooped a little, and rakes with its long arms.

    python Art/blender/hollow.py Art/models/hollow.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from person import *
from wild import *

reset()
HEIGHT = 0.34
man = Person("Hollow", "", Build(girth=0.72, shoulders=0.86, lean=True))
rig, p, a = man.rig, man.p, man.ax
ash = material("plain_ash", (0.60, 0.60, 0.58))
bone = material("plain_bone", (0.84, 0.81, 0.72))
shroud = material("plain_shroud", (0.70, 0.70, 0.66))
dark = material("plain_darkwool", (0.14, 0.13, 0.14))
dead = material("plain_deadwood", (0.32, 0.28, 0.24))
glow = material("glow_wild", (0.62, 0.86, 1.0))
p.skin, p.wool, p.leather, p.hair = ash, ash, ash, ash

man.body(hands=[("", bone)], face=None, belt=False)
man.coat("", shroud, dark, ash, long=True, hem=0.16)
man.hood("", dark)
man.mantle("", dark)
# The blank mask in the dark of the hood, and the eyes in it.
mask = solid("mask", "sphere", mat=bone, segments=6, rings=4, radius=(0.085, 0.03, 0.12), location=at_head(0, -0.085, -0.01))
hang(mask, rig, "head")
eyes(man, glow, spread=0.032, forward=-0.112, lift=0.025)
# Rags hanging from the arms, stirring as it moves.
for s, side in ((1, "L"), (-1, "R")):
    rag = solid("rag " + side, "box", mat=shroud, location=(a(s * 0.30), 0.06, 0.86), size=(0.012, 0.09, 0.30))
    sway(rag, lambda q: max(0.0, min(1.0, (0.99 - q.z) / 0.28)))
    hang(rag, rig, "forearm" + side)
# A crooked staff of dead wood, a bone charm alight at its head.
x, y = a(-0.30), -0.02
staff = [loft("staff", [((x, y, 0.04), 0.02, 0.02, {}), ((x - 0.04, y, 1.12), 0.018, 0.018, {})], segments=4, mat=dead, caps=(True, True)),
         loft("crook", [((x - 0.04, y, 1.12), 0.018, 0.018, {}), ((x + 0.09, y - 0.11, 1.62), 0.015, 0.015, {})], segments=4, mat=dead,
              caps=(False, True)),
         loft("hook", [((x + 0.09, y - 0.11, 1.62), 0.014, 0.014, {}), ((x + 0.18, y - 0.22, 1.51), 0.012, 0.012, {})], segments=4, mat=dead,
              caps=(False, True))]
hang(join("staff", staff), rig, "heldR")
hang(solid("charm", "box", mat=glow, location=(x + 0.18, y - 0.22, 1.40), size=(0.05, 0.05, 0.09)), rig, "heldR")
hang(join("charm cord!fine", [loft("cord", [((x + 0.18, y - 0.22, 1.51), 0.005, 0.005, {}), ((x + 0.18, y - 0.22, 1.45), 0.005, 0.005, {})],
                                   segments=4, mat=bone, caps=(False, False))]), rig, "heldR")
man.mattock()

# MARK: The clips

# The staff held upright in the right hand, the left arm hanging.
CARRY = {"armR": (-12, 0, -3), "forearmR": (-28, 0, 0), "heldR": (40, 0, 0), "armL": (-8, 0, -4), "forearmL": (-14, 0, 0)}
clips(man, CARRY, reach(gait_pace(HEIGHT, 0.38), HEIGHT), 7, raking, recoiling, searching)
man.finish(out_path("Art/models/hollow.glb"), [(1, None)])
