"""The land's tokens and the scaffold, each a variant of one file, its origin,
facing and measures as the game has them (Land in
Sources/NullmereModels/Land.swift, Holds.scaffold in Holds.swift):
- a commander's talent sigil, a thin ring of light laid on the ground
  beneath it on the march, its forward along +z, in its tree's light:
  steel's two swords crossed point foremost within eight studs, in ember
  (talentSigil0); ward's nested rings about a shield, in pale blue
  (talentSigil1); road's three chevrons pointing the march, in green-silver
  (talentSigil2);
- an ally's help light, a glowing lozenge in a thin band of gold
  (helpLight);
- a boundary stone, squared and its edges worn, its face toward the land
  beyond along +z with a dark notch cut in it, its cap banded in the
  alliance's colour, stones at its foot (borderStone);
- a House's crest board: a post and crossbar braced by a knee, the shield
  hung from it on two chains, its field in the House's colour and bound in
  iron, its face toward +z (crestBoard); and each of the ten charges laid in
  relief on that face at Land.crestFace, where the world sets one on a
  board: moon, tower, heron, star, oar, key, waves, flame, antler, bell
  (crestCharge0 to crestCharge9);
- a barge of the Still, forward along +z, its floor at the waterline: a
  tarred punt, its ends raked up and its sides swept up to them, three
  thwarts and a gunwale; its ferryman at the stern leaning on his pole over
  the side; a lantern hung from a crook at its prow; close, a rubbing strake
  down each side (barge);
- a commander's star, five points of starlight about a lit heart, set in a
  hair of gold (commanderStar);
- the scaffold round a rising work, a unit wide, deep and high for the
  world to stretch to the work: poles, ledgers at three lifts, a brace
  across each face, boards laid along the front and the right side, a
  ladder up the front; close, rope lashed round every joint of pole and
  ledger, rails along the boards, a ladder up the side and a hoist's beam
  out from a corner pole, its rope hanging to a bucket (scaffold).
None of them moves of itself (the world turns, bobs, breathes and rocks
them whole), so the file has no skeleton and is read as still.

    python Art/blender/tokens.py Art/models/tokens.glb

Each is made as the game's MeshBuilder made it (MeshBuilder.swift and
Shapes.swift), in the world's axes and units and ten times larger, as every
building is; where the game's made something it didn't mean (a disc of
light for a ring, a fan that filled the star's notches, a stroke laid on
its edge, a piece buried or floating), it is made as meant.
"""
import math
import os
import sys
from contextlib import contextmanager

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *

reset()
SIGILS = ["talentSigil0", "talentSigil1", "talentSigil2"]
CHARGES = ["crestCharge%d" % index for index in range(10)]
VARIANTS = SIGILS + ["helpLight", "borderStone", "crestBoard"] + CHARGES + ["barge", "commanderStar", "scaffold"]

# The palette's own, which the game colours exactly.
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
stone = material("plain_stone", (0.52, 0.51, 0.49))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
linen = material("plain_linen", (0.70, 0.67, 0.60))
leather = material("plain_leather_dark", (0.22, 0.16, 0.12))
house = material("house_roof", (0.78, 0.78, 0.78))
iron = material("metal_iron", (0.36, 0.37, 0.40), roughness=0.5, metallic=0.6)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.4, metallic=0.8)
fire = material("glow_fire", (1.0, 0.68, 0.32))
moonsalt = material("glow_moonsalt", (0.88, 0.91, 0.95))
# Colours of the game's own mixing, not the palette's.
ember = material("glow_ember", (0.95, 0.42, 0.18))
ward_blue = material("glow_wardblue", (0.45, 0.68, 1.0))
road_green = material("glow_roadgreen", (0.55, 0.9, 0.62))
help_glow = material("glow_helplight", (1.0, 0.86, 0.55))
# Palette.moonGlow.mix(Palette.gold, 0.35).
starlight = material("glow_starlight", (0.7305, 0.776, 0.762))
# Palette.timberDark.mix(Vec3(0.05, 0.05, 0.06), 0.55): tarred planks.
tar = material("plain_timber_tar", (0.113, 0.0905, 0.0825))
# Palette.linen.mix(Palette.leather, 0.6): the ferryman's hood and hands.
hood = material("plain_hood", (0.496, 0.418, 0.342))


# MARK: The game's MeshBuilder, in the world's axes and units

def V(p):
    return Vector((float(p[0]), float(p[1]), float(p[2])))


def P(p):
    return Vector((float(p[0]), float(p[1])))


def translation(x, y, z):
    return Matrix.Translation((x, y, z))


def ring(radius, y, angle):
    """A point on a ring about the upright, as MeshBuilder.ring counts:
    angle zero due east (+x), rising toward -z."""
    return Vector((radius * math.cos(angle), y, -radius * math.sin(angle)))


def aligning_up(direction):
    """The turn that carries straight up onto `direction` (Mat4.aligningUp)."""
    d = V(direction).normalized()
    axis = Vector((0.0, 1.0, 0.0)).cross(d)
    cosine = max(-1.0, min(1.0, d.y))
    if axis.length < 1e-6:
        return Matrix.Identity(4) if cosine > 0 else Matrix.Rotation(math.pi, 4, "X")
    return Matrix.Rotation(math.acos(cosine), 4, axis.normalized())


def noise_unit(x, y, seed):
    """Noise.unit: a value from 0 up to 1 for a lattice point."""
    m = 0xFFFFFFFF
    h = ((x & m) * 0x8DA6B343 & m) ^ ((y & m) * 0xD8163841 & m) ^ ((seed & m) * 0xCB1AB31F & m)
    h ^= h >> 13
    h = (h * 0x5BD1E995) & m
    h ^= h >> 15
    return (h >> 8) / float(1 << 24)


def area(outline):
    """Twice an outline's area, positive if it runs counter-clockwise."""
    pts = [P(p) for p in outline]
    return sum(a.x * b.y - b.x * a.y for a, b in zip(pts, pts[1:] + pts[:1]))


