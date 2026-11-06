"""The land's marks, each a variant of one file:
- the standard, an alliance's: a tall pole on a cairn over a stepped plinth
  of dressed stone, a crossbar and a long swallow-tailed banner in the
  alliance's colour, a stele of dark stone behind it with the alliance's
  oath in panels and its shield, torches on posts and lesser banners about
  it, a war horn on its post, guard posts either side of the way and
  braziers at its foot; close, guy ropes to pegs, the banner bound to its
  crossbar, shields leant against the cairn, two spears crossed behind the
  pole and the braziers on three legs each;
- the rally camp, a rally's war camp at its muster: tents about its edge,
  horse lines along its back, a rack of spears, a tall war pole flying the
  caller's banner over a pennon, a great war drum on its trestle with its
  beaters across it, and a fire in a ring of stones; close, guy ropes on the
  war pole, a horn on its post, a rack of spears with shields leant against
  it and logs stacked by the fire;
- the host banner, borne at a rally host's head: a tall staff, a gilt
  finial over a long swallow-tailed banner and two streamers under it;
- the Drowned Crown: a band of tarnished gold green with the lake, seven
  tines each set with a stone of moonsalt, circlets of pearls, studs and a
  chased line along the band, weed trailing from its rim, barnacles on its
  lip, rotted velvet within and a great stone at its heart, a halo of
  moonlight turning about it and the lake's water dripping from its tines;
- the listening stone: a rough standing stone on a cairn in the water,
  veined with moonsalt, a cord of salt-white about its waist, a glow at its
  crown and rings of ripple turning out about it;
- the pedlar's skiff: a narrow hull of tarred planks with a high carved
  prow, a patched awning on four poles hung with three lanterns, crates,
  jars, a chest bound in iron and bolts of dyed cloth, and the pedlar in
  his hooded cloak at the stern on his pole.
Each faces +z, standing on y = 0 (the skiff's deck at the waterline).

The standard's torches and braziers burn, the camp's fire leaps and its
drum's beaters rise and fall, the crown's halo turns and its drips rock,
the stone's ripples turn, the skiff's lanterns flicker and its pedlar
works his pole: each as the game's Machinery moved it.

    python Art/blender/marks.py Art/models/marks.glb

Built as the game's Land built them in code (Sources/NullmereModels/
Land.swift), solid for solid: the Shape below lays triangles as the game's
MeshBuilder does, in the world's axes and units, and writes them into
Blender's at ten times that. Where the game's pieces were buried, floating,
inside one another, mis-turned or never placed, they are set right here;
each such place says so.
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
MARKS = ["standard", "rallyCamp", "hostBanner", "drownedCrown", "listeningStone", "pedlarSkiff"]
# The marks that move; the host banner stands still.
MOVING = [mark for mark in MARKS if mark != "hostBanner"]

# MARK: Materials

stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
white_stone = material("plain_stone_white", (0.84, 0.84, 0.82))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark_timber = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale_timber = material("plain_timber_pale", (0.45, 0.37, 0.28))
earth = material("plain_earth", (0.24, 0.21, 0.18))
linen = material("plain_linen", (0.7, 0.67, 0.6))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
bone = material("plain_bone", (0.8, 0.78, 0.7))
leather = material("plain_leather", (0.36, 0.25, 0.17))
dark_leather = material("plain_leather_dark", (0.22, 0.16, 0.12))
soot = material("plain_soot", (0.11, 0.1, 0.1))
hair = material("plain_hair", (0.21, 0.17, 0.14))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.4, metallic=0.8)
house = material("house_roof", (0.78, 0.78, 0.78))
banner = material("cloth_banner", (0.78, 0.78, 0.78))
fire = material("glow_fire", (1.0, 0.68, 0.32))
candle = material("glow_candle", (1.0, 0.8, 0.52))
moonglow = material("glow_moonglow", (0.72, 0.86, 1.0))
moonsalt_glow = material("glow_moonsalt", (0.88, 0.91, 0.95))
# The camp's horses, in the palette's coats (Art.buildingColours has them).
bay = material("plain_horse_bay", (0.36, 0.23, 0.15))
grey_coat = material("plain_horse_grey", (0.62, 0.62, 0.62))
black_coat = material("plain_horse_black", (0.13, 0.12, 0.12))
# Colours the game mixed from its palette, each named for what it is.
rope = material("plain_guyrope", (0.53, 0.46, 0.385))  # linen mixed half with leather
horn_pale = material("plain_cowhorn", (0.598, 0.544, 0.471))  # linen, a third leather
crown_gold = material("plain_crowngold", (0.68, 0.5535, 0.299))  # gold, a third bronze
verdigris = material("plain_verdigris", (0.364, 0.442, 0.332))  # bronze gone green
lake_weed = material("foliage_lakeweed", (0.13, 0.24, 0.17))
moss_weed = material("foliage_mossweed", (0.162, 0.248, 0.19))  # the weed, a share moss
pearl = material("plain_pearl", (0.816, 0.844, 0.856))  # white stone, a fifth moonglow
stud_salt = material("plain_moonsalt", (0.88, 0.91, 0.95))
velvet = material("plain_velvet", (0.2585, 0.163, 0.1405))  # madder rotted half black
drip = material("crystal_drip", (0.426, 0.488, 0.568), roughness=0.1)  # slate, two fifths moonglow
vein = material("crystal_moonglow", (0.72, 0.86, 1.0), roughness=0.1)
ripple = material("glow_ripple", (0.475, 0.55, 0.64))  # moonglow mixed half with slate
tar = material("plain_tar", (0.106, 0.086, 0.08))  # dark timber tarred
awning_cloth = material("plain_awning", (0.547, 0.481, 0.4065))  # linen, near half leather
awning_patch = material("plain_awningpatch", (0.6125, 0.4915, 0.453))  # linen, a third red
crate_wood = material("plain_timber_crate", (0.25, 0.182, 0.134))  # timber, two fifths dark
crimson = material("plain_crimson", (0.45, 0.16, 0.18))
blue_cloth = material("plain_bluecloth", (0.426, 0.488, 0.568))  # moonglow, three fifths slate
lantern_glow = material("glow_lantern", (0.925, 0.662, 0.32))  # fire, a third gold
cloak = material("plain_cloak", (0.12, 0.11, 0.14))
hood_cloth = material("plain_hood", (0.1, 0.09, 0.12))


# MARK: The game's chance, so its stones fall as they did

def noise(x, y, seed):
    """Noise.unit: from 0 up to 1 for a lattice point, the same as the game's."""
    m = 0xFFFFFFFF
    h = ((x & m) * 0x8DA6B343 & m) ^ ((y & m) * 0xD8163841 & m) ^ ((seed & m) * 0xCB1AB31F & m)
    h ^= h >> 13
    h = h * 0x5BD1E995 & m
    h ^= h >> 15
    return (h >> 8) / float(1 << 24)


# MARK: Solids laid as the game's MeshBuilder lays them

def V(x, y, z):
    return Vector((x, y, z))


UP, X, Z = (0.0, 1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)


def ring(radius, y, angle):
    """MeshBuilder.ring: a point about the upright, from +x toward -z."""
    return V(radius * math.cos(angle), y, -radius * math.sin(angle))


def round_point(radius, y, angle):
    """A point about the upright as the game's crown and stone count them:
    from +z toward +x."""
    return V(radius * math.sin(angle), y, radius * math.cos(angle))


def shift(p):
    return Matrix.Translation(Vector(p))


def turn_x(angle):
    return Matrix.Rotation(angle, 4, "X")


def turn_y(angle):
    return Matrix.Rotation(angle, 4, "Y")


def turn_z(angle):
    return Matrix.Rotation(angle, 4, "Z")


