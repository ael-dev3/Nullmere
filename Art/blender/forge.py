"""The Forge, where the House's smiths work its makings into gear, its five
levels the tiers of one file, each within a work's slot and facing +z, its
chimney always where Works.forgeChimney says the smoke rises:
1. a bloomery of clay smoking in a ring of stones, a smith's anvil on its
   stump under a thatched lean-to, bellows heaving, charcoal heaped;
2. a timber smithy with a stone chimney, its hearth glowing through the
   open front, a quench barrel, a hitching rail with shoes hung on it;
3. a smithy of dark stone, a trip hammer beating at the anvil, the
   bloomery rebuilt in stone, a rack of blades by the door, an ore cart;
4. an armourer's shop beside it, a stand of mail, a grindstone turning,
   bar iron stacked in the yard;
5. a great forge hall of three hearths under its tall chimney flying the
   House's banner, a furnace of moonglass burning cold and bright.
Close: cinders trodden into the yard, the bloomery's courses, the lean-to's
battens, the hammer and tongs by the anvil, the hoops, the horseshoes, the
lintels over the hearths and the smithy's frame.
The bellows' lever rocks or the hammer beats, the hearths flicker and the
grindstone turns.

    python Art/blender/forge.py Art/models/forge.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

ground_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
stone = material("plain_stone", (0.52, 0.51, 0.49))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
rough = material("plain_stone_rock", (0.4, 0.4, 0.42))
clay = material("plain_earth", (0.24, 0.21, 0.18))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
straw = material("plain_thatch_straw", (0.62, 0.55, 0.36))
slate = material("plain_slate", (0.23, 0.24, 0.28))
linen = material("plain_linen", (0.7, 0.67, 0.6))
madder = material("plain_madder", (0.44, 0.24, 0.19))
soot = material("plain_soot", (0.11, 0.1, 0.1))
leather = material("plain_leather_dark", (0.22, 0.16, 0.12))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.35, metallic=0.8)
mail_metal = material("metal_mail", (0.47, 0.49, 0.52), roughness=0.5, metallic=0.7)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.35, metallic=0.8)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))
fire = material("glow_fire", (1.0, 0.68, 0.32))
moonsalt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)

CHIMNEYS = {1: 0.3, 2: 0.36, 3: 0.42, 4: 0.5, 5: 0.56}


def flue(level):
    """The top of a level's chimney, where its smoke rises
    (Works.forgeChimney)."""
    return (-0.13, CHIMNEYS[level], -0.12)


# Each level's moving parts: what glows, what rocks or beats, what turns.
BLOOMS = {1: (-0.13, 0.03, -0.07), 3: (-0.2, 0.03, 0.19), 4: (-0.18, 0.03, 0.17)}
BELLOWS = {1: (-0.25, 0.12, 0.0), 2: (-0.26, 0.12, 0.06)}
HAMMERS = {3: (0.2, 0.13, 0.1), 4: (0.09, 0.13, 0.1), 5: (0.07, 0.13, 0.11)}
GRINDSTONES = {4: (0.15, 0.06, 0.11), 5: (0.16, 0.06, 0.12)}
HEARTHS = {2: (-0.13, 0.05, -0.07), 3: (-0.13, 0.05, -0.07), 4: (-0.13, 0.05, -0.07), 5: (-0.06, 0.05, -0.06)}

parts = [("bloom@%d" % level, at_point, (0, 1, 0)) for level, at_point in BLOOMS.items()]
parts += [("hearth@%d" % level, at_point, (0, 1, 0)) for level, at_point in HEARTHS.items()]
parts += [("bellows@%d" % level, at_point, (0, 0, 1)) for level, at_point in BELLOWS.items()]
parts += [("hammer@%d" % level, at_point, (0, 0, -1)) for level, at_point in HAMMERS.items()]
parts += [("grindstone@%d" % level, at_point, (0, 0, 1)) for level, at_point in GRINDSTONES.items()]
rig = work_rig(parts)
ground(pad(tagged("pad", []), 0.31, ground_stone, sides=12), rig)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


def moving(name, level, bone, pieces):
    """Pieces carried by one of a level's moving parts."""
    obj = join(tagged(name, level_tags([level])), pieces)
    on(obj, rig, "%s@%d" % (bone, level))


