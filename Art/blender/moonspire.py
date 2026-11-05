"""The Moonspire, the great work of the age, a white tower of moonsalt and
stone raised in five stages on its plinth, each stage a tier of one file,
within a work's slot and facing +z:
1. its foundations: the drum's first courses of white blocks laid round,
   open at its door, each course shorter than the one below as the masons
   work their way round, more blocks and moonsalt waiting;
2. the drum, buttressed and crenellated, its door lit under a carved arch
   between braziers, its windows lit;
3. a tapering stage ribbed in moonsalt above a gallery about the drum's
   top;
4. a slender upper stage ribbed in moonsalt, and the wonder's dress: a
   colonnade about the drum's foot under a ring of stone, a string course
   and the House's banners hung between the buttresses;
5. the spire, crowned with a great moonsalt crystal round a light, turning
   slowly, a halo of shards turning the other way below it, moonsalt grown
   out of the plinth.
Until it is crowned a crane works from the top of the stage last raised,
its treadwheel turning. It stands in a court of its own: a landing of pale
flags before its door, obelisks of black stone tipped with moonsalt round
the plinth's edge, more with each stage, moonsalt braziers from the third
and a gate arch with the House's banners at the fifth.

    python Art/blender/moonspire.py Art/models/moonspire.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

white = material("plain_stone_white", (0.84, 0.84, 0.82))
pale = material("plain_stone_pale", (0.68, 0.67, 0.64))
stone = material("plain_stone", (0.52, 0.51, 0.49))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
linen = material("plain_linen", (0.7, 0.67, 0.6))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
bronze = material("metal_bronze", (0.55, 0.43, 0.26), roughness=0.4, metallic=0.7)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.35, metallic=0.8)
hanging = material("house_awning", (0.6, 0.2, 0.2))
banner = material("cloth_banner", (0.78, 0.78, 0.78))
moonglow = material("glow_moonglow", (0.72, 0.86, 1.0))
fire = material("glow_fire", (1.0, 0.68, 0.32))
moonsalt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)

FRONT = 3 * math.pi / 2  # +z, as the game's MeshBuilder.ring counts round
PLINTH = [(0.31, -0.14), (0.31, 0.04), (0.28, 0.06)]
DRUM = [(0.23, 0.04), (0.21, 0.4), (0.235, 0.42), (0.235, 0.45)]
STAGE3 = [(0.17, 0.44), (0.14, 0.82), (0.175, 0.84), (0.175, 0.87)]
STAGE4 = [(0.12, 0.86), (0.09, 1.28), (0.115, 1.3), (0.115, 1.33)]
TOP = 0.06  # the plinth's top
# The buttresses stand round the drum either side of its door, the windows,
# spouts and banners between them, the door between the two at the front.
BUTTRESSES = [math.pi / 10 + k * 2 * math.pi / 5 for k in range(5)]
BETWEEN = [a + math.pi / 5 for a in BUTTRESSES]
SIDES = [a for a in BETWEEN if abs(a - 3 * math.pi / 2) > 0.5]
COLONNADE = 0.265
# The crane on the stage last raised: its foot, height, reach and the
# treadwheel's radius.
CRANES = {1: ((0.0, 0.06, -0.04), 0.32, 0.17, 0.05), 2: ((0.0, 0.45, 0.0), 0.3, 0.295, 0.05),
          3: ((0.0, 0.87, 0.0), 0.26, 0.26, 0.045), 4: ((0.0, 1.33, 0.0), 0.24, 0.2, 0.035)}
DOOR_FIRES = {"L": (-0.055, TOP + 0.086, 0.25), "R": (0.055, TOP + 0.086, 0.25)}
COURT_FIRES = {"L": 7 * math.pi / 6 - 0.03, "R": 11 * math.pi / 6 + 0.03}
LIT_DOOR, LIT_COURT = [2, 3, 4, 5], [3, 4, 5]


def hub(level):
    foot, _, _, radius = CRANES[level]
    return (foot[0], foot[1] + radius + 0.006, foot[2] - (radius + 0.02))


parts = [("crane@%d" % level, CRANES[level][0], (0, 1, 0)) for level in CRANES]
parts += [("treadwheel@%d" % level, hub(level), (1, 0, 0)) for level in CRANES]
parts += [("crown@5", (0.0, 1.62, 0.0), (0, 1, 0)), ("halo@5", (0.0, 1.48, 0.0), (0, 1, 0))]
parts += [("door fire %s@%s" % (side, ",".join(map(str, LIT_DOOR))), at_point, (0, 1, 0)) for side, at_point in DOOR_FIRES.items()]
parts += [("court fire %s@%s" % (side, ",".join(map(str, LIT_COURT))), on_ring(0.293, TOP + 0.067, angle), (0, 1, 0))
          for side, angle in COURT_FIRES.items()]
rig = work_rig(parts)
ground(rings(tagged("plinth", []), PLINTH, 10, pale), rig)


def piece(name, levels, far, fine=()):
    """Pieces drawn at these levels, joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