def aligning_up(direction):
    """Mat4.aligningUp: the turn that carries straight up onto `direction`."""
    d = Vector(direction).normalized()
    axis = Vector(UP).cross(d)
    cosine = max(-1.0, min(1.0, d.y))
    if axis.length < 1e-6:
        return Matrix.Identity(4) if cosine > 0 else turn_x(math.pi)
    return Matrix.Rotation(math.acos(cosine), 4, axis.normalized())


BOX_FACES = {"east": ((1, 0, 1), (1, 0, 0), (1, 1, 0), (1, 1, 1)), "west": ((0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)),
             "top": ((0, 1, 1), (1, 1, 1), (1, 1, 0), (0, 1, 0)), "bottom": ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)),
             "south": ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)), "north": ((1, 0, 0), (0, 0, 0), (0, 1, 0), (1, 1, 0))}


class Shape:
    """Triangles gathered in the world's axes and units as the game's
    MeshBuilder lays them: each solid placed by the placements it is built
    within, each triangle wound counter-clockwise seen from outside (put
    back so under a mirroring placement), those of no area left out; how far
    each corner moves in the wind, by its place in its solid's own frame as
    the game's swayRange has it, or by its place in the world."""

    def __init__(self):
        self.faces = []
        self.transform = Matrix.Identity(4)
        self.sway = 0.0
        self.sway_range = None
        self.sway_world = None

    @contextmanager
    def place(self, placement):
        saved = self.transform
        self.transform = saved @ placement
        try:
            yield self
        finally:
            self.transform = saved

    @contextmanager
    def swaying(self, sway=1.0, sway_range=None, sway_world=None):
        saved = (self.sway, self.sway_range, self.sway_world)
        self.sway, self.sway_range, self.sway_world = sway, sway_range, sway_world
        try:
            yield self
        finally:
            self.sway, self.sway_range, self.sway_world = saved

    def sway_at(self, local, world):
        if self.sway_world is not None:
            return max(0.0, min(1.0, self.sway_world(world)))
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
        self.faces.append(((pa, pb, pc), mat, (self.sway_at(a, pa), self.sway_at(b, pb), self.sway_at(c, pc))))

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

    def box(self, low, high, mat, skip=()):
        """A box between two corners, its faces as the game lays them; those
        named in `skip` (hidden in another solid) left off."""
        corner = (Vector(low), Vector(high))
        for name, quad in BOX_FACES.items():
            if name not in skip:
                self.quad(*[V(corner[x].x, corner[y].y, corner[z].z) for x, y, z in quad], mat)

    def box_at(self, centre, size, mat, turn=0.0, skip=()):
        """A box about its centre, turned about the upright as the game's
        box(center:size:turn:)."""
        with self.place(shift(centre) @ turn_y(turn)):
            self.box(tuple(-s / 2 for s in size), tuple(s / 2 for s in size), mat, skip)

    def lathe(self, profile, sides, mat, twist=0.0, caps=(True, True)):
        """A solid turned about the upright from its profile, bottom to top,
        its ends capped where they have a radius (but where `caps` says not)."""
        step = 2 * math.pi / sides
        for (r0, y0), (r1, y1) in zip(profile, profile[1:]):
            for side in range(sides):
                a0 = side * step + twist
                a1 = a0 + step
                self.quad(ring(r0, y0, a0), ring(r0, y0, a1), ring(r1, y1, a1), ring(r1, y1, a0), mat)
        if caps[0] and profile[0][0] > 0:
            r, y = profile[0]
            self.polygon([ring(r, y, s * step + twist) for s in reversed(range(sides))], mat)
        if caps[1] and profile[-1][0] > 0:
            r, y = profile[-1]
            self.polygon([ring(r, y, s * step + twist) for s in range(sides)], mat)

    def tube(self, profile, sides, mat, twist=0.0):
        """A lathe's sides without its ends."""
        self.lathe(profile, sides, mat, twist, caps=(False, False))

    def cone(self, sides, radius, bottom, top, mat, twist=0.0, caps=(True, True)):
        self.lathe([(radius, bottom), (0.0, top)], sides, mat, twist, caps)

    def limb(self, a, b, radius, mat, top=None, sides=4, caps=(False, False)):
        """A pole from one point to another, its ends left open for the
        joints to hide (or capped, where `caps` says)."""
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        if length <= 0:
            return
        with self.place(shift(a) @ aligning_up(b - a)):
            self.lathe([(radius, 0.0), (radius if top is None else top, length)], sides, mat, caps=caps)

    def sheet(self, points, normal, thickness, mat):
        """A thin flat thing seen from both sides, as the game's sheet."""
        offset = Vector(normal).normalized() * (thickness / 2)
        self.face([Vector(p) + offset for p in points], normal, mat)
        self.face([Vector(p) - offset for p in points], -Vector(normal), mat)

    def slab(self, points, normal, thickness, mat, edge=None):
        """A sheet closed round its edge, so it reads solid edge on."""
        n = Vector(normal).normalized()
        offset = n * (thickness / 2)
        points = [Vector(p) for p in points]
        self.face([p + offset for p in points], n, mat)
        self.face([p - offset for p in points], -n, mat)
        # The outline's turn about its normal, for each edge's outward side.
        middle = sum(points, Vector()) / len(points)
        turn = sum(((points[i] - middle).cross(points[(i + 1) % len(points)] - middle) for i in range(len(points))), Vector()).dot(n)
        for i in range(len(points)):
            p, q = points[i], points[(i + 1) % len(points)]
            out = (q - p).cross(n) if turn > 0 else n.cross(q - p)
            self.face([p + offset, q + offset, q - offset, p - offset], out, edge or mat)

    def beam(self, a, b, width, mat, depth=None, skip=()):
        """A squared timber from one point to another, as the game's beam."""
        a, b = Vector(a), Vector(b)
        along = b - a
        length = along.length
        if length <= 0:
            return
        up = along / length
        reference = Vector((0, 0, 1)) if abs(up.y) > 0.95 else Vector(UP)
        side = up.cross(reference).normalized()
        front = side.cross(up)
        frame = Matrix(((side.x, up.x, front.x, a.x), (side.y, up.y, front.y, a.y), (side.z, up.z, front.z, a.z), (0, 0, 0, 1)))
        d = width if depth is None else depth
        with self.place(frame):
            self.box((-width / 2, 0, -d / 2), (width / 2, length, d / 2), mat, skip)

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
                row.append(V(centre[0] + d[0] * size[0] * push, centre[1] + d[1] * size[1] * push, centre[2] + d[2] * size[2] * push))
            grid.append(row)
        for band in range(rings):
            for side in range(sides):
                n = (side + 1) % sides
                self.quad(grid[band][side], grid[band][n], grid[band + 1][n], grid[band + 1][side], mat)

    def sphere(self, centre, radius, rings, sides, mat, squash=1.0):
        """A faceted ball, as the game's sphere."""
        profile = []
        for band in range(rings + 1):
            angle = math.pi * band / rings - math.pi / 2
            profile.append((radius * math.cos(angle), radius * squash * math.sin(angle)))
        with self.place(shift(centre)):
            self.lathe(profile, sides, mat)

    def gable_roof(self, width, depth, base, height, mat, overhang=0.0):
        """A roof of two slopes, its ridge east to west, as the game's."""
        w, d, top = width / 2 + overhang, depth / 2 + overhang, base + height
        self.quad((-w, base, d), (w, base, d), (w, top, 0), (-w, top, 0), mat)
        self.quad((w, base, -d), (-w, base, -d), (-w, top, 0), (w, top, 0), mat)
        self.triangle((w, base, d), (w, base, -d), (w, top, 0), mat)
        self.triangle((-w, base, -d), (-w, base, d), (-w, top, 0), mat)
        self.quad((-w, base, -d), (w, base, -d), (w, base, d), (-w, base, d), mat)

    def flag(self, top, width, height, mat, turn=0.0, tail=False):
        """A cloth hung from a pole at `top`, as the game's flag: `width` out
        along +x turned `turn` about the upright, `height` down, moving more
        toward its free end (as the square of the way out); closed round its
        edge, where the game's was two faces."""
        with self.swaying(1.0, (0.0, width)), self.place(shift(top) @ turn_y(turn) @ turn_z(-math.pi / 2)):
            t = max(width * 0.03, 0.004)
            outline = ([V(0, 0, 0), V(0, width, 0), V(height / 2, width * 0.72, 0), V(height, width, 0), V(height, 0, 0)] if tail
                       else [V(0, 0, 0), V(0, width, 0), V(height, width, 0), V(height, 0, 0)])
            self.slab(outline, (0, 0, 1), t, mat)

    def loft(self, points, radii, sides, mat, caps=(False, False), twist=0.0):
        """A round body along a path of points, a ring of `sides` at each
        (its radius there), turned to the path's run; seamless where the
        game's joined limbs end to end."""
        points = [Vector(p) for p in points]
        count = len(points)
        tangents = [(points[min(i + 1, count - 1)] - points[max(i - 1, 0)]).normalized() for i in range(count)]
        reference = Vector(X) if abs(tangents[0].dot(Vector(X))) < 0.9 else Vector(Z)
        u = (reference - tangents[0] * reference.dot(tangents[0])).normalized()
        rings = []
        for i in range(count):
            t = tangents[i]
            u = (u - t * u.dot(t)).normalized()
            v = t.cross(u)
            rings.append([points[i] + (u * math.cos(twist + 2 * math.pi * s / sides) - v * math.sin(twist + 2 * math.pi * s / sides)) * radii[i]
                          for s in range(sides)])
        for i in range(count - 1):
            for s in range(sides):
                n = (s + 1) % sides
                self.quad(rings[i][s], rings[i][n], rings[i + 1][n], rings[i + 1][s], mat)
        if caps[0]:
            self.polygon(list(reversed(rings[0])), mat)
        if caps[1]:
            self.polygon(rings[-1], mat)

    def strip(self, rings_of_points, mat, outward_from=None):
        """Bands between rings of points running counter-clockwise seen
        from above, as a lathe's are, but each ring as it is given."""
        for lower, upper in zip(rings_of_points, rings_of_points[1:]):
            count = len(lower)
            for s in range(count):
                n = (s + 1) % count
                self.quad(lower[s], lower[n], upper[n], upper[s], mat)


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
        if len(set(verts)) < 3 or bm.faces.get(verts) is not None:
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


