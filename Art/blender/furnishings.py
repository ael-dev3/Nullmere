"""The land's furnishings, each a variant of one file by its name, scattered
over the land by the thousand (Scatter stands each on the ground at its
foot, sunk a hundredth into it, turned and scaled):
- fir: a dark fir in three tiers on a short trunk, every other bough's tip
  drooping below its tier's rim;
- elderTree: an elder grove's vast old tree, a gnarled trunk on spread
  roots, three boughs up into a broad crown of heavy masses;
- deadTree: a dead tree bleached pale, its four branches bare, a twig
  forking from each;
- crag: the Spine's broken rock, a tall jagged shard, a lesser beside it,
  a stone behind and a splinter split from it standing against its flank;
- boulder: a rough grey lump;
- reeds: thin blades rising from one root;
- saltCrystals: moonsalt grown in clustered six-sided spars;
- barrowMound: a grassed burial mound, a doorway of three stones in its
  front and a kerb of stones about its foot;
- standingStone: a tall stone set upright long ago, leaning a little;
- ruin: a half-sunken ruin, its broken walls, a stump of a column, a drum
  of it fallen, turf and the walls' stones tumbled;
- grass: tufts of grey grass, each of six blades leaning out from its root;
- driftwood: a pale log thrown up on the strand, its broken branches up;
- furrows: furrows of dark loam ploughed in ridges;
- stoneFace: a seam's face cut flat, the blocks taken from it lying by;
- heather: low clumps of dark mauve, each with four sprigs in bloom;
- fern: fronds arching out from one crown and down again;
- pebbles: small, smooth, of the lake's two stones;
- birch: a slim pale trunk banded dark, two thin boughs and a light crown;
- steppingStones: broad flat stones laid a stride apart across a shoal.
They stand still: only their leaves, blades, boughs and fronds move, in the
wind, by their height above the ground (a blade by its length from its
root, a frond by its reach from its crown), their roots still.

Built as the game built them in code (Land.furnishing), triangle by
triangle: each solid made in the world's axes and units and placed as the
game placed it, each triangle flat, the game's noise shaping and laying out
what it shaped and laid out. They are drawn by the thousand, so each keeps
to about the game's count of triangles, what is hidden underground or
within another spent where it shows, and to the game's reach across the
ground (Scatter.footprint, which spaces them).

    python Art/blender/furnishings.py Art/models/furnishings.glb
"""
import math
import os
import sys
from contextlib import contextmanager

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *

reset()
FURNISHINGS = ["fir", "elderTree", "deadTree", "crag", "boulder", "reeds", "saltCrystals", "barrowMound", "standingStone", "ruin",
               "grass", "driftwood", "furrows", "stoneFace", "heather", "fern", "pebbles", "birch", "steppingStones"]

# MARK: Materials, each one of the palette's colours or a mix of two

bark = material("plain_timber_bark", (0.21, 0.17, 0.14))
birch_bark = material("plain_timber_birchbark", (0.8, 0.79, 0.74))
dead_wood = material("plain_timber_deadwood", (0.7, 0.67, 0.61))
soot = material("plain_soot", (0.11, 0.1, 0.1))
rock_grey = material("plain_stone_rock", (0.4, 0.4, 0.42))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
earth = material("plain_earth", (0.24, 0.21, 0.18))
loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
# The barrow's turf: the palette's grass three tenths of the way to earth;
# the ruin's, four tenths.
barrow_turf = material("plain_barrowturf", (0.331, 0.35, 0.271))
ruin_turf = material("plain_ruinturf", (0.318, 0.33, 0.258))
salt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)
leaf = material("foliage_ivy", (0.16, 0.24, 0.17))
fir_green = material("foliage_fir", (0.11, 0.19, 0.15))
fir_dark = material("foliage_firdark", (0.08, 0.14, 0.12))
birch_leaf = material("foliage_birchleaf", (0.4, 0.44, 0.27))
fern_green = material("foliage_fern", (0.18, 0.28, 0.19))
heather_mauve = material("foliage_heather", (0.3, 0.24, 0.29))
heather_dark = material("foliage_heatherdark", (0.21, 0.18, 0.21))
heather_bloom = material("foliage_heatherbloom", (0.46, 0.34, 0.44))
# Reed-coloured blades, grained as the game grains the reed's colour.
reed_blade = material("foliage_thatch_reed", (0.47, 0.45, 0.33))
grass_blade = material("foliage_grass", (0.37, 0.41, 0.31))