def moving(name, levels, bone, pieces, fine=False):
    """Pieces carried by a moving part at these levels."""
    obj = join(tagged(name, level_tags(levels)) + ("!fine" if fine else ""), pieces)
    on(obj, rig, bone)


def wall(profile, y):
    """A turned body's radius at a height, between its profile's rings."""
    for (r0, y0), (r1, y1) in zip(profile, profile[1:]):
        if y0 <= y <= y1 and y1 > y0:
            return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
    return profile[-1][0]


def ring_of(name, radius, base, count, size, mat, start=0.0):
    """Blocks set round a ring, each along it: merlons, balusters."""
    out = []
    for index in range(count):
        angle = start + 2 * math.pi * index / count
        x, y, z = on_ring(radius, base, angle)
        out.append(block(name, (x - size[0] / 2, y, z - size[2] / 2), (x + size[0] / 2, y + size[1], z + size[2] / 2), mat,
                         turn=-angle - math.pi / 2))
    return out


def shard(name, foot, direction, radius, length, point, mat=moonsalt):
    """A crystal of moonsalt: a four-sided prism and its point, grown from
    `foot` along `direction`."""
    obj = rings(name, [(radius, 0.0), (radius, length), (0.0, length + point)], 4, mat)
    d = Vector(direction).normalized()
    up = Vector((0, 1, 0))
    axis, angle = up.cross(d), up.angle(d)
    if axis.length < 1e-6:
        axis, angle = Vector((1, 0, 0)), (0.0 if d.y > 0 else math.pi)
    return posed(obj, foot, tuple(axis.normalized()), angle)


# MARK: The stages

def foundations():
    """The first courses laid round, open at the door, and what waits to be
    laid: dressed blocks, a heap of moonsalt, the banker, a coil of rope."""
    far, fine = [], []
    for course, laid in enumerate((18, 12, 6)):
        for slot in range(1, laid + 1):
            angle = -math.pi / 2 + (slot + 0.5 + 0.5 * (course % 2)) * math.pi / 10
            x, y, z = on_ring(0.222, 0.0775 + 0.035 * course, angle)
            far.append(block("course block", (x - 0.034, y - 0.017, z - 0.025), (x + 0.034, y + 0.017, z + 0.025),
                             pale if course == 1 else white, turn=-angle - math.pi / 2))
    chance = random.Random(11)
    for index in range(6):
        row, layer = index % 3, index // 3
        x, y, z = 0.09 + row * 0.062 - 0.062, TOP + layer * 0.042, -0.02 + layer * 0.012
        far.append(block("waiting block", (x - 0.028, y, z - 0.025), (x + 0.028, y + 0.04, z + 0.025), pale if index % 2 else white,
                         turn=(chance.random() - 0.5) * 0.3))
    far.append(rings("moonsalt heap", [(0.05, TOP - 0.01), (0.0375, TOP + 0.03), (0.0, TOP + 0.06)], 6, moonsalt, centre=(-0.11, 0.03)))
    fine += [block("banker", (-0.11, TOP, -0.1375), (-0.05, 0.11, -0.1025), dark),
             block("block on the banker", (-0.1, 0.11, -0.134), (-0.06, 0.138, -0.106), white),
             rod("mallet haft", (-0.055, 0.112, -0.1), (-0.035, 0.112, -0.085), 0.0025, timber, sides=3),
             block("mallet", (-0.065, 0.108, -0.108), (-0.051, 0.12, -0.096), dark, turn=-0.65),
             rings("rope coil", [(0.012, TOP), (0.026, TOP), (0.026, TOP + 0.012), (0.012, TOP + 0.012), (0.012, TOP)], 8, linen,
                   centre=(0.065, -0.125), caps=(False, False))]
    return far, fine


