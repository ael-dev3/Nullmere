"""The Quarry, where the House's stone is cut, its five levels the tiers of
one file, each within a work's slot and facing +z: a face of rock at the
back of its slot, cut down in benches that deepen and widen as it grows,
each bench's lip ragged with rock; rough blocks levered out before it,
rubble heaped and a trough of lime at every level;
1. a shallow cut into an outcrop, a windlass on its frame turning to drag a
   block out of the cut, a lean-to of planks for the tools;
2. two benches, shear legs over the cut swinging a block on their tackle,
   rough blocks and more rubble;
3. three benches, a boom derrick slewing on its guyed mast, the
   stone-cutters' shed under slate with a banker at its open front, a block
   on rollers, dressed blocks stacked;
4. four benches, a treadwheel crane, its jib slewing, a sledge track down
   the face with a sledge and its block on the rails, a trough for the saws;
5. a deep terraced pit, a great gantry over it, its trolley swinging a
   block, the quarry-master's house of stone, the House's banners at the
   cart road.
Close: chips and spoil strewn over the floor, the wedge marks down the
face, the picks and bars under the lean-to, the derricks' lashings and
pegs, the banker's mallet, chisel and chips, the roofs' courses, gable
boards and rafters, the saws' trough and the gantry's ladder.
What lifts the stone works: the windlass turns, the derricks and cranes
swing, the treadwheel is walked round.

    python Art/blender/quarry.py Art/models/quarry.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
LEVELS = [1, 2, 3, 4, 5]

floor = material("plain_earth_quarry", (0.355, 0.345, 0.335))
rock_stone = material("plain_stone_rock", (0.4, 0.4, 0.42))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
white = material("plain_stone_white", (0.84, 0.84, 0.82))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
# The rollers' bark, in the palette's colour before works.log asks for it.
material("plain_timber_bark", (0.21, 0.17, 0.14))
linen = material("plain_linen", (0.7, 0.67, 0.6))
water = material("plain_seawool", (0.27, 0.33, 0.38))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.4, metallic=0.7)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))

# Where each level's moving part turns, and about what: the windlass's drum,
# the shear legs' tackle, the boom derrick's boom, the treadwheel and the
# crane's jib, the gantry's trolley.
PARTS = [("quarry windlass@1", (0.12, 0.07, 0.1), (1, 0, 0)),
         ("quarry tackle@2", (0.04, 0.28, 0.0), (1, 0, 0)),
         ("quarry boom@3", (0.0, 0.0, 0.06), (0, 1, 0)),
         ("quarry treadwheel@4", (0.18, 0.08, 0.06), (0, 0, 1)),
         ("quarry jib@4", (0.14, 0.25, 0.02), (0, 1, 0)),
         ("quarry trolley@5", (0.0, 0.32, -0.1), (1, 0, 0))]
rig = work_rig(PARTS)
ground(pad(tagged("pad", []), 0.31, floor), rig)


# MARK: Shapes as the game's own are built

TO_BLENDER = Matrix(((UNIT, 0, 0, 0), (0, 0, -UNIT, 0), (0, UNIT, 0, 0), (0, 0, 0, 1)))
FROM_BLENDER = TO_BLENDER.inverted()


def moved(obj, placement):
    """A piece made about the origin, carried by `placement` (a matrix in
    the world's axes and units, as the game places a solid)."""
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
    """A squared timber or stone from one point to another, `width` across
    and `depth` through, its faces set as the game's beam sets them: a
    level one flat on top, a standing one `width` east to west."""
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
    ends left open unless they show."""
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    obj = rings(name, [(radius, 0.0), (radius if top is None else top, length)], sides, mat, caps=caps)
    return moved(obj, Matrix.Translation(a) @ aligning_up(b - a))


def sphere(name, centre, radius, mat, bands=4, sides=6, squash=1.0):
    """A faceted ball, squashed to `squash` of its height."""
    profile = []
    for ring in range(bands + 1):
        angle = math.pi * ring / bands - math.pi / 2
        r = 0.0 if ring in (0, bands) else radius * math.cos(angle)
        profile.append((r, centre[1] + radius * squash * math.sin(angle)))
    return rings(name, profile, sides, mat, centre=(centre[0], centre[2]))


def piece(name, levels, far, fine=()):
    """A level's pieces joined, far and near."""
    tags = level_tags(levels)
    if far:
        join(tagged(name, tags), list(far))
    if fine:
        join(tagged(name + " close", tags) + "!fine", list(fine))


def moving(name, bone, pieces):
    """A moving part's pieces joined and hung on its bone, at its level."""
    on(join(tagged(name, [bone.split("@")[1]]), list(pieces)), rig, bone)


# MARK: The cut and its floor

def face(benches):
    """The rock face at the back, cut in benches: each bench a step of
    stone, its lip ragged with rock; close, the wedge marks down its face."""
    far, fine = [], []
    back, depth = -0.19, 0.04
    for bench in range(benches):
        z = back + bench * depth
        h = 0.05 + (benches - bench) * 0.045
        w = 0.4 - bench * 0.035
        far.append(block("bench", (-w / 2, 0.0, z - depth), (w / 2, h, z), rock_stone if bench % 2 == 0 else dark_stone))
        for index in range(9):
            x = -w / 2 + w * (index + 0.5) / 9
            far.append(rock("lip", (x, h + 0.008, z - depth * 0.5), (0.03, 0.016, 0.028), bench * 11 + index + 300,
                            rock_stone if index % 2 == 0 else stone))
        for index in range(4):
            x = -w / 2 + w * (index + 0.3) / 4
            fine.append(box("wedge mark", (x, h * 0.5, z + 0.001), (0.003, h * 0.8, 0.002), pale_stone))
    return far, fine


def blocks(at_point, rows, dressed, first=0):
    """Blocks: rough ones as levered out, or dressed and stacked square,
    course on course; the courses from `first`."""
    pieces = []
    for row in range(first, rows):
        for index in range(3 - min(row, 2)):
            p = (at_point[0] + index * 0.034 + row * 0.017 - 0.034, at_point[1] + 0.015 + row * 0.03, at_point[2])
            if dressed:
                pieces.append(box("dressed block", p, (0.032, 0.03, 0.05), pale_stone if (index + row) % 2 == 0 else stone,
                                  chamfer=0.0025))
            else:
                pieces.append(rock("rough block", p, (0.032, 0.026, 0.04), row * 5 + index + 410, stone))
    return pieces


def rubble(at_point):
    """Rubble heaped where it was thrown, broken stone about its foot."""
    x0, _, z0 = at_point
    pieces = [rings("rubble", [(0.06, 0.0), (0.0, 0.05)], 7, rock_stone, centre=(x0, z0))]
    for index in range(5):
        angle = index * 1.4
        pieces.append(rock("broken stone", (x0 + 0.05 * math.cos(angle), 0.01, z0 + 0.05 * math.sin(angle)), (0.016, 0.012, 0.014),
                           index + 520, dark_stone))
    return pieces


def lime_trough(at_point):
    """A trough of lime, its paddle laid across it."""
    x0, _, z0 = at_point
    return [block("trough", (x0 - 0.04, 0.0, z0 - 0.02), (x0 + 0.04, 0.03, z0 + 0.02), dark),
            block("lime", (x0 - 0.036, 0.026, z0 - 0.016), (x0 + 0.036, 0.031, z0 + 0.016), white),
            beam("paddle", (x0 - 0.045, 0.0325, z0), (x0 + 0.04, 0.0325, z0 + 0.01), 0.004, pale)]


def spoil():
    """Chips and spoil strewn over the floor of the cut, each lying along
    the way it was thrown."""
    chips = []
    for index in range(18):
        angle = index * 2.39996
        r = 0.06 + 0.2 * ((index * 23) % 11) / 11
        x, z = r * math.cos(angle), r * math.sin(angle)
        chips.append(block("chip", (x - 0.005, 0.01, z - 0.004), (x + 0.005, 0.016, z + 0.004), pale_stone if index % 3 == 0 else rock_stone,
                           turn=angle))
    return chips


# MARK: What lifts the stone

def windlass(at_point):
    """A windlass on its frame, its drum turned by handspikes on its axle to
    drag a block out of the cut. Returns the frame and rope, and the drum."""
    x0, _, z0 = at_point
    far = [box("windlass frame", (x0 + x, 0.04, z0), (0.01, 0.08, 0.04), dark) for x in (-0.04, 0.04)]
    hub = (x0, 0.07, z0)
    drum = [rings("drum", [(0.014, -0.04), (0.014, 0.04)], 7, timber),
            limb("axle", (x0 - 0.05, 0.07, z0), (x0 + 0.056, 0.07, z0), 0.004, dark, caps=(True, True))]
    moved(drum[0], shift(*hub) @ turn_z(math.pi / 2))
    for angle in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
        start = (x0 + 0.05, 0.07, z0)
        drum.append(beam("handspike", start, (start[0], start[1] + 0.035 * math.cos(angle), start[2] + 0.035 * math.sin(angle)), 0.005,
                         pale))
    far.append(limb("drag rope", (x0, 0.07, z0 - 0.01), (x0 - 0.05, 0.02, -0.16), 0.002, linen))
    far.append(rock("dragged block", (x0 - 0.05, 0.024, -0.176), (0.026, 0.02, 0.024), 440, stone))
    return far, drum


def lean_to(at_point):
    """A lean-to of planks on four posts where the picks and bars are kept."""
    x0, _, z0 = at_point
    rise = math.tan(0.35)
    far = []
    for z in (-0.05, 0.05):
        far.append(limb("lean-to post", (x0 + 0.03, 0.0, z0 + z), (x0 + 0.03, 0.1 + 0.03 * rise + 0.002, z0 + z), 0.006, dark))
        far.append(limb("lean-to prop", (x0 - 0.04, 0.0, z0 + z), (x0 - 0.04, 0.1 - 0.04 * rise + 0.002, z0 + z), 0.005, dark))
    far.append(moved(block("lean-to roof", (-0.05, 0.0, -0.07), (0.05, 0.008, 0.07), grey), shift(x0, 0.1, z0) @ turn_z(0.35)))
    fine = [limb("tool", (x0 - 0.01, 0.0, z0 + z), (x0 + 0.02, 0.08, z0 + z), 0.0025, pale if index % 2 == 0 else iron)
            for index, z in enumerate((-0.03, -0.01, 0.01, 0.03))]
    return far, fine


def shear_derrick(at_point):
    """Shear legs over the cut, guyed back, a block swinging on their
    tackle. Returns the legs, their lashing and peg, and the tackle."""
    x0, _, z0 = at_point
    head = (x0, 0.28, z0 - 0.04)
    far = [limb("shear leg", (x0 + x, 0.0, z0 + 0.04), head, 0.008, grey) for x in (-0.08, 0.08)]
    far.append(limb("guy", (x0, 0.0, z0 + 0.16), head, 0.0018, linen))
    fine = [box("lashing", head, (0.022, 0.016, 0.018), dark),
            limb("peg", (x0, 0.0, z0 + 0.16), (x0, 0.022, z0 + 0.16), 0.003, dark, caps=(False, True))]
    load = [limb("fall", head, (head[0], head[1] - 0.156, head[2]), 0.002, linen),
            box("load", (head[0], head[1] - 0.17, head[2]), (0.04, 0.03, 0.035), pale_stone)]
    return far, fine, load


def boom_derrick(at_point):
    """A boom derrick: a mast guyed to pegs in the ground, its boom slewing
    round with a block on its fall."""
    x0, _, z0 = at_point
    top = (x0, 0.34, z0)
    far = [limb("mast", at_point, top, 0.009, dark, caps=(False, True))]
    fine = []
    for angle in (0.6, 2.6, 4.6):
        peg = (x0 + 0.15 * math.cos(angle), 0.0, z0 + 0.15 * math.sin(angle))
        far.append(limb("guy", top, peg, 0.0016, linen))
        fine.append(limb("peg", peg, (peg[0], 0.022, peg[2]), 0.003, dark, caps=(False, True)))
    boom = [beam("boom", (x0, 0.03, z0), (x0, 0.26, z0 - 0.16), 0.009, timber),
            limb("fall", (x0, 0.26, z0 - 0.16), (x0, 0.148, z0 - 0.16), 0.002, linen),
            box("load", (x0, 0.135, z0 - 0.16), (0.04, 0.028, 0.034), pale_stone)]
    return far, fine, boom


def treadwheel(hub, radius, width):
    """A treadwheel on its axle along z, between the crane's frames: a drum
    of treads open at its faces, three spokes across each face."""
    cx, cy, cz = hub
    inner, w = radius - 0.007, width / 2
    shell = moved(rings("treads", [(inner, -w), (radius, -w), (radius, w), (inner, w), (inner, -w)], 10, timber, caps=(False, False)),
                  shift(*hub) @ turn_x(math.pi / 2))
    pieces = [shell]
    for z in (-w + 0.004, w - 0.004):
        for k in range(3):
            angle = math.pi / 6 + k * math.pi / 3
            dx, dy = inner * math.cos(angle), inner * math.sin(angle)
            pieces.append(beam("spoke", (cx - dx, cy - dy, cz + z), (cx + dx, cy + dy, cz + z), 0.006, dark))
    pieces.append(limb("wheel axle", (cx, cy, cz - 0.04), (cx, cy, cz + 0.04), 0.006, dark, sides=6, caps=(True, True)))
    return pieces


def tread_crane(at_point):
    """A treadwheel crane at the cut's edge: the wheel walked round between
    two A-frames, the crane's post and its jib slewing, a block on its fall.
    Returns the frames and post, the wheel, and the jib."""
    x0, _, z0 = at_point
    hub = (x0, 0.08, z0)
    far = []
    for z in (-0.03, 0.03):
        for x in (-0.055, 0.055):
            far.append(beam("crane frame", (x0 + x, 0.0, z0 + z), (x0, 0.08, z0 + z), 0.008, dark))
    far.append(limb("crane post", (x0 - 0.04, 0.0, z0 - 0.04), (x0 - 0.04, 0.27, z0 - 0.04), 0.008, dark, caps=(False, True)))
    jib = [beam("jib", (x0 - 0.04, 0.25, z0 - 0.04), (x0 - 0.04, 0.27, z0 - 0.18), 0.008, timber),
           limb("fall", (x0 - 0.04, 0.27, z0 - 0.175), (x0 - 0.04, 0.192, z0 - 0.175), 0.002, linen),
           box("load", (x0 - 0.04, 0.18, z0 - 0.175), (0.034, 0.026, 0.03), pale_stone)]
    return far, treadwheel(hub, 0.075, 0.05), jib


def gantry():
    """The great gantry of the fifth level: two A-frames, tied, and a beam
    over the pit, a trolley on it swinging its block; close, a ladder up an
    A-frame. Returns the frames, the trolley and the ladder."""
    far = []
    for x in (-0.2, 0.2):
        for z in (-0.2, 0.0):
            far.append(limb("gantry leg", (x, 0.0, z), (x, 0.32, -0.1), 0.009, dark))
        far.append(beam("gantry tie", (x, 0.12, -0.17), (x, 0.12, -0.03), 0.006, dark))
    far.append(beam("gantry beam", (-0.22, 0.32, -0.1), (0.22, 0.32, -0.1), 0.014, timber))
    trolley = [box("trolley", (0.0, 0.305, -0.1), (0.03, 0.02, 0.03), iron),
               limb("fall", (0.0, 0.3, -0.1), (0.0, 0.2705, -0.1), 0.002, linen),
               box("load", (0.0, 0.254, -0.1), (0.05, 0.035, 0.04), pale_stone)]
    return far, trolley, ladder("gantry ladder", (0.2, 0.0, 0.01), (0.2, 0.31, -0.09), 0.025, 9, pale)


# MARK: Where the stone is worked

def banker(at_point):
    """A banker where a block is dressed: a slab on two piers, the block on
    it; close, its dressed face, a mallet and a chisel laid by, and the chips
    heaped at its foot."""
    x0, _, z0 = at_point
    far = [box("banker pier", (x0 + x, 0.03, z0), (0.022, 0.06, 0.05), dark_stone) for x in (-0.035, 0.035)]
    far.append(box("banker", (x0, 0.066, z0), (0.1, 0.012, 0.06), stone))
    far.append(box("banker block", (x0, 0.094, z0), (0.06, 0.044, 0.04), pale_stone, turn=0.15, chamfer=0.004))
    fine = [box("dressed face", (x0 + 0.012, 0.118, z0), (0.036, 0.004, 0.026), white, turn=0.15),
            limb("mallet haft", (x0 + 0.04, 0.074, z0 + 0.02), (x0 + 0.07, 0.074, z0 + 0.025), 0.003, pale, caps=(True, True)),
            box("mallet", (x0 + 0.036, 0.078, z0 + 0.02), (0.012, 0.01, 0.01), dark),
            beam("chisel", (x0 - 0.045, 0.074, z0 + 0.02), (x0 - 0.015, 0.074, z0 + 0.022), 0.004, steel),
            sphere("chips", (x0, 0.0125, z0 + 0.045), 0.025, pale_stone, bands=2, sides=6, squash=0.25)]
    return far, fine


def shed(at_point):
    """The stone-cutters' shed: open-fronted under slate, a banker at its
    open front."""
    x0, _, z0 = at_point
    body, close = hall("shed", 0.11, 0.1, 0.08, grey, slate, dark, pitch=0.6)
    for obj in body + close:
        placed(obj, at_point, math.pi / 2)
    far, fine = list(body), list(close)
    far.append(box("shed front", (x0 + 0.055, 0.03, z0), (0.004, 0.06, 0.07), dark))
    more, more_fine = banker((x0 + 0.09, 0.0, z0))
    return far + more, fine + more_fine


def rollers(at_point):
    """A block on rollers laid on the floor, a bar under it to lever it
    along."""
    x0, _, z0 = at_point
    far = [log("roller", (x0 - 0.04, 0.02, z0 + z), (x0 + 0.04, 0.02, z0 + z), 0.007) for z in (-0.025, 0.0, 0.025)]
    far.append(box("rolled block", (x0, 0.047, z0), (0.06, 0.04, 0.06), pale_stone, chamfer=0.004))
    far.append(limb("bar", (x0 + 0.028, 0.016, z0 + 0.028), (x0 + 0.058, 0.1, z0 + 0.06), 0.0025, iron, caps=(False, True)))
    return far


def sledge_track():
    """The sledge track down the face: two timber rails, and a sledge with
    its block sat on them; close, a trough of water for the saws."""
    far = [beam("rail", (x - 0.06, 0.012, 0.1), (x - 0.06, 0.2, -0.2), 0.008, dark) for x in (-0.03, 0.03)]
    # The sledge sits on the rails' tops where they pass z = 0.02, tipped to
    # their slope.
    slope = math.atan2(0.188, 0.3)
    normal = (math.cos(slope), math.sin(slope))
    t = (0.1 - 0.02 + 0.004 * normal[1]) / 0.3
    seat = shift(-0.06, 0.012 + 0.188 * t + 0.004 * normal[0], 0.02) @ turn_x(slope)
    far.append(moved(block("sledge", (-0.035, 0.0, -0.03), (0.035, 0.012, 0.03), timber), seat))
    far.append(moved(block("sledge load", (-0.025, 0.012, -0.02), (0.025, 0.042, 0.02), pale_stone, chamfer=0.003), seat))
    fine = [block("saw trough", (0.09, 0.0, 0.17), (0.15, 0.025, 0.21), dark),
            block("saw water", (0.093, 0.021, 0.173), (0.147, 0.026, 0.207), water)]
    return far, fine


def master_house(at_point):
    """The quarry-master's house of stone on a dark footing, slated, its
    door and lit window toward the cut, its chimney on the back slope."""
    x0, _, z0 = at_point
    body, close = hall("house", 0.12, 0.1, 0.09, stone, slate, dark, pitch=0.7, footing=dark_stone)
    for obj in body + close:
        placed(obj, at_point, math.pi / 2)
    far = list(body)
    # The door stands proud of the footing, down to the floor of the cut.
    far.append(box("door", (x0 + 0.0535, 0.04, z0 + 0.02), (0.03, 0.06, 0.02), dark, turn=math.pi / 2))
    far.append(lit("window", (x0 + 0.051, 0.06, z0 - 0.03), 0.018, 0.022, math.pi / 2, window))
    far.append(block("chimney", (x0 - 0.04, 0.08, z0 - 0.05), (x0 - 0.015, 0.16, z0 - 0.025), dark_stone))
    return far, list(close)


def banners():
    """The House's banners on their poles at the cart road, flying inward."""
    poles = []
    for x in (-0.06, 0.06):
        poles.append(limb("banner pole", (x, 0.0, 0.27), (x, 0.22, 0.27), 0.005, dark, caps=(False, True)))
        flag(tagged("quarry banner %s" % ("R" if x > 0 else "L"), ["5"]), (x, 0.215, 0.27), 0.045, 0.09, banner,
             turn=math.pi if x > 0 else 0.0, tail=True)
    return poles


# MARK: The levels

# At every level: the rubble and the lime trough before the cut, rough
# blocks levered out at its side (a course more at each of the first three
# levels), and the spoil strewn about.
piece("quarry yard", [], rubble((-0.06, 0.0, 0.21)) + lime_trough((0.08, 0.0, 0.25)) + blocks((0.19, 0.0, -0.02), 1, False))
piece("quarry blocks", [2, 3, 4, 5], blocks((0.19, 0.0, -0.02), 2, False, first=1))
piece("quarry block", [3, 4, 5], blocks((0.19, 0.0, -0.02), 3, False, first=2))
join("quarry spoil!fine", spoil())

far, fine = face(1)
frame, drum = windlass((0.12, 0.0, 0.1))
lean, tools = lean_to((-0.2, 0.0, 0.0))
piece("quarry", [1], far + frame + blocks((-0.12, 0.0, 0.12), 1, False) + lean, fine + tools)
moving("windlass drum", "quarry windlass@1", drum)

far, fine = face(2)
legs, lashing, load = shear_derrick((0.04, 0.0, 0.04))
lean, tools = lean_to((-0.21, 0.0, -0.02))
piece("quarry", [2], far + legs + blocks((-0.14, 0.0, 0.14), 2, False) + rubble((0.18, 0.0, 0.14)) + lean, fine + lashing + tools)
moving("tackle", "quarry tackle@2", load)

far, fine = shed((-0.19, 0.0, 0.08))
piece("shed", [3, 4], far, fine)

far, fine = face(3)
mast, pegs, boom = boom_derrick((0.0, 0.0, 0.06))
piece("quarry", [3], far + mast + rollers((0.17, 0.0, 0.15)) + blocks((0.06, 0.0, 0.21), 2, True), fine + pegs)
moving("boom", "quarry boom@3", boom)

far, fine = face(4)
frames, wheel_pieces, jib = tread_crane((0.18, 0.0, 0.06))
track, trough = sledge_track()
piece("quarry", [4], far + frames + track + blocks((-0.02, 0.0, 0.21), 3, True), fine + trough)
moving("treadwheel", "quarry treadwheel@4", wheel_pieces)
moving("jib", "quarry jib@4", jib)

far, fine = face(5)
frames, trolley, steps = gantry()
house, house_close = master_house((-0.18, 0.0, 0.09))
piece("quarry", [5], far + frames + house + blocks((0.17, 0.0, 0.18), 3, True) + banners(), fine + steps + house_close)
moving("trolley", "quarry trolley@5", trolley)

# What lifts the stone works: the windlass turns once round, the tackle,
# the boom, the jib and the trolley swing out and back, the treadwheel is
# walked once round.
idle(rig, turns=[("quarry windlass@1", (1, 0, 0), wheel_turns(1)),
                 ("quarry tackle@2", (1, 0, 0), lambda u: 0.3 * swing(u)),
                 ("quarry boom@3", (0, 1, 0), lambda u: 0.8 * swing(u)),
                 ("quarry treadwheel@4", (0, 0, 1), wheel_turns(1)),
                 ("quarry jib@4", (0, 1, 0), lambda u: 0.6 * swing(u)),
                 ("quarry trolley@5", (1, 0, 0), lambda u: 0.4 * swing(u))])

finish_building(out_path("Art/models/quarry.glb"), [str(level) for level in LEVELS])
