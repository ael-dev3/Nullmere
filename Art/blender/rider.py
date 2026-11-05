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
from person import *

reset()
GROUND = -0.56
SEAT = 0.90


def mirror(point, s):
    return (point[0] * s, point[1], point[2])


# MARK: The horse's skeleton, before the rider's

FORE_TOP, FORE_KNEE, FORE_FETLOCK, FORE_HOOF = (0.15, -0.60, 0.42), (0.15, -0.62, -0.04), (0.15, -0.60, -0.42), (0.15, -0.64, GROUND)
HIND_TOP, HIND_HOCK, HIND_FETLOCK, HIND_HOOF = (0.16, 0.66, 0.44), (0.16, 0.82, -0.02), (0.16, 0.74, -0.42), (0.16, 0.71, GROUND)
HORSE_BONES = [
    ("body", (0, 0.05, 0.57), (0, -0.55, 0.57), None),
    ("neck", (0, -0.58, 0.84), (0, -0.98, 1.28), "body"),
    ("horseHead", (0, -1.02, 1.33), (0, -1.36, 0.98), "neck"),
    ("tail", (0, 0.97, 0.80), (0, 1.12, 0.30), "body"),
]
for front, (top, joint, low) in (("fore", (FORE_TOP, FORE_KNEE, FORE_FETLOCK)), ("hind", (HIND_TOP, HIND_HOCK, HIND_FETLOCK))):
    for s, side in ((1, "L"), (-1, "R")):
        HORSE_BONES.append(("%sLeg%s" % (front, side), mirror(top, s), mirror(joint, s), "body"))
        HORSE_BONES.append(("%sShin%s" % (front, side), mirror(joint, s), mirror(low, s), "%sLeg%s" % (front, side)))
# The rig keeps the fore legs before the hind: left, its shin, right, its shin.
HORSE_BONES = HORSE_BONES[:4] + [b for b in HORSE_BONES[4:] if b[0].startswith("fore")] + [b for b in HORSE_BONES[4:] if b[0].startswith("hind")]

# The rider astride: hips on the saddle, thighs out and forward round the
# barrel, shins down to the stirrups.
SEATED = {}
for s, side in ((1, "L"), (-1, "R")):
    SEATED[side] = ((s * 0.11, 0.0, SEAT), (s * 0.33, -0.30, 0.66), (s * 0.30, -0.22, 0.26))
moved = {"hips": ((0, 0, SEAT), (0, 0, SEAT + 0.1), "body")}
for side, (hip, knee, ankle) in SEATED.items():
    moved["thigh" + side] = (hip, knee, "hips")
    moved["shin" + side] = (knee, ankle, "thigh" + side)
    moved["foot" + side] = (ankle, (ankle[0], ankle[1] - 0.14, ankle[2] - 0.05), "shin" + side)
man = Person("Rider", "blackwood,moundClans", Build(lean=True), moved=moved, before_bones=HORSE_BONES)
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

# MARK: The horse


def barrel(name, inflate, segments, mat, lean=False):
    sections = [
        ((0, 0.98, 0.62), 0.10, 0.12),
        ((0, 0.88, 0.60), 0.24, 0.30),
        ((0, 0.58, 0.58), 0.27, 0.35),
        ((0, 0.15, 0.56), 0.27, 0.37),
        ((0, -0.25, 0.58), 0.26, 0.36),
        ((0, -0.58, 0.62), 0.24, 0.33),
        ((0, -0.78, 0.62), 0.16, 0.25),
        ((0, -0.87, 0.62), 0.05, 0.08),
    ]
    if lean:
        sections = [sections[i] for i in (0, 1, 3, 5, 6, 7)]
    return loft(name, [(c, rx + inflate, ry + inflate, {"body": 1.0}) for c, rx, ry in sections], segments=segments, mat=mat)


# Under a caparison the cloth is the horse's body, far and near.
BARE = "@1-2,blackwood"
bind(barrel("horse body" + BARE, 0, 6, coat, lean=True), rig)
bind(barrel("horse body close%s!fine" % BARE, 0.006, 12, coat), rig)
neck_rings = [((0, -0.55, 0.84), 0.14, 0.21, {"body": 0.5, "neck": 0.5}), ((0, -0.78, 1.04), 0.12, 0.16, {"neck": 1.0}),
              ((0, -0.96, 1.24), 0.09, 0.11, {"neck": 0.7, "horseHead": 0.3}), ((0, -1.03, 1.34), 0.075, 0.09, {"horseHead": 1.0})]
