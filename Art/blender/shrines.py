"""The holy sites of the lake, each kind a variant of one file: a ring of
seven standing stones about its heart, lintels laid across them pair by pair
but at the way in, lesser stones lining that and a brazier burning either
side of it, a worn floor of flags within, and a pennant in its holder's
colour on a pole. Its heart:
- the moonwell, a well that holds the moon, motes of moonlight circling over
  its water; close, its coping with a lamp burning on every third stone, an
  arch over it crowned with the crescent, a silver bowl hung from it on a
  chain to draw the moon's water, stones to kneel on before it;
- the still stone, a dark stone that never stirs, a ring of black water-drops
  held in the air about it, turning so slowly it seems to stand; close,
  pilgrims' ribbons tied about the ring's stones stirring in the wind, a
  kerb about it and cairns of flat stones its pilgrims have left;
- the salt altar, crusted with moonsalt, a crown of salt crystals turning
  over it; close, its step and overhanging top, a crescent cut in its face,
  bowls of salt and a salt-knife on it, candles either side, sacks of
  moonsalt brought to it and moonsalt grown up from the floor behind it;
- the broken spire, the last age's Moonspire, a tall tapering shaft of pale
  stone snapped and leaning, its fallen courses about its foot, the shards
  of its crown still turning where it broke; close, carved bands about the
  shaft, moonsalt glinting in its seams, its head fallen out between two
  stones of the ring, rubble;
- the heartstone, the stone in the Crown's heart, a tall dark menhir on a
  stepped plinth veined with moonsalt, a halo of motes circling its crown;
  close, braziers burning at its four quarters, swords offered point down
  about its plinth, the shields of fallen Houses laid against it and runes
  cut in the plinth, glowing.
Close, every one shows its floor's flags, the socket its pole stands in and
grass at every other stone's foot. Its motes turn as a wheel; its fires leap.

    python Art/blender/shrines.py Art/models/shrines.glb

Built as the game's Land.shrine built them in code (Sources/NullmereModels/
Land.swift), solid for solid: the Shape below lays triangles as the game's
MeshBuilder does, in the world's axes and units, and writes them into
Blender's at ten times that.
"""
import math
import os
import sys
from contextlib import contextmanager

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

import bmesh
from mathutils import Matrix, Vector

reset()
KINDS = ["moonwell", "stillStone", "saltAltar", "brokenSpire", "heartstone"]

stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
# The floor's stone and its flags', mixed as the game mixed them: worn
# (pale and stone half and half), bleached (a third of the way to white)
# and weathered (a quarter of the way to stone).
floor_stone = material("plain_stone_floor", (0.6, 0.59, 0.565))
bleached = material("plain_stone_bleached", (0.736, 0.7295, 0.703))
weathered = material("plain_stone_weathered", (0.64, 0.63, 0.6025))
slate = material("plain_slate", (0.23, 0.24, 0.28))
dark_timber = material("plain_timber_dark", (0.19, 0.14, 0.11))
earth = material("plain_earth", (0.24, 0.21, 0.18))
linen = material("plain_linen", (0.7, 0.67, 0.6))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
madder = material("plain_madder", (0.44, 0.24, 0.19))
weld = material("plain_weld", (0.55, 0.49, 0.27))
sea_wool = material("plain_seawool", (0.27, 0.33, 0.38))
dark_wool = material("plain_wooldark", (0.24, 0.24, 0.25))
dark_leather = material("plain_leather_dark", (0.22, 0.16, 0.12))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.35, metallic=0.8)
bronze = material("metal_bronze", (0.55, 0.43, 0.26), roughness=0.4, metallic=0.7)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
fire = material("glow_fire", (1.0, 0.68, 0.32))
candle = material("glow_candle", (1.0, 0.8, 0.52))
moonsalt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)
salt_crust = material("crystal_saltcrust", (0.8, 0.83, 0.86), roughness=0.2)
moonglow = material("crystal_moonglow", (0.72, 0.86, 1.0), roughness=0.1)
# The still stone's black drops: slate, glinting (named so that its second
# word is not read as slate's grain).
drop = material("crystal_slatedrop", (0.23, 0.24, 0.28), roughness=0.1)
shard_stone = material("crystal_stonepale", (0.68, 0.67, 0.64), roughness=0.2)
grass_blade = material("foliage_grass", (0.37, 0.41, 0.31))
reed_blade = material("foliage_thatch_reed", (0.47, 0.45, 0.33))


# MARK: The game's chance, so its stones and ribbons fall as they did

def noise(x, y, seed):
    """Noise.unit: from 0 up to 1 for a lattice point, the same as the game's."""
    m = 0xFFFFFFFF
    h = ((x & m) * 0x8DA6B343 & m) ^ ((y & m) * 0xD8163841 & m) ^ ((seed & m) * 0xCB1AB31F & m)
    h ^= h >> 13
    h = h * 0x5BD1E995 & m
    h ^= h >> 15
    return (h >> 8) / float(1 << 24)


# MARK: Solids laid as the game's MeshBuilder lays them

UP = (0, 1, 0)


def ring(radius, y, angle):
    """MeshBuilder.ring: a point about the upright, from +x toward -z."""
    return Vector((radius * math.cos(angle), y, -radius * math.sin(angle)))


def shift(p):
    return Matrix.Translation(Vector(p))


def turn_x(angle):
    return Matrix.Rotation(angle, 4, "X")


