"""The horse every rider and commander sits: its skeleton's twelve bones,
which the rider's seat hangs from, its skinned body, its tack and the
House's cloth, and the keys its legs and body take through each clip.

It is made beneath a rider seated at a man's height, its hooves below the
ground (GROUND), and the game lifts the whole of it as it reads it. Its
bones are the first of the rig every horse and rider keeps (Steed, in
Sources/NullmereModels/Riders.swift): the body, neck, head and tail, then
the fore legs and the hind, each leg and its shin. The rider's legs, made
astride round its barrel (SEATED), are carried by his seat: their bones
are folded into it (FOLDED) before the clips are keyed.
"""
import math

from mathutils import Matrix, Vector

from common import *

GROUND = -0.56
SEAT = 0.90


def mirror(point, s):
    return (point[0] * s, point[1], point[2])


# MARK: The skeleton, before the rider's

FORE_TOP, FORE_KNEE, FORE_FETLOCK, FORE_HOOF = (0.15, -0.60, 0.42), (0.15, -0.62, -0.04), (0.15, -0.60, -0.42), (0.15, -0.64, GROUND)
HIND_TOP, HIND_HOCK, HIND_FETLOCK, HIND_HOOF = (0.16, 0.66, 0.44), (0.16, 0.82, -0.02), (0.16, 0.74, -0.42), (0.16, 0.71, GROUND)
BONES = [
    ("body", (0, 0.05, 0.57), (0, -0.55, 0.57), None),
    ("neck", (0, -0.58, 0.84), (0, -0.98, 1.28), "body"),
    ("horseHead", (0, -1.02, 1.33), (0, -1.36, 0.98), "neck"),
    ("tail", (0, 0.97, 0.80), (0, 1.12, 0.30), "body"),
]
for _front, (_top, _joint, _low) in (("fore", (FORE_TOP, FORE_KNEE, FORE_FETLOCK)), ("hind", (HIND_TOP, HIND_HOCK, HIND_FETLOCK))):
    for _s, _side in ((1, "L"), (-1, "R")):
        BONES.append(("%sLeg%s" % (_front, _side), mirror(_top, _s), mirror(_joint, _s), "body"))
        BONES.append(("%sShin%s" % (_front, _side), mirror(_joint, _s), mirror(_low, _s), "%sLeg%s" % (_front, _side)))
# The rig keeps the fore legs before the hind: left, its shin, right, its shin.
BONES = BONES[:4] + [b for b in BONES[4:] if b[0].startswith("fore")] + [b for b in BONES[4:] if b[0].startswith("hind")]

# The rider astride: hips on the saddle, thighs out and forward round the
# barrel, shins down to the stirrups.
SEATED = {}
for _s, _side in ((1, "L"), (-1, "R")):
    SEATED[_side] = ((_s * 0.11, 0.0, SEAT), (_s * 0.33, -0.30, 0.66), (_s * 0.30, -0.22, 0.26))


def astride():
    """The bones of the body every person shares hung astride the horse,
    as Person takes them (`moved`): the hips on the saddle and the legs
    round the barrel."""
    moved = {"hips": ((0, 0, SEAT), (0, 0, SEAT + 0.1), "body")}
    for side, (hip, knee, ankle) in SEATED.items():
        moved["thigh" + side] = (hip, knee, "hips")
        moved["shin" + side] = (knee, ankle, "thigh" + side)
        moved["foot" + side] = (ankle, (ankle[0], ankle[1] - 0.14, ankle[2] - 0.05), "shin" + side)
    return moved


# The rider's legs carried by his seat, astride or down from the saddle,
# and the bone the rig keeps for a lantern by his torso: the 23 bones after
# the game's root that every horse and rider moves on.
FOLDED = {"thighL": "hips", "shinL": "hips", "footL": "hips", "thighR": "hips", "shinR": "hips", "footR": "hips", "extra": "torso"}


# MARK: Its body and tack