paired(rig, "horse neck", neck_rings, far=4, near=8, between=1, mat=coat, caps=(False, False))
head_rings = [((0, -1.03, 1.34), 0.075, 0.09, {"horseHead": 1.0}), ((0, -1.12, 1.25), 0.085, 0.10, {"horseHead": 1.0}),
              ((0, -1.23, 1.13), 0.072, 0.085, {"horseHead": 1.0}), ((0, -1.33, 1.02), 0.055, 0.062, {"horseHead": 1.0}),
              ((0, -1.39, 0.95), 0.045, 0.045, {"horseHead": 1.0})]
paired(rig, "horse head", [head_rings[0], head_rings[2], head_rings[4]], far=5, near=8, between=2, mat=coat, caps=(False, True))
ears = [solid("ear", "cone", mat=coat, vertices=3, radius1=0.025, depth=0.11, location=(s * 0.05, -1.05, 1.42), rotation=(-10, s * 12, 0))
        for s in (1, -1)]
hang(join("horse ears", ears), rig, "horseHead")
features = []
for s in (1, -1):
    features.append(solid("eye", "sphere", mat=p.eye, segments=5, rings=3, radius=(0.014, 0.022, 0.018), location=(s * 0.078, -1.14, 1.23)))
    features.append(solid("nostril", "sphere", mat=p.eye, segments=4, rings=3, radius=(0.012, 0.014, 0.01), location=(s * 0.028, -1.385, 0.98)))
hang(join("horse face!fine", features), rig, "horseHead")
# The mane along the crest of the neck, and the forelock.
mane_rings = [((0, -0.56, 1.03), 0.022, 0.05, {"body": 0.4, "neck": 0.6}), ((0, -0.76, 1.19), 0.022, 0.055, {"neck": 1.0}),
              ((0, -0.95, 1.36), 0.02, 0.045, {"neck": 0.6, "horseHead": 0.4})]
paired(rig, "mane", mane_rings, far=3, near=6, between=1, mat=mane, caps=(False, False), tags="@1-4,blackwood,moundClans")
hang(solid("forelock!fine", "cone", mat=mane, vertices=4, radius1=0.03, depth=0.09, location=(0, -1.09, 1.36), rotation=(150, 0, 0)), rig,
     "horseHead")
tail_lean, tail_full = paired(rig, "horse tail", [((0, 0.97, 0.80), 0.05, 0.05, {"tail": 1.0}), ((0, 1.05, 0.55), 0.06, 0.05, {"tail": 1.0}),
                                                  ((0, 1.11, 0.28), 0.03, 0.025, {"tail": 1.0})], far=3, near=8, between=1, mat=mane,
                              caps=(False, True))
for piece in (tail_lean, tail_full):
    sway(piece, lambda q: max(0.0, min(1.0, (0.78 - q.z) / 0.5)))

for front, (top, joint, low, foot), (r_top, r_joint) in (("fore", (FORE_TOP, FORE_KNEE, FORE_FETLOCK, FORE_HOOF), (0.075, 0.048)),
                                                         ("hind", (HIND_TOP, HIND_HOCK, HIND_FETLOCK, HIND_HOOF), (0.085, 0.05))):
    for s, side in ((1, "L"), (-1, "R")):
        leg, shin = "%sLeg%s" % (front, side), "%sShin%s" % (front, side)
        t, j, l, f = (Vector(mirror(x, s)) for x in (top, joint, low, foot))
        # Far off, one lean leg to the hoof.
        bind(loft("%s leg %s" % (front, side), [(tuple(t), r_top, r_top * 1.15, {leg: 1.0}),
                                                (tuple(j), r_joint, r_joint * 1.1, {leg: 0.5, shin: 0.5}),
                                                (tuple(f), 0.05, 0.055, {shin: 1.0})], segments=4, mat=coat, caps=(False, True)), rig)
        # Near, rounded, the socks and the hoof their own.
        bind(loft("%s leg close %s!fine" % (front, side), [(tuple(t + Vector((0, 0, 0.12))), r_top * 1.2, r_top * 1.4, {"body": 0.6, leg: 0.4}),
                                                          (tuple(t), r_top + 0.004, r_top * 1.15 + 0.004, {leg: 1.0}),
                                                          (tuple(t + (j - t) * 0.5), r_top * 0.8, r_top * 0.9, {leg: 1.0}),
                                                          (tuple(j), r_joint + 0.004, r_joint * 1.1 + 0.004, {leg: 0.5, shin: 0.5})],
                  segments=8, mat=coat, caps=(False, False)), rig)
        bind(loft("%s cannon %s!fine" % (front, side), [(tuple(j), r_joint + 0.004, r_joint * 1.1 + 0.004, {leg: 0.5, shin: 0.5}),
                                                       (tuple(j + (l - j) * 0.5), 0.038, 0.042, {shin: 1.0}),
                                                       (tuple(l), 0.04, 0.044, {shin: 1.0})],
                  segments=6, mat=socks, caps=(False, False)), rig)
        bind(loft("%s hoof %s!fine" % (front, side), [(tuple(l), 0.04, 0.044, {shin: 1.0}),
                                                     (tuple(f + Vector((0, -0.01, 0.06))), 0.052, 0.056, {shin: 1.0}),
                                                     (tuple(f + Vector((0, -0.015, 0.0))), 0.059, 0.066, {shin: 1.0})],
                  segments=6, mat=hoof, caps=(False, True)), rig)