def turn_y(angle):
    return Matrix.Rotation(angle, 4, "Y")


def turn_z(angle):
    return Matrix.Rotation(angle, 4, "Z")


def scaled(x, y, z):
    return Matrix.Diagonal((x, y, z, 1.0))


def aligning_up(direction):
    """Mat4.aligningUp: the turn that carries straight up onto `direction`."""
    d = Vector(direction).normalized()
    axis = Vector(UP).cross(d)
    cosine = max(-1.0, min(1.0, d.y))
    if axis.length < 1e-6:
        return Matrix.Identity(4) if cosine > 0 else turn_x(math.pi)
    return Matrix.Rotation(math.acos(cosine), 4, axis.normalized())


class Shape:
    """Triangles gathered in the world's axes and units as the game's
    MeshBuilder lays them: each solid placed by the placements it is built
    within, each triangle wound counter-clockwise seen from outside (put
    back so under a mirroring placement), those of no area left out; how far
    each corner moves in the wind, by its place in its solid's own frame."""

    def __init__(self):
        self.faces = []
        self.transform = Matrix.Identity(4)
        self.sway = 0.0
        self.sway_range = None
        self.sway_of = None

    @contextmanager
    def place(self, placement):
        saved = self.transform
        self.transform = saved @ placement
        try:
            yield self
        finally:
            self.transform = saved

    @contextmanager
    def swaying(self, sway=0.0, sway_range=None, sway_of=None):
        """Built moving in the wind: `sway` rising from nothing at the first
        height of `sway_range` to full at the second, squared, as the game's
        swayRange; or `sway_of` a solid's own point."""
        saved = (self.sway, self.sway_range, self.sway_of)
        self.sway, self.sway_range, self.sway_of = sway, sway_range, sway_of
        try:
            yield self
        finally:
            self.sway, self.sway_range, self.sway_of = saved

    def sway_at(self, local):
        if self.sway_of is not None:
            return self.sway_of(local)
        if self.sway_range is not None and self.sway_range[1] > self.sway_range[0]:
            low, high = self.sway_range
            t = min(max((local.y - low) / (high - low), 0.0), 1.0)
            return self.sway * t * t
        return self.sway

    def triangle(self, a, b, c, mat):
        a, b, c = Vector(a), Vector(b), Vector(c)
        m = self.transform
        if m.to_3x3().determinant() < 0:
            b, c = c, b
        pa, pb, pc = m @ a, m @ b, m @ c
        if (pb - pa).cross(pc - pa).length <= 1e-9:
            return
        self.faces.append(((pa, pb, pc), mat, (self.sway_at(a), self.sway_at(b), self.sway_at(c))))

    def quad(self, a, b, c, d, mat):
        self.triangle(a, b, c, mat)
        self.triangle(a, c, d, mat)

    def polygon(self, points, mat):
        for i in range(1, len(points) - 1):
            self.triangle(points[0], points[i], points[i + 1], mat)

    def face(self, points, outward, mat):
        """A face turned, if need be, to look along `outward`."""
        points = [Vector(p) for p in points]
        n = (points[1] - points[0]).cross(points[2] - points[0])
        self.polygon(points if n.dot(Vector(outward)) >= 0 else list(reversed(points)), mat)

    def box(self, low, high, mat):
        """A box between two corners, its faces as the game lays them."""
        (x0, y0, z0), (x1, y1, z1) = low, high
        self.quad((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), mat)
        self.quad((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), mat)
        self.quad((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0), mat)
        self.quad((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), mat)
        self.quad((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), mat)
        self.quad((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), mat)

    def box_at(self, centre, size, mat, turn=0.0):
        """A box about its centre, turned about the upright as the game's
        box(center:size:turn:)."""
        with self.place(shift(centre) @ turn_y(turn)):
            self.box(tuple(-s / 2 for s in size), tuple(s / 2 for s in size), mat)

    def lathe(self, profile, sides, mat, twist=0.0, caps=True):
        """A solid turned about the upright from its profile, bottom to top,
        its ends capped where they have a radius (none, if not `caps`)."""
        step = 2 * math.pi / sides
        for (r0, y0), (r1, y1) in zip(profile, profile[1:]):
            for side in range(sides):
                a0 = side * step + twist
                a1 = a0 + step
                self.quad(ring(r0, y0, a0), ring(r0, y0, a1), ring(r1, y1, a1), ring(r1, y1, a0), mat)
        if caps and profile[0][0] > 0:
            r, y = profile[0]
            self.polygon([ring(r, y, s * step + twist) for s in reversed(range(sides))], mat)
        if caps and profile[-1][0] > 0:
            r, y = profile[-1]
            self.polygon([ring(r, y, s * step + twist) for s in range(sides)], mat)

    def tube(self, profile, sides, mat, twist=0.0):
        """A lathe's sides without its ends."""
        self.lathe(profile, sides, mat, twist, caps=False)

    def cone(self, sides, radius, bottom, top, mat, twist=0.0):
        self.lathe([(radius, bottom), (0.0, top)], sides, mat, twist)

    def prism(self, sides, radius, bottom, top, mat, twist=0.0):
        self.lathe([(radius, bottom), (radius, top)], sides, mat, twist)

    def limb(self, a, b, radius, mat, top=None, sides=4):
        """A pole from one point to another, its ends left open."""
        a, b = Vector(a), Vector(b)
        with self.place(shift(a) @ aligning_up(b - a)):
            self.tube([(radius, 0.0), (radius if top is None else top, (b - a).length)], sides, mat)

    def sheet(self, points, normal, thickness, mat):
        """A thin flat thing seen from both sides: a pennant, a blade."""
        offset = Vector(normal).normalized() * (thickness / 2)
        self.face([Vector(p) + offset for p in points], normal, mat)
        self.face([Vector(p) - offset for p in points], -Vector(normal), mat)

    def rock(self, centre, size, rings, sides, jitter, seed, mat):
        """A rough lump, each point pushed in or out by the game's own
        chance, the same stone as the game's for the same seed."""
        grid = []
        for band in range(rings + 1):
            latitude = math.pi * band / rings - math.pi / 2
            pole = band in (0, rings)
            row = []
            for side in range(sides):
                longitude = 2 * math.pi * side / sides
                push = 1 + jitter * (2 * noise(band, 0 if pole else side, seed) - 1)
                d = (math.cos(latitude) * math.cos(longitude), math.sin(latitude), -math.cos(latitude) * math.sin(longitude))
                row.append(Vector((centre[0] + d[0] * size[0] * push, centre[1] + d[1] * size[1] * push, centre[2] + d[2] * size[2] * push)))
            grid.append(row)
        for band in range(rings):
            for side in range(sides):
                n = (side + 1) % sides
                self.quad(grid[band][side], grid[band][n], grid[band + 1][n], grid[band + 1][side], mat)

    def solid(self, corners, faces, mat):
        """A convex solid from its corners and its faces (corner numbers in
        any order round each), every face wound to look out from its middle."""
        corners = [Vector(c) for c in corners]
        middle = sum(corners, Vector()) / len(corners)
        for face in faces:
            points = [corners[i] for i in face]
            centre = sum(points, Vector()) / len(points)
            self.face(points, centre - middle, mat)


