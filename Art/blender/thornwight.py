"""The thornwight: the second thing of the far country, stooped and
bark-black, its back hung with moss, a crown of dead antlers branching
from its brow, cold eyes in a face of bark and claws of bone at its hands.
It prowls with long strides, bent low, and rakes with its claws.

    python Art/blender/thornwight.py Art/models/thornwight.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from person import *
from wild import *

reset()
HEIGHT = 0.37
man = Person("Thornwight", "", Build(girth=0.88, shoulders=0.95, lean=True))
rig, p, a = man.rig, man.p, man.ax
bark_black = material("plain_barkblack", (0.12, 0.10, 0.09))
bark = material("plain_bark_timber", (0.26, 0.20, 0.15))
moss = material("plain_moss", (0.26, 0.32, 0.16))
dead = material("plain_deadwood", (0.40, 0.34, 0.27))
bone = material("plain_bone", (0.84, 0.81, 0.72))
glow = material("glow_wild", (0.62, 0.86, 1.0))
p.skin, p.wool, p.leather, p.hair = bark_black, bark_black, bark, bark_black

man.body(hands=[("", bark_black)], face=None, belt=False)
man.coat("", bark_black, moss, bark_black, hem=0.46)
man.mantle("", moss)
eyes(man, glow, spread=0.036, forward=-0.104)
# A crown of dead antlers, each a beam and its tines.
antlers = []
for s in (1, -1):
    root = Vector(at_head(s * 0.05, 0.0, 0.10))
    knee = root + Vector((s * 0.16, 0.03, 0.22))
    tip = knee + Vector((s * 0.09, 0.08, 0.24))
    antlers.append(loft("beam", [(tuple(root), 0.022, 0.022, {}), (tuple(knee), 0.018, 0.018, {})], segments=4, mat=dead, caps=(True, False)))
    antlers.append(loft("beam", [(tuple(knee), 0.018, 0.018, {}), (tuple(tip), 0.008, 0.008, {})], segments=4, mat=dead, caps=(False, True)))
    antlers.append(loft("tine", [(tuple(knee), 0.012, 0.012, {}), (tuple(knee + Vector((s * 0.18, -0.07, 0.05))), 0.005, 0.005, {})],
                        segments=3, mat=dead, caps=(False, True)))
    mid = root + (knee - root) * 0.5
    antlers.append(loft("tine", [(tuple(mid), 0.012, 0.012, {}), (tuple(mid + Vector((-s * 0.02, -0.06, 0.18))), 0.005, 0.005, {})],
                        segments=3, mat=dead, caps=(False, True)))
hang(join("antlers", antlers), rig, "head")
# Claws of bone, three to a hand.
for s, side in ((1, "L"), (-1, "R")):
    claws = [loft("claw", [((a(s * 0.30) + f * 0.026, -0.03, 0.70), 0.011, 0.011, {}),
                           ((a(s * 0.30) + f * 0.04, -0.09, 0.50), 0.003, 0.003, {})], segments=3, mat=bone, caps=(True, True))
             for f in (-1, 0, 1)]
    hang(join("claws " + side, claws), rig, "forearm" + side)
man.mattock()

# MARK: The clips

CARRY = {"armR": (-14, 0, 8), "forearmR": (-34, 0, 0), "armL": (-14, 0, -8), "forearmL": (-34, 0, 0)}
clips(man, CARRY, reach(gait_pace(HEIGHT, 0.5), HEIGHT), 17, raking, recoiling, searching)
man.finish(out_path("Art/models/thornwight.glb"), [(1, None)])
