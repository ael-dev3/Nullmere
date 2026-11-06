"""The sites of the land where a company gathers its stores, each a variant
of one file, filling a hex's heart some 0.6 from its middle:
- grain: a field of grain in ragged rows on dark loam, its ears standing
  thick above them and swaying; its sheaves stooked on the stubble along its
  front, a hedge of thorn down its western side with a gate open in it, an
  oak over its north-east corner and a shelter of poles under thatch where
  the tools are kept; close, a scarecrow between the rows, a sack for its
  head and a hat on that, a handcart of sheaves behind the stooks with a jug
  by it, a scythe against a stook and crows come for the grain;
- timber: a stand of tall firs in tiers of drooping boughs on spread roots,
  young firs between, two birches at its edge, ferns and heather under them;
  along its front the woodcutters' work: stumps, a felled trunk, the log
  pile, an axe left in a stump, their shelter of poles leant to a ridge and
  roofed in bark, a sledge with a log on it and a charcoal clamp under its
  turf; close, the stubs of the trunk's lopped branches and their greenery
  heaped, chips about the stumps, a sawhorse with a log in it and a saw in
  its cut over its sawdust, and a maul by the pile;
- stone: an outcrop of grey rock in three masses, its strata in bands, the
  quarrymen's faces cut back in steps into the greatest; blocks squared and
  stacked on the floor before it, a sledge with a block, sheerlegs over the
  cut with a block slung, the quarrymen's lean-to against the eastern mass,
  scree and boulders about its flanks and heather between; close, the
  chisel's marks down the cut faces, a split along the lowest step with the
  wedges driven into it and the hammer that drove them, a pick, rubble, a
  bucket, a rope coiled on the sledge's block and a bar by it;
- moonsalt: pans of moonsalt crusted white in rims of stone on the salt
  flat, moonsalt grown in clustered six-sided spars, heaps of it, walkways
  of planks between the pans, the rakers' hut of driftwood under reeds with
  its rakes leant at its door and their barrow, a rake by a heap, sluice
  boards holding back the brine at the shore's edge and reeds along it;
  close, baskets of salt, a wheelbarrow at the hut's door, a shovel in a
  heap, sacks filled from it and a pusher laid across a pan.
They stand still: only their leaves and grain move, in the wind.

Built as the game built them in code (Land.site and the land's small things
it borrows), triangle by triangle: each solid made in the world's axes and
units and placed as the game placed it, each triangle flat.

    python Art/blender/sites.py Art/models/sites.glb
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
SITES = ["grain", "timber", "stone", "moonsalt"]

# MARK: Materials, each one of the palette's colours or a mix of two

loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
# The salt flat: the palette's salt crust half way to earth.
saltflat = material("plain_earth_saltflat", (0.52, 0.52, 0.52))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
rock_grey = material("plain_stone_rock", (0.4, 0.4, 0.42))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
bark = material("plain_timber_bark", (0.21, 0.17, 0.14))
birch_bark = material("plain_timber_birchbark", (0.8, 0.79, 0.74))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
straw = material("plain_thatch_straw", (0.62, 0.55, 0.36))
reed_thatch = material("plain_thatch_reed", (0.47, 0.45, 0.33))
soot = material("plain_soot", (0.11, 0.1, 0.1))
moss = material("plain_moss", (0.21, 0.26, 0.22))
linen = material("plain_linen", (0.7, 0.67, 0.6))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
leather = material("plain_leather_dark", (0.22, 0.16, 0.12))
wool = material("plain_wooldark", (0.24, 0.24, 0.25))
ash = material("plain_ash", (0.55, 0.56, 0.56))
# The jug's fired clay: the palette's earth a third of the way to madder.
jug_clay = material("plain_jug", (0.3, 0.219, 0.183))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.7), roughness=0.4, metallic=0.7)
salt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)
crust = material("crystal_saltcrust", (0.8, 0.83, 0.86), roughness=0.2)
leaf = material("foliage_ivy", (0.16, 0.24, 0.17))
fir_green = material("foliage_fir", (0.11, 0.19, 0.15))
fir_dark = material("foliage_firdark", (0.08, 0.14, 0.12))
birch_leaf = material("foliage_birchleaf", (0.4, 0.44, 0.27))
fern_green = material("foliage_fern", (0.18, 0.28, 0.19))
heather_mauve = material("foliage_heather", (0.3, 0.24, 0.29))
heather_dark = material("foliage_heatherdark", (0.21, 0.18, 0.21))
heather_bloom = material("foliage_heatherbloom", (0.46, 0.34, 0.44))
reed_blade = material("foliage_reed", (0.47, 0.45, 0.33))
grass_blade = material("foliage_grass", (0.37, 0.41, 0.31))
grain_ear = material("foliage_grain", (0.66, 0.6, 0.4))
straw_stalk = material("foliage_straw", (0.62, 0.55, 0.36))

# The site is set a hundredth below the ground at its heart (Scatter.sink):
# what lies on the ground lies a little above that, as a work's pad does.
GROUND = 0.012


# MARK: The game's noise, so the site is laid out as it was

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


def S(s):
    return Matrix.Diagonal((s, s, s, 1.0))


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


def clamp01(t):
    return max(0.0, min(1.0, t))


def rising(amount, low, high, frame=None):
    """How far a corner sways, as the game's swayRange gives it: nothing at
    `low` to `amount` at `high`, as the square of the share between, the
    heights taken in `frame` (a placement, the world's if none)."""
    inverse = frame.inverted() if frame is not None else None

    def sway(p, inverse=inverse):
        y = (inverse @ p).y if inverse is not None else p.y
        return amount * clamp01((y - low) / (high - low)) ** 2
    return sway


# MARK: A piece built as the game's MeshBuilder builds, triangle by triangle

class Piece:
    """One object of the file, its triangles laid down as the game lays
    them (MeshBuilder, Shapes, Works): each solid placed by the matrices
    about it, each corner swaying as `sway` gives it at its point."""

    def __init__(self, name, site, fine=False):
        self.name = tagged(name, [site]) + ("!fine" if fine else "")
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

    def face(self, points, outward, mat):
        points = [V(p) for p in points]
        n = (points[1] - points[0]).cross(points[2] - points[0])
        self.polygon(points if n.dot(V(outward)) >= 0 else list(reversed(points)), mat)

    # Solids

    def box(self, low, high, mat):
        """MeshBuilder.box(min:max:)."""
        x0, y0, z0 = low
        x1, y1, z1 = high
        self.quad((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), mat)
        self.quad((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), mat)
        self.quad((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0), mat)
        self.quad((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), mat)
        self.quad((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), mat)
        self.quad((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), mat)

    def cube(self, centre, size, mat, turn=None):
        """MeshBuilder.box(center:size:), turned about the upright as the
        game turns it if `turn` is given."""
        half = V(size) / 2
        if turn is None:
            self.box(V(centre) - half, V(centre) + half, mat)
        else:
            with self.placed(T(centre) @ RY(turn)):
                self.box(-half, half, mat)

    def lathe(self, profile, sides, mat, twist=0.0, bands=None, caps=True):
        """A solid turned about the upright from its profile, bottom to top,
        its ends with a radius capped; `bands`, a material for each band."""
        step = 2 * math.pi / sides
        for band in range(len(profile) - 1):
            (r0, y0), (r1, y1) = profile[band], profile[band + 1]
            shade = bands[min(band, len(bands) - 1)] if bands else mat
            for side in range(sides):
                a0 = side * step + twist
                a1 = a0 + step
                self.quad(ring(r0, y0, a0), ring(r0, y0, a1), ring(r1, y1, a1), ring(r1, y1, a0), shade)
        if not caps:
            return
        r, y = profile[0]
        if r > 0:
            self.polygon([ring(r, y, s * step + twist) for s in reversed(range(sides))], bands[0] if bands else mat)
        r, y = profile[-1]
        if r > 0:
            self.polygon([ring(r, y, s * step + twist) for s in range(sides)], bands[-1] if bands else mat)

    def tube(self, profile, sides, mat, twist=0.0):
        self.lathe(profile, sides, mat, twist=twist, caps=False)

    def cone(self, sides, radius, top, mat, bottom=0.0, twist=0.0):
        self.lathe([(radius, bottom), (0.0, top)], sides, mat, twist=twist)

    def sphere(self, centre, radius, mat, rings=4, sides=6):
        profile = []
        for k in range(rings + 1):
            angle = math.pi * k / rings - math.pi / 2
            profile.append((radius * math.cos(angle), radius * math.sin(angle)))
        with self.placed(T(centre)):
            self.lathe(profile, sides, mat)

    def gable_roof(self, width, depth, base, height, mat, overhang=0.0):
        """MeshBuilder.gableRoof: its ridge east to west."""
        w, d, top = width / 2 + overhang, depth / 2 + overhang, base + height
        self.quad((-w, base, d), (w, base, d), (w, top, 0), (-w, top, 0), mat)
        self.quad((w, base, -d), (-w, base, -d), (-w, top, 0), (w, top, 0), mat)
        self.triangle((w, base, d), (w, base, -d), (w, top, 0), mat)
        self.triangle((-w, base, -d), (-w, base, d), (-w, top, 0), mat)
        self.quad((-w, base, -d), (w, base, -d), (w, base, d), (-w, base, d), mat)

    def limb(self, a, b, radius, mat, top=None, sides=4):
        """A haft or a bough from one point to another, its ends open."""
        a, b = V(a), V(b)
        length = (b - a).length
        if length == 0:
            return
        with self.placed(T(a) @ aligning_up(b - a)):
            self.tube([(radius, 0.0), (radius if top is None else top, length)], sides, mat)

    def sheet(self, points, normal, mat, thickness=0.004):
        """A thin flat thing seen from both sides: a blade, a tail."""
        offset = V(normal).normalized() * (thickness / 2)
        self.face([V(p) + offset for p in points], V(normal), mat)
        self.face([V(p) - offset for p in points], -V(normal), mat)

    def beam(self, a, b, width, mat, depth=None):
        """A squared timber from one point to another, squared as the game
        squares one: a level one `width` across the ground and `depth`
        deep, a standing one `width` east to west."""
        a, b = V(a), V(b)
        along = b - a
        length = along.length
        if length == 0:
            return
        up = along / length
        reference = V(0, 0, 1) if abs(up.y) > 0.95 else V(0, 1, 0)
        side = up.cross(reference).normalized()
        front = side.cross(up)
        frame = Matrix(((side.x, up.x, front.x, a.x), (side.y, up.y, front.y, a.y), (side.z, up.z, front.z, a.z), (0, 0, 0, 1)))
        d = width if depth is None else depth
        with self.placed(frame):
            self.box((-width / 2, 0, -d / 2), (width / 2, length, d / 2), mat)

    def rock(self, centre, size, seed, mat, rings=3, sides=6, jitter=0.2):
        """A rough lump, each point pushed in or out by the game's noise."""
        grid = []
        for k in range(rings + 1):
            latitude = math.pi * k / rings - math.pi / 2
            pole = k in (0, rings)
            row = []
            for side in range(sides):
                longitude = 2 * math.pi * side / sides
                push = 1 + jitter * (2 * unit(k, 0 if pole else side, seed) - 1)
                d = (math.cos(latitude) * math.cos(longitude), math.sin(latitude), -math.cos(latitude) * math.sin(longitude))
                row.append(V(centre) + V(d[0] * size[0] * push, d[1] * size[1] * push, d[2] * size[2] * push))
            grid.append(row)
        for k in range(rings):
            for side in range(sides):
                n = (side + 1) % sides
                self.quad(grid[k][side], grid[k][n], grid[k + 1][n], grid[k + 1][side], mat)

    def log(self, a, c, radius):
        """A log lying from one end to the other, its cut ends pale."""
        a, c = V(a), V(c)
        length = (c - a).length
        step = 2 * math.pi / 5
        with self.placed(T(a) @ aligning_up(c - a)):
            self.tube([(radius, 0.0), (radius, length)], 5, bark)
            self.polygon([ring(radius, 0, s * step) for s in reversed(range(5))], pale)
            self.polygon([ring(radius, length, s * step) for s in range(5)], pale)

    def tied_sack(self, at_point, size, mat=canvas):
        with self.placed(T(at_point) @ S(size)):
            self.lathe([(0.0, 0.0), (0.022, 0.004), (0.027, 0.02), (0.021, 0.036), (0.008, 0.044), (0.011, 0.05), (0.0, 0.052)], 6, mat)

    def salt_heap(self, at_point, radius, height):
        with self.placed(T(at_point)):
            self.lathe([(radius, -0.01), (radius * 0.75, height * 0.5), (0.0, height)], 6, salt)

    def salt_pan(self, at_point, size, share=1.0):
        """A shallow pan of moonsalt in a rim of stone, the rim's lengths
        along x running over the corners and those along z butting on them
        (the game's overlapped at each corner's inside, top on top, and
        left its outside open)."""
        h, rim = size / 2, 0.016
        with self.placed(T(at_point)):
            for z in (-h, h):
                self.beam((-h - rim / 2, 0.008, z), (h + rim / 2, 0.008, z), rim, pale_stone, depth=0.04)
            for x in (h, -h):
                self.beam((x, 0.008, -h + rim / 2), (x, 0.008, h - rim / 2), rim, pale_stone, depth=0.04)
            self.box((-h, -0.02, -h), (h, 0.006, h), loam)
            k = h * 0.92 * share
            self.box((-k, 0.008, -k), (k, 0.016, k), crust)

    def blocks(self, at_point, count, seed):
        """Cut stone blocks in courses, pale and grey."""
        for index in range(count):
            jitter = unit(index, 3, seed)
            row, layer = index % 3, index // 3
            p = V(at_point) + V(row * 0.062 - 0.062, layer * 0.042, layer * 0.012)
            self.cube(p + V(0, 0.021, 0), (0.056, 0.04, 0.05), pale_stone if jitter < 0.5 else stone, turn=(jitter - 0.5) * 0.3)

    def wheel(self, centre, radius, width, spokes, mat, rim=None, turn=0.0):
        """A spoked wheel about `centre` on an axle along x, as the game's
        stands, turned `turn` about the upright: its rim a ring of eight
        felloes, its spokes crossing at the hub and the light between them
        (the game's was a solid disc, its spokes buried in it)."""
        depth = max(radius * 0.2, width * 0.5)
        w = width / 2

        def p(r, a, x):
            return (x, r * math.cos(a), r * math.sin(a))
        with self.placed(T(centre) @ RY(turn)):
            for k in range(8):
                a0 = 2 * math.pi * k / 8 + math.pi / 8
                a1 = a0 + 2 * math.pi / 8
                out, inner = radius, radius - depth
                self.quad(p(out, a0, -w), p(out, a1, -w), p(out, a1, w), p(out, a0, w), rim or mat)
                self.quad(p(inner, a0, w), p(inner, a1, w), p(inner, a1, -w), p(inner, a0, -w), rim or mat)
                self.quad(p(inner, a0, w), p(out, a0, w), p(out, a1, w), p(inner, a1, w), rim or mat)
                self.quad(p(inner, a1, -w), p(out, a1, -w), p(out, a0, -w), p(inner, a0, -w), rim or mat)
            # Each spoke a little slighter than the last, so where they cross
            # at the hub no two faces lie in one plane.
            reach = radius - depth * 0.5
            for index in range(spokes):
                angle = math.pi * index / spokes
                d = V(0, math.cos(angle), math.sin(angle)) * reach
                self.beam(-d, d, width * 0.6 * (1 - 0.08 * index), mat)

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


def made(*pieces):
    for piece in pieces:
        piece.make()


# MARK: The land's small things, as Land.swift builds them

def fir(b, at_point, scale=1.0):
    """Land.fir: a dark fir in three tiers, its crown moving in the wind."""
    frame = T(at_point) @ S(scale)
    world = b.transform @ frame
    with b.placed(frame):
        b.lathe([(0.03, -0.06), (0.022, 0.16)], 4, bark)
    with b.placed(frame), b.swaying(rising(1.0, 0.08, 0.6, world)):
        for index, base in enumerate((0.1, 0.26, 0.4)):
            radius = 0.17 - index * 0.04
            b.lathe([(radius, base), (0.0, base + 0.25 - index * 0.02)], 6, fir_green if index == 1 else fir_dark, twist=index * 0.5)


def tall_fir(b, at_point, scale, seed):
    """Land.tallFir: a trunk flaring at its roots, tiers of boughs drooping
    at their tips, each tier twisted from the last."""
    lean = (unit(seed, 3, 41) - 0.5) * 0.06
    frame = T(at_point) @ S(scale) @ RZ(lean)
    world = b.transform @ frame
    with b.placed(frame):
        b.lathe([(0.05, -0.04), (0.034, 0.02), (0.026, 0.3), (0.012, 0.56)], 6, bark)
        for root in range(4):
            angle = root * math.pi / 2 + (seed % 7) * 0.3
            b.limb((0, 0.02, 0), ring(0.07, -0.01, angle), 0.014, bark, top=0.004, sides=3)
    with b.placed(frame), b.swaying(rising(1.0, 0.1, 0.62, world)):
        for tier in range(4):
            base = 0.1 + tier * 0.11
            radius = 0.18 - tier * 0.035
            b.lathe([(radius * 0.85, base - 0.02), (radius, base), (radius * 0.55, base + 0.07), (0.0, base + 0.15)], 6,
                    fir_dark if tier % 2 == 0 else fir_green, twist=tier * 0.4)


def birch(b, frame):
    """Land.birch: a slim pale trunk banded dark, two thin boughs and a
    light crown. Its boughs sway by their height on the tree, from where
    they leave the trunk (the game took it along each bough, so they never
    moved)."""
    world = b.transform @ frame
    with b.placed(frame):
        b.lathe([(0.022, -0.05), (0.018, 0.25), (0.01, 0.5)], 5, birch_bark)
        for index, height in enumerate((0.08, 0.17, 0.29, 0.38)):
            width = 0.044 - 0.006 * index
            b.cube((0, height, 0), (width, 0.012, width), soot, turn=index * 0.7)
    with b.placed(frame), b.swaying(rising(0.3, 0.2, 0.5, world)):
        b.limb((0, 0.3, 0), (0.09, 0.44, 0.02), 0.008, birch_bark, top=0.003, sides=3)
        b.limb((0, 0.36, 0), (-0.07, 0.5, -0.03), 0.007, birch_bark, top=0.003, sides=3)
    with b.placed(frame), b.swaying(rising(0.9, 0.3, 0.7, world)):
        masses = [((0, 0.52, 0), (0.11, 0.13, 0.1)), ((0.07, 0.43, 0.03), (0.08, 0.09, 0.07)), ((-0.06, 0.46, -0.03), (0.08, 0.09, 0.08))]
        for index, (centre, size) in enumerate(masses):
            b.rock(centre, size, 60 + index, birch_leaf if index == 0 else leaf, rings=3, sides=6, jitter=0.2)


def elder_tree(b, frame):
    """Land.elderTree: a gnarled trunk on spread roots, a broad crown of
    heavy masses."""
    world = b.transform @ frame
    with b.placed(frame):
        b.lathe([(0.12, -0.08), (0.085, 0.06), (0.07, 0.22), (0.08, 0.34), (0.05, 0.42)], 6, bark)
        for index in range(5):
            angle = index * 2 * math.pi / 5 + 0.3
            b.limb((0, 0.07, 0), ring(0.2, -0.01, angle), 0.035, bark, top=0.012, sides=3)
        for index in range(3):
            angle = index * 2 * math.pi / 3 + 0.8
            b.limb((0, 0.3, 0), ring(0.2, 0.52, angle), 0.035, bark, top=0.02, sides=4)
    with b.placed(frame), b.swaying(rising(0.7, 0.4, 0.95, world)):
        masses = [((0, 0.66, 0), (0.26, 0.18, 0.26)), ((0.17, 0.56, 0.09), (0.18, 0.13, 0.17)), ((-0.15, 0.58, 0.12), (0.17, 0.13, 0.16)),
                  ((0.02, 0.57, -0.19), (0.2, 0.13, 0.15)), ((0.04, 0.82, 0.02), (0.16, 0.12, 0.16))]
        for index, (centre, size) in enumerate(masses):
            b.rock(centre, size, 40 + index, leaf if index % 2 == 0 else fir_green, rings=3, sides=6, jitter=0.15)


def fern(b, at_point, seed):
    """Land.fern: fronds arching out from one crown and down again. They
    sway by their reach from the crown, more at their tips (the game took
    each half of a frond from its own foot, so the halves parted)."""
    frame = T(at_point)
    crown = b.transform @ frame @ V(0, 0.005, 0)
    with b.placed(frame), b.swaying(lambda p, c=crown: 0.6 * clamp01((p - c).length / 0.12) ** 2):
        for frond in range(7):
            angle = frond * 2 * math.pi / 7 + unit(frond, 14, seed) * 0.5
            reach = 0.09 + 0.04 * unit(frond, 15, seed)
            middle, tip = ring(reach * 0.5, 0.07, angle), ring(reach, 0.035, angle)
            b.limb((0, 0.005, 0), middle, 0.012, fern_green if frond % 2 == 0 else leaf, top=0.009, sides=3)
            b.limb(middle, tip, 0.009, fern_green, top=0.002, sides=3)


def heather(b, at_point, seed):
    """Land.heather: low clumps of dark mauve, each with sprigs in bloom,
    swaying a little by their height (the sprigs by their height on the
    clump, not along themselves, so they keep to it)."""
    frame = T(at_point)
    world = b.transform @ frame
    with b.placed(frame), b.swaying(rising(0.35, 0.0, 0.06, world)):
        for clump in range(4):
            u, v = unit(clump, 11, seed), unit(clump, 12, seed)
            centre = V((u - 0.5) * 0.16, 0.012, (v - 0.5) * 0.16)
            size = 0.028 + 0.018 * unit(clump, 13, seed)
            b.rock(centre, (size * 1.3, size * 0.7, size * 1.2), (seed + clump) & M32, heather_mauve if clump % 2 == 0 else heather_dark,
                   rings=2, sides=5, jitter=0.25)
            for sprig in range(3):
                angle = sprig * 2.1 + u * 5
                tip = centre + ring(size * 0.9, size * 1.4, angle)
                with b.placed(T(centre) @ aligning_up(tip - centre)):
                    b.cone(3, 0.006, (tip - centre).length, heather_bloom, twist=angle)


def crystals(b, at_point, count, height, seed):
    """Land.crystals: moonsalt grown in clustered six-sided spars, each one
    solid, a shoulder below its point (the game's spar was two, a column
    and its point, their ends face to face inside it)."""
    for index in range(count):
        u, v = unit(index, 7, seed), unit(index, 8, seed)
        foot = V(at_point) + V((u - 0.5) * 0.12, -0.02, (v - 0.5) * 0.12)
        lean = V((u - 0.5) * 0.8, 1, (v - 0.5) * 0.8)
        tall = height * (0.45 + 0.7 * unit(index, 9, seed))
        r = 0.018 + 0.012 * u
        with b.placed(T(foot) @ aligning_up(lean)):
            b.lathe([(r, 0.0), (r, tall * 0.62), (r * 0.86, tall * 0.75), (0.0, tall)], 6, salt)


def reeds(b, at_point, count, height, seed):
    """Land.reeds: thin blades rising from one root, bending more toward
    their tips."""
    for index in range(count):
        u, v = unit(index, 1, seed), unit(index, 2, seed)
        foot = V(at_point) + V((u - 0.5) * 0.12, -0.03, (v - 0.5) * 0.12)
        tip = foot + V((u - 0.5) * 0.08, height * (0.7 + 0.5 * v), (v - 0.5) * 0.08)
        along = tip - foot
        sway = (lambda p, f=b.transform @ foot, n=(b.transform.to_3x3() @ along).normalized(): clamp01((p - f).dot(n) / height) ** 2)
        with b.placed(T(foot) @ aligning_up(along)), b.swaying(sway):
            b.cone(3, 0.009, along.length, reed_blade if index % 3 == 0 else grass_blade, twist=u * 3)


def raven(b, at_point, facing, seed):
    """Lairs.raven: a crow on the ground, its tail out behind."""
    with b.placed(T(at_point) @ RY(facing)):
        b.rock((0, 0.016, 0), (0.021, 0.013, 0.012), seed, soot, rings=3, sides=5, jitter=0.06)
        b.sphere((0.018, 0.03, 0), 0.009, soot, rings=3, sides=5)
        with b.placed(T(0.025, 0.029, 0) @ RZ(-math.pi / 2)):
            b.cone(4, 0.0035, 0.014, ash)
        b.sheet([(-0.017, 0.014, -0.007), (-0.017, 0.014, 0.007), (-0.042, 0.006, 0.006), (-0.042, 0.006, -0.006)], (0, 1, 0), soot)
        for z in (-0.004, 0.004):
            b.limb((0.002, 0.006, z), (0.004, 0.0, z), 0.0012, ash, sides=3)


# MARK: The grain field

site = "grain"
field = Piece("field", site)
# The field's loam a little above the ground at its heart (the game's lay
# under it).
field.box((-0.55, -0.08, -0.45), (0.55, GROUND, 0.45), loam)

# Rows of standing grain, a little ragged, a tuft of straw over each length.
# They sway by their height above the field (the game took each length's
# sway along it, west to east).
rows = Piece("rows", site)
with rows.swaying(rising(0.8, 0.0, 0.1)):
    for row in range(8):
        z = row * 0.11 - 0.385
        for length in range(3):
            jitter = unit(row, length, 91)
            x0 = length * 0.35 - 0.52
            x1 = x0 + 0.33
            y = 0.03 + 0.012 * jitter
            rows.beam((x0, y, z), (x1, y, z), 0.075, straw_stalk if (row + length) % 3 == 0 else grain_ear, depth=0.09 + 0.025 * jitter)
            with rows.placed(T((x0 + x1) / 2 + (jitter - 0.5) * 0.2, 0.05, z)):
                rows.cone(3, 0.02, 0.1, straw_stalk, twist=jitter * 3)

# The ears standing thick above the rows, swaying by their height (the
# game took it along each stalk and each ear, so they hardly stirred).
ears = Piece("ears", site)
with ears.swaying(rising(1.0, 0.02, 0.14)):
    for index in range(40):
        row, along = index % 8, (index // 8) / 5
        x = -0.5 + along + 0.04 * unit(index, 2, 93)
        z = row * 0.11 - 0.385 + 0.03 * (unit(index, 3, 93) - 0.5)
        ears.limb((x, 0.06, z), (x + 0.006, 0.11, z), 0.003, straw_stalk, sides=3)
        with ears.placed(T(x + 0.006, 0.11, z)):
            ears.lathe([(0.004, 0.0), (0.007, 0.012), (0.0, 0.028)], 4, grain_ear)

# Stooks of sheaves on the stubble along the field's front, each bound; the
# band stands a little proud of its stook (the game's met it at its top).
stooks = Piece("stooks", site)
for index in range(7):
    with stooks.placed(T(-0.45 + index * 0.15, 0, 0.52 + 0.02 * unit(index, 4, 95)) @ RY(index)):
        stooks.lathe([(0.05, -0.01), (0.04, 0.08), (0.06, 0.1), (0.03, 0.13), (0.0, 0.15)], 7, straw)
        stooks.lathe([(0.044, 0.074), (0.048, 0.086)], 7, pale)

# A hedge of thorn along its western side, a gate open in it.
hedge = Piece("hedge", site)
for index in range(9):
    if index == 6:
        continue
    hedge.rock((-0.6, 0.05, -0.42 + index * 0.1), (0.04, 0.06, 0.055), 150 + index, leaf if index % 2 == 0 else moss, rings=3, sides=6,
               jitter=0.35)
for z in (0.15, 0.25):
    hedge.limb((-0.6, 0, z), (-0.6, 0.08, z), 0.006, dark)
for y in (0.025, 0.05, 0.075):
    hedge.beam((-0.6, y, 0.155), (-0.55, y, 0.24), 0.005, pale)

# An oak spreading over the corner where the reapers rest.
oak = Piece("oak", site)
elder_tree(oak, T(0.55, 0, -0.42) @ S(0.75))

# A field shelter of poles under thatch where the tools are kept.
shelter = Piece("tool shelter", site)
shed = V(0.58, 0, 0.18)
for x in (-0.05, 0.05):
    for z in (-0.05, 0.05):
        shelter.limb(shed + V(x, 0, z), shed + V(x, 0.1, z), 0.005, dark)
with shelter.placed(T(shed)):
    shelter.gable_roof(0.13, 0.13, 0.1, 0.06, thatch, overhang=0.008)
made(field, rows, ears, stooks, hedge, oak, shelter)

# Close: the scarecrow, a sack for its head and a hat on that.
scarecrow = Piece("scarecrow", site, fine=True)
post = V(0.1, 0, 0)
scarecrow.limb(post, post + V(0, 0.3, 0), 0.006, dark)
scarecrow.limb(post + V(-0.07, 0.245, 0), post + V(0.07, 0.245, 0), 0.005, dark)
scarecrow.cube(post + V(0, 0.21, 0), (0.06, 0.075, 0.028), wool)
for side in (-1, 1):
    scarecrow.limb(post + V(side * 0.028, 0.243, 0), post + V(side * 0.062, 0.238, 0), 0.011, wool, sides=5)
    with scarecrow.placed(T(post + V(side * 0.062, 0.238, 0)) @ RZ(-side * math.pi / 2)):
        scarecrow.cone(4, 0.009, 0.02, straw)
scarecrow.sphere(post + V(0, 0.272, 0), 0.02, linen, rings=3, sides=6)
with scarecrow.placed(T(post + V(0, 0.286, 0))):
    scarecrow.lathe([(0.034, 0.0), (0.034, 0.004), (0.016, 0.006), (0.014, 0.03), (0.0, 0.032)], 7, leather)

# The handcart, turned along the field's edge, its handles west, behind the
# stooks (the game set it among two of them), its jug by it.
cart = Piece("handcart", site, fine=True)
with cart.placed(T(-0.05, 0, 0.67) @ RY(math.pi / 2)):
    cart.box((-0.06, 0.055, -0.07), (0.06, 0.085, 0.07), pale)
    for x in (-0.075, 0.075):
        cart.wheel((x, 0.045, 0), 0.045, 0.012, 3, timber, rim=dark)
        cart.limb((x * 0.6, 0.075, -0.07), (x * 0.6, 0.04, -0.17), 0.005, dark)
    cart.limb((0, 0.06, 0.065), (0, 0, 0.07), 0.005, dark)
    for index, x in enumerate((-0.035, 0.0, 0.035)):
        y = 0.125 if index == 1 else 0.1
        cart.beam((x, y, -0.06), (x, y, 0.06), 0.034, straw, depth=0.03)
with cart.placed(T(0.07, 0, 0.64)):
    cart.lathe([(0.0, 0.0), (0.018, 0.002), (0.022, 0.025), (0.012, 0.045), (0.008, 0.055), (0.01, 0.06), (0.0, 0.059)], 7, jug_clay)

# A scythe against a stook, its blade on the stubble (the game's lay half
# under the ground at the site's heart).
scythe = Piece("scythe", site, fine=True)
heel, top = V(0.36, 0.016, 0.56), V(0.43, 0.24, 0.5)
scythe.limb(heel, top, 0.004, timber)
for t in (0.35, 0.7):
    grip = heel + (top - heel) * t
    scythe.limb(grip, grip + V(0.0, 0.006, 0.025), 0.003, timber, sides=3)
scythe.sheet([(0.36, 0.02, 0.56), (0.3, 0.018, 0.552), (0.26, 0.014, 0.535), (0.31, 0.024, 0.559)], (0.05, 1, 0.2), steel,
             thickness=0.002)

# Crows come for the grain: one on a row, one on the stubble, on its feet
# (the game's stood a little under the ground).
crows = Piece("crows", site, fine=True)
raven(crows, (-0.3, 0.09, -0.165), 0.8, 281)
raven(crows, (0.33, 0.01, 0.47), 2.6, 282)
made(scarecrow, cart, scythe, crows)

# MARK: The stand of timber

site = "timber"
firs = Piece("firs", site)
for index, (at_point, scale) in enumerate((((-0.3, 0, -0.25), 1.25), ((0.05, 0, -0.4), 1.4), ((0.35, 0, -0.22), 1.2),
                                           ((-0.46, 0, 0.08), 1.1), ((0.44, 0, 0.16), 1.15), ((0.3, 0, -0.48), 0.95))):
    tall_fir(firs, at_point, scale, 500 + index)
for index, at_point in enumerate(((-0.08, 0, -0.26), (0.2, 0, -0.3), (-0.36, 0, -0.06))):
    fir(firs, at_point, 0.45 + 0.1 * index)

birches = Piece("birches", site)
for at_point in ((0.5, 0, -0.06), (-0.52, 0, 0.3)):
    birch(birches, T(at_point) @ S(0.9))

undergrowth = Piece("undergrowth", site)
for index, at_point in enumerate(((-0.2, 0, -0.12), (0.12, 0, -0.16), (0.4, 0, 0.0), (-0.4, 0, -0.38), (0.2, 0, -0.5))):
    (fern if index % 2 == 0 else heather)(undergrowth, at_point, 520 + index)

# Stumps on their roots, a felled trunk, the pile of logs between its
# posts and an axe left in a stump.
felling = Piece("felling", site)
STUMPS = (V(-0.08, 0, -0.08), V(0.18, 0, 0.0), V(-0.22, 0, 0.22))
for at_point in STUMPS:
    with felling.placed(T(at_point)):
        felling.lathe([(0.05, -0.04), (0.042, 0.0), (0.036, 0.04)], 7, bark, bands=[bark, bark, pale])
    for root in range(3):
        angle = root * 2.1 + at_point.x * 9
        felling.limb(at_point + V(0, 0.01, 0), at_point + ring(0.075, -0.01, angle), 0.012, bark, top=0.004, sides=4)
TRUNK = (V(-0.05, 0.03, 0.12), V(0.38, 0.03, 0.42))
felling.log(TRUNK[0], TRUNK[1], 0.03)
logs = Piece("log pile", site)
for index in range(8):
    layer = 0 if index < 4 else (1 if index < 7 else 2)
    slot = index if index < 4 else (index - 4 if index < 7 else 0)
    y, z = 0.025 + layer * 0.042, 0.28 + slot * 0.05 + layer * 0.025
    logs.log((-0.45, y, z), (-0.15, y, z), 0.024)
for z in (0.26, 0.45):
    logs.limb((-0.47, 0, z), (-0.47, 0.1, z), 0.008, dark)
axe = Piece("axe", site)
axe.beam((0.18, 0.04, 0.0), (0.24, 0.13, 0.05), 0.012, pale)
axe.cube((0.185, 0.045, 0.004), (0.012, 0.03, 0.05), iron, turn=0.6)

# The woodcutters' shelter: poles leant to a ridge, crossed over it, roofed
# in two slopes of bark open at their ends (the game closed it, its poles
# hidden within), out past the felled trunk's end (the game's stood within
# the lowest boughs of the fir beside it).
hut = Piece("bark shelter", site)
HUT = V(0.43, 0, 0.52)
for x in (-0.06, 0.06):
    for z in (-0.05, 0.05):
        foot, ridge = HUT + V(x, 0, z), HUT + V(x * 0.9, 0.12, 0)
        hut.limb(foot, foot + (ridge - foot) * 1.2, 0.005, dark)
w, d = 0.15 / 2 + 0.006, 0.11 / 2 + 0.006
for side in (1, -1):
    eave, peak = HUT + V(0, 0, side * d), HUT + V(0, 0.12, 0)
    normal = V(0, d, side * 0.12).normalized()
    # The north slope a little longer, so the two don't end in one plane.
    hut.beam(eave - normal * 0.004, peak - normal * 0.004, 2 * w + (0.004 if side < 0 else 0.0), bark, depth=0.008)

# A sledge for hauling, a log on it, clear of the felled trunk (the game's
# ran into it).
sledge = Piece("sledge", site)
with sledge.placed(T(0.08, 0, 0.355) @ RY(0.5)):
    for z in (-0.03, 0.03):
        sledge.box((-0.08, 0, z - 0.005), (0.08, 0.012, z + 0.005), dark)
    sledge.box((-0.06, 0.012, -0.035), (0.06, 0.02, 0.035), timber)
    sledge.log((-0.07, 0.04, 0), (0.07, 0.04, 0), 0.02)

# A charcoal clamp under its turf at the stand's edge, smoke seeping from
# its crown (the game's swallowed a fir's foot and a clump of heather).
clamp = Piece("charcoal clamp", site)
with clamp.placed(T(-0.52, 0, -0.2)):
    clamp.lathe([(0.1, 0.0), (0.09, 0.04), (0.05, 0.08), (0.0, 0.095)], 9, loam)
    clamp.lathe([(0.012, 0.09), (0.0, 0.1)], 5, soot)
made(firs, birches, undergrowth, felling, logs, axe, hut, sledge, clamp)

# Close: the stubs of branches lopped from the felled trunk, their greenery
# heaped, and chips about the stumps, lying on the ground.
lopped = Piece("lopping", site, fine=True)
start, end = TRUNK
for index, t in enumerate((0.2, 0.42, 0.6, 0.8)):
    flank = 1 if index % 2 == 0 else -1
    p = start + (end - start) * t
    out = (end - start).normalized().cross(V(0, 1, 0)) * (0.028 * flank) + V(0, 0.012, 0)
    lopped.limb(p, p + out * 1.6, 0.007, bark, top=0.006, sides=4)
for index, angle in enumerate((0.2, 1.4, 2.5, 3.5, 4.6)):
    p = V(0.15, 0.008, -0.11) + ring(0.012 * (index % 3), 0, angle)
    lopped.limb(p, p + ring(0.07, 0.03, angle), 0.014, fir_green if index % 2 == 0 else fir_dark, top=0.002, sides=4)
for stump, at_point in enumerate(STUMPS):
    for chip in range(6):
        angle = chip * 1.05 + stump * 0.7
        centre = at_point + ring(0.055 + 0.015 * unit(chip, stump, 293), GROUND, angle)
        a, c = ring(0.008, 0, angle + 0.4), ring(0.006, 0, angle + 2.1)
        lopped.face([centre + a, centre + c, centre - a, centre - c], (0, 1, 0), pale)

# The sawhorse and its log, the saw standing in its cut, sawdust under it.
sawing = Piece("sawhorse", site, fine=True)
horse = V(0.0, 0, 0.47)
for x in (-0.05, 0.05):
    for z in (-0.04, 0.04):
        # Each crossed pair a hair apart where they cross.
        x_leg = x + (0.0015 if z > 0 else -0.0015)
        sawing.limb(horse + V(x_leg, 0, z), horse + V(x_leg, 0.09, -z * 0.75), 0.005, timber, sides=3)
sawing.log(horse + V(-0.12, 0.085, 0), horse + V(0.13, 0.085, 0.005), 0.022)
sawing.sheet([horse + V(0.08, 0.075, -0.06), horse + V(0.08, 0.075, 0.06), horse + V(0.08, 0.1, 0.06), horse + V(0.08, 0.1, -0.06)],
             (1, 0, 0), steel, thickness=0.002)
for z in (-0.075, 0.075):
    sawing.limb(horse + V(0.08, 0.075, z), horse + V(0.08, 0.125, z), 0.005, dark)
with sawing.placed(T(horse + V(0, GROUND - 0.006, 0))):
    sawing.lathe([(0.055, 0.0), (0.0, 0.012)], 7, pale)

# A maul by the log pile.
maul = Piece("maul", site, fine=True)
maul.limb((-0.38, 0.012, 0.24), (-0.29, 0.012, 0.245), 0.005, timber)
maul.cube((-0.39, 0.016, 0.24), (0.02, 0.026, 0.04), iron)
made(lopped, sawing, maul)

# MARK: The outcrop

site = "stone"


def cut(obj, hollows, mat):
    """The piece with each hollow (a box, by its low and high corners in the
    world's axes) cut out of it, the faces the cut lays bare in `mat`, and
    cut into triangles. The exact boolean makes the same faces every run;
    they are cut into triangles as they come, for common.settle's restarting
    of each at its least corner turns some of the cut's hollow faces over."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(obj.data)
    bm.free()
    for index, (low, high) in enumerate(hollows):
        cutter = block("hollow %d" % index, low, high, mat)
        modifier = obj.modifiers.new("cut", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.material_mode = "TRANSFER"
        modifier.object = cutter
        select_only(obj)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
    bm.to_mesh(obj.data)
    bm.free()
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


# The faces cut back in steps into the greatest mass, each a step higher,
# further back and narrower than the last (the game's lay within the rock,
# its front swelling over them, so little of them showed): the rock is cut
# away above and before each, the cut a little behind each step's face and
# below its top, so the steps' own faces show, and the cut's cheeks and its
# back wall above the highest step are bare stone.
STEPS = [((-0.28 + step * 0.04, -0.04 - 0.002 * step, -0.08 - step * 0.05), (0.2 - step * 0.04, step * 0.07 + 0.06, -0.02 - step * 0.05))
         for step in range(3)]
E = 0.004
HOLLOWS = [((STEPS[0][0][0] + E, 0.0, STEPS[0][1][2] - E), (STEPS[0][1][0] - E, 1.0, 1.0))]
for step, ((x0, _, z0), (x1, top, _)) in enumerate(STEPS):
    back = STEPS[step + 1][1][2] if step + 1 < len(STEPS) else z0
    HOLLOWS.append(((x0 + E, top - E, back - E), (x1 - E, 1.0, 1.0)))
ridge = Piece("ridge", site)
ridge.rock((0, 0.12, -0.24), (0.44, 0.3, 0.24), 101, rock_grey, rings=8, sides=16, jitter=0.18)
cut(ridge.make(), HOLLOWS, stone)

outcrop = Piece("outcrop", site)
outcrop.rock((-0.38, 0.08, -0.12), (0.18, 0.18, 0.2), 103, dark_stone, rings=6, sides=12, jitter=0.22)
outcrop.rock((0.36, 0.06, -0.02), (0.17, 0.13, 0.16), 102, dark_stone, rings=6, sides=12, jitter=0.25)
for low, high in STEPS:
    outcrop.box(low, high, pale_stone)
# The strata in bands at the game's heights, laid bare across the cut's
# faces, standing a little proud of them from cheek to cheek (the game's
# lay along the face the rock now has cut away, within it).
for band in range(4):
    y = 0.08 + band * 0.055
    # The face it crosses: the front of the first step higher than it, or
    # the back wall over the highest; the hollow before that face.
    face = next(index for index, (_, (_, top, _)) in enumerate(STEPS) if top > y) if y < STEPS[-1][1][1] else len(STEPS)
    x0, x1, z = HOLLOWS[face][0][0], HOLLOWS[face][1][0], HOLLOWS[face][0][2] + E
    outcrop.box((x0 - 0.01, y - 0.0055, z - 0.006), (x1 + 0.01, y + 0.0055, z + 0.006), stone if band % 2 == 0 else slate)

floor = Piece("quarry floor", site)
floor.blocks((-0.15, 0, 0.2), 8, 17)
floor.blocks((0.15, 0, 0.28), 6, 18)
floor.blocks((-0.34, 0, 0.3), 4, 19)
SLEDGE = T(0.38, 0, 0.32) @ RY(0.6)
with floor.placed(SLEDGE):
    for x in (-0.035, 0.035):
        floor.box((x - 0.008, 0, -0.07), (x + 0.008, 0.016, 0.07), dark)
    floor.box((-0.05, 0.016, -0.06), (0.05, 0.026, 0.06), timber)
    floor.cube((0, 0.05, 0), (0.06, 0.045, 0.05), pale_stone)

# Sheerlegs over the cut, a block slung from them.
sheerlegs = Piece("sheerlegs", site)
head = V(-0.04, 0.34, -0.02)
for x, z in ((-0.14, 0.06), (0.06, 0.06), (-0.04, -0.12)):
    sheerlegs.limb((x, 0, z), head, 0.007, grey)
sheerlegs.limb(head, head + V(0, -0.18, 0), 0.002, linen)
sheerlegs.cube(head + V(0, -0.2, 0), (0.05, 0.035, 0.035), pale_stone)

# The quarrymen's lean-to against the eastern mass, slates on boards.
lean_to = Piece("lean-to", site)
lean = V(0.3, 0, 0.14)
for x in (-0.06, 0.06):
    lean_to.limb(lean + V(x, 0, 0.05), lean + V(x, 0.1, 0.05), 0.005, dark)
# Its roof one slab, slates above and boards beneath (the game's were two
# loose sheets a hair apart, open at their edges).
top = [lean + V(-0.08, 0.1, 0.07), lean + V(0.08, 0.1, 0.07), lean + V(0.08, 0.14, -0.06), lean + V(-0.08, 0.14, -0.06)]
under = [p - V(0, 0.005, 0) for p in top]
lean_to.quad(top[0], top[1], top[2], top[3], slate)
lean_to.quad(under[3], under[2], under[1], under[0], dark)
for i in range(4):
    j = (i + 1) % 4
    lean_to.quad(under[i], under[j], top[j], top[i], dark)

# Scree and boulders tumbled about its flanks, heather between.
scree = Piece("scree", site)
for index in range(26):
    angle = math.pi * (0.85 + 1.3 * index / 25)
    p = V(0, 0, -0.18) + ring(0.4 + 0.06 * unit(index, 5, 107), 0, angle)
    size = 0.02 + 0.03 * unit(index, 9, 107)
    scree.rock(p + V(0, size * 0.4, 0), (size, size * 0.7, size), 110 + index, pale_stone if index % 3 == 0 else rock_grey, rings=3,
               sides=7, jitter=0.3)
growth = Piece("heather", site)
for index, at_point in enumerate(((-0.46, 0, 0.08), (0.48, 0, 0.14), (-0.2, 0, -0.5), (0.24, 0, -0.46))):
    heather(growth, at_point, 130 + index)
made(outcrop, floor, sheerlegs, lean_to, scree, growth)

# Close: the chisel's marks down the cut faces.
marks = Piece("chisel marks", site, fine=True)
for step in range(3):
    front, top = -0.02 - step * 0.05 + 0.0012, step * 0.07 + 0.06
    left, right = -0.28 + step * 0.04, 0.2 - step * 0.04
    for index in range(5):
        x = left + (right - left) * (index + 0.5) / 5 + 0.01 * (unit(index, step, 301) - 0.5)
        marks.quad((x - 0.0015, top - 0.075, front), (x + 0.0015, top - 0.075, front), (x + 0.0015, top - 0.005, front),
                   (x - 0.0015, top - 0.005, front), stone)
# The split along the lowest step's top (a little further above it than the
# game's hair), its wedges and their hammer, and a pick leant on the floor.
marks.quad((-0.24, 0.061, -0.052), (-0.24, 0.061, -0.048), (0.16, 0.061, -0.048), (0.16, 0.061, -0.052), soot)
tools = Piece("quarry tools", site, fine=True)
for x in (-0.16, -0.06, 0.04, 0.12):
    tools.cube((x, 0.068, -0.05), (0.012, 0.018, 0.008), iron)
tools.cube((-0.3, 0.012, 0.0), (0.045, 0.024, 0.026), iron)
with tools.placed(T(0.24, 0.0, 0.06) @ RZ(0.5)):
    tools.cube((0, 0.15, 0), (0.09, 0.012, 0.012), iron)
    tools.limb((0, 0, 0), (0, 0.15, 0), 0.005, timber)
tools.limb((-0.3, 0.012, 0.0), (-0.27, 0.11, -0.06), 0.005, timber)
# Rubble at the face's foot, a bucket by it.
for index, at_point in enumerate(((-0.22, 0.01, 0.03), (-0.12, 0.01, 0.05), (0.05, 0.01, 0.04), (0.12, 0.01, 0.06))):
    tools.rock(at_point, (0.022, 0.012, 0.018), index + 305, pale_stone if index % 2 == 0 else stone, rings=2, sides=5, jitter=0.25)
with tools.placed(T(0.02, 0, 0.12)):
    tools.lathe([(0.0, 0.0), (0.02, 0.0), (0.024, 0.04), (0.0, 0.041)], 7, pale)
    tools.tube([(0.025, 0.032), (0.025, 0.037)], 7, iron)
# A rope coiled on the sledge's block (the game's lay through it) and a bar
# laid by it.
with tools.placed(SLEDGE):
    with tools.placed(T(0.0, 0.0795, 0.0)):
        tools.tube([(0.024, -0.007), (0.03, 0.0), (0.024, 0.007)], 9, straw)
    tools.limb((-0.035, 0.03, -0.05), (0.03, 0.03, -0.045), 0.004, iron)
made(marks, tools)

# MARK: The moonsalt pans

site = "moonsalt"
# The salt flat and all that lies on it raised a little above the ground at
# the site's heart, as the grain field's loam is (the game's flat lay under
# it); what stands on it stands as it did.
LIFT = GROUND - 0.004
flat = Piece("salt flat", site)
flat.box((-0.5, -0.08, -0.4), (0.5, GROUND, 0.4), saltflat)
pans = Piece("pans", site)
for index, at_point in enumerate(((-0.25, 0, -0.18), (0.05, 0, -0.18), (0.35, 0, -0.18), (-0.25, 0, 0.12), (0.05, 0, 0.12))):
    pans.salt_pan(V(at_point) + V(0, LIFT, 0), 0.26, 0.95 if index % 2 == 0 else 0.7)
spars = Piece("moonsalt", site)
crystals(spars, (0.36, 0, 0.14), 7, 0.17, 23)
crystals(spars, (-0.42, 0, 0.32), 5, 0.12, 24)
crystals(spars, (0.44, 0, -0.34), 6, 0.1, 25)
crystals(spars, (-0.1, 0, -0.33), 4, 0.08, 26)
spars.salt_heap((0.2, 0, 0.32), 0.08, 0.09)
spars.salt_heap((-0.08, 0, 0.34), 0.06, 0.07)

# A rake by a heap; walkways of planks between the pans.
works = Piece("walkways", site)
works.beam((0.42, 0.0, 0.36), (0.3, 0.2, 0.3), 0.012, pale)
works.cube((0.3, 0.2, 0.3), (0.08, 0.012, 0.02), pale, turn=0.4)
for z in (-0.03, 0.27):
    for index in range(6):
        works.cube((-0.4 + index * 0.15, 0.01 + LIFT, z), (0.13, 0.008, 0.035), pale if index % 2 == 0 else grey, turn=0.03 * (index % 2))

# The rakers' hut of driftwood under reeds, clear of the pans (the game's
# stood in the corner of one, its door opening onto the brine), its rakes
# leant at its door.
hut = Piece("rakers' hut", site)
HUT = V(-0.465, 0, -0.3)
hut.box(HUT + V(-0.07, 0, -0.05), HUT + V(0.07, 0.08, 0.05), grey)
with hut.placed(T(HUT)):
    hut.gable_roof(0.16, 0.12, 0.08, 0.05, reed_thatch, overhang=0.01)
hut.cube(HUT + V(0.02, 0.035, 0.051), (0.03, 0.06, 0.003), dark)
for index, x in enumerate((-0.05, -0.035)):
    hut.limb(HUT + V(x, 0, 0.07), HUT + V(x + 0.01, 0.13, 0.052), 0.003, pale)
    hut.cube(HUT + V(x, GROUND + 0.004 + 0.003 * index, 0.075), (0.04, 0.008, 0.006), dark, turn=index * 0.2)

# The rakers' barrow, a heap on it, its wheel on an axle across it (the
# game's stood broadside to it), standing on the flat.
barrow = Piece("barrow", site)
with barrow.placed(T(-0.22, GROUND, 0.36) @ RY(0.8)):
    barrow.box((-0.03, 0.02, -0.022), (0.035, 0.05, 0.022), grey)
    barrow.wheel((0.045, 0.018, 0), 0.018, 0.006, 3, timber, rim=dark, turn=math.pi / 2)
    for z in (-0.018, 0.018):
        barrow.beam((0.04, 0.03, z), (-0.08, 0.04, z), 0.004, dark)
    barrow.salt_heap((0, 0.05, 0), 0.025, 0.02)

# Sluice boards holding back the brine at the shore's edge, reeds along it.
shore = Piece("shore", site)
for index in range(5):
    x = -0.45 + index * 0.22
    shore.limb((x, -0.02, -0.43), (x, 0.05, -0.43), 0.008, dark)
    if index < 4:
        shore.cube((x + 0.11, 0.025, -0.43), (0.21, 0.04, 0.008), grey)
for index in range(5):
    reeds(shore, (-0.5 + index * 0.25, 0, -0.5), 5, 0.1, 160 + index)
made(flat, pans, spars, works, hut, barrow, shore)

# Close: baskets of salt, a wheelbarrow at the hut's door (the game set it
# on the barrow), a shovel thrust in a heap, its blade showing at the crown
# (the game's lay wholly within), sacks filled from it and a pusher laid
# across a pan.
gear = Piece("salters' gear", site, fine=True)
for index, x in enumerate((0.04, 0.1)):
    with gear.placed(T(x, GROUND, 0.37 + 0.03 * index)):
        gear.lathe([(0.0, 0.0), (0.022, 0.003), (0.027, 0.035)], 7, straw)
        gear.cone(6, 0.024, 0.05, salt, bottom=0.03)
with gear.placed(T(-0.445, GROUND, -0.14)):
    gear.lathe([(0.03, 0.03), (0.05, 0.07), (0.0, 0.07)], 4, timber, twist=math.pi / 4)
    gear.cone(6, 0.04, 0.085, salt, bottom=0.065)
    gear.wheel((0, 0.025, 0.07), 0.025, 0.01, 2, dark)
    for x in (-0.022, 0.022):
        gear.limb((x, 0.05, 0.06), (x, 0.06, -0.11), 0.004, dark)
        gear.limb((x, 0.035, -0.02), (x, 0, -0.03), 0.004, dark)
DIG = V(0, 0.06, 0)
gear.limb(V(0.2, 0.03, 0.32) + DIG, V(0.24, 0.2, 0.36) + DIG, 0.004, timber)
gear.sheet([V(0.185, 0.0, 0.31) + DIG, V(0.215, 0.0, 0.33) + DIG, V(0.21, 0.045, 0.335) + DIG, V(0.19, 0.045, 0.32) + DIG],
           (0.6, 0.2, -0.7), iron, thickness=0.003)
gear.tied_sack((0.3, GROUND, 0.4), 0.9)
gear.tied_sack((0.33, GROUND, 0.35), 0.8)
# The pusher lies on the pan's crust (the game's hung a little over it).
gear.beam((0.0, 0.031, 0.12), (0.11, 0.031, 0.12), 0.018, pale, depth=0.012)
gear.limb((0.055, 0.036, 0.12), (0.12, 0.08, 0.22), 0.004, timber)
made(gear)

finish_building(out_path("Art/models/sites.glb"), SITES)
