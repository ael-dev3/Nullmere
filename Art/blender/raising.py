"""The rigs a work's builders raise it with, beside its scaffold while it
rises (HoldLayout stands one there), each family's own and each a variant of
one file, named for its family; each faces +z as its work does and moves as
they work:
- sawpit: shear legs over the pit, crossed and lashed at their head, a back
  pole raked off to their side, the log slung end on from their tackle
  swinging up and down between the legs;
- lodge: a treadwheel crane, the wheel walked round between its two A-frames
  on their sills, the crane's post behind them and its jib slewing a squared
  block up to the wall;
- archive: the same crane slewing a block of dressed ashlar, and a ladder up
  the scaffold beside it for the masons who set it;
- beacon: a gin pole guyed to its pegs, its fire basket, full of kindling,
  hauled up on the gaff at its head and let down;
- musterHall: a roof truss swung up between two shear legs onto the walls;
- granary: a thatchers' derrick, its jib swung round to the roof with a
  bundle of straw hauled up under it, and a ladder to the eaves with a
  bundle laid on its rungs;
- quarry: a tripod over the footings, its windlass wound by its two cranks
  and a squared stone gripped by its lewis swinging on the rope beneath;
- saltworks: a beam pile-engine driving piles into the shore mud, its ram
  hung from the beam's short arm lifted as the long arm is hauled down, and
  dropped on the pile; the piles already driven stand in a row beside it.
Close: foot stones, lashings, pegs, sheaves and slings, the treadwheel's
treads, the windlass's rope wound on, the bundles' bands, the ram's hoops
and the timber stacked by.

    python Art/blender/raising.py Art/models/raising.glb
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
VARIANTS = ["sawpit", "lodge", "beacon", "musterHall", "archive", "granary", "quarry", "saltworks"]

grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
bark = material("plain_timber_bark", (0.21, 0.17, 0.14))
linen = material("plain_linen", (0.7, 0.67, 0.6))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
# The archive's dressed stone, a shade under white (Palette.stoneWhite * 0.96).
ashlar = material("plain_stone_ashlar", (0.806, 0.806, 0.787))
straw = material("plain_thatch_straw", (0.62, 0.55, 0.36))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
mud = material("plain_earth_mud", (0.214, 0.194, 0.166))

# The packed ground's top where a rig stands, on its work's pad: what lies
# on the ground is set down on it, what stands in it goes down to nought
# (the game's foot stones lay level with the pad's top, and its timber and
# straw half sunk in it).
G = 0.012

# Where each moving part turns, as the game's Raising has them.
# The sawpit's shear legs' head, where the log's tackle hangs.
SAW_HEAD = (0.0, 0.3, 0.0)
# The crane's treadwheel hub; its post stands behind the wheel's frames (the
# game's stood in the wheel), its jib's foot on it.
HUB = (0.0, 0.075, 0.0)
POST = (-0.04, -0.05)
JIB_FOOT = (POST[0], 0.24, POST[1])
# The gin pole's top.
GIN_TOP = (0.0, 0.36, 0.0)
# The truss hangs from the line between the two shear legs' heads.
TRUSS_PIVOT = (0.0, 0.29, 0.0)
# The thatchers' derrick's foot, and its jib's foot on its pole.
DERRICK = (0.08, 0.0, 0.04)
DERRICK_PIVOT = (DERRICK[0], 0.22, DERRICK[2])
# The lewis tripod's head, and its windlass's hub.
TRIPOD_HEAD = (0.0, 0.32, 0.0)
WINDLASS = (0.07, 0.08, 0.04)
# Where the pile engine's beam is pinned.
ENGINE = (0.0, 0.2, 0.0)

rig = work_rig([("raised log@sawpit", SAW_HEAD, (1, 0, 0)),
                ("raising treadwheel@lodge,archive", HUB, (0, 0, 1)),
                ("raising jib@lodge,archive", JIB_FOOT, (0, 1, 0)),
                ("raised basket@beacon", GIN_TOP, (0, 0, 1)),
                ("raised truss@musterHall", TRUSS_PIVOT, (1, 0, 0)),
                ("thatch derrick@granary", DERRICK_PIVOT, (0, 1, 0)),
                ("windlass@quarry", WINDLASS, (0, 0, 1)),
                ("lewis stone@quarry", TRIPOD_HEAD, (1, 0, 0)),
                ("pile engine@saltworks", ENGINE, (0, 0, 1))])


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


def turn_z(angle):
    return Matrix.Rotation(angle, 4, "Z")


def aligning_up(direction):
    """The turn that carries straight up onto `direction` (Mat4.aligningUp)."""
    d = Vector(direction).normalized()
    axis = Vector((0, 1, 0)).cross(d)
    cosine = max(-1.0, min(1.0, d.y))
    if axis.length < 1e-6:
        return Matrix.Identity(4) if cosine > 0 else turn_x(math.pi)
    return Matrix.Rotation(math.acos(cosine), 4, axis.normalized())


def box(name, centre, size, mat, turn=0.0, chamfer=0.0):
    """A box about its centre, turned about the upright as the game turns
    it (MeshBuilder.box(center:size:turn:)); block turns the other way."""
    low = tuple(c - s / 2 for c, s in zip(centre, size))
    high = tuple(c + s / 2 for c, s in zip(centre, size))
    return block(name, low, high, mat, chamfer=chamfer, turn=-turn, about=tuple(centre))


def beam(name, a, b, width, mat, depth=None, chamfer=0.0):
    """A squared timber from one point to another, `width` across and
    `depth` through, its faces set as the game's beam sets them: a level
    one flat on top, a standing one `width` east to west."""
    a, b = Vector(a), Vector(b)
    along = b - a
    length = along.length
    up = along / length
    reference = Vector((0, 0, 1)) if abs(up.y) > 0.95 else Vector((0, 1, 0))
    side = up.cross(reference).normalized()
    front = side.cross(up)
    d = width if depth is None else depth
    frame = Matrix(((side.x, up.x, front.x, a.x), (side.y, up.y, front.y, a.y), (side.z, up.z, front.z, a.z), (0, 0, 0, 1)))
    return moved(block(name, (-width / 2, 0, -d / 2), (width / 2, length, d / 2), mat, chamfer=chamfer), frame)


def limb(name, a, b, radius, mat, top=None, sides=4, caps=(False, False)):
    """A pole or a rope from one point to another (MeshBuilder.limb), its
    ends left open where they are hidden."""
    a, b = Vector(a), Vector(b)
    obj = rings(name, [(radius, 0.0), (radius if top is None else top, (b - a).length)], sides, mat, caps=caps)
    return moved(obj, Matrix.Translation(a) @ aligning_up(b - a))


def pole(name, foot, head, radius, mat, past=0.0, sides=6):
    """A pole from its foot in the ground up to `head` and `past` beyond it,
    its top sawn off square."""
    foot, head = Vector(foot), Vector(head)
    top = head + (head - foot).normalized() * past
    return limb(name, tuple(foot), tuple(top), radius, mat, sides=sides, caps=(False, True))


def band(name, centre, axis, radius, length, mat, sides=6):
    """A band of rope or iron wound about an axis: a lashing, a hoop."""
    obj = rings(name, [(radius, -length / 2), (radius, length / 2)], sides, mat, caps=(False, False))
    return moved(obj, shift(*centre) @ aligning_up(axis))


def peg(name, at_point):
    """A peg driven into the ground, a guy tied off on it."""
    x, _, z = at_point
    return limb(name, (x, -0.006, z), (x, G + 0.012, z), 0.003, dark, caps=(False, True))


def stake(name, foot, top, radius, sides=6):
    """A pile in its bark, driven, its sawn top pale."""
    obj = limb(name, foot, top, radius, bark, sides=sides, caps=(False, True))
    obj.data.materials.append(pale)
    for poly in obj.data.polygons:
        if poly.normal.z > 0.9:
            poly.material_index = 1
    return obj


def bundle(name, profile, sides, placement):
    """A bundle of straw turned about its own length (a lathe along its y),
    set down by `placement`."""
    return moved(rings(name, profile, sides, straw), placement)


def joined(name, pieces):
    """Pieces joined into one object so named."""
    pieces = list(pieces)
    if len(pieces) == 1:
        pieces[0].name = name
        return pieces[0]
    return join(name, pieces)


def piece(name, tags, far, fine=()):
    """A rig's standing pieces joined, far and near."""
    if far:
        joined(tagged(name, tags), far)
    if fine:
        joined(tagged(name + " close", tags) + "!fine", fine)


