"""An alliance's storehouse and its yards, each a variant of one file
(Sources/NullmereModels/Stores.swift, made again in Blender), facing +z and
filling the heart of their hex, the alliance's colour about each:
- storehouse: a long barn of timber on a footing of stone under a high roof
  in the alliance's colour, its frame dark, great doors strapped with iron,
  lit windows and lanterns at the doors; a hoist at its loft door, its
  pulley turning and a sack swinging on the rope; a lean-to of stone under
  slate at its west end, a louvre on its ridge; before it sacks, barrels,
  planks, dressed stone and moonsalt under canvas, the alliance's banner;
- grain: a tilled acre fenced on three sides, its furrows half grown with
  swaying grain and half in stooks, a granary on staddle stones and a
  scarecrow in the standing grain;
- timber: logs stacked in tiers, a sawpit with a trunk on its trestles and
  the long saw in its cut, sheerlegs with a log swinging on the rope,
  stumps, planks and a woodshed;
- stone: a quarry face cut back in benches under a crag, a derrick slewing
  its block while its windlass turns, dressed blocks, rubble, a sledge
  and the masons' lodge;
- moonsalt: pans of brine crusting to moonsalt, a brine well under its
  turning windlass, a boiling house with its fire leaping and its chimney
  smoking (where Stores.saltSmoke says), an iron pan, heaps and sacks.
Each yard's wain stands loaded with its store at its near edge, its horse
in the shafts, with a mounting block, a trough and the yard's tally board;
and each its pennant where its gate would be. Close: the halls' rafters,
courses and gable boards; the great doors' boards, the windows' sills and
shutters, the louvre's slats; the grain's ears and the stooks' bands; the
sawyers' and masons' tools and ladders; the fire's stone mouth and the
chimney's course; the tally's notches, the wain's axles, a bucket; and
each yard's odds and ends, set down as the game's works set theirs.
The tilled acre stands still: the base bone is the moving variants' alone.

    python Art/blender/stores.py Art/models/stores.glb
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *
from person import drawn
from mathutils import Vector

reset()
VARIANTS = ["storehouse", "grain", "timber", "stone", "moonsalt"]
YARDS = ["grain", "timber", "stone", "moonsalt"]
MOVING = ["storehouse", "timber", "stone", "moonsalt"]

# MARK: Materials, the palette's own

yard_earth = material("plain_earth_yard", (0.31, 0.29, 0.25))
loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
earth = material("plain_earth", (0.24, 0.21, 0.18))
# The quarry's floor (the game's Palette.stoneDark.mix(Palette.yard, 0.5),
# a shade from the Quarry's own floor, Palette.rock.mix(Palette.yard, 0.5)).
quarry_floor = material("plain_earth_quarry", (0.355, 0.345, 0.335))
# The salt works' crusted ground: Palette.saltCrust.mix(Palette.earth, 0.55).
salt_ground = material("plain_stone_saltearth", (0.492, 0.489, 0.486))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
rough = material("plain_stone_rock", (0.40, 0.40, 0.42))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
bark = material("plain_timber_bark", (0.21, 0.17, 0.14))
straw = material("plain_thatch_straw", (0.62, 0.55, 0.36))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
grain_crop = material("foliage_grain", (0.66, 0.60, 0.40))
straw_crop = material("foliage_straw", (0.62, 0.55, 0.36))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
linen = material("plain_linen", (0.70, 0.67, 0.60))
wool = material("plain_wool", (0.39, 0.37, 0.33))
leather = material("plain_leather_dark", (0.22, 0.16, 0.12))
hair = material("plain_hair", (0.21, 0.17, 0.14))
bay = material("plain_horse_bay", (0.36, 0.23, 0.15))
black = material("plain_horse_black", (0.13, 0.12, 0.12))
soot = material("plain_soot", (0.11, 0.10, 0.10))
water = material("plain_water", (0.23, 0.24, 0.28))
house = material("house_roof", (0.78, 0.78, 0.78))
house_dark = material("house_dark", (0.5, 0.5, 0.5))
shutter = material("house_door", (0.78, 0.78, 0.78))
banner = material("cloth_banner", (0.78, 0.78, 0.78))
candle = material("glow_candle", (1.0, 0.8, 0.52))
fire = material("glow_fire", (1.0, 0.68, 0.32))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.4, metallic=0.7)
moonsalt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)
crust = material("crystal_saltcrust", (0.8, 0.83, 0.86), roughness=0.2)

# MARK: What the game reads, and where things turn

# The barn (Stores.barnWidth, barnDepth, barnHeight, barnAt) and the top of
# its footing (Stores.footing), which a rising storehouse is drawn up to.
BARN_W, BARN_D, BARN_H = 0.6, 0.28, 0.24
BARN = (0.0, 0.0, -0.08)
FOOTING = 0.04
FRONT, BACK = BARN[2] + BARN_D / 2, BARN[2] - BARN_D / 2
EAST, WEST = BARN_W / 2, -BARN_W / 2
RIDGE = BARN_H + BARN_D * 0.75
# The top of the storehouse's packed ground, which its goods stand on.
PAD_TOP = 0.012
# Where smoke rises from the salt works' boiling house (Stores.saltSmoke).
SALT_SMOKE = (0.32, 0.36, 0.22)

# The moving parts: the storehouse's pulley turning about x and the sack
# swinging under it; the timber yard's log swinging under the sheerlegs;
# the quarry's derrick slewing about its mast while its windlass turns; the
# salt works' windlass turning and the boiling house's fire leaping.
PULLEY = (EAST + 0.1, BARN_H + 0.105, BARN[2])
APEX = (0.3, 0.42, -0.26)
MAST = (0.3, 0.0, -0.22)
HUB = (MAST[0] + 0.04, 0.12, MAST[2])
WELL = (0.26, 0.0, -0.24)
AXLE = (WELL[0], 0.16, WELL[2])
HOUSE = (0.32, 0.0, 0.18)
HEARTH = (HOUSE[0], 0.015, HOUSE[2] + 0.083)
X, UP = (1, 0, 0), (0, 1, 0)
rig = work_rig([("pulley@storehouse", PULLEY, X), ("load@storehouse", PULLEY, X), ("hanging@timber", APEX, X),
                ("boom@stone", MAST, UP), ("windlass@stone", HUB, X), ("windlass@moonsalt", AXLE, X), ("fire@moonsalt", HEARTH, UP)])
# The storehouse's packed ground carries the skin; its base bone is kept
# only by the variants that move, so the tilled acre reads as still.
BASE = "base@" + ",".join(MOVING)
plot = ground(pad("pad@storehouse", 0.62, yard_earth, sides=6), rig)
rig.data.bones["base"].name = BASE
if plot.vertex_groups.get(BASE) is None:
    plot.vertex_groups["base"].name = BASE


# MARK: The game's builder's shapes

def joined(name, pieces):
    """Pieces joined into one object so named."""
    pieces = list(pieces)
    if len(pieces) == 1:
        pieces[0].name = name
        return pieces[0]
    return join(name, pieces)


def cbox(name, centre, size, mat, turn=0.0):
    """MeshBuilder.box(center:size:turn:): a box about its middle, turned
    as the game turns one (its own +x toward -z)."""
    (x, y, z), (w, h, d) = centre, size
    return block(name, (x - w / 2, y - h / 2, z - d / 2), (x + w / 2, y + h / 2, z + d / 2), mat, turn=-turn)


def beam(name, a, b, width, mat, depth=None):
    """MeshBuilder.beam: a squared timber from one point to another, `width`
    across the ground and `depth` deep if it lies, `width` east to west if
    it stands."""
    a, b = Vector(a), Vector(b)
    along = b - a
    length = along.length
    up = along / length
    reference = Vector((0, 0, 1)) if abs(up.y) > 0.95 else Vector((0, 1, 0))
    side = up.cross(reference).normalized()
    front = side.cross(up)
    d = width if depth is None else depth
    corners = [a + side * x + up * y + front * z for z in (-d / 2, d / 2) for y in (0.0, length) for x in (-width / 2, width / 2)]

    def build(bm):
        v = [bm.verts.new(at(*c)) for c in corners]
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            bm.faces.new([v[i] for i in f])
    return mesh_object(name, build, mat)


def limb(name, a, b, radius, mat, top=None, sides=4, caps=(False, False)):
    """MeshBuilder.limb: a pole of `sides` faces from one point to another,
    narrowing to `top`, its ends open where what it stands in hides them
    and capped where they show."""
    r0, r1 = radius * UNIT, (radius if top is None else top) * UNIT
    return loft(name, [(tuple(at(*a)), r0, r0, {}), (tuple(at(*b)), r1, r1, {})], segments=sides, mat=mat, caps=caps, smooth=False)


def lathe(name, profile, sides, mat, at_point=(0.0, 0.0, 0.0), turn=0.0, caps=(True, True), squash=1.0):
    """MeshBuilder.lathe, set at a point and turned: .translation(at) *
    .rotationY(turn)."""
    return placed(rings(name, profile, sides, mat, caps=caps, squash=squash), at_point, turn)


def sphere(name, centre, radius, bands, sides, mat):
    """MeshBuilder.sphere: a faceted ball of `bands` rings."""
    profile = [(0.0 if k in (0, bands) else radius * math.cos(math.pi * k / bands - math.pi / 2),
                centre[1] + radius * math.sin(math.pi * k / bands - math.pi / 2)) for k in range(bands + 1)]
    return rings(name, profile, sides, mat, centre=(centre[0], centre[2]))


def sack(name, at_point, size, seed, mat=canvas):
    """MeshBuilder.sack: a sack of grain or salt, a lump sat on the ground."""
    x, y, z = at_point
    return rock(name, (x, y + size * 0.8, z), (size, size * 0.85, size * 0.9), seed, mat, bands=3, sides=6, jitter=0.12)


def door(name, centre, width, height, facing, mat=dark, depth=0.02):
    """MeshBuilder.door: a dark slab set into a wall, looking out along
    `facing` radians round from +z."""
    return lit(name, centre, width, height, facing, mat, depth=depth)


def spoked(name, centre, radius, width, spokes, rim, spoke, axis="z", sides=8):
    """A spoked wheel on its axle along `axis` (x or z): its rim a hoop of a
    tread and two cheeks, its spokes crossing at a hub (the game's wheel was
    a solid disc, its spokes hidden within it)."""
    cx, cy, cz = centre
    inner = radius * 0.76

    def point(r, a, off):
        if axis == "z":
            return at(cx + r * math.cos(a), cy + r * math.sin(a), cz + off)
        return at(cx + off, cy + r * math.sin(a), cz + r * math.cos(a))

    def build(bm):
        made = []
        for k in range(sides):
            a = 2 * math.pi * (k + 0.5) / sides
            made.append((bm.verts.new(point(radius, a, width / 2)), bm.verts.new(point(radius, a, -width / 2)),
                         bm.verts.new(point(inner, a, 0.0))))
        for k in range(sides):
            (f0, b0, i0), (f1, b1, i1) = made[k], made[(k + 1) % sides]
            bm.faces.new((f0, f1, b1, b0))
            bm.faces.new((f0, i0, i1, f1))
            bm.faces.new((b0, b1, i1, i0))
    pieces = [mesh_object(name, build, rim)]
    thick = max(width * 0.6, 0.003)
    for k in range(max(spokes // 2, 1)):
        a = math.pi * k / max(spokes // 2, 1) + math.pi / 2
        reach = inner + width * 0.2
        if axis == "z":
            d = Vector((math.cos(a), math.sin(a), 0.0)) * reach
        else:
            d = Vector((0.0, math.sin(a), math.cos(a))) * reach
        # Each a hair thinner than the last, so no two share a face's plane where they cross.
        pieces.append(beam(name + " spoke", tuple(Vector(centre) - d), tuple(Vector(centre) + d), thick * (1 - 0.06 * k), spoke))
    along = Vector((0, 0, 1)) if axis == "z" else Vector((1, 0, 0))
    out = along * (width * 0.9)
    pieces.append(limb(name + " hub", tuple(Vector(centre) - out), tuple(Vector(centre) + out), max(radius * 0.17, 0.003), rim, sides=6,
                       caps=(True, True)))
    return pieces


def hall_at(name, at_point, width, depth, height, wall, roof, pitch, turn=0.0, footing=None, floor=False, ridge=True):
    """MeshBuilder.hall at a point, turned: its far pieces and its fine
    work. A roof in the alliance's colour has its courses in the House's
    darker shade, as the game's are, and stop short of the gables; `floor`,
    its walls and posts stand on its floor and no lower (a granary on its
    staddles); without `ridge`, its ridge is left to a beam of its own."""
    far, fine = hall(name, width, depth, height, wall, roof, dark, pitch=pitch, footing=footing)
    if not ridge:
        for obj in [o for o in far if o.name.split(".")[0] == "ridge"]:
            far.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)
    if floor:
        for obj in far:
            low = {"walls": 0.0, "post": -0.001}.get(obj.name.split(".")[0])
            if low is not None:
                for v in obj.data.vertices:
                    v.co.z = max(v.co.z, low * UNIT)
    # The courses stop a hair short of the gables' faces, never in their plane.
    end = (width / 2 + 0.022 - 0.002) * UNIT
    for obj in fine:
        if obj.name.split(".")[0] == "course":
            for v in obj.data.vertices:
                v.co.x = max(-end, min(end, v.co.x))
            if roof is house:
                obj.data.materials[0] = house_dark
    for obj in far + fine:
        placed(obj, at_point, turn)
    return far, fine


def flagged(name, foot, height, width, drop, turn, tail):
    """MeshBuilder.banner: a pole with the alliance's banner flying from it,
    its pole capped with an iron finial (the banner a piece of its own, to
    sway)."""
    x, y, z = foot
    flag(name, (x, y + height - 0.01, z), width, drop, banner, turn=turn, tail=tail, thickness=max(width * 0.03, 0.004))
    return [limb("pole", foot, (x, y + height, z), 0.009, dark, caps=(False, True)),
            rings("finial", [(0.012, y + height), (0.0, y + height + 0.025)], 4, iron, centre=(x, z))]


def salt_heap(name, at_point, radius, height, squash=1.0):
    """MeshBuilder.saltHeap: a heap of white salt."""
    x, y, z = at_point
    return rings(name, [(radius, y - 0.01), (radius * 0.75, y + height * 0.5), (0.0, y + height)], 6, moonsalt, centre=(x, z),
                 squash=squash)


def planks(at_point, length, layers, turn=0.0):
    """MeshBuilder.planks: a stack of sawn planks."""
    out = []
    for layer in range(layers):
        y = layer * 0.022
        shift = (layer % 2) * 0.01
        out.append(block("plank", (-length / 2 + shift, y, -0.05), (length / 2 + shift, y + 0.02, 0.05), pale if layer % 2 == 0 else grey))
    for obj in out:
        placed(obj, at_point, turn)
    return out


def dressed(at_point, count, seed):
    """MeshBuilder.blocks: cut stone blocks, pale or grey as they fell."""
    out = []
    for index in range(count):
        jitter = unit(index, 3, seed)
        row, layer = index % 3, index // 3
        x, y, z = at_point[0] + row * 0.062 - 0.062, at_point[1] + layer * 0.042, at_point[2] + layer * 0.012
        out.append(cbox("block", (x, y + 0.021, z), (0.056, 0.04, 0.05), pale_stone if jitter < 0.5 else stone, turn=(jitter - 0.5) * 0.3))
    return out


def barrel(at_point, turn):
    """Stores.barrel: a barrel of timber hooped with iron."""
    out = [rings("barrel", [(0.026, 0.0), (0.032, 0.035), (0.026, 0.07)], 7, pale)]
    out += [rings("hoop", [(0.03, y - 0.004), (0.031, y + 0.004)], 7, iron, caps=(False, False)) for y in (0.012, 0.058)]
    for obj in out:
        placed(obj, at_point, turn)
    return out


def stump(name, at_point):
    """A stump in its bark, its sawn top pale."""
    obj = lathe(name, [(0.035, -0.04), (0.03, 0.035)], 5, bark, at_point=at_point)
    obj.data.materials.append(pale)
    top = max(obj.data.polygons, key=lambda p: p.center.z)
    top.material_index = 1
    return obj


def trough(name, low, high, wall, level, mat, water_mat):
    """A trough open at its top, its walls `wall` thick and the water
    standing at `level` within them (the game's water was a box shut within
    a solid trough)."""
    (x0, y0, z0), (x1, y1, z1) = low, high
    outer = ((x0, z0), (x1, z0), (x1, z1), (x0, z1))
    inner = ((x0 + wall, z0 + wall), (x1 - wall, z0 + wall), (x1 - wall, z1 - wall), (x0 + wall, z1 - wall))

    def build(bm):
        base = [bm.verts.new(at(x, y0, z)) for x, z in outer]
        lip = [bm.verts.new(at(x, y1, z)) for x, z in outer]
        rim = [bm.verts.new(at(x, y1, z)) for x, z in inner]
        pool = [bm.verts.new(at(x, level, z)) for x, z in inner]
        bm.faces.new(list(reversed(base)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((base[i], base[j], lip[j], lip[i]))
            bm.faces.new((lip[i], lip[j], rim[j], rim[i]))
            bm.faces.new((rim[i], rim[j], pool[j], pool[i]))
        bm.faces.new(pool).material_index = 1
    obj = mesh_object(name, build, mat)
    obj.data.materials.append(water_mat)
    return obj


def pitted(name, low, high, pit_low, pit_high, floor, mat, pit_mat):
    """Ground from one corner to the other with a pit sunk in it, its walls
    and floor in `pit_mat` (the game's pit was a box under the ground's
    face)."""
    (x0, y0, z0), (x1, y1, z1) = low, high
    (px0, pz0), (px1, pz1) = pit_low, pit_high

    def build(bm):
        top = [bm.verts.new(at(x, y1, z)) for x, z in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]
        under = [bm.verts.new(at(x, y0, z)) for x, z in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]
        rim = [bm.verts.new(at(x, y1, z)) for x, z in ((px0, pz0), (px1, pz0), (px1, pz1), (px0, pz1))]
        pit = [bm.verts.new(at(x, floor, z)) for x, z in ((px0, pz0), (px1, pz0), (px1, pz1), (px0, pz1))]
        bm.faces.new(list(reversed(under)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((top[i], top[j], rim[j], rim[i]))
            bm.faces.new((under[i], under[j], top[j], top[i]))
            bm.faces.new((rim[i], rim[j], pit[j], pit[i])).material_index = 1
        bm.faces.new(pit).material_index = 1
    obj = mesh_object(name, build, mat)
    obj.data.materials.append(pit_mat)
    return obj


# MARK: The game's noise, for the same stone and sheaf where it fell

def unit(x, y, seed=0):
    """Noise.unit: a value from 0 up to 1 for a lattice point."""
    m = 0xFFFFFFFF
    h = ((x & m) * 0x8DA6B343 & m) ^ ((y & m) * 0xD8163841 & m) ^ ((seed & m) * 0xCB1AB31F & m)
    h ^= h >> 13
    h = h * 0x5BD1E995 & m
    h ^= h >> 15
    return (h >> 8) / float(1 << 24)


def named_seed(name):
    """Works.seed(of:): a seed from a model's name."""
    h = 2166136261
    for c in name.encode("utf-8"):
        h = (h ^ c) * 16777619 & 0xFFFFFFFF
    return h


