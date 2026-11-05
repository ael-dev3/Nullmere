"""The walls that ring a hold, all five levels in one file, each its tier,
on the hexagon a hold's walls keep (corners 0.84 from its heart, the gate
in the side toward +z):
1. a palisade of sharpened stakes, lashed, a walkway on posts behind it,
   braced, its gate's leaves strapped in iron, two watch platforms under
   thatch at the far corners;
2. a low wall of dark stone, its corners on squat piers, its coping pale
   and its buttresses dark, its gate under a little gatehouse roofed in
   slate, a fire burning on each of its piers;
3. a crenellated wall, buttressed, square towers at its corners, the gate
   between two square towers under an arch;
4. higher, round towers at its corners under slate cones, the gate's
   towers round and roofed, a portcullis, the House's banners hung either
   side of the gate;
5. highest, the towers' cones in the House's colour, the House's banner
   flying over the gate.
At every level the gate's leaves stand open, strapped in iron, and
torches burn before it. Close: the lashings, arrow loops and the holes the
masons' scaffolds left, string courses, the wall-walk behind the merlons,
ivy by the gate, slits, courses and finials on the round towers.

    python Art/blender/walls.py Art/models/walls.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *

reset()
RADIUS = 0.84
GATE = 0.085
HEIGHT = {1: 0.2, 2: 0.17, 3: 0.22, 4: 0.27, 5: 0.32}


def thick(level):
    return 0.035 if level == 1 else 0.05 + 0.006 * level


def corner(index):
    angle = index * math.pi / 3
    return (RADIUS * math.cos(angle), 0.0, RADIUS * math.sin(angle))


GATE_Z = corner(1)[2]
# The runs of wall, corner to corner, the gate's side split by the gate.
RUNS = []
for index in range(6):
    a, c = corner(index), corner(index + 1)
    if index == 1:
        RUNS.append((a, (GATE, 0.0, a[2])))
        RUNS.append(((-GATE, 0.0, a[2]), c))
    else:
        RUNS.append((a, c))

stone = material("plain_stone", (0.52, 0.51, 0.49))
dark = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale = material("plain_stone_pale", (0.68, 0.67, 0.64))
patched = material("plain_stone_patched", (0.62, 0.61, 0.58))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
beam = material("plain_timber_dark", (0.19, 0.14, 0.11))
plank = material("plain_timber_pale", (0.45, 0.37, 0.28))
thatch = material("plain_thatch", (0.66, 0.55, 0.34))
rope = material("plain_rope", (0.23, 0.17, 0.12))
hole = material("plain_hole", (0.11, 0.10, 0.10))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
house = material("house_roof", (0.78, 0.78, 0.78))
banner = material("cloth_banner", (0.78, 0.78, 0.78))
fire = material("glow_fire", (1.0, 0.68, 0.32))
candle = material("glow_candle", (1.0, 0.8, 0.52))
ivy = material("foliage_ivy", (0.16, 0.24, 0.17))


def frame(a, c):
    """A run's direction along it and outward from the hold's heart."""
    dx, dz = c[0] - a[0], c[2] - a[2]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    nx, nz = uz, -ux
    if nx * (a[0] + c[0]) + nz * (a[2] + c[2]) < 0:
        nx, nz = -nx, -nz
    return (ux, uz), (nx, nz), length


def along(name, a, c, t0, t1, low, high, through, mat, out=0.0, chamfer=0.0):
    """A block laid along a run from a share `t0` of its length to `t1`,
    `through` thick about `out` beyond its line, from `low` up to `high`."""
    (ux, uz), (nx, nz), length = frame(a, c)
    p = (a[0] + (c[0] - a[0]) * t0, a[2] + (c[2] - a[2]) * t0)
    q = (a[0] + (c[0] - a[0]) * t1, a[2] + (c[2] - a[2]) * t1)
    near, far = out - through / 2, out + through / 2
    feet = [(p[0] + nx * near, p[1] + nz * near), (q[0] + nx * near, q[1] + nz * near), (q[0] + nx * far, q[1] + nz * far),
            (p[0] + nx * far, p[1] + nz * far)]

    def build(bm):
        v = [bm.verts.new(at(x, y, z)) for y in (low, high) for x, z in feet]
        for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            bm.faces.new([v[i] for i in f])
        if chamfer > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=chamfer * UNIT, segments=1, affect="EDGES", clamp_overlap=True)
    return mesh_object(name, build, mat)


def around(name, centre, radius, angle, low, high, wide, deep, mat):
    """A block on a ring of `radius` about `centre` (x, z), at `angle`,
    `wide` along the ring and `deep` across it, from `low` to `high`."""
    cx, cz = centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle)
    tx, tz, nx, nz = -math.sin(angle), math.cos(angle), math.cos(angle), math.sin(angle)
    feet = [(cx - tx * wide / 2 - nx * deep / 2, cz - tz * wide / 2 - nz * deep / 2), (cx + tx * wide / 2 - nx * deep / 2, cz + tz * wide / 2 - nz * deep / 2),
            (cx + tx * wide / 2 + nx * deep / 2, cz + tz * wide / 2 + nz * deep / 2), (cx - tx * wide / 2 + nx * deep / 2, cz - tz * wide / 2 + nz * deep / 2)]

    def build(bm):
        v = [bm.verts.new(at(x, y, z)) for y in (low, high) for x, z in feet]
        for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            bm.faces.new([v[i] for i in f])
    return mesh_object(name, build, mat)


def flat_ivy(name, a, c, t, out, height, seed, mat):
    """Ivy climbing a run's face about a share `t` along it: leaves strewn
    over a tongue of growth narrowing as it climbs."""
    (ux, uz), (nx, nz), length = frame(a, c)
    base = (a[0] + (c[0] - a[0]) * t + nx * out, a[2] + (c[2] - a[2]) * t + nz * out)
    leaves = []
    for i in range(16):
        u = math.sin(seed * 7.1 + i * 2.3) * 0.07 * (1 - i / 20)
        v = height * (i / 16)
        x, z = base[0] + ux * u, base[1] + uz * u
        leaves.append(along("leaf", (x - ux * 0.014, 0, z - uz * 0.014), (x + ux * 0.014, 0, z + uz * 0.014), 0, 1, v, v + 0.024, 0.004, mat))
    return join(name, leaves)


def torches(tags, level):
    """Torches burning either side of the gate, out before it."""
    z = GATE_Z + 0.09
    pieces = []
    for side in (1, -1):
        x = side * (GATE + 0.012)
        pieces.append(rod("torch", (x, -0.05, z), (x, 0.15, z), 0.006, beam, sides=4))
        pieces.append(block("cresset", (x - 0.01, 0.149, z - 0.01), (x + 0.01, 0.161, z + 0.01), iron))
    join(tagged("torches", tags), pieces)
    join(tagged("torch flames", tags), [block("flame", (side * (GATE + 0.012) - 0.007, 0.161, z - 0.007),
                                              (side * (GATE + 0.012) + 0.007, 0.189, z + 0.007), fire) for side in (1, -1)])


def open_leaves(tags, level):
    """The gate's two leaves standing open outward, strapped in iron."""
    tall = min(HEIGHT[level], 0.2)
    leaves, straps = [], []
    for side in (1, -1):
        hinge = (side * GATE, 0.0, GATE_Z)
        free = (side * GATE * 0.4, 0.0, GATE_Z + 0.07)
        leaves.append(along("leaf", hinge, free, 0.0, 1.0, -0.01, tall, 0.012, timber))
        for y in (0.05, tall - 0.05):
            straps.append(along("strap", hinge, free, 0.05, 0.95, y - 0.005, y + 0.005, 0.016, iron))
    join(tagged("gate leaves", tags), leaves)
    join(tagged("gate straps", tags) + "!fine", straps)