def triangulate(outline):
    """A plain outline (no two edges crossing) cut into triangles by its
    ears, from its first corner on, the same every time: index triples."""
    pts = [P(p) for p in outline]
    order = list(range(len(pts))) if area(outline) > 0 else list(reversed(range(len(pts))))

    def cross(o, a, b):
        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

    cut = []
    while len(order) > 3:
        count = len(order)
        for k in range(count):
            i0, i1, i2 = order[k - 1], order[k], order[(k + 1) % count]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if cross(a, b, c) <= 1e-14:
                continue
            if any(cross(a, b, pts[j]) >= -1e-14 and cross(b, c, pts[j]) >= -1e-14 and cross(c, a, pts[j]) >= -1e-14
                   for j in order if j not in (i0, i1, i2)):
                continue
            cut.append((i0, i1, i2))
            del order[k]
            break
        else:
            raise ValueError("an outline that won't cut into triangles")
    cut.append(tuple(order))
    return cut


def offset(outline, distance):
    """A closed outline moved `distance` out from its inside (in, if
    negative), its corners mitred."""
    pts = [P(p) for p in outline]
    turn = 1.0 if area(outline) > 0 else -1.0
    moved = []
    for i, here in enumerate(pts):
        d0 = (here - pts[i - 1]).normalized()
        d1 = (pts[(i + 1) % len(pts)] - here).normalized()
        n0, n1 = Vector((d0.y, -d0.x)) * turn, Vector((d1.y, -d1.x)) * turn
        m = (n0 + n1).normalized()
        moved.append(here + m * (distance / max(m.dot(n1), 0.25)))
    return moved


def mitred(points, breadths, closed=False):
    """The left and right edges of a stroke `breadths` wide along `points`
    (one breadth, or one at each point), mitred where it bends."""
    pts = [P(p) for p in points]
    count = len(pts)
    if not isinstance(breadths, (list, tuple)):
        breadths = [breadths] * count
    left, right = [], []
    for i, here in enumerate(pts):
        if closed or 0 < i < count - 1:
            d0 = (here - pts[i - 1]).normalized()
            d1 = (pts[(i + 1) % count] - here).normalized()
        elif i == 0:
            d0 = d1 = (pts[1] - here).normalized()
        else:
            d0 = d1 = (here - pts[i - 1]).normalized()
        n0, n1 = Vector((-d0.y, d0.x)), Vector((-d1.y, d1.x))
        m = n0 + n1
        m = m.normalized() if m.length > 1e-9 else n1
        reach = breadths[i] / 2 / max(m.dot(n1), 0.25)
        left.append(here + m * reach)
        right.append(here - m * reach)
    return left, right