def profile_radius(profile, y):
    """A turned body's radius at a height, between the rings of its
    profile."""
    for (r0, y0), (r1, y1) in zip(profile, profile[1:]):
        if y0 <= y <= y1 and y1 > y0:
            return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
    return profile[-1][0]


# MARK: The forge's pieces

def cinders():
    """Cinders and slag trodden into the yard."""
    out = []
    for index in range(9):
        x, _, z = on_ring(0.12 + 0.015 * (index % 4), 0, index * 2.4)
        out.append(rock("cinder", (x, 0.0, z), (0.012, 0.005, 0.01), 300 + index, slate if index % 3 == 0 else soot, bands=2,
                        sides=4, jitter=0.35))
    return out


def bloomery(level, at_point, height, stone_built):
    """A bloomery: a shaft of clay, or of coursed stone, in a ring of
    stones, hollow at its top, its mouth glowing at the foot; the glow is
    the level's bloom."""
    x0, _, z0 = at_point
    shell = [(0.05, 0.0), (0.052, 0.04), (0.042, height * 0.5), (0.03, height * 0.9), (0.032, height), (0.024, height),
             (0.022, height - 0.03)]
    far = [rings("bloomery", shell, 9, ground_stone if stone_built else clay, centre=(x0, z0))]
    for index in range(8):
        fx, _, fz = on_ring(0.065, 0, index * math.pi / 4)
        far.append(rock("hearth stone", (x0 + fx, 0.0, z0 + fz), (0.018, 0.014, 0.016), 320 + index, stone, bands=2, sides=5,
                        jitter=0.3))
    fine = []
    if stone_built:
        y = 0.04
        while y < height - 0.01:
            r = profile_radius(shell, y)
            fine.append(rings("course", [(r - 0.001, y), (r + 0.002, y + 0.003), (r - 0.001, y + 0.006)], 9, stone, centre=(x0, z0),
                              caps=(False, False)))
            y += 0.035
    glowing = [block("mouth", (x0 - 0.015, 0.017, z0 + 0.043), (x0 + 0.015, 0.043, z0 + 0.053), fire),
               rings("flame", [(0.02, height - 0.03), (0.012, height), (0.0, height + 0.012)], 6, fire, centre=(x0, z0))]
    moving("bloom glow", level, "bloom", glowing)
    return far, fine


def lean_to(at_point, roof):
    """A lean-to on four posts, its roof falling toward the yard."""
    x0, _, z0 = at_point
    high, low = 0.17, 0.12
    far = [rod("post", (x0 + x, 0, z0 + z), (x0 + x, high if z < 0 else low, z0 + z), 0.007, dark, sides=5)
           for x, z in ((-0.09, -0.08), (0.09, -0.08), (-0.09, 0.08), (0.09, 0.08))]
    # Its slope rises from the front to the back: across it and up it.
    n = Vector((0.0, 0.2, high - low)).normalized()
    far.append(slab("roof", [(x0 - 0.11, low, z0 + 0.1), (x0 + 0.11, low, z0 + 0.1), (x0 + 0.11, high, z0 - 0.1), (x0 - 0.11, high, z0 - 0.1)],
                    roof, 0.012, normal=tuple(n)))
    far.append(lath("purlin", (x0 - 0.1, high - 0.008, z0 - 0.08), (x0 + 0.1, high - 0.008, z0 - 0.08), 0.008, 0.008, dark))
    far.append(lath("purlin", (x0 - 0.1, low - 0.004, z0 + 0.08), (x0 + 0.1, low - 0.004, z0 + 0.08), 0.008, 0.008, dark))
    fine = []
    x = -0.1
    while x <= 0.1001:
        lift = n * 0.009
        fine.append(lath("batten", (x0 + x + lift.x, low + lift.y, z0 + 0.1 + lift.z), (x0 + x + lift.x, high + lift.y, z0 - 0.1 + lift.z),
                         0.006, 0.004, straw))
        x += 0.04
    return far, fine