# MARK: The palisade

T1 = ["1"]
h = HEIGHT[1]
stakes, lashings = [], []
for run, (a, c) in enumerate(RUNS):
    (ux, uz), (nx, nz), length = frame(a, c)
    count = max(int(round(length / 0.055)), 2)
    for index in range(count):
        t = (index + 0.5) / count
        x, z = a[0] + (c[0] - a[0]) * t, a[2] + (c[2] - a[2]) * t
        tall = h * (0.9 + 0.2 * (0.5 + 0.5 * math.sin(run * 3.7 + index * 1.9)))
        stakes.append(rings("stake", [(0.02, -0.3), (0.02, tall), (0.0, tall + 0.05)], 3, timber, twist=index * 1.0 + run, centre=(x, z)))
    for y in (h * 0.35, h * 0.75):
        lashings.append(along("lashing", a, c, 0.0, 1.0, y - 0.006, y + 0.006, 0.006, rope, out=0.021))
join(tagged("palisade", T1), stakes)
join(tagged("lashings", T1) + "!fine", lashings)
# The walkway on its posts behind the stakes, braced, and the lintel over the gate.
walk, braces = [], []
for a, c in RUNS:
    (ux, uz), (nx, nz), length = frame(a, c)
    posts = max(int(round(length / 0.2)), 2)
    for index in range(posts + 1):
        t = index / posts
        x, z = a[0] + (c[0] - a[0]) * t - nx * 0.04, a[2] + (c[2] - a[2]) * t - nz * 0.04
        walk.append(rings("walk post", [(0.008, -0.05), (0.008, h * 0.72)], 3, beam, centre=(x, z)))
        if index > 0:
            px, pz = a[0] + (c[0] - a[0]) * (index - 1) / posts - nx * 0.04, a[2] + (c[2] - a[2]) * (index - 1) / posts - nz * 0.04
            braces.append(lath("brace", (px, 0.01, pz), (x, h * 0.68, z), 0.006, 0.006, beam))
    walk.append(along("walkway", a, c, 0.0, 1.0, h * 0.72 - 0.004, h * 0.72 + 0.004, 0.03, timber, out=-0.04))
