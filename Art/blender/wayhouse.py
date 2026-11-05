"""The Wayhouse, the post-house where the House's roads begin and its riders
change horses; its five levels the tiers of one file, each within a work's
slot and facing +z, the road running past its front:
1. a thatched waystation with a horse tethered at its post, a trough, a
   signpost at the road and the inn's sign swinging on its bracket;
2. a timber inn hall on a stone footing, a stable range of two bays, a horse
   looking out of each, a rick of hay under its thatch cap;
3. the inn rebuilt in pale stone, two storeys, the round cote for the
   post-birds with a vane turning on it, the road cobbled;
4. a gate over the road with its lantern lit, a post-coach in the yard;
5. a waymark pillar crowned with a moonsalt lamp, a long stable range of
   three bays and a second coach, the first's team standing in its traces.
Close: the road's ruts and cobbles, each hall's roof courses, bargeboards,
vents and rafters' ends, the timber inn's studs and the stone inn's string
course, the stables' door ledges and latches, the cote's string courses and
the post-birds about its foot, a bucket by the trough, the rick's prop.
The inn's sign swings on its bracket; the vane turns on the cote.

    python Art/blender/wayhouse.py Art/models/wayhouse.glb
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *
import bmesh
import bpy
from mathutils import Vector

reset()
LEVELS = [1, 2, 3, 4, 5]

yard = material("plain_earth_yard", (0.31, 0.29, 0.25))
loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
earth = material("plain_earth", (0.24, 0.21, 0.18))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
white_stone = material("plain_stone_white", (0.84, 0.84, 0.82))
slate = material("plain_slate", (0.23, 0.24, 0.28))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
straw = material("plain_thatch_straw", (0.62, 0.55, 0.36))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
weld = material("plain_weld", (0.55, 0.49, 0.27))
madder = material("plain_madder", (0.44, 0.24, 0.19))
leather = material("plain_leather", (0.36, 0.25, 0.17))
harness = material("plain_leather_dark", (0.22, 0.16, 0.12))
hair = material("plain_hair", (0.21, 0.17, 0.14))
bay = material("plain_horse_bay", (0.36, 0.23, 0.15))
dun = material("plain_horse_dun", (0.52, 0.43, 0.31))
grey_coat = material("plain_horse_grey", (0.62, 0.62, 0.62))
black_coat = material("plain_horse_black", (0.13, 0.12, 0.12))
wool = material("plain_wool", (0.39, 0.37, 0.33))
ash = material("plain_ash", (0.55, 0.56, 0.56))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.4, metallic=0.8)
candle = material("glow_candle", (1.0, 0.8, 0.52))
moonsalt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)

# The packed ground's top (works.pad): what stands on the ground is set down
# on it. The game's Wayhouse stood all at nought, sunk in the pad, where its
# road, its ruts and its birds never showed and its beasts stood to the
# fetlock in it.
G = 0.012
PAD = 0.31
TOP = PAD * 0.95
# The road's face, a little proud of the ground.
ROAD = G + 0.003
# The cote is made rounder than the game's eight sides.
COTE_SIDES = 10
# The stables' horses, bay by bay.
COATS = [bay, grey_coat, black_coat]

# Where the inn's sign stands, and the cote, at each level.
SIGNS = {1: (0.04, 0.0, 0.0), 2: (0.04, 0.0, 0.0), 3: (0.06, 0.0, 0.0), 4: (0.06, 0.0, 0.0), 5: (0.04, 0.0, 0.0)}
COTES = {3: (-0.21, 0.0, 0.07), 4: (-0.22, 0.0, 0.06), 5: (-0.23, 0.0, 0.06)}
# How high the vane turns on the cote.
VANE = 0.25


def hinge(level):
    """Where the inn's sign hangs from its bracket at a level."""
    x, _, z = SIGNS[level]
    return (x + 0.045, 0.156, z)


def vane_pivot(level):
    """Where the vane turns on its spindle at a level."""
    x, _, z = COTES[level]
    return (x, VANE, z)


rig = work_rig([("inn sign@%d" % level, hinge(level), (1, 0, 0)) for level in LEVELS]
               + [("post vane@%d" % level, vane_pivot(level), (0, 1, 0)) for level in COTES])
ground(pad(tagged("pad", []), PAD, yard), rig)


# MARK: Shapes the game's builder makes that the shared ones don't

def joined(name, pieces):
    """Pieces joined into one object so named."""
    if len(pieces) == 1:
        pieces[0].name = name
        return pieces[0]
    return join(name, pieces)