# MARK: Its tack: saddle and bridle, and the House's cloth by tier

hang(loft("saddle", [((0, 0.30, 0.935), 0.17, 0.05, {}), ((0, -0.28, 0.95), 0.16, 0.05, {})], segments=4, mat=p.dark_leather,
          caps=(True, True)), rig, "body")
hang(join("saddle close!fine", [
    loft("seat", [((0, 0.31, 0.937), 0.175, 0.052, {}), ((0, 0.0, 0.942), 0.205, 0.052, {}), ((0, -0.29, 0.952), 0.165, 0.052, {})],
         segments=8, mat=p.dark_leather, caps=(True, True)),
    solid("pommel", "box", mat=p.dark_leather, location=(0, -0.26, 1.02), size=(0.16, 0.06, 0.12)),
    solid("cantle", "box", mat=p.dark_leather, location=(0, 0.29, 1.01), size=(0.2, 0.06, 0.1)),
]), rig, "body")
for s, side in ((1, "L"), (-1, "R")):
    hang(solid("stirrup %s!fine" % side, "box", mat=p.iron, location=(s * 0.30, -0.22, 0.17), size=(0.1, 0.06, 0.02)), rig, "foot" + side)
    hang(solid("stirrup leather %s!fine" % side, "box", mat=p.dark_leather, location=(s * 0.29, -0.12, 0.62), size=(0.02, 0.03, 0.62),
               rotation=(10, 0, 0)), rig, "body")
bridle = join("bridle!fine", [
    loft("noseband", [((0, -1.30, 1.05), 0.062, 0.068, {}), ((0, -1.32, 1.08), 0.062, 0.068, {})], segments=10, mat=p.dark_leather,
         caps=(False, False)),
    loft("headpiece", [((0, -1.07, 1.30), 0.088, 0.1, {}), ((0, -1.09, 1.33), 0.088, 0.1, {})], segments=10, mat=p.dark_leather,
         caps=(False, False)),
])
hang(bridle, rig, "horseHead")


def saddle_cloth(tags):
    """The House's cloth under the saddle, a band about the barrel."""
    rings = [((0, 0.38, 0.57), 0.285, 0.385), ((0, 0.0, 0.56), 0.285, 0.39), ((0, -0.34, 0.58), 0.275, 0.38)]
    bind(loft("saddle cloth" + tags, [(c, rx, ry, {"body": 1.0}) for c, rx, ry in rings], segments=6, mat=p.tunic, caps=(False, False)), rig)
    bind(loft("saddle cloth close%s!fine" % tags, [(c, rx + 0.004, ry + 0.004, {"body": 1.0}) for c, rx, ry in rings], segments=14, mat=p.tunic,
              caps=(False, False)), rig)


def caparison(tags, hem):
    """The House's cloth draped from the back to the knees or near the
    ground, front and rear, the legs and the head out of it."""
    rings = [((0, 0.06, 0.97), 0.12, 0.50), ((0, 0.06, 0.80), 0.29, 0.88), ((0, 0.06, 0.60), 0.31, 0.97), ((0, 0.06, hem), 0.33, 1.02)]
    for name, segments, inflate in (("caparison" + tags, 6, 0.0), ("caparison close" + tags + "!fine", 14, 0.004)):
        piece = loft(name, [(c, rx + inflate, ry + inflate, {"body": 1.0}) for c, rx, ry in rings], segments=segments, mat=cloth,
                     caps=(False, False))
        sway(piece, lambda q, h=hem: max(0.0, min(1.0, (0.7 - q.z) / (0.7 - h))) * 0.5)
        bind(piece, rig)


