"""The spearman: a soldier of a House in five tiers, from a levy in an
undyed coat and a leather cap behind a plain round shield, to a knight of
the line in plate under a plumed great helm, a tall kite shield on his arm
and the House's cloak on his back; and as the Salt Wardens of the Saltborn
and the Spine Guard of the Spinewardens. The body every person on foot
shares (person.py), heavy-set; the gear of every tier hung from the bones
that carry it; the six clips the world plays.

    python Art/blender/spearman.py Art/models/spearman.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from person import *

reset()
man = Person("Spearman", "saltborn,spinewardens")
rig, p, every = man.rig, man.p, man.every

man.body(hands=[("@1-5", p.skin), ("@saltborn,spinewardens", p.steel)],
         # Behind a great helm's face plate there is no face to draw.
         face="@1-4,saltborn")

# MARK: What a tier or variant wears over it

man.coat("@1", p.linen, p.linen, p.linen)
man.coat("@2", p.tunic, p.tunic, p.tunic)
man.coat("@3", p.tunic, p.tunic, p.iron)
man.coat("@4-5", p.steel, p.tunic, p.iron)
man.coat("@saltborn", p.salt_linen, p.salt_linen, p.iron, long=True)
man.coat("@spinewardens", p.dark_iron, p.dark_iron, p.dark_iron)
# The levy's sash, the only colour it wears of its House.
sash = loft("sash@1", [((0, 0.0, 1.0), 0.178, 0.124, {"hips": 0.5, "torso": 0.5}), ((0, 0.0, 0.955), 0.182, 0.127, {"hips": 1.0})],
            segments=8, mat=p.tunic, caps=(False, False))
bind(sash, rig)
collar = loft("collar" + every("2-5") + "!fine", [((0, 0.005, 1.425), 0.097, 0.092, {"torso": 1.0}), ((0, 0.005, 1.395), 0.11, 0.1, {"torso": 1.0})],
              segments=12, mat=p.trim, caps=(False, False))
bind(collar, rig)
hem_trim = loft("hem trim@2-5!fine", [((0, 0.006, 0.72), 0.226, 0.159, skirt_weights(0.45)), ((0, 0.006, 0.695), 0.228, 0.161, skirt_weights(0.45))],
                segments=16, mat=p.trim, caps=(False, False))
bind(hem_trim, rig)
baldric = solid("baldric" + every("1-5") + "!fine", "box", mat=p.leather, location=(0.0, -0.128, 1.17), size=(0.045, 0.012, 0.52), rotation=(0, -38, 0))
hang(baldric, rig, "torso")
for s, side in ((1, "L"), (-1, "R")):
    band = loft("sleeve band %s%s!fine" % (side, every("1-5")), [((s * 0.283, 0.0, 1.05), 0.06, 0.062, {}), ((s * 0.284, 0.0, 1.025), 0.06, 0.062, {})],
                segments=12, mat=p.trim, caps=(False, False))
    hang(band, rig, "arm" + side)

# Mail's hem below the coat, and plate over it, by tier.
man.mail_hem("@3-5,saltborn")
for side in ("L", "R"):
    man.pauldron(side, "@4-5,spinewardens", p.steel)
    man.greave(side, "@saltborn,spinewardens", p.steel)

# Mantles on the shoulders of the two variants.
man.mantle("@saltborn", p.salt_crust)
man.mantle("@spinewardens", p.tunic)

# MARK: Helms, by tier and variant

man.cap("cap", "@1", p.leather, 0.004, 0.005)
man.cap("iron cap", "@2", p.iron, 0.008, -0.01)
man.nasal_helm("@3", p.iron)
man.crested("@4", p.steel)
man.crested("@saltborn", p.steel)
man.great_helm("@5", p.steel)
man.great_helm("@spinewardens", p.dark_iron, plume=False)

# MARK: Shields: faced forward and a little out, on the left forearm

man.round_shield("round shield@1", 0.19, p.board)
man.round_shield("painted shield@2", 0.22, p.painted)
man.round_shield("bossed shield@3", 0.245, p.painted, boss=True)


man.kite_shield("kite shield@4", 0.36, 0.2, p.painted, p.steel)
man.kite_shield("tall kite shield@5", 0.42, 0.22, p.painted, p.steel)
man.kite_shield("salt shield@saltborn", 0.42, 0.22, p.painted, p.salt_linen)
man.kite_shield("iron shield@spinewardens", 0.4, 0.21, p.dark_iron, p.tunic)

# MARK: The spear, longer and finer with the tier; and the mattock


def spear(name, length, head, tags, guard=False):
    pieces = [solid("shaft", "cylinder", mat=p.shaft, vertices=6, radius=0.017, depth=length, location=(-0.30, -0.02, 0.06 + length / 2))]
    tip = solid("head", "cone", mat=p.steel, vertices=4, radius1=0.036, depth=head, location=(-0.30, -0.02, 0.06 + length + head / 2))
    shape_vertices(tip, lambda v: Vector((v.x, -0.02 + (v.y + 0.02) * 0.45, v.z)))
    pieces.append(tip)
    if guard:
        pieces.append(solid("lugs", "box", mat=p.iron, location=(-0.30, -0.02, 0.06 + length + 0.01), size=(0.11, 0.025, 0.02)))
    hang(join(name + tags, pieces), rig, "heldR")
    wraps = [loft("wrap", [((-0.30, -0.02, z), 0.021, 0.021, {}), ((-0.30, -0.02, z + 0.04), 0.021, 0.021, {})], segments=8,
                  mat=p.dark_leather, caps=(False, False)) for z in (0.66, 0.74, length - 0.05)]
    wraps.append(solid("butt", "cone", mat=p.iron, vertices=6, radius1=0.02, depth=0.06, location=(-0.30, -0.02, 0.03), rotation=(180, 0, 0)))
    hang(join(name + " fittings" + tags + "!fine", wraps), rig, "heldR")


spear("spear", 2.2, 0.22, "@1-3")
spear("winged spear", 2.3, 0.3, "@4-5,saltborn,spinewardens", guard=True)
pennant = solid("pennant@5,saltborn!fine", "box", mat=p.cloak_cloth, location=(-0.30, -0.10, 2.16), size=(0.012, 0.16, 0.10))
sway(pennant, lambda q: max(0.0, (-0.03 - q.y) / 0.14))
hang(pennant, rig, "heldR")
man.mattock()

# MARK: Cloaks, the House's, for the fifth tier and the Salt Wardens

man.cloak("@5", 0.86)
man.cloak("@saltborn", 1.25)

# MARK: The clips

ARMED = dict(hidden=["tool"], shown=["heldR", "heldL"])
# The spear carried upright in the right hand, the shield before the body.
CARRY = {"armR": (-8, 0, 4), "forearmR": (-30, 0, 0), "heldR": (38, 0, 0),
         "armL": (-14, 0, -6), "forearmL": (-62, 0, 0), "heldL": (55, 0, 0)}
IDLE_KEYS = {
    0: merge(CARRY, {}),
    20: merge(CARRY, {"torso": {"turn": (-1.2, 0, 0), "shift": (0, 0, 0.005)}}),
    30: merge(CARRY, {"hips": {"turn": (0, 2.5, 0), "shift": (0.013, 0, 0)}, "thighL": (0, -2.5, 0), "thighR": (0, -2.5, 0),
                      "torso": (0, -2, 0), "cloak": (4, 0, 2)}),
    40: merge(CARRY, {"torso": {"turn": (-1.2, 0, 0), "shift": (0, 0, 0.005)}, "head": (2, 0, 22)}),
    55: merge(CARRY, {"head": (2, 0, 24), "armR": (-6, 0, 4)}),
    60: merge(CARRY, {"torso": {"turn": (-1.2, 0, 0), "shift": (0, 0, 0.005)}, "head": (0, 0, 8), "cloak": (2, 0, 0)}),
    70: merge(CARRY, {"head": (-1, 0, -18)}),
    86: merge(CARRY, {"head": (-1, 0, -20), "hips": {"turn": (0, -2.5, 0), "shift": (-0.013, 0, 0)},
                      "thighL": (0, 2.5, 0), "thighR": (0, 2.5, 0), "torso": (0, 2, 0), "cloak": (4, 0, -2)}),
    100: merge(CARRY, {"torso": {"turn": (-1.2, 0, 0), "shift": (0, 0, 0.005)}}),
    120: merge(CARRY, {}),
}
keyed(rig, "idle", 120, IDLE_KEYS, **ARMED)

# The march: the spear's butt swung a little with the step, the shield steady.
man.march(CARRY, lambda side: {"armL": (-14 + 4 * side, 0, -6), "armR": (-8 - 3 * side, 0, 4), "heldR": (38 + 3 * side, 0, 0)}, **ARMED)

GUARD = {"armR": (-10, 0, 8), "forearmR": (-55, 0, 0), "heldR": (145, 0, 0),
         "armL": (-22, 0, -6), "forearmL": (-72, 0, 0), "heldL": (64, 0, 0),
         "thighL": (-14, 0, 0), "shinL": (12, 0, 0), "thighR": (10, 0, 0), "shinR": (8, 0, 0),
         "hips": {"turn": (0, 0, 3), "shift": (0, 0, -0.02)}, "torso": (6, 0, -2)}
DRAWN = merge(GUARD, {"armR": (24, 0, 8), "forearmR": (-60, 0, 0), "heldR": (126, 0, 0), "torso": (2, 0, -10),
                      "hips": {"turn": (0, 0, 1), "shift": (0, 0.025, -0.03)}, "thighR": (14, 0, 0), "shinR": (18, 0, 0),
                      "head": (0, 0, 6), "cloak": (-4, 0, 0)})
THRUST = merge(GUARD, {"armR": (-58, 0, 2), "forearmR": (-14, 0, 0), "heldR": (162, 0, 0), "torso": (13, 0, 4),
                       "hips": {"turn": (0, 0, 3), "shift": (0, -0.07, -0.045)}, "thighL": (-38, 0, 0), "shinL": (30, 0, 0),
                       "thighR": (20, 0, 0), "shinR": (6, 0, 0), "head": (-6, 0, -4), "footL": (-6, 0, 0), "cloak": (14, 0, 0)})
attack = {0: GUARD, 13: DRAWN, 20: THRUST, 28: THRUST, 38: merge(GUARD, {"torso": (8, 0, 1)}), 45: GUARD}
keyed(rig, "attack", 45, attack, **ARMED)


def struck(share):
    """The guard, a share of the way to the worst of a blow taken on the shield."""
    pose = dict(GUARD)
    pose.update({"torso": (6 - 20 * share, 0, -2 + 9 * share), "head": (-12 * share, 0, -14 * share),
                 "hips": {"turn": (0, 0, 3), "shift": (0, 0.03 * share, -0.02 - 0.02 * share)},
                 "thighR": (10 + 20 * share, 0, 0), "shinR": (8 + 15 * share, 0, 0), "thighL": (-14 - 12 * share, 0, 0),
                 "shinL": (12 + 24 * share, 0, 0), "armL": (-22 - 34 * share, 0, -6 - 7 * share), "forearmL": (-72 - 20 * share, 0, 0),
                 "armR": (-10 + 17 * share, 0, 8 - 12 * share), "heldR": (145 - 12 * share, 0, 0), "cloak": (-8 * share, 0, 0)})
    return pose


hit = {0: struck(0), 3: struck(0.15), 6: struck(1.0), 14: struck(0.7), 25: struck(0.25), 32: struck(0.05), 36: struck(0), 45: struck(0)}
keyed(rig, "hit", 45, hit, **ARMED)
man.death(CARRY, **ARMED)
man.gather(hidden=["heldR", "heldL"], shown=["tool"])

man.finish(out_path("Art/models/spearman.glb"),
           [(1, None), (2, None), (3, None), (4, None), (5, None), (5, "saltborn"), (5, "spinewardens")])