def drum(level):
    """The drum, buttressed, its door lit under its arch and its windows
    lit between the buttresses; crenellated until the gallery is built."""
    far = [rings("drum", DRUM, 10, white)]
    if level == 2:
        far += ring_of("merlon", 0.225, 0.45, 10, (0.04, 0.04, 0.025), pale, start=math.pi / 10)
    for angle in BUTTRESSES:
        cx, _, cz = on_ring(0.215, 0, angle)
        # Square to the drum: its faces outward and along it.
        far.append(rings("buttress", [(0.04, 0.0), (0.03, 0.34), (0.0, 0.4)], 4, pale, centre=(cx, cz), twist=-angle + math.pi / 4))
    far.append(lit("doorway", (0.0, 0.1, 0.225), 0.06, 0.12, 0.0, moonglow))
    for angle in SIDES:
        far.append(lit("window", on_ring(wall(DRUM, 0.25) - 0.002, 0.25, angle), 0.025, 0.06, angle + math.pi / 2, moonglow))
    return far


def door_work(roundels):
    """The drum's carved work near: an arch of voussoirs about its door,
    the keystone and jambs, a step before it, a brazier burning at either
    hand, a spout under the parapet between each pair of buttresses and,
    until banners hang there, a moon carved in moonsalt on the drum."""
    fine = []
    for index in range(7):
        angle = index * math.pi / 6
        voussoir = block("voussoir", (-0.008, -0.007, -0.007), (0.008, 0.007, 0.007), pale)
        fine.append(posed(voussoir, (0.037 * math.cos(angle), 0.16 + 0.037 * math.sin(angle), 0.232), (0, 0, 1), angle - math.pi / 2))
    fine.append(block("keystone", (-0.008, 0.19, 0.226), (0.008, 0.21, 0.242), white))
    for x in (-0.037, 0.037):
        fine.append(block("jamb", (x - 0.007, 0.05, 0.225), (x + 0.007, 0.16, 0.239), pale))
    fine.append(block("door step", (-0.05, TOP, 0.232), (0.05, TOP + 0.014, 0.272), pale))
    for side, (x, y, z) in DOOR_FIRES.items():
        fine.append(rod("brazier stem", (x, TOP, z), (x, TOP + 0.07, z), 0.005, iron, sides=4))
        fine.append(rings("brazier", [(0.004, TOP + 0.068), (0.016, TOP + 0.078), (0.018, TOP + 0.088), (0.012, TOP + 0.088)], 6, iron,
                          centre=(x, z)))
    for angle in SIDES:
        ox, _, oz = on_ring(1, 0, angle)
        fine.append(lath("spout", (ox * 0.205, 0.425, oz * 0.205), (ox * 0.262, 0.418, oz * 0.262), 0.012, 0.012, pale))
        if roundels:
            disc = rings("carved moon", [(0.022, 0.0), (0.022, 0.004), (0.014, 0.008)], 8, moonsalt)
            fine.append(shard_disc(disc, (ox * 0.214, 0.33, oz * 0.214), (ox, 0, oz)))
    return fine


def shard_disc(obj, at_point, direction):
    """A disc made about the upright, turned to face `direction`."""
    d = Vector(direction).normalized()
    up = Vector((0, 1, 0))
    return posed(obj, at_point, tuple(up.cross(d).normalized()), up.angle(d))


def door_fires():
    """The door braziers' fires, each its own part to flicker."""
    for side, (x, y, z) in DOOR_FIRES.items():
        flame = rings("door flame", [(0.012, y), (0.008, y + 0.02), (0.0, y + 0.036)], 4, fire, centre=(x, z), twist=0.3)
        moving("door flame " + side, LIT_DOOR, "door fire %s@%s" % (side, ",".join(map(str, LIT_DOOR))), [flame], fine=True)


