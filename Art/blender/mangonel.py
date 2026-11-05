"""The Mangonel: a crewman behind a two-wheeled engine he pushes by its
shafts like a barrow. A frame of timber on its wheels, a skein of twisted
rope across it, a long arm lying cocked back with a stone in its cup, and a
padded stop bar on its posts for the arm to strike. A bed of planks and iron
bands from the second tier, a mantlet before it from the third, dark timber
and the House's colours from the fourth; at the fifth a great engine,
longer in the frame and the arm, its stop bar higher, bound in gilt and
flying a pennon. The crewman is short and stocky, on the body every person
on foot shares (person.py): a padded coat and a hood, the House's tunic
and a cap, mail and a nasal helm, plate under a kettle hat, gilt on the
shoulders.

    python Art/blender/mangonel.py Art/models/mangonel.glb

The engine is the rig's `extra` bone, at the rig's root, so it stands where
it is when its crewman falls; its wheels, arm and stone are bones after the
body's, in the order the game names them (Engine, in
Sources/NullmereModels/Engines.swift). Drawn a fifteenth shorter than a
company's spearmen (mangonelScale, in Sources/NullmereModels/Art/Art.swift);
its wheels turn once a march period and its crewman's stride is lengthened,
so both hold the ground at the pace every company on foot keeps.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from carts import *
from common import *
from person import *

reset()
# Its measures, in Blender's units from the crewman's feet: where the arm
# turns in its skein, how long it is, where the stop bar stands, and where
# the frame ends before (-y), for the engine and the great engine.
RAIL = WHEEL + 0.09
THROW, REST = 100.0, -1.2


def measures(great):
    pivot = Vector((0, -1.53 if great else -1.26, WHEEL + 0.234))
    length = 1.332 if great else 1.116
    front = -2.556 if great else -2.25
    axle = Vector((0, front + 0.36, WHEEL))
    bar_y = pivot.y - (0.576 if great else 0.45)
    bar_z = pivot.z + (pivot.y - bar_y) / math.tan(math.radians(THROW) + REST)
    cup = pivot + Vector((0, math.sin(-REST), math.cos(-REST))) * length
    return pivot, length, front, axle, bar_y, bar_z, cup


SMALL, GREAT = measures(False), measures(True)
pivot, length, front, axle, bar_y, bar_z, cup = SMALL
big_pivot, _, big_front, big_axle, big_bar_y, big_bar_z, big_cup = GREAT

BUILD = Build(girth=1.12, shoulders=0.94, lean=True)
moved = {"extra": ((0, pivot.y, WHEEL), (0, pivot.y, WHEEL + 0.1), None)}
WHEELS = [("wheelL", (axle.x + 0.468, axle.y, axle.z), (axle.x + 0.468, axle.y, axle.z + 0.1), "extra"),
          ("wheelR", (axle.x - 0.468, axle.y, axle.z), (axle.x - 0.468, axle.y, axle.z + 0.1), "extra"),
          ("arm", tuple(pivot), tuple(cup), "extra"),
          ("stone", tuple(cup), tuple(cup + Vector((0, 0, 0.1))), "arm")]
man = Person("Mangonel", "", BUILD, moved=moved, more_bones=WHEELS)
rig, p, g, a = man.rig, man.p, man.g, man.ax

padded = material("plain_padded", (0.62, 0.55, 0.42))
pale = material("plain_timber_pale", (0.66, 0.54, 0.38))
dark = material("plain_timber_dark", (0.34, 0.24, 0.15))
rope = material("plain_rope", (0.70, 0.64, 0.50))
canvas = material("plain_canvas", (0.74, 0.70, 0.60))
stone_mat = material("plain_stone_rock", (0.52, 0.50, 0.47))
gold = material("metal_gold", (0.85, 0.66, 0.28), roughness=0.3, metallic=1.0)

# MARK: The crewman

man.body(hands=[("@1-3", p.skin), ("@4-5", p.steel)], face="")
man.coat("@1", padded, padded, padded, hem=0.66)
man.coat("@2", p.tunic, p.tunic, padded, hem=0.66)
man.coat("@3", p.iron, p.iron, p.leather, hem=0.66)
man.coat("@4-5", p.steel, p.tunic, p.iron, hem=0.66)
# The House at his belt.
bind(loft("sash" + man.every("1-5"), [((0, 0.0, 1.0), g(0.178), g(0.124), {"hips": 0.5, "torso": 0.5}),
                                      ((0, 0.0, 0.955), g(0.182), g(0.127), {"hips": 1.0})],
          segments=man.far(8), mat=p.tunic, caps=(False, False)), rig)
man.hood("@1", p.wool)
man.cap("cap", "@2", p.dark_leather, 0.006, 0.0)
man.nasal_helm("@3", p.iron)
man.kettle("@4-5", p.steel)
for side in ("L", "R"):
    man.pauldron(side, "@5", gold)
man.mattock()

# MARK: The engine, on the extra bone at the rig's root

def frame(tags, m, wood):
    """Shafts from the hands forward to the frame's tail, the frame's two
    rails and the beams across them, the skein, posts and the stop bar."""
    piv, ln, fr, ax, by, bz, cp = m
    tail = -0.61
    pieces = []
    for s in (1, -1):
        pieces.append(beam("shaft", Vector((a(s * 0.30), -0.17, 0.74)), Vector((s * 0.324, tail - 0.04, RAIL + 0.07)), 0.05, wood))
        pieces.append(solid("rail", "box", mat=wood, location=(s * 0.36, (tail + fr) / 2, RAIL + 0.063), size=(0.108, abs(fr - tail), 0.126)))
        # The posts that hold the stop bar, from the rail up to it.
        pieces.append(beam("post", Vector((s * 0.36, by + 0.13, RAIL + 0.126)), Vector((s * 0.306, by, bz)), 0.063, wood))
    for y in (tail - 0.07, fr + 0.09):
        pieces.append(solid("beam", "box", mat=pale, location=(0, y, RAIL + 0.063), size=(0.61, 0.108, 0.09)))
    pieces.append(solid("skein", "cylinder", mat=rope, vertices=5, radius=0.09, depth=0.61, location=tuple(piv), rotation=(0, 90, 0)))
    pieces.append(solid("stop bar", "box", mat=pale, location=(0, by, bz + 0.012), size=(0.684, 0.126, 0.126)))
    hang(join("engine" + tags, pieces), rig, "extra")


def furniture(tier, m, wood):
    """What a tier adds: a bed of planks and bands from the second, a mantlet
    from the third, in the House's colours from the fourth; at the fifth gilt
    and a pennon."""
    piv, ln, fr, ax, by, bz, cp = m
    tags = "@%d" % tier
    tail = -0.61
    pieces = []
    house = tier >= 4
    pad = solid("padding", "box", mat=p.tunic if house else canvas, location=(0, by + 0.07, bz - 0.0), size=(0.432, 0.054, 0.20))
    pieces.append(pad)
    if tier >= 2:
        pieces.append(solid("bed", "box", mat=pale, location=(0, (tail + fr) / 2 - 0.02, RAIL + 0.054), size=(0.612, abs(fr - tail) - 0.27, 0.036)))
        for s in (1, -1):
            pieces.append(solid("side board", "box", mat=pale, location=(s * 0.36, (tail + fr) / 2 - 0.02, RAIL + 0.24),
                                size=(0.054, abs(fr - tail) - 0.30, 0.22)))
        # Spare stones on the bed: seen far off until a mantlet stands before them.
        spares = [solid("spare stone", "sphere", mat=stone_mat, segments=5, rings=3, radius=(0.085, 0.08, 0.075),
                        location=(x, y, RAIL + 0.15)) for x, y in ((0.14, tail - 0.30), (-0.12, tail - 0.36), (0.02, tail - 0.52))]
        hang(join("spare stones@%d%s" % (tier, "" if tier == 2 else "!fine"), spares), rig, "extra")
        # Iron (gilt, at the fifth) bound about the rails, near.
        band = gold if tier >= 5 else p.iron
        bands = [solid("band", "box", mat=band, location=(s * 0.36, y, RAIL + 0.063), size=(0.126, 0.072, 0.144))
                 for y in (tail - 0.38, fr + 0.36) for s in (1, -1)]
        hang(join("bands%s!fine" % tags, bands), rig, "extra")
    if tier >= 3:
        height = 1.08 if tier >= 5 else 0.90
        pieces.append(solid("mantlet", "box", mat=p.tunic if house else pale, location=(0, fr - 0.07, (RAIL + 0.126 + height) / 2),
                            size=(0.90, 0.072, height - RAIL - 0.126)))
    hang(join("engine furniture" + tags, pieces), rig, "extra")
    if tier >= 5:
        staff = solid("pennon staff@5!fine", "box", mat=dark, location=(0.306, by, bz + 0.30), size=(0.036, 0.036, 0.58))
        hang(staff, rig, "extra")
        flag = solid("pennon@5!fine", "box", mat=p.cloak_cloth, location=(0.306, by + 0.16, bz + 0.52), size=(0.012, 0.29, 0.16))
        sway(flag, lambda q, y0=by: max(0.0, min(1.0, (q.y - y0) / 0.3)))
        hang(flag, rig, "extra")


def arm(tags, m, wood):
    """The throwing arm lying cocked, its leather cup at the end, and the
    stone in it."""
    piv, ln, fr, ax, by, bz, cp = m
    cup_box = solid("cup", "box", mat=p.leather, location=tuple(cp), size=(0.198, 0.198, 0.063))
    hang(join("arm" + tags, [beam("arm beam", piv, cp, 0.081, wood), cup_box]), rig, "arm")
    rock = solid("stone" + tags, "sphere", mat=stone_mat, segments=5, rings=3, radius=(0.09, 0.09, 0.081),
                 location=tuple(cp + Vector((0, 0, 0.09))))
    hang(rock, rig, "stone")


def close_work(tags, m, wood):
    """Near: the skein wound in turns of rope between iron washers, the
    winch at the tail with its drum and crank, the frame's lashings."""
    piv, ln, fr, ax, by, bz, cp = m
    tail = -0.61
    work = []
    for turn in range(7):
        x = -0.27 + turn * 0.09
        work.append(solid("turn", "cylinder", mat=rope, vertices=10, radius=0.1, depth=0.05, location=(x, piv.y, piv.z), rotation=(0, 90, 0)))
    for x in (-0.33, 0.33):
        work.append(solid("washer", "cylinder", mat=p.iron, vertices=12, radius=0.135, depth=0.036, location=(x, piv.y, piv.z), rotation=(0, 90, 0)))
    work.append(solid("winch drum", "cylinder", mat=pale, vertices=10, radius=0.072, depth=0.576, location=(0, tail - 0.18, RAIL + 0.2),
                      rotation=(0, 90, 0)))
    work.append(solid("winch rope", "cylinder", mat=rope, vertices=10, radius=0.083, depth=0.29, location=(0, tail - 0.18, RAIL + 0.2),
                      rotation=(0, 90, 0)))
    work.append(solid("crank", "box", mat=p.iron, location=(0.39, tail - 0.18, RAIL + 0.15), size=(0.02, 0.02, 0.13)))
    for s in (1, -1):
        for y in (tail - 0.07, fr + 0.09, by + 0.13):
            work.append(solid("lashing", "cylinder", mat=rope, vertices=8, radius=0.075, depth=0.04, location=(s * 0.36, y, RAIL + 0.063)))
    hang(join("engine work%s!fine" % tags, work), rig, "extra")
    rope_line = loft("winch line%s!fine" % tags, [((0, tail - 0.18, RAIL + 0.27), 0.011, 0.011, {}),
                                                   (tuple(piv + Vector((0, 0.05, 0.11))), 0.011, 0.011, {})],
                     segments=4, mat=rope, caps=(False, False))
    hang(rope_line, rig, "extra")