def moving(name, tags, bone, far, fine=()):
    """A rig's moving part, its pieces joined, far and near, and hung on its
    bone."""
    if far:
        on(joined(tagged(name, tags), far), rig, bone)
    if fine:
        on(joined(tagged(name + " close", tags) + "!fine", fine), rig, bone)


# MARK: The sawpit's shear legs

# Its back pole stands off to the side of the legs, raked to their head:
# the game's stood square behind them, in the way of the log as it swung,
# and hung the log across the legs, through both of them; here it hangs
# end on, through the gap between them.
BACK_FOOT = (0.09, 0.0, -0.1)
tags = ["sawpit"]
far = [pole("shear leg", (x, 0.0, 0.02), SAW_HEAD, 0.008, grey, past=0.022) for x in (-0.07, 0.07)]
far.append(pole("back pole", BACK_FOOT, SAW_HEAD, 0.006, grey))
far.append(box("tackle block", (0.0, 0.284, 0.0), (0.02, 0.026, 0.016), iron))
# Close: stones under their feet (proud of the pad, where the game's lay
# level with its top), the lashing about their head, and the tackle's fall
# run down to a peg.
fine = [box("foot stone", (x, 0.01, 0.02), (0.024, 0.02, 0.024), dark_stone) for x in (-0.07, 0.07)]
fine.append(box("foot stone", (BACK_FOOT[0], 0.009, BACK_FOOT[2]), (0.02, 0.018, 0.02), dark_stone))
fine.append(band("lashing", (0.0, 0.3, 0.0), (0, 1, 0), 0.013, 0.012, linen))
fine.append(limb("fall", (0.004, 0.276, 0.006), (0.06, G + 0.008, 0.12), 0.0018, linen))
fine.append(peg("fall peg", (0.06, 0.0, 0.12)))
piece("shear legs", tags, far, fine)
moving("hoisted log", tags, "raised log@sawpit",
       [limb("tackle rope", (0.0, 0.29, 0.0), (0.0, 0.13, 0.0), 0.0025, linen),
        log("hoisted log", (0.0, 0.12, -0.08), (0.0, 0.12, 0.08), 0.02)],
       [band("sling", (0.0, 0.12, 0.0), (0, 0, 1), 0.0215, 0.01, linen, sides=5)])


