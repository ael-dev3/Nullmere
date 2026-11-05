"""The townsfolk who go about a hold's work and its lanes, plain folk in
linen and wool with a band of their House's colour at the waist, each a
variant of one file on the body every person on foot shares (person.py):
- the farmhand, in a linen smock and a straw-coloured cap, a pitchfork
  upright in the right hand;
- the salter, in sea-grey wool under a linen hood, a lidded basket of salt
  hanging from the left hand;
- the porter, in wool under a leather cap, a sack on the back and a staff;
- the householder, in a tunic dyed with madder, a hood thrown back on the
  shoulders, empty-handed;
- the water-carrier, a kerchief and an apron over the wool, a pail filled
  at the well hanging by its bail from the left hand;
- the elder, in a long robe of dark wool and a hood over grey hair,
  stooped over a crooked stick;
- the child, in a smock dyed with weld, bare-headed and quick.
(The carters who haul with handcarts are carters.py's.)

    python Art/blender/folk.py Art/models/folk.glb

Drawn a little smaller than a soldier (the elder smaller still, the child
smallest), each walk keyed with its stride set so its feet hold the ground
at its unhurried pace (Folk.gait's in the game). The rig's `extra` bone is
at the left hand, for what hangs from it.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from person import *

reset()
NAMES = "farmhand,salter,porter,householder,waterCarrier,elder,child"
BUILD = Build(girth=0.95, lean=True)
HOOK = (0.30, -0.02, 0.66)
man = Person("Folk", NAMES, BUILD, moved={"extra": (HOOK, (HOOK[0], HOOK[1], HOOK[2] - 0.1), "heldL")})
rig, p, g, a = man.rig, man.p, man.g, man.ax

thatch = material("plain_thatch_cap", (0.78, 0.66, 0.38))
sea_wool = material("plain_seawool", (0.42, 0.48, 0.50))
dark_wool = material("plain_darkwool", (0.18, 0.17, 0.16))
madder = material("plain_madder", (0.62, 0.26, 0.20))
weld = material("plain_weld", (0.80, 0.70, 0.30))
canvas = material("plain_canvas", (0.74, 0.70, 0.60))
reed = material("plain_reed", (0.66, 0.58, 0.36))
pale = material("plain_timber_pale", (0.66, 0.54, 0.38))
moonsalt = material("crystal_moonsalt", (0.80, 0.90, 0.98), roughness=0.1)
grey_hair = material("plain_greyhair", (0.62, 0.62, 0.60))

# MARK: Their bodies, faces and dress

man.body(hands=[("", p.skin)], face=None, belt=False)
man.face("@farmhand,porter")
man.face("@salter,householder,waterCarrier,child", beard=False)
hair = p.hair
p.hair = grey_hair
man.face("@elder")
p.hair = hair
man.coat("@farmhand", p.linen, p.linen, p.linen, hem=0.61)
man.coat("@salter", sea_wool, sea_wool, sea_wool, hem=0.43)
man.coat("@porter", p.wool, p.wool, dark_wool, hem=0.54)
man.coat("@householder", madder, madder, p.linen, hem=0.40)
man.coat("@waterCarrier", sea_wool, p.wool, p.wool, hem=0.36)
man.coat("@elder", dark_wool, dark_wool, dark_wool, long=True, hem=0.18)
man.coat("@child", weld, weld, weld, hem=0.54)
# The band of the House's colour every one of them wears at the waist.
bind(loft("band", [((0, 0.0, 1.0), g(0.178), g(0.124), {"hips": 0.5, "torso": 0.5}),
                                    ((0, 0.0, 0.955), g(0.182), g(0.127), {"hips": 1.0})],
          segments=man.far(8), mat=p.tunic, caps=(False, False)), rig)
man.crown("hair", "@householder", p.hair, 0.005, 0.085, -0.10)
# The child's mop of hair, the head looking the larger for it.
man.crown("hair", "@child", p.hair, 0.016, 0.075, -0.10)
man.crown("cap", "@farmhand", thatch, 0.008, 0.07, -0.03)
man.crown("leather cap", "@porter", p.leather, 0.008, 0.07, -0.03)
man.crown("kerchief", "@waterCarrier", p.linen, 0.006, 0.075, -0.07)
man.hood("@salter", p.linen)
man.hood("@elder", p.wool)
# The householder's hood thrown back on the shoulders.
hang(solid("hood back@householder", "sphere", mat=weld, segments=5, rings=3, radius=(0.15, 0.09, 0.08), location=(0, 0.13, 1.42)), rig, "torso")
# The water-carrier's apron.
bind(loft("apron@waterCarrier", [((0, -0.03, 0.99), g(0.15), g(0.12), {"hips": 1.0}), ((0, -0.04, 0.60), g(0.18), g(0.13),
                                                                                       {"hips": 0.4, "thighL": 0.3, "thighR": 0.3})],
          segments=man.far(8), mat=p.linen, caps=(False, False)), rig)

# MARK: What they carry

x, y = a(-0.30), -0.02
# The farmhand's pitchfork: a long pale shaft, an iron head of three tines.
fork = [loft("shaft", [((x, y, 0.07), 0.017, 0.017, {}), ((x, y, 1.70), 0.016, 0.016, {})], segments=4, mat=pale, caps=(True, True)),
        solid("crosshead", "box", mat=p.iron, location=(x, y, 1.70), size=(0.18, 0.025, 0.025))]
for dx in (-0.08, 0.0, 0.08):
    fork.append(loft("tine", [((x + dx, y, 1.70), 0.008, 0.008, {}), ((x + dx, y, 1.96), 0.003, 0.003, {})], segments=3, mat=p.iron,
                     caps=(False, True)))
hang(join("pitchfork@farmhand", fork), rig, "heldR")
# The porter's staff, and the sack on the back on its strap.
hang(loft("staff@porter", [((x, y, 0.05), 0.016, 0.016, {}), ((x, y, 1.89), 0.015, 0.015, {})], segments=4, mat=p.shaft, caps=(True, True)),
     rig, "heldR")
hang(solid("sack@porter", "sphere", mat=canvas, segments=6, rings=4, radius=(0.20, 0.13, 0.25), location=(0, 0.22, 1.20)), rig, "torso")
hang(loft("strap@porter", [((g(0.15), -0.10, 1.40), 0.02, 0.02, {}), ((g(-0.14), -0.12, 1.02), 0.02, 0.02, {})], segments=4, mat=p.leather,
          caps=(False, False)), rig, "torso")
# The elder's crooked stick.
hang(join("stick@elder", [loft("stick", [((x, y - 0.06, 0.04), 0.022, 0.022, {}), ((x, y, 0.78), 0.02, 0.02, {})], segments=4, mat=p.shaft,
                                caps=(True, False)),
                           loft("crook", [((x, y, 0.78), 0.02, 0.02, {}), ((x, y - 0.07, 0.86), 0.018, 0.018, {})], segments=4, mat=p.shaft,
                                caps=(False, True))]), rig, "heldR")
# The salter's basket and the water-carrier's pail, hung from the hand.
hx, hy, hz = HOOK
basket = [loft("handle", [((hx, hy, hz), 0.01, 0.01, {}), ((hx, hy, hz - 0.11), 0.01, 0.01, {})], segments=3, mat=reed, caps=(False, False)),
          loft("basket", [((hx, hy, hz - 0.38), 0.11, 0.11, {}), ((hx, hy, hz - 0.30), 0.16, 0.16, {}), ((hx, hy, hz - 0.13), 0.17, 0.17, {})],
               segments=6, mat=reed, caps=(True, False)),
          solid("salt", "sphere", mat=moonsalt, segments=5, rings=3, radius=(0.14, 0.14, 0.08), location=(hx, hy, hz - 0.13))]
hang(join("basket@salter", basket), rig, "extra")
pail = [loft("bail", [((hx, hy, hz), 0.008, 0.008, {}), ((hx, hy, hz - 0.12), 0.008, 0.008, {})], segments=3, mat=p.iron, caps=(False, False)),
        loft("pail", [((hx, hy, hz - 0.38), 0.10, 0.10, {}), ((hx, hy, hz - 0.13), 0.13, 0.13, {})], segments=7, mat=pale, caps=(True, False))]
hang(join("pail@waterCarrier", pail), rig, "extra")
hang(join("pail hoops@waterCarrier!fine", [loft("hoop", [((hx, hy, hz + dz - 0.014), r, r, {}), ((hx, hy, hz + dz + 0.014), r, r, {})],
                                                 segments=12, mat=p.iron, caps=(False, False))
                                            for dz, r in ((-0.33, 0.112), (-0.18, 0.128))]), rig, "extra")

# MARK: The clips, each group of folk its own

ADULT, ELDER, CHILD = gait_pace(0.27, 0.32), gait_pace(0.26, 0.24), gait_pace(0.19, 0.45)
STAFF = {"armR": (-8, 0, 4), "forearmR": (-30, 0, 0), "heldR": (38, 0, 0), "armL": (-4, 0, -4), "forearmL": (-10, 0, 0)}
HANGING = {"armL": (-2, 0, -6), "forearmL": (-6, 0, 0), "extra": (8, 0, 0), "armR": (-4, 0, 4), "forearmR": (-12, 0, 0)}
FREE = {"armL": (-2, 0, -4), "forearmL": (-8, 0, 0), "armR": (-2, 0, 4), "forearmR": (-8, 0, 0)}
STOOPED = merge(STAFF, {"torso": (16, 0, 0), "head": (-12, 0, 0), "armR": (-30, 0, 4), "forearmR": (-20, 0, 0), "heldR": (40, 0, 0)})


def smooth(t):
    return t * t * (3 - 2 * t)


def between(keys, f):
    """The share at frame `f` along keys [(frame, share)], eased."""
    for (f0, a0), (f1, a1) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            return a0 + (a1 - a0) * smooth((f - f0) / (f1 - f0))
    return keys[-1][1]


def tagged(clip, names):
    """The action just keyed for `clip`, renamed as these folk's own."""
    bpy.data.actions[clip].name = clip + "@" + names
    rig.animation_data.nla_tracks[clip].name = clip + "@" + names


