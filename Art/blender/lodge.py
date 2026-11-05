"""The Masons' Lodge, where the House's masons learn to cut and lay stone, its
five levels the tiers of one file, each within a work's slot and facing +z:
1. an open shed of timber under thatch over a banker where a block is
   dressed, a jib on its post to lift stone, rough blocks heaped, the
   masons' tools on their rack;
2. the shed walled in planks at its back and its west under slate, a second
   banker, squared blocks stacked;
3. a hall of white stone, gabled and slated, its door and lit windows, its
   walls dressed in ashlar, scaffold against its east gable while it is
   raised; a tracing floor of pale slabs before it where a work is drawn
   out full size, the jib beside;
4. a treadwheel crane in its frames at the hall's side, a block slung from
   its jib; buttresses and a chimney on the hall;
5. a carved arch over the yard's way in, a moonsalt finial on the ridge, a
   dormer on each slope and the House's banners at the door.
At every level a dry-stone wall along the yard's front, a course higher at
each of the first three levels (opened under the arch at the fifth), a
barrow with a block in it and a trough of lime.
Close: chips of stone strewn about the yard, the shed's braces, the
bankers' dressed faces, mallets, chisels and chips, the tools on their
rack, the hall's courses, hoods, ashlar, roof courses, gable boards and
rafters, the lines and the arch scored on the tracing floor, the
treadwheel's treads, the keystone's mark and the arch's bosses.
The jib slews its stone out and back as the masons work; the treadwheel
turns.

    python Art/blender/lodge.py Art/models/lodge.glb
"""
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

yard = material("plain_earth_yard", (0.31, 0.29, 0.25))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
white = material("plain_stone_white", (0.84, 0.84, 0.82))
# The hall's ashlar, a shade under its walls' white (Palette.stoneWhite * 0.96).
ashlar_white = material("plain_stone_ashlar", (0.806, 0.806, 0.787))
rock_grey = material("plain_stone_rock", (0.4, 0.4, 0.42))
slate = material("plain_slate", (0.23, 0.24, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
linen = material("plain_linen", (0.7, 0.67, 0.6))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.4, metallic=0.7)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.35, metallic=0.8)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))
moonsalt = material("glow_moonsalt", (0.88, 0.91, 0.95))

# The jib's foot at each level. The game's stood its second level's jib
# under the shed's eaves and its last three's footing in the wall; here
# each stands clear of both.
JIBS = {1: (-0.2, 0.0, 0.14), 2: (-0.2, 0.0, 0.14), 3: (-0.22, 0.0, 0.11), 4: (-0.22, 0.0, 0.11), 5: (-0.22, 0.0, 0.11)}
# The treadwheel crane's foot, and the hub its wheel turns on.
CRANE = (0.21, 0.0, -0.03)
HUB = (CRANE[0], 0.085, CRANE[2])
WHEELS = [4, 5]
# The hall's foot, from the third level.
HALL = (-0.03, 0.0, -0.1)

rig = work_rig([("lodge jib@%d" % level, foot, (0, 1, 0)) for level, foot in JIBS.items()]
               + [("treadwheel@%d" % level, HUB, (0, 0, 1)) for level in WHEELS])
ground(pad(tagged("pad", []), 0.31, yard), rig)

chance = random.Random(4261)


# MARK: Shapes as the game's own are built

TO_BLENDER = Matrix(((UNIT, 0, 0, 0), (0, 0, -UNIT, 0), (0, UNIT, 0, 0), (0, 0, 0, 1)))
FROM_BLENDER = TO_BLENDER.inverted()


def moved(obj, placement):
    """A piece carried by `placement`, a matrix in the world's axes and
    units, as the game places a solid."""
    obj.data.transform(TO_BLENDER @ placement @ FROM_BLENDER)
    return obj