def rock_poles(size, rings, jitter, seed):
    """How far below and above its centre a rock (as Shape.rock) reaches."""
    return (size[1] * (1 + jitter * (2 * noise(0, 0, seed) - 1)), size[1] * (1 + jitter * (2 * noise(rings, 0, seed) - 1)))


def make(name, shape):
    """The shape's triangles as one object, their corners shared where they
    meet, each in its own material; and how far each corner moves in the
    wind, if any does."""
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    bm = bmesh.new()
    corners, sways, mats = {}, [], []
    for points, mat, moves in shape.faces:
        verts = []
        for p, s in zip(points, moves):
            q = at(p.x, p.y, p.z)
            key = (round(q.x, 6), round(q.y, 6), round(q.z, 6))
            if key not in corners:
                corners[key] = bm.verts.new(key)
                sways.append(s)
            verts.append(corners[key])
        if len(set(verts)) < 3:
            continue
        if mat not in mats:
            mats.append(mat)
        made = bm.faces.new(verts)
        made.material_index = mats.index(mat)
        made.smooth = False
    bm.to_mesh(mesh)
    bm.free()
    for mat in mats:
        mesh.materials.append(mat)
    if any(s > 0 for s in sways):
        attr = mesh.attributes.new("_SWAY", "FLOAT", "POINT")
        for index, s in enumerate(sways):
            attr.data[index].value = max(0.0, min(1.0, s))
    return obj


# MARK: Where everything stands

GAP = 2.5 / 7 * 2 * math.pi + 0.3  # the way in, between the third stone and the fourth
BRAZIERS = {"L": ring(0.43, 0, GAP - 0.25), "R": ring(0.43, 0, GAP + 0.25)}
INNER = {"moonwell": 0.135, "stillStone": 0.19, "saltAltar": 0.13, "brokenSpire": 0.135, "heartstone": 0.175}
# The broken spire leans as it was snapped, toward -x and -z; the shards of
# its crown turn over what is left of its top (the game turned them about a
# point 0.09 to the east, where its top would be had it leant the other way).
LEAN = turn_z(0.12) @ turn_x(-0.06)
SPIRE_TOP = LEAN @ Vector((0, 0.72, 0))
# Each heart's motes: where they turn, how far out, how many, of what.
MOTES = {"moonwell": ((0.0, 0.14, 0.0), 0.08, 5, moonglow), "stillStone": ((0.0, 0.2, 0.0), 0.17, 7, drop),
         "saltAltar": ((0.0, 0.3, 0.0), 0.06, 6, moonsalt), "brokenSpire": ((SPIRE_TOP.x, 0.78, SPIRE_TOP.z), 0.1, 4, shard_stone),
         "heartstone": ((0.0, 0.6, 0.0), 0.12, 8, moonglow)}
LAMPS = [index / 9 * 2 * math.pi + 0.17 for index in (1, 4, 7)]
CANDLES = {"L": -0.19, "R": 0.19}
QUARTERS = {"E": 0.0, "N": math.pi / 2, "W": math.pi, "S": 3 * math.pi / 2}


def floor_at(radius):
    """The floor's top: it falls from 0.02 at its heart to 0.012 at its edge."""
    return 0.02 - 0.008 * radius / 0.3


def stone_angle(index):
    return index / 7 * 2 * math.pi + 0.3


def stone_place(index):
    """Where a stone of the ring stands, leaning a little in and out by turns."""
    angle = stone_angle(index)
    return shift(ring(0.36, 0, angle)) @ turn_y(angle) @ turn_z(0.05 if index % 2 == 0 else -0.04)