# MARK: The game's noise, so each kind keeps its shape

M32 = 0xFFFFFFFF


def unit(x, y, seed=0):
    """Noise.unit: a value from 0 up to 1 for a lattice point and a seed."""
    h = (((x & M32) * 0x8DA6B343) & M32) ^ (((y & M32) * 0xD8163841) & M32) ^ (((seed & M32) * 0xCB1AB31F) & M32)
    h ^= h >> 13
    h = (h * 0x5BD1E995) & M32
    h ^= h >> 15
    return (h >> 8) / float(1 << 24)


# MARK: Placements in the world's axes, as the game's Mat4 makes them

def V(x, y=None, z=None):
    return Vector(x) if y is None else Vector((x, y, z))


def T(x, y=None, z=None):
    return Matrix.Translation(V(x, y, z))


def RX(angle):
    return Matrix.Rotation(angle, 4, "X")


def RY(angle):
    """A turn about the upright: +z toward +x, as the game's rotationY."""
    return Matrix.Rotation(angle, 4, "Y")


def RZ(angle):
    return Matrix.Rotation(angle, 4, "Z")


def aligning_up(direction):
    """Mat4.aligningUp: the turn that carries straight up onto `direction`."""
    d = V(direction).normalized()
    axis = V(0, 1, 0).cross(d)
    cosine = max(-1.0, min(1.0, d.y))
    if axis.length < 1e-6:
        return Matrix.Identity(4) if cosine > 0 else RX(math.pi)
    return Matrix.Rotation(math.acos(cosine), 4, axis.normalized())


def ring(radius, y, angle):
    """MeshBuilder.ring: angle nought due east, rising toward -z."""
    return V(radius * math.cos(angle), y, -radius * math.sin(angle))


def mix(a, b, t):
    return V(a) + (V(b) - V(a)) * t


def clamp01(t):
    return max(0.0, min(1.0, t))


# MARK: How far a corner moves in the wind

def rising(amount, low, high):
    """As the game's swayRange gives it: nothing at height `low` to
    `amount` at `high`, as the square of the share between."""
    return lambda p: amount * clamp01((p.y - low) / (high - low)) ** 2


def along(amount, foot, tip, reach):
    """Along a blade from its foot: nothing there to `amount` at `reach`
    along it, as the game took a blade's sway in its own frame."""
    n = (V(tip) - V(foot)).normalized()
    return lambda p, f=V(foot), n=n: amount * clamp01((p - f).dot(n) / reach) ** 2


def outward(amount, crown, reach):
    """By the reach from a crown: nothing at it to `amount` at `reach`."""
    return lambda p, c=V(crown): amount * clamp01((p - c).length / reach) ** 2


# MARK: A piece built as the game's MeshBuilder builds, triangle by triangle

