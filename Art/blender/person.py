"""A person on foot, as every kind that walks is made: one body under a skin
weighted to its bones ring by ring, lean for afar and rounded close, its
hands, head and face; the coats, helms, cloaks and tools a kind puts on it;
and the clips the world plays, built from the way a kind carries its arms.

Made 1.8 tall, facing -y with its left at +x; the game takes it at a sixth
of that. Its bones after the root are in the order of the rig every figure
on foot keeps (Limb in Sources/NullmereModels/Person.swift), then its feet,
then any its kind adds. Pieces are tagged for the tiers (@1-5) and the
variants (@saltborn) they are worn at; "!fine" only near.
"""
import math
import os
import re

from common import *


class Palette:
    """The materials people are made of and wear, in sRGB as chosen."""

    def __init__(self):
        self.skin = material("plain_skin", (0.80, 0.60, 0.47), roughness=0.6)
        self.hair = material("plain_hair", (0.24, 0.16, 0.10))
        self.wool = material("plain_wool", (0.30, 0.27, 0.24))
        self.linen = material("plain_linen", (0.70, 0.64, 0.52))
        self.salt_linen = material("plain_saltlinen", (0.88, 0.87, 0.82))
        self.salt_crust = material("plain_saltcrust", (0.80, 0.84, 0.86))
        self.leather = material("plain_leather", (0.38, 0.25, 0.15))
        self.dark_leather = material("plain_darkleather", (0.22, 0.15, 0.10))
        self.tunic = material("house_tunic", (0.52, 0.52, 0.52))
        self.trim = material("house_trim", (0.42, 0.42, 0.42))
        self.iron = material("metal_iron", (0.50, 0.52, 0.56), roughness=0.4, metallic=0.9)
        self.dark_iron = material("metal_darkiron", (0.30, 0.31, 0.34), roughness=0.5, metallic=0.9)
        self.steel = material("metal_steel", (0.72, 0.74, 0.78), roughness=0.3, metallic=1.0)
        self.shaft = material("plain_timber_shaft", (0.50, 0.36, 0.22))
        self.board = material("plain_timber_board", (0.56, 0.43, 0.28))
        self.painted = material("house_timber_shield", (0.58, 0.58, 0.58))
        self.cloak_cloth = material("cloth_cloak", (0.50, 0.50, 0.50))
        self.plume_cloth = material("cloth_plume", (0.62, 0.62, 0.62))
        self.eye = material("plain_eye", (0.08, 0.07, 0.06))


class Build:
    """How a kind is built: `girth` the breadth and depth of its body and
    limbs (a spearman's 1, an archer's spare), `shoulders` how far out its
    arms hang; `lean`, fewer sides to what is drawn far off."""

    def __init__(self, girth=1.0, shoulders=1.0, lean=False):
        self.girth = girth
        self.shoulders = shoulders
        # Leaner still far off, for a figure that must share its budget
        # (a rider with his horse): fewer sides to every lean piece.
        self.lean = lean


# The head, a tenth larger than life so a face reads from the camera's height.
HEAD = (0, -0.012, 1.595)
HEAD_R = (0.103, 0.114, 0.13)


def at_head(dx, dy, dz):
    return (HEAD[0] + dx * 1.1, HEAD[1] + dy * 1.1, HEAD[2] + dz * 1.1)


def helm_radii(margin):
    return tuple(r + margin for r in HEAD_R)


def merge(*poses):
    out = {}
    for pose in poses:
        for bone, value in pose.items():
            out[bone] = value
    return out


def skirt_weights(top):
    """A skirt's ring: `top` with the hips, the rest with the thigh beneath
    each side, shared in the middle."""
    def weights(p):
        left = max(0.0, min(1.0, 0.5 + p.x / 0.3))
        rest = 1.0 - top
        return {"hips": top, "thighL": rest * left, "thighR": rest * (1 - left)}
    return weights


def stride(t, lead):
    """A leg through the march's cycle: forward at the heel's strike (0),
    passing under (0.25), back at the toe's lift (0.5), passing (0.75)."""
    thigh = {0.0: -26, 0.25: -6, 0.5: 24, 0.75: 2}
    shin = {0.0: 4, 0.25: 8, 0.5: 32, 0.75: 58}
    foot = {0.0: -14, 0.25: 0, 0.5: 18, 0.75: 6}
    u = (t + (0 if lead else 0.5)) % 1.0
    return thigh[round(u, 2)], shin[round(u, 2)], foot[round(u, 2)]