class Shape:
    """Triangles in the world's axes and units, each counter-clockwise seen
    from outside, built as the game's MeshBuilder builds its solids and
    placed by a transform as its `place` places them; made at the end into
    one object of Blender's, its faces lit flat."""

    def __init__(self):
        self.triangles = []
        self.transform = Matrix.Identity(4)

    @contextmanager
    def placed(self, placement):
        saved = self.transform
        self.transform = saved @ placement
        try:
            yield self
        finally:
            self.transform = saved

    def triangle(self, a, b, c, mat):
        m = self.transform
        # A mirroring placement turns the winding inside out: put it back.
        if m.to_3x3().determinant() < 0:
            b, c = c, b
        pa, pb, pc = m @ V(a), m @ V(b), m @ V(c)
        if (pb - pa).cross(pc - pa).length <= 1e-9:
            return
        self.triangles.append((pa, pb, pc, mat))

    def quad(self, a, b, c, d, mat):
        self.triangle(a, b, c, mat)
        self.triangle(a, c, d, mat)

    def polygon(self, points, mat):
        for i in range(1, len(points) - 1):
            self.triangle(points[0], points[i], points[i + 1], mat)

    def face(self, points, outward, mat):
        """A flat convex face, each of its triangles turned to look along
        `outward`."""
        p = [V(q) for q in points]
        out = V(outward)
        for i in range(1, len(p) - 1):
            a, b, c = p[0], p[i], p[i + 1]
            if (b - a).cross(c - a).dot(out) < 0:
                b, c = c, b
            self.triangle(a, b, c, mat)

    def box(self, low, high, mat, leave=()):
        """A box between two corners, its faces named east, west, top,
        bottom, south and north; those in `leave`, hidden, left off."""
        x0, y0, z0 = low
        x1, y1, z1 = high
        faces = {"east": ((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)),
                 "west": ((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)),
                 "top": ((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)),
                 "bottom": ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)),
                 "south": ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)),
                 "north": ((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0))}
        for name in ("east", "west", "top", "bottom", "south", "north"):
            if name not in leave:
                self.quad(*faces[name], mat)

    def block(self, centre, size, mat, turn=0.0, leave=()):
        """A box about its centre, turned about the upright as the game's
        box(center:size:turn:) is."""
        with self.placed(translation(*centre) @ Matrix.Rotation(turn, 4, "Y")):
            self.box(tuple(-s / 2 for s in size), tuple(s / 2 for s in size), mat, leave)

    def lathe(self, profile, sides, mat, twist=0.0, caps=(True, True)):
        """A solid turned about the upright from its profile, bottom to
        top, (radius, height) a ring; ends with a radius capped."""
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
        self.lathe(profile, sides, mat, twist, caps=(False, False))

    def limb(self, a, b, radius, mat, sides=4, top_radius=None, caps=(False, False), twist=0.0):
        """A haft from one point to another, its ends open unless capped."""
        a, b = V(a), V(b)
        length = (b - a).length
        if length <= 0:
            return
        with self.placed(Matrix.Translation(a) @ aligning_up(b - a)):
            self.lathe([(radius, 0.0), (radius if top_radius is None else top_radius, length)], sides, mat, twist, caps)

    def beam(self, a, b, width, mat, depth=None, ends=(True, True)):
        """A squared timber from one point to another, as the game's beam;
        an end hidden in what it meets left open."""
        a, b = V(a), V(b)
        along = b - a
        length = along.length
        if length <= 0:
            return
        up = along / length
        reference = Vector((0.0, 0.0, 1.0)) if abs(up.y) > 0.95 else Vector((0.0, 1.0, 0.0))
        side = up.cross(reference).normalized()
        front = side.cross(up)
        frame = Matrix.Identity(4)
        frame.col[0] = (side.x, side.y, side.z, 0.0)
        frame.col[1] = (up.x, up.y, up.z, 0.0)
        frame.col[2] = (front.x, front.y, front.z, 0.0)
        frame.col[3] = (a.x, a.y, a.z, 1.0)
        d = width if depth is None else depth
        leave = [name for name, kept in (("bottom", ends[0]), ("top", ends[1])) if not kept]
        with self.placed(frame):
            self.box((-width / 2, 0.0, -d / 2), (width / 2, length, d / 2), mat, leave)

    def plate(self, points, normal, thickness, mat):
        """A flat convex piece about `points`, `thickness` through along
        `normal` (the game's sheet), closed round its edge."""
        n = V(normal).normalized()
        shift = n * (thickness / 2)
        front = [V(p) + shift for p in points]
        back = [V(p) - shift for p in points]
        self.face(front, n, mat)
        self.face(back, -n, mat)
        middle = sum((V(p) for p in points), Vector()) / len(points)
        for i in range(len(points)):
            j = (i + 1) % len(points)
            out = (V(points[i]) + V(points[j])) / 2 - middle
            self.face([front[i], front[j], back[j], back[i]], out - n * out.dot(n), mat)

    def rock(self, centre, size, rings, sides, jitter, seed, mat):
        """A rough lump, each point pushed in or out by the game's own
        noise: the same stone the game made for the same seed."""
        grid = []
        for k in range(rings + 1):
            latitude = math.pi * k / rings - math.pi / 2
            pole = k in (0, rings)
            row = []
            for side in range(sides):
                longitude = 2 * math.pi * side / sides
                push = 1 + jitter * (2 * noise_unit(k, 0 if pole else side, seed) - 1)
                c = 0.0 if pole else math.cos(latitude)
                d = (c * math.cos(longitude), math.sin(latitude), -c * math.sin(longitude))
                row.append(Vector([centre[i] + d[i] * size[i] * push for i in range(3)]))
            grid.append(row)
        for k in range(rings):
            for side in range(sides):
                n = (side + 1) % sides
                self.quad(grid[k][side], grid[k][n], grid[k + 1][n], grid[k + 1][side], mat)

    # A flat piece cut to an outline and raised along its frame's third
    # axis, the frame (u, v, w) -> a point.

    def prism(self, outline, frame, low, high, mat, top=True, bottom=False, walls=True):
        """A piece cut to `outline` (u, v) and raised from `low` to `high`:
        its top, its bottom if asked, and its sides."""
        pts = [P(p) for p in outline]
        origin = frame(0, 0, 0)
        up = frame(0, 0, 1) - origin
        for i, j, k in triangulate(outline):
            if top:
                self.face([frame(pts[i].x, pts[i].y, high), frame(pts[j].x, pts[j].y, high), frame(pts[k].x, pts[k].y, high)], up, mat)
            if bottom:
                self.face([frame(pts[i].x, pts[i].y, low), frame(pts[j].x, pts[j].y, low), frame(pts[k].x, pts[k].y, low)], -up, mat)
        if walls:
            turn = 1.0 if area(outline) > 0 else -1.0
            for i, a in enumerate(pts):
                b = pts[(i + 1) % len(pts)]
                out = Vector((b.y - a.y, a.x - b.x)) * turn
                self.face([frame(a.x, a.y, low), frame(b.x, b.y, low), frame(b.x, b.y, high), frame(a.x, a.y, high)],
                          frame(out.x, out.y, 0) - origin, mat)

    def ribbon(self, points, breadths, frame, low, high, mat, closed=False, walls=True):
        """A stroke `breadths` wide along `points` (u, v), mitred where it
        bends, raised from `low` to `high`: its top and its sides, and its
        ends if it has any; a breadth of nothing comes to a point."""
        left, right = mitred(points, breadths, closed)
        pts = [P(p) for p in points]
        count = len(pts)
        origin = frame(0, 0, 0)
        up = frame(0, 0, 1) - origin

        def at_(q, w):
            return frame(q.x, q.y, w)

        def side(q):
            return frame(q.x, q.y, 0) - origin

        for i in (range(count) if closed else range(count - 1)):
            j = (i + 1) % count
            self.face([at_(left[i], high), at_(left[j], high), at_(right[j], high), at_(right[i], high)], up, mat)
            if walls:
                d = pts[j] - pts[i]
                toward = Vector((-d.y, d.x))
                self.face([at_(left[i], low), at_(left[j], low), at_(left[j], high), at_(left[i], high)], side(toward), mat)
                self.face([at_(right[i], low), at_(right[j], low), at_(right[j], high), at_(right[i], high)], side(-toward), mat)
        if walls and not closed:
            for i, k in ((0, 1), (count - 1, count - 2)):
                self.face([at_(left[i], low), at_(right[i], low), at_(right[i], high), at_(left[i], high)], side(pts[i] - pts[k]), mat)

    def rim(self, outer, inner, frame, low_outer, low_inner, high, mat):
        """A band between two closed outlines (u, v), its face at `high`,
        its outer side down to `low_outer` and its inner to `low_inner`."""
        origin = frame(0, 0, 0)
        up = frame(0, 0, 1) - origin
        count = len(outer)
        for i in range(count):
            j = (i + 1) % count
            o0, o1, i0, i1 = outer[i], outer[j], inner[i], inner[j]
            self.face([frame(o0.x, o0.y, high), frame(o1.x, o1.y, high), frame(i1.x, i1.y, high), frame(i0.x, i0.y, high)], up, mat)
            out = (o0 + o1) / 2 - (i0 + i1) / 2
            self.face([frame(o0.x, o0.y, low_outer), frame(o1.x, o1.y, low_outer), frame(o1.x, o1.y, high), frame(o0.x, o0.y, high)],
                      frame(out.x, out.y, 0) - origin, mat)
            self.face([frame(i0.x, i0.y, low_inner), frame(i1.x, i1.y, low_inner), frame(i1.x, i1.y, high), frame(i0.x, i0.y, high)],
                      origin - frame(out.x, out.y, 0), mat)

    def make(self, name):
        """The triangles made one object, in Blender's axes and measure."""
        mesh = bpy.data.meshes.new(name)
        obj = link(bpy.data.objects.new(name, mesh))
        bm = bmesh.new()
        mats = []
        for a, b, c, mat in self.triangles:
            if mat not in mats:
                mats.append(mat)
            face = bm.faces.new([bm.verts.new(at(*p)) for p in (a, b, c)])
            face.material_index = mats.index(mat)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bm.to_mesh(mesh)
        bm.free()
        for mat in mats:
            mesh.materials.append(mat)
        for poly in mesh.polygons:
            poly.use_smooth = False
        if len(mesh.polygons) != len(self.triangles):
            raise ValueError("%s: %d triangles made of %d" % (name, len(mesh.polygons), len(self.triangles)))
        return obj