def piece(name, levels, far, fine=()):
    """Pieces drawn at these levels joined, far and near."""
    tags = level_tags(levels)
    if far:
        joined(tagged(name, tags), list(far))
    if fine:
        joined(tagged(name + " close", tags) + "!fine", list(fine))


def moving(name, level, bone, pieces):
    """A level's moving part, its pieces joined and hung on its bone."""
    on(joined(tagged(name, level_tags([level])), pieces), rig, "%s@%d" % (bone, level))


def cbox(name, centre, size, mat, turn=0.0):
    """A block about its middle, turned `turn` as the game turns a box (its
    own +x toward -z): MeshBuilder.box(center:size:turn:)."""
    (x, y, z), (w, h, d) = centre, size
    return block(name, (x - w / 2, y - h / 2, z - d / 2), (x + w / 2, y + h / 2, z + d / 2), mat, turn=-turn)


def beam(name, a, b, width, mat, depth=None):
    """A squared timber from one point to another, squared as the game
    squares one (MeshBuilder.beam): `width` across the ground and `depth`
    deep if it lies, `width` east to west if it stands."""
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


def limb(name, a, b, radius, mat, top=None, sides=4, caps=(False, False), depth=None):
    """A pole of `sides` faces from one point to another, narrowing to `top`,
    its ends left open where what it stands in hides them (MeshBuilder.limb);
    `depth`, if given, its share front to back against its breadth."""
    r0, r1 = radius * UNIT, (radius if top is None else top) * UNIT
    s = 1.0 if depth is None else depth
    return loft(name, [(tuple(at(*a)), r0, r0 * s, {}), (tuple(at(*b)), r1, r1 * s, {})], segments=sides, mat=mat, caps=caps, smooth=False)


def ground_y(x, z):
    """How high the packed ground stands at (x, z): flat on its top, falling
    to nought at its rim (works.pad's twelve sides)."""
    r = math.hypot(x, z)
    step = math.pi / 6
    theta = math.atan2(z, x)
    off = theta - round(theta / step) * step
    top = TOP * math.cos(step / 2) / math.cos(off)
    rim = PAD * math.cos(step / 2) / math.cos(off)
    if r <= top:
        return G
    if r >= rim:
        return 0.0
    return G * (rim - r) / (rim - top)


def on_top(outline, inset=0.002):
    """A flat outline (x, z) cut to the packed ground's top, `inset` within
    its edge."""
    step = math.pi / 6
    reach = (TOP * math.cos(step / 2) - inset) / math.cos(step / 2)
    edge = [(reach * math.cos(step / 2 + k * step), reach * math.sin(step / 2 + k * step)) for k in range(12)]
    out = list(outline)
    for k in range(12):
        (px, pz), (qx, qz) = edge[k], edge[(k + 1) % 12]
        inside = [(qx - px) * (v[1] - pz) - (qz - pz) * (v[0] - px) for v in out]
        kept = []
        for i in range(len(out)):
            a, b, sa, sb = out[i - 1], out[i], inside[i - 1], inside[i]
            if (sa < 0) != (sb < 0):
                t = sa / (sa - sb)
                kept.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            if sb >= 0:
                kept.append(b)
        out = kept
    points = []
    for p in out:
        if not points or math.dist(p, points[-1]) > 1e-6:
            points.append(p)
    if len(points) > 1 and math.dist(points[0], points[-1]) <= 1e-6:
        points.pop()
    return points


def rect(x0, z0, x1, z1):
    """A rectangle's outline (x, z), counter-clockwise from +x to +z."""
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def laid(name, outline, low, high, mat):
    """A flat piece laid on the ground from `low` to `high`, its outline
    (x, z) cut to the ground's top."""
    y = (low + high) / 2
    return slab(name, [(x, y, z) for x, z in on_top(outline)], mat, high - low, normal=(0, 1, 0))


def trough_body(name, low, high, wall, water, mat, water_mat):
    """A trough open at its top, its walls `wall` thick and the water
    standing `water` high within them."""
    (x0, y0, z0), (x1, y1, z1) = low, high
    outer = ((x0, z0), (x1, z0), (x1, z1), (x0, z1))
    inner = ((x0 + wall, z0 + wall), (x1 - wall, z0 + wall), (x1 - wall, z1 - wall), (x0 + wall, z1 - wall))

    def build(bm):
        base = [bm.verts.new(at(x, y0, z)) for x, z in outer]
        lip = [bm.verts.new(at(x, y1, z)) for x, z in outer]
        rim = [bm.verts.new(at(x, y1, z)) for x, z in inner]
        pool = [bm.verts.new(at(x, water, z)) for x, z in inner]
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