def stage_three():
    """The tapering stage ribbed in moonsalt, crenellated, a window lit,
    and the gallery's balustrade round the drum's top."""
    far = [rings("third stage", STAGE3, 10, white)]
    far += ring_of("merlon", 0.17, 0.87, 10, (0.03, 0.035, 0.02), pale)
    for angle in BUTTRESSES:
        far.append(rod("moonsalt rib", on_ring(0.17, 0.45, angle), on_ring(0.142, 0.8, angle), 0.016, moonsalt, sides=3))
    far.append(lit("window", (0.0, 0.65, wall(STAGE3, 0.65) - 0.002), 0.03, 0.07, 0.0, moonglow))
    fine = ring_of("baluster", 0.228, 0.45, 20, (0.008, 0.03, 0.008), pale)
    fine.append(rings("gallery rail", [(0.222, 0.48), (0.234, 0.48), (0.234, 0.488), (0.222, 0.488), (0.222, 0.48)], 20, pale,
                      caps=(False, False)))
    return far, fine


def stage_four():
    """The slender upper stage ribbed in moonsalt, a window lit."""
    far = [rings("fourth stage", STAGE4, 8, white)]
    for k in range(4):
        angle = k * math.pi / 2 + math.pi / 4
        far.append(rod("moonsalt rib", on_ring(0.12, 0.87, angle), on_ring(0.092, 1.27, angle), 0.014, moonsalt, sides=3))
    far.append(lit("window", (0.0, 1.08, wall(STAGE4, 1.08) - 0.002), 0.025, 0.06, 0.0, moonglow))
    return far


def wonder():
    """The wonder's dress: a colonnade about the drum's foot under a ring
    of stone, open before the door; a string course round the drum; the
    House's banners hung between the buttresses."""
    far = []
    for k in range(10):
        angle = k * math.pi / 5
        x, _, z = on_ring(COLONNADE, TOP, angle)
        far.append(block("column base", (x - 0.015, TOP, z - 0.015), (x + 0.015, TOP + 0.024, z + 0.015), pale, turn=-angle))
        far.append(rings("column", [(0.011, TOP + 0.024), (0.0095, TOP + 0.25)], 6, white, centre=(x, z)))
        far.append(block("capital", (x - 0.016, TOP + 0.25, z - 0.016), (x + 0.016, TOP + 0.268, z + 0.016), pale, turn=-angle))
    far.append(rings("entablature", [(0.248, 0.328), (0.282, 0.328), (0.282, 0.352), (0.248, 0.352), (0.248, 0.328)], 20, pale,
                     caps=(False, False)))
    far.append(rings("string course", [(0.218, 0.19), (0.229, 0.196), (0.229, 0.21), (0.217, 0.216)], 10, pale, caps=(False, False)))
    for angle in SIDES:
        ox, _, oz = on_ring(1, 0, angle)
        across = (-oz, 0, ox)
        r = wall(DRUM, 0.35) + 0.004
        mx, mz = ox * r, oz * r
        outline = [(mx + across[0] * 0.026, 0.405, mz + across[2] * 0.026), (mx - across[0] * 0.026, 0.405, mz - across[2] * 0.026),
                   (mx - across[0] * 0.026, 0.312, mz - across[2] * 0.026), (mx, 0.296, mz), (mx + across[0] * 0.026, 0.312, mz + across[2] * 0.026)]
        far.append(slab("hanging banner", outline, hanging, 0.004, normal=(ox, 0, oz)))
    return far