def piece(name, shape):
    return shape.make(name)


def ground(u, v, w):
    """A point laid on the ground: u across (x), v forward (z), w up (y)."""
    return Vector((u, w, v))


# MARK: The talent sigils

# Laid a little over the ground: each band and figure stands from BED to
# its top, the ring's ridge at TOP (the game's ring of light rose to there).
BED, TOP = 0.004, 0.010


def ridged_ring(shape, inner, outer, sides, mat, base=BED, ridge=TOP, twist=0.0):
    """A band of light about the upright from `inner` to `outer`, ridged
    along its middle and sloping down to the ground either side of it."""
    middle = (inner + outer) / 2
    step = 2 * math.pi / sides
    up = Vector((0.0, 1.0, 0.0))
    for side in range(sides):
        a0 = twist + side * step
        a1 = a0 + step
        out = ring(1.0, 0.0, a0 + step / 2)
        shape.face([ring(outer, base, a0), ring(outer, base, a1), ring(middle, ridge, a1), ring(middle, ridge, a0)], up + out * 0.3, mat)
        shape.face([ring(inner, base, a0), ring(inner, base, a1), ring(middle, ridge, a1), ring(middle, ridge, a0)], up - out * 0.3, mat)


def stud(shape, angle, radius, size, mat, apex=0.012):
    """A low square stud laid on the ring at `angle` (round from +z toward
    +x, as the game set them), square to the ring."""
    centre = Vector((math.sin(angle) * radius, BED, math.cos(angle) * radius))
    out = Vector((math.sin(angle), 0.0, math.cos(angle))) * (size / 2)
    along = Vector((math.cos(angle), 0.0, -math.sin(angle))) * (size / 2)
    corners = [centre + out + along, centre - out + along, centre - out - along, centre + out - along]
    top = Vector((centre.x, apex, centre.z))
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        shape.face([a, b, top], (a + b) / 2 - centre + Vector((0.0, 0.01, 0.0)), mat)


# Each ring of the game's (the outer one of every tree, and ward's two
# within) was a lathe from one radius to another on one height, which caps
# both ends: a disc of light where a ring was meant, every figure on it the
# same light and lost in it. Here each is a ring.
RING = (0.46, 0.5)
RING_SIDES = 42


def sword(shape, point, pommel, high, mat):
    """A sword laid on the ground from its point to its pommel's end: a
    blade narrowing to its point, a crossguard, a grip and a pommel."""
    tip, end = P(point), P(pommel)
    along = (end - tip).normalized()
    across = Vector((-along.y, along.x))
    reach = (end - tip).length

    def outline(points):
        return [tip + along * (s * reach / 0.84) + across * t for s, t in points]

    shape.prism(outline([(0.0, 0.0), (0.07, 0.016), (0.525, 0.021), (0.525, -0.021), (0.07, -0.016)]), ground, BED, high, mat)
    shape.prism(outline([(0.515, -0.062), (0.5325, -0.07), (0.55, -0.062), (0.55, 0.062), (0.5325, 0.07), (0.515, 0.062)]), ground, BED,
                high + 0.001, mat)
    shape.prism(outline([(0.545, -0.011), (0.775, -0.011), (0.775, 0.011), (0.545, 0.011)]), ground, BED, high - 0.0005, mat)
    shape.prism(outline([(0.77, 0.0), (0.805, -0.026), (0.84, 0.0), (0.805, 0.026)]), ground, BED, high + 0.001, mat)


# Steel: two swords crossed, their points toward the march, where the game
# drew two strokes crossed; eight studs round the ring, each square to it
# (the game's stood square to the axes, four of them turned on the ring).
steel = Shape()
ridged_ring(steel, *RING, RING_SIDES, ember)
for k in range(8):
    stud(steel, k * math.pi / 4, 0.48, 0.05, ember)
for angle, high in ((0.6, 0.008), (-0.6, 0.0086)):
    point = (math.sin(angle) * 0.42, math.cos(angle) * 0.42)
    sword(steel, point, (-point[0], -point[1]), high, ember)
piece("steel sigil@talentSigil0", steel)

# Ward: a ring within a ring and a shield within both, its point aft.
ward = Shape()
ridged_ring(ward, *RING, RING_SIDES, ward_blue)
ridged_ring(ward, 0.3, 0.33, 16, ward_blue)
ridged_ring(ward, 0.14, 0.17, 12, ward_blue)
ward.prism([(-0.1, 0.08), (0.1, 0.08), (0.1, -0.04), (0.0, -0.14), (-0.1, -0.04)], ground, BED, 0.008, ward_blue)
piece("ward sigil@talentSigil1", ward)

# Road: three chevrons pointing the march, each mitred to a point (the
# game's two strokes met square and left a notch at the point).
road = Shape()
ridged_ring(road, *RING, RING_SIDES, road_green)
for z in (-0.24, -0.04, 0.16):
    road.ribbon([(-0.22, z), (0.0, z + 0.18), (0.22, z)], 0.035, ground, BED, 0.008, road_green)
piece("road sigil@talentSigil2", road)

# MARK: The help light

light = Shape()
light.lathe([(0.0, -0.05), (0.03, 0.0), (0.0, 0.05)], 8, help_glow)
# Its ring of gold a band with some substance to it (the game's a skin no
# thickness at all), about the lozenge's waist.
light.lathe([(0.04, -0.004), (0.044, -0.004), (0.044, 0.004), (0.04, 0.004), (0.04, -0.004)], 12, gold, caps=(False, False))
piece("help light@helpLight", light)

# MARK: The border stone

SQUARE = math.cos(math.pi / 4)


def worn(radius, y, wear=0.2):
    """A section of the squared stone at height y: the square the game's
    four-sided lathe of `radius` made, turned to show a face along +z (the
    game's showed a corner), its corners worn back."""
    h = radius * SQUARE
    c = h * wear
    corners = [(h - c, h), (h, h - c), (h, c - h), (h - c, -h), (c - h, -h), (-h, c - h), (-h, h - c), (c - h, h)]
    return [Vector((x, y, z)) for x, z in corners]