def lean_to(name, x0, x1, front, back, thickness, top_mat, under_mat):
    """A lean-to roof between x0 and x1, its top from the front eave (z, y)
    up to the back one, `thickness` deep beneath: slate above, its boards
    dark beneath and at its edges."""
    (zf, yf), (zb, yb) = front, back
    corners = ((x0, yf, zf), (x1, yf, zf), (x1, yb, zb), (x0, yb, zb))

    def build(bm):
        top = [bm.verts.new(at(x, y, z)) for x, y, z in corners]
        under = [bm.verts.new(at(x, y - thickness, z)) for x, y, z in corners]
        bm.faces.new(top)
        bm.faces.new(list(reversed(under)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((under[i], under[j], top[j], top[i]))
    obj = mesh_object(name, build, top_mat)
    obj.data.materials.append(under_mat)
    for poly in obj.data.polygons:
        if poly.normal.z < 0.5:
            poly.material_index = 1
    return obj


def octa(name, centre, rx, ry, rz, mat):
    """A little body of eight faces about `centre`, reaching rx, ry and rz."""
    x, y, z = centre

    def build(bm):
        v = [bm.verts.new(at(*p)) for p in ((x + rx, y, z), (x, y, z - rz), (x - rx, y, z), (x, y, z + rz), (x, y + ry, z), (x, y - ry, z))]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((v[i], v[j], v[4]))
            bm.faces.new((v[j], v[i], v[5]))
    return mesh_object(name, build, mat)


def coach_wheel(name, centre, radius, width, rim_mat, spoke_mat, sides=8):
    """A spoked wheel on its axle along z, about `centre`: its rim a hoop of
    three faces, its tread and two cheeks, and two spokes crossing at the
    hub (the game's were solid discs, their spokes hidden within, standing
    across the coach's way)."""
    cx, cy, cz = centre
    inner = radius * 0.72

    def build(bm):
        made = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            c, s = math.cos(a), math.sin(a)
            made.append((bm.verts.new(at(cx + radius * c, cy + radius * s, cz + width / 2)),
                         bm.verts.new(at(cx + radius * c, cy + radius * s, cz - width / 2)),
                         bm.verts.new(at(cx + inner * c, cy + inner * s, cz))))
        for k in range(sides):
            (f0, b0, i0), (f1, b1, i1) = made[k], made[(k + 1) % sides]
            bm.faces.new((f0, f1, b1, b0))
            bm.faces.new((f0, i0, i1, f1))
            bm.faces.new((b0, b1, i1, i0))
    reach, thick = inner + 0.0015, 0.003
    return [mesh_object(name, build, rim_mat),
            block(name + " spoke", (cx - reach, cy - thick / 2, cz - thick / 2), (cx + reach, cy + thick / 2, cz + thick / 2), spoke_mat),
            block(name + " spoke", (cx - thick / 2, cy - reach, cz - thick / 2), (cx + thick / 2, cy + reach, cz + thick / 2), spoke_mat)]


def decal(name, centre, width, height, facing, mat):
    """A flat patch `width` by `height` about `centre` (the world's), looking
    out along `facing` radians round from +z: a hole's dark mouth, laid a
    hair proud of the wall it opens in."""
    c, s = math.cos(facing), math.sin(facing)
    x, y, z = centre
    corners = [(x + u * c, y + v, z - u * s) for u, v in ((-width / 2, -height / 2), (width / 2, -height / 2), (width / 2, height / 2),
                                                          (-width / 2, height / 2))]
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new(at(*p)) for p in corners])
    face.normal_update()
    if face.normal.dot(Vector((s, -c, 0.0))) < 0:
        face.normal_flip()
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons[0].use_smooth = False
    mesh.materials.append(mat)
    return obj