def piece(name, tags, shape, fine=False):
    """A mark's solids as one piece, drawn for the marks named, near only if `fine`."""
    return make(tagged(name, tags) + ("!fine" if fine else ""), shape)


def flame(at_point, size):
    """Beacon.flame: tongues of flame over coals, its own part to leap."""
    s = Shape()
    at_point = Vector(at_point)
    with s.place(shift(at_point)):
        s.lathe([(size * 0.9, 0.0), (size, size * 0.3), (size * 0.6, size * 0.9), (size * 0.25, size * 1.5), (0.0, size * 2.1)], 7, fire)
    for index in range(4):
        angle = index * 1.6
        side = V(size * 0.55 * math.cos(angle), 0.0, size * 0.55 * math.sin(angle))
        with s.place(shift(at_point + side)):
            s.cone(4, size * 0.35, 0.0, size * 1.3, candle)
    return s


# MARK: Where everything moves

TORCHES = [ring(0.33, 0.0, index / 4 * 2 * math.pi + 0.9) for index in range(4)]
BRAZIERS = [V(x, 0.0, 0.16) for x in (-0.14, 0.14)]
# Where the camp's fire burns (Land.rallyFire: the world sends its smoke up from here).
RALLY_FIRE = V(0.24, 0.135, 0.2)
DRUM = V(-0.26, 0.0, 0.12)
BEATERS = DRUM + V(-0.12, 0.29, 0.0)
# The skiff's lanterns: the two at the awning's front hang a little in from
# its poles (the game's hung them on the poles themselves).
LANTERNS = [V(-0.065, 0.19, 0.2), V(0.065, 0.19, 0.2), V(0.0, 0.2, -0.13)]
STERN = V(0.0, 0.0, -0.27)

# Each fire its own part to leap, as the game's Beacon.flame made them.
FIRES = [("beacon fire %d@standard" % index, foot + V(0, 0.23, 0), 0.022) for index, foot in enumerate(TORCHES)]
FIRES += [("beacon fire %d@standard" % (4 + index), foot + V(0, 0.14, 0), 0.035) for index, foot in enumerate(BRAZIERS)]
FIRES.append(("beacon fire@rallyCamp", V(RALLY_FIRE.x, 0.0, RALLY_FIRE.z), 0.06))
LIGHTS = [("pedlar lantern %d@pedlarSkiff" % index, at_point) for index, at_point in enumerate(LANTERNS)]
TURNING = [("war drum beaters@rallyCamp", BEATERS, Z), ("crown halo@drownedCrown", V(0, 0.14, 0), UP),
           ("crown drips@drownedCrown", V(0, 0, 0), X), ("listening rings@listeningStone", V(0, 0, 0), UP), ("pedlar@pedlarSkiff", STERN, X)]
rig = work_rig([(bone, tuple(p), UP) for bone, p, _ in FIRES] + [(bone, tuple(p), UP) for bone, p in LIGHTS]
               + [(bone, tuple(p), axis) for bone, p, axis in TURNING])


def moving(name, tags, bone, shape, fine=False):
    """A moving part's solids hung on its bone."""
    return on(piece(name, tags, shape, fine), rig, bone)


# MARK: The standard

tag = ["standard"]

# A stepped plinth of dressed stone under the cairn: the rig's ground,
# skinned whole to its base, which is kept only by the marks that move so
# the host banner reads as still. (Its underside, below the ground, left
# off.)
plinth = Shape()
plinth.lathe([(0.3, -0.06), (0.3, 0.0), (0.26, 0.005), (0.26, 0.03), (0.22, 0.035)], 10, pale_stone, caps=(False, True))
BASE = "base@" + ",".join(MOVING)
footing = ground(piece("plinth", tag, plinth), rig)
rig.data.bones["base"].name = BASE
if footing.vertex_groups.get(BASE) is None:
    footing.vertex_groups["base"].name = BASE

far, flags, close = Shape(), Shape(), Shape()
# The alliance's shield on the plinth's face: set down on its lower step
# (the game's floated a hair over it, half in the upper step's face).
with far.place(shift((0, 0.0, 0.27))):
    far.lathe([(0.04, 0.0), (0.04, 0.023)], 8, house, caps=(False, True))
# A stele of dark stone behind the pole, the alliance's oath cut in panels
# down its face and its shield above them. (Its foot is in the plinth and
# its top under its cap: neither face drawn, where the game's lay in
# others'; the panels' and the shield's backs are in its face.)
far.box((-0.08, 0.03, -0.225), (0.08, 0.44, -0.175), slate, skip=("top", "bottom"))
with far.place(shift((0, 0.44, -0.2))):
    far.gable_roof(0.18, 0.07, 0.0, 0.05, dark_stone)
for row in range(5):
    far.box_at((0, 0.08 + row * 0.06, -0.174), (0.12, 0.03, 0.004), dark_stone, skip=("north",))