def girdle(shape, sections, mat):
    """The faces between sections of eight corners, each facing out."""
    for low, high in zip(sections, sections[1:]):
        for i in range(8):
            j = (i + 1) % 8
            middle = (low[i] + low[j]) / 2
            shape.face([low[i], low[j], high[j], high[i]], Vector((middle.x, 0.0, middle.z)), mat)


PROFILE = [(0.05, -0.04), (0.05, 0.0), (0.042, 0.16), (0.032, 0.2)]
APEX = 0.215


def stone_radius(y):
    for (r0, y0), (r1, y1) in zip(PROFILE, PROFILE[1:]):
        if y0 <= y <= y1:
            return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
    raise ValueError(y)


marker = Shape()
sections = [worn(r, y) for r, y in PROFILE]
girdle(marker, sections, pale_stone)
top = Vector((0.0, APEX, 0.0))
for i in range(8):
    a, b = sections[-1][i], sections[-1][(i + 1) % 8]
    marker.face([a, b, top], Vector(((a.x + b.x) / 2, 0.02, (a.z + b.z) / 2)), pale_stone)
marker.face(list(reversed(sections[0])), (0, -1, 0), pale_stone)
# The notch cut in its face toward the land beyond, dark, just proud of the
# face and leaning in with it (the game's dark block stood off the corner
# the stone showed there).
for low, high in ((0.085, 0.115),):
    front = [SQUARE * stone_radius(y) + 0.0008 for y in (low, high)]
    back = [SQUARE * stone_radius(y) - 0.006 for y in (low, high)]
    f = [Vector((-0.015, low, front[0])), Vector((0.015, low, front[0])), Vector((0.015, high, front[1])), Vector((-0.015, high, front[1]))]
    b = [Vector((-0.015, low, back[0])), Vector((0.015, low, back[0])), Vector((0.015, high, back[1])), Vector((-0.015, high, back[1]))]
    marker.face(f, (0, 0, 1), dark_stone)
    marker.face([b[0], f[0], f[3], b[3]], (-1, 0, 0), dark_stone)
    marker.face([f[1], b[1], b[2], f[2]], (1, 0, 0), dark_stone)
    marker.face([f[3], f[2], b[2], b[3]], (0, 1, 0), dark_stone)
    marker.face([b[0], b[1], f[1], f[0]], (0, -1, 0), dark_stone)
# Stones at its foot: the game's own, and another at its fore corner.
marker.rock((0.05, 0.0, -0.03), (0.03, 0.02, 0.025), 2, 4, 0.25, 410, stone)
marker.rock((-0.04, 0.0, 0.03), (0.022, 0.015, 0.018), 2, 5, 0.25, 411, stone)
piece("border stone@borderStone", marker)

# Its cap banded in the alliance's colour, the band laid evenly over the
# stone as its sides lean in (the game's band ran straight across the bend
# in the stone's sides, which showed through it), closed above and below.
band = Shape()
LIFT = 0.002
plain = [worn(stone_radius(y), y) for y in (0.14, 0.16, 0.17)]
banded = []
for y in (0.14, 0.16, 0.17):
    h = stone_radius(y) * SQUARE
    c = h * 0.2 + (2 - math.sqrt(2)) * LIFT
    hb = h + LIFT
    banded.append([Vector((x, y, z)) for x, z in [(hb - c, hb), (hb, hb - c), (hb, c - hb), (hb - c, -hb), (c - hb, -hb), (-hb, c - hb),
                                                  (-hb, hb - c), (c - hb, hb)]])
girdle(band, banded, house)
for inside, outside, facing in ((plain[0], banded[0], (0, -1, 0)), (plain[-1], banded[-1], (0, 1, 0))):
    for i in range(8):
        j = (i + 1) % 8
        band.face([inside[i], inside[j], outside[j], outside[i]], facing, house)
piece("border band@borderStone", band)

# MARK: The crest board

CREST_FACE = (0.0, 0.42, 0.014)
SHIELD = [(-0.08, 0.1), (0.08, 0.1), (0.08, -0.02), (0.05, -0.08), (0.0, -0.11), (-0.05, -0.08), (-0.08, -0.02)]
# The shield's faces, 0.012 through about the crest's face.
SHIELD_BACK, SHIELD_FRONT = CREST_FACE[2] - 0.006, CREST_FACE[2] + 0.006


def on_shield(u, v, w):
    """A point on the shield: u across and v up from the crest's face, w
    out along +z."""
    return Vector((CREST_FACE[0] + u, CREST_FACE[1] + v, w))


board = Shape()
# The post squared to its crossbar (the game's showed the crossbar a
# corner), its head capped where the game's was open.
with board.placed(translation(-0.14, 0.0, -0.02)):
    board.lathe([(0.012, 0.0), (0.012, 0.62), (0.0, 0.632)], 4, dark, twist=math.pi / 4, caps=(False, False))
board.beam((-0.146, 0.58, -0.02), (0.06, 0.58, -0.02), 0.014, timber)
# A knee under the crossbar, from the post.
board.beam((-0.14, 0.5, -0.02), (-0.086, 0.58, -0.02), 0.01, timber)
for x in (-0.05, 0.05):
    # Each chain from inside the crossbar down into the shield's head (the
    # game's stood off both), iron.
    board.limb((x, 0.584, -0.016), (x, 0.513, 0.012), 0.003, iron)
piece("crest board@crestBoard", board)
field = Shape()
field.prism(SHIELD, on_shield, SHIELD_BACK, SHIELD_FRONT, house, top=True, bottom=True, walls=False)
piece("crest field@crestBoard", field)
# Its rim of iron following the shield's edge all round (the game's ran
# straight across the curve of its foot, and lay buried in the field or in
# the plane of its face), standing proud of the face and binding the edge.
binding = Shape()
binding.rim(offset(SHIELD, 0.0008), offset(SHIELD, -0.0072), on_shield, SHIELD_BACK - 0.001, SHIELD_FRONT - 0.001, SHIELD_FRONT + 0.004,
            iron)
piece("crest rim@crestBoard", binding)

# MARK: The crest's charges

# Each laid in relief on the shield's face in the House's colour, from
# just within the face out to where the game's stood (it stood off it),
# every stroke its breadth across the face and its depth out of it (the
# game's beams laid most of them on their edges); a lesser stroke over
# another stands a hair lower, so no two faces lie in one plane.
CHARGE_BACK, CHARGE_FRONT, UNDER = SHIELD_FRONT - 0.0005, CREST_FACE[2] + 0.012, CREST_FACE[2] + 0.0117