def round_body(radius, height, wall, roof, band, finial, sides):
    """A round tower under a cone, about the origin, as works.round_house
    makes one (its fine work two courses about its wall, a ring round its
    roof and a finial), but its roof's ring laid on the cone's slope, where
    the shared one's upper edge stood off it."""
    rise, eave = radius * 1.5, radius * 1.18
    far = [rings("wall", [(radius, -0.06), (radius, height)], sides, wall),
           rings("roof", [(eave, height), (0.0, height + rise)], sides, roof)]
    fine = []
    for y in (height * 0.3, height * 0.72):
        fine.append(rings("band", [(radius * 0.98, y), (radius * 1.05, y + 0.004), (radius * 1.05, y + 0.013), (radius * 0.98, y + 0.017)],
                          sides, band, caps=(False, False)))

    def slope(y):
        return eave * (1 - (y - height) / rise)

    y = height + rise * 0.45
    fine.append(rings("roof ring", [(slope(y - 0.006) - 0.0006, y - 0.006), (slope(y) + 0.0025, y), (slope(y + 0.008) - 0.0006, y + 0.008)],
                      sides, roof, caps=(False, False)))
    fine.append(rings("finial", [(0.006, height + rise - 0.012), (0.002, height + rise + 0.035)], 4, finial))
    return far, fine


def on_round(radius, sides, angle):
    """How far out the face of a round body of `sides` (works.rings') is met
    at `angle` (as the game's ring counts it), and the angle that face looks
    along."""
    step = 2 * math.pi / sides
    middle = (math.floor(angle / step) + 0.5) * step
    return radius * math.cos(step / 2) / math.cos(angle - middle), middle


# MARK: What the Wayhouse is built of

def road():
    """The road past the front, laid on the ground and cut to its rim: loam
    rutted by the wheels, cobbled from the third level."""
    span = rect(-0.2, 0.16, 0.2, 0.24)
    piece("road", [1, 2], [laid("road", span, G - 0.001, ROAD, loam)])
    piece("road", [3, 4, 5], [laid("road", span, G - 0.001, ROAD, stone)])
    join("ruts!fine", [laid("rut", rect(-0.19, z - 0.004, 0.19, z + 0.004), ROAD - 0.0004, ROAD + 0.0008, earth) for z in (0.185, 0.215)])
    cobbles = []
    for index in range(10):
        x, z = -0.18 + index * 0.04, 0.2 + (-0.02 if index % 2 == 0 else 0.02)
        cobbles.append(laid("cobble", rect(x - 0.013, z - 0.01, x + 0.013, z + 0.01), ROAD - 0.0004, ROAD + 0.0018, pale_stone))
    join(tagged("cobbles", level_tags([3, 4, 5])) + "!fine", cobbles)


def waystation(at_point):
    """A thatched waystation: low timber walls, its door, a lit window, its
    chimney stack (raised to stand clear of the thatch)."""
    x0, _, z0 = at_point
    body, close = hall("waystation", 0.18, 0.12, 0.09, timber, thatch, dark, pitch=0.75)
    for obj in body + close:
        placed(obj, at_point)
    front = z0 + 0.06
    far = list(body) + [block("door", (x0 + 0.004, 0.005, front - 0.008), (x0 + 0.036, 0.075, front + 0.012), dark),
                        lit("window", (x0 - 0.05, 0.055, front + 0.002), 0.022, 0.024, 0.0, candle)]
    cx, cz = x0 - 0.07, z0 - 0.02
    far.append(block("chimney", (cx - 0.0115, 0.0, cz - 0.0115), (cx + 0.0115, 0.2, cz + 0.0115), dark_stone))
    far.append(block("chimney cap", (cx - 0.0145, 0.193, cz - 0.0145), (cx + 0.0145, 0.203, cz + 0.0145), stone))
    return far, list(close)


def inn(at_point, stone_built, width):
    """The inn: timber or pale stone on a footing of stone, two storeys when
    of stone, its door, its windows lit above and below, its chimney."""
    x0, _, z0 = at_point
    depth, height = 0.13, (0.16 if stone_built else 0.11)
    front = z0 + depth / 2
    body, close = hall("inn", width, depth, height, pale_stone if stone_built else timber, slate, dark, pitch=0.7, footing=stone)
    for obj in body + close:
        placed(obj, at_point)
    far, fine = list(body), list(close)
    # The door comes out to the footing's face, so it stands at the ground,
    # a step before it.
    far.append(block("door", (x0 + 0.011, 0.005, front - 0.006), (x0 + 0.049, 0.085, front + 0.0135), dark))
    fine.append(block("doorstep", (x0 + 0.006, G - 0.004, front + 0.0125), (x0 + 0.054, G + 0.006, front + 0.028), pale_stone))
    for x in (-0.07, -0.025):
        far.append(lit("window", (x0 + x, 0.055, front + 0.002), 0.022, 0.026, 0.0, candle))
    if stone_built:
        for x in (-0.07, 0.0, 0.07):
            far.append(lit("window", (x0 + x, 0.12, front + 0.002), 0.02, 0.024, 0.0, candle))
        fine.append(block("string course", (x0 - width / 2, 0.088, front - 0.001), (x0 + width / 2, 0.096, front + 0.006), white_stone))
    else:
        x = -width / 2 + 0.01
        while x <= width / 2 + 1e-9:
            fine.append(block("stud", (x0 + x - 0.003, 0.038, front), (x0 + x + 0.003, height, front + 0.006), dark))
            x += 0.055
    fx, fz = x0 - width / 2 + 0.03, z0 - 0.02
    top = height + 0.11
    far.append(block("chimney", (fx - 0.018, 0.0, fz - 0.018), (fx + 0.018, top, fz + 0.018), dark_stone))
    far.append(block("chimney cap", (fx - 0.021, top - 0.007, fz - 0.021), (fx + 0.021, top + 0.003, fz + 0.021), stone))
    return far, fine