def crane(level):
    """The masons' crane on the stage last raised: its mast and jib
    slewing a white block over the edge and back, its stay and rope, and
    the treadwheel that winds it, turning between its posts."""
    foot, height, reach, radius = CRANES[level]
    fx, fy, fz = foot
    tip = (fx, fy + height * 0.8, fz + reach)
    drop = height * 0.55
    arm = [rod("mast", foot, (fx, fy + height, fz), 0.011, dark, sides=6),
           lath("jib", (fx, fy + height * 0.55, fz - 0.03), tip, 0.012, 0.012, timber),
           rod("stay", (fx, fy + height, fz), tip, 0.0025, linen, sides=3),
           rod("rope", tip, (tip[0], tip[1] - drop, tip[2]), 0.0025, linen, sides=3),
           block("hung block", (tip[0] - 0.0225, tip[1] - drop - 0.034, tip[2] - 0.02), (tip[0] + 0.0225, tip[1] - drop + 0.001, tip[2] + 0.02),
                 white)]
    moving("crane arm", [level], "crane@%d" % level, arm)
    hx, hy, hz = hub(level)
    wheel_pieces = [rings("treadwheel rim", [(radius, -0.015), (radius, 0.015)], 10, dark, caps=(False, False)),
                    rings("treadwheel rim inside", [(radius - 0.004, 0.015), (radius - 0.004, -0.015)], 10, timber, caps=(False, False))]
    wheel_pieces = [posed(obj, (hx, hy, hz), (0, 0, 1), math.pi / 2) for obj in wheel_pieces]
    for k in range(3):
        a = k * math.pi / 3
        wheel_pieces.append(lath("treadwheel spoke", (hx, hy + radius * math.sin(a), hz + radius * math.cos(a)),
                                 (hx, hy - radius * math.sin(a), hz - radius * math.cos(a)), 0.006, 0.006, timber))
    wheel_pieces.append(rod("treadwheel axle", (hx - 0.022, hy, hz), (hx + 0.022, hy, hz), 0.004, iron, sides=4))
    moving("treadwheel", [level], "treadwheel@%d" % level, wheel_pieces)
    posts = [rod("treadwheel post", (hx + x, fy, hz), (hx + x, hy, hz), 0.004, dark, sides=4) for x in (-0.022, 0.022)]
    return posts


def crowned():
    """The spire, its banner, the crown and its halo, and the moonsalt grown
    out of the plinth at the buttresses' feet."""
    far = [rings("spire", [(0.1, 1.32), (0.0, 1.62)], 8, white)]
    far.append(rod("banner pole", (0.0, 1.33, 0.1), (0.0, 1.51, 0.1), 0.009, dark, sides=5))
    flag(tagged("spire banner", ["5"]), (0.0, 1.5, 0.1), 0.12, 0.07, banner, turn=-math.pi / 2, tail=True)
    crown = [rings("crown crystal", [(0.0, 1.6), (0.07, 1.7), (0.06, 1.84), (0.0, 1.96)], 6, moonsalt)]
    for k in range(3):
        angle = k * 2 * math.pi / 3
        out = on_ring(0.6, 1.0, angle)
        crown.append(shard("crown shard", on_ring(0.06, 1.66, angle), out, 0.022, 0.08, 0.05))
    crown.append(rings("crown light", [(0.0, 1.73), (0.03, 1.76), (0.0, 1.79)], 4, moonglow))
    moving("crown", [5], "crown@5", crown)
    halo = []
    for k in range(8):
        x, y, z = on_ring(0.16, 1.48 + (0.02 if k % 2 == 0 else -0.02), k * math.pi / 4)
        halo.append(rings("halo shard", [(0.0, y - 0.045), (0.013, y), (0.0, y + 0.055)], 4, moonsalt, centre=(x, z)))
    moving("halo", [5], "halo@5", halo)
    for angle in SIDES:
        for index, lean in enumerate((0.35, -0.2, 0.05)):
            x, _, z = on_ring(0.284, 0, angle + (index - 1) * 0.07)
            ox, _, oz = on_ring(1, 0, angle + lean)
            far.append(shard("plinth moonsalt", (x, TOP - 0.012, z), (ox * 0.12, 1, oz * 0.12), 0.014, 0.06 + 0.025 * index, 0.03))
    return far