def charge(index, shape):
    piece("charge %d@crestCharge%d" % (index, index), shape)


def raised(shape, outline, high=CHARGE_FRONT):
    shape.prism(outline, on_shield, CHARGE_BACK, high, house)


def stroke(shape, points, breadths, high=CHARGE_FRONT, closed=False):
    shape.ribbon(points, breadths, on_shield, CHARGE_BACK, high, house, closed=closed)


def disc(centre, radius, sides, turn=0.0):
    return [(centre[0] + radius * math.sin(turn + 2 * math.pi * k / sides), centre[1] + radius * math.cos(turn + 2 * math.pi * k / sides))
            for k in range(sides)]


# A crescent moon, horns down, waxing to its middle and fining to its
# horns.
moon = Shape()
arc = [-1.9 + 3.8 * k / 14 for k in range(15)]
stroke(moon, [(math.sin(a) * 0.045, math.cos(a) * 0.045) for a in arc], [0.017 * math.sqrt(max(0.0, 1 - (a / 1.9) ** 2)) for a in arc])
charge(0, moon)

# A tower, its three merlons on it and its door open.
tower = Shape()
raised(tower, [(-0.03, -0.06), (-0.009, -0.06), (-0.009, -0.032), (0.0, -0.024), (0.009, -0.032), (0.009, -0.06), (0.03, -0.06),
               (0.03, 0.04), (0.033, 0.04), (0.033, 0.06), (0.017, 0.06), (0.017, 0.04), (0.008, 0.04), (0.008, 0.06), (-0.008, 0.06),
               (-0.008, 0.04), (-0.017, 0.04), (-0.017, 0.06), (-0.033, 0.06), (-0.033, 0.04), (-0.03, 0.04)])
charge(1, tower)

# A heron on one leg, its neck up and its bill out.
heron = Shape()
raised(heron, [(-0.03, -0.01), (0.03, -0.02), (0.01, 0.02)])
stroke(heron, [(0.0, -0.065), (0.0, -0.012)], 0.006, UNDER)
stroke(heron, [(-0.011, -0.064), (0.012, -0.066)], 0.005, UNDER)
stroke(heron, [(0.012, 0.014), (0.0, 0.06), (0.042, 0.05)], [0.007, 0.007, 0.0], UNDER)
raised(heron, disc((0.003, 0.059), 0.0075, 6))
charge(2, heron)

# A star of six rays, each to a point.
star_rays = Shape()
rays = []
for k in range(6):
    a = k * math.pi / 3
    d, n = Vector((math.sin(a), math.cos(a))), Vector((math.cos(a), -math.sin(a)))
    rays += [d * 0.045 - n * 0.007, d * 0.055, d * 0.045 + n * 0.007,
             Vector((math.sin(a + math.pi / 6), math.cos(a + math.pi / 6))) * (0.007 / math.sin(math.pi / 6))]
for i in range(len(rays)):
    a, b = rays[i], rays[(i + 1) % len(rays)]
    star_rays.face([on_shield(0, 0, CHARGE_FRONT), on_shield(a.x, a.y, CHARGE_FRONT), on_shield(b.x, b.y, CHARGE_FRONT)], (0, 0, 1), house)
    mid = (a + b) / 2
    star_rays.face([on_shield(a.x, a.y, CHARGE_BACK), on_shield(b.x, b.y, CHARGE_BACK), on_shield(b.x, b.y, CHARGE_FRONT),
                    on_shield(a.x, a.y, CHARGE_FRONT)], (mid.x, mid.y, 0), house)
charge(3, star_rays)

# An oar, its blade down and its grip knobbed.
oar = Shape()
raised(oar, [(0.01, -0.02), (0.04, -0.03), (0.045, -0.07), (0.025, -0.07)])
stroke(oar, [(-0.04, 0.06), (0.02, -0.03)], 0.008, UNDER)
raised(oar, disc((-0.042, 0.063), 0.0065, 6, math.pi / 6))
charge(4, oar)

# A key: its bow a ring through the game's four corners, its shank, its
# two teeth and a collar.
key = Shape()
stroke(key, disc((-0.01, 0.04), 0.02, 8), 0.012, closed=True)
stroke(key, [(-0.01, 0.017), (-0.01, -0.06), (0.02, -0.06)], 0.01, UNDER)
stroke(key, [(-0.012, -0.04), (0.015, -0.04)], 0.01, UNDER - 0.0003)
stroke(key, [(-0.018, 0.004), (-0.002, 0.004)], 0.005)
charge(5, key)

# Two waves, rolling where the game's ran in zigzags through the same crests
# and troughs.
waves = Shape()
for y0 in (-0.03, 0.02):
    xs = [-0.06 + 0.12 * k / 24 for k in range(25)]
    stroke(waves, [(x, y0 + 0.0075 * (1 - math.cos(2 * math.pi * (x + 0.06) / 0.03))) for x in xs], 0.01)
charge(6, waves)

# A flame, licking up either side of its tongue (the game's a plain
# hexagon on the same bounds).
flame = Shape()
raised(flame, [(0.0, -0.06), (0.022, -0.054), (0.034, -0.038), (0.036, -0.018), (0.028, 0.0), (0.03, 0.022), (0.016, 0.01), (0.017, 0.035),
               (0.005, 0.065), (-0.006, 0.04), (-0.012, 0.022), (-0.026, 0.036), (-0.024, 0.006), (-0.034, -0.014), (-0.034, -0.036),
               (-0.022, -0.054)])
charge(7, flame)

# An antler, its beam rising from its burr and fining to a point, its three
# tines curving up to theirs.
antler = Shape()
stroke(antler, [(0.0, -0.058), (0.0, 0.055), (0.0, 0.068)], [0.012, 0.008, 0.0])
raised(antler, disc((0.0, -0.058), 0.0105, 6, math.pi / 6), CHARGE_FRONT + 0.0003)
for y, side in ((-0.02, -1), (0.01, 1), (0.04, -1)):
    stroke(antler, [(0.0, y), (side * 0.025, y + 0.012), (side * 0.04, y + 0.03)], [0.008, 0.006, 0.0], UNDER)
charge(8, antler)