def sign_post(at_point):
    """The post the inn's sign hangs from, its bracket and the brace under it."""
    x0, _, z0 = at_point
    return [block("sign post", (x0 - 0.0042, -0.02, z0 - 0.0042), (x0 + 0.0042, 0.17, z0 + 0.0042), dark),
            beam("bracket", (x0, 0.16, z0), (x0 + 0.06, 0.16, z0), 0.006, dark),
            beam("brace", (x0, 0.12, z0), (x0 + 0.04, 0.16, z0), 0.004, dark)]


def sign_board(level):
    """The inn's sign on its chains, a horse on it, its own part to swing."""
    hx, hy, hz = hinge(level)
    board = [limb("chain", (hx + dx, 0.159, hz), (hx + dx, 0.14, hz), 0.0015, iron, sides=3) for dx in (-0.012, 0.012)]
    board.append(cbox("sign board", (hx, hy - 0.035, hz), (0.045, 0.04, 0.005), weld))
    board.append(cbox("sign horse", (hx, hy - 0.035, hz), (0.022, 0.022, 0.007), dun))
    moving("sign board", level, "inn sign", board)


def horse(at_point, turn, coat):
    """A horse standing on the ground, head down a little, made facing -x and
    turned `turn` as the game turns it: its barrel, legs, neck and head, its
    tail and saddle-cloth."""
    u = UNIT
    pieces = [loft("horse", [(tuple(at(-0.027, 0.05, 0.0)), 0.0105 * u, 0.012 * u, {}),
                             (tuple(at(0.0, 0.051, 0.0)), 0.0115 * u, 0.0135 * u, {}),
                             (tuple(at(0.026, 0.052, 0.0)), 0.011 * u, 0.0125 * u, {})], segments=6, mat=coat, smooth=False)]
    for x, z in ((-0.019, -0.0065), (-0.019, 0.0065), (0.018, -0.0065), (0.018, 0.0065)):
        pieces.append(limb("leg", (x, 0.046, z), (x, 0.0, z), 0.0035, coat, top=0.0028))
    pieces.append(limb("neck", (-0.021, 0.055, 0.0), (-0.039, 0.077, 0.0), 0.0075, coat, top=0.0055, caps=(False, True)))
    pieces.append(limb("head", (-0.036, 0.08, 0.0), (-0.057, 0.065, 0.0), 0.0058, coat, top=0.0038, caps=(True, True)))
    pieces.append(limb("tail", (0.024, 0.057, 0.0), (0.034, 0.027, 0.0), 0.0028, hair, top=0.0014, caps=(False, True)))
    pieces.append(cbox("saddle", (0.0, 0.0635, 0.0), (0.02, 0.004, 0.03), harness))
    for obj in pieces:
        placed(obj, (at_point[0], G, at_point[2]), turn)
    return pieces


def tether(at_point, coat):
    """A horse tethered at its post, facing it."""
    x0, _, z0 = at_point
    return [limb("tether post", (x0 - 0.05, -0.02, z0), (x0 - 0.05, G + 0.07, z0), 0.005, dark, sides=6, caps=(False, True)),
            limb("tether", (x0 - 0.05, G + 0.06, z0), (x0 - 0.03, G + 0.065, z0), 0.0015, leather, sides=3)] + horse(at_point, 0.0, coat)


def trough(at_point):
    """A trough of timber, water in it; near, a bucket by it."""
    x0, _, z0 = at_point
    far = [trough_body("trough", (x0 - 0.045, G - 0.004, z0 - 0.016), (x0 + 0.045, G + 0.03, z0 + 0.016), 0.004, G + 0.025, dark, slate)]
    return far, [rings("bucket", [(0.012, G - 0.001), (0.014, G + 0.022)], 6, timber, centre=(x0 + 0.06, z0))]