# MARK: The lodge's and the archive's treadwheel crane

tags = ["lodge", "archive"]
hx, hy, hz = HUB
far = [beam("frame", (x, 0.0, z), (hx, hy, z), 0.008, dark) for z in (-0.03, 0.03) for x in (-0.05, 0.05)]
# The frames stand on sills laid on the ground.
far += [beam("sill", (x, G + 0.002, -0.038), (x, G + 0.002, 0.038), 0.012, dark, depth=0.012) for x in (-0.05, 0.05)]
far.append(pole("crane post", (POST[0], 0.0, POST[1]), (POST[0], 0.26, POST[1]), 0.008, dark))
piece("crane", tags, far, [box("post stone", (POST[0], 0.009, POST[1]), (0.02, 0.018, 0.02), dark_stone)])

# The wheel on its axle along z, the axis it turns about (the game's stood
# its wheel across its frames, its axle along x): a drum open at its faces,
# three spokes across each face, its axle through the frames' heads; close,
# the treads across the drum inside, between the spokes.
inner, outer, half = 0.063, 0.07, 0.025
wheel = [moved(rings("drum", [(inner, -half), (outer, -half), (outer, half), (inner, half), (inner, -half)], 12, dark, caps=(False, False)),
               shift(*HUB) @ turn_x(math.pi / 2))]
for z in (-0.021, 0.021):
    for k in range(3):
        angle = k * math.pi / 3
        dx, dy = 0.064 * math.cos(angle), 0.064 * math.sin(angle)
        wheel.append(beam("spoke", (hx - dx, hy - dy, hz + z), (hx + dx, hy + dy, hz + z), 0.006, timber))