class Horse:
    """The horse on `rig`, in its own materials: its coat, socks and mane
    (which the game colours as each horse is), its hooves, and the House's
    cloth of its caparison; leather and steel from the rider's palette `p`."""

    def __init__(self, rig, p, coat, socks, mane, hoof, cloth):
        self.rig, self.p = rig, p
        self.coat, self.socks, self.mane, self.hoof, self.cloth = coat, socks, mane, hoof, cloth

    def barrel(self, name, inflate, segments, lean=False):
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
        return loft(name, [(c, rx + inflate, ry + inflate, {"body": 1.0}) for c, rx, ry in sections], segments=segments, mat=self.coat)

    def body(self, bare, maned):
        """Its body: the barrel where `bare` (under a caparison the cloth is
        its body, far and near; None, always caparisoned), neck, head, ears
        and face, its mane where `maned`, forelock and tail, and its legs."""
        rig, p, coat, mane = self.rig, self.p, self.coat, self.mane
        if bare is not None:
            bind(self.barrel("horse body" + bare, 0, 6, lean=True), rig)
            bind(self.barrel("horse body close%s!fine" % bare, 0.006, 12), rig)
        neck_rings = [((0, -0.55, 0.84), 0.14, 0.21, {"body": 0.5, "neck": 0.5}), ((0, -0.78, 1.04), 0.12, 0.16, {"neck": 1.0}),
                      ((0, -0.96, 1.24), 0.09, 0.11, {"neck": 0.7, "horseHead": 0.3}), ((0, -1.03, 1.34), 0.075, 0.09, {"horseHead": 1.0})]
        paired(rig, "horse neck", neck_rings, far=4, near=8, between=1, mat=coat, caps=(False, False))
        head_rings = [((0, -1.03, 1.34), 0.075, 0.09, {"horseHead": 1.0}), ((0, -1.12, 1.25), 0.085, 0.10, {"horseHead": 1.0}),
                      ((0, -1.23, 1.13), 0.072, 0.085, {"horseHead": 1.0}), ((0, -1.33, 1.02), 0.055, 0.062, {"horseHead": 1.0}),
                      ((0, -1.39, 0.95), 0.045, 0.045, {"horseHead": 1.0})]
        paired(rig, "horse head", [head_rings[0], head_rings[2], head_rings[4]], far=5, near=8, between=2, mat=coat, caps=(False, True))
        ears = [solid("ear", "cone", mat=coat, vertices=3, radius1=0.025, depth=0.11, location=(s * 0.05, -1.05, 1.42),
                      rotation=(-10, s * 12, 0)) for s in (1, -1)]
        hang(join("horse ears", ears), rig, "horseHead")
        features = []
        for s in (1, -1):
            features.append(solid("eye", "sphere", mat=p.eye, segments=5, rings=3, radius=(0.014, 0.022, 0.018), location=(s * 0.078, -1.14, 1.23)))
            features.append(solid("nostril", "sphere", mat=p.eye, segments=4, rings=3, radius=(0.012, 0.014, 0.01),
                                  location=(s * 0.028, -1.385, 0.98)))
        hang(join("horse face!fine", features), rig, "horseHead")
        # The mane along the crest of the neck, and the forelock.
        mane_rings = [((0, -0.56, 1.03), 0.022, 0.05, {"body": 0.4, "neck": 0.6}), ((0, -0.76, 1.19), 0.022, 0.055, {"neck": 1.0}),
                      ((0, -0.95, 1.36), 0.02, 0.045, {"neck": 0.6, "horseHead": 0.4})]
        paired(rig, "mane", mane_rings, far=3, near=6, between=1, mat=mane, caps=(False, False), tags=maned)
        hang(solid("forelock!fine", "cone", mat=mane, vertices=4, radius1=0.03, depth=0.09, location=(0, -1.09, 1.36), rotation=(150, 0, 0)),
             rig, "horseHead")
        tail_lean, tail_full = paired(rig, "horse tail", [((0, 0.97, 0.80), 0.05, 0.05, {"tail": 1.0}), ((0, 1.05, 0.55), 0.06, 0.05, {"tail": 1.0}),
                                                          ((0, 1.11, 0.28), 0.03, 0.025, {"tail": 1.0})], far=3, near=8, between=1, mat=mane,
                                      caps=(False, True))
        for piece in (tail_lean, tail_full):
            sway(piece, lambda q: max(0.0, min(1.0, (0.78 - q.z) / 0.5)))
        self.legs()

    def legs(self):
        rig = self.rig
        for front, (top, joint, low, foot), (r_top, r_joint) in (("fore", (FORE_TOP, FORE_KNEE, FORE_FETLOCK, FORE_HOOF), (0.075, 0.048)),
                                                                 ("hind", (HIND_TOP, HIND_HOCK, HIND_FETLOCK, HIND_HOOF), (0.085, 0.05))):
            for s, side in ((1, "L"), (-1, "R")):
                leg, shin = "%sLeg%s" % (front, side), "%sShin%s" % (front, side)
                t, j, l, f = (Vector(mirror(x, s)) for x in (top, joint, low, foot))
                # Far off, one lean leg to the hoof.
                bind(loft("%s leg %s" % (front, side), [(tuple(t), r_top, r_top * 1.15, {leg: 1.0}),
                                                        (tuple(j), r_joint, r_joint * 1.1, {leg: 0.5, shin: 0.5}),
                                                        (tuple(f), 0.05, 0.055, {shin: 1.0})], segments=4, mat=self.coat, caps=(False, True)), rig)
                # Near, rounded, the socks and the hoof their own.
                bind(loft("%s leg close %s!fine" % (front, side), [(tuple(t + Vector((0, 0, 0.12))), r_top * 1.2, r_top * 1.4, {"body": 0.6, leg: 0.4}),
                                                                  (tuple(t), r_top + 0.004, r_top * 1.15 + 0.004, {leg: 1.0}),
                                                                  (tuple(t + (j - t) * 0.5), r_top * 0.8, r_top * 0.9, {leg: 1.0}),
                                                                  (tuple(j), r_joint + 0.004, r_joint * 1.1 + 0.004, {leg: 0.5, shin: 0.5})],
                          segments=8, mat=self.coat, caps=(False, False)), rig)
                bind(loft("%s cannon %s!fine" % (front, side), [(tuple(j), r_joint + 0.004, r_joint * 1.1 + 0.004, {leg: 0.5, shin: 0.5}),
                                                               (tuple(j + (l - j) * 0.5), 0.038, 0.042, {shin: 1.0}),
                                                               (tuple(l), 0.04, 0.044, {shin: 1.0})],
                          segments=6, mat=self.socks, caps=(False, False)), rig)
                bind(loft("%s hoof %s!fine" % (front, side), [(tuple(l), 0.04, 0.044, {shin: 1.0}),
                                                             (tuple(f + Vector((0, -0.01, 0.06))), 0.052, 0.056, {shin: 1.0}),
                                                             (tuple(f + Vector((0, -0.015, 0.0))), 0.059, 0.066, {shin: 1.0})],
                          segments=6, mat=self.hoof, caps=(False, True)), rig)

    def tack(self):
        """Saddle, stirrups and their leathers, and the bridle."""
        rig, p = self.rig, self.p
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

    def saddle_cloth(self, tags):
        """The House's cloth under the saddle, a band about the barrel."""
        rings = [((0, 0.38, 0.57), 0.285, 0.385), ((0, 0.0, 0.56), 0.285, 0.39), ((0, -0.34, 0.58), 0.275, 0.38)]
        bind(loft("saddle cloth" + tags, [(c, rx, ry, {"body": 1.0}) for c, rx, ry in rings], segments=6, mat=self.p.tunic,
                  caps=(False, False)), self.rig)
        bind(loft("saddle cloth close%s!fine" % tags, [(c, rx + 0.004, ry + 0.004, {"body": 1.0}) for c, rx, ry in rings], segments=14,
                  mat=self.p.tunic, caps=(False, False)), self.rig)

    def caparison(self, tags, hem):
        """The House's cloth draped from the back to the knees or near the
        ground, front and rear, the legs and the head out of it."""
        rings = [((0, 0.06, 0.97), 0.12, 0.50), ((0, 0.06, 0.80), 0.29, 0.88), ((0, 0.06, 0.60), 0.31, 0.97), ((0, 0.06, hem), 0.33, 1.02)]
        for name, segments, inflate in (("caparison" + tags, 6, 0.0), ("caparison close" + tags + "!fine", 14, 0.004)):
            piece = loft(name, [(c, rx + inflate, ry + inflate, {"body": 1.0}) for c, rx, ry in rings], segments=segments, mat=self.cloth,
                         caps=(False, False))
            sway(piece, lambda q, h=hem: max(0.0, min(1.0, (0.7 - q.z) / (0.7 - h))) * 0.5)
            bind(piece, self.rig)

    def barding(self, tags):
        """Steel on the face and the breast: a chanfron and a peytral."""
        steel = self.p.steel
        hang(solid("chanfron" + tags, "box", mat=steel, location=(0, -1.24, 1.16), size=(0.12, 0.04, 0.30), rotation=(-48, 0, 0)), self.rig,
             "horseHead")
        hang(loft("peytral" + tags, [((0, -0.70, 0.62), 0.27, 0.30, {}), ((0, -0.84, 0.62), 0.2, 0.26, {})], segments=8, mat=steel,
                  caps=(False, False)), self.rig, "body")

    def crinet(self, tags):
        """Steel plates along the crest of the neck where the mane would be."""
        paired(self.rig, "crinet", [((0, -0.56, 1.0), 0.06, 0.07, {"body": 0.4, "neck": 0.6}), ((0, -0.77, 1.17), 0.055, 0.065, {"neck": 1.0}),
                                    ((0, -0.95, 1.34), 0.045, 0.05, {"neck": 0.6, "horseHead": 0.4})], far=3, near=8, between=1,
               mat=self.p.steel, caps=(True, True), tags=tags)