def signpost(at_point):
    """A signpost at the road, its arms pointing two ways."""
    x0, _, z0 = at_point
    far = [block("signpost", (x0 - 0.0035, -0.02, z0 - 0.0035), (x0 + 0.0035, 0.15, z0 + 0.0035), dark)]
    for y, turn in ((0.135, 0.5), (0.11, -0.7)):
        c, s = math.cos(turn), math.sin(turn)
        outline = [(-0.035, 0.0), (-0.028, -0.0075), (0.028, -0.0075), (0.035, 0.0), (0.028, 0.0075), (-0.028, 0.0075)]
        far.append(slab("finger", [(x0 + p * c, y + q, z0 - p * s) for p, q in outline], pale, 0.005, normal=(s, 0.0, c)))
    return far


def looking_out(mid, z0, coat):
    """A horse looking out over its half-door: its neck up out of the stall,
    its head down toward the yard."""
    return [limb("stabled neck", (mid, 0.044, z0 + 0.012), (mid, 0.073, z0 + 0.04), 0.0085, coat, top=0.0065, depth=0.8),
            limb("stabled head", (mid, 0.076, z0 + 0.036), (mid, 0.06, z0 + 0.064), 0.0062, coat, top=0.0042, caps=(True, True), depth=0.8)]


def stables(at_point, bays):
    """A stable range under a lean-to slate roof: its back wall, its stalls
    parted, their half-doors, a horse looking out of each."""
    x0, _, z0 = at_point
    span = 0.075
    left, right = x0 - bays * span / 2, x0 + bays * span / 2

    def under(z):
        """The roof's underside a depth `z` in from the range's middle."""
        return 0.08 + 0.025 * (0.05 - z) / 0.115

    far = [block("stable wall", (left, -0.04, z0 - 0.06), (right, under(-0.06) + 0.003, z0 - 0.05), dark),
           lean_to("stable roof", left - 0.01, right + 0.01, (z0 + 0.05, 0.09), (z0 - 0.065, 0.115), 0.01, slate, dark)]
    fine = []
    for bay_line in range(bays + 1):
        x = left + bay_line * span
        far.append(block("stable post", (x - 0.0035, -0.02, z0 + 0.0415), (x + 0.0035, under(0.045) + 0.005, z0 + 0.0485), dark))
        far.append(slab("stall side", [(x, -0.04, z0 - 0.05), (x, -0.04, z0 + 0.042), (x, under(0.042) + 0.003, z0 + 0.042),
                                       (x, under(-0.05) + 0.003, z0 - 0.05)], timber, 0.004, normal=(1, 0, 0)))
        if bay_line == bays:
            continue
        mid = x + span / 2
        far.append(block("half-door", (mid - 0.03, -0.01, z0 + 0.036), (mid + 0.03, 0.045, z0 + 0.042), timber))
        far += looking_out(mid, z0, COATS[bay_line % len(COATS)])
        fine.append(cbox("ledge", (mid, 0.03, z0 + 0.043), (0.05, 0.004, 0.003), dark))
        fine.append(cbox("latch", (mid + 0.024, 0.024, z0 + 0.0435), (0.004, 0.012, 0.003), iron))
    return far, fine


def rick(at_point):
    """A rick of hay under its thatch cap; near, a prop against it."""
    x0, _, z0 = at_point
    far = [rings("rick", [(0.038, G - 0.003), (0.042, G + 0.04), (0.032, G + 0.07), (0.0, G + 0.09)], 8, straw, centre=(x0, z0)),
           rings("rick cap", [(0.034, G + 0.066), (0.0, G + 0.095)], 8, thatch, centre=(x0, z0))]
    return far, [beam("rick prop", (x0 + 0.045, G - 0.002, z0), (x0 + 0.02, G + 0.08, z0 + 0.02), 0.004, pale)]


def bird(foot, heading, mat):
    """A post-bird on the ground: its body and its head, made facing +x and
    turned `heading` as the game turns."""
    pieces = [octa("bird", (0.0, 0.0037, 0.0), 0.0075, 0.0042, 0.0045, mat),
              octa("bird head", (0.005, 0.0072, 0.0), 0.0032, 0.003, 0.0026, mat)]
    for obj in pieces:
        placed(obj, foot, heading)
    return pieces