wheel.append(limb("axle", (hx, hy, hz - 0.042), (hx, hy, hz + 0.042), 0.006, timber, sides=6, caps=(True, True)))
treads = []
for k in range(12):
    angle = (k + 0.5) * math.pi / 6
    treads.append(moved(block("tread", (-0.0035, -0.0025, -0.023), (0.0035, 0.0025, 0.023), pale),
                        shift(hx + 0.0585 * math.cos(angle), hy + 0.0585 * math.sin(angle), hz) @ turn_z(angle)))
moving("treadwheel", tags, "raising treadwheel@lodge,archive", wheel, treads)

# The jib slewing on its post, braced to it, its fall from the sheave at its
# head (run down into the block, where the game's stopped short of it).
px, py, pz = JIB_FOOT
moving("crane jib", tags, "raising jib@lodge,archive",
       [beam("jib", JIB_FOOT, (0.1, 0.27, pz), 0.009, timber),
        beam("jib strut", (px, 0.19, pz), (0.03, 0.255, pz), 0.006, dark),
        limb("crane fall", (0.095, 0.268, pz), (0.095, 0.155, pz), 0.002, linen)],
       [box("sheave block", (0.095, 0.262, pz), (0.012, 0.014, 0.012), iron),
        box("lewis", (0.095, 0.16, pz), (0.008, 0.008, 0.005), iron)])
# The lodge's block squared, the archive's dressed ashlar.
for variant, mat in (("lodge", pale_stone), ("archive", ashlar)):
    moving("crane load", [variant], "raising jib@lodge,archive",
           [box("crane load", (0.095, 0.145, pz), (0.032, 0.028, 0.03), mat, chamfer=0.002)])
piece("crane ladder", ["archive"], ladder("ladder", (-0.1, 0.0, 0.04), (-0.09, 0.26, 0.0), 0.03, 8, pale))


# MARK: The beacon's gin pole

# Its guys pegged round it clear of the basket's swing (the game's ran one
# through the basket), and the basket hung plumb from a gaff at the pole's
# head, clear of the pole (the game's hung it on a slanting rope about the
# pole).
GUYS = (1.0, 3.1, 5.0)
GAFF = 0.08
tags = ["beacon"]
far = [pole("gin pole", (0.0, 0.0, 0.0), (0.0, 0.372, 0.0), 0.008, grey)]
fine = [box("pole stone", (0.0, 0.01, 0.0), (0.026, 0.02, 0.026), dark_stone),
        band("lashing", (0.0, 0.344, 0.0), (0, 1, 0), 0.0105, 0.008, linen)]
for angle in GUYS:
    x, z = 0.14 * math.cos(angle), 0.14 * math.sin(angle)
    far.append(limb("guy", GIN_TOP, (x, 0.006, z), 0.0018, linen))
    far.append(box("guy peg", (x, 0.008, z), (0.01, 0.016, 0.01), dark))
piece("gin pole", tags, far, fine)

basket = rings("fire basket", [(0.012, 0.17), (0.035, 0.19), (0.038, 0.22), (0.026, 0.226), (0.0, 0.229)], 8, iron, centre=(GAFF, 0.0))
basket.data.materials.append(dark)
for poly in basket.data.polygons:
    if poly.center.z > 0.221 * UNIT:
        # The kindling heaped in it.
        poly.material_index = 1
close = [moved(rings("gin wheel", [(0.009, -0.0025), (0.009, 0.0025)], 8, iron), shift(GAFF, 0.352, 0.0) @ turn_x(math.pi / 2))]
for k in range(3):
    a = 2 * math.pi * k / 3 + math.pi / 6
    close.append(limb("bail", (GAFF + 0.036 * math.cos(a), 0.221, 0.036 * math.sin(a)), (GAFF, 0.264, 0.0), 0.0012, iron, sides=3))
for k in range(8):
    a = 2 * math.pi * k / 8 + math.pi / 8
    close.append(limb("bar", (GAFF + 0.031 * math.cos(a), 0.2, 0.031 * math.sin(a)), (GAFF + 0.044 * math.cos(a), 0.244, 0.044 * math.sin(a)),
                      0.0022, iron, caps=(False, True)))
moving("fire basket", tags, "raised basket@beacon",
       [beam("gaff", GIN_TOP, (GAFF + 0.006, 0.36, 0.0), 0.007, timber),
        limb("basket rope", (GAFF, 0.36, 0.0), (GAFF, 0.262, 0.0), 0.002, linen), basket], close)


# MARK: The muster hall's truss lift