# MARK: The storehouse

tag = ["storehouse"]
far, close = [], []
barn, barn_close = hall_at("barn", BARN, BARN_W, BARN_D, BARN_H, timber, house, 0.75, footing=dark_stone, ridge=False)
far += barn
close += barn_close
# Its frame: posts down front and back, a rail between them.
for z in (FRONT + 0.004, BACK - 0.004):
    for index in range(7):
        # Standing on the footing, not in one plane with its ends.
        far.append(block("frame post", (WEST + index * BARN_W / 6 - 0.012, FOOTING, z - 0.006), (WEST + index * BARN_W / 6 + 0.012, BARN_H - 0.005,
                                                                                               z + 0.006), dark))
    # A hair thinner than the posts and ending within the end posts, so
    # their faces are never in one plane.
    far.append(cbox("frame rail", (0.0, BARN_H * 0.55, z), (BARN_W - 0.004, 0.018, 0.01), dark))
# The great doors, two leaves under a lintel, strapped and studded with iron.
for leaf in (-1, 1):
    far.append(door("great door", (leaf * 0.045, 0.1, FRONT + 0.01), 0.085, 0.17, 0.0))
    for y in (0.05, 0.15):
        far.append(cbox("strap", (leaf * 0.045, y, FRONT + 0.022), (0.08, 0.012, 0.006), iron))
    far.append(sphere("stud", (leaf * 0.012, 0.1, FRONT + 0.024), 0.008, 2, 4, iron))