with far.place(shift((0, 0.39, -0.173)) @ turn_x(math.pi / 2)):
    far.lathe([(0.035, -0.003), (0.035, 0.003)], 10, house, caps=(False, True))
# Torches on posts round the ring's edge, burning.
for foot in TORCHES:
    far.limb(foot, foot + V(0, 0.2, 0), 0.006, dark_timber)
    with far.place(shift(foot + V(0, 0.2, 0))):
        far.lathe([(0.008, 0.0), (0.016, 0.03)], 6, iron)
# The war horn on its post, to call the alliance to the standard: laid on
# the post's top, which is capped (the game's floated over an open post).
far.limb((0.2, 0, 0.08), (0.2, 0.18, 0.08), 0.007, dark_timber, caps=(False, True))
with far.place(shift((0.2, 0.184, 0.08)) @ turn_z(-1.2)):
    far.lathe([(0.004, 0.0), (0.012, 0.08), (0.03, 0.13)], 8, bone)
# Lesser banners of the alliance's Houses set in a ring about it, each on a
# stone, its pole tipped with iron, flying out from the ring (the game's
# were turned against their angle, two of them back in over the cairn).
for index in range(6):
    angle = index / 6 * 2 * math.pi + 0.5
    foot = ring(0.4, 0.0, angle)
    far.rock(foot + V(0, 0.015, 0), (0.03, 0.025, 0.03), 2, 5, 0.2, 140 + index, dark_stone)
    far.limb(foot, foot + V(0, 0.42, 0), 0.006, dark_timber)
    with far.place(shift(foot + V(0, 0.42, 0))):
        far.cone(4, 0.008, 0.0, 0.026, iron)
    flags.flag(foot + V(0, 0.41, 0), 0.1, 0.14, banner, turn=angle, tail=index % 2 == 0)
# A guard post either side of the way, its pyramid cap turned square on it
# (the game's stood corner to face, the post's corners through it), a spear
# planted beside it.
for x in (-0.26, 0.26):
    far.box((x - 0.025, 0.0, 0.175), (x + 0.025, 0.16, 0.225), stone, skip=("top", "bottom"))
    with far.place(shift((x, 0.16, 0.2))):
        far.cone(4, 0.04, 0.0, 0.05, slate, twist=math.pi / 4)
    far.limb((x + 0.04, 0, 0.24), (x + 0.03, 0.3, 0.24), 0.004, timber)
    with far.place(shift((x + 0.03, 0.3, 0.24))):
        far.cone(4, 0.008, 0.0, 0.03, iron)
# The cairn, stones heaped about the pole's foot (what of it was within the
# plinth left off).
far.lathe([(0.18, 0.03), (0.16, 0.06), (0.08, 0.11), (0.0, 0.12)], 7, dark_stone, caps=(False, False))
for index in range(6):
    angle = index / 6 * 2 * math.pi + 0.3
    far.rock(ring(0.17, 0.03, angle), (0.05, 0.04, 0.045), 2, 4, 0.25, index + 120, stone if index % 2 == 0 else pale_stone)
# The pole and its crossbar, a finial of iron at its head; the banner
# hanging from the crossbar in the alliance's colour.
far.limb((0, 0.05, 0), (0, 1.0, 0), 0.016, dark_timber, top=0.011, sides=6)
far.beam((-0.02, 0.92, 0), (0.32, 0.92, 0), 0.014, timber)
with far.place(shift((0, 1.0, 0))):
    far.cone(4, 0.02, 0.0, 0.07, iron)
flags.flag((0.01, 0.91, 0), 0.3, 0.42, banner, tail=True)
# Braziers at its foot, burning in bowls of coals (the game's bowls were
# never set on their posts, but stood twice over at the pole's foot).
for foot in BRAZIERS:
    far.limb(foot + V(0, 0.03, 0), foot + V(0, 0.12, 0), 0.008, iron)
    with far.place(shift(foot)):
        far.lathe([(0.0, 0.11), (0.035, 0.12), (0.04, 0.15)], 6, iron, caps=(False, False))
        far.lathe([(0.0393, 0.146), (0.0, 0.149)], 6, dark_timber)
piece("standard", tag, far)
piece("standard banners", tag, flags)
for part, at_point, size in FIRES:
    if part.endswith("@standard"):
        moving(part.split("@")[0].replace("beacon", "standard"), tag, part, flame(at_point, size))

# Close: guy ropes from its pole to pegs (the one the game ran through the
# stele brought round beside it).
for angle in (1.05, 3.3, 4.9):
    peg = ring(0.44, 0.0, angle)
    close.limb((0, 0.72, 0), peg + V(0, 0.03, 0), 0.002, rope, sides=3)
    close.limb(peg - V(0, 0.01, 0), peg + ring(0.01, 0.04, angle), 0.004, dark_timber, sides=3)
# Its banner bound to its crossbar: straps round the bar and the banner's
# head (the game's rings stood corner to face on the bar, its edges through
# them, and short of the banner).
for x in (0.06, 0.16, 0.26):
    close.box((x - 0.004, 0.902, -0.0075), (x + 0.004, 0.929, 0.0075), dark_leather)
# Shields in the alliance's colour leant against its cairn: each with its
# rim on the plinth and its back on the cairn's shoulder (the game's stood
# half sunk in the plinth, leaning on nothing).
LEAN = 1.0
for angle in (0.82, 2.92, 5.01):
    sector = 2 * math.pi / 7
    face = math.cos(math.pi / 7) / math.cos((angle % sector) - math.pi / 7)
    n = V(math.sin(LEAN), math.cos(LEAN), 0)
    u = V(-math.cos(LEAN), math.sin(LEAN), 0)
    crease = V(0.16 * face, 0.06, 0) + n * 0.002
    reach = 0.045 + (0.035 - crease.y) / math.sin(LEAN)
    middle = crease + u * reach + n * 0.005
    with close.place(shift(ring(middle.x, middle.y, angle)) @ turn_y(angle) @ turn_z(-LEAN)):
        close.lathe([(0.045, -0.005), (0.045, 0.003), (0.0, 0.008)], 8, house)
        close.cone(5, 0.011, 0.007, 0.018, iron)
# Two spears crossed behind its pole, their feet on the plinth's rim either
# side of the stele (the game's ran through it).
for foot_angle, top in ((0.9, V(-0.06, 0.5, -0.02)), (math.pi - 0.9, V(0.06, 0.5, -0.02))):
    foot = ring(0.3, 0.0, foot_angle)
    close.limb(foot, top, 0.005, dark_timber)
    with close.place(shift(top) @ aligning_up(top - foot)):
        close.cone(4, 0.011, 0.0, 0.045, iron)
# Its braziers on three legs each, their feet on the plinth.
for foot in BRAZIERS:
    for leg in range(3):
        angle = leg * 2 * math.pi / 3 + 0.3
        close.limb(foot + V(0, 0.1, 0) + ring(0.012, 0, angle), foot + V(0, 0.03, 0) + ring(0.045, 0, angle), 0.004, iron, sides=3)
piece("standard close", tag, close, fine=True)


# MARK: The rally camp

tag = ["rallyCamp"]
far, flags, close = Shape(), Shape(), Shape()


def horse(shape, at_point, turn, coat):
    """Wayhouse.horse: a little horse tethered, its body closed at its ends."""
    with shape.place(shift(at_point) @ turn_y(turn)):
        shape.limb((-0.025, 0.05, 0), (0.025, 0.05, 0), 0.014, coat, caps=(True, True))
        for x, z in ((-0.02, -0.008), (-0.02, 0.008), (0.02, -0.008), (0.02, 0.008)):
            shape.limb((x, 0.045, z), (x, 0.0, z), 0.004, coat)
        shape.limb((-0.025, 0.055, 0), (-0.04, 0.075, 0), 0.008, coat, top=0.006)
        shape.limb((-0.04, 0.075, 0), (-0.055, 0.065, 0), 0.006, coat, top=0.004, caps=(False, True))
        shape.limb((0.028, 0.055, 0), (0.034, 0.025, 0), 0.003, hair)
        shape.box_at((0, 0.066, 0), (0.02, 0.004, 0.03), dark_leather)


