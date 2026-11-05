"""The archer: a bowman of a House in five tiers, from a levy in a wool coat
and a padded hood with a short self bow, to a marksman in plate under the
House's tabard, a crested helm and a cloak, drawing a recurved war bow
tipped in steel; and as the Reed Bows of the Fenfolk and the Strand Bows
of the Strandfolk. The body every person on foot shares (person.py),
spare and long-armed; a hip quiver on the right; the bow on the left arm,
drawn to the cheek with its arrow on the string and loosed.

    python Art/blender/archer.py Art/models/archer.glb

The bow's string is kept on a bone of its own, put away while the bow is
drawn; the drawn string and the arrow on it are weighted to the bow at one
end and to the drawing hand at the other, on the `extra` bone (hung at the
bow's grip) and the `nock` bone (in the right hand), shown only while the
bow is drawn, so the string comes back with the hand and the arrow lies
from the hand to the bow.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from person import *

reset()
BUILD = Build(girth=0.86, shoulders=0.94)
A = BUILD.shoulders
GRIP = (0.30 * A, -0.02, 0.72)
HAND_R = (-0.299 * A, -0.014, 0.705)
man = Person("Archer", "fenfolk,strandfolk", BUILD,
             moved={"extra": (GRIP, (GRIP[0], GRIP[1] - 0.1, GRIP[2]), "heldL")},
             more_bones=[("string", GRIP, (GRIP[0], GRIP[1], GRIP[2] + 0.1), "heldL"),
                         ("nock", HAND_R, (HAND_R[0], HAND_R[1], HAND_R[2] - 0.1), "forearmR")])
rig, p, every, g = man.rig, man.p, man.every, man.g

padded = material("plain_padded", (0.62, 0.55, 0.42))
gold = material("metal_gold", (0.80, 0.63, 0.30), roughness=0.3, metallic=1.0)
bronze = material("metal_bronze", (0.66, 0.46, 0.26), roughness=0.35, metallic=1.0)
moss = material("plain_moss", (0.30, 0.36, 0.20))
reed = material("plain_reed", (0.62, 0.58, 0.40))
sea_wool = material("plain_seawool", (0.42, 0.48, 0.50))
canvas = material("plain_canvas", (0.66, 0.62, 0.52))
bow_wood = material("plain_timber_bow", (0.60, 0.44, 0.25))
dark_wood = material("plain_timber_darkbow", (0.32, 0.21, 0.12))
cord = material("plain_cord", (0.82, 0.78, 0.68))
fletch = material("plain_fletch", (0.88, 0.86, 0.82))

man.body(hands=[("", p.skin)], face="")

# MARK: Coats, by tier and heritage


# Under the tabard (the fourth tier on, and the Strand Bows) the coat's body
# is never seen, and is left out.
man.coat("@1", p.wool, p.wool, p.wool, long=True, hem=0.5)
man.coat("@2", p.leather, p.leather, p.wool, hem=0.72)
man.coat("@3", p.iron, p.wool, p.wool, hem=0.72)
man.coat("@4", p.dark_leather, p.iron, p.iron, body=False)
man.coat("@5", p.steel, p.iron, p.iron, body=False)
man.coat("@fenfolk", moss, reed, reed, hem=0.76)
man.coat("@strandfolk", sea_wool, canvas, canvas, hem=0.62, body=False)
# The levy's belt in its House's colour, the only colour it wears of it.
bind(loft("sash@1", [((0, 0.0, 1.0), g(0.178), g(0.124), {"hips": 0.5, "torso": 0.5}), ((0, 0.0, 0.955), g(0.182), g(0.127), {"hips": 1.0})],
          segments=8, mat=p.tunic, caps=(False, False)), rig)


def tabard(tags, hem=0.75):
    """The House's tabard over mail: sleeveless, to the thigh (or to
    `hem`), its hem parted over the legs."""
    paired(rig, "tabard", [
        ((0, 0.005, 1.43), g(0.10), g(0.09), {"torso": 1.0}),
        ((0, 0.0, 1.36), g(0.224), g(0.13), {"torso": 1.0}),
        ((0, -0.015, 1.26), g(0.214), g(0.142), {"torso": 1.0}),
        ((0, -0.005, 1.12), g(0.188), g(0.127), {"torso": 1.0}),
        ((0, 0.0, 0.985), g(0.19), g(0.132), {"hips": 0.5, "torso": 0.5}),
        ((0, 0.0, 0.86), g(0.21), g(0.145), skirt_weights(0.8)),
        ((0, 0.006, hem), g(0.224 + (0.75 - hem) * 0.12), g(0.157 + (0.75 - hem) * 0.08), skirt_weights(0.5 if hem >= 0.7 else 0.38)),
    ], far=6, near=14, between=1, mat=p.tunic, tags=tags)


tabard("@4,strandfolk")
# The marksman's to the knee.
tabard("@5", hem=0.6)
man.mail_hem("@4-5")
for side in ("L", "R"):
    man.pauldron(side, "@4", p.steel)
    man.pauldron(side, "@5", gold)
    man.pauldron(side, "@strandfolk", bronze)
    man.greave(side, "@fenfolk", p.leather)
    man.greave(side, "@5", p.steel)
    # Steel over the bracer of the fifth tier's arms.
    s = 1 if side == "L" else -1
    vambrace = loft("vambrace %s@5" % side, [((s * 0.288 * A, -0.004, 0.99), g(0.062), g(0.064), {}),
                                           ((s * 0.297 * A, -0.01, 0.79), g(0.05), g(0.052), {})],
                    segments=6, mat=p.steel, caps=(False, False))
    hang(vambrace, rig, "forearm" + side)
man.mantle("@1", padded)
man.mantle("@2", p.tunic)
man.mantle("@3", p.tunic)
man.mantle("@fenfolk", reed)

# MARK: Hoods and hats


man.hood("@1", padded)
man.hood("@2", p.tunic)
man.hood("@fenfolk", p.tunic)


man.cap("iron cap", "@3", p.iron, 0.008, -0.01)
man.kettle("@4", p.steel)
man.kettle("@strandfolk", p.iron)
man.crested("@5", p.steel, cheeks=False)

# MARK: The bow, longer and better with the tier; the quiver; the mattock


def bow(tags, half, bend, wood, recurve=False, tips=None):
    """The bow in the left hand, standing through the grip, its limbs
    curving back toward the string; its string between the tips."""
    def at(t):
        y = bend * t * t
        if recurve and abs(t) > 0.8:
            # The tips turned forward again.
            y -= 0.35 * bend * ((abs(t) - 0.8) / 0.2) ** 2
        return (GRIP[0], GRIP[1] + y, GRIP[2] + half * t)

    def stave(name, count, segments, thick):
        sections = []
        for k in range(count + 1):
            t = -1 + 2 * k / count
            r = thick * (1 - 0.5 * abs(t))
            sections.append((at(t), r * 1.25, r, {}))
        return loft(name, sections, segments=segments, mat=wood, caps=(True, True))

    hang(stave("bow" + tags, 6, 4, 0.016), rig, "heldL")
    hang(stave("bow close" + tags + "!fine", 16, 8, 0.0175), rig, "heldL")
    grip = loft("bow grip%s!fine" % tags, [((GRIP[0], GRIP[1], GRIP[2] - 0.05), 0.024, 0.02, {}),
                                           ((GRIP[0], GRIP[1], GRIP[2] + 0.05), 0.024, 0.02, {})],
                segments=8, mat=p.dark_leather, caps=(False, False))
    hang(grip, rig, "heldL")
    if tips:
        nocks = [solid("nock", "cone", mat=tips, vertices=4, radius1=0.012, depth=0.05, location=at(s * 0.98),
                       rotation=(0 if s > 0 else 180, 0, 0)) for s in (1, -1)]
        hang(join("bow tips%s!fine" % tags, nocks), rig, "heldL")
    top, bottom = at(1), at(-1)
    # The string at rest, on its own bone.
    string = loft("string%s!fine" % tags, [(bottom, 0.004, 0.004, {}), (top, 0.004, 0.004, {})], segments=4, mat=cord, caps=(False, False))
    hang(string, rig, "string")
    # Drawn: from each tip to the hand; the bow's end with it, the hand's
    # with the hand.
    nock = (HAND_R[0], HAND_R[1] - 0.02, HAND_R[2])
    halves = [loft("drawn string", [(end, 0.004, 0.004, {"extra": 1.0}), (nock, 0.004, 0.004, {"nock": 1.0})],
                   segments=4, mat=cord, caps=(False, False)) for end in (top, bottom)]
    bind(join("drawn string%s!fine" % tags, halves), rig)
    return top, bottom


bow("@1", 0.70, 0.15, bow_wood)
bow("@2", 0.70, 0.15, bow_wood)
bow("@3", 0.76, 0.16, bow_wood)
bow("@4", 0.80, 0.16, dark_wood, tips=p.steel)
bow("@5,fenfolk,strandfolk", 0.78, 0.19, dark_wood, recurve=True, tips=p.steel)

# The arrow on the string while the bow is drawn: from the hand to the
# grip, its head standing past the bow.
NOCK = (HAND_R[0], HAND_R[1] - 0.02, HAND_R[2])
shaft = loft("arrow", [(NOCK, 0.0065, 0.0065, {"nock": 1.0}), (GRIP, 0.0065, 0.0065, {"extra": 1.0})], segments=3, mat=bow_wood,
             caps=(False, False))
bind(shaft, rig)
head = solid("arrowhead", "cone", mat=p.steel, vertices=4, radius1=0.016, depth=0.07, location=(GRIP[0], GRIP[1] - 0.045, GRIP[2]),
             rotation=(90, 0, 0))
hang(head, rig, "extra")


def quiver(tags, mat, band=None, back=False):
    """A quiver at the right hip, or slung across the back with its mouth
    over the right shoulder, its arrows' fletchings standing out of it."""
    if back:
        bone, mouth, foot = "torso", Vector((-0.13 * A, 0.19, 1.56)), Vector((0.12 * A, 0.2, 0.84))
    else:
        x = -0.235 * A
        bone, mouth, foot = "hips", Vector((x, -0.035, 1.03)), Vector((x - 0.01, 0.075, 0.63))
    body = loft("quiver" + tags, [(tuple(foot), 0.04, 0.04, {}), (tuple(mouth), 0.046, 0.046, {})], segments=6, mat=mat, caps=(True, False))
    hang(body, rig, bone)
    hang(loft("quiver close%s!fine" % tags, [(tuple(foot), 0.043, 0.043, {}), (tuple(mouth), 0.049, 0.049, {})], segments=12, mat=mat,
              caps=(True, False)), rig, bone)
    up = (mouth - foot).normalized()
    feathers = []
    for k, (dx, dy) in enumerate(((0.012, 0.0), (-0.014, 0.012), (0.0, -0.016), (-0.006, 0.0))):
        base = mouth + Vector((dx, dy, 0)) + up * 0.01
        feathers.append(solid("fletching", "box", mat=fletch, location=tuple(base + up * 0.05), size=(0.006, 0.02, 0.09)))
    hang(join("fletchings%s!fine" % tags, feathers), rig, bone)
    if band:
        hang(loft("quiver band%s!fine" % tags, [(tuple(mouth - up * 0.03), 0.05, 0.05, {}), (tuple(mouth - up * 0.01), 0.05, 0.05, {})],
                  segments=12, mat=band, caps=(False, False)), rig, bone)
    if back:
        # Its strap across the chest, from the right shoulder to the left hip.
        strap = solid("quiver strap%s!fine" % tags, "box", mat=p.dark_leather, location=(0.0, g(-0.135), 1.17), size=(0.04, 0.012, 0.56),
                      rotation=(0, 36, 0))
        hang(strap, rig, "torso")
    else:
        # Its strap to the belt.
        hang(solid("quiver strap%s!fine" % tags, "box", mat=p.dark_leather, location=(-0.235 * A + 0.02, -0.02, 0.99),
                   size=(0.03, 0.012, 0.07)), rig, "hips")