CROUCH = {"hips": {"turn": (0, 0, 0), "shift": (0, 0.03, -0.32)}, "thighL": (-80, 0, -6), "shinL": (112, 0, 0), "footL": (-30, 0, 0),
          "thighR": (-58, 0, 6), "shinR": (104, 0, 0), "footR": (-44, 0, 0), "torso": (28, 0, 0), "head": (-14, 0, 0)}


def pitching(f):
    """The farmhand's fork driven tines-down into the heap before them,
    levered up laden, and swung up to pitch it, twice a period: the fork's
    lean from upright the sum of the arm's, the forearm's and the hand's."""
    s = between([(0, 0.0), (9, 1.0), (14, 1.0), (22, 0.0), (30, 0.0)], f % 30)
    toss = between([(0, 0.0), (14, 0.0), (19, 1.0), (25, 0.4), (30, 0.0)], f % 30)
    arm, forearm = -64 + 22 * s - 46 * toss, -40 + 10 * s + 10 * toss
    lean = 112 + 18 * s - 66 * toss
    return merge(STAFF, {"torso": (16 + 20 * s - 8 * toss, 0, -10 * toss), "head": (-6 + 8 * s - 6 * toss, 0, -8 * toss),
                         "armR": (arm, 0, 8), "forearmR": (forearm, 0, 0), "heldR": (lean - arm - forearm, 0, 0),
                         "armL": (arm + 10, 0, -22), "forearmL": (forearm - 30, 0, 0),
                         "thighL": (-18, 0, 0), "shinL": (22, 0, 0), "thighR": (8, 0, 0), "shinR": (12, 0, 0),
                         "hips": {"turn": (0, 0, -6 - 8 * toss), "shift": (0, 0, -0.03 - 0.04 * s)}})