class Piece:
    """One object of the file, its triangles laid down as the game lays
    them (MeshBuilder, Shapes), each solid placed by the matrices about it,
    each corner swaying as `sway` gives it at its point."""

    def __init__(self, name, variant):
        self.name = tagged(name, [variant])
        self.transform = Matrix.Identity(4)
        self.sway = None
        self.corners = []

    @contextmanager
    def placed(self, placement):
        saved = self.transform
        self.transform = saved @ placement
        try:
            yield self
        finally:
            self.transform = saved

    @contextmanager
    def swaying(self, sway):
        saved = self.sway
        self.sway = sway
        try:
            yield self
        finally:
            self.sway = saved

    # Faces

    def triangle(self, a, b, c, mat):
        m = self.transform
        if m.to_3x3().determinant() < 0:
            b, c = c, b
        pa, pb, pc = m @ V(a), m @ V(b), m @ V(c)
        # The game drops what has no area: a cone's point, a ball's pole.
        if (pb - pa).cross(pc - pa).length <= 1e-9:
            return
        for p in (pa, pb, pc):
            self.corners.append((p, mat, self.sway(p) if self.sway else 0.0))

    def quad(self, a, b, c, d, mat):
        self.triangle(a, b, c, mat)
        self.triangle(a, c, d, mat)

    def polygon(self, points, mat):
        for i in range(1, len(points) - 1):
            self.triangle(points[0], points[i], points[i + 1], mat)

    # Solids

    def box(self, low, high, mat, bottom=True, back=True):
        """MeshBuilder.box(min:max:); without its bottom (its -y face) or its
        back (its -z face) where those lie underground or within another."""
        x0, y0, z0 = low
        x1, y1, z1 = high
        self.quad((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), mat)
        self.quad((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), mat)
        self.quad((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0), mat)
        if bottom:
            self.quad((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), mat)
        self.quad((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), mat)
        if back:
            self.quad((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), mat)

    def cube(self, centre, size, mat, turn=None, bottom=True):
        """MeshBuilder.box(center:size:), turned about the upright as the
        game turns it if `turn` is given."""
        half = V(size) / 2
        if turn is None:
            self.box(V(centre) - half, V(centre) + half, mat, bottom=bottom)
        else:
            with self.placed(T(centre) @ RY(turn)):
                self.box(-half, half, mat, bottom=bottom)

    def lathe(self, profile, sides, mat, twist=0.0, caps=(True, True)):
        """A solid turned about the upright from its profile, bottom to top,
        each end with a radius capped if `caps` says so."""
        step = 2 * math.pi / sides
        for band in range(len(profile) - 1):
            (r0, y0), (r1, y1) = profile[band], profile[band + 1]
            for side in range(sides):
                a0 = side * step + twist
                a1 = a0 + step
                self.quad(ring(r0, y0, a0), ring(r0, y0, a1), ring(r1, y1, a1), ring(r1, y1, a0), mat)
        r, y = profile[0]
        if caps[0] and r > 0:
            self.polygon([ring(r, y, s * step + twist) for s in reversed(range(sides))], mat)
        r, y = profile[-1]
        if caps[1] and r > 0:
            self.polygon([ring(r, y, s * step + twist) for s in range(sides)], mat)

    def tube(self, profile, sides, mat, twist=0.0):
        self.lathe(profile, sides, mat, twist=twist, caps=(False, False))

    def cone(self, sides, radius, top, mat, bottom=0.0, twist=0.0, base=True):
        self.lathe([(radius, bottom), (0.0, top)], sides, mat, twist=twist, caps=(base, False))

    def limb(self, a, b, radius, mat, top=None, sides=4, closed=(False, False)):
        """A bough or a branch from one point to another, its ends left open
        for the trunk to hide, unless `closed` says to close them (its foot,
        its far end)."""
        a, b = V(a), V(b)
        length = (b - a).length
        if length == 0:
            return
        with self.placed(T(a) @ aligning_up(b - a)):
            self.lathe([(radius, 0.0), (radius if top is None else top, length)], sides, mat, caps=closed)

    def spike(self, a, b, radius, mat, sides=3, twist=0.0):
        """A blade or a twig from its foot to its point, its foot left open
        where it is hidden."""
        a, b = V(a), V(b)
        with self.placed(T(a) @ aligning_up(b - a)):
            self.cone(sides, radius, (b - a).length, mat, twist=twist, base=False)

    def beam(self, a, b, width, mat, depth=None, bottom=True):
        """A squared stone from one point to another, squared as the game
        squares one: a level one `width` across the ground and `depth`
        deep; without its underside if `bottom` is false."""
        a, b = V(a), V(b)
        along_ = b - a
        length = along_.length
        if length == 0:
            return
        up = along_ / length
        reference = V(0, 0, 1) if abs(up.y) > 0.95 else V(0, 1, 0)
        side = up.cross(reference).normalized()
        front = side.cross(up)
        frame = Matrix(((side.x, up.x, front.x, a.x), (side.y, up.y, front.y, a.y), (side.z, up.z, front.z, a.z), (0, 0, 0, 1)))
        d = width if depth is None else depth
        with self.placed(frame):
            # A level beam's local -z is the world's down.
            self.box((-width / 2, 0, -d / 2), (width / 2, length, d / 2), mat, back=bottom)

    def rock(self, centre, size, seed, mat, rings=3, sides=6, jitter=0.2, shape=None):
        """A rough lump, each point pushed in or out by the game's noise;
        each point then moved by `shape`, if given."""
        grid = []
        for k in range(rings + 1):
            latitude = math.pi * k / rings - math.pi / 2
            pole = k in (0, rings)
            row = []
            for side in range(sides):
                longitude = 2 * math.pi * side / sides
                push = 1 + jitter * (2 * unit(k, 0 if pole else side, seed) - 1)
                d = (math.cos(latitude) * math.cos(longitude), math.sin(latitude), -math.cos(latitude) * math.sin(longitude))
                p = V(centre) + V(d[0] * size[0] * push, d[1] * size[1] * push, d[2] * size[2] * push)
                row.append(shape(p) if shape else p)
            grid.append(row)
        for k in range(rings):
            for side in range(sides):
                n = (side + 1) % sides
                self.quad(grid[k][side], grid[k][n], grid[k + 1][n], grid[k + 1][side], mat)

    def tier(self, radius, base, top, mat, twist, droop, sides=6):
        """A fir's tier of boughs: a cone from its rim up to its point,
        every other bough's tip drooping `droop` below the rim and those
        between lifted half that, its underside closed."""
        step = 2 * math.pi / sides
        rim = [ring(radius, base - droop if s % 2 == 0 else base + droop / 2, s * step + twist) for s in range(sides)]
        for s in range(sides):
            self.triangle(rim[s], rim[(s + 1) % sides], (0, top, 0), mat)
        self.polygon(list(reversed(rim)), mat)

    # Out to Blender

    def make(self):
        """The piece as an object of the file, flat, its sway as _SWAY."""
        mesh = bpy.data.meshes.new(self.name)
        obj = link(bpy.data.objects.new(self.name, mesh))
        bm = bmesh.new()
        mats = []
        for i in range(0, len(self.corners), 3):
            corners = self.corners[i:i + 3]
            mat = corners[0][1]
            if mat not in mats:
                mats.append(mat)
            made = bm.faces.new([bm.verts.new(at(p.x, p.y, p.z)) for p, _, _ in corners])
            made.material_index = mats.index(mat)
        bm.to_mesh(mesh)
        bm.free()
        for mat in mats:
            mesh.materials.append(mat)
        if any(s > 0 for _, _, s in self.corners):
            attr = mesh.attributes.new("_SWAY", "FLOAT", "POINT")
            for i, (_, _, s) in enumerate(self.corners):
                attr.data[i].value = clamp01(s)
        return obj