for tier in range(1, 6):
    m = GREAT if tier == 5 else SMALL
    wood = dark if tier >= 4 else p.shaft
    tags = "@%d" % tier
    frame(tags, m, wood)
    furniture(tier, m, wood)
    arm(tags, m, wood)
    wheel_pair(rig, p, m[3], 0.468, tags, wood, rimmed=tier >= 4, hub=dark)
    close_work(tags, m, wood)

# MARK: The clips

AT_WORK = dict(hidden=["tool"], shown=["heldR", "heldL"])
# Both hands on the shafts, the crewman leaning into them.
CARRY = {"armR": (-10, 0, 3), "forearmR": (-10, 0, 0), "armL": (-10, 0, -3), "forearmL": (-10, 0, 0), "torso": (8, 0, 0), "head": (-6, 0, 0)}


def creak(u):
    return {"arm": (0.9 * math.sin(4 * math.pi * u), 0, 0)}


IDLE = {f: merge(CARRY, creak(f / 120), {"head": (-6, 0, 16 * math.sin(2 * math.pi * f / 120))}) for f in range(0, 121, 10)}
keyed(rig, "idle", 120, IDLE, **AT_WORK)


man.march(CARRY, lambda side: {}, **AT_WORK, reach=REACH, more=rolling)


def loosing(frame):
    """The throw: he pulls the pin and the arm flies to the stop bar, its
    stone gone; then he bends to the winch and winds it back down, cranking,
    and lays another stone in the cup."""
    u = frame / 45
    if u <= 0.22:
        swing = 0.0
    elif u <= 0.30:
        swing = THROW * (u - 0.22) / 0.08
    elif u <= 0.42:
        swing = THROW
    elif u <= 0.90:
        swing = THROW * (0.90 - u) / 0.48
    else:
        swing = 0.0
    pull = 1.0 if 0.16 <= u <= 0.26 else 0.0
    wind = 1.0 if 0.50 <= u <= 0.84 else 0.0
    crank = 18 * math.sin(2 * math.pi * (u - 0.5) / 0.08) * wind
    pose = merge(CARRY, {
        "arm": (swing, 0, 0),
        "torso": (8 - 14 * pull + 22 * wind, 0, 0), "head": (-6 + 10 * wind, 0, 0),
        "armR": (-10 - 28 * pull - 34 * wind + crank, 0, 3), "armL": (-10 - 28 * pull - 34 * wind - crank, 0, -3),
        "forearmR": (-10 - 22 * pull - 28 * wind, 0, 0), "forearmL": (-10 - 22 * pull - 28 * wind, 0, 0),
        "thighL": (-14 * wind, 0, 0), "shinL": (20 * wind, 0, 0),
        "hips": {"turn": (0, 0, 0), "shift": (0, 0, -0.04 * wind)},
    })
    pose["stone"] = {"turn": (0, 0, 0), "scale": 0.001 if 0.275 <= u <= 0.915 else 1.0}
    return pose