def lamp_foot(angle):
    return ring(0.12, 0.087, angle)


def candle_foot(x):
    return Vector((x, floor_at(0.19), 0.03))


def quarter_foot(angle):
    return ring(0.235, floor_at(0.235), angle)


# The fires, each its own part to leap, a little out of step with the others.
FIRES = [("beacon fire %s" % side, foot + Vector((0, 0.115, 0)), phase) for (side, foot), phase in zip(BRAZIERS.items(), (0.0, 0.37))]
FIRES += [("lamp fire %d@moonwell" % (n + 1), lamp_foot(angle) + Vector((0, 0.01, 0)), phase)
          for n, (angle, phase) in enumerate(zip(LAMPS, (0.13, 0.52, 0.79)))]
FIRES += [("candle fire %s@saltAltar" % side, candle_foot(x) + Vector((0, 0.262, 0)), phase)
          for (side, x), phase in zip(CANDLES.items(), (0.21, 0.64))]
FIRES += [("quarter fire %s@heartstone" % q, quarter_foot(angle) + Vector((0, 0.14, 0)), phase)
          for (q, angle), phase in zip(QUARTERS.items(), (0.08, 0.33, 0.58, 0.83))]

rig = work_rig([("holy motes@%s" % kind, MOTES[kind][0], UP) for kind in KINDS] + [(bone, tuple(pivot), UP) for bone, pivot, _ in FIRES])


def moving(name, bone, shape):
    """A moving part's solids hung on its bone."""
    return on(make(name, shape), rig, bone)


# MARK: What every holy site has

# A worn floor of flags within the ring: the ground the rest stands on.
floor = Shape()
floor.lathe([(0.3, -0.03), (0.3, 0.012), (0.0, 0.02)], 9, floor_stone)
ground(make("floor", floor), rig)


def lintel(shape, index, mat):
    """A lintel from one stone's head to the next's, as broad and deep as
    the game's beam; its ends cut along the stones' radii, so two meeting on
    a stone meet in a mitre, their tops never one in another."""
    a0, a1 = stone_angle(index), stone_angle(index + 1)
    p0, p1 = ring(0.36, 0, a0), ring(0.36, 0, a1)
    along, out = p1 - p0, ring(1, 0, (a0 + a1) / 2)
    corners = []
    for angle in (a0, a1):
        cut = Vector((math.sin(angle), 0, math.cos(angle)))
        for s in (-0.0225, 0.0225):
            base = p0 + out * s
            p = base + along * (-base.dot(cut) / along.dot(cut))
            corners += [(p.x, y, p.z) for y in (0.265, 0.305)]
    shape.solid(corners, [(0, 2, 6, 4), (1, 3, 7, 5), (0, 1, 5, 4), (2, 3, 7, 6), (0, 1, 3, 2), (4, 5, 7, 6)], mat)


stones = Shape()
for index in range(7):
    with stones.place(stone_place(index)):
        stones.lathe([(0.05, -0.06), (0.05, 0.17), (0.035, 0.27), (0.0, 0.29)], 6, stone if index % 3 == 0 else dark_stone, twist=0.3)
# Lintels across the stones pair by pair, but over the way in.
for index in range(6):
    if index != 2:
        lintel(stones, index, stone if index % 2 == 0 else dark_stone)
make("standing stones", stones)

# The way in: two lines of lesser stones outside the ring's gap, and a
# brazier of bronze at either side of it (metal, where the game's were plain).
way = Shape()
for step in (1, 2, 3):
    for side in (-1, 1):
        with way.place(shift(ring(0.36 + step * 0.07, 0, GAP + side * 0.12))):
            way.lathe([(0.025, -0.02), (0.022, 0.07 - step * 0.01), (0.0, 0.085 - step * 0.01)], 5, dark_stone, twist=0.4)
for foot in BRAZIERS.values():
    with way.place(shift(foot)):
        way.lathe([(0.025, 0.0), (0.014, 0.08), (0.03, 0.1), (0.034, 0.115)], 7, bronze)
make("way in", way)


def flame(shape, foot, size):
    """A fire as the game's beacon burns: a body of flame and four tongues
    licking up about it."""
    with shape.place(shift(foot)):
        shape.lathe([(size * 0.9, 0.0), (size, size * 0.3), (size * 0.6, size * 0.9), (size * 0.25, size * 1.5), (0.0, size * 2.1)], 7, fire)
    for index in range(4):
        angle = index * 1.6
        with shape.place(shift(foot + Vector((size * 0.55 * math.cos(angle), 0, size * 0.55 * math.sin(angle))))):
            shape.cone(4, size * 0.35, 0.0, size * 1.3, candle)


for (side, foot), (bone, _, _) in zip(BRAZIERS.items(), FIRES):
    burning = Shape()
    flame(burning, foot + Vector((0, 0.115, 0)), 0.03)
    moving("brazier fire " + side, bone, burning)

# The pole, and its pennant in the holder's colour: held at the pole, free
# at its end.
pole = Shape()
pole.box_at((0.2, 0.22, -0.2), (0.012, 0.44, 0.012), dark_timber)
make("pole", pole)
pennant = Shape()
with pennant.swaying(sway_of=lambda p: 0.6 * min(max((p.x - 0.206) / 0.134, 0.0), 1.0)):
    pennant.sheet([(0.206, 0.43, -0.2), (0.206, 0.35, -0.2), (0.34, 0.39, -0.2), (0.34, 0.43, -0.2)], (0, 0, 1), 0.003, banner)