def heaving(f):
    """The porter bowed under the sack and heaving it higher on the back,
    twice a period, the free hand at its strap."""
    s = between([(0, 0.0), (10, 1.0), (16, 1.0), (30, 0.0)], f % 30)
    return merge(STAFF, {"torso": (16 + 22 * s, 0, 0), "head": (-12 - 14 * s, 0, 0), "thighL": (-12 - 14 * s, 0, 0), "shinL": (16 + 24 * s, 0, 0),
                         "thighR": (-6 - 14 * s, 0, 0), "shinR": (10 + 22 * s, 0, 0),
                         "hips": {"turn": (0, 0, 0), "shift": (0, 0.01 * s, -0.02 - 0.06 * s)},
                         "armL": (-20 - 30 * s, 0, -24), "forearmL": (-100 + 10 * s, 0, 0), "armR": (-14 - 10 * s, 0, 4)})


def scooping(f):
    """Crouched over what they fill, set down beside them: a hand dipped and
    scooped up into it, twice a period."""
    s = between([(0, 0.0), (12, 1.0), (18, 1.0), (30, 0.0)], f % 30)
    return merge(CROUCH, {"armL": (-26, 0, -12), "forearmL": (-14, 0, 0), "extra": (30, 0, 0),
                          "armR": (-50 - 30 * s, 0, 10 - 14 * s), "forearmR": (-30 - 30 * (1 - s), 0, 0), "head": (-10 - 6 * s, 0, 0)})