# The host's tents pitched about the camp's edge, each with its pole and
# pennon, its door toward the camp's heart. (The game's were turned against
# their angles, each its own way; and one stood on the horse lines, one on
# the drum and one on the fire's stones: the first is pitched on the camp's
# open side here, the others a little along, a neighbour with them.)
TENTS = [(0.9, canvas), (0.2, linen), (2.3, canvas), (3.9, linen), (4.45, canvas), (5.0, linen)]
SLOPE = math.atan2(0.09 * math.cos(math.pi / 8), 0.16)


def on_tent(across, up_slope, out):
    """A point on a tent's door face (its own +x, the face turned to it),
    `across` along it, `up_slope` up its slope, `out` off it."""
    base = V(0.09 * math.cos(math.pi / 8), 0.0, 0.0)
    along = V(-math.sin(SLOPE), math.cos(SLOPE), 0.0)
    normal = V(math.cos(SLOPE), math.sin(SLOPE), 0.0)
    return base + along * up_slope + V(0, 0, across) + normal * out


for angle, cloth in TENTS:
    placing = shift(ring(0.36, 0.0, angle)) @ turn_y(angle + math.pi)
    with far.place(placing), flags.place(placing):
        # (Its floor, under the camp's, left off.)
        far.cone(8, 0.09, 0.0, 0.16, cloth, twist=math.pi / 8, caps=(False, True))
        far.limb((0, 0.15, 0), (0, 0.24, 0), 0.004, dark_timber, caps=(False, True))
        # Its pennon, cloth now, where the game's was a stiff board.
        flags.flag((0.0, 0.2375, 0.0), 0.047, 0.025, banner)
        # Its door laid on its face (the game's stood upright off the slope).
        door = [on_tent(-0.0225, 0.012, 0.0015), on_tent(0.0225, 0.012, 0.0015), on_tent(0.015, 0.076, 0.0015), on_tent(-0.015, 0.076, 0.0015)]
        far.slab(door, V(math.cos(SLOPE), math.sin(SLOPE), 0), 0.002, soot)
# The horse lines along its back.
LINE = V(0.0, 0.0, -0.38)
for x in (-0.16, 0.16):
    far.limb(LINE + V(x, 0, 0), LINE + V(x, 0.08, 0), 0.005, dark_timber, caps=(False, True))
far.limb(LINE + V(-0.16, 0.075, 0), LINE + V(0.16, 0.075, 0), 0.002, linen)
for x, coat in ((-0.09, bay), (0.0, grey_coat), (0.09, black_coat)):
    horse(far, LINE + V(x, 0, 0.04), -math.pi / 2, coat)
# A rack of spears by the drum, their heads iron (the game's had none).
RACK = V(-0.34, 0.0, -0.08)
far.beam(RACK + V(0, 0.12, -0.07), RACK + V(0, 0.12, 0.07), 0.006, dark_timber)
for z in (-0.07, 0.07):
    far.limb(RACK + V(0, 0, z), RACK + V(0, 0.13, z), 0.004, dark_timber, caps=(False, True))
for index in range(5):
    z = -0.05 + index * 0.025
    a, b = RACK + V(0.02, 0, z), RACK + V(-0.01, 0.24, z)
    far.limb(a, b, 0.0025, timber)
    with far.place(shift(b) @ aligning_up(b - a)):
        far.cone(3, 0.005, 0.0, 0.024, iron)
# Trodden ground, the camp's floor (its underside, below the ground, left off).
far.lathe([(0.46, -0.05), (0.46, 0.0), (0.4, 0.012), (0.0, 0.014)], 9, earth, caps=(False, False))
# The war pole, its finial and crossbar, and its banners.
far.limb((0, 0, 0), (0, 1.45, 0), 0.02, dark_timber, top=0.013, sides=6)
far.beam((-0.02, 1.36, 0), (0.4, 1.36, 0), 0.016, timber)
with far.place(shift((0, 1.45, 0))):
    far.cone(4, 0.026, 0.0, 0.1, gold, twist=math.pi / 4)
flags.flag((0.01, 1.35, 0), 0.38, 0.62, banner, tail=True)
flags.flag((0, 0.98, 0), 0.22, 0.12, banner, turn=math.pi / 2)
for angle in (0.5, 2.6, 4.7):
    far.limb(ring(0.12, 0.0, angle), (0, 0.3, 0), 0.008, dark_timber)
# The war drum on its trestle, its skin stretched over its head (the game's
# skin lay a hair over a lid of its own, the two in all but one plane).
for x in (-0.07, 0.07):
    far.limb(DRUM + V(x, 0, -0.06), DRUM + V(x * 0.6, 0.16, 0), 0.008, dark_timber)
    far.limb(DRUM + V(x, 0, 0.06), DRUM + V(x * 0.6, 0.16, 0), 0.008, dark_timber)
with far.place(shift(DRUM + V(0, 0.16, 0))):
    far.lathe([(0.0, 0.0), (0.1, 0.0), (0.115, 0.06), (0.1, 0.12)], 10, dark_leather, caps=(False, False))
    far.lathe([(0.117, 0.05), (0.118, 0.07)], 10, house)
    far.lathe([(0.1, 0.12), (0.0, 0.121)], 10, linen)
# The fire in its ring of stones, logs burning under it.
for index in range(7):
    far.rock(V(RALLY_FIRE.x, 0.01, RALLY_FIRE.z) + ring(0.07, 0.0, index / 7 * 2 * math.pi), (0.03, 0.025, 0.03), 2, 4, 0.2, index + 300,
             dark_stone)
for index in range(3):
    angle = index * 2 * math.pi / 3 + 0.4
    far.limb(V(RALLY_FIRE.x, 0.012, RALLY_FIRE.z) + ring(0.058, 0.0, angle), V(RALLY_FIRE.x, 0.03, RALLY_FIRE.z) + ring(0.006, 0.0, angle),
             0.009, dark_timber, sides=5, caps=(True, False))
piece("rally camp", tag, far)
piece("rally camp banners", tag, flags)
# The drummer's beaters, rising and falling on the skin, their heads padded.
beaters = Shape()
for z in (-0.03, 0.03):
    a, b = DRUM + V(-0.12, 0.29, z), DRUM + V(0.02, 0.3, z * 2)
    beaters.limb(a, b, 0.006, timber, caps=(True, False))
    beaters.sphere(b, 0.011, 2, 5, dark_leather)
moving("beaters", tag, "war drum beaters@rallyCamp", beaters)
for part, at_point, size in FIRES:
    if part.endswith("@rallyCamp"):
        moving("camp fire", tag, part, flame(at_point, size))

# Close: guy ropes on the war pole (the one the game ran through the drum
# brought round clear of it, and one clear of the rack's spearheads).
for angle in (1.4, 2.6, 5.4):
    peg = ring(0.42, 0.0, angle)
    close.limb((0, 1.05, 0), peg + V(0, 0.03, 0), 0.0025, rope, sides=3)
    close.limb(peg - V(0, 0.01, 0), peg + V(0, 0.04, 0), 0.005, dark_timber, sides=3)