make("pennant", pennant)

# Close: the pole's socket of stone, and grass at every other stone's foot.
socket = Shape()
with socket.place(shift((0.2, floor_at(0.283), -0.2))):
    socket.lathe([(0.024, -0.004), (0.024, 0.022), (0.014, 0.03)], 6, dark_stone)
make("pole socket!fine", socket)


def grass(shape, foot, tufts, spread, seed):
    """Tufts of grey grass, each a few blades leaning out from its root
    (Land.grass)."""
    with shape.swaying(0.8, (0.0, 0.1)):
        for index in range(tufts):
            u, v = noise(index, 5, seed), noise(index, 6, seed)
            root = Vector(foot) + Vector(((u - 0.5) * 2 * spread, -0.015, (v - 0.5) * 2 * spread))
            for blade in range(4):
                angle = blade * 1.7 + u * 6
                tip = root + ring(0.035, 0.07 + 0.04 * noise(index, blade, seed), angle)
                with shape.place(shift(root) @ aligning_up(tip - root)):
                    shape.cone(3, 0.011, 0.0, (tip - root).length, grass_blade if blade % 2 == 0 else reed_blade, twist=angle)


tufts = Shape()
for index in range(0, 7, 2):
    grass(tufts, ring(0.42, 0.012, stone_angle(index) + 0.12), 2, 0.025, index + 7)
make("stone grass!fine", tufts)


def flags(inner):
    """The floor's flags in two courses about the heart, worn, each a
    little proud of the floor and sunk into it at its foot; any worn least
    was lifted long ago and is left out (by the game's chance, none is)."""
    shape = Shape()
    middle = (inner + 0.292) / 2
    for course, (low, high, count) in enumerate(((inner, middle - 0.004, 9), (middle + 0.004, 0.292, 13))):
        step = 2 * math.pi / count
        for index in range(count):
            a0 = index * step + course * 0.31 + 0.1
            a1 = a0 + step - 0.035
            wear = noise(index, course + 60, 19)
            if wear < 0.1:
                continue
            lift = 0.003 + 0.002 * wear
            top0, top1 = floor_at(low) + lift, floor_at(high) + lift
            foot0, foot1 = floor_at(low) - 0.002, floor_at(high) - 0.002
            mat = pale_stone if wear < 0.4 else bleached if wear < 0.75 else weathered
            shape.quad(ring(low, top0, a0), ring(high, top1, a0), ring(high, top1, a1), ring(low, top0, a1), mat)
            shape.quad(ring(high, foot1, a0), ring(high, foot1, a1), ring(high, top1, a1), ring(high, top1, a0), mat)
            shape.quad(ring(low, foot0, a1), ring(low, foot0, a0), ring(low, top0, a0), ring(low, top0, a1), mat)
            shape.quad(ring(low, foot0, a0), ring(high, foot1, a0), ring(high, top1, a0), ring(low, top0, a0), mat)
            shape.quad(ring(high, foot1, a1), ring(low, foot0, a1), ring(low, top0, a1), ring(high, top1, a1), mat)
    return shape


for inner in sorted(set(INNER.values())):
    make(tagged("flags", [kind for kind in KINDS if INNER[kind] == inner]) + "!fine", flags(inner))

# Each heart's motes held in the air in a ring about it, turning as one.
for kind in KINDS:
    centre, radius, count, mat = MOTES[kind]
    motes = Shape()
    for index in range(count):
        with motes.place(shift(Vector(centre) + ring(radius, 0.02 * (index % 2), index / count * 2 * math.pi))):
            motes.lathe([(0.0, -0.014), (0.01, 0.0), (0.0, 0.016)], 5, mat)
    moving(tagged("motes", [kind]), "holy motes@" + kind, motes)

# MARK: The moonwell

tag = ["moonwell"]
well = Shape()
well.lathe([(0.13, 0.0), (0.13, 0.07), (0.11, 0.075), (0.11, 0.03), (0.0, 0.03)], 9, stone)
well.lathe([(0.105, 0.05), (0.0, 0.052)], 9, moonglow)
make(tagged("well", tag), well)

# Close: its coping, a lamp burning on every third stone; an arch over it
# crowned with the crescent, a silver bowl hung from it on a chain to draw the
# moon's water; stones to kneel on before it. (The coping is bedded down on
# the kerb's outer edge, where the game's stood clear of its sloping top; the
# arch's posts run up into its lintel, not to its underside.)
close = Shape()
for index in range(9):
    angle = index / 9 * 2 * math.pi + 0.17
    with close.place(shift(ring(0.12, 0.0785, angle)) @ turn_y(angle)):
        close.box((-0.014, -0.0085, -0.038), (0.014, 0.0085, 0.038), pale_stone if index % 2 == 0 else stone)
for angle in LAMPS:
    with close.place(shift(lamp_foot(angle))):
        close.lathe([(0.0, 0.0), (0.011, 0.003), (0.013, 0.012)], 5, earth)
for x in (-0.165, 0.165):
    close.box((x - 0.016, 0.0, -0.018), (x + 0.016, 0.31, 0.018), pale_stone)
