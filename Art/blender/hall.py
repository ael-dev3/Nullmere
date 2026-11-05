"""An alliance's hall, made whole: a great timbered hall on a platform of
dressed stone, its roof in the alliance's colour with carved horns crossed
at its gables and a louvre on its ridge; a round tower behind it under a
cone in the alliance's colour, flying the alliance's great banner; banners
hanging from crossbars at the platform's corners, bollards at its corners
and braziers burning at its door. It faces +z, its platform a hexagon with
flats to +z and -z, and fills the heart of its hex.
Close: a crenellated parapet round the platform, open at the steps; iron
bands and a ring on the great door, lanterns under the porch; a rack of
spears with shields in the alliance's colour, the alliance's stores
stacked and a well in its court; slits, a string course and a door on the
tower.

    python Art/blender/hall.py Art/models/hall.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import on_ring, posed, rock, tied_sack

reset()

ground_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
stone = material("plain_stone", (0.52, 0.51, 0.49))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
slate = material("plain_slate", (0.23, 0.24, 0.28))
linen = material("plain_linen", (0.7, 0.67, 0.6))
canvas = material("plain_canvas", (0.6, 0.55, 0.45))
soot = material("plain_soot", (0.11, 0.1, 0.1))
deep_water = material("plain_water_deep", (0.05, 0.07, 0.09))
roof_colour = material("house_roof", (0.6, 0.2, 0.2))
shield_colour = material("house_door", (0.6, 0.2, 0.2))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))
fire = material("glow_fire", (1.0, 0.68, 0.32))

# The hall's measures, as Sources/NullmereModels/Halls.swift keeps them.
PLATFORM = 0.64
FLOOR = 0.07
FRONT, BACK, SIDE = 0.3, -0.24, 0.17
EAVES, RIDGE = 0.27, 0.47
TOWER = (0.0, -0.38)
TOWER_TOP = 0.8


def hall_body():
    """The platform and its steps, the hall's footing, its timbered walls and
    porch, its roof and louvre, the horns at its gables, its door, windows
    and the alliance's shields down its sides; the bollards and braziers."""
    far = [rings("platform", [(PLATFORM, -0.3), (PLATFORM, FLOOR - 0.025), (PLATFORM - 0.04, FLOOR - 0.02), (PLATFORM - 0.04, FLOOR)], 6,
                 ground_stone)]
    for index, z in enumerate((0.56, 0.6)):
        far.append(block("step", (-0.11, -0.3, z), (0.11, FLOOR - 0.03 - 0.025 * index, z + 0.06), stone))
    far.append(block("footing", (-SIDE - 0.012, FLOOR, BACK - 0.012), (SIDE + 0.012, FLOOR + 0.05, FRONT + 0.012), stone, chamfer=0.003))
    far.append(block("walls", (-SIDE, FLOOR + 0.05, BACK), (SIDE, EAVES, FRONT), timber))
    for x in (-SIDE, SIDE):
        for k in range(5):
            z = BACK + (FRONT - BACK) * k / 4
            far.append(block("post", (x - 0.014, FLOOR + 0.05, z - 0.014), (x + 0.014, EAVES, z + 0.014), dark))
    far.append(block("sill beam", (-SIDE - 0.006, EAVES - 0.016, FRONT - 0.006), (SIDE + 0.006, EAVES, FRONT + 0.008), dark))
    for x in (-0.08, 0.08):
        far.append(rod("porch post", (x, FLOOR, FRONT + 0.1), (x, EAVES - 0.01, FRONT + 0.1), 0.014, dark, sides=6))
    far.append(lath("porch beam", (-0.1, EAVES - 0.008, FRONT + 0.1), (0.1, EAVES - 0.008, FRONT + 0.1), 0.02, 0.016, dark))
    # The roof, steep and high, over the porch too, in the alliance's colour.
    far.append(gable_roof("roof", (0.0, (FRONT + BACK) / 2 + 0.03), 2 * SIDE, FRONT - BACK + 0.1, EAVES, RIDGE - EAVES, roof_colour,
                          overhang=0.035, along="z", thickness=0.02))
    far.append(block("ridge", (-0.01, RIDGE - 0.002, BACK - 0.05), (0.01, RIDGE + 0.016, FRONT + 0.11), dark))
    # The louvre on its ridge, where the smoke goes out.
    far.append(block("louvre", (-0.035, RIDGE - 0.005, -0.065), (0.035, RIDGE + 0.045, 0.025), slate))
    far.append(hip_roof("louvre roof", (0.0, -0.02), 0.1, 0.12, RIDGE + 0.045, 0.04, slate, thickness=0.006))
    # Carved horns crossed at each gable's peak.
    for z in (BACK - 0.05, FRONT + 0.1):
        for lean in (-1, 1):
            far.append(lath("gable horn", (-lean * 0.06, RIDGE - 0.07, z), (lean * 0.07, RIDGE + 0.09, z), 0.02, 0.016, dark))
    # The great door, lit windows down both sides and either side of the door.
    far.append(block("door", (-0.05, FLOOR + 0.05, FRONT - 0.004), (0.05, FLOOR + 0.175, FRONT + 0.012), dark))
    far.append(block("door frame", (-0.058, FLOOR + 0.05, FRONT - 0.002), (0.058, FLOOR + 0.185, FRONT + 0.006), timber))
    for z in (-0.12, 0.0, 0.12, 0.22):
        for out in (-1, 1):
            far.append(lit("window", (out * (SIDE + 0.002), 0.19, z), 0.035, 0.05, out * math.pi / 2, window))
    for x in (-0.11, 0.11):
        far.append(lit("window", (x, 0.19, FRONT + 0.002), 0.03, 0.05, 0.0, window))
    # The alliance's shields hung down both sides between the windows, each
    # with its boss of iron.
    for out in (-1, 1):
        for z in (-0.06, 0.06, 0.17):
            shield = rings("shield", [(0.0, -0.002), (0.03, 0.0), (0.03, 0.006), (0.0, 0.01)], 8, shield_colour)
            boss = rings("boss", [(0.0, 0.001), (0.009, 0.01), (0.0, 0.019)], 4, iron)
            for obj in (shield, boss):
                far.append(posed(obj, (out * (SIDE + 0.004), 0.165, z), (0, 0, 1), -out * math.pi / 2))
    # Bollards of stone at the platform's corners.
    for index in range(6):
        angle = index * math.pi / 3
        x, y, z = on_ring(PLATFORM - 0.05, FLOOR + 0.035, angle)
        far.append(block("bollard", (x - 0.025, FLOOR, z - 0.025), (x + 0.025, FLOOR + 0.07, z + 0.025), pale_stone, chamfer=0.004,
                         turn=-angle))
    # Braziers either side of the steps, burning.
    for x in (-0.17, 0.17):
        far.append(rod("brazier stem", (x, FLOOR - 0.02, 0.5), (x, FLOOR + 0.12, 0.5), 0.009, iron, sides=5))
        far.append(rings("brazier", [(0.0, FLOOR + 0.11), (0.04, FLOOR + 0.12), (0.045, FLOOR + 0.15)], 6, iron, caps=(True, False),
                         centre=(x, 0.5)))
        far.append(rings("brazier coals", [(0.038, FLOOR + 0.135), (0.0, FLOOR + 0.142)], 6, soot, centre=(x, 0.5)))
        far.append(rings("brazier fire", [(0.034, FLOOR + 0.14), (0.04, FLOOR + 0.168), (0.0, FLOOR + 0.22)], 5, fire, centre=(x, 0.5)))
    return far