def shift(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def turn_x(angle):
    return Matrix.Rotation(angle, 4, "X")


def joined(name, pieces):
    """Pieces joined into one object so named."""
    pieces = list(pieces)
    if len(pieces) == 1:
        pieces[0].name = name
        return pieces[0]
    return join(name, pieces)


def hidden(obj, *directions):
    """A piece with its faces that look along these directions (the world's)
    taken away: those set on what it stands on or against what it is laid
    on, never seen."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    looks = [Vector((d[0], -d[2], d[1])).normalized() for d in directions]
    gone = [f for f in bm.faces if any(f.normal.dot(look) > 0.999 for look in looks)]
    bmesh.ops.delete(bm, geom=gone, context="FACES_ONLY")
    bm.to_mesh(obj.data)
    bm.free()
    return obj


DOWN = (0, -1, 0)


def box(name, centre, size, mat, turn=0.0, chamfer=0.0):
    """A box about its centre, turned about the upright as the game turns it
    (MeshBuilder.box(center:size:turn:)); block turns the other way."""
    low = tuple(c - s / 2 for c, s in zip(centre, size))
    high = tuple(c + s / 2 for c, s in zip(centre, size))
    return block(name, low, high, mat, chamfer=chamfer, turn=-turn, about=tuple(centre))


def beam(name, a, b, width, mat, depth=None):
    """A squared timber from one point to another, squared as the game
    squares one (MeshBuilder.beam): `width` across, level if it lies, east
    to west if it stands, and `depth` through."""
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
    """A pole of `sides` faces from one point to another, narrowing to `top`,
    its ends left open for what it stands in to hide (MeshBuilder.limb)."""
    r0, r1 = radius * UNIT, (radius if top is None else top) * UNIT
    return loft(name, [(tuple(at(*a)), r0, r0, {}), (tuple(at(*b)), r1, r1, {})], segments=sides, mat=mat, caps=caps, smooth=False)


def sphere(name, centre, radius, mat, bands=4, sides=6, squash=1.0):
    """A faceted ball, squashed to `squash` of its height."""
    profile = []
    for band in range(bands + 1):
        angle = math.pi * band / bands - math.pi / 2
        r = 0.0 if band in (0, bands) else radius * math.cos(angle)
        profile.append((r, centre[1] + radius * squash * math.sin(angle)))
    return rings(name, profile, sides, mat, centre=(centre[0], centre[2]))


def hexahedron(name, corners, mat, chamfer=0.0):
    """A solid of six faces from its eight corners (the world's): the four
    of one face, then the four of the face across from it in the same
    order; its edges cut back by `chamfer` if given."""
    def build(bm):
        v = [bm.verts.new(at(*c)) for c in corners]
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            bm.faces.new([v[i] for i in f])
        if chamfer > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=chamfer * UNIT, segments=1, affect="EDGES", clamp_overlap=True)
    return mesh_object(name, build, mat)


def strided(start, end, step):
    """The values from `start` by `step` short of `end`, as the game's
    stride(from:to:by:) counts them."""
    values = []
    while start + len(values) * step < end - 1e-6:
        values.append(start + len(values) * step)
    return values


def piece(name, levels, far, fine=()):
    """Pieces for these levels joined, far and near."""
    tags = level_tags(levels)
    if far:
        joined(tagged(name, tags), far)
    if fine:
        joined(tagged(name + " close", tags) + "!fine", fine)


def moving(name, level, bone, far, fine=()):
    """A level's moving part, its pieces joined, far and near, and hung on
    its bone."""
    tags = level_tags([level])
    on(joined(tagged(name, tags), far), rig, "%s@%d" % (bone, level))
    if fine:
        on(joined(tagged(name + " close", tags) + "!fine", fine), rig, "%s@%d" % (bone, level))


# MARK: The yard

def chips():
    """Chips and dust of the work strewn about the yard."""
    stones = []
    for index in range(14):
        angle = index * 2.39996
        r = 0.12 + 0.15 * ((index * 37) % 11) / 11
        stones.append(hidden(box("chip", (r * math.cos(angle), 0.014, r * math.sin(angle)), (0.012, 0.006, 0.009),
                                 white if index % 3 == 0 else pale_stone, turn=angle), DOWN))
    return stones


def boundary():
    """A dry-stone wall along the yard's front, a course higher at each of
    the first three levels, each stone laid along its arc a little askew
    (the game's turned its stones round the ring); at the fifth it is opened
    under the arch, the yard's way in."""
    for course in range(3):
        kept, gate = [], []
        for index in range(18):
            angle = math.pi * (1.08 + 0.84 * index / 17) + (0.0 if course % 2 == 0 else 0.5 * 0.84 * math.pi / 18)
            centre = on_ring(0.295, 0.012 + course * 0.02, angle)
            shade = (stone, pale_stone, rock_grey)[(index + course) % 3]
            askew = 0.1 * (chance.random() - 0.5)
            laid = hidden(box("field stone", centre, (0.05, 0.019, 0.026), shade, turn=angle + math.pi / 2 + askew), DOWN)
            (gate if abs(centre[0]) < 0.07 else kept).append(laid)
        levels = list(range(course + 1, 6))
        joined(tagged("lodge wall", level_tags(levels) if course else []), kept)
        joined(tagged("lodge wall gate", level_tags([level for level in levels if level < 5])), gate)


def barrow_wheel(centre, radius, width):
    """The barrow's wheel on its axle along z, shod in iron (the game's
    stood its wheel across its way)."""
    disc = rings("barrow wheel", [(radius, -width / 2), (radius, width / 2)], 8, dark, twist=math.pi / 8)
    disc.data.materials.append(iron)
    for poly in disc.data.polygons:
        if abs(poly.normal.z) < 0.5:
            poly.material_index = 1
    return moved(disc, shift(*centre) @ turn_x(math.pi / 2))


def barrow(at_point):
    """A barrow of timber on its iron-shod wheel, a block in it, stood on its
    wheel and legs (the game's sank them in the ground), its handles turned
    from the wall."""
    lift = 0.01
    pieces = [block("barrow tray", (-0.03, 0.025 + lift, -0.02), (0.03, 0.05 + lift, 0.02), timber),
              barrow_wheel((0.04, 0.018 + lift, 0.0), 0.018, 0.008)]
    for z in (-0.016, 0.016):
        pieces.append(beam("barrow handle", (0.04, 0.02 + lift, z), (-0.07, 0.045 + lift, z), 0.005, dark))
        pieces.append(limb("barrow leg", (-0.02, 0.025 + lift, z), (-0.02, lift - 0.002, z), 0.003, dark))
    pieces.append(box("barrow block", (0.0, 0.058 + lift, 0.0), (0.03, 0.02, 0.025), pale_stone, chamfer=0.002))
    for obj in pieces:
        placed(obj, at_point, -0.5)
    return pieces


def lime_trough(at_point):
    """A trough of lime mortar, the lime to its brim, its paddle across it."""
    x0, _, z0 = at_point
    return [hidden(block("trough", (x0 - 0.04, 0.0, z0 - 0.02), (x0 + 0.04, 0.03, z0 + 0.02), dark), DOWN),
            hidden(block("lime", (x0 - 0.036, 0.026, z0 - 0.016), (x0 + 0.036, 0.031, z0 + 0.016), white), DOWN),
            beam("paddle", (x0 - 0.05, 0.033, z0), (x0 + 0.04, 0.039, z0 + 0.01), 0.004, pale)]


def heap(at_point, rough, seed=0):
    """Blocks heaped, rough from the quarry, or squared and stacked course on
    course."""
    x0, _, z0 = at_point
    pieces = []
    if rough:
        for index in range(5):
            angle = index * 1.3
            pieces.append(rock("rough block", (x0 + 0.03 * math.sin(angle), 0.018 + (index // 3) * 0.025, z0 + 0.03 * math.cos(angle)),
                               (0.032, 0.026, 0.028), seed + index, stone))
    else:
        for course in range(3):
            for index in range(3 - course):
                # Each course sat on the one below (the game's stood 2 mm off it).
                pieces.append(hidden(box("squared block", (x0 - 0.03 + index * 0.03 + course * 0.015, 0.014 + course * 0.028, z0),
                                         (0.028, 0.028, 0.05), pale_stone if course % 2 == 0 else stone), DOWN))
    return pieces


def tool_rack(at_point):
    """The masons' tools on their rack: mallets and chisels, a square."""
    x0, _, z0 = at_point
    far = [limb("rack post", (x0 + x, 0.0, z0), (x0 + x, 0.12, z0), 0.005, dark, caps=(False, True)) for x in (-0.04, 0.04)]
    far.append(beam("rack rail", (x0 - 0.05, 0.11, z0), (x0 + 0.05, 0.11, z0), 0.008, timber))
    fine = []
    for index, x in enumerate((-0.03, -0.012, 0.006, 0.024)):
        length = 0.04 + (index % 2) * 0.02
        fine.append(limb("tool", (x0 + x, 0.11, z0 + 0.006), (x0 + x, 0.105 - length, z0 + 0.008), 0.003, pale if index % 2 == 0 else iron,
                         caps=(False, True)))
    # The square hung from the rail (the game's hung a little below it).
    fine.append(beam("square", (x0 + 0.032, 0.11, z0 + 0.006), (x0 + 0.032, 0.06, z0 + 0.006), 0.004, iron))
    fine.append(beam("square", (x0 + 0.032, 0.06, z0 + 0.006), (x0 + 0.05, 0.06, z0 + 0.006), 0.004, iron))
    return far, fine


def banker(at_point, laden):
    """A banker: a mason's bench of two stone legs and a slab, a block on it
    half dressed if `laden`; close, its dressed face, a mallet and chisel
    laid by and the chips at its foot."""
    x0, _, z0 = at_point
    far = [hidden(box("banker leg", (x0 + x, 0.03, z0), (0.022, 0.06, 0.05), dark_stone), DOWN) for x in (-0.035, 0.035)]
    far.append(box("banker", (x0, 0.066, z0), (0.1, 0.012, 0.06), stone))
    fine = []
    if laden:
        far.append(box("banker block", (x0, 0.094, z0), (0.06, 0.044, 0.04), pale_stone, turn=0.15, chamfer=0.003))
        # Its dressed face (the game's hung it over an empty banker too).
        fine.append(hidden(box("dressed face", (x0 + 0.012, 0.118, z0), (0.036, 0.004, 0.026), white, turn=0.15), DOWN))
    fine += [limb("mallet haft", (x0 + 0.04, 0.074, z0 + 0.02), (x0 + 0.07, 0.074, z0 + 0.025), 0.003, pale, caps=(True, True)),
             box("mallet", (x0 + 0.036, 0.077, z0 + 0.02), (0.012, 0.01, 0.01), dark),
             beam("chisel", (x0 - 0.045, 0.074, z0 + 0.02), (x0 - 0.015, 0.074, z0 + 0.022), 0.004, steel),
             # The chips heaped at its foot, on the ground (the game's lay under it).
             sphere("chips", (x0, 0.012, z0 + 0.045), 0.025, pale_stone, bands=2, sides=6, squash=0.25)]
    return far, fine


def jib(level):
    """The jib on its post, its arm slewing with a block slung from it.
    Returns the footing and post; the arm hangs on its bone."""
    x0, _, z0 = JIBS[level]
    arm = [beam("jib arm", (x0, 0.22, z0), (x0 + 0.14, 0.21, z0), 0.012, timber),
           beam("jib strut", (x0, 0.12, z0), (x0 + 0.09, 0.215, z0), 0.007, timber),
           limb("jib fall", (x0 + 0.13, 0.205, z0), (x0 + 0.13, 0.113, z0), 0.002, linen),
           box("jib load", (x0 + 0.13, 0.1, z0), (0.035, 0.03, 0.03), pale_stone, chamfer=0.003)]
    moving("lodge jib arm", level, "lodge jib", arm, [box("jib sheave", (x0 + 0.13, 0.205, z0), (0.014, 0.02, 0.012), iron)])
    return [hidden(box("jib footing", (x0, 0.012, z0), (0.05, 0.024, 0.05), stone), DOWN),
            limb("jib post", (x0, 0.0, z0), (x0, 0.24, z0), 0.01, dark, caps=(False, True))]


# MARK: The shed of the first two levels

def shed(walled, roofing, eaves):
    """The open shed: six posts, braced, under a gable whose thickness rises
    over its wall plates; walled at the back and the west in planks, a lit
    window in its west wall, at the second level."""
    w, d, h = 0.3, 0.2, 0.15
    far, fine = [], []
    for x in (-w / 2, 0.0, w / 2):
        for z in (-d / 2, d / 2):
            far.append(limb("shed post", (x, -0.02, z), (x, h, z), 0.009, timber))
            fine.append(beam("shed brace", (x, h * 0.65, z), (x + (0.04 if x <= 0 else -0.04), h, z), 0.005, dark))
    for z in (-d / 2, d / 2):
        far.append(beam("wall plate", (-w / 2 - 0.01, h, z), (w / 2 + 0.01, h, z), 0.012, dark))
    far.append(gable_roof("shed roof", (0.0, 0.0), d, w, h + eaves, 0.08 - eaves, roofing, overhang=0.025, along="x", thickness=eaves))
    far.append(beam("shed ridge", (-w / 2 - 0.03, h + 0.083, 0.0), (w / 2 + 0.03, h + 0.083, 0.0), 0.01, dark))
    if walled:
        for index in range(9):
            x = -w / 2 + w * (index + 0.5) / 9
            far.append(hidden(box("board", (x, h / 2 - 0.01, -d / 2), (w / 9 - 0.003, h + 0.02, 0.012), grey if index % 2 == 0 else timber),
                              DOWN))
        for index in range(6):
            z = -d / 2 + d * (index + 0.5) / 6
            far.append(hidden(box("board", (-w / 2, h / 2 - 0.01, z), (0.012, h + 0.02, d / 6 - 0.003), timber if index % 2 == 0 else grey),
                              DOWN))
        far.append(lit("shed window", (-w / 2 - 0.007, h * 0.6, 0.02), 0.03, 0.025, -math.pi / 2, window))
    return far, fine


# MARK: The hall of the last three levels

def hall_size(level):
    """The hall's width, depth and height at a level."""
    return (0.3 if level >= 4 else 0.26), 0.15, (0.17 if level >= 5 else 0.14)


def buttress(x, wall, top):
    """A buttress against the hall's back wall, its face at `wall`: from
    under the ground to `top` at the wall, its head weathered down away
    from it (the game's stood a square block just off the wall)."""
    half, low = 0.011, -0.04
    inner, outer = wall + 0.003, wall - 0.031
    corners = [(x - half, low, inner), (x + half, low, inner), (x + half, low, outer), (x - half, low, outer),
               (x - half, top, inner), (x + half, top, inner), (x + half, top - 0.02, outer), (x - half, top - 0.02, outer)]
    return hidden(hexahedron("buttress", corners, stone), DOWN, (0, 0, 1))


def dormer(side, h, rise):
    """A dormer on a slope of the hall's roof: its gabled front of white
    stone standing out of the slope, a lit window in it, its slates running
    back to the hall's ridge (the game's sat sunk in the slope under a
    ridge along the hall's)."""
    x0, _, z0 = HALL
    middle = z0 + side * 0.033
    front, back = middle + side * 0.025, middle - side * 0.025
    eave, peak = h + 0.08, h + rise
    outline = [(x0 - 0.035, h + 0.02), (x0 + 0.035, h + 0.02), (x0 + 0.035, eave), (x0, peak), (x0 - 0.035, eave)]
    far = [slab("dormer", [(x, y, middle) for x, y in outline], white, 0.05, normal=(0, 0, 1))]
    thick, over = 0.006, 0.008
    tip = front + side * over
    mid, length = (back + tip) / 2, abs(tip - back)
    for sx in (-1, 1):
        ex, ey = x0 + sx * 0.035, eave
        span = math.hypot(x0 - ex, peak - ey)
        ux, uy = (x0 - ex) / span, (peak - ey) / span
        nx, ny = sx * uy * thick / 2, -sx * ux * thick / 2
        far.append(beam("dormer slates", (ex - ux * over + nx, ey - uy * over + ny, mid), (x0 + ux * thick / 2 + nx, peak + uy * thick / 2 + ny, mid),
                        length, slate, depth=thick))
    far.append(hidden(lit("dormer window", (x0, h + 0.058, front), 0.022, 0.024, 0.0 if side > 0 else math.pi, window), (0, 0, -side)))
    return far


def lodge_hall(level):
    """The hall of white stone: gabled and slated on its footing, its frame
    dark, its door under a lintel and lit windows under their hoods, string
    courses across its front; buttressed with a chimney at the fourth; its
    dormers, finial and banners at the fifth."""
    x0, _, z0 = HALL
    w, d, h = hall_size(level)
    rise = d * 0.7
    far, fine = hall("hall", w, d, h, white, slate, dark, pitch=0.7, footing=stone)
    for obj in far + fine:
        placed(obj, HALL)
    front = z0 + d / 2
    # The door stands on the footing (the game's ran down into it, its face
    # on the footing's).
    far.append(hidden(block("door", (x0 - 0.0225, 0.035, front - 0.008), (x0 + 0.0225, 0.105, front + 0.011), dark), (0, 0, -1), DOWN))
    far.append(hidden(block("lintel", (x0 - 0.03, 0.106, front - 0.002), (x0 + 0.03, 0.118, front + 0.012), pale_stone), (0, 0, -1)))
    for x in (-w * 0.32, w * 0.32):
        far.append(hidden(lit("window", (x0 + x, h * 0.6, front + 0.002), 0.026, 0.04, 0.0, window), (0, 0, -1)))
        fine.append(hidden(block("hood", (x0 + x - 0.018, h * 0.6 + 0.022, front - 0.002), (x0 + x + 0.018, h * 0.6 + 0.03, front + 0.011), stone),
                           (0, 0, -1)))
    for y in strided(0.03, h, 0.028):
        if y > 0.042:
            # Those under the footing's top left off, hidden in it.
            fine.append(hidden(block("course", (x0 - w / 2 + 0.002, y - 0.0015, front - 0.0005), (x0 + w / 2 - 0.002, y + 0.0015, front + 0.0025),
                                     pale_stone), (0, 0, -1)))
    if level >= 4:
        for x in (-w / 2, -w / 6, w / 6, w / 2):
            far.append(buttress(x0 + x, z0 - d / 2, h * 0.7 + 0.04))
        far.append(hidden(block("chimney", (x0 + w / 2 - 0.07, h, z0 - 0.04), (x0 + w / 2 - 0.035, h + 0.15, z0 - 0.005), dark_stone), DOWN))
        fine.append(block("chimney cap", (x0 + w / 2 - 0.074, h + 0.15, z0 - 0.044), (x0 + w / 2 - 0.031, h + 0.162, z0 - 0.001), stone))
    if level >= 5:
        for side in (1, -1):
            far += dormer(side, h, rise)
        # The finial stands on the ridge (the game's hung over it).
        y = h + rise + 0.008
        far.append(rings("finial", [(0.0, y), (0.014, y + 0.012), (0.008, y + 0.035), (0.0, y + 0.06)], 8, moonsalt, centre=(x0, z0)))
        for x in (-0.05, 0.05):
            # The banners hung along their rods out of the wall (the game's
            # rods stood off it, their banners from their tips).
            far.append(limb("banner rod", (x0 + x, h * 0.8, front - 0.002), (x0 + x, h * 0.8, front + 0.06), 0.003, iron, caps=(False, True)))
            flag(tagged("lodge banner %s" % ("R" if x > 0 else "L"), ["5"]), (x0 + x, h * 0.8 - 0.003, front + 0.018), 0.036, 0.08, banner,
                 turn=-math.pi / 2, tail=True)
    return far, fine


def ashlar(level):
    """The hall's walls dressed in courses of ashlar, each block proud: on
    its back, and on its gables while it is narrow; its lowest course,
    hidden in the footing, left off."""
    x0, _, z0 = HALL
    w, d, h = hall_size(level)
    blocks = []
    for row in range(1, int(h / 0.034)):
        y = 0.022 + row * 0.034
        offset = 0.0 if row % 2 == 0 else 0.03
        for x in strided(-w / 2 + 0.03 + offset, w / 2 - 0.02, 0.06):
            blocks.append(hidden(box("ashlar", (x0 + x, y, z0 - d / 2 - 0.002), (0.056, 0.03, 0.004), ashlar_white), (0, 0, 1)))
        if w < 0.3:
            for z in strided(-d / 2 + 0.03 + offset, d / 2 - 0.02, 0.06):
                for side in (-1, 1):
                    blocks.append(hidden(box("ashlar", (x0 + side * (w / 2 + 0.002), y, z0 + z), (0.004, 0.03, 0.056), ashlar_white), (-side, 0, 0)))
    return blocks


def tracing_floor(at_point):
    """The tracing floor: pale slabs set a little proud of the yard before
    the hall (the game's lay level with it), a work drawn out on them full
    size in scored lines, an arch and its voussoirs' joints."""
    x0, _, z0 = at_point
    top = 0.018
    far = [hidden(block("tracing floor", (x0 - 0.11, 0.008, z0 - 0.055), (x0 + 0.11, top, z0 + 0.055), white), DOWN)]
    fine = []
    for x in (-0.1, -0.045, 0.01, 0.065):
        fine.append(hidden(block("scored line", (x0 + x - 0.001, top - 0.0005, z0 - 0.05), (x0 + x + 0.001, top + 0.0008, z0 + 0.05), stone), DOWN))
    for index in range(9):
        angle = math.pi * index / 8
        cx, cz = x0 + 0.06 * math.cos(angle), z0 - 0.03 + 0.06 * math.sin(angle)
        # Each joint drawn out from the arch's middle (the game's turned some across it).
        fine.append(hidden(block("joint line", (cx - 0.006, top - 0.0005, cz - 0.0012), (cx + 0.006, top + 0.001, cz + 0.0012), slate, turn=angle,
                                 about=(cx, top, cz)), DOWN))
    return far, fine


def scaffold(at_point):
    """Scaffold poles lashed against the hall's east gable while it is still
    being raised: standards, ledgers and three boards."""
    x0, _, z0 = at_point
    far = []
    for z in (-0.06, 0.0, 0.06):
        for x in (0.0, 0.04):
            far.append(limb("standard", (x0 + x, -0.02, z0 + z), (x0 + x, 0.25, z0 + z), 0.004, grey, caps=(False, True)))
    for y in (0.08, 0.16, 0.23):
        for x in (0.0, 0.04):
            far.append(beam("ledger", (x0 + x, y, z0 - 0.065), (x0 + x, y, z0 + 0.065), 0.004, grey))
        far.append(box("scaffold board", (x0 + 0.02, y + 0.004, z0), (0.045, 0.004, 0.13), pale))
    return far


def treadwheel():
    """The great wheel on its axle along z (the game's stood it across its
    frames): a drum of boards open at its faces, three spokes across each
    face, its axle through the frames; close, its treads across it inside."""
    hx, hy, hz = HUB
    outer, inner, half = 0.08, 0.072, 0.03
    far = [moved(rings("drum", [(inner, -half), (outer, -half), (outer, half), (inner, half), (inner, -half)], 12, timber, caps=(False, False)),
                 shift(*HUB) @ turn_x(math.pi / 2))]
    for z in (-half + 0.004, half - 0.004):
        for k in range(3):
            angle = math.pi / 6 + k * math.pi / 3
            dx, dy = inner * math.cos(angle), inner * math.sin(angle)
            far.append(beam("spoke", (hx - dx, hy - dy, hz + z), (hx + dx, hy + dy, hz + z), 0.006, dark))
    far.append(limb("axle", (hx, hy, hz - 0.044), (hx, hy, hz + 0.044), 0.006, dark, sides=6, caps=(True, True)))
    fine = []
    for index in range(12):
        angle = index / 12 * 2 * math.pi
        tread = block("tread", (-0.004, -0.004, -0.029), (0.004, 0.004, 0.029), pale)
        fine.append(posed(tread, (hx + 0.068 * math.cos(angle), hy + 0.068 * math.sin(angle), hz), (0, 0, 1), angle))
    return far, fine


def tread_crane(level):
    """The treadwheel crane at the hall's side: its two A-frames, the
    wheel turning between them, the crane's post behind them (the game's
    stood in the wheel) and its jib out over the yard, a block slung from
    it. Returns the frames, post, jib and load; the wheel hangs on its
    bone."""
    x0, _, z0 = CRANE
    hx, hy, hz = HUB
    far = []
    for z in (-0.035, 0.035):
        for x in (-0.06, 0.06):
            far.append(beam("crane frame", (x0 + x, 0.0, z0 + z), (hx, hy, hz + z), 0.009, dark))
    post, tip = (x0 - 0.04, 0.25, z0 - 0.055), (x0 + 0.06, 0.28, z0 + 0.08)
    far.append(limb("crane post", (post[0], 0.0, post[2]), (post[0], 0.27, post[2]), 0.009, dark, caps=(False, True)))
    far.append(beam("crane jib", post, tip, 0.009, timber))
    # The fall from the jib's head (the game's hung a little under it).
    t = (x0 + 0.055 - post[0]) / (tip[0] - post[0])
    head = tuple(p + (q - p) * t for p, q in zip(post, tip))
    far.append(limb("crane fall", (head[0], head[1] - 0.002, head[2]), (head[0], 0.168, head[2]), 0.002, linen))
    far.append(box("crane load", (head[0], 0.155, head[2]), (0.03, 0.028, 0.03), pale_stone, chamfer=0.003))
    wheel, treads = treadwheel()
    moving("lodge treadwheel", level, "treadwheel", wheel, treads)
    return far


def arch(at_point):
    """A carved arch over the yard's way in: two piers on their plinths (the
    game's sunk in the ground), its voussoirs cut to the ring and laid round
    it (the game's square ones stood upright), the keystone standing proud,
    carved with the House's mark; close, bosses at its springing."""
    x0, _, z0 = at_point
    far = []
    for x in (-0.07, 0.07):
        far.append(hidden(box("pier", (x0 + x, 0.065, z0), (0.028, 0.13, 0.03), white, chamfer=0.003), DOWN))
        far.append(hidden(box("plinth", (x0 + x, 0.017, z0), (0.036, 0.014, 0.038), stone), DOWN))
    for index in range(7):
        middle = math.pi * index / 6
        low, high = middle - math.pi / 12 + 0.015, middle + math.pi / 12 - 0.015
        key = index == 3
        # Each between the ring's inner and outer edges, a little deeper
        # than the piers so its faces are never in theirs.
        inner, outer, deep = -0.012, 0.012 + (0.005 if key else 0.0), 0.016 + (0.002 if key else 0.0)
        face = [(x0 + (0.07 + r) * math.cos(a), 0.13 + (0.06 + r) * math.sin(a)) for r, a in ((inner, low), (outer, low), (outer, high), (inner, high))]
        corners = [(x, y, z0 + z) for z in (-deep, deep) for x, y in face]
        far.append(hexahedron("voussoir", corners, pale_stone if key else white, chamfer=0.002 if key else 0.0))
    fine = [box("mark", (x0, 0.192, z0 + 0.018), (0.016, 0.018, 0.004), gold)]
    for x in (-0.07, 0.07):
        fine.append(sphere("boss", (x0 + x, 0.14, z0 + 0.016), 0.008, pale_stone, bands=2, sides=5))
    return far, fine


# MARK: The levels

# At every level: the barrow and the lime trough, the chips strewn about,
# the wall along the yard's front.
piece("lodge yard", [], [*barrow((-0.12, 0.0, 0.21)), *lime_trough((0.11, 0.0, 0.23))])
joined("lodge chips!fine", chips())
boundary()

# The open shed under thatch. (Its heaps set clear of the trough and the
# shed's posts, where the game's ran into them.)
far, fine = shed(False, thatch, 0.012)
more, close = banker((0.02, 0.0, 0.0), True)
rack, tools = tool_rack((0.19, 0.0, -0.15))
piece("lodge", [1], far + more + rack + heap((0.005, 0.0, 0.2), True, 11) + heap((0.21, 0.0, 0.04), True, 21) + jib(1), fine + close + tools)

# The shed walled and slated, a second banker, squared blocks stacked.
# (Its heaps set clear of the barrow and the wall.)
far, fine = shed(True, slate, 0.008)
one, one_close = banker((-0.04, 0.0, 0.0), True)
two, two_close = banker((0.09, 0.0, 0.0), False)
rack, tools = tool_rack((0.2, 0.0, -0.14))
piece("lodge", [2], far + one + two + rack + heap((0.19, 0.0, 0.132), False) + heap((-0.01, 0.0, 0.2), True, 31) + jib(2),
      fine + one_close + two_close + tools)

# The hall: before it the tracing floor and squared blocks (clear of the
# wall, where the game's stood in it), the jib beside it.
floor, lines = tracing_floor((0.0, 0.0, 0.17))
piece("lodge floor", [3, 4, 5], floor + heap((0.175, 0.0, 0.145), False), lines)
for level in (3, 4, 5):
    far, fine = lodge_hall(level)
    far += jib(level)
    fine += ashlar(level)
    if level == 3:
        more, close = banker((0.17, 0.0, 0.04), True)
        far += scaffold((0.13, 0.0, -0.1)) + more
        fine += close
    else:
        far += tread_crane(level)
    if level == 5:
        gate, gate_close = arch((0.0, 0.0, 0.27))
        far += gate
        fine += gate_close
    piece("lodge", [level], far, fine)

# The jib slewing its stone out over the yard and back, a little past its
# rest (the game's slewed it in under the shed's eaves), at every level;
# the treadwheel walked once round.
idle(rig, turns=[("lodge jib@%d" % level, (0, 1, 0), lambda u: -0.6 * swing(u)) for level in LEVELS]
     + [("treadwheel@%d" % level, (0, 0, 1), wheel_turns(1)) for level in WHEELS])

finish_building(out_path("Art/models/lodge.glb"), [str(level) for level in LEVELS])
