"""The commanders: the six heroes who ride at a company's head, each told
apart at a glance on the horse every rider sits (horse.py), and each its
own variant of one file:

- the Warden, in plate under a crested helm and a tall plume, a greatsword
  upright in his hand and a kite shield on his arm, his cloak cast back
  over a black warhorse barded in steel and caparisoned to the hoof;
- the Lamplighter, robed in dark wool under the House's hood and mantle, a
  staff in his left hand where a silver crescent cradles a moon-pale
  light, on a pale horse with grey socks;
- the Salt Crown, in white plate with pauldrons of moonsalt and a crown of
  its spikes, a lance tipped with a moonsalt crystal, on a pale horse with
  a moonsalt mane;
- the Horned Axe, in leather and mail under a mantle of fur and a nasal
  helm with curling horns, a great axe and a bossed shield, on a bay under
  a caparison to the knee;
- the Standard, in plate under a plumed great helm, the House's great
  banner on its pole, on a grey warhorse barded in steel;
- the Tide Heir, in sea-dark scale under a great helm crested like a
  breaking wave, a trident in his hand and his cloak cast back, on a black
  horse with pale socks.

    python Art/blender/commanders.py Art/models/commanders.glb

Drawn a ninth larger than a company's riders (commanderScale, in
Sources/NullmereModels/Art/Art.swift) and lifted as they are. Its bones are
the rider's but for the last: no commander digs, and the bone a rider's
mattock hangs from is the Lamplighter's light at the head of his staff,
which flares as he lifts it. Each way of striking is an action of the
variants that strike so ("attack@warden,hornedAxe"), the rest shared.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *
from horse import *
from person import *

reset()
NAMES = "warden,lamplighter,saltCrown,hornedAxe,standard,tideHeir"
BUILD = Build(girth=1.04, shoulders=1.04, lean=True)
A = BUILD.shoulders
HAND_R = (-0.30 * A, -0.02, 0.72)
HAND_L = (0.30 * A, -0.02, 0.72)
# The Lamplighter's staff, made leaning forward as far as the left arm's
# carry leans it back, so it stands upright as he rides.
STAFF = Vector((0, -math.sin(math.radians(21)), math.cos(math.radians(21))))
LIGHT = Vector(HAND_L) + STAFF * 2.05
moved = astride()
moved["tool"] = (tuple(LIGHT), tuple(LIGHT + Vector((0, 0, 0.1))), "heldL")
man = Person("Commander", NAMES, BUILD, moved=moved, before_bones=BONES)
rig, p, g = man.rig, man.p, man.g

coat = material("plain_coat", (0.45, 0.28, 0.16))
socks = material("plain_socks", (0.45, 0.28, 0.16))
mane = material("plain_mane", (0.10, 0.07, 0.05))
hoof = material("plain_hoof", (0.16, 0.14, 0.12))
cloth = material("cloth_caparison", (0.55, 0.55, 0.55))
dark_wool = material("plain_darkwool", (0.16, 0.15, 0.15))
fur = material("plain_fur", (0.36, 0.28, 0.20))
horn = material("plain_bone", (0.82, 0.78, 0.66))
timber = material("plain_timber_darkshaft", (0.30, 0.21, 0.13))
white_plate = material("metal_whiteplate", (0.88, 0.88, 0.85), roughness=0.35, metallic=0.8)
sea_scale = material("metal_seascale", (0.30, 0.40, 0.42), roughness=0.4, metallic=0.9)
gold = material("metal_gold", (0.85, 0.66, 0.28), roughness=0.3, metallic=1.0)
moonsalt = material("crystal_moonsalt", (0.80, 0.90, 0.98), roughness=0.1)
moon = material("glow_moon", (0.86, 0.92, 1.0))
banner = material("cloth_banner", (0.60, 0.60, 0.60))

# MARK: The horses

horse = Horse(rig, p, coat, socks, mane, hoof, cloth)
# Every commander's horse goes caparisoned: no barrel shows under the cloth.
horse.body(bare=None, maned="@lamplighter,saltCrown,hornedAxe,tideHeir")
horse.tack()
horse.caparison("@warden,lamplighter,saltCrown,standard", -0.30)
horse.caparison("@hornedAxe,tideHeir", 0.04)
horse.barding("@warden,saltCrown,standard")
horse.crinet("@warden,standard")

# MARK: The heroes, astride

man.body(hands=[("@warden,saltCrown,standard,tideHeir", p.steel), ("@lamplighter", p.skin), ("@hornedAxe", p.leather)],
         face="@warden,lamplighter,saltCrown,hornedAxe", seated=SEATED)
man.coat("@warden,standard", p.steel, p.tunic, p.iron, skirt=False)
man.coat("@lamplighter", dark_wool, dark_wool, dark_wool, skirt=False)
man.coat("@saltCrown", white_plate, white_plate, p.iron, skirt=False)
man.coat("@hornedAxe", p.dark_leather, p.dark_leather, p.iron, skirt=False)
man.coat("@tideHeir", sea_scale, sea_scale, sea_scale, skirt=False)
seated_tabard(man, "@warden,saltCrown,standard", segments=4)
# The Tide Heir's sash of the House over his scale.
bind(loft("sash@tideHeir", [((0, 0.0, 1.0), g(0.18), g(0.126), {"hips": 0.5, "torso": 0.5}), ((0, 0.0, 0.955), g(0.184), g(0.129), {"hips": 1.0})],
          segments=man.far(8), mat=p.tunic, caps=(False, False)), rig)
for side in ("L", "R"):
    man.pauldron(side, "@warden,standard,tideHeir", p.steel)
    man.pauldron(side, "@saltCrown", moonsalt)
man.mantle("@lamplighter", p.tunic)
man.mantle("@hornedAxe", fur)
trailing_cloak(man, "@warden", 0.30)
trailing_cloak(man, "@saltCrown", 0.24)
trailing_cloak(man, "@tideHeir", 0.36)

# The Warden's crested helm and the tall plume that rises from it.
man.crested("@warden", p.steel, cheeks=False)
plume = solid("plume@warden", "box", mat=p.plume_cloth, location=at_head(0, 0.03, 0.33), size=(0.05, 0.16, 0.42), rotation=(-14, 0, 0))
shape_vertices(plume, lambda v: Vector((v.x * (0.6 if v.z > HEAD[2] + 0.4 else 1.0), v.y, v.z)))
sway(plume, lambda q: max(0.0, min(1.0, (q.z - HEAD[2] - 0.16) / 0.3)))
hang(plume, rig, "head")

# The Lamplighter's hood, the House's.
man.hood("@lamplighter", p.tunic)

# The Salt Crown: a band of gold at the brow and seven spikes of moonsalt,
# tallest at the brow.
hang(loft("crown band@saltCrown", [(at_head(0, 0, 0.055), HEAD_R[0] + 0.012, HEAD_R[1] + 0.012, {}),
                                   (at_head(0, 0, 0.085), HEAD_R[0] + 0.012, HEAD_R[1] + 0.012, {})],
          segments=man.far(8), mat=gold, caps=(False, False)), rig, "head")
spikes = []
for index in range(7):
    angle = 2 * math.pi * index / 7 - math.pi / 2
    tall = 0.24 if index == 0 else 0.17 if index % 2 == 0 else 0.11
    x, y = math.cos(angle) * (HEAD_R[0] + 0.01), math.sin(angle) * (HEAD_R[1] + 0.01)
    spike = solid("spike", "cone", mat=moonsalt, vertices=3, radius1=0.03, depth=tall, location=at_head(x / 1.1, y / 1.1, 0.07 + tall / 2.2))
    spikes.append(spike)
hang(join("crown@saltCrown", spikes), rig, "head")

# The Horned Axe's nasal helm, horns curling out and up from it.
man.nasal_helm("@hornedAxe", p.iron)
horns = []
for s in (1, -1):
    horns.append(loft("horn", [(at_head(s * 0.09, 0.0, 0.05), 0.032, 0.032, {}), (at_head(s * 0.19, -0.01, 0.10), 0.024, 0.024, {}),
                               (at_head(s * 0.22, -0.06, 0.22), 0.012, 0.012, {}), (at_head(s * 0.20, -0.11, 0.29), 0.003, 0.003, {})],
                      segments=4, mat=horn, caps=(True, True)))
hang(join("horns@hornedAxe", horns), rig, "head")

# Great helms: the Standard's plumed, the Tide Heir's crested like a wave.
man.great_helm("@standard", p.steel)
man.great_helm("@tideHeir", p.dark_iron, plume=False)
wave = solid("wave crest@tideHeir", "box", mat=sea_scale, location=at_head(0, 0.03, 0.2), size=(0.018, 0.30, 0.14))
shape_vertices(wave, lambda v: Vector((v.x, v.y, v.z + 0.12 * max(0.0, (HEAD[1] - v.y) / 0.15) ** 2 if v.z > HEAD[2] + 0.2 else v.z)))
hang(wave, rig, "head")

# MARK: Their arms, upright in the right hand

x, y, z = HAND_R
# The Warden's greatsword: a grip bound in leather, a gold guard and pommel, a long blade.
sword = join("greatsword@warden", [
    solid("grip", "cylinder", mat=p.dark_leather, vertices=4, radius=0.022, depth=0.26, location=(x, y, z + 0.02)),
    solid("guard", "box", mat=gold, location=(x, y, z + 0.17), size=(0.34, 0.045, 0.04)),
    solid("blade", "box", mat=p.steel, location=(x, y, z + 0.80), size=(0.075, 0.022, 1.22)),
    solid("point", "cone", mat=p.steel, vertices=4, radius1=0.053, depth=0.16, location=(x, y, z + 1.49), rotation=(0, 0, 45)),
])
hang(sword, rig, "heldR")
# Near, its gold pommel and the fuller down the blade.
hang(join("greatsword work@warden!fine", [
    solid("pommel", "sphere", mat=gold, segments=8, rings=4, radius=(0.035, 0.035, 0.035), location=(x, y, z - 0.13)),
    solid("fuller", "box", mat=p.iron, location=(x, y - 0.012, z + 0.75), size=(0.018, 0.004, 1.0)),
]), rig, "heldR")

# The Salt Crown's lance, its head a crystal of moonsalt.
butt = z - 0.6
hang(join("lance@saltCrown", [
    solid("lance shaft", "cylinder", mat=p.shaft, vertices=5, radius=0.021, depth=3.1, location=(x, y, butt + 1.55)),
    solid("vamplate", "cone", mat=p.steel, vertices=6, radius1=0.08, depth=0.2, location=(x, y, z + 0.18), rotation=(180, 0, 0)),
    solid("crystal", "cone", mat=moonsalt, vertices=4, radius1=0.05, depth=0.34, location=(x, y, butt + 3.27)),
]), rig, "heldR")
hang(loft("lance grip@saltCrown!fine", [((x, y, z - 0.08), 0.027, 0.027, {}), ((x, y, z + 0.08), 0.027, 0.027, {})], segments=8,
          mat=p.dark_leather, caps=(False, False)), rig, "heldR")

# The Horned Axe's great axe: a long haft and a broad crescent of a blade.
blade = solid("axe blade", "box", mat=p.steel, location=(x, y - 0.17, z + 1.12), size=(0.022, 0.30, 0.40))
shape_vertices(blade, lambda v: Vector((v.x, v.y, z + 1.12 + (v.z - z - 1.12) * (1.35 if v.y < y - 0.2 else 0.55))))
hang(join("great axe@hornedAxe", [
    solid("haft", "cylinder", mat=timber, vertices=5, radius=0.024, depth=1.80, location=(x, y, z + 0.38)),
    blade,
    solid("spike", "cone", mat=p.iron, vertices=4, radius1=0.03, depth=0.16, location=(x, y + 0.09, z + 1.12), rotation=(-90, 0, 0)),
]), rig, "heldR")

# The Standard's great banner of the House on its pole, hung from a
# crossbar behind it.
top = z + 2.7
pole = join("standard pole@standard", [
    solid("pole", "cylinder", mat=timber, vertices=5, radius=0.024, depth=3.3, location=(x, y, top - 1.65)),
    solid("crossbar", "box", mat=timber, location=(x, y + 0.45, top - 0.06), size=(0.03, 0.92, 0.03)),
    solid("finial", "cone", mat=gold, vertices=4, radius1=0.05, depth=0.16, location=(x, y, top + 0.08), rotation=(0, 0, 45)),
])
hang(pole, rig, "heldR")
flag = solid("banner@standard", "box", mat=banner, location=(x, y + 0.47, top - 0.48), size=(0.014, 0.88, 0.76))
sway(flag, lambda q: max(0.0, min(1.0, 0.75 * (q.y - y) / 0.9 + 0.5 * (top - 0.06 - q.z) / 0.76)))
hang(flag, rig, "heldR")

# The Tide Heir's trident.
prongs = [solid("shaft", "cylinder", mat=timber, vertices=4, radius=0.02, depth=2.6, location=(x, y, z + 0.6)),
          solid("bar", "box", mat=p.steel, location=(x, y, z + 1.92), size=(0.34, 0.035, 0.035))]
for dx, tall in ((-0.15, 0.30), (0.0, 0.42), (0.15, 0.30)):
    prongs.append(solid("prong", "cone", mat=p.steel, vertices=4, radius1=0.022, depth=tall, location=(x + dx, y, z + 1.92 + tall / 2)))
hang(join("trident@tideHeir", prongs), rig, "heldR")

# MARK: In the left hand: shields, and the Lamplighter's staff and light

man.kite_shield("kite shield@warden", 0.44, 0.23, p.painted, gold)
man.round_shield("bossed shield@hornedAxe", 0.27, p.painted, boss=True)
hx, hy, hz = HAND_L
bottom, head = Vector(HAND_L) - STAFF * 0.5, Vector(HAND_L) + STAFF * 1.9
hang(loft("staff@lamplighter", [(tuple(bottom), 0.02, 0.02, {}), (tuple(head), 0.017, 0.017, {})], segments=5, mat=timber, caps=(True, True)),
     rig, "heldL")
# A crescent of silver cradling the light.
arc = []
for index in range(6):
    a = math.radians(-70 + 140 * index / 5)
    arc.append((tuple(LIGHT + Vector((0, -math.sin(a) * 0.13, -math.cos(a) * 0.13 + 0.02))), 0.016, 0.016, {}))
hang(loft("crescent@lamplighter", arc, segments=4, mat=p.steel, caps=(True, True)), rig, "heldL")
hang(solid("light@lamplighter", "sphere", mat=moon, segments=6, rings=4, radius=(0.075, 0.075, 0.075), location=tuple(LIGHT)), rig, "tool")

# Each rider's legs carried by his seat, and the rig's lantern bone by his torso.
fold(rig, FOLDED)

# MARK: The clips

# Each right hand's arm upright, the shield or the staff (or the reins)
# before the body in the left.
CARRY = {"armR": (-8, 0, 4), "forearmR": (-30, 0, 0), "heldR": (38, 0, 0),
         "armL": (-14, 0, -6), "forearmL": (-62, 0, 0), "heldL": (55, 0, 0)}

IDLE = {}
for f in range(0, 121, 10):
    u = f / 120
    IDLE[f] = merge(CARRY, at_rest(u), {"head": (2, 0, 28 * math.sin(2 * math.pi * (u - 0.1))),
                                        "torso": (0, 0, 7 * math.sin(2 * math.pi * (u - 0.1)))})
keyed(rig, "idle", 120, IDLE)

march = {}
for k in range(13):
    f = 2.5 * k
    march[f] = merge(CARRY, canter((f / 15) % 1.0), {"heldR": (38 + 3 * math.sin(2 * math.pi * f / 15), 0, 0)})
keyed(rig, "march", 30, march)


def charging(f):
    """The horse at the gallop, three long strides over the strike."""
    return canter((f / 15) % 1.0, reach=32, fold=90)


def share_at(f):
    return min(1.0, f / 10) if f < 38 else max(0.0, 1 - (f - 38) / 7)


FRAMES = [2.5 * k for k in range(19)]

# The lance (and the trident) levelled and couched at the foe.
keyed(rig, "attack@saltCrown,tideHeir", 45, {f: merge(CARRY, charging(f), couched(share_at(f))) for f in FRAMES})


def cut(f):
    """A blade or an axe raised back over the shoulder and cut down across
    the horse's neck at the foe."""
    raised = {"armR": (-160, 0, 14), "forearmR": (-50, 0, 0), "heldR": (75, 0, 0), "torso": (-4, 0, -14), "head": (-4, 0, -8)}
    struck = {"armR": (-36, 0, -6), "forearmR": (-6, 0, 0), "heldR": (124, 0, 0), "torso": (16, 0, 14), "head": (-8, 0, 6)}
    keys = [(0, CARRY), (16, raised), (22, struck), (30, struck), (45, CARRY)]
    for (f0, a), (f1, b) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            t = (f - f0) / (f1 - f0)
            t = t * t * (3 - 2 * t)
            pose = {}
            for bone in set(a) | set(b):
                va, vb = a.get(bone, (0, 0, 0)), b.get(bone, (0, 0, 0))
                pose[bone] = tuple(va[i] + (vb[i] - va[i]) * t for i in range(3))
            return pose
    return CARRY