# Slung across the back where no cloak hangs; at the hip under one.
quiver("@1-2", p.leather, back=True)
quiver("@3", p.dark_leather, back=True)
quiver("@4", p.dark_leather)
quiver("@5", p.dark_leather, band=gold)
quiver("@fenfolk", reed)
quiver("@strandfolk", p.leather, band=bronze, back=True)
man.mattock()

# MARK: Cloaks

man.cloak("@4", 0.74)
man.cloak("@5", 1.0)
man.cloak("@fenfolk", 1.0)

# MARK: The clips

STILL = {"string": {"scale": 1.0}, "extra": {"scale": 0.001}, "nock": {"scale": 0.001}}
DRAWING = {"string": {"scale": 0.001}, "extra": {"scale": 1.0}, "nock": {"scale": 1.0}}
AT_REST = dict(hidden=["tool", "extra", "nock"], shown=["heldL", "string"])
# The bow held low at the left side, standing upright; the right arm easy.
CARRY = {"armL": (-12, 0, -4), "forearmL": (-28, 0, 0), "heldL": (40, 0, 0),
         "armR": (-4, 0, 6), "forearmR": (-14, 0, 0)}

IDLE_KEYS = {
    0: merge(CARRY, {}),
    14: merge(CARRY, {"hips": {"turn": (0, 2.5, 0), "shift": (-0.012, 0, 0)}, "thighL": (0, -2.5, 0), "thighR": (0, -2.5, 0),
                      "torso": (0, -1.5, 0), "head": (2, 0, 20)}),
    26: merge(CARRY, {"torso": {"turn": (-2, 3, 6), "shift": (0, 0, 0.006)}, "armL": (-16, 0, -2), "armR": (-8, 0, 10), "head": (0, 0, 14)}),
    38: merge(CARRY, {"armR": (-38, 0, 28), "forearmR": (-64, 0, 0), "armL": (-20, 0, -2), "forearmL": (-40, 0, 0), "heldL": (58, 0, 0),
                      "head": (8, 0, 18), "torso": (3, 0, 8)}),
    46: merge(CARRY, {"armR": (-36, 0, 30), "forearmR": (-58, 0, 0), "armL": (-20, 0, -2), "forearmL": (-40, 0, 0), "heldL": (58, 0, 0),
                      "head": (10, 0, 20), "torso": (3, 0, 8)}),
    58: merge(CARRY, {"head": (-4, 0, -6)}),
    74: merge(CARRY, {"hips": {"turn": (0, -2.5, 0), "shift": (0.012, 0, 0)}, "thighL": (0, 2.5, 0), "thighR": (0, 2.5, 0),
                      "torso": (0, 1.5, 0), "head": (-7, 0, -22)}),
    90: merge(CARRY, {"head": (-8, 0, -24), "torso": {"turn": (-1, 0, -4), "shift": (0, 0, 0.004)}}),
    104: merge(CARRY, {"torso": {"turn": (-1.5, -2, -3), "shift": (0, 0, 0.006)}, "armL": (-14, 0, -6), "head": (0, 0, -6)}),
    120: merge(CARRY, {}),
}
keyed(rig, "idle", 120, {f: merge(pose, STILL) for f, pose in IDLE_KEYS.items()}, hidden=["tool"], shown=["heldL"])