def anvil(at_point):
    """An anvil on its stump, a hammer and tongs laid by it."""
    x0, _, z0 = at_point
    far = [rings("stump", [(0.028, 0.0), (0.03, 0.045), (0.026, 0.05)], 8, dark, centre=(x0, z0)),
           block("anvil waist", (x0 - 0.011, 0.05, z0 - 0.01), (x0 + 0.011, 0.066, z0 + 0.01), iron),
           block("anvil face", (x0 - 0.032, 0.065, z0 - 0.014), (x0 + 0.032, 0.079, z0 + 0.014), iron)]
    horn = rings("anvil horn", [(0.01, 0.0), (0.0, 0.028)], 4, iron, twist=math.pi / 4)
    far.append(posed(horn, (x0 - 0.032, 0.074, z0), (0, 0, 1), math.pi / 2))
    fine = [block("hammer head", (x0 + 0.006, 0.079, z0), (x0 + 0.018, 0.087, z0 + 0.008), steel),
            lath("hammer haft", (x0 + 0.012, 0.083, z0 + 0.008), (x0 + 0.012, 0.083, z0 + 0.04), 0.004, 0.004, timber),
            lath("tongs", (x0 + 0.032, 0.0, z0 + 0.03), (x0 + 0.026, 0.05, z0 + 0.02), 0.003, 0.003, iron),
            lath("tongs", (x0 + 0.038, 0.0, z0 + 0.026), (x0 + 0.026, 0.05, z0 + 0.02), 0.003, 0.003, iron)]
    return far, fine


def bellows(level, at_point):
    """Bellows on a frame, two boards and the leather between them, the
    smith's helper's lever above them rocking on its post."""
    x0, _, z0 = at_point
    far = [block("bellows frame", (x0 - 0.03, 0.0, z0 - 0.025), (x0 + 0.03, 0.04, z0 + 0.025), dark),
           block("bellows board", (x0 - 0.035, 0.04, z0 - 0.03), (x0 + 0.035, 0.044, z0 + 0.03), timber),
           slab("bellows leather", [(x0 - 0.035, 0.044, z0), (x0 + 0.035, 0.046, z0), (x0 + 0.035, 0.05, z0), (x0 - 0.035, 0.066, z0)], leather,
                0.056, normal=(0, 0, 1)),
           lath("bellows lid", (x0 - 0.036, 0.068, z0), (x0 + 0.036, 0.052, z0), 0.062, 0.004, timber)]
    nozzle = rings("nozzle", [(0.008, 0.0), (0.0, 0.04)], 4, iron, twist=math.pi / 4)
    far.append(posed(nozzle, (x0 + 0.035, 0.05, z0), (0, 0, 1), -math.pi / 2))
    far.append(rod("lever post", (x0 - 0.04, 0, z0), (x0 - 0.04, 0.12, z0), 0.005, dark, sides=5))
    px, py, pz = BELLOWS[level]
    lever = [lath("lever", (px - 0.03, py, pz), (px + 0.05, py - 0.04, pz), 0.006, 0.006, timber),
             rod("lever cord", (px + 0.04, py - 0.035, pz), (x0, 0.068, z0), 0.002, linen, sides=3)]
    moving("bellows lever", level, "bellows", lever)
    return far


def chimney(level, stone_built):
    """A chimney stack up to the flue, coursed and sooted."""
    fx, fy, fz = flue(level)
    far = [block("chimney", (fx - 0.032, 0.0, fz - 0.032), (fx + 0.032, fy, fz + 0.032), ground_stone)]
    fine = []
    y = 0.16
    while y < fy - 0.01:
        fine.append(block("chimney course", (fx - 0.035, y, fz - 0.035), (fx + 0.035, y + 0.012, fz + 0.035), pale_stone))
        y += 0.07
    fine.append(block("flue", (fx - 0.022, fy, fz - 0.022), (fx + 0.022, fy + 0.003, fz + 0.022), soot))
    return far, fine