def talking(f):
    """The householder's errand met with a neighbour: talking with the hands,
    the head nodding, the weight shifting."""
    u = f / 60
    w = math.sin(2 * math.pi * u)
    return merge(FREE, {"armR": (-38 - 16 * math.sin(4 * math.pi * u), 0, 10), "forearmR": (-70 + 20 * math.sin(4 * math.pi * u + 1), 0, 0),
                        "armL": (8, 0, -20), "forearmL": (-110, 0, 0), "head": (6 * math.sin(4 * math.pi * u) - 2, 0, 12 * w),
                        "torso": (2, 0, 4 * w), "hips": {"turn": (0, 0, -3 * w), "shift": (0.012 * w, 0, 0)}})


def resting(f):
    """The elder's rest on the stick, a hand at the small of the back, the
    head nodding slowly as they look about."""
    u = f / 60
    return merge(STOOPED, {"armL": (24, 0, -16), "forearmL": (-96, 0, 0), "head": (-10 + 5 * math.sin(4 * math.pi * u), 0, 20 * math.sin(2 * math.pi * u)),
                           "torso": (18 + 2 * math.sin(2 * math.pi * u), 0, 0)})


def playing(f):
    """The child crouched at play in the dirt, patting at it, the head
    turning after something."""
    u = f / 60
    return merge(CROUCH, {"torso": (34, 0, 0), "head": (-16, 0, 26 * math.sin(2 * math.pi * u)),
                          "armR": (-58 - 22 * abs(math.sin(4 * math.pi * u)), 0, 8), "forearmR": (-24, 0, 0),
                          "armL": (-44 - 18 * abs(math.sin(4 * math.pi * u + 1.3)), 0, -10), "forearmL": (-30, 0, 0)})


def brandish(carry, arm, held=None):
    """Roused: a fist (or what the hand holds) shaken overhead, twice."""
    side = "R" if arm == "R" else "L"
    sign = 1 if side == "R" else -1

    def pose(f):
        up = between([(0, 0.0), (8, 1.0), (37, 1.0), (45, 0.0)], f)
        shake = math.sin(2 * math.pi * f / 15) * up
        more = {"arm" + side: (-30 - 120 * up, 0, sign * (6 + 14 * up)), "forearm" + side: (-30 - 30 * up + 20 * shake, 0, 0),
                "torso": (carry.get("torso", (0, 0, 0))[0] - 6 * up, 0, -sign * 6 * up), "head": (-8 * up, 0, 0)}
        if held:
            more[held] = (carry.get(held, (0, 0, 0))[0] + 30 * up, 0, 0)
        return merge(carry, more)
    return pose