def tower():
    """The round tower of stone behind the hall, crowned, under a cone in
    the alliance's colour, its windows lit and the great banner over it."""
    tx, tz = TOWER
    profile = [(0.12, FLOOR - 0.02), (0.11, TOWER_TOP - 0.04), (0.135, TOWER_TOP - 0.02), (0.135, TOWER_TOP + 0.04)]
    far = [rings("tower", profile, 8, stone, centre=(tx, tz))]
    for index in range(8):
        angle = 2 * math.pi * index / 8
        x, y, z = on_ring(0.128, TOWER_TOP + 0.04, angle, centre=TOWER)
        far.append(block("merlon", (x - 0.0225, y, z - 0.015), (x + 0.0225, y + 0.045, z + 0.015), pale_stone, turn=-angle - math.pi / 2))
    far.append(rings("tower cone", [(0.12, TOWER_TOP + 0.03), (0.0, TOWER_TOP + 0.34)], 8, roof_colour, centre=(tx, tz)))
    for angle in (-math.pi / 2, -math.pi / 6, -5 * math.pi / 6):
        far.append(lit("tower window", on_ring(0.112, 0.52, angle, centre=TOWER), 0.028, 0.06, angle + math.pi / 2, window))
    top = TOWER_TOP + 0.66
    far.append(rod("banner pole", (tx, TOWER_TOP + 0.3, tz), (tx, top, tz), 0.009, dark, sides=5))
    flag(tagged("great banner", []), (tx, top - 0.01, tz), 0.36, 0.22, banner, tail=True)
    return far