def smithy(level, stone_built, width):
    """A smithy of timber or dark stone, its front open on the glowing
    hearth beside the chimney, its door and a window lit."""
    fx, _, _ = flue(level)
    x0, z0 = fx + width / 2 - 0.04, -0.13
    height = 0.14 if stone_built else 0.12
    body, close = hall("smithy", width, 0.13, height, ground_stone if stone_built else timber, slate, dark, pitch=0.6,
                       footing=stone if stone_built else ground_stone)
    for obj in body + close:
        placed(obj, (x0, 0, z0))
    stack, stack_close = chimney(level, stone_built)
    front = z0 + 0.065
    far = list(body) + stack + [
        block("hearth mouth", (fx - 0.04, 0.04, front), (fx + 0.04, 0.11, front + 0.004), soot),
        block("door", (x0 + width / 2 - 0.0675, 0.04, front - 0.004), (x0 + width / 2 - 0.0325, 0.108, front + 0.006), dark),
        lit("window", (x0, 0.08, front + 0.001), 0.022, 0.028, 0.0, window),
    ]
    fine = list(close) + stack_close + [
        block("hearth lintel", (fx - 0.05, 0.11, front), (fx + 0.05, 0.12, front + 0.012), pale_stone if stone_built else dark)]
    if not stone_built:
        x = x0 - width / 2 + 0.02
        while x < x0 + width / 2:
            if abs(x - fx) > 0.05:
                fine.append(lath("stud", (x, 0.0, front + 0.002), (x, height, front + 0.002), 0.006, 0.004, dark))
            x += 0.05
    hearth = [block("hearth glow", (fx - 0.03, 0.045, front - 0.003), (fx + 0.03, 0.065, front + 0.005), fire)]
    moving("hearth fire", level, "hearth", hearth)
    return far, fine


def trip_hammer(level, at_point):
    """A trip hammer: its helve on a post, beating the anvil."""
    x0, _, z0 = at_point
    far, fine = anvil(at_point)
    px, py, pz = HAMMERS[level]
    far.append(rod("hammer post", (px, 0, pz), (px, py, pz), 0.011, timber, sides=6))
    far.append(rod("hammer brace", (px - 0.02, 0, pz + 0.03), (px, py - 0.02, pz), 0.005, dark, sides=4))
    helve = [lath("helve", (px + 0.03, py + 0.01, pz), (x0, 0.125, z0), 0.015, 0.012, timber),
             block("hammer", (x0 - 0.015, 0.094, z0 - 0.014), (x0 + 0.015, 0.122, z0 + 0.014), iron, chamfer=0.002),
             block("hammer pin", (px - 0.007, py - 0.011, pz - 0.015), (px + 0.007, py + 0.011, pz + 0.015), iron)]
    moving("trip hammer", level, "hammer", helve)
    return far, fine


def barrel(at_point):
    """A quench barrel, hooped, its water dark within."""
    x0, _, z0 = at_point
    far = [rings("barrel", [(0.024, 0.0), (0.028, 0.03), (0.024, 0.06), (0.02, 0.058)], 8, timber, centre=(x0, z0))]
    fine = []
    for y in (0.008, 0.046):
        r = profile_radius([(0.024, 0.0), (0.028, 0.03), (0.024, 0.06)], y + 0.003)
        fine.append(rings("hoop", [(r - 0.0005, y), (r + 0.0015, y + 0.003), (r - 0.0005, y + 0.006)], 8, iron, centre=(x0, z0),
                          caps=(False, False)))
    return far, fine


