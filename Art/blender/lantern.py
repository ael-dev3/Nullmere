"""The lantern-bearer: a House's scout, slight and wiry, in a dark wool coat
under the House's hood and a wool mantle, a long knife at the belt, the
lantern hung from a crook held high in the left hand. The body every
person on foot shares (person.py); the lantern on the `extra` bone, hung
from the crook's hook, so it swings there and is lifted with the crook.

    python Art/blender/lantern.py Art/models/lantern.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from person import *

reset()
BUILD = Build(girth=0.80, shoulders=0.92)
A = BUILD.shoulders
GRIP = (0.30 * A, -0.02, 0.72)
# The crook's hook, forward over the hand, and the lantern hung from it.
HOOK = (GRIP[0], -0.27, 1.97)
man = Person("Lantern", "", BUILD, moved={"extra": (HOOK, (HOOK[0], HOOK[1], HOOK[2] - 0.1), "heldL")})
rig, p, g = man.rig, man.p, man.g

dark_wool = material("plain_darkwool", (0.18, 0.17, 0.16))
pale_wood = material("plain_timber_crook", (0.62, 0.50, 0.34))
candle = material("glow_candle", (1.0, 0.78, 0.42))

man.body(hands=[("", p.skin)], face="")
man.coat("", dark_wool, dark_wool, dark_wool, hem=0.74)
man.hood("", p.tunic)
man.mantle("", p.wool)

# MARK: The crook and its lantern

staff = loft("crook", [((GRIP[0], GRIP[1], 0.06), 0.017, 0.017, {}), ((GRIP[0], GRIP[1], 2.02), 0.015, 0.015, {})],
             segments=5, mat=pale_wood, caps=(True, True))
hang(staff, rig, "heldL")
hook_arm = loft("crook hook", [((GRIP[0], GRIP[1], 2.0), 0.013, 0.013, {}), ((GRIP[0], -0.16, 2.05), 0.012, 0.012, {}),
                               ((GRIP[0], HOOK[1], HOOK[2] + 0.03), 0.011, 0.011, {})], segments=4, mat=pale_wood, caps=(False, True))
hang(hook_arm, rig, "heldL")
hang(loft("crook close!fine", [((GRIP[0], GRIP[1], 0.06), 0.019, 0.019, {}), ((GRIP[0], GRIP[1], 2.02), 0.017, 0.017, {})],
          segments=10, mat=pale_wood, caps=(True, True)), rig, "heldL")
# Its iron ferrule and the binding at the hand, near.
hang(join("crook fittings!fine", [
    solid("ferrule", "cone", mat=p.iron, vertices=6, radius1=0.02, depth=0.07, location=(GRIP[0], GRIP[1], 0.05), rotation=(180, 0, 0)),
    loft("binding", [((GRIP[0], GRIP[1], 0.66), 0.022, 0.022, {}), ((GRIP[0], GRIP[1], 0.80), 0.022, 0.022, {})], segments=8,
         mat=p.dark_leather, caps=(False, False)),
]), rig, "heldL")

x, y, z = HOOK
lantern = join("lantern", [
    solid("bail", "box", mat=p.iron, location=(x, y, z - 0.03), size=(0.012, 0.012, 0.06)),
    solid("lantern cap", "cone", mat=p.iron, vertices=4, radius1=0.10, depth=0.08, location=(x, y, z - 0.09), rotation=(0, 0, 45)),
    solid("lantern base", "box", mat=p.iron, location=(x, y, z - 0.27), size=(0.13, 0.13, 0.03)),
])
hang(lantern, rig, "extra")
light = solid("lantern light", "box", mat=candle, location=(x, y, z - 0.18), size=(0.10, 0.10, 0.15))
hang(light, rig, "extra")
# Its frame's corner bars and a ring at the bail, near.
bars = [solid("bar", "box", mat=p.iron, location=(x + dx, y + dy, z - 0.18), size=(0.014, 0.014, 0.17))
        for dx, dy in ((0.055, 0.055), (-0.055, 0.055), (0.055, -0.055), (-0.055, -0.055))]
bars.append(loft("ring", [((x, y, z - 0.005), 0.02, 0.02, {}), ((x, y, z + 0.005), 0.02, 0.02, {})], segments=8, mat=p.iron,
                 caps=(False, False)))
hang(join("lantern frame!fine", bars), rig, "extra")

# A long knife at the right hip.
knife = join("knife", [
    solid("sheath", "box", mat=p.dark_leather, location=(g(-0.17), g(-0.05), 0.80), size=(0.035, 0.03, 0.30), rotation=(0, 12, 0)),
    solid("hilt", "box", mat=p.leather, location=(g(-0.15), g(-0.05), 1.0), size=(0.025, 0.025, 0.10), rotation=(0, 12, 0)),
])
hang(knife, rig, "hips")
man.mattock()

# MARK: The clips

AT_REST = dict(hidden=["tool"], shown=["heldL", "extra"])
# The crook held up before the left shoulder, standing upright, the
# lantern hanging at the hook; the right hand easy.
CARRY = {"armL": (-24, 0, -6), "forearmL": (-48, 0, 0), "heldL": (72, 0, 0),
         "armR": (-4, 0, 6), "forearmR": (-16, 0, 0)}


def swing(x_deg, z_deg=0):
    return {"extra": (x_deg, 0, z_deg)}


IDLE = {
    0: merge(CARRY, swing(0)),
    16: merge(CARRY, {"head": (4, 0, 34), "torso": (6, 0, 8), "armL": (-30, 0, -2), "heldL": (78, 0, 0)}, swing(5, 3)),
    30: merge(CARRY, {"head": (6, 0, 40), "torso": (6, 0, 10), "armL": (-30, 0, -2), "heldL": (78, 0, 0)}, swing(-4, -2)),
    44: merge(CARRY, {"head": (-2, 0, 6)}, swing(3)),
    60: merge(CARRY, {"head": (-6, 0, -10), "hips": {"turn": (0, 0, 0), "shift": (0, 0, -0.01)}}, swing(-3, 2)),
    74: merge(CARRY, {"head": (4, 0, -36), "torso": (6, 0, -8), "armL": (-28, 0, -10), "heldL": (76, 0, 0)}, swing(5, -3)),
    88: merge(CARRY, {"head": (6, 0, -40), "torso": (6, 0, -10), "armL": (-28, 0, -10), "heldL": (76, 0, 0)}, swing(-4, 2)),
    104: merge(CARRY, {"head": (0, 0, -4)}, swing(2)),
    120: merge(CARRY, swing(0)),
}
keyed(rig, "idle", 120, IDLE, **AT_REST)

# The careful way into the dark: stooped, the head turning one side and
# the other, the lantern swinging on its hook.
man.march(CARRY, lambda side: {"torso": (12, 0, 3 * side), "head": (-10, 0, 14 * side), "armR": (-4 - 10 * side, 0, 6),
                               "extra": (6 * side, 0, 0)}, **AT_REST)

# The lantern lifted high on its crook, flaring, and lowered.
RAISED = merge(CARRY, {"armL": (-135, 0, -10), "forearmL": (-16, 0, 0), "heldL": (151, 0, 0), "torso": (-6, 0, 0), "head": (-14, 0, 0),
                       "armR": (-16, 0, 14), "forearmR": (-30, 0, 0)})
attack = {0: merge(CARRY, {"extra": {"scale": 1.0}}),
          12: merge(RAISED, {"extra": {"scale": 1.0}}),
          16: merge(RAISED, {"extra": {"turn": (4, 0, 0), "scale": 1.35}}),
          21: merge(RAISED, {"extra": {"turn": (-3, 0, 0), "scale": 1.2}}),
          26: merge(RAISED, {"extra": {"turn": (3, 0, 0), "scale": 1.4}}),
          31: merge(RAISED, {"extra": {"turn": (0, 0, 0), "scale": 1.25}}),
          36: merge(RAISED, {"extra": {"scale": 1.0}}),
          45: merge(CARRY, {"extra": {"scale": 1.0}})}
keyed(rig, "attack", 45, attack, hidden=["tool"], shown=["heldL"])


def struck(share):
    """The carry, a share of the way to the worst of a blow: flinching from
    it, the lantern held away, the free arm across the face."""
    return merge(CARRY, {"torso": (-14 * share, 0, -18 * share), "head": (-12 * share, 0, 30 * share),
                         "hips": {"turn": (0, 0, -4 * share), "shift": (0, 0.03 * share, -0.02 * share)},
                         "thighR": (12 * share, 0, 0), "shinR": (12 * share, 0, 0), "thighL": (-10 * share, 0, 0), "shinL": (18 * share, 0, 0),
                         "armL": (-24 + 6 * share, -26 * share, -6), "armR": (-4 - 76 * share, 0, 6 + 34 * share),
                         "forearmR": (-16 - 84 * share, 0, 0), "extra": (-14 * share, 0, 0)})


hit = {0: struck(0), 3: struck(0.15), 6: struck(1.0), 14: struck(0.7), 25: struck(0.25), 32: struck(0.05), 36: struck(0), 45: struck(0)}
keyed(rig, "hit", 45, hit, **AT_REST)
man.death(CARRY, **AT_REST)
man.gather(hidden=["heldL"], shown=["tool"])

man.finish(out_path("Art/models/lantern.glb"), [(1, None)])