walk.append(along("lintel", (-GATE - 0.03, 0, GATE_Z), (GATE + 0.03, 0, GATE_Z), 0.0, 1.0, h + 0.012, h + 0.048, 0.04, timber))
for x in (-GATE - 0.01, GATE + 0.01):
    walk.append(rings("gate post", [(0.024, -0.3), (0.024, h + 0.06)], 6, beam, centre=(x, GATE_Z)))
join(tagged("walkway", T1), walk)
join(tagged("braces", T1) + "!fine", braces)
# Two watch platforms under thatch at the far corners, a ladder up each.
watch, rails = [], []
for index in (0, 3):
    cx, _, cz = corner(index)
    d = math.hypot(cx, cz)
    cx, cz = cx - cx / d * 0.06, cz - cz / d * 0.06
    for dx, dz in ((-0.035, -0.035), (0.035, -0.035), (-0.035, 0.035), (0.035, 0.035)):
        watch.append(rings("watch post", [(0.007, -0.05), (0.007, 0.36)], 4, beam, centre=(cx + dx, cz + dz)))
    watch.append(block("platform", (cx - 0.045, 0.24, cz - 0.045), (cx + 0.045, 0.255, cz + 0.045), timber))
    watch.append(hip_roof("watch roof", (cx, cz), 0.11, 0.11, 0.36, 0.07, thatch, overhang=0.01, thickness=0.008))
    for p, q in (((-0.045, -0.045), (0.045, -0.045)), ((0.045, -0.045), (0.045, 0.045)), ((0.045, 0.045), (-0.045, 0.045)),
                 ((-0.045, 0.045), (-0.045, -0.045))):
        rails.append(lath("rail", (cx + p[0], 0.29, cz + p[1]), (cx + q[0], 0.29, cz + q[1]), 0.006, 0.006, timber))
    for side in (-1, 1):
        rails.append(lath("ladder", (cx + 0.06 + side * 0.012, 0.0, cz + 0.06), (cx + 0.04 + side * 0.012, 0.25, cz + 0.04), 0.005, 0.005, plank))
    for rung in range(1, 6):
        y = 0.25 * rung / 6
        f = rung / 6
        rails.append(lath("rung", (cx + 0.06 - 0.02 * f - 0.012, y, cz + 0.06 - 0.02 * f), (cx + 0.06 - 0.02 * f + 0.012, y, cz + 0.06 - 0.02 * f),
                          0.004, 0.004, plank))