# MARK: Trees

def fir(b):
    """Land.fir: a dark fir in three tiers, its crown moving in the wind.
    Its trunk six-sided and open, its foot underground and its head within
    the lowest tier (the game's was four-sided and capped where neither
    shows), every other bough's tip drooping below its tier's rim."""
    b.tube([(0.03, -0.06), (0.022, 0.16)], 6, bark)
    with b.swaying(rising(1.0, 0.08, 0.6)):
        for index, base in enumerate((0.1, 0.26, 0.4)):
            radius = 0.17 - index * 0.04
            b.tier(radius, base, base + 0.25 - index * 0.02, fir_green if index == 1 else fir_dark, twist=index * 0.5,
                   droop=0.028 - index * 0.006)


ELDER_MASSES = [((0, 0.66, 0), (0.26, 0.18, 0.26)), ((0.17, 0.56, 0.09), (0.18, 0.13, 0.17)), ((-0.15, 0.58, 0.12), (0.17, 0.13, 0.16)),
                ((0.02, 0.57, -0.19), (0.2, 0.13, 0.15)), ((0.04, 0.82, 0.02), (0.16, 0.12, 0.16))]


def elder_tree(b):
    """Land.elderTree: a gnarled trunk on spread roots, a broad crown of
    heavy masses. Its boughs' ends closed (the game left them open, one
    out under the crown's western side and the others half out of their
    masses), its trunk's foot left open underground."""
    b.lathe([(0.12, -0.08), (0.085, 0.06), (0.07, 0.22), (0.08, 0.34), (0.05, 0.42)], 6, bark, caps=(False, True))
    for index in range(5):
        angle = index * 2 * math.pi / 5 + 0.3
        b.limb((0, 0.07, 0), ring(0.2, -0.01, angle), 0.035, bark, top=0.012, sides=3)
    for index in range(3):
        angle = index * 2 * math.pi / 3 + 0.8
        b.limb((0, 0.3, 0), ring(0.2, 0.52, angle), 0.035, bark, top=0.02, sides=4, closed=(False, True))
    with b.swaying(rising(0.7, 0.4, 0.95)):
        for index, (centre, size) in enumerate(ELDER_MASSES):
            b.rock(centre, size, 40 + index, leaf if index % 2 == 0 else fir_green, rings=3, sides=6, jitter=0.15)


