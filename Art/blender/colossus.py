"""The colossus: the greatest thing that walks out of the far country, a
giant of stone grown over with moonsalt at its shoulders, its back and its
brow, a cold light shining from the crack in its chest where its heart
should be, eyes of the same light, and a slab of stone for a club with salt
crusted on its head. It treads heavily and brings its club down.

    python Art/blender/colossus.py Art/models/colossus.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from person import *
from wild import *

reset()
HEIGHT = 0.56
man = Person("Colossus", "", Build(girth=1.35, shoulders=1.2, lean=True))
rig, p, a, g = man.rig, man.p, man.ax, man.g
pale = material("plain_stone_pale", (0.62, 0.60, 0.56))
grey = material("plain_stone", (0.48, 0.47, 0.44))
dark = material("plain_stone_dark", (0.32, 0.31, 0.30))
moonsalt = material("crystal_moonsalt", (0.80, 0.90, 0.98), roughness=0.1)
glow = material("glow_wild", (0.62, 0.86, 1.0))
p.skin, p.wool, p.leather, p.hair = pale, dark, grey, pale

man.body(hands=[("", grey)], face=None, belt=False)
man.coat("", pale, dark, grey, skirt=False)
eyes(man, glow, spread=0.03, forward=-0.104)
# The cold light in the crack of its chest.
hang(solid("heart", "box", mat=glow, location=(0.03, g(-0.135), 1.25), size=(0.08, 0.03, 0.13), rotation=(0, 12, 0)), rig, "torso")
# Moonsalt grown through the stone at the shoulders, the back and the brow.
growths = [("armL", (a(0.27), 0.0, 1.42), (0.5, -0.2, 1.0), 0.30), ("armL", (a(0.29), 0.06, 1.36), (0.8, 0.1, 0.5), 0.20),
           ("armR", (a(-0.27), 0.0, 1.42), (-0.5, -0.1, 1.0), 0.32), ("torso", (0.08, 0.17, 1.32), (0.2, 1.0, 0.7), 0.30),
           ("torso", (-0.12, 0.18, 1.18), (-0.3, 1.0, 0.5), 0.24), ("torso", (0.03, 0.18, 1.06), (0.1, 1.0, 0.3), 0.18),
           ("head", at_head(0.05, 0.03, 0.10), (0.6, 0.4, 0.8), 0.13), ("head", at_head(-0.06, 0.02, 0.09), (-0.7, 0.3, 0.7), 0.11),
           ("head", at_head(0.0, 0.06, 0.11), (0.0, 0.8, 0.6), 0.10)]
for index, (bone_name, at, lean, length) in enumerate(growths):
    base, tip = Vector(at), Vector(at) + Vector(lean).normalized() * length
    crystal = [loft("shaft", [(tuple(base), length * 0.2, length * 0.2, {}), (tuple(base + (tip - base) * 0.7), length * 0.2, length * 0.2, {})],
                    segments=4, mat=moonsalt, caps=(True, False), smooth=False),
               loft("point", [(tuple(base + (tip - base) * 0.7), length * 0.2, length * 0.2, {}), (tuple(tip), 0.004, 0.004, {})],
                    segments=4, mat=moonsalt, caps=(False, True), smooth=False)]
    hang(join("moonsalt %d" % index, crystal), rig, bone_name)
# A slab of stone for a club, salt crusted on its head.
x, y = a(-0.30), -0.02
club = [loft("haft", [((x, y, 0.84), 0.04, 0.04, {}), ((x, y - 0.02, 0.40), 0.05, 0.05, {})], segments=5, mat=dark, caps=(True, True)),
        solid("head", "box", mat=grey, location=(x, y - 0.03, 0.22), size=(0.17, 0.20, 0.36), rotation=(6, 0, 4))]
hang(join("club", club), rig, "heldR")
hang(loft("salt crust", [((x + 0.04, y - 0.10, 0.12), 0.05, 0.05, {}), ((x + 0.08, y - 0.24, 0.02), 0.004, 0.004, {})], segments=4,
          mat=moonsalt, caps=(True, True), smooth=False), rig, "heldR")
man.mattock()

# MARK: The clips

CARRY = {"armR": (6, 0, 6), "forearmR": (-14, 0, 0), "armL": (-6, 0, -10), "forearmL": (-24, 0, 0)}


def slamming(f):
    """The club heaved up overhead in both hands and brought down."""
    keys = [(0, 0.0, 0.0), (14, 1.0, 0.0), (20, 0.0, 1.0), (28, 0.0, 1.0), (45, 0.0, 0.0)]
    for (f0, h0, s0), (f1, h1, s1) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            t = (f - f0) / (f1 - f0)
            t = t * t * (3 - 2 * t)
            heave, slam = h0 + (h1 - h0) * t, s0 + (s1 - s0) * t
            break
    return {"armR": (6 - 176 * heave - 66 * slam, 0, 6 - 16 * heave), "armL": (-6 - 166 * heave - 60 * slam, 0, -10 + 24 * heave),
            "forearmR": (-14 - 30 * heave, 0, 0), "forearmL": (-24 - 30 * heave, 0, 0), "heldR": (40 * slam, 0, 0),
            "torso": (-12 * heave + 34 * slam, 0, 0), "head": (-10 * heave + 10 * slam, 0, 0),
            "hips": {"turn": (0, 0, 0), "shift": (0, -0.04 * slam, -0.06 * slam)},
            "thighL": (-26 * slam, 0, 0), "shinL": (24 * slam, 0, 0), "thighR": (14 * slam, 0, 0), "shinR": (12 * slam, 0, 0)}


clips(man, CARRY, reach(gait_pace(HEIGHT, 0.32), HEIGHT), 12, slamming, recoiling, searching)
man.finish(out_path("Art/models/colossus.glb"), [(1, None)])