# A bell, its sides swelling to its lip, its clapper showing under it and
# its canon over it.
bell = Shape()
right = [(0.012, 0.05), (0.022, 0.044), (0.027, 0.03), (0.029, 0.01), (0.033, -0.015), (0.041, -0.035), (0.047, -0.045)]
raised(bell, right + [(-x, y) for x, y in reversed(right)])
raised(bell, disc((0.0, -0.053), 0.0065, 6, math.pi / 6), UNDER)
stroke(bell, [(0.0, 0.047), (0.0, 0.065)], 0.01, UNDER)
charge(9, bell)

# MARK: The barge

hull = Shape()
# The flat bottom, reaching into its raked ends (the game's stopped short
# of them, a crack open between).
hull.box((-0.17, -0.025, -0.316), (0.17, 0.005, 0.316), tar)
for x in (-0.17, 0.17):
    hull.block((x, 0.03, 0.0), (0.02, 0.07, 0.62), tar)


def rake(y):
    """How far out along z the middle of a raked end stands at height y."""
    return 0.31 + 0.7 * (y + 0.02)


for s in (-1, 1):
    z = s * 0.31
    # The raked end, as wide as the hull and closed round its edges (the
    # game's was a sheet, open at its edges, narrower than the sides).
    hull.plate([(-0.1797, -0.02, z), (0.1797, -0.02, z), (0.1797, 0.08, z + s * 0.07), (-0.1797, 0.08, z + s * 0.07)], (0, -s * 0.6, s),
               0.02, tar)
    # The sides swept up to it, where the game's stopped and left the end
    # standing free of them.
    for x0, x1 in ((0.1605, 0.1795), (-0.1795, -0.1605)):
        hull.prism([(s * 0.305, -0.005), (s * 0.305, 0.065), (s * rake(0.065), 0.065), (s * rake(-0.005), -0.005)],
                   lambda u, v, w: Vector((w, v, u)), x0, x1, tar, top=True, bottom=True)
# Thwarts across it, into its sides.
for z in (-0.18, 0.0, 0.18):
    hull.beam((-0.165, 0.05, z), (0.165, 0.05, z), 0.025, timber)
# The gunwale capping each side from end to end (the game's rail hung over
# the sides, clear of them).
for x in (-0.17, 0.17):
    hull.beam((x, 0.0725, -0.373), (x, 0.0725, 0.373), 0.012, timber, depth=0.017)
piece("barge hull@barge", hull)

# The ferryman at the stern, leaning on his pole: it runs from over his
# head down past his side, over the gunwale and into the water aft of the
# barge (the game's ran from his hand down through the floor).
STERN = Vector((0.05, 0.0, -0.25))
POLE_TOP, POLE_WATER = Vector((0.005, 0.34, -0.17)), Vector((0.29, 0.0, -0.33))
pole_dir = POLE_WATER - POLE_TOP


def pole_at(y):
    return POLE_TOP + pole_dir * ((POLE_TOP.y - y) / (POLE_TOP.y - POLE_WATER.y))


ferryman = Shape()
with ferryman.placed(Matrix.Translation(STERN)):
    ferryman.lathe([(0.05, 0.0), (0.06, 0.1), (0.045, 0.2), (0.02, 0.24), (0.0, 0.25)], 7, leather)
with ferryman.placed(Matrix.Translation(STERN + Vector((0, 0.29, 0)))):
    ferryman.lathe([(0.0, -0.04), (0.035, -0.02), (0.03, 0.02), (0.0, 0.04)], 6, hood)
ferryman.limb(POLE_TOP, pole_at(-0.35), 0.008, timber, caps=(True, False))
# His arms, which the game left off: the left across him to the pole high,
# the right to it at his side.
for shoulder, hand in (((-0.035, 0.205, 0.005), 0.25), ((0.035, 0.205, 0.0), 0.18)):
    ferryman.limb(STERN + Vector(shoulder), pole_at(hand), 0.011, leather, sides=5, caps=(False, True))
piece("barge ferryman@barge", ferryman)

# The lantern on its crook at the prow: the crook stepped into the floor
# at the foot of the bow (the game's stood on nothing), the lantern hung
# from its arm (the game's floated under it), capped and footed in iron.
lantern = Shape()
lantern.limb((0.0, 0.0, 0.33 - 0.05 * 0.03 / 0.21), (0.0, 0.262, 0.3603), 0.008, dark, caps=(False, True))
lantern.beam((0.0, 0.26, 0.355), (0.0, 0.26, 0.42), 0.008, dark)
lantern.limb((0.0, 0.258, 0.416), (0.0, 0.228, 0.42), 0.002, iron, sides=3)
with lantern.placed(translation(0.0, 0.2, 0.42)):
    lantern.lathe([(0.0, -0.03), (0.022, -0.02), (0.022, 0.02), (0.0, 0.03)], 6, fire)
    lantern.lathe([(0.024, 0.018), (0.0, 0.036)], 6, iron, caps=(False, False))
    lantern.lathe([(0.0, -0.036), (0.024, -0.018)], 6, iron, caps=(False, False))
piece("barge lantern@barge", lantern)

# Close: a rubbing strake down each side.
strakes = Shape()
for s in (-1, 1):
    x = s * 0.18
    strakes.box((min(x, x + s * 0.006), 0.03, -0.3), (max(x, x + s * 0.006), 0.04, 0.3), tar, leave=("west",) if s > 0 else ("east",))
piece("barge strakes@barge!fine", strakes)

# MARK: The commander's star

OUTLINE = []
for index in range(10):
    angle = index / 10 * 2 * math.pi
    radius = 0.05 if index % 2 == 0 else 0.021
    OUTLINE.append(Vector((radius * math.sin(angle), radius * math.cos(angle))))
star = Shape()
# Its light cut from its heart out to each point (the game's was cut from
# its upper point, which filled the notches either side of it).
for i in range(10):
    a, b = OUTLINE[i], OUTLINE[(i + 1) % 10]
    for z in (0.004, -0.004):
        star.face([(0.0, 0.0, z), (a.x, a.y, z), (b.x, b.y, z)], (0, 0, z), starlight)