def cote(level):
    """The round cote for the post-birds, its rows of holes and its spindle;
    the vane on it, its own part to turn; near, the birds about its foot."""
    x0, _, z0 = COTES[level]
    radius = 0.045
    body, close = round_body(radius, 0.17, pale_stone, slate, pale_stone, dark, COTE_SIDES)
    for obj in body + close:
        placed(obj, (x0, 0.0, z0))
    far, fine = list(body), list(close)
    # The holes lie in the faces of the wall, the upper row above its upper
    # course.
    for y in (0.11, 0.146):
        for angle in (0.3, 1.2, 2.1, 3.0):
            reach, middle = on_round(radius, COTE_SIDES, angle)
            px, _, pz = on_ring(reach, y, angle, centre=(x0, z0))
            proud = 0.0015
            far.append(decal("hole", (px + math.cos(middle) * proud, y, pz - math.sin(middle) * proud), 0.012, 0.012, middle + math.pi / 2,
                             dark))
    far.append(rod("spindle", (x0, VANE - 0.03, z0), (x0, VANE + 0.02, z0), 0.002, iron, sides=4))
    y = VANE + 0.02
    vane = [cbox("vane", (x0 + 0.008, y, z0), (0.04, 0.003, 0.002), iron),
            slab("vane tail", [(x0 - 0.017, y, z0), (x0 - 0.003, y, z0), (x0 - 0.003, y + 0.012, z0), (x0 - 0.017, y + 0.014, z0)], gold, 0.002),
            slab("vane point", [(x0 + 0.027, y - 0.0045, z0), (x0 + 0.036, y, z0), (x0 + 0.027, y + 0.0045, z0)], gold, 0.002)]
    moving("vane", level, "post vane", vane)
    for index, angle in enumerate((0.4, 1.6, 2.6)):
        fx, _, fz = on_ring(0.07, 0.0, angle, centre=(x0, z0))
        fine += bird((fx, ground_y(fx, fz), fz), angle + 1.9 + index * 0.8, wool if index == 1 else ash)
    return far, fine


def gate():
    """A gate over the road: two posts of stone under their copings, a
    lintel between them, a little slate roof over all (the game's stood in
    the middle of the yard), and its lantern lit beneath on its hook."""
    gx, gz = 0.0, 0.22
    far = []
    for x in (-0.08, 0.08):
        far.append(block("gate post", (gx + x - 0.013, -0.02, gz - 0.013), (gx + x + 0.013, 0.18, gz + 0.013), stone))
        far.append(block("coping", (gx + x - 0.017, 0.179, gz - 0.017), (gx + x + 0.017, 0.192, gz + 0.017), pale_stone))
    far.append(block("lintel", (gx - 0.095, 0.171, gz - 0.009), (gx + 0.095, 0.1915, gz + 0.009), dark))
    far.append(gable_roof("gate roof", (gx, gz), 0.04, 0.2, 0.199, 0.03, slate, overhang=0.005, along="x", thickness=0.008))
    far.append(rod("lantern hook", (gx, 0.172, gz), (gx, 0.14, gz), 0.0018, iron, sides=3))
    far.append(rings("lantern cap", [(0.0115, 0.135), (0.0, 0.143)], 4, iron, centre=(gx, gz), twist=math.pi / 4))
    far.append(block("lantern", (gx - 0.008, 0.113, gz - 0.008), (gx + 0.008, 0.1352, gz + 0.008), candle))
    return far


def coach(at_point, turn):
    """A post-coach made along +x and turned `turn` as the game turns it: its
    body on four wheels on their axletrees, its windows lit, its pole down
    to the ground, luggage on its roof."""
    pieces = [block("coach body", (-0.04, 0.03, -0.024), (0.04, 0.08, 0.024), madder),
              block("coach roof", (-0.043, 0.078, -0.027), (0.043, 0.084, 0.027), dark),
              block("luggage", (-0.02, 0.0835, -0.015), (0.02, 0.1, 0.015), leather)]
    for z in (-0.024, 0.024):
        pieces.append(lit("coach window", (0.0, 0.055, z), 0.02, 0.026, 0.0, candle, depth=0.003))
    for x, r in ((-0.028, 0.022), (0.03, 0.017)):
        pieces.append(block("axletree", (x - 0.003, r - 0.003, -0.0295), (x + 0.003, 0.032, 0.0295), dark))
        for z in (-0.03, 0.03):
            pieces += coach_wheel("wheel", (x, r, z), r, 0.005, dark, timber)
    pieces.append(beam("coach pole", (0.03, 0.02, 0.0), (0.11, 0.0025, 0.0), 0.005, dark))
    for obj in pieces:
        placed(obj, (at_point[0], G, at_point[2]), turn)
    return pieces