def birch(b):
    """Land.birch: a slim pale trunk banded dark, two thin boughs and a
    light crown that moves in the wind. Its boughs sway by their height on
    the tree (the game took it along each bough, so they never moved)."""
    b.lathe([(0.022, -0.05), (0.018, 0.25), (0.01, 0.5)], 5, birch_bark)
    for index, height in enumerate((0.08, 0.17, 0.29, 0.38)):
        width = 0.044 - 0.006 * index
        b.cube((0, height, 0), (width, 0.012, width), soot, turn=index * 0.7)
    with b.swaying(rising(0.3, 0.2, 0.5)):
        b.limb((0, 0.3, 0), (0.09, 0.44, 0.02), 0.008, birch_bark, top=0.003, sides=3)
        b.limb((0, 0.36, 0), (-0.07, 0.5, -0.03), 0.007, birch_bark, top=0.003, sides=3)
    with b.swaying(rising(0.9, 0.3, 0.7)):
        masses = [((0, 0.52, 0), (0.11, 0.13, 0.1)), ((0.07, 0.43, 0.03), (0.08, 0.09, 0.07)), ((-0.06, 0.46, -0.03), (0.08, 0.09, 0.08))]
        for index, (centre, size) in enumerate(masses):
            b.rock(centre, size, 60 + index, birch_leaf if index == 0 else leaf, rings=3, sides=6, jitter=0.2)


DEAD_BRANCHES = [(0.18, (0.13, 0.3, 0.03)), (0.24, (-0.11, 0.38, -0.04)), (0.33, (0.05, 0.46, -0.1)), (0.36, (-0.06, 0.5, 0.09))]


def dead_tree(b):
    """Land.deadTree: bleached pale, its branches bare, a twig forking from
    each. They sway a little by their height on the tree (the game took it
    along each branch, so they never moved); the trunk stands, its broken
    top capped and its foot left open underground."""
    b.lathe([(0.04, -0.05), (0.03, 0.2), (0.016, 0.45)], 5, dead_wood, caps=(False, True))
    with b.swaying(rising(0.25, 0.15, 0.5)):
        for index, (height, tip) in enumerate(DEAD_BRANCHES):
            foot, tip = V(0, height, 0), V(tip)
            b.limb(foot, tip, 0.013, dead_wood, top=0.004, sides=3)
            fork = mix(foot, tip, 0.55)
            out = V(tip.x, 0, tip.z).normalized()
            turn = 0.9 if index % 2 == 0 else -0.9
            sideways = V(out.x * math.cos(turn) + out.z * math.sin(turn), 0, -out.x * math.sin(turn) + out.z * math.cos(turn))
            b.spike(fork, fork + sideways * 0.05 + V(0, 0.065, 0), 0.0045, dead_wood, twist=index)


# MARK: Stone

def crag(b):
    """Land.crag: a tall jagged shard with a lesser beside it and a stone
    behind; and a splinter split from it standing against its western
    flank, to break its outline."""
    b.rock((0, 0.18, 0), (0.16, 0.34, 0.13), 51, rock_grey, rings=4, sides=6, jitter=0.3)
    b.rock((0.15, 0.06, 0.08), (0.09, 0.14, 0.08), 52, dark_stone, rings=3, sides=5, jitter=0.3)
    b.rock((-0.12, 0.03, -0.08), (0.07, 0.07, 0.06), 53, rock_grey, rings=2, sides=5, jitter=0.2)
    with b.placed(T(-0.17, 0.0, 0.07) @ RZ(-0.1) @ RX(-0.08)):
        b.rock((0, 0.06, 0), (0.055, 0.18, 0.045), 54, rock_grey, rings=2, sides=4, jitter=0.25)


def boulder(b):
    """Land.furnishing's boulder: a rough lump of grey rock."""
    b.rock((0, 0.035, 0), (0.09, 0.07, 0.075), 31, rock_grey, rings=3, sides=6, jitter=0.2)


def standing_stone(b):
    """Land.standingStone: a tall stone set upright long ago, leaning a
    little, a lesser stone at its foot."""
    with b.placed(RZ(0.06) @ RX(-0.04)):
        b.lathe([(0.075, -0.08), (0.07, 0.2), (0.045, 0.34), (0.0, 0.37)], 4, dark_stone, twist=0.2)
    b.rock((0.08, 0.0, 0.06), (0.04, 0.025, 0.035), 61, stone, rings=2, sides=4, jitter=0.2)