tags = ["musterHall"]
far = [pole("shear leg", (x, 0.0, z), (x, 0.3, 0.0), 0.006, grey, past=0.02) for x in (-0.1, 0.1) for z in (-0.05, 0.05)]
fine = [box("foot stone", (x, 0.009, z), (0.02, 0.018, 0.02), dark_stone) for x in (-0.1, 0.1) for z in (-0.05, 0.05)]
fine += [band("lashing", (x, 0.297, 0.0), (0, 1, 0), 0.0105, 0.012, linen) for x in (-0.1, 0.1)]
piece("truss lift", tags, far, fine)
# The truss slung from both heads (its ropes made fast to the rafters, where
# the game's ended short of them), its tie beam running out past the
# rafters' feet, its king post up between their heads; close, its struts.
truss = [limb("truss rope", (x, 0.29, 0.0), (x * 0.6, 0.188, 0.0), 0.0018, linen) for x in (-0.1, 0.1)]
truss.append(beam("tie beam", (-0.088, 0.17, 0.0), (0.088, 0.17, 0.0), 0.008, timber))
truss += [beam("rafter", (x, 0.17, 0.0), (0.0, 0.23, 0.0), 0.008, timber) for x in (-0.08, 0.08)]
truss.append(beam("king post", (0.0, 0.17, 0.0), (0.0, 0.238, 0.0), 0.006, dark))
moving("roof truss", tags, "raised truss@musterHall", truss,
       [beam("strut", (0.0, 0.176, 0.0), (x * 0.5, 0.2, 0.0), 0.005, dark) for x in (-0.08, 0.08)])


# MARK: The granary's thatchers' derrick

# Its guys pegged round it out of the jib's swing and off the bundles laid
# by (the game's ran one through the jib's root as it swung to the roof);
# the bundle hauled up under the jib's head, over the ladder's head (the
# game's hung it into the ladder).
GUY_ANGLES = (1.84, 3.84, 5.84)
LADDER = ((-0.12, 0.0, 0.08), (-0.1, 0.2, 0.02))
fx, _, fz = DERRICK
tags = ["granary"]
far = [box("derrick block", (fx, 0.012, fz), (0.04, 0.024, 0.04), dark),
       pole("derrick pole", DERRICK, (fx, 0.31, fz), 0.008, grey)]
fine = [band("lashing", (fx, 0.296, fz), (0, 1, 0), 0.0105, 0.008, linen)]
for angle in GUY_ANGLES:
    x, z = fx + 0.11 * math.cos(angle), fz + 0.11 * math.sin(angle)
    far.append(limb("guy", (fx, 0.3, fz), (x, 0.006, z), 0.0016, linen))
    fine.append(peg("guy peg", (x, 0.0, z)))
far += ladder("ladder", LADDER[0], LADDER[1], 0.03, 7, pale)
# A bundle laid across the ladder's rungs, on them (the game's lay through
# them), and two side by side on the ground (on the pad, where the game's
# sank half in, one through the other).
foot, head = Vector(LADDER[0]), Vector(LADDER[1])
across = Vector(((head - foot).z, 0.0, -(head - foot).x)).normalized()
facing = across.cross(head - foot).normalized()
if facing.z < 0:
    facing = -facing
middle = foot + (head - foot) * 0.55 + facing * 0.0155
fine.append(bundle("bundle", [(0.01, -0.03), (0.014, 0.0), (0.008, 0.03)], 5, shift(*middle) @ aligning_up(across)))
for x, z, turn in ((0.0, 0.115, 0.0), (-0.005, 0.148, 0.25)):
    fine.append(bundle("bundle", [(0.01, -0.035), (0.013, 0.0), (0.008, 0.035)], 5,
                       shift(x, G + 0.012, z) @ turn_z(math.pi / 2) @ turn_x(turn)))