def rail(at_point):
    """A hitching rail with horseshoes hung on it."""
    x0, _, z0 = at_point
    far = [rod("rail post", (x0 + x, 0, z0), (x0 + x, 0.07, z0), 0.005, dark, sides=5) for x in (-0.06, 0.06)]
    far.append(lath("rail", (x0 - 0.07, 0.066, z0), (x0 + 0.07, 0.066, z0), 0.008, 0.008, timber))
    fine = []
    for x in (-0.03, -0.005, 0.03):
        fine += [block("shoe", (x0 + x - 0.0065, 0.046, z0 + 0.0045), (x0 + x - 0.0035, 0.062, z0 + 0.0075), iron),
                 block("shoe", (x0 + x + 0.0035, 0.046, z0 + 0.0045), (x0 + x + 0.0065, 0.062, z0 + 0.0075), iron),
                 block("shoe", (x0 + x - 0.0065, 0.0445, z0 + 0.0045), (x0 + x + 0.0065, 0.0475, z0 + 0.0075), iron)]
    return far, fine


def charcoal(at_point):
    """A heap of charcoal and its basket."""
    x0, _, z0 = at_point
    return [rock("charcoal", (x0, 0.0, z0), (0.05, 0.03, 0.04), 341, soot, bands=3, sides=7, jitter=0.3),
            rings("basket", [(0.016, 0.0), (0.022, 0.03), (0.0, 0.031)], 7, thatch, centre=(x0 - 0.05, z0 + 0.02))]


def bars(at_point, count):
    """Bar iron stacked crosswise."""
    x0, _, z0 = at_point
    out = []
    for index in range(count):
        layer, cross = index // 3, (index // 3) % 2 == 1
        offset = (index % 3 - 1) * 0.014
        y = 0.004 + layer * 0.008
        if cross:
            low, high = (x0 + offset - 0.0035, y - 0.0035, z0 - 0.035), (x0 + offset + 0.0035, y + 0.0035, z0 + 0.035)
        else:
            low, high = (x0 - 0.035, y - 0.0035, z0 + offset - 0.0035), (x0 + 0.035, y + 0.0035, z0 + offset + 0.0035)
        out.append(block("bar", low, high, iron if index % 2 == 0 else mail_metal))
    return out


def blades(at_point):
    """A rack of blades, hilted in gold."""
    x0, _, z0 = at_point
    out = [rod("rack post", (x0 + x, 0, z0), (x0 + x, 0.11, z0), 0.005, dark, sides=5) for x in (-0.045, 0.045)]
    out.append(lath("rack", (x0 - 0.05, 0.1, z0), (x0 + 0.05, 0.1, z0), 0.008, 0.008, timber))
    for index in range(4):
        x = x0 - 0.03 + index * 0.02
        blade = slab("blade", [(x - 0.003, 0.09, z0 + 0.006), (x + 0.003, 0.09, z0 + 0.006), (x + 0.003, 0.022, z0 + 0.006),
                               (x, 0.012, z0 + 0.006), (x - 0.003, 0.022, z0 + 0.006)], steel, 0.002, normal=(0, 0, 1))
        out += [blade, block("hilt", (x - 0.008, 0.09, z0 + 0.0035), (x + 0.008, 0.094, z0 + 0.0085), gold),
                rod("grip", (x, 0.094, z0 + 0.006), (x, 0.108, z0 + 0.006), 0.0025, leather, sides=4)]
    return out


def armoury(at_point):
    """An armourer's shop of stone, its shields hung on its front."""
    x0, _, z0 = at_point
    body, close = hall("armoury", 0.14, 0.12, 0.12, stone, slate, dark, pitch=0.65, footing=ground_stone)
    for obj in body + close:
        placed(obj, at_point)
    far = list(body) + [block("door", (x0 - 0.045, 0.04, z0 + 0.058), (x0 - 0.015, 0.105, z0 + 0.066), dark)]
    for x in (0.02, 0.05):
        shield = rings("shield", [(0.013, -0.002), (0.013, 0.002)], 8, madder)
        far.append(posed(shield, (x0 + x, 0.075, z0 + 0.064), (1, 0, 0), math.pi / 2))
        far.append(rings("boss", [(0.0, 0.0), (0.004, 0.0015), (0.0, 0.003)], 5, iron))
        posed(far[-1], (x0 + x, 0.075, z0 + 0.066), (1, 0, 0), math.pi / 2)
    return far, list(close)