# MARK: What its rider wears that lies on it


def trailing_cloak(man, tags, trail):
    """The House's cloak from the rider's shoulders, down his back, over the
    cantle and back over the horse's croup `trail` beyond it, swaying free
    toward its hem."""
    rig, p = man.rig, man.p
    end = (0, 0.36 + trail, 1.02 - 0.08 * trail)
    lean, full = paired(rig, "cloak", [((0, 0.11, 1.40), 0.2, 0.045, {"torso": 0.7, "cloak": 0.3}),
                                       ((0, 0.29, 1.10), 0.27, 0.05, {"cloak": 1.0}),
                                       (end, 0.31, 0.05, {"cloak": 1.0})],
                        far=man.far(8), near=man.near(16), between=3, mat=p.cloak_cloth, tags=tags, inflate=0.003)
    for piece in (lean, full):
        sway(piece, lambda q: max(0.0, min(1.0, (q.y - 0.11) / (end[1] - 0.11))))
    hang(solid("clasp%s!fine" % tags, "sphere", mat=p.steel, segments=8, rings=4, radius=(0.025, 0.012, 0.025),
               location=(0.0, -0.1, 1.41)), rig, "torso")


def seated_tabard(man, tags, segments=6):
    """The House on the rider's chest, to his seat on the saddle."""
    bind(loft("tabard" + tags, [((0, 0.0, 1.36), 0.222, 0.128, {"torso": 1.0}), ((0, -0.015, 1.26), 0.212, 0.14, {"torso": 1.0}),
                                ((0, -0.005, 1.12), 0.186, 0.125, {"torso": 1.0}), ((0, 0.0, 0.99), 0.18, 0.13, {"hips": 0.5, "torso": 0.5})],
              segments=segments, mat=man.p.tunic, caps=(False, False)), man.rig)