saddle_cloth("@1-2,blackwood")
# Short at the third tier, to the knees at the fourth, to the hoof at the fifth.
caparison("@3", 0.22)
caparison("@4", 0.0)
caparison("@5,moundClans", -0.30)
# Steel on the face and the breast, from the fourth tier; on the neck at the fifth.
for tags in ("@4", "@5"):
    hang(solid("chanfron" + tags, "box", mat=p.steel, location=(0, -1.24, 1.16), size=(0.12, 0.04, 0.30), rotation=(-48, 0, 0)), rig,
         "horseHead")
    hang(loft("peytral" + tags, [((0, -0.70, 0.62), 0.27, 0.30, {}), ((0, -0.84, 0.62), 0.2, 0.26, {})], segments=8, mat=p.steel,
              caps=(False, False)), rig, "body")
crinet = paired(rig, "crinet", [((0, -0.56, 1.0), 0.06, 0.07, {"body": 0.4, "neck": 0.6}), ((0, -0.77, 1.17), 0.055, 0.065, {"neck": 1.0}),
                                ((0, -0.95, 1.34), 0.045, 0.05, {"neck": 0.6, "horseHead": 0.4})], far=3, near=8, between=1, mat=p.steel,
                caps=(True, True), tags="@5")

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
bind(loft("tabard@moundClans", [((0, 0.0, 1.36), 0.222, 0.128, {"torso": 1.0}), ((0, -0.015, 1.26), 0.212, 0.14, {"torso": 1.0}),
                                ((0, -0.005, 1.12), 0.186, 0.125, {"torso": 1.0}), ((0, 0.0, 0.99), 0.18, 0.13, {"hips": 0.5, "torso": 0.5})],
          segments=6, mat=p.tunic, caps=(False, False)), rig)
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


def cloak(tags, trail):
    """The House's cloak from the rider's shoulders, down his back, over the
    cantle and back over the horse's croup `trail` beyond it, swaying free
    toward its hem."""
    end = (0, 0.36 + trail, 1.02 - 0.08 * trail)
    lean, full = paired(rig, "cloak", [((0, 0.11, 1.40), 0.2, 0.045, {"torso": 0.7, "cloak": 0.3}),
                                       ((0, 0.29, 1.10), 0.27, 0.05, {"cloak": 1.0}),
                                       (end, 0.31, 0.05, {"cloak": 1.0})],
                        far=man.far(8), near=man.near(16), between=3, mat=p.cloak_cloth, tags=tags, inflate=0.003)
    for piece in (lean, full):
        sway(piece, lambda q: max(0.0, min(1.0, (q.y - 0.11) / (end[1] - 0.11))))
    hang(solid("clasp%s!fine" % tags, "sphere", mat=p.steel, segments=8, rings=4, radius=(0.025, 0.012, 0.025),
               location=(0.0, -0.1, 1.41)), rig, "torso")


cloak("@5", 0.2)
cloak("@blackwood", 0.48)

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

# The rider's legs carried by his seat, astride or down from the saddle,
# and the bone the rig keeps for a lantern by his torso: the 23 bones
# after the game's root that every horse and rider moves on.
fold(rig, {"thighL": "hips", "shinL": "hips", "footL": "hips", "thighR": "hips", "shinR": "hips", "footR": "hips", "extra": "torso"})

# MARK: The clips

STILL = dict(hidden=["tool"], shown=["heldR", "heldL"])
# The lance upright in the right hand, the shield (or the reins) before
# the body in the left.
CARRY = {"armR": (-8, 0, 4), "forearmR": (-30, 0, 0), "heldR": (38, 0, 0),
         "armL": (-14, 0, -6), "forearmL": (-62, 0, 0), "heldL": (55, 0, 0)}
LEGS = ("foreLegL", "foreLegR", "hindLegL", "hindLegR")


def leg_pose(u, contact, stance, reach, fold, hind):
    """A leg through a stride: planted at `contact`, pushed back through its
    stance, then lifted, folded and brought forward again."""
    t = (u - contact) % 1.0
    if t < stance:
        swing, flex = -reach + 2 * reach * t / stance, 0.0
    else:
        w = (t - stance) / (1 - stance)
        swing, flex = reach * math.cos(math.pi * w), fold * math.sin(math.pi * w)
    return swing, (-flex if hind else flex)