join(tagged("watch", T1), watch)
join(tagged("watch rails", T1) + "!fine", rails)

# MARK: The stone walls, from the second level

for level in (2, 3, 4, 5):
    tags = [str(level)]
    h, t = HEIGHT[level], thick(level)
    walls, close = [], []
    for run, (a, c) in enumerate(RUNS):
        (ux, uz), (nx, nz), length = frame(a, c)
        walls.append(along("wall", a, c, 0.0, 1.0, -0.3, h, t, dark if level == 2 else stone))
        count = max(int(round(length / 0.2)) - 1, 1)
        if level == 2:
            # The coping, pale, a little proud of the wall.
            walls.append(along("coping", a, c, 0.0, 1.0, h, h + 0.022, t + 0.024, pale, chamfer=0.004))
        else:
            merlon_count = max(int(round(length / 0.075)), 1)
            for index in range(merlon_count):
                middle = (index + 0.5) / merlon_count
                walls.append(along("merlon", a, c, middle - 0.02 / length, middle + 0.02 / length, h, h + 0.045, t * 0.9, pale))
        # Buttresses along the outer face.
        for index in range(1, count + 1):
            middle = index / (count + 1)
            walls.append(along("buttress", a, c, middle - 0.018 / length, middle + 0.018 / length, -0.3, h * 0.8, 0.028, dark,
                               out=t / 2 + 0.014))
            if level == 2:
                # Close, the low wall's buttresses capped in pale stone.
                close.append(along("buttress cap", a, c, middle - 0.021 / length, middle + 0.021 / length, h * 0.8, h * 0.8 + 0.012, 0.034,
                                   pale, out=t / 2 + 0.016))
        # Close: arrow loops between the buttresses, the masons' putlog holes,
        # a string course, and from the third level the wall-walk's boards.
        face = t / 2 + 0.002
        for index in range(1, count):
            middle = (index + 0.5) / (count + 1)
            close.append(along("loop", a, c, middle - 0.006 / length, middle + 0.006 / length, h * 0.55 - 0.0275, h * 0.55 + 0.0275, 0.012,
                               beam, out=face))
        if level <= 3:
            for row, y in enumerate((0.3, 0.66)):
                for index in range(row, count + 1, 2):
                    middle = (index + 0.3) / (count + 1)
                    close.append(along("putlog", a, c, middle - 0.005 / length, middle + 0.005 / length, h * y - 0.005, h * y + 0.005, 0.004,
                                       hole, out=face))
        if level == 2:
            close.append(along("course", a, c, 0.0, 1.0, h * 0.5 - 0.005, h * 0.5 + 0.005, 0.008, pale, out=face))
            for share in (0.22, 0.71):
                y = h * (0.2 + 0.5 * share)
                close.append(along("patch", a, c, share - 0.016 / length, share + 0.016 / length, y - 0.009, y + 0.009, 0.006, patched,
                                   out=face))
        else:
            close.append(along("course", a, c, 0.0, 1.0, h * 0.82 - 0.006, h * 0.82 + 0.006, 0.012, pale, out=face))
            close.append(along("wall-walk", a, c, 0.0, 1.0, h - 0.016, h - 0.008, 0.024, timber, out=-(t / 2 + 0.012)))
    if level == 2:
        # The low wall's corners on squat piers of dressed stone.
        for index in range(6):
            cx, _, cz = corner(index)
            angle = index * math.pi / 3
            walls.append(around("pier", (cx, cz), 0.0, angle, -0.3, h + 0.05, 0.11, 0.11, stone))
            walls.append(around("pier cap", (cx, cz), 0.0, angle, h + 0.035, h + 0.055, 0.13, 0.13, pale))
    join(tagged("walls", tags), walls)
    join(tagged("walls close", tags) + "!fine", close)
    if level in (2, 3):
        # Ivy up the stone either side of the gate.
        for index, (a, c) in enumerate((RUNS[0], RUNS[3])):
            flat_ivy(tagged("ivy %d" % index, tags) + "!fine", a, c, 0.38 if index == 0 else 0.62, t / 2 + 0.003, h * 0.9, 31 + index, ivy)