far.append(cbox("lintel", (0.0, 0.195, FRONT + 0.012), (0.2, 0.025, 0.02), dark))
# Lit windows either side of the doors, between the frame's posts.
for x in (-0.25, 0.25):
    far.append(lit("window", (x, 0.15, FRONT + 0.006), 0.04, 0.05, 0.0, candle))
# The loft door high in the east gable, proud of it, a beam over it.
far.append(door("loft door", (EAST + 0.027, BARN_H + 0.05, BARN[2]), 0.07, 0.08, math.pi / 2, depth=0.012))
far.append(beam("hoist beam", (EAST - 0.02, BARN_H + 0.13, BARN[2]), (EAST + 0.12, BARN_H + 0.13, BARN[2]), 0.022, dark))
# Its pulley turning as the sack is hauled, the sack swinging on the rope
# clear of the planks stacked under it.
on(joined("pulley@storehouse", spoked("pulley", PULLEY, 0.018, 0.01, 4, iron, iron, axis="x")), rig, "pulley@storehouse")
load = (PULLEY[0], 0.13, BARN[2] + 0.018)
on(joined("load@storehouse", [limb("rope", (PULLEY[0], PULLEY[1] - 0.015, BARN[2] + 0.018), (load[0], 0.19, load[2]), 0.003, canvas),
                              sack("hauled sack", load, 0.04, 41)]), rig, "load@storehouse")
# A lean-to of stone at its west end under slate.
lean, lean_close = hall_at("lean-to", (WEST - 0.075, 0.0, BARN[2]), 0.14, 0.22, 0.13, stone, slate, 0.45, turn=math.pi / 2)
far += lean
close += lean_close
# The yard before it, on the packed ground: sacks of grain, barrels,
# planks, dressed stone and moonsalt.
for index, (x, y, z) in enumerate(((-0.3, 0.0, 0.2), (-0.24, 0.0, 0.24), (-0.27, 0.05, 0.22), (-0.19, 0.0, 0.19))):
    far.append(sack("sack", (x, y + PAD_TOP, z), 0.034, 50 + index))