# The canter, leading with the near fore: off hind, then near hind with off
# fore, then near fore, then all four off the ground.
CONTACTS = {"hindLegR": 0.0, "hindLegL": 0.16, "foreLegR": 0.16, "foreLegL": 0.32}


def stride(u, reach=27, fold=80):
    pose = {}
    for leg in LEGS:
        hind = leg.startswith("hind")
        swing, flex = leg_pose(u, CONTACTS[leg], 0.32, reach, fold if not hind else 55, hind)
        pose[leg] = (swing, 0, 0)
        pose[leg.replace("Leg", "Shin")] = (flex, 0, 0)
    rock = math.cos(2 * math.pi * (u - 0.32))
    pose["body"] = {"turn": (-3.5 * rock, 0, 0), "shift": (0, 0, 0.03 * math.cos(2 * math.pi * (u - 0.8)))}
    pose["neck"] = (5 * rock, 0, 0)
    pose["horseHead"] = (-4 * rock, 0, 0)
    pose["tail"] = (-12 - 4 * rock, 0, 0)
    pose["hips"] = (2 * rock, 0, 0)
    return pose


IDLE = {}
for f in range(0, 121, 10):
    u = f / 120
    IDLE[f] = merge(CARRY, {
        "neck": (6 * math.sin(2 * math.pi * u) + 3, 0, 4 * math.sin(4 * math.pi * u)),
        "horseHead": (8 * max(0.0, math.sin(2 * math.pi * (u - 0.2))), 0, 0),
        "tail": (-10, 0, 18 * math.sin(6 * math.pi * u)),
        "hindShinR": (-14 * max(0.0, math.sin(2 * math.pi * (u - 0.5))), 0, 0),
        "body": {"turn": (0, 1.5 * math.sin(2 * math.pi * u), 0), "shift": (0, 0, 0)},
        "head": (2, 0, 24 * math.sin(2 * math.pi * (u - 0.1))),
        "torso": (0, 0, 6 * math.sin(2 * math.pi * (u - 0.1))),
    })
keyed(rig, "idle", 120, IDLE, **STILL)

march = {}
for k in range(13):
    f = 2.5 * k
    march[f] = merge(CARRY, stride((f / 15) % 1.0), {"heldR": (38 + 3 * math.sin(2 * math.pi * f / 15), 0, 0)})
keyed(rig, "march", 30, march, **STILL)

# The charge: three long strides, the rider low over the neck, the lance
# brought down from upright and couched at the foe.


def couched(share):
    """The right arm and the lance a share of the way from upright to
    couched under the arm, pointing ahead."""
    arm = least(Vector((0, 0, -1)), Vector((-0.05, -0.75 * share, -1 + 0.6 * share)))
    fore = least(Vector((0, 0, -1)), Vector((0.12 * share, -1.0 * share, -1 + share)))
    aim = Vector((0.05 * share, -math.sin(math.radians(90 * share)), math.cos(math.radians(90 * share))))
    lean = Matrix.Rotation(math.radians(16 * share), 3, "X")
    lance_turn = least(Vector((0, 0, 1)), aim)
    return {"armR": {"rotation": lean.inverted() @ arm}, "forearmR": {"rotation": arm.inverted() @ fore},
            "heldR": {"rotation": fore.inverted() @ lance_turn}, "torso": (16 * share, 0, 0), "head": (-12 * share, 0, 0)}


def least(a, b):
    return a.normalized().rotation_difference(b.normalized()).to_matrix()


charge = {}
for k in range(19):
    f = 2.5 * k
    share = min(1.0, f / 10) if f < 38 else max(0.0, 1 - (f - 38) / 7)
    charge[f] = merge(CARRY, stride((f / 15) % 1.0, reach=32, fold=90), couched(share))
keyed(rig, "attack", 45, charge, **STILL)

# Struck: the horse shies and half rears, its rider rocked back.
REAR_PIVOT = Vector(HIND_TOP) * Vector((0, 1, 1))
BODY_HEAD = Vector(HORSE_BONES[0][1])