# The horn on its post (stood clear of the black horse's rump, where the
# game's was).
POST = V(0.12, 0.0, -0.25)
close.limb(POST, POST + V(0, 0.28, 0), 0.012, dark_timber, caps=(False, True))
with close.place(shift(POST + V(0.02, 0.26, 0)) @ turn_z(-1.2)):
    close.tube([(0.012, 0.0), (0.018, 0.06), (0.03, 0.12), (0.042, 0.15)], 6, horn_pale)
    close.lathe([(0.042, 0.15), (0.0, 0.132)], 6, dark_leather, caps=(False, False))
# The rack of spears, shields leant back against it, their faces out (the
# game's stood in a tent, its shields leaning out from it face in).
NEAR_RACK = V(-0.03, 0.0, -0.2)
close.beam(NEAR_RACK + V(-0.12, 0.2, 0), NEAR_RACK + V(0.12, 0.2, 0), 0.012, timber)
for x in (-0.12, 0.12):
    close.limb(NEAR_RACK + V(x, 0, 0), NEAR_RACK + V(x, 0.22, 0), 0.008, dark_timber, caps=(False, True))
for index in range(5):
    x = -0.09 + index * 0.045
    close.limb(NEAR_RACK + V(x, 0, 0.03), NEAR_RACK + V(x, 0.5, -0.02), 0.004, dark_timber, sides=3)
    with close.place(shift(NEAR_RACK + V(x, 0.5, -0.02))):
        close.cone(4, 0.009, 0.0, 0.04, iron)
for x in (-0.07, 0.07):
    with close.place(shift(NEAR_RACK + V(x, 0.049, 0.05)) @ turn_x(1.1)):
        close.lathe([(0.055, -0.005), (0.055, 0.004), (0.0, 0.01)], 8, house)
        close.cone(5, 0.013, 0.008, 0.02, iron)
# Logs stacked by the fire, their sawn ends pale, resting on the ground past
# the floor's edge (the game's lay half sunk in it, and their top log in the
# air over the two it was stacked on).
for z, y in ((-0.0135, 0.022), (0.0135, 0.022), (0.0, 0.0445)):
    a, b = RALLY_FIRE + V(0.12, y - 0.135, z), RALLY_FIRE + V(0.26, y - 0.135, z)
    close.limb(a, b, 0.013, timber, sides=5)
    for end, facing in ((a, -1), (b, 1)):
        with close.place(shift(end) @ turn_z(-math.pi / 2)):
            close.polygon([ring(0.013, 0.0, s * 2 * math.pi / 5) for s in (range(5) if facing > 0 else reversed(range(5)))], pale_timber)
piece("rally camp close", tag, close, fine=True)


# MARK: The host banner

tag = ["hostBanner"]
far, flags, close = Shape(), Shape(), Shape()
far.limb((0, 0.0, 0), (0, 1.25, 0), 0.012, dark_timber, top=0.009, sides=6)
far.beam((-0.01, 1.17, 0), (0.3, 1.17, 0), 0.012, timber)
# Its gilt finial, a blade over a collar; a gilt knob on the crossbar's end.
far.lathe([(0.0088, 1.238), (0.014, 1.244), (0.014, 1.252), (0.0105, 1.257)], 6, gold, caps=(False, False))
with far.place(shift((0, 1.25, 0))):
    far.lathe([(0.012, 0.0), (0.02, 0.024), (0.0, 0.08)], 4, gold, twist=math.pi / 4)
far.sphere((0.306, 1.17, 0), 0.0095, 2, 6, gold)
flags.flag((0.005, 1.16, 0), 0.3, 0.5, banner, tail=True)
# And its two streamers under the banner (the game made but the one).
flags.flag((0, 0.62, 0), 0.16, 0.05, banner, turn=math.pi / 2)
flags.flag((0, 0.585, 0), 0.2, 0.04, banner, turn=math.pi / 2 + 0.45, tail=True)
piece("host banner", tag, far)
piece("host banner cloth", tag, flags)
# Close: the banner bound to its crossbar, and the staff's grip bound in leather.
for x in (0.05, 0.15, 0.25):
    close.box((x - 0.004, 1.153, -0.0075), (x + 0.004, 1.178, 0.0075), dark_leather)
close.tube([(0.0103, 0.42), (0.0135, 0.426), (0.0133, 0.5), (0.01, 0.506)], 6, dark_leather)
piece("host banner close", tag, close, fine=True)


# MARK: The Drowned Crown

tag = ["drownedCrown"]
crown, weeds = Shape(), Shape()
# The band, a little flared, and its rolled lip (begun and ended within the
# band, where the game's was capped twice over inside it).
crown.lathe([(0.15, 0.0), (0.155, 0.02), (0.15, 0.05), (0.158, 0.08), (0.162, 0.09)], 18, crown_gold)
with crown.place(shift((0, 0.005, 0))):
    crown.tube([(0.15, 0.0), (0.165, 0.01), (0.153, 0.02)], 18, verdigris)
# Seven tines, each a leaf of gold rising to a point, solid (the game's were
# two faces, open along their edges), each set with a stone of moonsalt lit
# from within.
for index in range(7):
    angle = index / 7 * 2 * math.pi
    out = V(math.sin(angle), 0, math.cos(angle))
    foot = out * 0.155 + V(0, 0.085, 0)
    tip = out * 0.17 + V(0, 0.2, 0)
    side = V(out.z, 0, -out.x) * 0.03
    crown.slab([foot - side, foot + side, tip], out, 0.012, crown_gold if index % 2 == 0 else verdigris)
    crown.sphere(out * 0.165 + V(0, 0.13, 0), 0.018, 3, 6, moonsalt_glow)
# A second circlet of pearls along its lower lip.
for index in range(18):
    crown.sphere(round_point(0.166, 0.012, index / 18 * 2 * math.pi), 0.008, 3, 5, pearl)
# A circlet of pearls at the brow, set into the band (the game's stood off it).
for index in range(14):
    crown.sphere(round_point(0.157, 0.045, (index + 0.5) / 14 * 2 * math.pi), 0.009, 2, 5, white_stone)
# The lake's weed trailing from its rim, each strand one length that sways
# from nothing at the rim to all of it at its end (the game's swayed most at
# the rim, each length of it its own way).
with weeds.swaying(sway_world=lambda p: ((0.02 - p.y) / 0.12) ** 2):
    for index in range(9):
        angle = index * 0.73
        out = V(math.sin(angle), 0, math.cos(angle))
        points = [out * 0.16 + V(0, 0.02, 0)]
        for step in range(3):
            points.append(points[-1] + out * 0.016 + V(0.006 * (1 if step % 2 == 0 else -1), -0.04, 0))
        weeds.loft(points, [0.006, 0.00475, 0.00325, 0.002], 4, moss_weed if index % 3 == 0 else lake_weed)
# Filigree along the band: studs between the pearls, and a chased line of
# verdigris round its middle, laid on the band (the game's ring stood off it).
for index in range(21):
    crown.sphere(round_point(0.158, 0.068, index / 21 * 2 * math.pi), 0.005, 2, 4, stud_salt if index % 3 == 0 else crown_gold)
crown.tube([(0.153, 0.027), (0.1553, 0.03), (0.1543, 0.036), (0.1515, 0.039)], 18, verdigris)
# The rotted velvet of its cap within (what of it was inside the band left
# off), and a great stone at its heart.
crown.lathe([(0.12, 0.09), (0.06, 0.15), (0.0, 0.17)], 14, velvet, caps=(False, False))
with crown.place(shift((0, 0.17, 0))):
    crown.lathe([(0.0, 0.0), (0.03, 0.025), (0.0, 0.07)], 7, moonsalt_glow)
# Barnacles and shells on its lower rim.
for index in range(10):
    angle = index * 2.39
    crown.rock(round_point(0.16, 0.008, angle), (0.012, 0.008, 0.011), 2, 5, 0.3, 800 + index, pale_stone if index % 2 == 0 else bone)