def flinching(carry):
    """Startled by a blow: rocked back, the arms flung up before the face."""
    def pose(share):
        return merge(carry, {"torso": (carry.get("torso", (0, 0, 0))[0] - 20 * share, 0, 10 * share),
                             "head": (carry.get("head", (0, 0, 0))[0] - 14 * share, 0, -16 * share),
                             "hips": {"turn": (0, 0, 4 * share), "shift": (0, 0.04 * share, -0.02 * share)},
                             "thighR": (12 * share, 0, 0), "shinR": (12 * share, 0, 0), "thighL": (-10 * share, 0, 0), "shinL": (16 * share, 0, 0),
                             "armL": (-70 * share, 0, -10 * share), "forearmL": (-90 * share, 0, 0)})
    return pose


GROUPS = [("farmhand", STAFF, reach(ADULT, 0.27), lambda s: {"armL": (-4 + 14 * s, 0, -4)}, pitching, brandish(STAFF, "R", "heldR")),
          ("porter", STAFF, reach(ADULT, 0.27), lambda s: {"armL": (-4 + 14 * s, 0, -4)}, heaving, brandish(STAFF, "R", "heldR")),
          ("salter,waterCarrier", HANGING, reach(ADULT, 0.27), lambda s: {"armR": (-4 - 14 * s, 0, 4), "extra": (8 + 6 * s, 0, 0)}, scooping,
           brandish(HANGING, "R")),
          ("householder", FREE, reach(ADULT, 0.27), lambda s: {"armL": (-2 + 16 * s, 0, -4), "armR": (-2 - 16 * s, 0, 4)}, talking,
           brandish(FREE, "R")),
          ("elder", STOOPED, reach(ELDER, 0.26), lambda s: {"armL": (-6 + 8 * s, 0, -4), "armR": (-30 - 6 * s, 0, 4)}, resting,
           brandish(STOOPED, "R", "heldR")),
          ("child", FREE, reach(CHILD, 0.19), lambda s: {"armL": (-2 + 24 * s, 0, -4), "armR": (-2 - 24 * s, 0, 4)}, playing,
           brandish(FREE, "R"))]
for names, carry, stride_reach, arms, work, roused in GROUPS:
    idle = {}
    for f in range(0, 121, 10):
        u = f / 120
        idle[f] = merge(carry, {"head": (carry.get("head", (0, 0, 0))[0] + 3 * math.sin(4 * math.pi * u), 0, 24 * math.sin(2 * math.pi * u)),
                                "torso": (carry.get("torso", (0, 0, 0))[0] + 1.5 * math.sin(2 * math.pi * u), 0, 4 * math.sin(2 * math.pi * u)),
                                "hips": {"turn": (0, 0, 0), "shift": (0.008 * math.sin(2 * math.pi * u), 0, 0)}})
    keyed(rig, "idle@" + names, 120, idle)
    man.march(carry, arms, hidden=[], shown=[], reach=stride_reach)
    tagged("march", names)
    keyed(rig, "gather@" + names, 60, {f: work(f) for f in range(0, 61, 3)})
    keyed(rig, "attack@" + names, 45, {f: roused(f) for f in range(0, 46, 3)})
    struck = flinching(carry)
    keyed(rig, "hit@" + names, 45, {0: struck(0), 3: struck(0.15), 6: struck(1.0), 14: struck(0.7), 25: struck(0.25), 32: struck(0.05), 36: struck(0),
                                    45: struck(0)})
    man.death(carry, hidden=[], shown=[])
    tagged("death", names)

man.finish(out_path("Art/models/folk.glb"), [(1, name) for name in NAMES.split(",")])