def court(level):
    """The Moonspire's court: a landing of pale flags before its door,
    obelisks round the plinth's edge leaving the way open, more with each
    stage, moonsalt braziers from the third, a gate arch at the fifth."""
    far = [block("landing", (-0.045, 0.036, 0.272), (0.045, TOP + 0.002, 0.312), white),
           block("landing", (-0.04, 0.03, 0.312), (0.04, 0.044, 0.322), pale)]
    count = min(level + 1, 5)
    for index in range(count):
        angle = FRONT + math.pi / 6 + (2 * math.pi - math.pi / 3) * index / max(count - 1, 1)
        x, _, z = on_ring(0.295, 0, angle)
        base = 0.045
        far.append(block("obelisk base", (x - 0.015, base - 0.01, z - 0.015), (x + 0.015, base + 0.02, z + 0.015), stone, turn=-angle))
        far.append(rings("obelisk", [(0.011, base + 0.02), (0.008, base + 0.13)], 4, slate, centre=(x, z), twist=-angle + math.pi / 4))
        far.append(rings("obelisk tip", [(0.008, base + 0.13), (0.0, base + 0.15)], 4, moonsalt, centre=(x, z), twist=-angle + math.pi / 4))
    if level >= 3:
        for side, angle in COURT_FIRES.items():
            x, y, z = on_ring(0.293, TOP, angle)
            far.append(rings("court brazier", [(0.012, 0.045), (0.008, TOP + 0.05), (0.02, TOP + 0.06), (0.022, TOP + 0.07)], 6, bronze,
                             centre=(x, z)))
    if level >= 5:
        for x in (-0.06, 0.06):
            far.append(block("gate post", (x - 0.011, 0.03, 0.283), (x + 0.011, 0.19, 0.307), white))
            far.append(rod("gate banner pole", (x, 0.19, 0.295), (x, 0.255, 0.295), 0.003, gold, sides=4))
            # Flown out to either side, within the slot.
            flag(tagged("gate banner %s" % ("L" if x < 0 else "R"), ["5"]), (x, 0.25, 0.295), 0.03, 0.06, banner,
                 turn=math.pi if x < 0 else 0.0, tail=True)
        for index in range(5):
            angle = math.pi * index / 4
            voussoir = block("gate voussoir", (-0.009, -0.008, -0.012), (0.009, 0.008, 0.012), moonsalt if index == 2 else white)
            far.append(posed(voussoir, (0.06 * math.cos(angle), 0.19 + 0.035 * math.sin(angle), 0.295), (0, 0, 1), angle - math.pi / 2))
    return far


def court_fires():
    """The court braziers' cold fires of moonsalt, each its own part."""
    for side, angle in COURT_FIRES.items():
        x, y, z = on_ring(0.293, TOP + 0.067, angle)
        flame = rings("court flame", [(0.016, y), (0.009, y + 0.02), (0.0, y + 0.035)], 6, moonglow, centre=(x, z))
        moving("court flame " + side, LIT_COURT, "court fire %s@%s" % (side, ",".join(map(str, LIT_COURT))), [flame])


# MARK: The levels

for level in LEVELS:
    far, fine = [], []
    if level == 1:
        laid, close = foundations()
        far += laid
        fine += close
    else:
        far += drum(level)
        fine += door_work(roundels=level < 4)
    if level >= 3:
        more, close = stage_three()
        far += more
        fine += close
    if level >= 4:
        far += stage_four() + wonder()
    if level <= 4:
        far += crane(level)
    if level == 5:
        far += crowned()
    far += court(level)
    piece("moonspire", [level], far, fine)

door_fires()
court_fires()

# The crane slewing and its treadwheel turning until the spire is crowned;
# then the crown turning one way and its halo the other; the fires
# flickering.
idle(rig,
     turns=[("crane@%d" % level, (0, 1, 0), lambda u: 0.9 * swing(u)) for level in CRANES] +
           [("treadwheel@%d" % level, (1, 0, 0), wheel_turns(1)) for level in CRANES] +
           [("crown@5", (0, 1, 0), wheel_turns(1)), ("halo@5", (0, 1, 0), wheel_turns(-1))],
     stretches=[("door fire %s@%s" % (side, ",".join(map(str, LIT_DOOR))), leaping) for side in DOOR_FIRES] +
               [("court fire %s@%s" % (side, ",".join(map(str, LIT_COURT))), leaping) for side in COURT_FIRES])

finish_building(out_path("Art/models/moonspire.glb"), [str(level) for level in LEVELS])