def grindstone(level, at_point):
    """A grindstone turning in its frame on an axle across it, its crank at
    the side."""
    x0, _, z0 = at_point
    hx, hy, hz = GRINDSTONES[level]
    far = [rod("grindstone post", (x0, 0, z0 + z), (hx, hy + 0.006, hz + z), 0.006, dark, sides=5) for z in (-0.02, 0.02)]
    far.append(block("grindstone trough", (x0 - 0.04, 0.0, z0 - 0.025), (x0 + 0.04, 0.024, z0 + 0.025), timber))
    stone_wheel = rings("grindstone", [(0.0, -0.009), (0.042, -0.009), (0.042, 0.009), (0.0, 0.009)], 12, stone)
    wheel_parts = [posed(stone_wheel, (hx, hy, hz), (1, 0, 0), math.pi / 2),
                   rod("axle", (hx, hy, hz - 0.024), (hx, hy, hz + 0.024), 0.003, iron, sides=4),
                   lath("crank", (hx, hy, hz + 0.024), (hx + 0.03, hy, hz + 0.026), 0.005, 0.005, iron),
                   rod("crank handle", (hx + 0.03, hy, hz + 0.026), (hx + 0.03, hy, hz + 0.04), 0.003, timber, sides=4)]
    moving("grindstone wheel", level, "grindstone", wheel_parts)
    return far


def mail(at_point):
    """A stand of mail with a helm on it."""
    x0, _, z0 = at_point
    return [rod("mail stand", (x0, 0, z0), (x0, 0.15, z0), 0.005, dark, sides=5),
            lath("mail arms", (x0 - 0.03, 0.13, z0), (x0 + 0.03, 0.13, z0), 0.006, 0.006, dark),
            rings("hauberk", [(0.03, 0.066), (0.028, 0.1), (0.024, 0.125), (0.012, 0.135)], 8, mail_metal, centre=(x0, z0), squash=0.5),
            rings("helm", [(0.0, 0.14), (0.016, 0.142), (0.017, 0.155), (0.011, 0.168), (0.0, 0.172)], 7, steel, centre=(x0, z0))]


def great_hall(level):
    """The great forge hall: a long hall of dark stone, buttressed, three
    hearth mouths glowing in its front and the tall chimney at its end."""
    x0, z0 = -0.06, -0.13
    body, close = hall("forge hall", 0.3, 0.14, 0.17, ground_stone, slate, dark, pitch=0.6, footing=stone)
    for obj in body + close:
        placed(obj, (x0, 0, z0))
    stack, stack_close = chimney(level, True)
    front = z0 + 0.07
    far = list(body) + stack
    for x in (-0.135, -0.045, 0.045, 0.135):
        far.append(block("buttress", (x0 + x - 0.008, -0.02, front - 0.002), (x0 + x + 0.008, 0.13, front + 0.016), stone))
    glowing = []
    fine = list(close) + stack_close
    for x in (-0.1, 0.0, 0.1):
        far.append(block("hearth mouth", (x0 + x - 0.03, 0.04, front), (x0 + x + 0.03, 0.12, front + 0.004), soot))
        glowing.append(block("hearth glow", (x0 + x - 0.0225, 0.045, front - 0.003), (x0 + x + 0.0225, 0.065, front + 0.006), fire))
        fine.append(block("hearth lintel", (x0 + x - 0.037, 0.12, front), (x0 + x + 0.037, 0.132, front + 0.01), pale_stone))
    x = -0.13
    while x <= 0.0801:
        far.append(lit("window", (x0 + x + 0.03, 0.15, front + 0.001), 0.014, 0.02, 0.0, window))
        x += 0.06
    moving("hearth fires", level, "hearth", glowing)
    return far, fine