# MARK: How it moves

LEGS = ("foreLegL", "foreLegR", "hindLegL", "hindLegR")
# The canter, leading with the near fore: off hind, then near hind with off
# fore, then near fore, then all four off the ground.
CONTACTS = {"hindLegR": 0.0, "hindLegL": 0.16, "foreLegR": 0.16, "foreLegL": 0.32}
REAR_PIVOT = Vector(HIND_TOP) * Vector((0, 1, 1))
BODY_HEAD = Vector(BONES[0][1])
DOWN = Vector((0, 0, GROUND + 0.27)) - BODY_HEAD


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


def canter(u, reach=27, fold=80):
    """The canter `u` of the way through a stride: each leg on its beat, the
    body rocking and the neck nodding with it, the rider's seat with them."""
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


def at_rest(u):
    """The horse at rest `u` of the way through its idle: shifting its weight,
    nodding, a hind hoof cocked, its tail swishing."""
    return {
        "neck": (6 * math.sin(2 * math.pi * u) + 3, 0, 4 * math.sin(4 * math.pi * u)),
        "horseHead": (8 * max(0.0, math.sin(2 * math.pi * (u - 0.2))), 0, 0),
        "tail": (-10, 0, 18 * math.sin(6 * math.pi * u)),
        "hindShinR": (-14 * max(0.0, math.sin(2 * math.pi * (u - 0.5))), 0, 0),
        "body": {"turn": (0, 1.5 * math.sin(2 * math.pi * u), 0), "shift": (0, 0, 0)},
    }