close.box((-0.195, 0.3, -0.024), (0.195, 0.334, 0.024), stone)
for index in range(6):
    t = (index + 0.5) / 6
    angle = math.pi * (1.1 + 0.8 * t)
    with close.place(shift(Vector((math.cos(angle), math.sin(angle), 0)) * 0.05 + Vector((0, 0.39, 0))) @ turn_z(angle)):
        close.box_at((0, 0, 0), (0.008 + 0.008 * math.sin(t * math.pi), 0.03, 0.012), moonglow)
close.limb((0, 0.3, 0), (0, 0.183, 0), 0.0025, iron)
# The bowl, its lip turned in to the water it holds.
close.tube([(0.0, 0.16), (0.022, 0.165), (0.03, 0.185), (0.027, 0.185), (0.027, 0.18)], 7, steel)
close.tube([(0.027, 0.18), (0.0, 0.181)], 7, moonglow)
for index, angle in enumerate((4.25, 4.71, 5.17)):
    close.rock(ring(0.205, floor_at(0.205) + 0.006, angle), (0.034, 0.012, 0.026), 2, 6, 0.12, index + 130, stone)
make(tagged("well close", tag) + "!fine", close)
for n, angle in enumerate(LAMPS):
    lamp = Shape()
    with lamp.place(shift(lamp_foot(angle))):
        lamp.cone(4, 0.005, 0.01, 0.028, candle)
    moving(tagged("lamp flame %d" % (n + 1), tag) + "!fine", "lamp fire %d@moonwell" % (n + 1), lamp)

# MARK: The still stone

tag = ["stillStone"]
still = Shape()
with still.place(turn_y(0.4)):
    still.lathe([(0.11, 0.0), (0.12, 0.12), (0.08, 0.3), (0.0, 0.33)], 5, slate, twist=0.1)
make(tagged("still stone", tag), still)

# Close: pilgrims' ribbons tied about the ring's stones, stirring in the
# wind about the stone that never stirs, knotted at each cord's corner most
# downwind; a kerb about it, and cairns of flat stones its pilgrims have left.
WIND = Vector((0.94, 0, 0.34)).normalized()
ACROSS = WIND.cross(Vector(UP)).normalized()
RIBBONS = [madder, weld, sea_wool, linen]
close = Shape()
for index in range(7):
    angle = stone_angle(index)
    # The cord bound round the stone's six faces, a little proud of them (the
    # game's was square, and lay mostly within the stone).
    with close.place(stone_place(index)):
        close.tube([(0.054, 0.15), (0.054, 0.168)], 6, dark_leather, twist=0.3)
    corner = max(range(6), key=lambda k: ring(1, 0, angle + 0.3 + k * math.pi / 3).dot(WIND))
    knot = stone_place(index) @ ring(0.054, 0.159, 0.3 + corner * math.pi / 3)
    for strand in range(2):
        long = 0.08 + 0.03 * strand + 0.02 * noise(index, strand, 77)
        # Built measuring down from the knot, so the wind stirs its tail and
        # never the knot; not cloth, which would take the holder's colour.
        with close.place(shift(knot + ACROSS * (0.007 * (strand * 2 - 1))) @ scaled(1, -1, 1)):
            with close.swaying(0.9, (0.0, long)):
                across = WIND * 0.016
                tail = WIND * (0.03 + 0.03 * strand) + ACROSS * (0.012 * (strand * 2 - 1)) + Vector((0, long, 0))
                close.sheet([Vector(), across, tail + across, tail], ACROSS, 0.002, RIBBONS[(index + strand * 2) % 4])
for index in range(10):
    angle = index / 10 * 2 * math.pi + 0.2
    close.rock(ring(0.162, floor_at(0.162) + 0.004, angle), (0.026, 0.014, 0.022), 2, 4, 0.2, index + 170,
               dark_stone if index % 2 == 0 else stone)
# Each cairn's stones laid one on another, each sat a little into the one below.
for index, angle in enumerate((0.2, 2.2, 3.7, 5.2)):
    foot = ring(0.225, floor_at(0.225), angle)
    y = foot.y + 0.008
    for layer, size in enumerate((0.028, 0.022, 0.016)):
        extent = (size, size * 0.4, size * 0.85)
        seed = index * 3 + layer + 150
        below, above = rock_poles(extent, 2, 0.15, seed)
        if layer > 0:
            y = top + below - 0.002
        close.rock((foot.x + 0.004 * layer, y, foot.z), extent, 2, 5, 0.15, seed, slate if layer % 2 == 0 else stone)
        top = y + above
make(tagged("still stone close", tag) + "!fine", close)

# MARK: The salt altar

tag = ["saltAltar"]
altar = Shape()
altar.box_at((0, 0.05, 0), (0.2, 0.1, 0.13), pale_stone)
for x, z, h in ((-0.05, 0.0, 0.09), (0.02, 0.02, 0.13), (0.06, -0.02, 0.07)):
    with altar.place(shift((x, 0, z))):
        altar.cone(5, 0.025, 0.1, 0.1 + h, moonsalt)
make(tagged("altar", tag), altar)


def crystals(shape, foot, count, height, seed):
    """Moonsalt grown in clustered six-sided spars (Land.crystals), each one
    solid from its foot to its point."""
    for index in range(count):
        u, v = noise(index, 7, seed), noise(index, 8, seed)
        base = Vector(foot) + Vector(((u - 0.5) * 0.12, -0.02, (v - 0.5) * 0.12))
        lean = Vector(((u - 0.5) * 0.8, 1, (v - 0.5) * 0.8))
        tall = height * (0.45 + 0.7 * noise(index, 9, seed))
        radius = 0.018 + 0.012 * u
        with shape.place(shift(base) @ aligning_up(lean)):
            shape.lathe([(radius, 0.0), (radius, tall * 0.75), (0.0, tall)], 6, moonsalt)