for index, (x, z) in enumerate(((0.2, 0.17), (0.26, 0.2), (0.23, 0.26))):
    far += barrel((x, PAD_TOP, z), index * 0.7)
far += planks((0.36, PAD_TOP, 0.0), 0.2, 4, turn=math.pi / 2)
far += dressed((-0.08, PAD_TOP, 0.32), 5, 31)
far.append(salt_heap("salt heap", (0.08, PAD_TOP, 0.3), 0.045, 0.05))
# The moonsalt under canvas, a rim of it showing white beneath.
far.append(rings("salt canvas", [(0.04, 0.026), (0.0368, 0.037), (0.0, 0.0655)], 6, canvas, caps=(False, False), centre=(0.08, 0.3)))
# Iron straps hanging the pulley from the hoist beam, either side of it.
for dx in (-0.011, 0.011):
    far.append(cbox("pulley strap", (PULLEY[0] + dx, PULLEY[1] + 0.0075, PULLEY[2]), (0.003, 0.016, 0.008), iron))
# A door into the lean-to, under its gable.
far.append(door("lean-to door", (WEST - 0.1, 0.035, BARN[2] + 0.08), 0.04, 0.07, 0.0))
# Close: the great doors' boards, sills under the windows and shutters
# thrown back from them in the alliance's colour, slats in the louvre.
for leaf in (-1, 1):
    for dx in (-0.028, 0.0, 0.028):
        close.append(cbox("door board", (leaf * 0.045 + dx, 0.1, FRONT + 0.0205), (0.004, 0.16, 0.0015), timber))
for x in (-0.25, 0.25):
    close.append(cbox("sill", (x, 0.122, FRONT + 0.012), (0.052, 0.006, 0.014), pale))
    for side in (-1, 1):
        close.append(cbox("shutter", (x + side * 0.031, 0.15, FRONT + 0.0125), (0.018, 0.05, 0.004), shutter))
for y in (RIDGE + 0.027, RIDGE + 0.042):
    for side in (-1, 1):
        close.append(block("slat", (-0.032, y - 0.003, BARN[2] + side * 0.035 - 0.002), (0.032, y + 0.003, BARN[2] + side * 0.035 + 0.002), dark))
        close.append(block("slat", (side * 0.04 - 0.002, y - 0.003, BARN[2] - 0.027), (side * 0.04 + 0.002, y + 0.003, BARN[2] + 0.027), dark))
# Lanterns on posts at the door, their caps square to them.
for x in (-0.13, 0.13):
    far.append(limb("lantern post", (x, 0.0, FRONT + 0.06), (x, 0.2, FRONT + 0.06), 0.008, dark))
    far.append(cbox("lantern", (x, 0.215, FRONT + 0.06), (0.026, 0.034, 0.026), candle))
    far.append(rings("lantern cap", [(0.022, 0.232), (0.0, 0.252)], 4, iron, twist=math.pi / 4, centre=(x, FRONT + 0.06)))
# A ridge beam along its roof, and the louvre at its middle where the air
# goes in and out, set down into the roof's slopes.
far.append(beam("ridge", (WEST - 0.025, RIDGE + 0.006, BARN[2]), (EAST + 0.025, RIDGE + 0.006, BARN[2]), 0.02, dark))
far.append(block("louvre", (-0.04, RIDGE - 0.05, BARN[2] - 0.035), (0.04, RIDGE + 0.055, BARN[2] + 0.035), grey))
far.append(hip_roof("louvre roof", (0.0, BARN[2]), 0.11, 0.1, RIDGE + 0.055, 0.04, slate))
# The alliance's banner at its west corner, flying clear of the roof.
far += flagged("banner@storehouse", (WEST - 0.16, 0.0, FRONT + 0.12), 0.62, 0.16, 0.24, math.pi, True)
joined(tagged("storehouse", tag), far)
joined(tagged("storehouse close", tag) + "!fine", close)


# MARK: What every yard shares: its wain, trough and tally

WAIN = (0.3, 0.0, 0.5)
TALLY = (-0.45, 0.0, 0.5)


def horse(coat):
    """Wayhouse.horse: a horse standing, head down a little, made facing -x
    about its own foot: its barrel, legs, neck and head, ears and mane, its
    tail, the harness on its back and its collar."""
    u = UNIT
    pieces = [loft("horse", [(tuple(at(-0.027, 0.05, 0.0)), 0.011 * u, 0.0125 * u, {}), (tuple(at(0.0, 0.051, 0.0)), 0.012 * u, 0.014 * u, {}),
                             (tuple(at(0.026, 0.052, 0.0)), 0.0115 * u, 0.013 * u, {})], segments=6, mat=coat, smooth=False)]
    for x, z in ((-0.02, -0.0068), (-0.02, 0.0068), (0.019, -0.0068), (0.019, 0.0068)):
        pieces.append(limb("leg", (x, 0.046, z), (x, 0.0, z), 0.0038, coat, top=0.003))
    pieces.append(limb("neck", (-0.021, 0.055, 0.0), (-0.039, 0.077, 0.0), 0.0078, coat, top=0.0058, caps=(False, True)))
    pieces.append(limb("head", (-0.036, 0.08, 0.0), (-0.057, 0.064, 0.0), 0.0058, coat, top=0.0036, caps=(True, True)))
    pieces.append(limb("tail", (0.025, 0.057, 0.0), (0.034, 0.026, 0.0), 0.003, hair, top=0.0015, caps=(False, True)))
    pieces.append(beam("mane", (-0.016, 0.0595, 0.0), (-0.034, 0.0805, 0.0), 0.003, hair, depth=0.004))
    for z in (-0.0028, 0.0028):
        pieces.append(rings("ear", [(0.0018, 0.082), (0.0, 0.09)], 3, coat, centre=(-0.035, z)))
    pieces.append(cbox("harness", (0.0, 0.0655, 0.0), (0.02, 0.004, 0.03), leather))
    pieces.append(limb("collar", (-0.0221, 0.0564, 0.0), (-0.0259, 0.061, 0.0), 0.0098, leather, sides=6, caps=(True, True)))
    return pieces


def haulage():
    """Stores.haulage: the wain in its own frame (its wheels made to roll
    along its way, on axles across it, where the game's stood across its
    way), its shafts reaching to the horse's shoulders; the mounting block,
    the trough with water standing in it and the tally board on its post."""
    cart = [block("bed", (-0.08, 0.035, -0.04), (0.08, 0.045, 0.04), pale)]
    for z in (-0.043, 0.043):
        cart.append(block("side", (-0.08, 0.045, z - 0.003), (0.08, 0.07, z + 0.003), timber))
        for x in (-0.055, 0.055):
            cart += spoked("wheel", (x, 0.03, z * 1.12), 0.03, 0.006, 6, dark, timber, axis="z")
        cart.append(beam("shaft", (0.08, 0.045, z * 0.6), (0.255, 0.052, z * 0.5), 0.005, dark))
        # A trace from each shaft's end to the horse's collar.
        cart.append(limb("trace", (0.255, 0.052, z * 0.5), (0.263, 0.058, math.copysign(0.009, z)), 0.0012, leather, sides=3))
    for obj in cart:
        placed(obj, WAIN, 0.15)
    rest = [cbox("mounting block", (WAIN[0] - 0.18, 0.02, WAIN[2] + 0.02), (0.05, 0.04, 0.04), stone),
            trough("trough", (WAIN[0] + 0.12, 0.0, WAIN[2] - 0.1), (WAIN[0] + 0.198, 0.025, WAIN[2] - 0.07), 0.004, 0.021, dark, water),
            limb("tally post", TALLY, (TALLY[0], 0.16, TALLY[2]), 0.006, dark, caps=(False, True)),
            cbox("tally board", (TALLY[0], 0.13, TALLY[2] + 0.006), (0.08, 0.05, 0.006), pale)]
    return cart + rest