# The march: the light quick step of every kind on foot, the bow carried
# steady and the free arm swinging.
man.march(merge(CARRY, STILL), lambda side: {"armL": (-12 + 3 * side, 0, -4), "armR": (-4 - 16 * side, 0, 6),
                                             "forearmR": (-14 - 10 * (1 if side > 0 else 0), 0, 0)}, hidden=["tool"], shown=["heldL"])

# MARK: The draw, worked out where the hands must be


def bone_head(name):
    return rig.data.bones[name].head_local.copy()


def yaw(degrees):
    return Matrix.Rotation(math.radians(degrees), 3, "Z")


def least(a, b):
    """The least turn taking direction a to direction b."""
    return a.normalized().rotation_difference(b.normalized()).to_matrix()


def frame(right, back, up):
    """The turn taking the armature's axes to these, as columns."""
    return Matrix((right, back, up)).transposed()


ELEVATION = math.radians(14)
AIM = Vector((0, -math.cos(ELEVATION), math.sin(ELEVATION)))
# The corner of the mouth, where the string is drawn to: the head turned
# back to look along the arrow over the left shoulder.
ANCHOR = Vector((-0.035, -0.118, 1.49))
DRAW = 0.70
GRIP_DRAWN = ANCHOR + AIM * DRAW
SHOULDER_L, SHOULDER_R = bone_head("armL"), bone_head("armR")
REACH = (Vector(GRIP) - SHOULDER_L).length