piece("derrick pole", tags, far, fine)
# The jib, its stay from the pole's head, and the bundle on its rope; close,
# the bands it is tied with.
hauled = shift(fx - 0.145, 0.226, fz) @ turn_z(math.pi / 2)
moving("derrick jib", tags, "thatch derrick@granary",
       [beam("jib", DERRICK_PIVOT, (fx - 0.15, 0.27, fz), 0.008, timber),
        beam("jib stay", (fx, 0.29, fz), (fx - 0.15, 0.27, fz), 0.004, dark),
        limb("jib rope", (fx - 0.145, 0.268, fz), (fx - 0.145, 0.238, fz), 0.002, linen),
        bundle("hauled bundle", [(0.012, -0.04), (0.018, -0.02), (0.016, 0.03), (0.008, 0.045)], 6, hauled)],
       [moved(rings("bundle band", [(radius, y - 0.003), (radius, y + 0.003)], 6, thatch, caps=(False, False)), hauled)
        for y, radius in ((-0.025, 0.0175), (0.02, 0.0174))])


# MARK: The quarry's lewis tripod

# Its legs set round clear of the windlass (the game's ran one through the
# windlass's drum), its feet on stones proud of the pad (the game's lay level
# with its top); its windlass's cranks outside its posts (the game's turned
# through them), on an axle run through them.
LEG_ANGLES = (1.4, 3.5, 5.6)
tags = ["quarry"]
far = []
for angle in LEG_ANGLES:
    x, z = 0.12 * math.cos(angle), 0.12 * math.sin(angle)
    far.append(pole("tripod leg", (x, 0.0, z), TRIPOD_HEAD, 0.0075, grey, past=0.02))
    far.append(box("foot stone", (x, 0.01, z), (0.022, 0.02, 0.022), dark_stone))
far.append(box("tripod head", (0.0, 0.308, 0.0), (0.018, 0.02, 0.018), iron))
# The tackle block hung under it, the stone's rope run down from inside it,
# clear of the legs as it swings.
far.append(box("tackle block", (0.0, 0.29, 0.0), (0.02, 0.02, 0.02), dark))
wx, wy, wz = WINDLASS
far += [beam("windlass post", (wx, 0.0, z), (wx, wy + 0.012, z), 0.008, dark) for z in (wz - 0.04, wz + 0.04)]
far.append(limb("windlass rope", WINDLASS, (0.0, 0.31, 0.0), 0.0018, linen))
piece("lewis tripod", tags, far, [band("lashing", (0.0, 0.326, 0.0), (0, 1, 0), 0.0125, 0.01, linen),
                                  beam("windlass sill", (wx, G + 0.002, wz - 0.052), (wx, G + 0.002, wz + 0.052), 0.012, dark, depth=0.012)])
moving("windlass drum", tags, "windlass@quarry",
       [limb("drum", (wx, wy, wz - 0.04), (wx, wy, wz + 0.04), 0.012, timber, sides=6),
        limb("windlass axle", (wx, wy, wz - 0.056), (wx, wy, wz + 0.056), 0.0035, dark, sides=6, caps=(True, True)),
        beam("crank", (wx, wy, wz + 0.051), (wx + 0.035, wy, wz + 0.051), 0.005, dark),
        beam("crank", (wx, wy, wz - 0.051), (wx - 0.035, wy, wz - 0.051), 0.005, dark),
        limb("crank handle", (wx + 0.033, wy, wz + 0.051), (wx + 0.033, wy, wz + 0.072), 0.0028, pale, sides=6, caps=(False, True)),
        limb("crank handle", (wx - 0.033, wy, wz - 0.051), (wx - 0.033, wy, wz - 0.072), 0.0028, pale, sides=6, caps=(False, True))],
       [band("wound rope", (wx, wy, wz + 0.005), (0, 0, 1), 0.0132, 0.03, linen)])
# The stone on its lewis, the lewis let into its top (the game's stood clear
# of it).
moving("hoisted stone", tags, "lewis stone@quarry",
       [limb("lewis rope", (0.0, 0.286, 0.0), (0.0, 0.16, 0.0), 0.002, linen),
        box("lewis", (0.0, 0.149, 0.0), (0.01, 0.026, 0.006), iron),
        box("hoisted stone", (0.0, 0.125, 0.0), (0.06, 0.04, 0.04), pale_stone, chamfer=0.003)])


# MARK: The saltworks' pile engine