def in_the_wain(pieces):
    """Pieces made in the wain's own frame, set in it."""
    for obj in pieces:
        placed(obj, WAIN, 0.15)
    return pieces


def harnessed(coat):
    """The horse in the shafts, its head toward the wain's way."""
    pieces = horse(coat)
    for obj in pieces:
        placed(obj, (0.24, 0.0, 0.0), math.pi)
    return in_the_wain(pieces)


joined(tagged("wain", YARDS), haulage())
joined(tagged("horse", ["grain", "timber", "moonsalt"]), harnessed(bay))
joined(tagged("horse", ["stone"]), harnessed(black))
# Close: the tally's notches, the wain's axles and a bucket by the trough.
joined(tagged("wain close", YARDS) + "!fine",
       [cbox("notch", (TALLY[0] - 0.03 + index * 0.014, 0.13, TALLY[2] + 0.0098), (0.003, 0.03, 0.002), soot) for index in range(5)] +
       in_the_wain([limb("axle", (x, 0.03, -0.052), (x, 0.03, 0.052), 0.0025, dark) for x in (-0.055, 0.055)]) +
       [rings("bucket", [(0.012, 0.0), (0.015, 0.024)], 6, timber, centre=(WAIN[0] + 0.105, WAIN[2] - 0.053))])