piece("drowned crown", tag, crown)
piece("drowned crown weed", tag, weeds)
# About it, slowly turning, a halo of moonlight; and the lake's water still
# dripping from its tines.
halo = Shape()
for index in range(12):
    angle = index / 12 * 2 * math.pi
    with halo.place(shift(round_point(0.24, 0.14 + 0.02 * (index % 2), angle))):
        halo.lathe([(0.0, -0.01), (0.008, 0.0), (0.0, 0.012)], 5, moonglow)
moving("halo", tag, "crown halo@drownedCrown", halo)
drips = Shape()
for index in range(7):
    with drips.place(shift(round_point(0.172, 0.08, index / 7 * 2 * math.pi))):
        drips.lathe([(0.0, -0.012), (0.004, -0.004), (0.0, 0.006)], 4, drip)
moving("drips", tag, "crown drips@drownedCrown", drips)


# MARK: The listening stone

tag = ["listeningStone"]
far = Shape()
# The cairn it stands on, half under the water.
for index in range(6):
    angle = index / 6 * 2 * math.pi + 0.4
    out = V(math.sin(angle), 0, math.cos(angle))
    far.rock(out * 0.06 + V(0, -0.01, 0), (0.035, 0.02, 0.03), 2, 5, 0.3, 900 + index, dark_stone if index % 2 == 0 else slate)
# The stone itself, its faces rough.
menhir = Shape()
menhir.rock((0.005, 0.11, 0), (0.034, 0.13, 0.026), 5, 6, 0.18, 917, slate)
far.faces += menhir.faces
TRIANGLES = [points for points, _, _ in menhir.faces]
AXIS = V(0.005, 0.0, 0.0)


def stone_face(y, angle):
    """How far out from its upright the stone's face is at a height and an
    angle (as MeshBuilder.ring counts), along the level from its axis."""
    origin = AXIS + V(0, y, 0)
    direction = ring(1.0, 0.0, angle)
    best = None
    for a, b, c in TRIANGLES:
        e1, e2 = b - a, c - a
        p = direction.cross(e2)
        det = e1.dot(p)
        if abs(det) < 1e-12:
            continue
        t0 = origin - a
        u = t0.dot(p) / det
        q = t0.cross(e1)
        v = direction.dot(q) / det
        t = e2.dot(q) / det
        if u >= -1e-9 and v >= -1e-9 and u + v <= 1 + 1e-9 and t > 0 and (best is None or t < best):
            best = t
    return best


# Its veins of moonsalt, each run along its face (the game's were straight
# bars across it, their ends standing off its round).
FRONT = 3 * math.pi / 2
for index, y in enumerate((0.05, 0.1, 0.16)):
    tilt = index * 0.7
    reach = math.asin(min(0.03 * math.cos(tilt) / 0.034, 0.95))
    steps = (6, 4, 1)[index]
    points = []
    for k in range(steps + 1):
        angle = FRONT - reach + 2 * reach * k / steps
        height = y + 0.02 * k / steps
        points.append(AXIS + V(0, height, 0) + ring(stone_face(height, angle) + 0.0008, 0.0, angle))
    far.loft(points, [0.0026] * len(points), 4, vein, caps=(True, True), twist=math.pi / 4)
# The cord bound about its waist, drawn tight to its faces (the game's was a
# hoop standing off them).
CORD = 20
cord_rings = []
for y, out in ((0.0705, -0.002), (0.072, 0.0022), (0.08, 0.0022), (0.0815, -0.002)):
    cord_rings.append([AXIS + V(0, y, 0) + ring(stone_face(y, 2 * math.pi * s / CORD) + out, 0.0, 2 * math.pi * s / CORD) for s in range(CORD)])
far.strip(cord_rings, pale_stone)
# A glow at its crown, where it listens.
far.lathe([(0.0, 0.225), (0.012, 0.235), (0.0, 0.25)], 6, moonglow)
piece("listening stone", tag, far)
# Rings of ripple on the water about it, turning out slowly: each arc one
# ribbon laid on the water (the game's were bars end to end, their floors on
# the water and their ends one in another).
ripples = Shape()
for radius, segments in ((0.12, 18), (0.18, 24), (0.25, 30)):
    for index in range(0, segments, 3):
        a0, a1 = index / segments * 2 * math.pi, (index + 2) / segments * 2 * math.pi
        chords = 3
        angles = [a0 + (a1 - a0) * k / chords for k in range(chords + 1)]
        inner, outer = radius - 0.003, radius + 0.003
        for k in range(chords):
            a, b = angles[k], angles[k + 1]
            mid = (a + b) / 2
            ripples.face([round_point(inner, 0.005, a), round_point(outer, 0.005, a), round_point(outer, 0.005, b), round_point(inner, 0.005, b)],
                         UP, ripple)
            ripples.face([round_point(outer, 0.003, a), round_point(outer, 0.003, b), round_point(outer, 0.005, b), round_point(outer, 0.005, a)],
                         round_point(1.0, 0.0, mid), ripple)
            ripples.face([round_point(inner, 0.003, a), round_point(inner, 0.005, a), round_point(inner, 0.005, b), round_point(inner, 0.003, b)],
                         -round_point(1.0, 0.0, mid), ripple)
        for end, along in ((a0, -1), (a1, 1)):
            tangent = V(math.cos(end), 0, -math.sin(end)) * along
            ripples.face([round_point(inner, 0.003, end), round_point(outer, 0.003, end), round_point(outer, 0.005, end),
                          round_point(inner, 0.005, end)], tangent, ripple)
moving("ripples", tag, "listening rings@listeningStone", ripples)


# MARK: The pedlar's skiff

tag = ["pedlarSkiff"]
hull, far, close = Shape(), Shape(), Shape()
# The hull of tarred planks, its sides flaring, closed to a stem at its bow
# and to a transom at its stern (the game's was a floor between two side
# boards, open at its bow and at its quarters): its outside and its inside,
# station by station from the stern, and the gunwale between them.
GUNWALE, KEEL, FLOOR = 0.07, -0.027, 0.003
# (z at the gunwale, the gunwale's half breadth, z at the chine, the chine's half breadth)
STATIONS = [(-0.367, 0.1375, -0.34, 0.11), (-0.15, 0.1375, -0.15, 0.11), (0.05, 0.1375, 0.05, 0.11), (0.22, 0.1375, 0.22, 0.11),
            (0.31, 0.105, 0.285, 0.08), (0.375, 0.058, 0.322, 0.042), (0.412, 0.012, 0.342, 0.012)]


def outside(station):
    zg, g, zc, c = station
    g += 0.006
    return [V(-g, GUNWALE, zg), V(-c, KEEL, zc), V(c, KEEL, zc), V(g, GUNWALE, zg)]


def inside(station):
    zg, g, zc, c = station
    g, c = max(g - 0.006, 0.004), max(c - 0.004, 0.004)
    return [V(-g, GUNWALE, zg), V(-c, FLOOR, zc), V(c, FLOOR, zc), V(g, GUNWALE, zg)]


for here, there in zip(STATIONS, STATIONS[1:]):
    o0, o1, i0, i1 = outside(here), outside(there), inside(here), inside(there)
    for j, out in enumerate(((-1, -0.3, 0), (0, -1, 0), (1, -0.3, 0))):
        hull.face([o0[j], o0[j + 1], o1[j + 1], o1[j]], out, tar)
        hull.face([i0[j], i0[j + 1], i1[j + 1], i1[j]], tuple(-c for c in out), tar)
    for j in (0, 3):
        hull.face([o0[j], o1[j], i1[j], i0[j]], UP, tar)