def shoulder_at(turn):
    return yaw(turn) @ SHOULDER_L


# How far the body turns, left shoulder to the foe, for the bow arm to
# reach the grip straight.
low, high = -95.0, 0.0
for _ in range(60):
    mid = (low + high) / 2
    if (GRIP_DRAWN - shoulder_at(mid)).length > REACH:
        high = mid
    else:
        low = mid
TURN = (low + high) / 2
HIPS_TURN = TURN * 0.45
BODY = yaw(TURN)
ARM_L = least(Vector(GRIP) - SHOULDER_L, GRIP_DRAWN - shoulder_at(TURN))
# The bow upright across the arrow, a little canted, its string toward the archer.
UP = Vector((0, math.sin(ELEVATION), math.cos(ELEVATION)))
BOW = Matrix.Rotation(math.radians(-8), 3, AIM) @ frame(AIM.cross(UP) * -1, -AIM, UP)


def right_arm(hand):
    """The turns of the right arm and forearm that put the right hand at
    `hand`, the elbow out behind, along the arrow."""
    shoulder = yaw(TURN) @ SHOULDER_R
    elbow0, wrist0 = bone_head("forearmR"), Vector(HAND_R)
    upper, lower = (elbow0 - SHOULDER_R).length, (wrist0 - elbow0).length
    to = hand - shoulder
    span = min(to.length, (upper + lower) * 0.995)
    along = to.normalized()
    cos_a = (upper ** 2 + span ** 2 - lower ** 2) / (2 * upper * span)
    angle = math.acos(max(-1.0, min(1.0, cos_a)))
    out = yaw(TURN) @ Vector((-1, 0, 0))
    want = (-AIM * 1.0 + out * 0.35 + Vector((0, 0, 0.25)))
    side = (want - along * want.dot(along)).normalized()
    elbow = shoulder + (along * math.cos(angle) + side * math.sin(angle)) * upper
    arm = least(elbow0 - SHOULDER_R, elbow - shoulder)
    fore = least(wrist0 - elbow0, shoulder + along * span - elbow)
    return {"armR": {"rotation": BODY.inverted() @ arm}, "forearmR": {"rotation": arm.inverted() @ fore}}