DOOR = 0.02


def barrow_mound(b):
    """Land.barrowMound: a grassed burial mound, ten-sided so a face of it
    looks square out of its front (the game's nine set it askew), its
    foot left open underground; a doorway of three stones in its front,
    brought out a fiftieth to stand whole on the ground at the mound's
    foot (the game's lower half lay under the turf), its dark way in
    running back into the mound; and a kerb of stones half sunk about its
    foot."""
    b.lathe([(0.34, -0.06), (0.32, 0.04), (0.25, 0.13), (0.13, 0.19), (0, 0.21)], 10, barrow_turf, caps=(False, True))
    b.box((-0.07, -0.02, 0.2), (0.07, 0.11, 0.3 + DOOR), loam)
    for x in (-0.065, 0.065):
        b.cube((x, 0.05, 0.29 + DOOR), (0.035, 0.13, 0.035), dark_stone)
    b.cube((0, 0.125, 0.29 + DOOR), (0.17, 0.03, 0.045), stone)
    for index in range(5):
        angle = index * 0.7 + 2.2
        b.cube(ring(0.33, 0.015, angle), (0.04, 0.04, 0.035), dark_stone, turn=angle)


RUIN_WALLS = [((-0.2, 0, -0.15), (0.15, 0, -0.15), 0.2), ((-0.2, 0, -0.15), (-0.2, 0, 0.12), 0.13), ((0.15, 0, -0.15), (0.2, 0, 0.0), 0.08)]


def ruin(b):
    """Land.ruin: broken walls, a stump of a column, a drum of it fallen
    and a mound of turf, half sunk; and three of the walls' stones
    tumbled, two within and one out from the tallest, made of what the
    walls' and the column's undersides cost deep underground."""
    for index, (start, end, height) in enumerate(RUIN_WALLS):
        for piece in range(3):
            t0, t1 = piece / 3, (piece + 1) / 3 - 0.02
            tall = height * (0.5 + unit(index, piece, 71))
            a, c = mix(start, end, t0), mix(start, end, t1)
            lift = V(0, (tall - 0.08) / 2, 0)
            b.beam(a + lift, c + lift, 0.045, stone if piece % 2 == 0 else dark_stone, depth=tall + 0.08, bottom=False)
    b.lathe([(0.04, -0.05), (0.04, 0.16), (0.05, 0.17), (0.05, 0.2)], 6, pale_stone, caps=(False, True))
    with b.placed(T(0.08, 0.02, 0.12) @ RZ(math.pi / 2) @ RX(0.3)):
        b.lathe([(0.035, -0.12), (0.035, 0.12)], 6, pale_stone)
    b.rock((-0.05, 0.0, 0.05), (0.12, 0.03, 0.1), 72, ruin_turf, rings=2, sides=5, jitter=0.2)
    b.cube((-0.07, 0.014, -0.08), (0.06, 0.032, 0.04), dark_stone, turn=0.5, bottom=False)
    b.cube((0.1, 0.012, -0.075), (0.05, 0.028, 0.04), stone, turn=-0.35, bottom=False)
    b.cube((0.02, 0.013, -0.215), (0.055, 0.03, 0.04), stone, turn=0.25, bottom=False)


def stone_face(b):
    """Land.stoneFace: a seam's face cut flat, the blocks taken from it
    lying by. The rock is cut back behind the face (the game's swelled out
    over it, so little of the face or its marks showed), its marks stop
    short of its top (the game's met it in one plane), a third block lies
    on the others and spalls at the face's foot."""
    b.rock((0, 0.1, -0.08), (0.24, 0.17, 0.12), 81, rock_grey, rings=3, sides=6, jitter=0.2,
           shape=lambda p: V(p.x, p.y, min(p.z, -0.004)))
    b.box((-0.15, -0.02, -0.06), (0.13, 0.19, 0.0), pale_stone, bottom=False, back=False)
    for x in (-0.08, 0.0, 0.07):
        b.cube((x, 0.085, 0.001), (0.004, 0.19, 0.004), stone, bottom=False)
    b.cube((-0.1, 0.02, 0.09), (0.07, 0.045, 0.05), pale_stone, turn=0.3, bottom=False)
    b.cube((0.06, 0.02, 0.1), (0.06, 0.045, 0.05), stone, turn=-0.2, bottom=False)
    # The third on the first, within its top.
    b.cube((-0.1 + 0.005 * math.cos(0.3), 0.063, 0.09 - 0.005 * math.sin(0.3)), (0.05, 0.04, 0.04), pale_stone, turn=0.48, bottom=False)
    b.rock((-0.02, 0.004, 0.032), (0.03, 0.016, 0.022), 82, pale_stone, rings=2, sides=4, jitter=0.25)