# Close: the altar on a step, its top slab overhanging, a crescent cut in a
# panel on its face; bowls of salt and a salt-knife on it, candles either
# side, sacks of moonsalt brought to it, and moonsalt grown up from the
# floor behind it.
# (The kneeler and the panel are set a little into the step and the altar's
# face, where the game's lay in their planes.)
close = Shape()
close.box_at((0, 0.0175, 0.01), (0.3, 0.035, 0.22), stone)
close.box((-0.1, 0.0, 0.115), (0.1, 0.024, 0.15), stone)
close.box_at((0, 0.106, 0), (0.23, 0.014, 0.155), bleached)
close.box((-0.075, 0.034, 0.063), (0.075, 0.085, 0.069), stone)
for index in range(4):
    t = (index + 0.5) / 4
    angle = math.pi * (1.15 + 0.7 * t)
    with close.place(shift(Vector((math.cos(angle), math.sin(angle), 0)) * 0.016 + Vector((0, 0.07, 0.07))) @ turn_z(angle)):
        close.box_at((0, 0, 0), (0.005, 0.012, 0.003), moonglow)
for x in (-0.08, 0.08):
    with close.place(shift((x, 0.113, 0.045))):
        close.lathe([(0.0, 0.0), (0.016, 0.004), (0.022, 0.016)], 7, bronze)
        close.cone(6, 0.019, 0.012, 0.03, salt_crust)
close.sheet([(-0.005, 0.1135, 0.058), (0.04, 0.1135, 0.06), (0.04, 0.1135, 0.064), (-0.005, 0.1135, 0.067)], UP, 0.002, steel)
close.limb((-0.006, 0.117, 0.0625), (-0.035, 0.117, 0.0625), 0.004, dark_timber)
for x in CANDLES.values():
    foot = candle_foot(x)
    close.limb(foot, foot + Vector((0, 0.22, 0)), 0.005, iron)
    for leg in range(3):
        angle = leg * 2 * math.pi / 3 + 0.4
        close.limb(foot + Vector((0, 0.05, 0)), foot + ring(0.032, 0, angle), 0.003, iron, sides=3)
    with close.place(shift(foot + Vector((0, 0.215, 0)))):
        close.lathe([(0.0, 0.0), (0.02, 0.005), (0.022, 0.012)], 6, iron)
    with close.place(shift(foot + Vector((0, 0.222, 0)))):
        close.prism(5, 0.008, 0.0, 0.04, linen)
for at_point, size in (((-0.17, 0.012, 0.135), 1.0), ((-0.13, 0.012, 0.185), 0.85)):
    with close.place(shift(at_point) @ scaled(size, size, size)):
        close.lathe([(0.0, 0.0), (0.022, 0.004), (0.027, 0.02), (0.021, 0.036), (0.008, 0.044), (0.011, 0.05), (0.0, 0.052)], 6, canvas)
with close.place(shift((-0.095, 0.012, 0.19))):
    close.cone(6, 0.026, 0.0, 0.022, salt_crust)
# Six spars where the game grew four, its first four as they were.
crystals(close, (0.02, 0.015, -0.19), 6, 0.07, 143)
make(tagged("altar close", tag) + "!fine", close)
for side, x in CANDLES.items():
    flicker = Shape()
    with flicker.place(shift(candle_foot(x) + Vector((0, 0.222, 0)))):
        flicker.cone(4, 0.006, 0.04, 0.063, candle)
    moving(tagged("candle flame " + side, tag) + "!fine", "candle fire %s@saltAltar" % side, flicker)

# MARK: The broken spire

tag = ["brokenSpire"]
spire = Shape()
with spire.place(LEAN):
    spire.lathe([(0.12, 0.0), (0.11, 0.18), (0.095, 0.42), (0.08, 0.62), (0.07, 0.7), (0.0, 0.72)], 7, pale_stone, twist=0.15)
for x, z, turn in ((0.2, 0.08, 0.5), (-0.17, 0.15, 1.2), (0.06, -0.21, 2.1)):
    spire.box_at((x, 0.035, z), (0.12, 0.07, 0.08), stone, turn=turn)
for x, z, h in ((0.1, -0.06, 0.06), (-0.08, -0.1, 0.05)):
    with spire.place(shift((x, 0, z))):
        spire.cone(5, 0.02, 0.0, h, moonsalt)
make(tagged("spire", tag), spire)

# Close: carved bands about the shaft, moonsalt glinting in its seams; its
# head, snapped off and fallen out through the way in between two stones of
# the ring, the moonsalt it was crowned with still on it; rubble.
close = Shape()
with close.place(LEAN):
    for y, radius in ((0.2, 0.109), (0.44, 0.0935)):
        close.tube([(radius, y - 0.012), (radius + 0.008, y - 0.006), (radius + 0.008, y + 0.006), (radius, y + 0.012)], 7, stone, twist=0.15)
    for y, radius, turn in ((0.3, 0.097, 0.6), (0.53, 0.0824, 2.4), (0.12, 0.1076, 4.4)):
        with close.place(shift((0, y, 0)) @ turn_y(turn)):
            close.box_at((radius, 0, 0), (0.016, 0.05, 0.022), moonglow)