def least(a, b):
    """The least turn taking direction a to direction b, as a matrix."""
    return a.normalized().rotation_difference(b.normalized()).to_matrix()


def couched(share):
    """The right arm and the lance in it a share of the way from upright to
    couched under the arm, pointing ahead, the rider low over the neck."""
    arm = least(Vector((0, 0, -1)), Vector((-0.05, -0.75 * share, -1 + 0.6 * share)))
    fore = least(Vector((0, 0, -1)), Vector((0.12 * share, -1.0 * share, -1 + share)))
    aim = Vector((0.05 * share, -math.sin(math.radians(90 * share)), math.cos(math.radians(90 * share))))
    lean = Matrix.Rotation(math.radians(16 * share), 3, "X")
    lance_turn = least(Vector((0, 0, 1)), aim)
    return {"armR": {"rotation": lean.inverted() @ arm}, "forearmR": {"rotation": arm.inverted() @ fore},
            "heldR": {"rotation": fore.inverted() @ lance_turn}, "torso": (16 * share, 0, 0), "head": (-12 * share, 0, 0)}


def shied(share):
    """Struck, a share of the way to the worst: the horse shying half up on
    its hind legs about its hips, its rider rocked back in the saddle."""
    turn = Matrix.Rotation(math.radians(-24 * share), 3, "X")
    shift = (turn @ (BODY_HEAD - REAR_PIVOT) + REAR_PIVOT) - BODY_HEAD
    return {
        "body": {"rotation": turn, "shift": tuple(shift + Vector((0, 0, 0.04 * share)))},
        "foreLegL": (-48 * share, 0, 0), "foreShinL": (96 * share, 0, 0), "foreLegR": (-56 * share, 0, 0), "foreShinR": (104 * share, 0, 0),
        "hindLegL": (24 * share, 0, 0), "hindShinL": (-10 * share, 0, 0), "hindLegR": (26 * share, 0, 0), "hindShinR": (-12 * share, 0, 0),
        "neck": (-14 * share, 0, 0), "horseHead": (-10 * share, 0, 8 * share), "tail": (-20 * share, 0, 0),
        "hips": (18 * share, 0, 0), "torso": (-6 * share, 0, 4 * share), "head": (-8 * share, 0, -10 * share),
    }


def fallen(share):
    """Down, a share of the way: the horse fallen on its off side, its rider
    thrown clear, his hips on the ground beyond its back, lying on his back
    with his knees up as his seat held them and his cloak flat under him,
    whatever the horse's body does."""
    turn = Matrix.Rotation(math.radians(-84 * share), 3, "Y")
    pose = {
        "body": {"rotation": turn, "shift": tuple(DOWN * share + Vector((0.12 * share, 0, 0)))},
        "foreLegL": (-30 * share, 0, 0), "foreShinL": (40 * share, 0, 0), "foreLegR": (-14 * share, 0, 0), "foreShinR": (24 * share, 0, 0),
        "hindLegL": (20 * share, 0, 0), "hindShinL": (-20 * share, 0, 0), "hindLegR": (10 * share, 0, 0), "hindShinR": (-10 * share, 0, 0),
        "neck": (-6 * share, 0, -30 * share), "horseHead": (-20 * share, 0, 0), "tail": (0, 0, 0),
    }
    rider_turn = turn.inverted() @ Matrix.Rotation(math.radians(-60 * share), 3, "X")
    hips_world = Vector((0.95 * share, 0.15 * share, SEAT + (GROUND + 0.13 - SEAT) * share))
    body_world = turn @ (Vector((0, 0, SEAT)) - BODY_HEAD) + BODY_HEAD + DOWN * share + Vector((0.12 * share, 0, 0))
    pose["hips"] = {"rotation": rider_turn, "shift": tuple(turn.inverted() @ (hips_world - body_world))}
    pose.update({"torso": (-25 * share, 0, 0), "armL": (-10, -60 * share, 0), "armR": (-6, 56 * share, 0), "head": (-14 * share, 0, 10 * share),
                 "cloak": (-58 * share, 0, 0)})
    return pose


def grazing(u):
    """The horse cropping the grass `u` of the way through its gathering."""
    return {"neck": (52, 0, 0), "horseHead": (24 + 8 * math.sin(4 * math.pi * u), 0, 0)}