def corner_banners():
    """Banners hanging from crossbars at the platform's corners."""
    far = []
    for index, (cx, cz) in enumerate(((-0.44, 0.3), (0.44, 0.3), (-0.44, -0.3), (0.44, -0.3))):
        out = -1 if cx < 0 else 1
        far.append(rings("banner pole", [(0.011, FLOOR - 0.02), (0.008, 0.62)], 6, dark, centre=(cx, cz)))
        far.append(lath("crossbar", (cx - out * 0.01, 0.58, cz), (cx + out * 0.13, 0.58, cz), 0.012, 0.012, timber))
        far.append(rings("finial", [(0.016, 0.62), (0.0, 0.67)], 4, iron, centre=(cx, cz)))
        flag(tagged("corner banner %d" % index, []), (cx + out * 0.005, 0.575, cz), 0.12, 0.28, banner, turn=math.pi if out < 0 else 0.0,
             tail=True)
    return far


def near():
    """What is seen close: the parapet, the door's iron, the porch's lanterns,
    the spear rack, the stores, the well, the tower's door, slits and course."""
    fine = []
    # The parapet, a little inside the rim, open at the steps.
    rim, wall = 0.57, 0.045
    for index in range(6):
        a, b = on_ring(rim, FLOOR, index * math.pi / 3), on_ring(rim, FLOOR, (index + 1) * math.pi / 3)
        runs = [(a, (-0.22, FLOOR, a[2])), ((0.22, FLOOR, b[2]), b)] if index == 4 else [(a, b)]
        for start, end in runs:
            lift = wall / 2
            fine.append(lath("parapet", (start[0], start[1] + lift, start[2]), (end[0], end[1] + lift, end[2]), 0.024, wall, stone))
            length = math.dist((start[0], start[2]), (end[0], end[2]))
            count = max(1, round(length / 0.1))
            fine.append(merlons("parapet merlons", (start[0], FLOOR + wall, start[2]), (end[0], FLOOR + wall, end[2]), count,
                                (0.032, 0.024, 0.026), pale_stone))
    # The great door's iron bands and its ring.
    for y in (0.11, 0.16, 0.21):
        fine.append(block("door band", (-0.052, y - 0.004, FRONT + 0.012), (0.052, y + 0.004, FRONT + 0.015), iron))
    ring = rings("door ring", [(0.009, -0.002), (0.011, 0.0), (0.009, 0.002)], 6, iron, caps=(False, False))
    fine.append(posed(ring, (0.026, 0.15, FRONT + 0.016), (1, 0, 0), math.pi / 2))
    # Lanterns hung under the porch's eave.
    for x in (-0.12, 0.12):
        fine += [rod("lantern chain", (x, EAVES - 0.004, 0.37), (x, 0.235, 0.37), 0.0018, iron, sides=3),
                 block("lantern cap", (x - 0.013, 0.229, 0.357), (x + 0.013, 0.235, 0.383), iron),
                 block("lantern light", (x - 0.01, 0.199, 0.36), (x + 0.01, 0.229, 0.38), window),
                 block("lantern base", (x - 0.012, 0.1945, 0.358), (x + 0.012, 0.1995, 0.382), iron)]
    # A rack of spears in the court, shields in the alliance's colour at its foot.
    rx, ry, rz = -0.36, FLOOR, 0.12
    for x in (-0.07, 0.07):
        for z in (-0.025, 0.025):
            fine.append(rod("rack leg", (rx + x, ry, rz + z), (rx + x, ry + 0.13, rz), 0.005, dark, sides=3))
    fine.append(rod("rack bar", (rx - 0.08, ry + 0.125, rz), (rx + 0.08, ry + 0.125, rz), 0.005, timber, sides=4))
    for x in (-0.05, -0.017, 0.017, 0.05):
        foot, top = (rx + x, ry, rz + 0.05), (rx + x + 0.004, ry + 0.23, rz - 0.012)
        fine.append(rod("spear", foot, top, 0.0035, dark, sides=4))
        fine.append(spearhead(foot, top))
    for x in (-0.035, 0.035):
        shield = rings("rack shield", [(0.032, -0.004), (0.032, 0.003), (0.0, 0.007)], 8, shield_colour)
        boss = rings("rack boss", [(0.008, 0.006), (0.0, 0.014)], 5, iron)
        for obj in (shield, boss):
            fine.append(posed(obj, (rx + x, ry + 0.035, rz + 0.075), (1, 0, 0), 1.25))
    # The alliance's stores stacked on the other side.
    for (x, y, z), turn in (((0.32, FLOOR, 0.06), 0.2), ((0.385, FLOOR, 0.1), 1.0), ((0.35, FLOOR + 0.07, 0.08), 0.6)):
        fine.append(rings("barrel", [(0.026, y), (0.032, y + 0.035), (0.026, y + 0.07)], 7, pale, centre=(x, z), twist=turn))
        for h in (0.012, 0.058):
            fine.append(rings("barrel hoop", [(0.03, y + h - 0.004), (0.0315, y + h), (0.03, y + h + 0.004)], 7, iron, centre=(x, z),
                              twist=turn, caps=(False, False)))
    fine.append(block("crate", (0.31, FLOOR, -0.0775), (0.37, FLOOR + 0.05, -0.0225), pale, turn=-0.3))
    fine.append(block("crate", (0.375, FLOOR, -0.045), (0.425, FLOOR + 0.044, 0.005), timber, turn=0.2))
    fine.append(tied_sack("sack", (0.3, FLOOR, 0.16), 0.02, canvas))
    # A well at the back of the court.
    wx, wz = 0.3, -0.22
    fine += [rings("well", [(0.045, FLOOR), (0.045, FLOOR + 0.05), (0.036, FLOOR + 0.055), (0.036, FLOOR + 0.02)], 8, stone, centre=(wx, wz),
                   caps=(True, False)),
             rings("well water", [(0.036, FLOOR + 0.035), (0.0, FLOOR + 0.036)], 8, deep_water, centre=(wx, wz))]
    for x in (-0.05, 0.05):
        fine.append(rod("well post", (wx + x, FLOOR, wz), (wx + x, FLOOR + 0.15, wz), 0.005, dark, sides=4))
    fine += [rod("well axle", (wx - 0.06, FLOOR + 0.14, wz), (wx + 0.06, FLOOR + 0.14, wz), 0.006, timber, sides=5),
             rod("well rope", (wx, FLOOR + 0.14, wz), (wx, FLOOR + 0.08, wz), 0.0015, linen, sides=3),
             rings("bucket", [(0.0, FLOOR + 0.06), (0.014, FLOOR + 0.062), (0.016, FLOOR + 0.082)], 6, pale, centre=(wx, wz))]
    # The tower's door toward the court, its slits and a string course.
    tx, tz = TOWER
    profile = [(0.12, FLOOR - 0.02), (0.11, TOWER_TOP - 0.04)]

    def tower_wall(y):
        (r0, y0), (r1, y1) = profile
        return r0 + (r1 - r0) * (y - y0) / (y1 - y0)

    door_angle = -math.pi / 8  # as the game's ring counts round: toward the court, beside the hall
    dx, _, dz = on_ring(tower_wall(FLOOR + 0.055) + 0.002, 0, door_angle, centre=TOWER)
    door = block("tower door", (-0.025, FLOOR + 0.005, -0.004), (0.025, FLOOR + 0.105, 0.004), dark)
    fine.append(posed(door, (dx, 0.0, dz), (0, 1, 0), door_angle + math.pi / 2))
    for quarter in range(4):
        angle = door_angle + quarter * math.pi / 2
        sx, _, sz = on_ring(tower_wall(0.3) - 0.001, 0, angle, centre=TOWER)
        slit = block("tower slit", (-0.006, 0.275, -0.003), (0.006, 0.325, 0.003), soot)
        fine.append(posed(slit, (sx, 0.0, sz), (0, 1, 0), angle + math.pi / 2))
    r = tower_wall(0.42)
    fine.append(rings("string course", [(r, 0.41), (r + 0.006, 0.415), (r + 0.006, 0.425), (r, 0.43)], 8, pale_stone, centre=TOWER,
                      caps=(False, False)))
    return fine


def spearhead(foot, top):
    """A spear's iron head, a point on the shaft's line beyond its top."""
    d = (Vector(top) - Vector(foot)).normalized()
    up = Vector((0, 1, 0))
    head = rings("spearhead", [(0.008, 0.0), (0.0, 0.03)], 4, iron)
    return posed(head, top, tuple(up.cross(d).normalized()), up.angle(d))


join("hall", hall_body() + tower() + corner_banners())
join("hall close!fine", near())

finish_building(out_path("Art/models/hall.glb"), ["1"])