# Its frame's legs on sills, their heads in a bearing block wide enough to
# hold them (the game's stood half out of it); the piles' tops sawn and
# capped (the game's were open); the shore mud heaped about them, the rig's
# ground, skinned to its base; close, the timber for the next piles stacked
# clear of the frame (the game's lay under its legs, sunk in the pad).
ex, ey, ez = ENGINE
tags = ["saltworks"]
far = [limb("frame leg", (x * 1.6, 0.0, z), (ex + x * 0.2, ey, ez + z * 0.5), 0.006, grey, sides=6) for x in (-0.05, 0.05) for z in (-0.04, 0.04)]
far.append(box("bearing", ENGINE, (0.034, 0.026, 0.058), dark))
far += [beam("frame sill", (-0.095, G + 0.002, z), (0.095, G + 0.002, z), 0.012, dark, depth=0.012) for z in (-0.04, 0.04)]
far.append(stake("driven pile", (-0.075, -0.02, 0.0), (-0.075, 0.06, 0.0), 0.012))
far += [stake("pile", (-0.16 + index * 0.04, -0.02, 0.1), (-0.16 + index * 0.04, 0.02 + (index % 2) * 0.008, 0.1), 0.011) for index in range(5)]
fine = [limb("pin", (ex, ey, ez - 0.034), (ex, ey, ez + 0.034), 0.004, iron, sides=6, caps=(True, True)),
        band("pile ring", (-0.075, 0.055, 0.0), (0, 1, 0), 0.0128, 0.006, iron)]
fine += [log("seasoning pile", (x, G + 0.009, -0.17), (x, G + 0.009, -0.07), 0.009) for x in (0.06, 0.08, 0.1)]
piece("pile frame", tags, far, fine)
ground(join(tagged("shore mud", tags), [rings("mud", [(0.055, -0.004), (0.04, 0.012), (0.018, 0.018), (0.0, 0.02)], 8, mud, caps=(False, False),
                                              centre=(-0.075, 0.0)),
                                        rings("mud", [(0.115, -0.004), (0.085, 0.011), (0.045, 0.015), (0.0, 0.016)], 10, mud, caps=(False, False),
                                              centre=(-0.08, 0.1), squash=0.33)]), rig)
# The beam rocking on its pin, a bar across its long arm for the haul ropes
# (the game's hung two of them off it in the air), the ram on its rope from
# the short arm; close, the ram's hoops.
moving("engine beam", tags, "pile engine@saltworks",
       [beam("engine beam", (ex - 0.08, ey + 0.02, ez), (ex + 0.17, ey - 0.04, ez), 0.012, timber),
        beam("haul bar", (0.16, 0.1624, -0.026), (0.16, 0.1624, 0.026), 0.006, dark),
        limb("ram rope", (-0.075, 0.215, 0.0), (-0.075, 0.12, 0.0), 0.002, linen),
        rings("ram", [(0.02, 0.08), (0.022, 0.12), (0.012, 0.125)], 7, iron, centre=(-0.075, 0.0))]
       + [limb("haul rope", (0.16, 0.161, dz), (0.2, 0.0, dz * 2), 0.0016, linen) for dz in (-0.02, 0.0, 0.02)],
       [band("ram hoop", (-0.075, y, 0.0), (0, 1, 0), radius, 0.005, iron, sides=7) for y, radius in ((0.09, 0.0215), (0.114, 0.0227))])


# MARK: How they move

# Each as the game's Machinery moves it: the log, the truss and the stone
# swung on their ropes, the jibs slewed, the basket hauled up and let down,
# the beam rocked; the treadwheel walked and the windlass wound once round.
idle(rig, turns=[("raised log@sawpit", (1, 0, 0), lambda u: 0.35 * swing(u)),
                 ("raising treadwheel@lodge,archive", (0, 0, 1), wheel_turns(1)),
                 ("raising jib@lodge,archive", (0, 1, 0), lambda u: 0.7 * swing(u)),
                 ("raised basket@beacon", (0, 0, 1), lambda u: 0.3 * swing(u)),
                 ("raised truss@musterHall", (1, 0, 0), lambda u: 0.3 * swing(u)),
                 ("thatch derrick@granary", (0, 1, 0), lambda u: 0.9 * swing(u)),
                 ("windlass@quarry", (0, 0, 1), wheel_turns(1)),
                 ("lewis stone@quarry", (1, 0, 0), lambda u: 0.2 * swing(u)),
                 ("pile engine@saltworks", (0, 0, 1), lambda u: 0.25 * swing(u))])

finish_building(out_path("Art/models/raising.glb"), VARIANTS)