class Person:
    """A kind's figure: its armature, its build and its materials; `variants`
    the heritages it is also made for, as a list in tags ("saltborn,...")."""

    def __init__(self, name, variants, build=None, more_bones=(), moved=None, before_bones=()):
        """`more_bones` added after the feet, `before_bones` before the
        person's own (a rider's horse, which his seat hangs from); `moved`,
        {name: (head, tail, parent)}, bones of the shared rig hung elsewhere
        by this kind (the archer's `extra` at the bow, a rider's legs astride)."""
        self.build = build or Build()
        self.p = Palette()
        self.variants = variants
        bones = [(name_, *moved[name_]) if moved and name_ in moved else (name_, head, tail, parent)
                 for name_, head, tail, parent in self.bones()]
        self.rig = armature(name, list(before_bones) + bones + list(more_bones))

    def ax(self, x):
        """An x across the body where the arms hang, by the build."""
        return x * self.build.shoulders

    def far(self, sides):
        """The sides of a lean piece, by the build."""
        return sides - 2 if self.build.lean else sides

    def near(self, sides):
        """The sides of a rounded piece drawn close, by the build."""
        return sides - max(2, sides // 4) if self.build.lean else sides

    def between(self, rings):
        """The rings eased in between each two of a piece drawn close."""
        return max(1, rings - 1) if self.build.lean else rings

    def g(self, r):
        """A radius of the body or a limb, by the build."""
        return r * self.build.girth

    def every(self, tiers):
        """Tags for these tiers and for every variant."""
        return "@%s,%s" % (tiers, self.variants)

    def bones(self):
        a = self.ax
        return [
            ("hips", (0, 0, 0.90), (0, 0, 1.00), None),
            ("torso", (0, 0, 1.00), (0, 0, 1.42), "hips"),
            ("head", (0, 0, 1.44), (0, 0, 1.76), "torso"),
            ("armL", (a(0.25), 0, 1.38), (a(0.28), 0, 1.02), "torso"),
            ("forearmL", (a(0.28), 0, 1.02), (a(0.295), -0.01, 0.74), "armL"),
            ("armR", (a(-0.25), 0, 1.38), (a(-0.28), 0, 1.02), "torso"),
            ("forearmR", (a(-0.28), 0, 1.02), (a(-0.295), -0.01, 0.74), "armR"),
            ("thighL", (0.11, 0, 0.90), (0.12, 0, 0.49), "hips"),
            ("shinL", (0.12, 0, 0.49), (0.12, 0.01, 0.09), "thighL"),
            ("thighR", (-0.11, 0, 0.90), (-0.12, 0, 0.49), "hips"),
            ("shinR", (-0.12, 0, 0.49), (-0.12, 0.01, 0.09), "thighR"),
            ("heldR", (a(-0.30), -0.02, 0.72), (a(-0.30), -0.02, 0.92), "forearmR"),
            ("heldL", (a(0.30), -0.02, 0.72), (a(0.30), -0.12, 0.72), "forearmL"),
            ("cloak", (0, 0.13, 1.38), (0, 0.16, 1.00), "torso"),
            ("tool", (a(-0.30), -0.02, 0.72), (a(-0.30), -0.02, 0.92), "forearmR"),
            ("extra", (0, 0.05, 1.20), (0, 0.05, 1.30), "torso"),
            ("footL", (0.12, 0.01, 0.09), (0.12, -0.12, 0.03), "shinL"),
            ("footR", (-0.12, 0.01, 0.09), (-0.12, -0.12, 0.03), "shinR"),
        ]

    # MARK: The body every tier and variant shares

    def body(self, hands, face, seated=None):
        """Legs, boots, bracers and hands, neck, head and face, and the belt.
        `hands`: (tags, material) for the hands each tier or variant wears,
        bare or gauntleted; `face`: the tags it is drawn for, where no helm
        hides it; `seated`, for a rider, {side: (hip, knee, ankle)} where
        each leg bends astride."""
        body_parts = []
        for side in ("L", "R"):
            if seated:
                body_parts.append(self.seated_leg(side, *seated[side]))
            else:
                body_parts.append(self.standing_leg(side))
            self.arm_end(side, hands)
            if seated:
                self.seated_bands(side, *seated[side])
            else:
                self.standing_bands(side)
        self.head_and_belt(face, body_parts)

    def standing_leg(self, side):
        """A leg standing, and its boot; the boot's foot is returned for the
        body."""
        rig, p, g = self.rig, self.p, self.g
        s = 1 if side == "L" else -1
        thigh, shin, foot = "thigh" + side, "shin" + side, "foot" + side
        paired(rig, "leg " + side, [
            ((s * 0.105, 0.0, 0.94), g(0.104), g(0.11), {"hips": 0.55, thigh: 0.45}),
            ((s * 0.12, 0.0, 0.49), g(0.063), g(0.069), {thigh: 0.5, shin: 0.5}),
            ((s * 0.12, 0.013, 0.30), g(0.062), g(0.07), {shin: 1.0}),
        ], far=self.far(6), near=self.near(12), between=2, mat=p.wool)
        paired(rig, "boot " + side, [
            ((s * 0.12, 0.01, 0.335), g(0.07), g(0.078), {shin: 1.0}),
            ((s * 0.12, 0.012, 0.12), g(0.058), g(0.064), {shin: 0.6, foot: 0.4}),
        ], far=self.far(6), near=self.near(12), between=1, mat=p.leather)
        boot = solid("foot " + side, "box", mat=p.leather, weights={foot: 1.0}, location=(s * 0.12, -0.045, 0.055),
                     size=(0.105, 0.24, 0.11))
        shape_vertices(boot, lambda v: Vector((v.x * (0.7 if v.y < -0.1 else 1.0), v.y,
                                               v.z * (0.6 if v.y < -0.1 else 1.0) + (-0.02 if v.y < -0.1 else 0))))
        return boot

    def arm_end(self, side, hands):
        """The bracer and hand of an arm, as each tier or variant wears it."""
        rig, p, g, a = self.rig, self.p, self.g, self.ax
        s = 1 if side == "L" else -1
        forearm = "forearm" + side
        paired(rig, "bracer " + side, [
            ((a(s * 0.282), 0.0, 1.03), g(0.052), g(0.054), {"arm" + side: 0.5, forearm: 0.5}),
            ((a(s * 0.295), -0.01, 0.765), g(0.04), g(0.043), {forearm: 1.0}),
        ], far=self.far(6), near=self.near(12), between=2, mat=p.leather)
        for tags, mat in hands:
            hand = solid("hand %s%s" % (side, tags), "sphere", mat=mat, smooth=True, segments=4 if self.build.lean else 5,
                         rings=3,
                         radius=(0.038, 0.033, 0.058), location=(a(s * 0.299), -0.014, 0.705))
            hang(hand, rig, forearm)
            close_hand = solid("hand close %s%s!fine" % (side, tags), "sphere", mat=mat, smooth=True, segments=8, rings=5,
                               radius=(0.041, 0.036, 0.061), location=(a(s * 0.299), -0.014, 0.705))
            hang(close_hand, rig, forearm)
            thumb = solid("thumb %s%s!fine" % (side, tags), "box", mat=mat, location=(a(s * 0.282), -0.045, 0.725),
                          size=(0.022, 0.03, 0.045), rotation=(15, 0, 0))
            hang(thumb, rig, forearm)

    def standing_bands(self, side):
        """Bands at the knee and the boot's cuff, and the sole, near."""
        rig, p, g = self.rig, self.p, self.g
        s = 1 if side == "L" else -1
        thigh, shin, foot = "thigh" + side, "shin" + side, "foot" + side
        garter = loft("garter %s!fine" % side, [((s * 0.12, 0.002, 0.53), g(0.072), g(0.078), {}),
                                                ((s * 0.12, 0.002, 0.50), g(0.072), g(0.078), {})],
                      segments=12, mat=p.dark_leather, caps=(False, False))
        hang(garter, rig, thigh)
        cuff = loft("boot cuff %s!fine" % side, [((s * 0.12, 0.01, 0.345), g(0.078), g(0.086), {}),
                                                 ((s * 0.12, 0.01, 0.31), g(0.076), g(0.084), {})],
                    segments=12, mat=p.dark_leather, caps=(False, False))
        hang(cuff, rig, shin)
        sole = solid("sole %s!fine" % side, "box", mat=p.dark_leather, location=(s * 0.12, -0.045, 0.008), size=(0.112, 0.25, 0.018))
        hang(sole, rig, foot)

    def seated_leg(self, side, hip, knee, ankle):
        """A leg astride, along the bones the rider's rig bends it on: the
        thigh out and forward round a barrel, the shin down to the stirrup,
        the foot in it. The boot's foot is returned for the body."""
        rig, p, g = self.rig, self.p, self.g
        thigh, shin, foot = "thigh" + side, "shin" + side, "foot" + side
        H, K, A = Vector(hip), Vector(knee), Vector(ankle)
        paired(rig, "leg " + side, [
            (tuple(H + Vector((0, 0, 0.04))), g(0.104), g(0.11), {"hips": 0.55, thigh: 0.45}),
            (tuple(K), g(0.068), g(0.074), {thigh: 0.5, shin: 0.5}),
            (tuple(K + (A - K) * 0.45), g(0.062), g(0.07), {shin: 1.0}),
        ], far=self.far(6), near=self.near(12), between=self.between(2), mat=p.wool)
        paired(rig, "boot " + side, [
            (tuple(K + (A - K) * 0.4), g(0.07), g(0.078), {shin: 1.0}),
            (tuple(K + (A - K) * 0.92), g(0.058), g(0.064), {shin: 0.6, foot: 0.4}),
        ], far=self.far(6), near=self.near(12), between=1, mat=p.leather)
        return solid("foot " + side, "box", mat=p.leather, weights={foot: 1.0}, location=tuple(A + Vector((0, -0.06, -0.035))),
                     size=(0.1, 0.23, 0.1))

    def seated_bands(self, side, hip, knee, ankle):
        """A seated leg's bands and sole, near."""
        rig, p, g = self.rig, self.p, self.g
        thigh, shin, foot = "thigh" + side, "shin" + side, "foot" + side
        K, A = Vector(knee), Vector(ankle)
        hang(loft("garter %s!fine" % side, [(tuple(K + (A - K) * 0.04), g(0.072), g(0.078), {}),
                                            (tuple(K - (A - K) * 0.04), g(0.072), g(0.078), {})],
                  segments=12, mat=p.dark_leather, caps=(False, False)), rig, thigh)
        hang(loft("boot cuff %s!fine" % side, [(tuple(K + (A - K) * 0.37), g(0.078), g(0.086), {}),
                                               (tuple(K + (A - K) * 0.45), g(0.076), g(0.084), {})],
                  segments=12, mat=p.dark_leather, caps=(False, False)), rig, shin)
        hang(solid("sole %s!fine" % side, "box", mat=p.dark_leather, location=tuple(A + Vector((0, -0.06, -0.088))),
                   size=(0.106, 0.24, 0.018)), rig, foot)

    def head_and_belt(self, face, body_parts):
        """The neck, head and face, the belt, and the body joined and bound."""
        rig, p, g = self.rig, self.p, self.g
        paired(rig, "neck", [
            ((0, 0.012, 1.40), g(0.056), g(0.054), {"torso": 1.0}),
            ((0, 0.004, 1.50), g(0.05), g(0.05), {"head": 1.0}),
        ], far=self.far(6), near=self.near(10), between=1, mat=p.skin)
        body_parts.append(solid("head", "sphere", mat=p.skin, weights={"head": 1.0}, smooth=True, segments=self.far(8),
                                rings=3 if self.build.lean else 4,
                                radius=HEAD_R, location=HEAD))
        body_parts.append(loft("belt", [((0, 0.0, 0.995), g(0.176), g(0.122), {"hips": 1.0}),
                                        ((0, 0.0, 0.95), g(0.18), g(0.125), {"hips": 1.0})],
                               segments=8, mat=p.dark_leather, caps=(False, False)))
        bind(join("body", body_parts), rig)
        close_head = solid("head close!fine", "sphere", mat=p.skin, smooth=True, segments=12, rings=8,
                           radius=tuple(r + 0.003 for r in HEAD_R), location=HEAD)
        hang(close_head, rig, "head")

        features = [solid("nose", "cone", mat=p.skin, vertices=6, radius1=0.021, depth=0.05, location=at_head(0, -0.109, -0.01),
                          rotation=(90, 0, 0))]
        for s in (1, -1):
            features.append(solid("eye", "sphere", mat=p.eye, segments=4, rings=3, radius=(0.013, 0.006, 0.011),
                                  location=at_head(s * 0.036, -0.094, 0.02)))
            features.append(solid("brow", "box", mat=p.hair, location=at_head(s * 0.037, -0.096, 0.046), size=(0.044, 0.013, 0.013),
                                  rotation=(0, s * 8, 0)))
            features.append(solid("ear", "sphere", mat=p.skin, segments=4, rings=3, radius=(0.013, 0.024, 0.033),
                                  location=at_head(s * 0.093, 0.007, 0.0)))
        features.append(solid("beard", "sphere", mat=p.hair, smooth=True, segments=8, rings=5, radius=(0.08, 0.056, 0.058),
                              location=at_head(0, -0.07, -0.075)))
        features.append(solid("hair", "sphere", mat=p.hair, smooth=True, segments=8, rings=5, radius=(0.1, 0.095, 0.085),
                              location=at_head(0, 0.04, -0.025)))
        hang(join("face%s!fine" % face, features), rig, "head")
        belt_gear = [solid("buckle", "box", mat=p.steel, location=(0, g(-0.126), 0.973), size=(0.05, 0.015, 0.04)),
                     solid("pouch", "box", mat=p.dark_leather, location=(g(0.15), g(-0.085), 0.92), size=(0.07, 0.05, 0.08),
                           rotation=(0, 0, 30)),
                     solid("sheath", "box", mat=p.leather, location=(g(-0.16), g(-0.06), 0.88), size=(0.03, 0.035, 0.2),
                           rotation=(0, 15, -30)),
                     solid("pommel", "sphere", mat=p.steel, segments=6, rings=4, radius=(0.018, 0.018, 0.018),
                           location=(g(-0.17), g(-0.07), 1.0))]
        hang(join("belt gear!fine", belt_gear), rig, "hips")

    # MARK: What a tier or variant wears over it

    def coat(self, tags, mat, skirt_mat, sleeve_mat, long=False, hem=None, body=True, skirt=True):
        """The coat of a tier: body, skirt and sleeves, lean afar and round
        close; plate, for the tiers that wear it, is the coat's body. Its
        skirt to the knee, long to the shin, or to `hem`; its body left
        out (`body` False) where a tabard covers it whole."""
        rig, g, a = self.rig, self.g, self.ax
        if body:
            self.coat_body(tags, mat)
        hem = hem if hem is not None else 0.52 if long else 0.70
        if skirt:
            self.skirt(tags, skirt_mat, hem, long)
        for s, side in ((1, "L"), (-1, "R")):
            arm, forearm = "arm" + side, "forearm" + side
            paired(rig, "sleeve " + side, [
                ((a(s * 0.20), 0.0, 1.41), g(0.072), g(0.077), {"torso": 0.6, arm: 0.4}),
                ((a(s * 0.262), 0.0, 1.25), g(0.063), g(0.067), {"torso": 0.1, arm: 0.9}),
                ((a(s * 0.282), 0.0, 1.02), g(0.053), g(0.055), {arm: 0.5, forearm: 0.5}),
            ], far=self.far(6), near=self.near(12), between=self.between(2), mat=sleeve_mat, tags=tags)

    def coat_body(self, tags, mat):
        g = self.g
        paired(self.rig, "coat", [
            ((0, 0.0, 0.84), g(0.19), g(0.125), {"hips": 1.0}),
            ((0, 0.0, 0.98), g(0.165), g(0.112), {"hips": 0.5, "torso": 0.5}),
            ((0, -0.005, 1.12), g(0.178), g(0.118), {"torso": 1.0}),
            ((0, -0.015, 1.26), g(0.205), g(0.132), {"torso": 1.0}),
            ((0, 0.0, 1.36), g(0.215), g(0.12), {"torso": 1.0}),
            ((0, 0.005, 1.43), g(0.09), g(0.085), {"torso": 1.0}),
        ], far=self.far(8), near=self.near(16), between=1, mat=mat, tags=tags)

    def skirt(self, tags, mat, hem, long):
        g = self.g
        paired(self.rig, "skirt", [
            ((0, 0.0, 0.99), g(0.171), g(0.118), {"hips": 1.0}),
            ((0, 0.0, 0.86), g(0.20), g(0.135), skirt_weights(0.8)),
            ((0, 0.006, hem), g(0.218 + (0.02 if long else 0)), g(0.152 + (0.015 if long else 0)),
             skirt_weights(0.45 if not long else 0.35)),
        ], far=8, near=16, between=2, mat=mat, tags=tags)

    def mail_hem(self, tags, mat=None):
        """Mail's hem below the coat."""
        g = self.g
        paired(self.rig, "mail hem", [
            ((0, 0.0, 0.80), g(0.21), g(0.145), skirt_weights(0.7)),
            ((0, 0.008, 0.66), g(0.225), g(0.158), skirt_weights(0.4)),
        ], far=self.far(8), near=self.near(16), between=1, mat=mat or self.p.iron, tags=tags)

    def pauldron(self, side, tags, mat):
        """A shoulder's plate, lean afar and round close."""
        s = 1 if side == "L" else -1
        x = self.ax(s * 0.27)
        hang(dome("pauldron %s%s" % (side, tags), (0.09, 0.096, 0.072), (x, 0.0, 1.355), segments=self.far(6), rings=2, mat=mat), self.rig,
             "arm" + side)
        hang(dome("pauldron close %s%s!fine" % (side, tags), (0.094, 0.1, 0.076), (x, 0.0, 1.355), segments=self.near(12), rings=4, mat=mat),
             self.rig, "arm" + side)

    def greave(self, side, tags, mat):
        s = 1 if side == "L" else -1
        greave = loft("greave %s%s" % (side, tags), [((s * 0.12, 0.012, 0.46), self.g(0.07), self.g(0.078), {}),
                                                    ((s * 0.12, 0.014, 0.18), self.g(0.064), self.g(0.072), {})],
                      segments=8, mat=mat, caps=(False, False))
        hang(greave, self.rig, "shin" + side)

    def mantle(self, tags, mat):
        """A mantle about the shoulders."""
        g = self.g
        paired(self.rig, "mantle", [
            ((0, 0.0, 1.46), g(0.12), g(0.11), {"torso": 1.0}),
            ((0, 0.0, 1.38), g(0.25), g(0.16), {"torso": 0.7, "armL": 0.15, "armR": 0.15}),
            ((0, 0.0, 1.28), g(0.27), g(0.17), {"torso": 0.6, "armL": 0.2, "armR": 0.2}),
        ], far=self.far(8), near=self.near(16), between=1, mat=mat, tags=tags)

    # MARK: What they wear on the head

    def cap(self, name, tags, mat, margin, floor):
        """A cap or helm over the crown, lean afar, round close."""
        hang(dome(name + tags, helm_radii(margin), HEAD, segments=self.far(8), rings=2, mat=mat, floor=floor), self.rig, "head")
        hang(dome(name + " close" + tags + "!fine", helm_radii(margin + 0.004), HEAD, segments=14, rings=5, mat=mat, floor=floor),
             self.rig, "head")

    def hood(self, tags, mat):
        """A hood over the head, open before the face, its tail down the back."""
        for name, margin, segments, rings in (("hood" + tags, 0.02, self.far(8), 3), ("hood close" + tags + "!fine", 0.024, self.near(14), 5)):
            obj = dome(name, helm_radii(margin), (HEAD[0], HEAD[1] + 0.022, HEAD[2] + 0.004), segments=segments, rings=rings, mat=mat,
                       floor=-0.10)
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            # The face left open before a plane leaning back from the chin to
            # the brow: what lies wholly before it taken away, and every
            # corner before it pressed back onto it, so the opening's edge
            # rolls in a little. Each corner moves by where it is alone, so
            # the same hood is made every time (a bisect's cut, worked from
            # either end of an edge, is not).
            normal = Vector((0, -1, 0.42)).normalized()
            origin = Vector((0, HEAD[1] - 0.07, HEAD[2] + 0.01))
            before = {v for v in bm.verts if (v.co - origin).dot(normal) > 0}
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(v in before for v in f.verts)], context="FACES_ONLY")
            bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            for v in bm.verts:
                ahead = (v.co - origin).dot(normal)
                if ahead > 0:
                    v.co = v.co - normal * ahead
            settle(bm)
            bm.to_mesh(obj.data)
            bm.free()
            hang(obj, self.rig, "head")
        tail = solid("hood tail%s!fine" % tags, "cone", mat=mat, vertices=6, radius1=0.035, depth=0.2,
                     location=(0, HEAD[1] + 0.13, HEAD[2] - 0.12), rotation=(200, 0, 0))
        hang(tail, self.rig, "head")

    def nasal_helm(self, tags, mat):
        parts = [dome("helm", helm_radii(0.01), HEAD, segments=self.far(8), rings=2, mat=mat, floor=-0.025)]
        for s in (1, -1):
            parts.append(solid("cheek", "box", mat=mat, location=at_head(s * 0.092, -0.035, -0.045), size=(0.02, 0.075, 0.1)))
        hang(join("nasal helm" + tags, parts), self.rig, "head")
        hang(dome("nasal helm close%s!fine" % tags, helm_radii(0.014), HEAD, segments=14, rings=5, mat=mat, floor=-0.025), self.rig, "head")
        hang(solid("nasal%s!fine" % tags, "box", mat=self.p.steel, location=at_head(0, -0.115, 0.005), size=(0.02, 0.012, 0.075)),
             self.rig, "head")

    def crested(self, tags, mat, cheeks=True):
        parts = [dome("helm", helm_radii(0.012), HEAD, segments=self.far(8), rings=2, mat=mat, floor=-0.03),
                 solid("crest", "box", mat=self.p.tunic, location=at_head(0, 0.0, 0.135), size=(0.032, 0.24, 0.065))]
        for s in (1, -1) if cheeks else ():
            parts.append(solid("cheek", "box", mat=mat, location=at_head(s * 0.094, -0.035, -0.05), size=(0.02, 0.08, 0.11)))
        hang(join("crested helm" + tags, parts), self.rig, "head")
        hang(dome("crested helm close%s!fine" % tags, helm_radii(0.016), HEAD, segments=14, rings=5, mat=mat, floor=-0.03), self.rig, "head")

    def great_helm(self, tags, mat, plume=True):
        rig, p = self.rig, self.p
        rx, ry, rz = HEAD_R
        parts = [loft("great helm", [
            ((0, HEAD[1], HEAD[2] - 0.13), rx + 0.012, ry + 0.014, {}),
            ((0, HEAD[1] - 0.002, HEAD[2] + 0.01), rx + 0.018, ry + 0.02, {}),
            ((0, HEAD[1] + 0.002, HEAD[2] + 0.115), rx + 0.004, ry + 0.004, {}),
            ((0, HEAD[1] + 0.008, HEAD[2] + 0.152), 0.05, 0.055, {}),
        ], segments=self.far(8), mat=mat, caps=(False, True), smooth=False)]
        if plume:
            parts.append(solid("plume", "cone", mat=p.plume_cloth, vertices=6, radius1=0.035, depth=0.2, location=(0, 0.05, HEAD[2] + 0.25),
                               rotation=(-25, 0, 0)))
        helm = join("great helm" + tags, parts)
        if plume:
            sway(helm, lambda q: max(0.0, (q.z - HEAD[2] - 0.155) / 0.12))
        hang(helm, rig, "head")
        hang(solid("eye slit%s!fine" % tags, "box", mat=p.eye, location=(0, HEAD[1] - ry - 0.021, HEAD[2] + 0.025), size=(0.16, 0.01, 0.013)),
             rig, "head")
        hang(solid("breaths%s!fine" % tags, "box", mat=p.eye, location=(0.045, HEAD[1] - ry - 0.019, HEAD[2] - 0.04), size=(0.03, 0.01, 0.045)),
             rig, "head")

    # MARK: Shields: faced forward and a little out, on the left forearm

    def shield_place(self, obj):
        """Strapped on: centred on the left hand's grip, before the forearm,
        faced forward and a little out."""
        obj.rotation_euler = Euler((math.radians(90), 0, math.radians(28)), "XYZ")
        obj.location = Vector((0.335, -0.092, 0.78))
        apply_transforms(obj)
        hang(obj, self.rig, "heldL")
        return obj

    def round_shield(self, name, radius, mat, boss=False):
        p = self.p
        base, tags = split_tags(name)
        pieces = [solid(name, "cylinder", mat=mat, vertices=self.far(10), radius=radius, depth=0.03, location=(0, 0, 0))]
        if boss:
            pieces.append(solid("boss", "cone", mat=p.steel, vertices=6, radius1=0.055, depth=0.04, location=(0, 0, 0.035)))
        self.shield_place(join(name, pieces) if len(pieces) > 1 else pieces[0])
        rim = loft(base + " rim" + tags + "!fine",
                   [((0, 0, -0.019), radius + 0.006, radius + 0.006, {}), ((0, 0, 0.019), radius + 0.006, radius + 0.006, {})],
                   segments=20, mat=p.iron if boss else p.dark_leather, caps=(False, False))
        self.shield_place(rim)
        studs = [solid("stud", "cone", mat=p.steel, vertices=4, radius1=0.012, depth=0.012,
                       location=(math.cos(a) * radius * 0.82, math.sin(a) * radius * 0.82, 0.018))
                 for a in [i * math.pi / 3 for i in range(6)]]
        self.shield_place(join(base + " studs" + tags + "!fine", studs))

    def kite_shield(self, name, height, width, mat, face):
        p = self.p
        base, tags = split_tags(name)
        kite = solid(name, "cylinder", mat=mat, vertices=self.far(8), radius=1, depth=0.03, location=(0, 0, 0))
        shape_vertices(kite, lambda v, h=height, w=width: Vector((v.x * w, (v.y * h if v.y > 0 else v.y * h * 1.35) - 0.04, v.z)))
        boss = solid("kite boss", "cone", mat=p.steel, vertices=6, radius1=0.045, depth=0.035, location=(0, 0.02, 0.032))
        self.shield_place(join(name, [kite, boss]))
        self.shield_place(solid(base + " emblem" + tags + "!fine", "box", mat=face, location=(0, -0.02, 0.018),
                                size=(width * 0.25, height * 1.6, 0.006)))
        self.shield_place(solid(base + " bar" + tags + "!fine", "box", mat=face, location=(0, 0.06, 0.018),
                                size=(width * 1.5, 0.05, 0.006)))

    # MARK: Tools and cloaks

    def mattock(self):
        """The mattock a figure brings out to gather, on the tool bone."""
        p, x = self.p, self.ax(-0.30)
        tool = join("mattock", [
            solid("haft", "cylinder", mat=p.shaft, vertices=4, radius=0.015, depth=0.85, location=(x, -0.02, 0.70)),
            solid("blade", "box", mat=p.iron, location=(x, -0.07, 1.10), size=(0.035, 0.2, 0.05)),
        ])
        hang(tool, self.rig, "tool")

    def cloak(self, tags, length):
        """A cloak from the shoulders, swaying free toward its hem."""
        bottom = 1.40 - length
        lean, full = paired(self.rig, "cloak", [
            ((0, 0.11, 1.40), 0.2, 0.045, {"torso": 0.7, "cloak": 0.3}),
            ((0, 0.165, 1.12), 0.24, 0.05, {"cloak": 1.0}),
            ((0, 0.21, bottom), 0.27, 0.05, {"cloak": 1.0}),
        ], far=self.far(8), near=self.near(16), between=2, mat=self.p.cloak_cloth, tags=tags, inflate=0.003)
        for piece in (lean, full):
            sway(piece, lambda q, b=bottom: max(0.0, min(1.0, (1.38 - q.z) / (1.38 - b))))
        hang(solid("clasp%s!fine" % tags, "sphere", mat=self.p.steel, segments=8, rings=4, radius=(0.025, 0.012, 0.025),
                   location=(0.0, -0.1, 1.41)), self.rig, "torso")

    # MARK: The clips every kind on foot plays its own way

    def march(self, carry, arms, hidden, shown):
        """The march: the legs' cycle, the hips rising and falling over each
        step and turning with it, the torso and head against them; the arms
        as `arms(side)` swings them (side 1 the left foot's half, -1 the
        right's) over the kind's `carry`."""
        keys = {}
        for frame, t in ((0, 0.0), (7.5, 0.25), (15, 0.5), (22.5, 0.75), (30, 0.0)):
            lt, ls, lf = stride(t, True)
            rt, rs, rf = stride(t, False)
            down = t in (0.0, 0.5)
            side = 1 if t < 0.5 else -1
            keys[frame] = merge(carry, {
                "thighL": (lt, 0, 0), "shinL": (ls, 0, 0), "footL": (lf, 0, 0),
                "thighR": (rt, 0, 0), "shinR": (rs, 0, 0), "footR": (rf, 0, 0),
                "hips": {"turn": (0, 0, -5 * side if down else 0), "shift": (0.008 * side, 0, -0.016 if down else 0.01)},
                "torso": (4, 0, 4 * side if down else 0),
                "head": (-3, 0, -2 * side if down else 0),
                "cloak": (10 if down else 6, 0, 2 * side),
            }, arms(side))
        keyed(self.rig, "march", 30, keys, hidden=hidden, shown=shown)

    def death(self, carry, hidden, shown):
        """Struck down: staggered back, to the knees, and over onto the back."""
        lying = {"hips": {"turn": (-90, 0, 4), "shift": (0, 0.12, -0.76)}, "torso": (-4, 0, 0), "head": (-16, 0, 12),
                 "thighL": (-22, 0, 0), "shinL": (28, 0, 0), "thighR": (-14, 0, 0), "shinR": (18, 0, 0),
                 "armL": (-10, -72, 0), "forearmL": (-20, 0, 0), "heldL": (20, 0, 0),
                 "armR": (-6, 66, 0), "forearmR": (-12, 0, 0), "heldR": (12, 0, 0), "footL": (10, 0, 0), "footR": (6, 0, 0),
                 # Lying on its back, the cloak spread on the ground beneath.
                 "cloak": (6, 0, 0)}
        keys = {
            0: merge(carry, {}),
            6: merge(carry, {"torso": (-10, 0, 0), "head": (-15, 0, 0), "hips": {"turn": (0, 0, 0), "shift": (0, 0.015, 0)}}),
            11: merge(carry, {"torso": (-12, 0, 0), "head": (-18, 0, 6), "hips": {"turn": (-6, 0, 0), "shift": (0, 0.03, -0.03)},
                              "thighL": (-10, 0, 0), "shinL": (16, 0, 0), "thighR": (-6, 0, 0), "shinR": (12, 0, 0)}),
            22: {"hips": {"turn": (-45, 0, 2), "shift": (0, 0.07, -0.36)}, "torso": (-8, 0, 0), "head": (-14, 0, 8),
                 "thighL": (-34, 0, 0), "shinL": (54, 0, 0), "thighR": (-28, 0, 0), "shinR": (48, 0, 0),
                 "armL": (-14, -36, 0), "forearmL": (-40, 0, 0), "heldL": (40, 0, 0),
                 "armR": (-8, 34, 0), "forearmR": (-20, 0, 0), "heldR": (20, 0, 0), "cloak": (-12, 0, 0)},
            36: lying,
            38: lying,
            45: lying,
        }
        keyed(self.rig, "death", 45, keys, hidden=hidden, shown=shown)

    def gather(self, hidden, shown):
        """Two strokes of the mattock each period, both hands on its haft."""
        stance = {"thighL": (-14, 0, 0), "shinL": (17, 0, 0), "thighR": (9, 0, 0), "shinR": (11, 0, 0),
                  "hips": {"turn": (0, 0, 0), "shift": (0, 0, -0.03)}}

        def swing(lift, strike):
            return merge(stance, {"armR": (-35 - 125 * lift + 20 * strike, 0, 9), "armL": (-35 - 125 * lift + 20 * strike, 0, -20),
                                  "forearmR": (-17, 0, 0), "forearmL": (-26, 0, 0), "tool": (80 + 40 * lift, 0, 0),
                                  "torso": (11 - 14 * lift + 12 * strike, 0, 0), "head": (6 + 4 * strike, 0, 0),
                                  "cloak": (6 + 6 * strike, 0, 0)})

        keys = {}
        for half in (0, 30):
            keys[half + 0] = swing(0, 0)
            keys[half + 12] = swing(1, 0)
            keys[half + 16.5] = swing(0, 1)
            keys[half + 22.5] = swing(0, 1)
        keys[60] = swing(0, 0)
        keyed(self.rig, "gather", 60, keys, hidden=hidden, shown=shown)

    # MARK: Out

    def finish(self, path, looks):
        """Every mesh cleaned, each look's triangles far and near told, and
        the figure written out. `looks`: (tier, variant or None) pairs."""
        doubled = [obj.name for obj in bpy.context.scene.objects if obj.type == "MESH" and re.search(r"\.\d{3}$", obj.name)]
        if doubled:
            # Blender's suffix for a name taken: the tags would not read.
            raise ValueError("pieces named twice: %s" % ", ".join(sorted(doubled)))
        if len(self.rig.data.bones) > 23:
            # The game's root and these: the most parts any figure's rig may have.
            raise ValueError("%d bones: a figure's rig is 23 and the game's root" % len(self.rig.data.bones))
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH":
                clean(obj)
        for tier, variant in looks:
            coarse = fine = 0
            for obj in bpy.context.scene.objects:
                if obj.type != "MESH" or not drawn(obj.name, tier, variant):
                    continue
                if obj.name.endswith("!fine"):
                    fine += triangles(obj)
                else:
                    coarse += triangles(obj)
            print("%s: %d triangles far, %d near" % (variant or "TIER %d" % tier, coarse, coarse + fine))
            if os.environ.get("NULLMERE_PIECES") == (variant or str(tier)):
                for obj in sorted((o for o in bpy.context.scene.objects if o.type == "MESH" and drawn(o.name, tier, variant)),
                                  key=lambda o: -triangles(o)):
                    print("    %4d %s" % (triangles(obj), obj.name))
        export(path)


def split_tags(name):
    """A piece's name, and its tags: "round shield@1" as ("round shield", "@1")."""
    base, tags = name.split("@")
    return base, "@" + tags


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def drawn(name, tier, variant):
    """Whether a piece so named is drawn at this tier, or for this variant,
    as the game's importer reads its tags."""
    base = name.replace("!fine", "")
    if "@" not in base:
        return True
    tags = base.split("@")[-1].split(",")
    if variant:
        return variant in tags
    for tag in tags:
        if tag[0].isdigit():
            a, *b = tag.split("-")
            if int(a) <= tier <= int(b[0] if b else a):
                return True
    return False