# MARK: The corner towers, from the third level

for level in (3, 4, 5):
    tags = [str(level)]
    h = HEIGHT[level]
    top = h + 0.12 + 0.05 * (level - 3)
    radius = 0.075 + 0.012 * (level - 3)
    towers, roofs, close = [], [], []
    for index in range(6):
        cx, _, cz = corner(index)
        base = -0.1
        if level == 3:
            towers.append(rings("tower", [(radius * 1.3, base - 0.2), (radius * 1.25, base + top + 0.1)], 4, stone, twist=math.pi / 4,
                                centre=(cx, cz)))
            for k in range(4):
                angle = 2 * math.pi * k / 4
                towers.append(around("merlon", (cx, cz), radius * 0.95, angle, base + top + 0.1, base + top + 0.14, 0.04, 0.03, pale))
        else:
            towers.append(rings("tower", [(radius * 1.08, base - 0.2), (radius, base + top + 0.1), (radius * 1.12, base + top + 0.12),
                                          (radius * 1.12, base + top + 0.15)], 8, stone, centre=(cx, cz)))
            roofs.append(rings("cone", [(radius * 1.16, base + top + 0.15), (0.0, base + top + 0.15 + radius * 2.6)], 8,
                               house if level == 5 else slate, centre=(cx, cz)))
            outward = math.atan2(cz, cx)
            for spread in (-0.5, 0.5):
                close.append(around("slit", (cx, cz), radius * 1.02, outward + spread, base + top * 0.62 - 0.025, base + top * 0.62 + 0.025,
                                    0.012, 0.016, beam))
            close.append(rings("course", [(radius * 0.98, base + top * 0.45), (radius * 1.1, base + top * 0.45 + 0.005),
                                          (radius * 1.1, base + top * 0.45 + 0.015), (radius * 0.98, base + top * 0.45 + 0.02)], 8, pale,
                               centre=(cx, cz), caps=(False, False)))
            peak = base + top + 0.15 + radius * 2.6
            close.append(rings("finial", [(0.006, peak - 0.015), (0.002, peak + 0.05)], 4, iron, centre=(cx, cz)))
    join(tagged("towers", tags), towers)
    if roofs:
        join(tagged("tower roofs", tags), roofs)
    if close:
        join(tagged("towers close", tags) + "!fine", close)

# MARK: The gate at every level

torches(["1", "2", "3", "4", "5"], 1)
for level in (1, 2, 3, 4, 5):
    open_leaves([str(level)], level)
# The low wall's gatehouse: two piers, a chamber roofed in slate over the
# way, its window lit and fires on the piers.
h = HEIGHT[2]
gatehouse = []
for x in (-0.1, 0.1):
    gatehouse.append(block("gate pier", (x - 0.025, -0.05, GATE_Z - 0.04), (x + 0.025, h + 0.12, GATE_Z + 0.04), stone))
gatehouse.append(block("gate chamber", (-0.13, h + 0.12, GATE_Z - 0.05), (0.13, h + 0.18, GATE_Z + 0.05), stone))
gatehouse.append(gable_roof("gate roof", (0, GATE_Z), 0.11, 0.27, h + 0.18, 0.07, slate, overhang=0.012, along="x", thickness=0.006))
join(tagged("gatehouse", ["2"]), gatehouse)
join(tagged("gatehouse lights", ["2"]), [lit("gate window", (0, h + 0.15, GATE_Z + 0.051), 0.02, 0.022, 0.0, candle)] +
     [rings("pier fire", [(0.0, h + 0.038), (0.01, h + 0.05), (0.0, h + 0.072)], 5, fire, centre=(x, GATE_Z + 0.05)) for x in (-0.1, 0.1)])