def furnace(at_point):
    """A furnace of moonglass burning cold and bright on its stone footing."""
    x0, _, z0 = at_point
    return [rings("furnace footing", [(0.05, 0.0), (0.05, 0.02), (0.04, 0.025)], 8, stone, centre=(x0, z0)),
            rings("moonglass", [(0.035, 0.025), (0.04, 0.075), (0.02, 0.125), (0.0, 0.145)], 6, moonsalt, centre=(x0, z0))]


def ore_cart(at_point):
    """A cart of ore brought up from the diggings, its shafts down."""
    pieces = [block("cart bed", (-0.045, 0.025, -0.03), (0.045, 0.06, 0.03), pale)]
    for z in (-0.034, 0.034):
        # A wheel of planks on the axle across the cart.
        disc = rings("cart wheel", [(0.0, -0.003), (0.026, -0.003), (0.026, 0.003), (0.0, 0.003)], 8, timber)
        pieces.append(posed(disc, (0.0, 0.026, z), (1, 0, 0), math.pi / 2))
        pieces.append(rod("cart shaft", (0.045, 0.04, z * 0.7), (0.11, 0.0, z * 0.6), 0.003, dark, sides=3))
    pieces.append(rod("cart axle", (0.0, 0.026, -0.036), (0.0, 0.026, 0.036), 0.003, iron, sides=4))
    for index in range(5):
        pieces.append(rock("ore", ((index % 3 - 1) * 0.026, 0.066, (index // 3) * 0.022 - 0.01), (0.02, 0.014, 0.018), 360 + index,
                           rough if index % 2 == 0 else madder, bands=2, sides=5, jitter=0.35))
    for obj in pieces:
        placed(obj, at_point, 0.5)
    return pieces


def woodpile(at_point):
    """Cut wood stacked for the hearths, the axe in the block beside it."""
    x0, _, z0 = at_point
    far = []
    for row in range(3):
        for index in range(4 - row):
            z = z0 - 0.03 + index * 0.02 + row * 0.01
            y = 0.012 + row * 0.018
            far.append(log("log", (x0 - 0.04, y, z), (x0 + 0.04, y, z), 0.009))
    fine = [rings("block", [(0.016, 0.0), (0.016, 0.03)], 6, timber, centre=(x0 + 0.06, z0 + 0.03)),
            lath("axe haft", (x0 + 0.06, 0.03, z0 + 0.03), (x0 + 0.08, 0.06, z0 + 0.04), 0.004, 0.004, pale),
            block("axe head", (x0 + 0.054, 0.027, z0 + 0.026), (x0 + 0.066, 0.036, z0 + 0.034), iron, turn=0.46)]
    return far, fine


def boundary(courses, count=12):
    """A low wall of field stones along the front of the yard, laid along
    its arc, course on course."""
    stones = []
    for index in range(count):
        for course in range(courses):
            angle = math.pi * (1.08 + 0.84 * index / (count - 1)) + (0.5 * 0.84 * math.pi / count if course % 2 else 0.0)
            x, y, z = on_ring(0.295, 0.012 + course * 0.02, angle)
            stones.append(block("field stone", (x - 0.025, y - 0.0095, z - 0.013), (x + 0.025, y + 0.0095, z + 0.013),
                                (stone, pale_stone, rough)[(index + course) % 3], turn=-angle - math.pi / 2))
    return stones


# MARK: The levels

def level_one():
    far, fine = bloomery(1, (-0.13, 0, -0.12), CHIMNEYS[1], False)
    roof, roof_close = lean_to((0.09, 0, 0.02), thatch)
    anvil_far, anvil_close = anvil((0.09, 0, 0.04))
    far += roof + anvil_far + bellows(1, (-0.21, 0, 0.0)) + charcoal((0.2, 0, 0.17)) + bars((-0.06, 0, 0.18), 4)
    piece("forge", [1], far, fine + roof_close + anvil_close)


def level_two():
    far, fine = smithy(2, False, 0.3)
    anvil_far, anvil_close = anvil((0.02, 0, 0.1))
    tub, tub_close = barrel((0.12, 0, 0.08))
    hitch, hitch_close = rail((0.12, 0, 0.21))
    far += anvil_far + tub + hitch + bellows(2, (-0.22, 0, 0.06)) + charcoal((-0.17, 0, 0.19)) + boundary(1)
    piece("forge", [2], far, fine + anvil_close + tub_close + hitch_close)


def level_three():
    far, fine = smithy(3, True, 0.3)
    hammer_far, hammer_close = trip_hammer(3, (0.05, 0, 0.1))
    furnace_far, furnace_close = bloomery(3, (-0.2, 0, 0.14), 0.16, True)
    tub, tub_close = barrel((0.19, 0, 0.13))
    hitch, hitch_close = rail((0.02, 0, 0.24))
    far += hammer_far + furnace_far + blades((0.21, 0, -0.03)) + tub + hitch + ore_cart((-0.08, 0, 0.22)) + boundary(2)
    piece("forge", [3], far, fine + hammer_close + furnace_close + tub_close + hitch_close)


def level_four():
    far, fine = smithy(4, True, 0.24)
    shop, shop_close = armoury((0.17, 0, -0.1))
    hammer_far, hammer_close = trip_hammer(4, (-0.06, 0, 0.1))
    furnace_far, furnace_close = bloomery(4, (-0.18, 0, 0.12), 0.16, True)
    wood, wood_close = woodpile((-0.26, 0, -0.02))
    far += shop + hammer_far + furnace_far + grindstone(4, (0.15, 0, 0.11)) + mail((0.24, 0, 0.06)) + bars((0.06, 0, 0.22), 6) + \
        ore_cart((0.18, 0, 0.0)) + wood + boundary(3)
    piece("forge", [4], far, fine + shop_close + hammer_close + furnace_close + wood_close)


def level_five():
    far, fine = great_hall(5)
    shop, shop_close = armoury((0.18, 0, -0.1))
    hammer_far, hammer_close = trip_hammer(5, (-0.08, 0, 0.11))
    tub, tub_close = barrel((0.1, 0, 0.24))
    wood, wood_close = woodpile((-0.26, 0, -0.02))
    fx, fy, fz = flue(5)
    far += shop + hammer_far + grindstone(5, (0.16, 0, 0.12)) + furnace((0.04, 0, 0.2)) + tub + charcoal((-0.06, 0, 0.25)) + \
        mail((0.25, 0, 0.07)) + bars((-0.2, 0, 0.2), 6) + ore_cart((0.18, 0, 0.0)) + wood + boundary(3)
    far.append(rod("banner pole", (fx + 0.04, fy - 0.1, fz), (fx + 0.04, fy + 0.1, fz), 0.005, dark, sides=5))
    flag(tagged("banner", ["5"]), (fx + 0.04, fy + 0.095, fz), 0.1, 0.07, banner, tail=True)
    piece("forge", [5], far, fine + shop_close + hammer_close + tub_close + wood_close)


level_one()
level_two()
level_three()
level_four()
level_five()
join("cinders!fine", cinders())

# The bellows' lever rocking, the hammer beating, the hearths and blooms
# flickering and the grindstone turning.
idle(rig,
     turns=[("bellows@%d" % level, (0, 0, 1), lambda u: 0.25 * swing(u)) for level in BELLOWS] +
           [("hammer@%d" % level, (0, 0, -1), lambda u: 0.3 * swing(u)) for level in HAMMERS] +
           [("grindstone@%d" % level, (0, 0, 1), wheel_turns(2)) for level in GRINDSTONES],
     stretches=[("bloom@%d" % level, leaping) for level in BLOOMS] + [("hearth@%d" % level, leaping) for level in HEARTHS])

finish_building(out_path("Art/models/forge.glb"), [str(level) for level in LEVELS])
