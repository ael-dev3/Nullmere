"""The Saltworks, where the black lake's brine is dried to moonsalt, its five
levels the tiers of one file, each within a work's slot and facing +z
(Sources/NullmereModels/Saltworks.swift, made again in Blender):
1. shallow pans in the shore mud, a crust of salt in each, a shaduf
   dipping brine from its trough, the salt-maker's hut under thatch, a
   heap of raked salt;
2. pans in a grid on timber walkways, the hut, cones of raked salt;
3. a boiling house of stone with its furnace and chimney, lead pans of
   salt before it, the salt packed in sacks;
4. a brine wheel of buckets turning in its race, lifting the brine into a
   trough on a trestle, racks of salt cakes drying;
5. a refinery of white stone, its round tower lit with the moon's light,
   crystals of moonsalt lit from within, more pans, the House's banners.
At every level a dyke of stones along the bank, rising as the works grow,
cones of salt heaped on it and a sluice to let the brine in.
Close: the halls' rafters, courses and gable boards, the tower's bands and
finial, the chimney's cap, the lead pans, a rake at the hut, flecks of
salt and the lake's weed strewn on the mud.
The shaduf dips and the brine wheel turns.

    python Art/blender/saltworks.py Art/models/saltworks.glb
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

# The shore mud the works stand in: loam trodden with the yard's earth
# (Palette.loam.mix(Palette.yard, 0.4)).
mud = material("plain_earth_mud", (0.214, 0.194, 0.166))
loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
white = material("plain_stone_white", (0.84, 0.84, 0.82))
rock = material("plain_stone_rock", (0.40, 0.40, 0.42))
slate = material("plain_slate", (0.23, 0.24, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
linen = material("plain_linen", (0.7, 0.67, 0.6))
# The brine, grey-blue (Palette.seaWool); the lake's weed (Palette.moss).
brine = material("plain_seawool", (0.27, 0.33, 0.38))
moss = material("plain_moss", (0.21, 0.26, 0.22))
# Salt crust (Palette.saltCrust): crystal where it forms in the pans, plain
# where it is cut into cakes or strewn on the mud.
crust = material("crystal_saltcrust", (0.8, 0.83, 0.86))
cake = material("plain_saltcrust", (0.8, 0.83, 0.86))
moonsalt = material("crystal_moonsalt", (0.88, 0.91, 0.95))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
candle = material("glow_candle", (1.0, 0.8, 0.52))
fire = material("glow_fire", (1.0, 0.68, 0.32))
# The refinery's light: its tower's windows (Palette.moonGlow) and its
# crystals of moonsalt lit from within (Palette.moonsalt, glowing).
moonglow = material("glow_moonglow", (0.72, 0.86, 1.0))
lit_salt = material("glow_moonsalt", (0.88, 0.91, 0.95))

# Where each level's shaduf stands and its brine wheel turns: the shaduf's
# pole swings on its post's head about x, the wheel about its hub along z.
SHADUFS = {1: (0.17, 0.0, -0.12), 2: (0.19, 0.0, -0.15), 3: (0.2, 0.0, -0.14)}
WHEELS = {4: (0.17, 0.0, -0.12), 5: (0.18, 0.0, -0.12)}
POST = 0.13
HUB = 0.08
rig = work_rig([("shaduf@%d" % level, (x, POST, z), (1, 0, 0)) for level, (x, _, z) in SHADUFS.items()]
               + [("brine wheel@%d" % level, (x, HUB, z), (0, 0, 1)) for level, (x, _, z) in WHEELS.items()])
ground(pad(tagged("pad", []), 0.31, mud), rig)


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


# MARK: Shapes of its own

def ring_point(radius, y, angle):
    """A point on a ring about the upright as the game counts it: angle
    zero due east, rising toward -z (MeshBuilder.ring)."""
    return (radius * math.cos(angle), y, -radius * math.sin(angle))


def box(name, centre, size, mat, turn=0.0, chamfer=0.0):
    """A block about its middle, `size` along x, up and along z, turned as
    block() turns it."""
    cx, cy, cz = centre
    sx, sy, sz = size
    return block(name, (cx - sx / 2, cy - sy / 2, cz - sz / 2), (cx + sx / 2, cy + sy / 2, cz + sz / 2), mat, chamfer=chamfer, turn=turn,
                 about=centre)


def tipped(obj, at_point, tip):
    """A piece made about the origin, tipped `tip` radians about the world's
    z (+x toward +y) and set down at a point."""
    obj.location = at(*at_point)
    obj.rotation_euler = (0.0, -tip, 0.0)
    apply_transforms(obj)
    return obj


def solid(name, points, faces, mats, which=None):
    """A closed solid of corners (the world's) and faces (corner numbers),
    face i in mats[which[i]]."""
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    bm = bmesh.new()
    verts = [bm.verts.new(at(*p)) for p in points]
    for index, corners in enumerate(faces):
        face = bm.faces.new([verts[k] for k in corners])
        face.material_index = which[index] if which else 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    for mat in mats:
        mesh.materials.append(mat)
    return obj


def beam(name, a, b, width, mat, depth=None):
    """A squared timber from one point to another (the world's), framed as
    the game frames one: a level one `width` across the ground and `depth`
    deep."""
    a, b = Vector(a), Vector(b)
    along = b - a
    up = along.normalized()
    reference = Vector((0, 0, 1)) if abs(up.y) > 0.95 else Vector((0, 1, 0))
    side = up.cross(reference).normalized()
    front = side.cross(up)
    d = width if depth is None else depth
    points = [tuple(end + side * (sx * width / 2) + front * (sz * d / 2)) for end in (a, b) for sx in (-1, 1) for sz in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return solid(name, points, faces, [mat])


def tray(name, low, high, wall, floor, mat, floor_mat, chamfer=0.0, frame=None):
    """An open box from corner to corner, its walls `wall` thick and its
    floor at `floor` in a stuff of its own: a pan of brine, a trough, a
    race; the edges of its rim cut back by `chamfer`, if given. `frame`, if
    given, carries its corners into the world from the axes they are given
    in (a trough laid on a slope)."""
    x0, y0, z0 = low
    x1, y1, z1 = high
    c = chamfer

    def square(inset, y):
        return [(x, y, z) for x, z in ((x0 + inset, z0 + inset), (x1 - inset, z0 + inset), (x1 - inset, z1 - inset), (x0 + inset, z1 - inset))]
    # From the outer foot up the wall, over the rim and down to the floor.
    loops = [square(0.0, y0), square(0.0, y1 - c)]
    if c > 0:
        loops += [square(c, y1), square(wall - c, y1)]
    loops += [square(wall, y1 - c), square(wall, floor)]
    points = [p for loop in loops for p in loop]
    if frame:
        points = [frame(p) for p in points]
    faces = []
    for k in range(len(loops) - 1):
        for i in range(4):
            j = (i + 1) % 4
            faces.append((4 * k + i, 4 * k + j, 4 * k + 4 + j, 4 * k + 4 + i))
    last = 4 * (len(loops) - 1)
    faces += [(last, last + 1, last + 2, last + 3), (3, 2, 1, 0)]
    return solid(name, points, faces, [mat, floor_mat], [0] * (len(faces) - 2) + [1, 0])


def ball(name, centre, radius, mat, bands=3, sides=6):
    """A faceted ball (the game's sphere)."""
    x, y, z = centre
    sections = []
    for k in range(bands + 1):
        angle = math.pi * k / bands - math.pi / 2
        sections.append((0.0 if k in (0, bands) else radius * math.cos(angle), y + radius * math.sin(angle)))
    return rings(name, sections, sides, mat, centre=(x, z))


def salt_heap(name, at_point, radius, height):
    """A heap of white salt, raked up."""
    x, y, z = at_point
    return rings(name, [(radius, y - 0.01), (radius * 0.75, y + height * 0.5), (0.0, y + height)], 6, moonsalt, centre=(x, z))


# MARK: The bank, at every level

def dyke(course):
    """A course of the dry-stone dyke along the bank, each stone laid along
    it, the courses breaking joint."""
    stones = []
    for index in range(18):
        angle = math.pi * (1.08 + 0.84 * index / 17)
        a = angle + (0.0 if course % 2 == 0 else 0.5 * 0.84 * math.pi / 18)
        p = ring_point(0.295, 0.012 + course * 0.02, a)
        stones.append(box("dyke stone", p, (0.05, 0.019, 0.026), (stone, pale_stone, rock)[(index + course) % 3], turn=-a - math.pi / 2))
    return stones


def cone(index):
    """A cone of raked salt drying on the bank."""
    return salt_heap("cone", (-0.05 + index * 0.045, 0.0, 0.22 + (index % 2) * 0.02), 0.022, 0.035)


def sluice(at_point):
    """A sluice gate in the bank: two posts, a board raised in its slots,
    the brine let in under it."""
    x, _, z = at_point
    pieces = [rod("sluice post", (x, -0.01, z + dz), (x, 0.08, z + dz), 0.005, dark, sides=4) for dz in (-0.025, 0.025)]
    pieces.append(box("sluice board", (x, 0.05, z), (0.008, 0.04, 0.05), timber))
    pieces.append(block("sluice beam", (x - 0.003, 0.077, z - 0.03), (x + 0.003, 0.083, z + 0.03), dark))
    pieces.append(block("sluice brine", (x + 0.005, 0.006, z - 0.02), (x + 0.08, 0.0135, z + 0.02), brine))
    return pieces


# MARK: The works

def salt_pan(centre, size, share):
    """A shallow pan in a rim of pale stone, its bed of loam and a crust of
    salt over `share` of it."""
    cx, _, cz = centre
    h, rim = size / 2, 0.016
    out, inner = h + rim / 2, h - rim / 2
    pieces = [tray("pan", (cx - out, 0.0, cz - out), (cx + out, 0.028, cz + out), rim, 0.013, pale_stone, loam, chamfer=0.003)]
    if share > 0:
        c = min(h * 0.92 * share, inner - 0.0005)
        pieces.append(block("crust", (cx - c, 0.0125, cz - c), (cx + c, 0.016, cz + c), crust))
    return pieces


def pans(columns, rows, origin, walkways):
    """Pans in a grid, each crusted as far as its brine has dried, with
    timber walkways laid along the rims between them and before them."""
    size, gap = 0.075, 0.012
    step = size + gap
    width, depth = columns * step, rows * step
    ox, _, oz = origin
    pieces = []
    for column in range(columns):
        for row in range(rows):
            middle = (ox - width / 2 + (column + 0.5) * step, 0.0, oz - depth / 2 + (row + 0.5) * step)
            pieces += salt_pan(middle, size, ((column + row) % 3) / 2)
    if walkways:
        for column in range(1, columns):
            x = ox - width / 2 + column * step
            pieces.append(block("walkway", (x - gap * 0.45, 0.027, oz - depth / 2), (x + gap * 0.45, 0.032, oz + depth / 2), grey))
        pieces.append(block("walkway", (ox - width / 2, 0.013, oz + depth / 2), (ox + width / 2, 0.019, oz + depth / 2 + 0.012), grey))
    return pieces


def hut(at_point):
    """The salt-maker's hut of timber under thatch, its door, its window
    lit, a rake leant at its corner."""
    x0, _, z0 = at_point
    body, close = hall("hut", 0.11, 0.09, 0.075, timber, thatch, dark, pitch=0.7)
    for obj in body + close:
        placed(obj, at_point)
    far, fine = list(body), list(close)
    far.append(box("door", (x0 + 0.02, 0.035, z0 + 0.046), (0.026, 0.055, 0.02), dark))
    far.append(lit("window", (x0 - 0.03, 0.05, z0 + 0.046), 0.016, 0.018, 0.0, candle))
    fine.append(rod("rake", (x0 + 0.06, 0.0, z0 + 0.05), (x0 + 0.07, 0.11, z0 + 0.05), 0.003, pale, sides=4))
    fine.append(box("rake head", (x0 + 0.07, 0.11, z0 + 0.05), (0.004, 0.006, 0.05), pale))
    return far, fine


def shaduf(level):
    """A shaduf: a pole on its post weighted at one end, a bucket on the
    other, dipping brine from its trough; the pole hung on its bone."""
    x, _, z = SHADUFS[level]
    still = [rod("shaduf post", (x, 0.0, z), (x, POST, z), 0.008, dark, sides=4),
             tray("trough", (x - 0.05, 0.0, z + 0.03), (x + 0.05, 0.025, z + 0.07), 0.004, 0.022, dark, brine)]
    # The pole laid through the pivot in the post's head, so it rides on the
    # post as it swings; its weight, rope and bucket hung from it.
    y = POST - 0.012
    moving = [beam("pole", (x, y, z - 0.08), (x, y + 0.03, z + 0.12), 0.006, timber),
              ball("counterweight", (x, y - 0.005, z - 0.08), 0.018, stone),
              rod("rope", (x, y + 0.03, z + 0.12), (x, y - 0.046, z + 0.12), 0.0015, linen, sides=4),
              rings("bucket", [(0.01, y - 0.067), (0.013, y - 0.045)], 6, dark, centre=(x, z + 0.12))]
    on(join(tagged("shaduf pole", level_tags([level])), moving), rig, "shaduf@%d" % level)
    return still


def sacks(at_point):
    """Sacks of salt packed by the boiling house, heaped."""
    out = []
    for index in range(5):
        angle = index * 1.7
        p = (at_point[0] + 0.025 * math.cos(angle), at_point[1] + (index // 3) * 0.02, at_point[2] + 0.025 * math.sin(angle))
        out.append(tied_sack("sack", p, 0.02, linen))
    return out


def boiling_house(at_point):
    """The boiling house: stone under slate on a dressed footing, its
    furnace mouth glowing and its chimney; lead pans of salt before it."""
    x0, _, z0 = at_point
    w, d = 0.16, 0.12
    body, close = hall("boiling house", w, d, 0.1, stone, slate, dark, pitch=0.65)
    for obj in body + close:
        placed(obj, at_point)
    far, fine = list(body), list(close)
    far.append(block("footing", (x0 - w / 2 - 0.012, -0.08, z0 - d / 2 - 0.012), (x0 + w / 2 + 0.012, 0.04, z0 + d / 2 + 0.012), dark_stone,
                     chamfer=0.004))
    far.append(box("door", (x0 - 0.035, 0.045, z0 + 0.061), (0.03, 0.07, 0.02), dark))
    far.append(block("furnace", (x0 + 0.025, 0.014, z0 + 0.069), (x0 + 0.055, 0.036, z0 + 0.075), fire))
    far.append(block("chimney", (x0 + 0.045, 0.09, z0 - 0.04), (x0 + 0.075, 0.24, z0 - 0.01), dark_stone, chamfer=0.003))
    fine.append(block("chimney cap", (x0 + 0.041, 0.24, z0 - 0.044), (x0 + 0.079, 0.25, z0 - 0.006), stone, chamfer=0.002))
    for x in (-0.05, 0.01):
        fine.append(tray("lead pan", (x0 + x, 0.0, z0 + 0.07), (x0 + x + 0.05, 0.02, z0 + 0.1), 0.003, 0.018, iron, moonsalt))
    return far, fine


def brine_wheel(level):
    """A brine wheel: buckets on a wheel turning in its stone race, lifting
    the brine into a trough led off on a trestle; the wheel hung on its
    bone."""
    x, _, z = WHEELS[level]
    hub = (x, HUB, z)
    still = [tray("race", (x - 0.065, 0.0, z - 0.035), (x + 0.065, 0.022, z + 0.035), 0.006, 0.016, dark_stone, brine, chamfer=0.002)]
    for dz in (-0.035, 0.035):
        still.append(box("wheel post", (x, HUB - 0.04, z + dz), (0.012, 0.1, 0.01), dark))
    # The trough from over the wheel's head, falling westward to its trestle.
    start, end = Vector((x, HUB + 0.095, z)), Vector((x - 0.12, HUB + 0.065, z))
    run = (end - start).length
    along = (end - start).normalized()
    up = Vector((-along.y, along.x, 0.0))
    if up.y < 0:
        up = -up

    def slope(p):
        return tuple(start + along * p[0] + up * p[1] + Vector((0, 0, 1)) * p[2])
    still.append(tray("brine trough", (0.0, -0.006, -0.01), (run, 0.006, 0.01), 0.003, 0.002, timber, brine, frame=slope))
    still.append(rod("trestle", (x - 0.115, 0.0, z), (x - 0.115, 0.142, z), 0.005, dark, sides=4))
    turning = wheel("rim", hub, 0.063, 0.012, 6, timber, axis="z")
    for felloe in turning[:10]:
        felloe.data.materials[0] = dark
    for k in range(8):
        a = k * math.pi / 4
        bucket = block("bucket", (-0.009, -0.009, -0.02), (0.009, 0.009, 0.02), dark)
        turning.append(tipped(bucket, (x + 0.075 * math.cos(a), HUB + 0.075 * math.sin(a), z), a))
    turning.append(rod("axle", (x, HUB, z - 0.04), (x, HUB, z + 0.04), 0.006, timber, sides=6))
    on(join(tagged("bucket wheel", level_tags([level])), turning), rig, "brine wheel@%d" % level)
    return still


def racks(at_point):
    """Racks where cakes of salt dry, three shelves of them."""
    x0, _, z0 = at_point
    far = [rod("rack post", (x0 + x, 0.0, z0), (x0 + x, 0.1, z0), 0.004, dark, sides=4) for x in (-0.04, 0.04)]
    for y in (0.035, 0.07, 0.1):
        far.append(box("shelf", (x0, y, z0), (0.09, 0.004, 0.035), grey))
        for x in (-0.03, -0.01, 0.01, 0.03):
            far.append(box("salt cake", (x0 + x, y + 0.008, z0), (0.014, 0.012, 0.02), cake))
    return far


def refinery(at_point):
    """The refinery of white stone: its hall on a dressed footing, its round
    tower lit with the moon's light, and its crystals of moonsalt lit from
    within before its door."""
    x0, _, z0 = at_point
    hx, hz, w, d = x0 + 0.04, z0 + 0.02, 0.15, 0.12
    body, close = hall("refinery", w, d, 0.11, white, slate, dark, pitch=0.65)
    for obj in body + close:
        placed(obj, (hx, 0.0, hz))
    far, fine = list(body), list(close)
    far.append(block("footing", (hx - w / 2 - 0.012, -0.08, hz - d / 2 - 0.012), (hx + w / 2 + 0.012, 0.04, hz + d / 2 + 0.012), stone,
                     chamfer=0.004))
    far.append(box("door", (x0 + 0.04, 0.05, z0 + 0.081), (0.03, 0.07, 0.02), dark))
    tx, tz = x0 - 0.04, z0 - 0.04
    body, close = round_house("tower", 0.045, 0.28, white, slate, pale_stone, dark, rise=0.08, sides=10)
    for obj in body + close:
        placed(obj, (tx, 0.0, tz))
    far += body
    fine += close
    # Its cone given the eaves' thickness the halls' roofs have.
    far.append(rings("tower eave", [(0.045 * 1.18, 0.27), (0.045 * 1.18, 0.28)], 10, slate, caps=(True, False), centre=(tx, tz)))
    for index, y in enumerate((0.12, 0.2)):
        angle = index * 2.4 + 0.5
        p = ring_point(0.045, y, angle)
        far.append(lit("tower window", (tx + p[0], y, tz + p[2]), 0.014, 0.03, angle + math.pi / 2, moonglow))
    for index in range(5):
        angle = index * 1.25
        crystal = rings("crystal", [(0.0, 0.0), (0.008, 0.01), (0.005, 0.04), (0.0, 0.05)], 5, lit_salt)
        far.append(tipped(crystal, (x0 + 0.1 + 0.03 * math.cos(angle), 0.0, z0 + 0.12 + 0.03 * math.sin(angle)), 0.2 if index % 2 == 0 else -0.2))
    return far, fine


def banners():
    """The House's banners at the pans, on poles planted in the dyke."""
    far = []
    for x in (-0.24, 0.24):
        far.append(rod("banner pole", (x, 0.0, 0.16), (x, 0.2, 0.16), 0.005, dark, sides=4))
        flag("banner %s@5" % ("E" if x > 0 else "W"), (x, 0.195, 0.16), 0.045, 0.085, banner, turn=math.pi if x > 0 else 0.0, tail=True)
    return far


# MARK: The levels

# The bank, rising as the works grow: a course of the dyke and a cone of
# salt more at the second level and the third, the sluice from the first.
piece("bank", [], dyke(0) + [cone(0), cone(1)] + sluice((-0.25, 0.0, 0.06)))
piece("bank", [2, 3, 4, 5], dyke(1) + [cone(2)])
piece("bank", [3, 4, 5], dyke(2) + [cone(3)])

far, fine = hut((-0.19, 0.0, -0.12))
far += pans(2, 2, (-0.02, 0.0, 0.0), False)
far.append(salt_heap("heap", (0.16, 0.0, 0.16), 0.04, 0.04))
piece("saltworks", [1], far + shaduf(1), fine)

far, fine = hut((-0.19, 0.0, -0.11))
far += pans(3, 2, (0.02, 0.0, 0.02), True)
far += [salt_heap("cone", (-0.15 + index * 0.045, 0.0, 0.17 + (index % 2) * 0.02), 0.022, 0.035) for index in range(3)]
piece("saltworks", [2], far + shaduf(2), fine)

far, fine = boiling_house((-0.12, 0.0, -0.12))
piece("boiling house", [3, 4], far, fine)
piece("saltworks", [3], pans(3, 2, (0.06, 0.0, 0.08), True) + sacks((-0.2, 0.0, 0.12)) + shaduf(3))
piece("saltworks", [4], pans(3, 2, (0.04, 0.0, 0.1), True) + brine_wheel(4) + racks((-0.21, 0.0, 0.13)))

far, fine = refinery((-0.13, 0.0, -0.12))
piece("saltworks", [5], far + pans(4, 2, (0.02, 0.0, 0.11), True) + brine_wheel(5) + banners(), fine)

# Flecks of salt and the lake's weed strewn on the mud, at every level.
flecks = []
for index in range(16):
    angle = index * 2.39996
    r = 0.12 + 0.17 * ((index * 17) % 9) / 9
    flecks.append(box("fleck", (r * math.cos(angle), 0.0125, r * math.sin(angle)), (0.012, 0.002, 0.009), moss if index % 3 == 0 else cake,
                      turn=angle))
join("crust!fine", flecks)

# The shaduf dipping and lifting, the brine wheel turning once an idle.
idle(rig, turns=[("shaduf@%d" % level, (1, 0, 0), lambda u: 0.35 * swing(u)) for level in SHADUFS]
     + [("brine wheel@%d" % level, (0, 0, 1), wheel_turns(1)) for level in WHEELS])

finish_building(out_path("Art/models/saltworks.glb"), [str(level) for level in LEVELS])