def waymark(at_point):
    """The waymark: a pillar of white stone on its plinth, a moonsalt lamp
    burning on it."""
    x0, _, z0 = at_point
    return [block("plinth", (x0 - 0.025, -0.01, z0 - 0.025), (x0 + 0.025, G + 0.02, z0 + 0.025), stone),
            rings("pillar", [(0.02, G + 0.02), (0.015, G + 0.22)], 8, white_stone, centre=(x0, z0), twist=math.pi / 8),
            rings("lamp", [(0.0, G + 0.22), (0.018, G + 0.25), (0.0, G + 0.285)], 6, moonsalt, centre=(x0, z0))]


# MARK: The levels

road()
piece("sign", [1, 2, 5], sign_post(SIGNS[1]))
piece("sign", [3, 4], sign_post(SIGNS[3]))
for level in LEVELS:
    sign_board(level)

# 1. The thatched waystation, its horse at the post, the trough and the
# signpost at the road.
far, fine = waystation((-0.08, 0.0, -0.1))
water, water_close = trough((0.15, 0.0, 0.08))
piece("wayhouse", [1], far + tether((0.14, 0.0, -0.02), bay) + water + signpost((-0.2, 0.0, 0.14)), fine + water_close)

# 2. The timber inn, the stables of two bays and the rick.
far, fine = inn((-0.09, 0.0, -0.12), False, 0.22)
stalls, stalls_close = stables((0.18, 0.0, -0.08), 2)
hay, hay_close = rick((0.22, 0.0, 0.08))
water, water_close = trough((0.07, 0.0, 0.08))
piece("wayhouse", [2], far + stalls + hay + water + signpost((-0.2, 0.0, 0.14)), fine + stalls_close + hay_close + water_close)

# 3 and 4. The inn of pale stone and the stables, the same at both.
far, fine = inn((-0.08, 0.0, -0.12), True, 0.24)
stalls, stalls_close = stables((0.2, 0.0, -0.08), 2)
piece("inn", [3, 4], far + stalls, fine + stalls_close)

# 3. The cote, the cobbled road, the trough, the rick and the signpost.
far, fine = cote(3)
water, water_close = trough((0.12, 0.0, 0.08))
hay, hay_close = rick((0.23, 0.0, 0.1))
piece("wayhouse", [3], far + water + hay + signpost((-0.08, 0.0, 0.18)), fine + water_close + hay_close)

# 4 and 5. The gate over the road.
piece("gate", [4, 5], gate())

# 4. The post-coach in the yard, a grey at the post.
far, fine = cote(4)
water, water_close = trough((-0.09, 0.0, 0.09))
piece("wayhouse", [4], far + coach((0.16, 0.0, 0.08), 0.3) + water + tether((0.05, 0.0, 0.04), grey_coat), fine + water_close)

# 5. The inn moved over for the long stables of three bays, two coaches, the
# first's team in its traces, the waymark at the road. The rick stands
# behind the stables (the game's stood within the cote's wall).
far, fine = inn((-0.1, 0.0, -0.12), True, 0.24)
stalls, stalls_close = stables((0.17, 0.0, -0.06), 3)
more, more_close = cote(5)
team = []
for index, x in enumerate((0.2, 0.235)):
    team += horse((x, 0.0, 0.06 + index * 0.018), math.pi + 0.3, grey_coat if index == 0 else bay)
water, water_close = trough((-0.2, 0.0, -0.01))
hay, hay_close = rick((0.12, 0.0, -0.2))
piece("wayhouse", [5], far + stalls + more + coach((0.12, 0.0, 0.1), 0.3) + coach((-0.12, 0.0, 0.13), -0.2) + waymark((0.2, 0.0, 0.18))
      + team + tether((-0.02, 0.0, 0.03), dun) + water + signpost((-0.19, 0.0, 0.2)) + hay,
      fine + stalls_close + more_close + water_close + hay_close)

# Its sign swinging on its bracket and its vane turning once in the idle
# (Machinery's swing and wheel in the game).
idle(rig, turns=[("inn sign@%d" % level, (1, 0, 0), lambda u: 0.22 * swing(u)) for level in LEVELS]
     + [("post vane@%d" % level, (0, 1, 0), wheel_turns(1)) for level in COTES])

finish_building(out_path("Art/models/wayhouse.glb"), [str(level) for level in LEVELS])