# MARK: Small things

def reeds(b, count=9, height=0.2, seed=5):
    """Land.reeds: thin blades rising from one root, bending more toward
    their tips, by their length from it. Each open at its foot underground
    (the game's were capped there), and for those caps three more, laid out
    by the game's own rule: the first after its nine that keep within their
    reach across the ground (the tenth would reach beyond it)."""
    for index in list(range(count)) + [count + 1, count + 2, count + 3]:
        u, v = unit(index, 1, seed), unit(index, 2, seed)
        foot = V((u - 0.5) * 0.12, -0.03, (v - 0.5) * 0.12)
        tip = foot + V((u - 0.5) * 0.08, height * (0.7 + 0.5 * v), (v - 0.5) * 0.08)
        with b.swaying(along(1.0, foot, tip, height)):
            b.spike(foot, tip, 0.009, reed_blade if index % 3 == 0 else grass_blade, twist=u * 3)


def grass(b, tufts=5, spread=0.07, seed=2):
    """Land.grass: tufts of grey grass, each of blades leaning out from its
    root, swaying by their length from it. Six to a tuft, each open at its
    foot underground (the game's four were capped there)."""
    for index in range(tufts):
        u, v = unit(index, 5, seed), unit(index, 6, seed)
        root = V((u - 0.5) * 2 * spread, -0.015, (v - 0.5) * 2 * spread)
        for blade in range(6):
            angle = blade * 1.7 + u * 6
            tip = root + ring(0.035, 0.07 + 0.04 * unit(index, blade, seed), angle)
            with b.swaying(along(0.8, root, tip, 0.1)):
                b.spike(root, tip, 0.011, grass_blade if blade % 2 == 0 else reed_blade, twist=angle)


def heather(b, seed=21):
    """Land.heather: low clumps of dark mauve, each with sprigs in bloom,
    swaying a little by their height (the sprigs by their height on the
    clump, not along themselves, so they keep to it). Four sprigs to a
    clump, the fourth shorter between the first two, each open at its
    foot within the clump (the game's three were capped there)."""
    with b.swaying(rising(0.35, 0.0, 0.06)):
        for clump in range(4):
            u, v = unit(clump, 11, seed), unit(clump, 12, seed)
            centre = V((u - 0.5) * 0.16, 0.012, (v - 0.5) * 0.16)
            size = 0.028 + 0.018 * unit(clump, 13, seed)
            b.rock(centre, (size * 1.3, size * 0.7, size * 1.2), (seed + clump) & M32, heather_mauve if clump % 2 == 0 else heather_dark,
                   rings=2, sides=5, jitter=0.25)
            for sprig in range(4):
                angle = sprig * 2.1 + u * 5 if sprig < 3 else 1.05 + u * 5
                reach = 1.0 if sprig < 3 else 0.8
                b.spike(centre, centre + ring(size * 0.9 * reach, size * 1.4 * reach, angle), 0.006, heather_bloom, twist=angle)


def fern(b, seed=23):
    """Land.fern: fronds arching out from one crown and down again, each in
    two lengths. They sway by their reach from the crown, more at their
    tips (the game took each length from its own foot, so the two parted)."""
    with b.swaying(outward(0.6, (0, 0.005, 0), 0.12)):
        for frond in range(7):
            angle = frond * 2 * math.pi / 7 + unit(frond, 14, seed) * 0.5
            reach = 0.09 + 0.04 * unit(frond, 15, seed)
            middle, tip = ring(reach * 0.5, 0.07, angle), ring(reach, 0.035, angle)
            b.limb((0, 0.005, 0), middle, 0.012, fern_green if frond % 2 == 0 else leaf, top=0.009, sides=3)
            b.limb(middle, tip, 0.009, fern_green, top=0.002, sides=3)