keyed(rig, "attack@warden,hornedAxe", 45, {f: merge(CARRY, charging(f), cut(f)) for f in FRAMES})


def lifted(f):
    """The staff lifted high in the left hand, upright, its light flaring."""
    share = share_at(f)
    pose = {"armL": (-14 - 136 * share, 0, -6 - 6 * share), "forearmL": (-62 + 42 * share, 0, 0), "heldL": (55 + 94 * share, 0, 0),
            "torso": (-6 * share, 0, 0), "head": (-12 * share, 0, 0)}
    flare = 1.0 + share * (0.25 + 0.15 * math.sin(2 * math.pi * f / 9))
    pose["tool"] = {"turn": (0, 0, 0), "scale": flare}
    return pose


keyed(rig, "attack@lamplighter", 45, {f: merge(CARRY, charging(f), lifted(f)) for f in FRAMES})


def sweep(f):
    """The banner raised high on its pole and swept from side to side over
    the charge."""
    share = share_at(f)
    side = math.sin(2 * math.pi * f / 22)
    return {"armR": (-8 - 62 * share, 0, 4), "forearmR": (-30, 0, 0), "heldR": (38 + 62 * share, 34 * share * side, 0),
            "torso": (-4 * share, 0, -6 * share * side)}


keyed(rig, "attack@standard", 45, {f: merge(CARRY, charging(f), sweep(f)) for f in FRAMES})