join(tagged("gatehouse irons", ["2"]) + "!fine", [lath("pier iron", (x, h + 0.01, GATE_Z + 0.04), (x, h + 0.04, GATE_Z + 0.05), 0.006, 0.006, iron)
                                                 for x in (-0.1, 0.1)])
# From the third level, two towers flank the gate under an arch.
for level in (3, 4, 5):
    tags = [str(level)]
    h = HEIGHT[level]
    half = 0.06 + 0.008 * (level - 3)
    top = h + 0.16 + 0.05 * (level - 3)
    gate, roofs, lights = [], [], []
    for side in (1, -1):
        x, z = side * (GATE + half), GATE_Z + 0.01
        if level == 3:
            gate.append(block("gate tower", (x - half, -0.3, z - half), (x + half, top, z + half), stone))
            for k in range(4):
                gate.append(around("merlon", (x, z), half * 0.9, k * math.pi / 2 + math.pi / 4, top, top + 0.04, 0.035, 0.03, pale))
        else:
            gate.append(rings("gate tower", [(half * 1.15, -0.3), (half * 1.05, top)], 8, stone, centre=(x, z)))
            roofs.append(rings("gate cone", [(half * 1.25, top), (0.0, top + half * 2.4)], 8, house if level == 5 else slate, centre=(x, z)))
        lights.append(lit("gate tower window", (x, top - 0.02, z + half * 1.05 + 0.002), 0.018, 0.05, 0.0, candle))
    gate.append(block("arch", (-GATE - 0.01, h - 0.02, GATE_Z - 0.04), (GATE + 0.01, h + 0.08, GATE_Z + 0.05), pale, chamfer=0.004))
    join(tagged("gate towers", tags), gate)
    if roofs:
        join(tagged("gate roofs", tags), roofs)
    join(tagged("gate lights", tags), lights)
    if level >= 4:
        # A portcullis hung in the way.
        bars = [lath("bar", (x, 0.08, GATE_Z + 0.03), (x, h - 0.02, GATE_Z + 0.03), 0.008, 0.008, iron) for x in (-0.05, 0.0, 0.05)]
        bars.append(lath("bar", (-GATE, h * 0.6, GATE_Z + 0.03), (GATE, h * 0.6, GATE_Z + 0.03), 0.008, 0.008, iron))
        join(tagged("portcullis", tags), bars)
        # The House's banners down the walls either side of the gate.
        for side, (a, c) in ((1, RUNS[1]), (-1, RUNS[2])):
            mx, mz = (a[0] + c[0]) / 2, (a[2] + c[2]) / 2
            front = mz + thick(level) / 2 + 0.006
            hung = h - 0.03
            sheet = slab(tagged("gate banner %d" % side, tags), [(mx - 0.03, hung, front), (mx + 0.03, hung, front), (mx + 0.03, hung - 0.14, front),
                                                                (mx, hung - 0.16, front), (mx - 0.03, hung - 0.14, front)], banner, 0.004)
            sway(sheet, lambda q, top=hung: max(0.0, min(1.0, (top * UNIT - q.z) / (0.16 * UNIT) * 0.3)))
# At the fifth, the House's banner flown over the gate.
h = HEIGHT[5]
join(tagged("gate pole", ["5"]), [rod("pole", (0, h + 0.08, GATE_Z), (0, h + 0.5, GATE_Z), 0.008, beam, sides=6)])
flag(tagged("gate flag", ["5"]), (0, h + 0.49, GATE_Z), 0.22, 0.15, banner, turn=math.pi / 2)

finish_building(out_path("Art/models/walls.glb"), ["1", "2", "3", "4", "5"])