# Each wain loaded with its yard's own goods.
joined(tagged("wain load", ["grain"]),
       in_the_wain([tied_sack("wain sack", (-0.05 + (index % 3) * 0.05, 0.045 + (index // 3) * 0.03, (index % 2) * 0.03 - 0.015), 0.9 * 0.022,
                              canvas) for index in range(6)]))
joined(tagged("wain load", ["timber"]),
       in_the_wain([log("wain log", (-0.1, 0.057 + (index // 3) * 0.022, (index % 3 - 1) * 0.024 + (index // 3) * 0.012),
                        (0.1, 0.057 + (index // 3) * 0.022, (index % 3 - 1) * 0.024 + (index // 3) * 0.012), 0.012) for index in range(5)]))
joined(tagged("wain load", ["stone"]),
       in_the_wain([cbox("wain block", (-0.045 + (index % 2) * 0.09, 0.0625 + (index // 2) * 0.035, 0.0), (0.07, 0.035, 0.06),
                         pale_stone if index % 2 == 0 else stone, turn=0.05 * index) for index in range(4)]))
# The salt heaped within the wain's sides, a crystal of moonsalt grown in it.
joined(tagged("wain load", ["moonsalt"]),
       in_the_wain([salt_heap("wain salt", (0.0, 0.046, 0.0), 0.06, 0.049, squash=0.7),
                    rings("wain crystal", [(0.0, 0.072), (0.01, 0.087), (0.0, 0.107)], 5, moonsalt, centre=(0.03, 0.01))]))


def pennant(foot, variant):
    """Stores.pennant: a pennant on a pole in the alliance's colour, set
    in its stone where a yard's gate would be."""
    x, y, z = foot
    return [rings("pennant stone", [(0.04, y - 0.03), (0.035, y + 0.02), (0.0, y + 0.035)], 5, dark_stone, centre=(x, z))] + \
        flagged(tagged("pennant", [variant]), foot, 0.5, 0.13, 0.08, 0.0, True)


def fence(posts):
    """Stores.fence: posts, and two rails from one post to the next."""
    pieces = [cbox("fence post", (x, y + 0.04, z), (0.016, 0.1, 0.016), dark) for x, y, z in posts]
    for (ax, ay, az), (cx, cy, cz) in zip(posts, posts[1:]):
        for y in (0.035, 0.07):
            pieces.append(beam("fence rail", (ax, ay + y, az), (cx, cy + y, cz), 0.008, grey, depth=0.012))
    return pieces


# MARK: The tilled acre

tag = ["grain"]
far, close = [], []
far.append(block("acre", (-0.52, -0.08, -0.42), (0.52, 0.006, 0.42), loam))
# Furrows ridged across it.
for row in range(9):
    z = row * 0.09 - 0.36
    far.append(beam("furrow", (-0.46, 0.012, z), (0.12, 0.012, z), 0.04, earth, depth=0.03))
# Grain standing in the back half, swaying: still at its root, free at its ears.
rows = []
for row in range(5):
    z = row * 0.09 - 0.36
    rows.append(beam("grain", (-0.44, 0.04, z), (-0.06, 0.04, z), 0.06, grain_crop if row % 2 == 0 else straw_crop,
                     depth=0.08 + 0.02 * unit(row, 5, 77)))
sway(joined(tagged("standing grain", tag), rows), lambda q: 0.8 * max(0.0, min(1.0, q.z / (0.1 * UNIT))) ** 2)
# Close, its ears standing up along each row, swaying the more.
ears = []
for row in range(5):
    z = row * 0.09 - 0.36
    top = 0.04 + (0.08 + 0.02 * unit(row, 5, 77)) / 2
    for k in range(7):
        ears.append(rings("ear", [(0.011, top - 0.004), (0.0, top + 0.02 + 0.006 * unit(row, k, 78))], 4, grain_crop if row % 2 == 0 else straw_crop,
                          caps=(False, False), twist=0.4 * k, centre=(-0.41 + k * 0.05, z + (0.013 if (k + row) % 2 == 0 else -0.013))))
sway(joined(tagged("standing grain ears", tag) + "!fine", ears), lambda q: 0.8 * max(0.0, min(1.0, q.z / (0.1 * UNIT))) ** 2)
# Stooks of sheaves in the reaped half, each bound about its waist.
for index, p in enumerate(((-0.36, 0.0, 0.12), (-0.22, 0.0, 0.18), (-0.08, 0.0, 0.1), (-0.3, 0.0, 0.3))):
    far.append(lathe("stook", [(0.045, -0.01), (0.036, 0.07), (0.052, 0.09), (0.0, 0.14)], 5, straw, at_point=p, turn=index * 0.9))
    close.append(lathe("stook band", [(0.0378, 0.058), (0.0392, 0.064), (0.0376, 0.071)], 5, thatch, at_point=p, turn=index * 0.9,
                       caps=(False, False)))
# The granary on its staddle stones, its walls standing on its floor.
GRANARY = (0.3, 0.0, -0.16)
for x in (-0.07, 0.07):
    for z in (-0.05, 0.05):
        far.append(rings("staddle", [(0.02, 0.0), (0.013, 0.045), (0.032, 0.052), (0.032, 0.064)], 5, stone,
                         centre=(GRANARY[0] + x, GRANARY[2] + z)))
granary, granary_close = hall_at("granary", (GRANARY[0], 0.064, GRANARY[2]), 0.2, 0.15, 0.11, timber, house, 0.8, floor=True)
far += granary
close += granary_close
far.append(door("granary door", (GRANARY[0], 0.12, GRANARY[2] + 0.077), 0.045, 0.07, 0.0))
# Three steps up to its door, between its staddles.
for k in range(3):
    far.append(block("granary step", (GRANARY[0] - 0.025, 0.028 * k, GRANARY[2] + 0.074), (GRANARY[0] + 0.025, 0.028 * (k + 1),
                                                                                          GRANARY[2] + 0.075 + 0.02 * (3 - k)), grey))
far.append(sack("sack", (0.24, 0.0, 0.0), 0.032, 61))
far.append(sack("sack", (0.3, 0.0, 0.03), 0.028, 62))
# A scarecrow in the standing grain, ragged and leaning, his coat stirring at its hem.
crow = [limb("scarecrow pole", (0.0, 0.0, 0.0), (0.0, 0.2, 0.0), 0.006, dark, caps=(False, True)),
        beam("scarecrow arms", (-0.06, 0.15, 0.0), (0.06, 0.15, 0.0), 0.008, dark),
        sphere("scarecrow head", (0.0, 0.205, 0.0), 0.02, 2, 5, straw),
        rings("scarecrow hat", [(0.03, 0.22), (0.0, 0.25)], 5, leather)]
coat = cbox("scarecrow coat", (0.0, 0.135, 0.0), (0.1, 0.06, 0.02), wool)
tufts = [limb("straw tuft", (side * 0.058, 0.15, 0.0), (side * 0.066, 0.128, 0.0), 0.005, straw, top=0.001) for side in (-1, 1)]
for obj in crow + [coat] + tufts:
    posed(obj, (-0.22, 0.0, -0.18), (0, 0, 1), 0.08)
far += crow
close += tufts
sway(joined(tagged("scarecrow coat", tag), [coat]), lambda q: 0.6 * max(0.0, min(1.0, (1.65 - q.z) / 0.6)))
# Fenced on three sides, open toward its gate.
far += fence([(-0.5, 0.0, 0.4), (-0.5, 0.0, -0.4), (0.5, 0.0, -0.4), (0.5, 0.0, 0.4)])
# More posts along its rails, so they never run a unit unheld.
far += [cbox("fence post", (x, 0.04, z), (0.016, 0.1, 0.016), dark)
        for x, z in ((-0.5, -0.2), (-0.5, 0.0), (-0.5, 0.2), (-0.25, -0.4), (0.0, -0.4), (0.25, -0.4), (0.5, -0.2), (0.5, 0.0), (0.5, 0.2))]
far += pennant((0.44, 0.0, 0.36), "grain")
joined(tagged("acre", tag), far)
joined(tagged("acre close", tag) + "!fine", close)


# MARK: The timber yard

tag = ["timber"]
far, close = [], []
far.append(pitted("timber ground", (-0.5, -0.08, -0.42), (0.5, 0.004, 0.42), (0.02, -0.04), (0.34, 0.06), -0.05, yard_earth, loam))
# Logs stacked three tiers high, held by stakes.
for tier in range(3):
    for index in range(4 - tier):
        y = 0.03 + tier * 0.05
        z = -0.34 + index * 0.06 + tier * 0.03
        far.append(log("log", (-0.46, y, z), (-0.08, y, z), 0.028))
for x in (-0.44, -0.1):
    for z in (-0.4, -0.125):
        far.append(cbox("stake", (x, 0.08, z), (0.014, 0.18, 0.014), dark))
# The sawpit: a trunk on two trestles over the pit, the saw standing in its cut.
for x in (0.06, 0.3):
    for z in (-0.05, 0.07):
        far.append(limb("trestle", (x, 0.0, z), (x, 0.09, 0.01), 0.008, dark))
far.append(log("trunk", (-0.02, 0.1, 0.01), (0.4, 0.1, 0.01), 0.03))
far.append(cbox("saw", (0.2, 0.08, 0.01), (0.008, 0.2, 0.05), steel))
far.append(cbox("saw handle", (0.2, 0.19, 0.01), (0.012, 0.012, 0.08), pale))
# Close: the saw's other handle down in the pit over a heap of sawdust;
# a maul and wedges laid by the trunk's end.
close.append(cbox("saw handle", (0.2, -0.022, 0.01), (0.012, 0.012, 0.08), pale))
close.append(rings("sawdust", [(0.045, -0.049), (0.0, -0.036)], 6, pale, centre=(0.2, 0.01)))
close.append(beam("maul haft", (-0.075, 0.009, 0.075), (-0.02, 0.009, 0.115), 0.006, pale))
close.append(cbox("maul head", (-0.08, 0.013, 0.071), (0.018, 0.018, 0.03), dark, turn=-0.63))
for k, (x, z) in enumerate(((-0.035, 0.05), (-0.022, 0.06))):
    close.append(cbox("wedge", (x, 0.008, z), (0.014, 0.008, 0.008), iron, turn=0.4 * k))
# Sheerlegs lashed at their head over a log, the log slung from its rope.
for foot in ((0.18, 0.0, -0.34), (0.42, 0.0, -0.34), (0.3, 0.0, -0.1)):
    far.append(limb("sheerleg", foot, APEX, 0.01, timber))
far.append(rings("lashing", [(0.02, APEX[1] - 0.022), (0.02, APEX[1] + 0.004)], 6, canvas, centre=(APEX[0], APEX[2])))
sling = posed(rings("sling", [(0.028, -0.004), (0.028, 0.004)], 6, canvas, caps=(False, False)), (APEX[0], 0.15, APEX[2]), (0, 0, 1), math.pi / 2)
on(joined("hanging@timber", [limb("rope", APEX, (APEX[0], APEX[1] - 0.26, APEX[2]), 0.003, canvas),
                             log("hung log", (0.18, 0.15, -0.26), (0.42, 0.15, -0.26), 0.024), sling]), rig, "hanging@timber")
# Stumps and sawn planks.
for p in ((-0.36, 0.0, 0.18), (-0.18, 0.0, 0.3)):
    far.append(stump("stump", p))
far += planks((0.05, 0.0, 0.28), 0.24, 3)
# A woodshed roofed in the alliance's colour.
shed, shed_close = hall_at("woodshed", (0.3, 0.0, 0.26), 0.2, 0.14, 0.12, grey, house, 0.7, turn=math.pi / 2)
far += shed
close += shed_close
# Firewood stacked along its west wall, under its eaves.
for x, y in ((0.219, 0.014), (0.199, 0.014), (0.209, 0.032)):
    far.append(log("firewood", (x, y, 0.18), (x, y, 0.34), 0.01))
# The axe in the stump.
far.append(cbox("axe head", (-0.17, 0.05, 0.31), (0.012, 0.03, 0.05), iron, turn=0.6))
far.append(beam("axe haft", (-0.18, 0.035, 0.3), (-0.12, 0.13, 0.35), 0.01, pale))
# Its pennant a little in from the yard's edge, clear of the trough.
far += pennant((0.44, 0.0, 0.36), "timber")
joined(tagged("timber yard", tag), far)
joined(tagged("timber yard close", tag) + "!fine", close)


# MARK: The quarry

tag = ["stone"]
far, close = [], []
far.append(block("quarry floor", (-0.5, -0.08, -0.42), (0.5, 0.004, 0.42), quarry_floor))
# The face, cut back in benches toward the back of the hex, each bench's
# back a hair inside the one above's, never in one plane with it.
for bench in range(4):
    y = bench * 0.07
    z = -0.18 - bench * 0.055
    back = -0.419 + 0.0015 * (3 - bench)
    far.append(block("bench", (-0.46 + bench * 0.03, -0.04, back), (0.2 - bench * 0.02, y + 0.07, z), pale_stone if bench % 2 == 0 else stone))
far.append(rock("crag", (-0.36, 0.26, -0.38), (0.14, 0.12, 0.08), 141, rough, bands=4, sides=8, jitter=0.2))
# Close: ladders up the benches, chips of stone at the face's foot.
close += ladder("ladder", (-0.1, 0.004, -0.15), (-0.1, 0.09, -0.183), 0.04, 3, pale)
close += ladder("ladder", (0.05, 0.07, -0.2), (0.05, 0.16, -0.238), 0.04, 3, pale)
for index in range(6):
    close.append(rock("chip", (-0.37 + index * 0.1 + 0.03 * unit(index, 11, 171), 0.008, -0.12 + 0.03 * unit(index, 12, 171)),
                      (0.012, 0.008, 0.01), 180 + index, pale_stone if index % 2 else rough, bands=2, sides=4, jitter=0.3))
# The derrick: a mast and its stays, a boom out over the yard, a block on its rope.
far.append(limb("mast", MAST, (MAST[0], 0.5, MAST[2]), 0.013, timber, caps=(False, True)))
for stay in ((0.44, 0.0, -0.36), (0.46, 0.0, -0.06)):
    far.append(limb("stay", (MAST[0], 0.5, MAST[2]), stay, 0.002, canvas))
END = (MAST[0] - 0.26, 0.42, MAST[2] + 0.12)
# The boom held up from the mast's head by its topping lift, which stands
# on the mast's line and so slews with it; the block's rope reaching it.
on(joined("boom@stone", [limb("boom", (MAST[0], 0.08, MAST[2]), END, 0.009, timber, caps=(True, True)),
                         limb("topping lift", (MAST[0], 0.5, MAST[2]), END, 0.0015, canvas, sides=3),
                         limb("boom rope", END, (END[0], END[1] - 0.27, END[2]), 0.003, canvas),
                         cbox("hoisted block", (END[0], END[1] - 0.29, END[2]), (0.07, 0.05, 0.06), pale_stone)]), rig, "boom@stone")
# The windlass on its axle out from the mast.
on(joined("windlass@stone", spoked("windlass", HUB, 0.05, 0.012, 6, dark, dark, axis="x", sides=10) +
          [limb("windlass axle", (MAST[0], HUB[1], HUB[2]), (HUB[0] - 0.008, HUB[1], HUB[2]), 0.004, dark, sides=6)]), rig, "windlass@stone")
# Dressed blocks stacked for carting, and rubble.
far += dressed((-0.25, 0.0, 0.12), 9, 151)
far += dressed((0.02, 0.0, 0.22), 6, 152)
for index in range(5):
    far.append(rock("rubble", (-0.42 + index * 0.05, 0.02, -0.08 + unit(index, 9, 153) * 0.06), (0.035, 0.025, 0.03), 160 + index, rough,
                    bands=2, sides=4, jitter=0.3))
# Close, a mason's mallet and chisel left on the stack.
close.append(cbox("mallet head", (0.01, 0.091, 0.232), (0.014, 0.014, 0.024), dark))
close.append(beam("mallet haft", (0.017, 0.088, 0.232), (0.05, 0.088, 0.245), 0.005, pale))
close.append(cbox("chisel", (0.0, 0.0855, 0.212), (0.03, 0.004, 0.004), steel, turn=0.3))
# A sledge with a block on it, the block sat on its deck.
sledge = [block("runner", (x - 0.008, 0.0, -0.09), (x + 0.008, 0.018, 0.09), dark) for x in (-0.04, 0.04)]
sledge.append(block("deck", (-0.055, 0.018, -0.075), (0.055, 0.028, 0.075), timber))
sledge.append(cbox("sledged block", (0.0, 0.058, 0.0), (0.08, 0.06, 0.1), pale_stone))
for obj in sledge:
    placed(obj, (0.24, 0.0, 0.12), 0.5)
far += sledge
# The masons' lodge.
lodge, lodge_close = hall_at("lodge", (0.36, 0.0, 0.3), 0.18, 0.13, 0.11, stone, house, 0.65)
far += lodge
close += lodge_close
far.append(door("lodge door", (0.36, 0.06, 0.367), 0.04, 0.07, 0.0))
far += pennant((-0.44, 0.0, 0.36), "stone")
joined(tagged("quarry", tag), far)
joined(tagged("quarry close", tag) + "!fine", close)


# MARK: The salt works

def salt_pan(at_point, size, crust_share):
    """MeshBuilder.saltPan: a shallow pan of brine in a rim of stone, its
    crust of moonsalt lying on the brine."""
    x0, y0, z0 = at_point
    h, rim = size / 2, 0.016
    corners = ((-h, -h), (h, -h), (h, h), (-h, h))
    pieces = []
    for index, ((ax, az), (cx, cz)) in enumerate(zip(corners, corners[1:] + corners[:1])):
        # Those along z a hair shallower, so the rims' faces never share a plane where they cross.
        pieces.append(beam("pan rim", (x0 + ax, y0 + 0.008, z0 + az), (x0 + cx, y0 + 0.008, z0 + cz), rim, pale_stone,
                           depth=0.04 - 0.001 * (index % 2)))
    pieces.append(block("brine", (x0 - h, y0 - 0.02, z0 - h), (x0 + h, y0 + 0.006, z0 + h), loam))
    c = h * 0.92 * crust_share
    pieces.append(block("crust", (x0 - c, y0 + 0.006, z0 - c), (x0 + c, y0 + 0.016, z0 + c), crust))
    return pieces


tag = ["moonsalt"]
far, close = [], []
far.append(block("salt flat", (-0.5, -0.08, -0.42), (0.5, 0.004, 0.42), salt_ground))
# Pans in rows, some crusted thick, some still wet.
for row in range(2):
    for column in range(3):
        far += salt_pan((-0.36 + column * 0.2, 0.0, -0.26 + row * 0.2), 0.17, 0.95 if (row + column) % 2 == 0 else 0.6)
# The brine well, the brine standing in it, and its windlass.
far.append(rings("well", [(0.07, -0.02), (0.07, 0.06), (0.055, 0.065), (0.055, 0.02)], 8, stone, centre=(WELL[0], WELL[2])))
far.append(rings("well brine", [(0.0545, 0.019), (0.0545, 0.03)], 8, water, centre=(WELL[0], WELL[2])))
for x in (-0.07, 0.07):
    far.append(cbox("well post", (WELL[0] + x, 0.09, WELL[2]), (0.014, 0.18, 0.014), dark))
on(joined("windlass@moonsalt", [limb("drum", (AXLE[0] - 0.08, AXLE[1], AXLE[2]), (AXLE[0] + 0.08, AXLE[1], AXLE[2]), 0.012, timber,
                                     caps=(True, True))] +
          spoked("crank", (AXLE[0] + 0.1, AXLE[1], AXLE[2]), 0.035, 0.01, 4, dark, dark, axis="x")), rig, "windlass@moonsalt")
far.append(limb("well rope", (WELL[0], 0.15, WELL[2]), (WELL[0], 0.07, WELL[2]), 0.003, canvas))
far.append(rings("bucket", [(0.018, 0.05), (0.022, 0.08)], 6, pale, centre=(WELL[0], WELL[2])))
# The boiling house, its fire at its mouth and its chimney, whose top is
# where the smoke rises.
works, works_close = hall_at("boiling house", HOUSE, 0.18, 0.16, 0.13, stone, house, 0.7)
far += works
close += works_close
far.append(cbox("chimney", (SALT_SMOKE[0], (0.04 + SALT_SMOKE[1]) / 2, SALT_SMOKE[2]), (0.045, SALT_SMOKE[1] - 0.04, 0.045), dark_stone))
on(joined("fire@moonsalt", [cbox("fire", (HOUSE[0], 0.035, HOUSE[2] + 0.083), (0.07, 0.04, 0.012), fire)]), rig, "fire@moonsalt")
# Fuel stacked by the fire's mouth.
for x, y in ((0.235, 0.013), (0.255, 0.013), (0.245, 0.03)):
    far.append(log("fuel", (x, y, 0.262), (x, y, 0.312), 0.009))
# Close: jambs and a lintel of stone about the fire's mouth, a course
# about the chimney below its top, a rake leant on the boiling house.
close.append(cbox("fire lintel", (HOUSE[0], 0.062, HOUSE[2] + 0.086), (0.094, 0.014, 0.016), dark_stone))
for side in (-1, 1):
    close.append(cbox("fire jamb", (HOUSE[0] + side * 0.042, 0.03, HOUSE[2] + 0.086), (0.014, 0.06, 0.014), dark_stone))
close.append(cbox("chimney course", (SALT_SMOKE[0], 0.335, SALT_SMOKE[2]), (0.051, 0.01, 0.051), stone))
close.append(beam("rake haft", (0.195, 0.004, 0.135), (0.226, 0.128, 0.135), 0.005, pale))
close.append(cbox("rake head", (0.2255, 0.132, 0.135), (0.006, 0.01, 0.05), pale))
# The iron pan, the moonsalt crusting in it (the game's crust lay buried
# within a solid pan).
PAN = (HOUSE[0] - 0.17, HOUSE[2])
far.append(rings("pan", [(0.06, 0.0), (0.06, 0.04), (0.055, 0.045), (0.05, 0.045), (0.05, 0.025)], 8, iron, centre=PAN))
far.append(rings("panned salt", [(0.05, 0.036), (0.0, 0.043)], 8, moonsalt, centre=PAN))
# Heaps of moonsalt and sacks of it ready for carting.
far.append(salt_heap("salt heap", (-0.3, 0.0, 0.24), 0.07, 0.09))
far.append(salt_heap("salt heap", (-0.16, 0.0, 0.3), 0.055, 0.07))
for index, p in enumerate(((0.0, 0.0, 0.26), (0.05, 0.0, 0.3), (0.02, 0.045, 0.28))):
    far.append(sack("salt sack", p, 0.03, 170 + index, linen))
far += pennant((-0.44, 0.0, 0.38), "moonsalt")
joined(tagged("salt works", tag), far)
joined(tagged("salt works close", tag) + "!fine", close)


# MARK: Every yard's odds and ends

def footprint(variant):
    """Works.Footprint: the cells a hundredth across, within 0.34 of the
    heart, over which anything of a variant rises higher than 0.015."""
    cells = 68

    def index(value):
        return min(max(int(math.floor((value + 0.34) / 0.01)), 0), cells - 1)
    taken = [[False] * cells for _ in range(cells)]
    for obj in sorted((o for o in bpy.context.scene.objects if o.type == "MESH" and drawn(o.name, 1, variant)), key=lambda o: o.name):
        m = obj.matrix_world
        mesh = obj.data
        mesh.calc_loop_triangles()
        points = [m @ v.co for v in mesh.vertices]
        for tri in mesh.loop_triangles:
            corners = [points[i] for i in tri.vertices]
            if max(p.z for p in corners) / UNIT <= 0.015:
                continue
            xs = [p.x / UNIT for p in corners]
            zs = [-p.y / UNIT for p in corners]
            for row in range(index(min(zs)), index(max(zs)) + 1):
                for column in range(index(min(xs)), index(max(xs)) + 1):
                    taken[row][column] = True
    return lambda x, z, r: not any(taken[row][column] for row in range(index(z - r), index(z + r) + 1)
                                   for column in range(index(x - r), index(x + r) + 1))


def odds_and_ends(variant, name, top):
    """Works.yard: barrels, crates, sacks, a bucket, a bench and a stack of
    logs set down where nothing of the yard stands, apart from each other
    and clear of the way in, the same for the same yard each time; on the
    ground's own face (the game's stood a little above a yard's)."""
    free = footprint(variant)
    seed = named_seed(name)
    spots, pieces = [], []
    for step in range(64):
        if len(spots) >= 4:
            break
        angle = step * 2.39996 + unit(step, 31, seed) * 0.5
        radius = 0.17 + 0.1 * unit(step, 32, seed)
        x, z = radius * math.cos(angle), radius * math.sin(angle)
        if (abs(x) < 0.08 and z > 0) or not free(x, z, 0.035) or not all(math.hypot(x - sx, z - sz) > 0.075 for sx, sz in spots):
            continue
        spots.append((x, z))
        turn = unit(step, 33, seed) * 2 * math.pi
        kind = int(unit(step, 34, seed) * 6)
        p = (x, top, z)
        if kind == 0:
            pieces.append(rings("barrel", [(0.021, top), (0.025, top + 0.026), (0.021, top + 0.052)], 7, timber, centre=(x, z)))
            pieces.append(rings("hoop", [(0.0235, top + 0.012), (0.0255, top + 0.015), (0.0235, top + 0.018)], 7, iron, centre=(x, z),
                                caps=(False, False)))
        elif kind == 1:
            pieces.append(cbox("crate", (x, top + 0.02, z), (0.04, 0.04, 0.04), pale, turn=turn))
            pieces.append(cbox("crate", (x, top + 0.054, z), (0.03, 0.028, 0.03), grey, turn=turn + 0.4))
        elif kind == 2:
            pieces.append(sack("sack", (x - 0.012, top, z), 0.022, seed + step))
            pieces.append(sack("sack", (x + 0.014, top, z + 0.006), 0.019, seed + step + 1))
        elif kind == 3:
            pieces.append(rings("bucket", [(0.013, top), (0.016, top + 0.026)], 6, dark, centre=(x, z)))
            pieces.append(limb("handle", (x - 0.015, top + 0.026, z), (x, top + 0.04, z), 0.002, iron, sides=3))
            pieces.append(limb("handle", (x, top + 0.04, z), (x + 0.015, top + 0.026, z), 0.002, iron, sides=3))
        elif kind == 4:
            bench = [cbox("bench", (0.0, 0.026, 0.0), (0.06, 0.006, 0.016), pale)]
            bench += [cbox("trestle", (bx, 0.012, 0.0), (0.006, 0.024, 0.014), timber) for bx in (-0.022, 0.022)]
            pieces += [placed(obj, p, turn) for obj in bench]
        else:
            stack = [log("log", (lx, ly, -0.026), (lx, ly, 0.026), 0.009) for lx, ly in ((-0.01, 0.009), (0.01, 0.009), (0.0, 0.025))]
            pieces += [placed(obj, p, turn) for obj in stack]
    return pieces


TOPS = {"storehouse": PAD_TOP, "grain": 0.006, "timber": 0.004, "stone": 0.004, "moonsalt": 0.004}
NAMES = {"storehouse": "storehouse", "grain": "grain yard", "timber": "timber yard", "stone": "stone yard", "moonsalt": "moonsalt yard"}
for variant in VARIANTS:
    # Each variant's joined and tagged before the next's footprint is taken.
    odds = odds_and_ends(variant, NAMES[variant], TOPS[variant])
    if odds:
        joined(tagged("odds and ends", [variant]) + "!fine", odds)

# The storehouse's pulley turning and its sack swinging; the timber yard's
# log swinging out from its sheerlegs and back; the derrick slewing and its
# windlass turning; the salt works' windlass turning and its fire leaping.
idle(rig, turns=[("pulley@storehouse", X, wheel_turns(1)),
                 ("load@storehouse", X, lambda u: 0.12 * swing(u)),
                 ("hanging@timber", X, lambda u: -0.18 * swing(u)),
                 ("boom@stone", UP, lambda u: 0.5 * swing(u)),
                 ("windlass@stone", X, wheel_turns(1)),
                 ("windlass@moonsalt", X, wheel_turns(1))],
     stretches=[("fire@moonsalt", leaping)])

finish_building(out_path("Art/models/stores.glb"), VARIANTS)