def stepping_stones(b):
    """Land.steppingStones: broad flat stones a stride apart along a ford,
    each its own shape."""
    for index in range(5):
        x = (index - 2) * 0.13
        wander = (unit(index, 41, 7) - 0.5) * 0.05
        size = 0.045 + 0.012 * unit(index, 42, 7)
        b.rock((x, 0.012, wander), (size * 1.2, 0.022, size), 61 + index, pale_stone if index % 2 == 0 else stone, rings=2, sides=6,
               jitter=0.12)


def pebbles(b, seed=27):
    """Land.pebbles: washed up and left, small and smooth, of the lake's two
    stones."""
    for index in range(6):
        u, v = unit(index, 16, seed), unit(index, 17, seed)
        size = 0.012 + 0.012 * unit(index, 18, seed)
        b.rock(((u - 0.5) * 0.18, size * 0.4, (v - 0.5) * 0.18), (size * 1.3, size * 0.8, size), (seed + index) & M32,
               pale_stone if index % 3 == 0 else stone, rings=2, sides=5, jitter=0.15)


def crystals(b, count=6, height=0.13, seed=8):
    """Land.crystals: moonsalt grown in clustered six-sided spars, each one
    solid, a shoulder at its column's head below its point (the game's spar
    was two, a column and its point, their ends face to face inside it)
    and its foot open underground."""
    for index in range(count):
        u, v = unit(index, 7, seed), unit(index, 8, seed)
        foot = V((u - 0.5) * 0.12, -0.02, (v - 0.5) * 0.12)
        lean = V((u - 0.5) * 0.8, 1, (v - 0.5) * 0.8)
        tall = height * (0.45 + 0.7 * unit(index, 9, seed))
        r = 0.018 + 0.012 * u
        with b.placed(T(foot) @ aligning_up(lean)):
            b.lathe([(r, 0.0), (r, tall * 0.75), (r * 0.78, tall * 0.8), (0.0, tall)], 6, salt, caps=(False, False))


def driftwood(b):
    """Land.driftwood: a pale log thrown up on the strand, its broken
    branches up; its ends and the branches' closed (the game's were open,
    the log hollow), the branch from its end grown out of it."""
    with b.placed(RY(0.4)):
        b.limb((-0.17, 0.02, 0), (0.17, 0.025, 0.01), 0.028, dead_wood, top=0.018, sides=5, closed=(True, True))
        b.limb((-0.06, 0.03, 0), (-0.1, 0.1, 0.05), 0.012, dead_wood, top=0.005, sides=3, closed=(False, True))
        b.limb((0.08, 0.03, 0), (0.13, 0.07, -0.06), 0.01, dead_wood, top=0.004, sides=3, closed=(False, True))
        # The branch out of the log's end, its foot drawn back within it.
        root, end = V(-0.17, 0.02, 0), V(-0.22, 0.05, -0.03)
        b.limb(root - (end - root).normalized() * 0.03, end, 0.015, dead_wood, top=0.006, sides=3, closed=(False, True))


FIELD = 0.018


def furrows(b):
    """Land.furrows: dark loam ploughed in ridges. The field lies a little
    above the ground at its foot even at its least size, the ridges with
    it (the game's lay under the ground, the ridges' tops a hair above
    it), and each ridge lies on a face, its crest up (the game's lay on an
    edge, a face upright, turned a quarter from its crest)."""
    lift = FIELD - 0.004
    b.box((-0.26, -0.06, -0.22), (0.26, FIELD, 0.22), loam)
    for index in range(6):
        z = index * 0.075 - 0.19
        with b.placed(T(0, lift, z) @ RZ(math.pi / 2)):
            b.lathe([(0.026, -0.25), (0.026, 0.25)], 3, earth)


BUILD = {"fir": fir, "elderTree": elder_tree, "deadTree": dead_tree, "crag": crag, "boulder": boulder, "reeds": reeds,
         "saltCrystals": crystals, "barrowMound": barrow_mound, "standingStone": standing_stone, "ruin": ruin, "grass": grass,
         "driftwood": driftwood, "furrows": furrows, "stoneFace": stone_face, "heather": heather, "fern": fern, "pebbles": pebbles,
         "birch": birch, "steppingStones": stepping_stones}
for name in FURNISHINGS:
    piece = Piece(name, name)
    BUILD[name](piece)
    piece.make()

finish_building(out_path("Art/models/furnishings.glb"), FURNISHINGS)