# Its heart, lit brighter, a low boss on either face.
for k in range(10):
    a0, a1 = 2 * math.pi * k / 10, 2 * math.pi * (k + 1) / 10
    for z, apex in ((0.004, 0.0062), (-0.004, -0.0062)):
        star.face([(0.012 * math.sin(a0), 0.012 * math.cos(a0), z), (0.012 * math.sin(a1), 0.012 * math.cos(a1), z), (0.0, 0.0, apex)],
                  (0, 0, apex), moonsalt)
# The hair of gold round its edge, bevelled to a ridge either face, as
# broad across the face as the game meant it and as deep through (its
# strokes lay on their edges, some one way and some the other).
outer, inner = mitred(OUTLINE, 0.004, closed=True)
if outer[0].length < inner[0].length:
    outer, inner = inner, outer
for i in range(10):
    j = (i + 1) % 10
    m0, m1, o0, o1, i0, i1 = OUTLINE[i], OUTLINE[j], outer[i], outer[j], inner[i], inner[j]
    d = m1 - m0
    out = Vector((d.y, -d.x))
    if out.dot((m0 + m1) / 2) < 0:
        out = -out
    o3 = Vector((out.x, out.y, 0.0))
    star.face([(o0.x, o0.y, -0.003), (o1.x, o1.y, -0.003), (o1.x, o1.y, 0.003), (o0.x, o0.y, 0.003)], o3, gold)
    for z, ridge in ((0.003, 0.005), (-0.003, -0.005)):
        star.face([(o0.x, o0.y, z), (o1.x, o1.y, z), (m1.x, m1.y, ridge), (m0.x, m0.y, ridge)], o3 + Vector((0, 0, ridge)) * 200, gold)
        star.face([(m0.x, m0.y, ridge), (m1.x, m1.y, ridge), (i1.x, i1.y, z), (i0.x, i0.y, z)], -o3 + Vector((0, 0, ridge)) * 200, gold)
piece("commander star@commanderStar", star)

# MARK: The scaffold

POLE = 0.022
POSTS = [Vector(p) for p in ((-0.5, 0, -0.5), (0, 0, -0.52), (0.5, 0, -0.5), (0.52, 0, 0), (0.5, 0, 0.5), (0, 0, 0.52), (-0.5, 0, 0.5),
                             (-0.52, 0, 0))]
LIFTS = (0.34, 0.68, 1.0)
UP = Vector((0.0, 1.0, 0.0))


def ladder(shape, a, b, width, rungs, mat):
    """A ladder leaning from its foot to its head, as the game's."""
    a, b = V(a), V(b)
    along = b - a
    side = along.cross(UP).normalized() * (width / 2)
    rail = width * 0.12
    shape.beam(a + side, b + side, rail, mat)
    shape.beam(a - side, b - side, rail, mat)
    for index in range(1, max(rungs, 1) + 1):
        t = index / (rungs + 1)
        shape.beam(a + along * t - side, a + along * t + side, rail * 0.8, mat)


frame = Shape()
# The poles, their heads capped (the game's were open).
for post in POSTS:
    frame.limb(post - UP * 0.05, post + UP * 1.06, POLE, pale, caps=(False, True))
for level in LIFTS:
    for index in range(len(POSTS)):
        frame.limb(POSTS[index] + UP * level, POSTS[(index + 1) % len(POSTS)] + UP * level, POLE * 0.8, pale)
# Braces across each face.
for a, c in ((0, 2), (2, 4), (4, 6), (6, 0)):
    frame.limb(POSTS[a], POSTS[c] + UP * 0.68, POLE * 0.7, timber)
# Boards to walk on along the front and the right side, each laid in three
# planks; the front's butt against the side's (the game's two boards
# overlapped at the corner, their faces in one plane).
for level in (0.34, 0.68):
    for z0, z1 in ((0.44, 0.477), (0.4815, 0.5185), (0.523, 0.56)):
        frame.box((-0.5, level, z0), (0.44, level + 0.02, z1), grey, leave=("east",))
    for x0, x1 in ((0.44, 0.477), (0.4815, 0.5185), (0.523, 0.56)):
        frame.box((x0, level, -0.5), (x1, level + 0.02, 0.56), grey)
# The ladder up the front, its head resting against the upper boards' edge
# and standing above them (the game's ran up into the boards).
ladder(frame, (-0.3, 0.0, 0.62), (-0.3, 0.76, 0.5627), 0.12, 4, timber)
piece("scaffold@scaffold", frame)

# Close: rope lashed round every joint of pole and ledger, square to its
# pole (the game's was turned an eighth of a turn from it, the pole's
# corners through it); rails along the boards, meeting at the corner and
# capped (the game's ends stood open, short of each other); a ladder up the
# side resting against its boards; a hoist's beam out from a corner pole,
# its block, its rope and a bucket hung on it.
fine = Shape()
lashings = Shape()
for post in POSTS:
    for level in LIFTS:
        with lashings.placed(Matrix.Translation(post + UP * (level - 0.02))):
            lashings.tube([(POLE * 1.3, 0.0), (POLE * 1.3, 0.04)], 4, canvas)
for level in (0.34, 0.68):
    y = level + 0.16
    fine.limb((-0.51, y, 0.53), (0.535 + POLE * 0.6, y, 0.53), POLE * 0.6, timber, caps=(True, True))
    fine.limb((0.535, y, -0.51), (0.535, y, 0.53 + POLE * 0.6), POLE * 0.6, timber, caps=(True, True))
ladder(fine, (0.62, 0.0, -0.25), (0.5584, 0.42, -0.25), 0.12, 3, timber)
fine.limb((0.5, 0.98, 0.5), (0.68, 1.03, 0.68), POLE * 0.8, dark, caps=(False, True))
fine.block((0.66, 1.0, 0.66), (0.022, 0.03, 0.016), dark, turn=-math.pi / 4)
fine.limb((0.66, 1.0, 0.66), (0.66, 0.13, 0.66), 0.004, linen, sides=3)
with fine.placed(translation(0.66, 0.0, 0.66)):
    fine.lathe([(0.014, 0.075), (0.018, 0.115)], 6, dark, caps=(True, False))
for a, b in (((0.643, 0.114, 0.66), (0.66, 0.13, 0.66)), ((0.66, 0.13, 0.66), (0.677, 0.114, 0.66))):
    fine.limb(a, b, 0.0015, iron, sides=3)
piece("scaffold close@scaffold!fine", fine)
piece("scaffold lashings@scaffold!fine", lashings)

finish_building(out_path("Art/models/tokens.glb"), VARIANTS)