FALL = 2.544
with close.place(shift(ring(0.17, 0.06, FALL)) @ aligning_up(ring(1, -0.06, FALL))):
    close.lathe([(0.068, 0.0), (0.064, 0.1), (0.055, 0.2), (0.04, 0.28), (0.0, 0.31)], 7, pale_stone, twist=0.4)
    close.cone(6, 0.022, 0.27, 0.36, moonsalt)
for index, at_point in enumerate(((0.25, 0.012, -0.05), (-0.05, 0.012, 0.22), (0.16, 0.012, 0.18), (-0.26, 0.012, -0.02), (0.02, 0.012, 0.25))):
    size = 0.018 + 0.01 * noise(index, 5, 88)
    close.rock(at_point, (size * 1.2, size * 0.8, size), 2, 5, 0.2, index + 180, pale_stone if index % 2 == 0 else stone)
make(tagged("spire close", tag) + "!fine", close)

# MARK: The heartstone

tag = ["heartstone"]
heart = Shape()
heart.lathe([(0.17, 0.0), (0.17, 0.04), (0.13, 0.045), (0.13, 0.08), (0.0, 0.085)], 8, dark_stone)
with heart.place(shift((0, 0.08, 0)) @ turn_y(0.3)):
    heart.lathe([(0.075, 0.0), (0.085, 0.2), (0.065, 0.48), (0.03, 0.6), (0.0, 0.62)], 5, slate, twist=0.2)
# Each vein of moonsalt set in the middle of a face, a little proud of it.
for y, radius, turn in ((0.18, 0.071, 6.155), (0.32, 0.0648, 2.385), (0.46, 0.0567, 3.641)):
    with heart.place(shift((0, 0.08 + y, 0)) @ turn_y(turn)):
        heart.box_at((radius, 0, 0), (0.012, 0.07, 0.03), moonglow)
make(tagged("menhir", tag), heart)

# Close: braziers at its four quarters; swords offered point down in the
# ground about its plinth, and shields of fallen Houses laid against it,
# each leaning on the edge of its lower step; runes cut in the plinth, glowing.
close = Shape()
for angle in QUARTERS.values():
    foot = quarter_foot(angle)
    for leg in range(3):
        out = ring(0.03, 0, angle + leg * 2 * math.pi / 3 + 0.5)
        close.limb(foot + out, foot + Vector((0, 0.125, 0)) + out * 0.4, 0.004, iron, sides=3)
    with close.place(shift(foot + Vector((0, 0.12, 0)))):
        close.lathe([(0.0, 0.0), (0.03, 0.012), (0.036, 0.03)], 6, iron)
for index in range(8):
    angle = index * math.pi / 4 + math.pi / 8
    tilt = 0.14 * (noise(index, 3, 91) - 0.5)
    with close.place(shift(ring(0.205, floor_at(0.205), angle)) @ turn_y(angle) @ turn_z(tilt)):
        close.sheet([(0, 0, -0.002), (0, 0, 0.002), (0, 0.09, 0.007), (0, 0.09, -0.007)], (1, 0, 0), 0.002, steel)
        close.box_at((0, 0.093, 0), (0.008, 0.007, 0.04), iron)
        close.box_at((0, 0.134, 0), (0.01, 0.01, 0.01), bronze)
        close.limb((0, 0.096, 0), (0, 0.13, 0), 0.004, dark_leather)
# (The game set them 0.19 out, where they leant on nothing: each is drawn in
# till its back meets the step's edge at the plinth's corner it faces.)
for share, colour in zip((0.75, 1.25, 1.75, 0.25), (madder, sea_wool, weld, dark_wool)):
    angle = share * math.pi
    with close.place(shift(ring(0.177, 0.038, angle)) @ turn_y(angle) @ turn_z(-1.05)):
        close.lathe([(0.04, -0.005), (0.04, 0.003), (0.0, 0.007)], 8, colour)
        close.cone(5, 0.01, 0.006, 0.016, iron)
for index in range(8):
    angle = (index + 0.5) * math.pi / 4
    with close.place(shift(ring(0.1212, 0.0625, angle)) @ turn_y(angle)):
        close.box_at((0, 0, 0), (0.003, 0.02, 0.005), moonglow)
        close.box_at((0, 0.004 if index % 2 == 0 else -0.003, 0.005), (0.003, 0.004, 0.008), moonglow)
make(tagged("menhir close", tag) + "!fine", close)
for (q, angle), (bone, _, _) in zip(QUARTERS.items(), FIRES[-4:]):
    burning = Shape()
    with burning.place(shift(quarter_foot(angle) + Vector((0, 0.12, 0)))):
        burning.lathe([(0.03, 0.02), (0.033, 0.04), (0.0, 0.09)], 5, fire)
    moving(tagged("quarter flame " + q, tag) + "!fine", bone, burning)

# Every heart's motes turning as a wheel, once round in the idle; every fire
# leaping, each in its own time.
idle(rig, turns=[("holy motes@" + kind, UP, wheel_turns(1)) for kind in KINDS],
     stretches=[(bone, lambda u, phase=phase: leaping((u + phase) % 1.0)) for bone, _, phase in FIRES])

finish_building(out_path("Art/models/shrines.glb"), KINDS)