def shied(share):
    turn = Matrix.Rotation(math.radians(-24 * share), 3, "X")
    shift = (turn @ (BODY_HEAD - REAR_PIVOT) + REAR_PIVOT) - BODY_HEAD
    pose = merge(CARRY, {
        "body": {"rotation": turn, "shift": tuple(shift + Vector((0, 0, 0.04 * share)))},
        "foreLegL": (-48 * share, 0, 0), "foreShinL": (96 * share, 0, 0), "foreLegR": (-56 * share, 0, 0), "foreShinR": (104 * share, 0, 0),
        "hindLegL": (24 * share, 0, 0), "hindShinL": (-10 * share, 0, 0), "hindLegR": (26 * share, 0, 0), "hindShinR": (-12 * share, 0, 0),
        "neck": (-14 * share, 0, 0), "horseHead": (-10 * share, 0, 8 * share), "tail": (-20 * share, 0, 0),
        "hips": (18 * share, 0, 0), "torso": (-6 * share, 0, 4 * share), "head": (-8 * share, 0, -10 * share),
        "armR": (-8 + 14 * share, 0, 4 - 8 * share), "armL": (-14 - 30 * share, 0, -6 - 8 * share), "forearmL": (-62 - 18 * share, 0, 0),
    })
    return pose


hit = {0: shied(0), 3: shied(0.15), 6: shied(1.0), 14: shied(0.7), 25: shied(0.25), 32: shied(0.05), 36: shied(0), 45: shied(0)}
keyed(rig, "hit", 45, hit, **STILL)

# Down: the horse falls on its off side, its rider thrown clear and lying
# on his back beside it.
FALLEN = Matrix.Rotation(math.radians(-84), 3, "Y")
DOWN = Vector((0, 0, GROUND + 0.27)) - BODY_HEAD
THROWN = Matrix.Rotation(math.radians(-88), 3, "X")


def fallen(share):
    turn = Matrix.Rotation(math.radians(-84 * share), 3, "Y")
    pose = merge(CARRY, {
        "body": {"rotation": turn, "shift": tuple(DOWN * share + Vector((0.12 * share, 0, 0)))},
        "foreLegL": (-30 * share, 0, 0), "foreShinL": (40 * share, 0, 0), "foreLegR": (-14 * share, 0, 0), "foreShinR": (24 * share, 0, 0),
        "hindLegL": (20 * share, 0, 0), "hindShinL": (-20 * share, 0, 0), "hindLegR": (10 * share, 0, 0), "hindShinR": (-10 * share, 0, 0),
        "neck": (-6 * share, 0, -30 * share), "horseHead": (-20 * share, 0, 0), "tail": (0, 0, 0),
    })
    # The rider, out of the saddle: his hips on the ground beyond the
    # horse's back, lying on his back with his knees up as his seat held
    # them, whatever the horse's body does.
    rider_turn = turn.inverted() @ Matrix.Rotation(math.radians(-60 * share), 3, "X")
    hips_world = Vector((0.95 * share, 0.15 * share, SEAT + (GROUND + 0.13 - SEAT) * share))
    body_world = turn @ (Vector((0, 0, SEAT)) - BODY_HEAD) + BODY_HEAD + DOWN * share + Vector((0.12 * share, 0, 0))
    pose["hips"] = {"rotation": rider_turn, "shift": tuple(turn.inverted() @ (hips_world - body_world))}
    # His cloak, trailing back from his shoulders, laid flat under him.
    pose.update({"torso": (-25 * share, 0, 0), "armL": (-10, -60 * share, 0), "armR": (-6, 56 * share, 0), "heldR": (38 - 26 * share, 0, 0),
                 "head": (-14 * share, 0, 10 * share), "cloak": (-58 * share, 0, 0)})
    return pose


death = {0: fallen(0), 6: fallen(0.12), 12: fallen(0.35), 22: fallen(0.75), 30: fallen(1.0), 38: fallen(1.0), 45: fallen(1.0)}
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
        u = (half + f) / 60
        gather[half + f] = merge(DISMOUNTED, swing(lift, strike), {"neck": (52, 0, 0), "horseHead": (24 + 8 * math.sin(4 * math.pi * u), 0, 0)})
gather[60] = merge(DISMOUNTED, swing(0, 0), {"neck": (52, 0, 0), "horseHead": (24, 0, 0)})
keyed(rig, "gather", 60, gather, hidden=["heldR", "heldL"], shown=["tool"])

man.finish(out_path("Art/models/rider.glb"),
           [(1, None), (2, None), (3, None), (4, None), (5, None), (5, "blackwood"), (5, "moundClans")])