def drawn_pose(hand, head_down=8.0):
    """The body turned to the foe, the bow arm straight at it, the right
    hand at `hand`."""
    pose = {"hips": {"turn": (0, 0, HIPS_TURN), "shift": (0, 0, -0.025)},
            "torso": {"rotation": yaw(TURN - HIPS_TURN)},
            "head": (head_down, -5, -(TURN * 0.92)),
            "armL": {"rotation": BODY.inverted() @ ARM_L},
            "forearmL": (0, 0, 0),
            "heldL": {"rotation": ARM_L.inverted() @ BOW},
            "thighL": (-10, 0, 6), "shinL": (10, 0, 0), "thighR": (6, 0, -4), "shinR": (6, 0, 0), "cloak": (8, 0, 0)}
    pose.update(right_arm(hand))
    return pose


SET = drawn_pose(GRIP_DRAWN - AIM * 0.21)
FULL = drawn_pose(ANCHOR - AIM * 0.02)
LOOSED = drawn_pose(ANCHOR - AIM * 0.11 + yaw(TURN) @ Vector((-0.03, 0.0, 0.02)), head_down=6)
READY = merge(CARRY, {"hips": {"turn": (0, 0, 0), "shift": (0, 0, -0.012)}, "thighL": (-6, 0, 0), "shinL": (6, 0, 0)})
attack = {0: merge(READY, STILL), 6: merge(READY, {"armL": (-34, 0, -2), "forearmL": (-30, 0, 0), "heldL": (64, 0, 0)}, STILL),
          11.9: merge(SET, STILL), 12: merge(SET, DRAWING), 22: merge(FULL, DRAWING), 27.9: merge(FULL, DRAWING),
          28: merge(LOOSED, STILL), 34: merge(LOOSED, STILL), 45: merge(READY, STILL)}
keyed(rig, "attack", 45, attack, hidden=["tool"], shown=["heldL"])


def struck(share):
    """The carry, a share of the way to the worst of a blow: rocked back,
    the free arm thrown up, the bow arm flung out."""
    return merge(CARRY, {"torso": (-16 * share, 0, 6 * share), "head": (-14 * share, 0, -10 * share),
                         "hips": {"turn": (0, 0, 2 * share), "shift": (0, 0.03 * share, -0.02 * share)},
                         "thighR": (14 * share, 0, 0), "shinR": (12 * share, 0, 0), "thighL": (-12 * share, 0, 0), "shinL": (20 * share, 0, 0),
                         "armR": (-4 - 52 * share, 0, 6 + 24 * share), "forearmR": (-14 - 46 * share, 0, 0),
                         "armL": (-12 + 14 * share, 0, -4 - 16 * share), "cloak": (-10 * share, 0, 0)})


hit = {0: struck(0), 3: struck(0.15), 6: struck(1.0), 14: struck(0.7), 25: struck(0.25), 32: struck(0.05), 36: struck(0), 45: struck(0)}
keyed(rig, "hit", 45, hit, **AT_REST)
man.death(CARRY, **AT_REST)
# The bow put by: its string and its arrow's bone go with it.
man.gather(hidden=["heldL", "nock"], shown=["tool"])

man.finish(out_path("Art/models/archer.glb"),
           [(1, None), (2, None), (3, None), (4, None), (5, None), (5, "fenfolk"), (5, "strandfolk")])