# Its planks' ends closed under the stem (at the stern, the board covers them).
o, i = outside(STATIONS[-1]), inside(STATIONS[-1])
for j in range(3):
    hull.face([o[j], o[j + 1], i[j + 1], i[j]], Z, tar)
# The stern board, raked, standing proud of the gunwale (cut to the hull,
# where the game's stood out past its floor).
hull.slab([V(-0.118, KEEL, -0.341), V(0.118, KEEL, -0.341), V(0.15, 0.08, -0.373), V(-0.15, 0.08, -0.373)], V(0, -0.287, -0.958), 0.016, tar)
# The rails along its gunwales, from the stern board to the stem.
for x in (-1, 1):
    points = [V(x * station[1], 0.075, station[0]) for station in STATIONS]
    points[-1] = V(x * 0.016, 0.075, 0.406)
    far.beam(points[0], points[3], 0.012, timber)
    for a, b in zip(points[3:], points[4:]):
        far.beam(a, b, 0.012, timber)
# The high prow rising in a curl, one carved piece (the game's was six
# lengths end to end), a stone of moonglow at its head.
prow = [V(0, -0.02, 0.34)] + [V(0, -0.02 + 0.24 * (step + 1) / 6, 0.34 + 0.09 * math.sin((step + 1) / 6 * 2.6)) for step in range(6)]
# Each joint as thick as the two lengths of the game's that met there.
radii = [0.016] + [0.016 - 0.0015 * (k - 0.5) for k in range(1, 6)] + [0.0085]
hull.loft(prow, radii, 5, tar, caps=(False, True))
far.sphere(prow[-1] + V(0, 0.012, -0.01), 0.012, 2, 5, vein)
piece("skiff hull", tag, hull)
# The awning on its four poles, patched; the poles stand on its floor (the
# game's stood a hand above it).
for x in (-0.1, 0.1):
    for z in (-0.12, 0.2):
        far.limb((x, FLOOR - 0.002, z), (x, 0.24, z), 0.006, timber)
far.slab([V(-0.13, 0.24, -0.14), V(0.13, 0.24, -0.14), V(0.13, 0.26, 0.04), V(-0.13, 0.26, 0.04)], V(0, 1, -0.1), 0.006, awning_cloth)
far.slab([V(-0.13, 0.26, 0.04), V(0.13, 0.26, 0.04), V(0.13, 0.24, 0.22), V(-0.13, 0.24, 0.22)], V(0, 1, 0.1), 0.006, awning_patch)
# The wares, set down on its floor (the game's stood in the air a hand over
# it, two of its jars half in the chest): crates, a chest bound in iron,
# jars and bolts of cloth, their ends closed.
far.box((-0.09, FLOOR, 0.04), (-0.01, FLOOR + 0.06, 0.12), timber, skip=("bottom",))
far.box((0.015, FLOOR, 0.09), (0.085, FLOOR + 0.05, 0.15), crate_wood, skip=("bottom",))
far.box((-0.06, FLOOR, -0.075), (0.06, FLOOR + 0.06, -0.005), dark_leather, skip=("bottom",))
for x in (-0.04, 0.04):
    far.box((x - 0.005, FLOOR - 0.002, -0.077), (x + 0.005, FLOOR + 0.062, -0.003), iron, skip=("bottom",))
for index, at_point in enumerate((V(0.07, FLOOR - 0.005, 0.015), V(0.08, FLOOR - 0.005, 0.06), V(-0.075, FLOOR - 0.005, -0.1))):
    with far.place(shift(at_point)):
        far.lathe([(0.0, 0.0), (0.02, 0.01), (0.022, 0.04), (0.01, 0.06), (0.012, 0.07)], 6, slate if index == 1 else leather)
for z, cloth in ((0.168, crimson), (0.2, blue_cloth)):
    far.limb((-0.08, FLOOR + 0.014, z), (0.08, FLOOR + 0.014, z), 0.014, cloth, sides=6, caps=(True, True))
# The lanterns under the awning, each on its wire under a hood of iron
# (the game never set its lanterns where they hang, but all three in the
# hull's floor).
for at_point in LANTERNS:
    far.limb(at_point + V(0, 0.052, 0), at_point + V(0, 0.03, 0), 0.002, iron, sides=3)
    with far.place(shift(at_point)):
        far.lathe([(0.018, 0.02), (0.006, 0.032)], 6, iron)
piece("skiff", tag, far)
for part, at_point in LIGHTS:
    light = Shape()
    with light.place(shift(at_point)):
        light.lathe([(0.0, -0.022), (0.016, -0.014), (0.016, 0.014), (0.0, 0.022)], 6, lantern_glow)
    moving(part.split("@")[0].replace("pedlar lantern", "lantern light"), tag, part, light)
# The pedlar at the stern, hooded, his arm on his pole, which goes over the
# starboard quarter into the water (the game's went down through the floor).
pedlar = Shape()
with pedlar.place(shift(STERN)):
    pedlar.lathe([(0.055, 0.0), (0.06, 0.08), (0.045, 0.17), (0.03, 0.22), (0.0, 0.23)], 8, cloak, caps=(False, True))
with pedlar.place(shift(STERN + V(0, 0.255, 0))):
    pedlar.lathe([(0.0, -0.035), (0.034, -0.015), (0.03, 0.025), (0.012, 0.045), (0.0, 0.05)], 7, hood_cloth)
POLE_TOP, POLE_FOOT = STERN + V(0.04, 0.27, 0.03), STERN + V(0.3, -0.16, -0.14)
pedlar.limb(POLE_TOP, POLE_FOOT, 0.007, timber, caps=(True, False))
hand = POLE_TOP + (POLE_FOOT - POLE_TOP) * 0.07
pedlar.limb(STERN + V(0.034, 0.2, 0.0), hand, 0.013, cloak, top=0.01, sides=5)
moving("pedlar figure", tag, "pedlar@pedlarSkiff", pedlar)
# Close: a thwart across the bow, a rubbing strake along each side, a sack
# of the pedlar's own behind the chest.
close.beam((-0.098, 0.05, 0.29), (0.098, 0.05, 0.29), 0.024, timber, depth=0.01)
for x in (-1, 1):
    points = []
    for zg, g, zc, c in STATIONS[:-1]:
        share = 0.62
        points.append(V(x * (c + (g - c) * share + 0.0055), KEEL + (GUNWALE - KEEL) * share, zc + (zg - zc) * share))
    for a, b in zip(points, points[1:]):
        close.beam(a, b, 0.006, dark_timber)
with close.place(shift((0.055, FLOOR - 0.002, -0.15))):
    close.lathe([(0.0, 0.0), (0.022, 0.004), (0.027, 0.02), (0.021, 0.036), (0.008, 0.044), (0.011, 0.05), (0.0, 0.052)], 6, canvas)
piece("skiff close", tag, close, fine=True)


# MARK: How they move

# Each as the game's Machinery moved it: the torches, braziers, camp fire
# and lanterns leaping; the drum's beaters swung up and down on the skin;
# the crown's halo and the stone's ripples turned once round the idle, the
# crown's drips rocked; the pedlar swung on his pole.
idle(rig, turns=[("war drum beaters@rallyCamp", Z, lambda u: 0.35 * swing(u)),
                 ("crown halo@drownedCrown", UP, wheel_turns(1)),
                 ("crown drips@drownedCrown", X, lambda u: 0.05 * swing(u)),
                 ("listening rings@listeningStone", UP, wheel_turns(1)),
                 ("pedlar@pedlarSkiff", X, lambda u: 0.12 * swing(u))],
     stretches=[(bone, leaping) for bone, _, _ in FIRES] + [(bone, leaping) for bone, _ in LIGHTS])

finish_building(out_path("Art/models/marks.glb"), MARKS)