ATTACK = {}
for f in [0, 6, 7.2, 9.9, 11.7, 12.3, 13.5, 16, 18.9, 22.5, 24, 26, 28, 30, 32, 34, 36, 37.8, 40.5, 41.1, 41.4, 45]:
    ATTACK[f] = loosing(f)
keyed(rig, "attack", 45, ATTACK, **AT_WORK)


def jolted(share):
    """Struck: the engine jolted and rocked on its wheels, the arm jumping
    in its skein, the crewman ducking behind it."""
    return merge(CARRY, {"extra": {"turn": (4.6 * share, 0, 5.7 * share * (1 if share > 0.5 else -1)), "shift": (0, 0.02 * share, 0.01 * share)},
                         "arm": (14 * share, 0, 0), "torso": (8 + 30 * share, 0, 0), "head": (-6 + 12 * share, 0, 0),
                         "hips": {"turn": (0, 0, 0), "shift": (0, 0.04 * share, -0.06 * share)},
                         "thighL": (-16 * share, 0, 0), "shinL": (26 * share, 0, 0), "thighR": (-12 * share, 0, 0), "shinR": (20 * share, 0, 0)})


keyed(rig, "hit", 45, {0: jolted(0), 3: jolted(0.15), 6: jolted(1.0), 14: jolted(0.7), 25: jolted(0.25), 32: jolted(0.05), 36: jolted(0),
                       45: jolted(0)}, **AT_WORK)

# Down: the crewman falls as any man on foot does, and his engine settles
# askew where it stands, its arm slack.


def askew(frame):
    share = min(1.0, max(0.0, (frame - 13.5) / 22.5))
    return {"extra": {"turn": (-2.9 * share, 0, 8 * share), "shift": (0, 0, -0.06 * share)}, "arm": (20 * share, 0, 0)}


man.death(CARRY, **AT_WORK, more=askew)
# Gathering: he steps out from the shafts and works the mattock beside the
# engine, which stands.
man.gather(hidden=["heldR", "heldL"], shown=["tool"], more=lambda frame: {"hips": {"turn": (0, 0, 0), "shift": (0.62, 0.1, -0.03)}})

man.finish(out_path("Art/models/mangonel.glb"), [(1, None), (2, None), (3, None), (4, None), (5, None)])