def struck(share):
    """The horse shying, its rider rocked back, his shield or staff thrown up."""
    return merge(CARRY, shied(share), {"armR": (-8 + 14 * share, 0, 4 - 8 * share), "armL": (-14 - 30 * share, 0, -6 - 8 * share),
                                       "forearmL": (-62 - 18 * share, 0, 0)})


keyed(rig, "hit", 45, {0: struck(0), 3: struck(0.15), 6: struck(1.0), 14: struck(0.7), 25: struck(0.25), 32: struck(0.05), 36: struck(0),
                       45: struck(0)})


def down(share):
    return merge(CARRY, fallen(share), {"heldR": (38 - 26 * share, 0, 0)})


keyed(rig, "death", 45, {0: down(0), 6: down(0.12), 12: down(0.35), 22: down(0.75), 30: down(1.0), 38: down(1.0), 45: down(1.0)})

# Gathering: the horse crops the grass while its rider sits easy and looks
# about him, his arms at rest.
gather = {}
for f in range(0, 61, 10):
    u = f / 60
    gather[f] = merge(CARRY, grazing(u if f < 60 else 0), {"head": (6, 0, 32 * math.sin(2 * math.pi * u)), "torso": (4, 0, 8 * math.sin(2 * math.pi * u)),
                                                           "hips": (-3, 0, 0)})
keyed(rig, "gather", 60, gather)

man.finish(out_path("Art/models/commanders.glb"), [(1, name) for name in NAMES.split(",")])
