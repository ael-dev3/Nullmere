"""The rider: a House's horseman in five tiers, from a levy on a dun pony
with a spear and a wool cap, to a knight in plate under a plumed great helm
on a pale warhorse barded in steel and caparisoned to the ground, couching
a pennoned lance; and as the Wood Riders of the Blackwood Kin, hooded in
fir-green on black horses, and the Barrow Riders of the Mound Clans, in
black and bone on ash-grey ones. The horse's own skinned body on its own
bones, then the body every person on foot shares (person.py) astride it.

    python Art/blender/rider.py Art/models/rider.glb

The rider is made seated at a man's height, his horse beneath him with its
hooves below the ground, and the game lifts the whole of it as it reads it
(riderLift, in Sources/NullmereModels/Art/Art.swift). Its bones are the
rig every horse and rider keeps (Steed, in Sources/NullmereModels/Riders.swift),
the 24 parts with the game's root that every figure's rig is held to: the
rider's legs are carried by his seat and each hoof by its shin, their
bones folded away before the clips are keyed. The horse's coat, socks and
mane are made in materials of their own that the game colours as each
tier's horse is (Riders.mount).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from horse import *
from person import *

reset()
man = Person("Rider", "blackwood,moundClans", Build(lean=True), moved=astride(), before_bones=BONES)
rig, p, every = man.rig, man.p, man.every

coat = material("plain_coat", (0.45, 0.28, 0.16))
socks = material("plain_socks", (0.45, 0.28, 0.16))
mane = material("plain_mane", (0.10, 0.07, 0.05))
hoof = material("plain_hoof", (0.16, 0.14, 0.12))
fir = material("plain_fir", (0.18, 0.26, 0.17))
bone = material("plain_bone", (0.80, 0.76, 0.66))
black_wool = material("plain_blackwool", (0.10, 0.10, 0.11))
shroud = material("cloth_shroud", (0.46, 0.46, 0.44))
cloth = material("cloth_caparison", (0.55, 0.55, 0.55))

# MARK: The horse, its tack and the House's cloth by tier

horse = Horse(rig, p, coat, socks, mane, hoof, cloth)
# Under a caparison the cloth is the horse's body, far and near.
horse.body(bare="@1-2,blackwood", maned="@1-4,blackwood,moundClans")
horse.tack()
horse.saddle_cloth("@1-2,blackwood")
# Short at the third tier, to the knees at the fourth, to the hoof at the fifth.
horse.caparison("@3", 0.22)
horse.caparison("@4", 0.0)
horse.caparison("@5,moundClans", -0.30)
# Steel on the face and the breast, from the fourth tier; on the neck at the fifth.
horse.barding("@4")
horse.barding("@5")
horse.crinet("@5")

# MARK: The rider, astride

man.body(hands=[("@1-5,blackwood", p.skin), ("@moundClans", p.steel)], face="@1-4,blackwood", seated=SEATED)
man.coat("@1", p.linen, p.linen, p.linen, skirt=False)
man.coat("@2", p.tunic, p.tunic, p.tunic, skirt=False)
man.coat("@3", p.tunic, p.tunic, p.iron, skirt=False)
man.coat("@4-5", p.steel, p.tunic, p.iron, skirt=False)
man.coat("@blackwood", p.dark_leather, p.dark_leather, p.leather, skirt=False)
man.coat("@moundClans", black_wool, black_wool, black_wool, skirt=False)
bind(loft("sash@1", [((0, 0.0, 1.0), 0.178, 0.124, {"hips": 0.5, "torso": 0.5}), ((0, 0.0, 0.955), 0.182, 0.127, {"hips": 1.0})],
          segments=8, mat=p.tunic, caps=(False, False)), rig)
for side in ("L", "R"):
    man.pauldron(side, "@4-5", p.steel)
    man.pauldron(side, "@moundClans", bone)
man.mantle("@moundClans", shroud)
# The Barrow Riders' House on the chest.
seated_tabard(man, "@moundClans")
man.cap("wool cap", "@1", p.wool, 0.006, 0.0)
man.cap("iron cap", "@2", p.iron, 0.008, -0.01)
man.nasal_helm("@3", p.iron)
man.crested("@4", p.steel)
man.great_helm("@5", p.steel)
man.great_helm("@moundClans", p.dark_iron, plume=False)
man.hood("@blackwood", fir)
man.round_shield("painted shield@2", 0.22, p.painted)
man.round_shield("bossed shield@3,blackwood", 0.245, p.painted, boss=True)
man.kite_shield("kite shield@4", 0.40, 0.22, p.painted, p.steel)
man.kite_shield("tall kite shield@5,moundClans", 0.44, 0.23, p.painted, p.steel)


trailing_cloak(man, "@5", 0.2)
trailing_cloak(man, "@blackwood", 0.48)

# The lance, longer and finer with the tier: upright in the right hand.
HAND = (-0.30, -0.02, 0.72)


def lance(tags, length, guard=None, pennon=None):
    x, y, z = HAND
    butt = z - 0.6
    pieces = [solid("lance shaft", "cylinder", mat=p.shaft, vertices=5, radius=0.02, depth=length, location=(x, y, butt + length / 2))]
    tip = solid("lance head", "cone", mat=p.steel, vertices=4, radius1=0.032, depth=0.22, location=(x, y, butt + length + 0.11))
    pieces.append(tip)
    if guard:
        pieces.append(solid("vamplate", "cone", mat=guard, vertices=6, radius1=0.08, depth=0.2, location=(x, y, z + 0.18), rotation=(180, 0, 0)))
    hang(join("lance" + tags, pieces), rig, "heldR")
    hang(loft("lance grip%s!fine" % tags, [((x, y, z - 0.08), 0.026, 0.026, {}), ((x, y, z + 0.08), 0.026, 0.026, {})], segments=8,
              mat=p.dark_leather, caps=(False, False)), rig, "heldR")
    if pennon:
        width, height = pennon
        flag = solid("pennon%s" % tags, "box", mat=p.tunic, location=(x, y + width / 2 + 0.02, butt + length - 0.18),
                     size=(0.01, width, height))
        sway(flag, lambda q, y0=y: max(0.0, min(1.0, (q.y - y0) / 0.3)))
        hang(flag, rig, "heldR")


lance("@1", 2.7)
lance("@2", 3.0)
lance("@3", 3.1, guard=p.iron)
lance("@4", 3.2, guard=p.steel, pennon=(0.30, 0.13))
lance("@5,moundClans", 3.35, guard=p.steel, pennon=(0.42, 0.18))
lance("@blackwood", 2.9)
man.mattock()

# His legs carried by his seat, and the rig's lantern bone by his torso.
fold(rig, FOLDED)

# MARK: The clips

STILL = dict(hidden=["tool"], shown=["heldR", "heldL"])
# The lance upright in the right hand, the shield (or the reins) before
# the body in the left.
CARRY = {"armR": (-8, 0, 4), "forearmR": (-30, 0, 0), "heldR": (38, 0, 0),
         "armL": (-14, 0, -6), "forearmL": (-62, 0, 0), "heldL": (55, 0, 0)}
IDLE = {}
for f in range(0, 121, 10):
    u = f / 120
    IDLE[f] = merge(CARRY, at_rest(u), {"head": (2, 0, 24 * math.sin(2 * math.pi * (u - 0.1))),
                                        "torso": (0, 0, 6 * math.sin(2 * math.pi * (u - 0.1)))})
keyed(rig, "idle", 120, IDLE, **STILL)

march = {}
for k in range(13):
    f = 2.5 * k
    march[f] = merge(CARRY, canter((f / 15) % 1.0), {"heldR": (38 + 3 * math.sin(2 * math.pi * f / 15), 0, 0)})
keyed(rig, "march", 30, march, **STILL)

# The charge: three long strides, the rider low over the neck, the lance
# brought down from upright and couched at the foe.
charge = {}
for k in range(19):
    f = 2.5 * k
    share = min(1.0, f / 10) if f < 38 else max(0.0, 1 - (f - 38) / 7)
    charge[f] = merge(CARRY, canter((f / 15) % 1.0, reach=32, fold=90), couched(share))
keyed(rig, "attack", 45, charge, **STILL)


def struck(share):
    """The horse shying, its rider rocked back, his shield thrown up."""
    return merge(CARRY, shied(share), {"armR": (-8 + 14 * share, 0, 4 - 8 * share), "armL": (-14 - 30 * share, 0, -6 - 8 * share),
                                       "forearmL": (-62 - 18 * share, 0, 0)})


hit = {0: struck(0), 3: struck(0.15), 6: struck(1.0), 14: struck(0.7), 25: struck(0.25), 32: struck(0.05), 36: struck(0), 45: struck(0)}
keyed(rig, "hit", 45, hit, **STILL)


def down(share):
    """The horse fallen on its side, its rider thrown and lying by it, his
    lance still in his hand."""
    return merge(CARRY, fallen(share), {"heldR": (38 - 26 * share, 0, 0)})


death = {0: down(0), 6: down(0.12), 12: down(0.35), 22: down(0.75), 30: down(1.0), 38: down(1.0), 45: down(1.0)}
keyed(rig, "death", 45, death, **STILL)

# Gathering: the horse crops the ground while its rider, down from the
# saddle beside it, crouches as his seat holds his legs, his soles on the
# ground, and works a mattock.
SOLE = SEATED["L"][2][2] - 0.097
DISMOUNTED = {"hips": {"turn": (0, 0, 0), "shift": (0.78, 0.15, GROUND - SOLE)}}


def swing(lift, strike):
    return {"armR": (-35 - 125 * lift + 20 * strike, 0, 9), "armL": (-35 - 125 * lift + 20 * strike, 0, -20),
            "forearmR": (-17, 0, 0), "forearmL": (-26, 0, 0), "tool": (80 + 40 * lift, 0, 0),
            "torso": (28 - 14 * lift + 12 * strike, 0, 0), "head": (-6 + 4 * strike, 0, 0),
            # His cloak, cast back over the croup in the saddle, hanging down his back.
            "cloak": (-70 + 14 * lift - 12 * strike, 0, 0)}


gather = {}
for half in (0, 30):
    for f, lift, strike in ((0, 0, 0), (12, 1, 0), (16.5, 0, 1), (22.5, 0, 1)):
        gather[half + f] = merge(DISMOUNTED, swing(lift, strike), grazing((half + f) / 60))
gather[60] = merge(DISMOUNTED, swing(0, 0), grazing(0))
keyed(rig, "gather", 60, gather, hidden=["heldR", "heldL"], shown=["tool"])

man.finish(out_path("Art/models/rider.glb"),
           [(1, None), (2, None), (3, None), (4, None), (5, None), (5, "blackwood"), (5, "moundClans")])
