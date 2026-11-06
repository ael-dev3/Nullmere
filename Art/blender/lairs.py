"""The lairs of the wilds and the gate of the Crown, each a variant of one
file, filling the heart of its hex (Sources/NullmereModels/Lairs.swift
built them in code):
- saltwights: a hollow crusted white, its rim heaped up and bristling
  with spars of moonsalt, bones about its floor and its cold heart lit;
  about it crystals grown in a ring and pale cairns. Close, a great
  beast's bones where it slid in head first, the husks the wights crawl
  out of, moonsalt grown on the floor, skulls by the heart and the arms of
  those who came for them, crusted white;
- reavers: a stockade of sharpened stakes round its fire, two hide tents
  and a trophy pole hung with antlers; about it more tents, a beached boat
  and its loot. Close, a beast on a spit over the fire, bedrolls, a rack
  of spears, the holds' plunder, a war drum, a chopping block and its axe,
  skulls on the stakes and the gate's posts and lintel under a horned
  skull;
- barrowkin: the hall of a barrow under its long mound, its kerb of
  stones, its way in dark between its posts and its cold light within,
  standing stones beside it; about it cairns and crooked headstones.
  Close, urns, a shield and a sword at its door, a skull in its passage, a
  rune glowing on its lintel, a dead tree on its mound with a raven in it
  and another on the lintel, headstones and a cairn;
- spineHunters: an eyrie of timber on its rock, a ladder up, hide
  windbreaks and pelts, the hunters' fire and a spear; about it racks of
  drying hides and bone totems. Close, the deck's planks and rails, a
  stag's skull and antlers, a bow and a quiver, furs, a horn, a basket on
  a rope and a hide stretched on its frame;
- drowned: a chapel half sunk in the strand, black water where its floor
  was, two pillars and what is left of their arch, fallen stones, reeds
  and pale lights over the water; about it broken columns hung with weed
  and pools. Close, its pews drowned in rows, its altar, its bell fallen,
  a font, steps down into the water, lilies and its yard's graves;
- gatehold: a gate of the Crown, two squat towers of rough stone either
  side of the pass, coursed and crowned with merlons, a gate of stakes
  under a lintel of logs between them, hides and shields hung toward the
  pass, wing walls into the peaks, a stair, a hunters' tent behind and
  their fire before it. Close, slits in the towers, a ladder, a hide
  banner and antlers on a pole, a fire on each tower, a horned skull over
  the gate and wood stacked by the fire.
Their fires (Lairs.fire(of:) and Lairs.gateFire, where smoke rises) and
wild lights are lit, and all of them stand still.

Points are the world's (y up, the front toward +z, in its units), built
as the game's MeshBuilder built them, each piece's triangles wound as its
were, and written in Blender's axes at ten times the size.

    python Art/blender/lairs.py Art/models/lairs.glb
"""
import contextlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *

import bmesh
import bpy
from mathutils import Matrix, Vector

reset()
VARIANTS = ["saltwights", "reavers", "barrowkin", "spineHunters", "drowned", "gatehold"]

# MARK: Materials

stone = material("plain_stone", (0.52, 0.51, 0.49))
stone_dark = material("plain_stone_dark", (0.37, 0.37, 0.38))
stone_pale = material("plain_stone_pale", (0.68, 0.67, 0.64))
rough = material("plain_stone_rock", (0.40, 0.40, 0.42))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
timber_dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
timber_pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
bark = material("plain_timber_bark", (0.21, 0.17, 0.14))
earth = material("plain_earth", (0.24, 0.21, 0.18))
loam = material("plain_earth_loam", (0.15, 0.13, 0.11))
madder = material("plain_madder", (0.44, 0.24, 0.19))
canvas = material("plain_canvas", (0.62, 0.58, 0.49))
linen = material("plain_linen", (0.70, 0.67, 0.60))
bone = material("plain_bone", (0.80, 0.78, 0.70))
soot = material("plain_soot", (0.11, 0.10, 0.10))
leather = material("plain_leather", (0.36, 0.25, 0.17))
leather_dark = material("plain_leather_dark", (0.22, 0.16, 0.12))
moss = material("plain_moss", (0.21, 0.26, 0.22))
crust = material("plain_saltcrust", (0.80, 0.83, 0.86))
straw = material("plain_thatch_straw", (0.62, 0.55, 0.36))
iron = material("metal_iron", (0.36, 0.37, 0.40), roughness=0.5, metallic=0.6)
bronze = material("metal_bronze", (0.55, 0.43, 0.26), roughness=0.4, metallic=0.7)
flame = material("glow_fire", (1.0, 0.68, 0.32))
moonsalt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)
# Palette colours the list above has no name for.
ash = material("plain_ash", (0.55, 0.56, 0.56))
fur = material("plain_fur", (0.33, 0.29, 0.25))
deadwood = material("plain_timber_deadwood", (0.70, 0.67, 0.61))
wild = material("glow_wildglow", (0.55, 0.95, 0.88))
grass = material("foliage_grass", (0.37, 0.41, 0.31))
reed = material("foliage_thatch_reed", (0.47, 0.45, 0.33))
# Colours mixed from the palette's, as Lairs.swift mixed them.
hide = material("plain_hide", (0.516, 0.448, 0.362))                # canvas.mix(leather, 0.4)
mossy = material("plain_stone_mossy", (0.539, 0.547, 0.514))         # stonePale.mix(moss, 0.3)
lichen = material("plain_lichen", (0.274, 0.32, 0.256))              # moss.mix(grass, 0.4)
salt_bone = material("plain_saltbone", (0.80, 0.7975, 0.756))        # bone.mix(saltCrust, 0.35)
horn_dark = material("plain_horn_dark", (0.5585, 0.542, 0.49))       # bone.mix(barkBlack, 0.35)
horn = material("plain_horn", (0.593, 0.576, 0.52))                  # bone.mix(barkBlack, 0.3)
husk = material("plain_husk", (0.74, 0.74, 0.70))                    # bone.mix(shroud, 0.5)
salt_wood = material("plain_saltwood", (0.572, 0.566, 0.554))        # timberGrey.mix(saltCrust, 0.4)
salt_iron = material("plain_saltiron", (0.58, 0.60, 0.63))           # iron.mix(saltCrust, 0.5)
salt_madder = material("plain_saltmadder", (0.656, 0.594, 0.592))    # madder.mix(saltCrust, 0.6)
roast = material("plain_roast", (0.319, 0.196, 0.1515))              # madder.mix(leatherDark, 0.55)
drumhead = material("plain_drumhide", (0.496, 0.418, 0.342))         # leather.mix(linen, 0.4)
urn = material("plain_urn", (0.31, 0.2205, 0.1835))                  # earth.mix(madder, 0.35)
rust = material("metal_rust", (0.384, 0.331, 0.337), roughness=0.6, metallic=0.5)  # iron.mix(madder, 0.3)
antler = material("plain_antler", (0.596, 0.552, 0.48))              # bone.mix(timber, 0.4)
rawhide = material("plain_rawhide", (0.462, 0.376, 0.299))           # leather.mix(linen, 0.3)
wet = material("plain_timber_wet", (0.154, 0.122, 0.1055))           # timberDark.mix(barkBlack, 0.45)
altar_stone = material("plain_stone_altar", (0.5625, 0.5675, 0.535))  # stonePale.mix(moss, 0.25)
bell_bronze = material("metal_mossbronze", (0.431, 0.3705, 0.246), roughness=0.5, metallic=0.6)  # bronze.mix(moss, 0.35)
lily = material("plain_lilypad", (0.185, 0.25, 0.195))               # moss.mix(leaf, 0.5)
black_water = material("plain_water_black", (0.03, 0.04, 0.05))      # Vec3(0.03, 0.04, 0.05)

# MARK: The game's noise

MASK = 0xFFFFFFFF


def unit(x, y, seed=0):
    """Noise.unit: a value from 0 up to 1 for a lattice point, as the game
    stirs it."""
    h = ((x & MASK) * 0x8DA6B343 & MASK) ^ ((y & MASK) * 0xD8163841 & MASK) ^ ((seed & MASK) * 0xCB1AB31F & MASK)
    h ^= h >> 13
    h = h * 0x5BD1E995 & MASK
    h ^= h >> 15
    return (h >> 8) / float(1 << 24)


# MARK: Building as the game's MeshBuilder builds

def V(x, y, z):
    return Vector((x, y, z))


UP = V(0, 1, 0)


def ring(radius, y, angle):
    """MeshBuilder.ring: angle zero due east, rising toward -z."""
    return V(radius * math.cos(angle), y, -radius * math.sin(angle))


def T(v):
    return Matrix.Translation(Vector(v))


def RX(a):
    return Matrix.Rotation(a, 4, "X")


def RY(a):
    return Matrix.Rotation(a, 4, "Y")


def RZ(a):
    return Matrix.Rotation(a, 4, "Z")


def S(x, y, z):
    return Matrix.Diagonal((x, y, z, 1.0))


def aligning_up(direction):
    """Mat4.aligningUp: the turn that carries straight up onto a direction."""
    d = Vector(direction).normalized()
    axis = UP.cross(d)
    cosine = min(max(UP.dot(d), -1.0), 1.0)
    if axis.length < 1e-6:
        return Matrix.Identity(4) if cosine > 0 else RX(math.pi)
    return Matrix.Rotation(math.acos(cosine), 4, axis.normalized())


class Builder:
    """The game's MeshBuilder: solids placed through a stack of the world's
    transforms, each triangle kept with its material and how far it sways,
    one piece's at a time."""

    def __init__(self):
        self.transform = Matrix.Identity(4)
        self.sway = 0.0
        self.sway_range = None
        self.triangles = []

    @contextlib.contextmanager
    def place(self, placement):
        saved = self.transform
        self.transform = saved @ placement
        try:
            yield self
        finally:
            self.transform = saved

    @contextlib.contextmanager
    def swaying(self, amount, low=None, high=None):
        """Sway from nothing at `low` to `amount` at `high` (squared), in
        the solid's own frame, or `amount` throughout."""
        saved = (self.sway, self.sway_range)
        self.sway, self.sway_range = amount, (low, high) if low is not None else None
        try:
            yield self
        finally:
            self.sway, self.sway_range = saved

    def sway_at(self, local):
        if self.sway_range and self.sway_range[1] > self.sway_range[0]:
            low, high = self.sway_range
            t = min(max((local.y - low) / (high - low), 0.0), 1.0)
            return self.sway * t * t
        return self.sway

    def triangle(self, a, b, c, mat):
        if self.transform.to_3x3().determinant() < 0:
            b, c = c, b
        pa, pb, pc = self.transform @ a, self.transform @ b, self.transform @ c
        # Triangles smaller than the game's least are dropped: a cone's point.
        if (pb - pa).cross(pc - pa).length <= 1e-9:
            return
        self.triangles.append(((pa, pb, pc), mat, (self.sway_at(a), self.sway_at(b), self.sway_at(c))))

    def quad(self, a, b, c, d, mat):
        self.triangle(a, b, c, mat)
        self.triangle(a, c, d, mat)

    def polygon(self, points, mat):
        for i in range(1, len(points) - 1):
            self.triangle(points[0], points[i], points[i + 1], mat)

    def face(self, points, outward, mat):
        n = (points[1] - points[0]).cross(points[2] - points[0])
        self.polygon(points if n.dot(outward) >= 0 else list(reversed(points)), mat)

    def box(self, low, high, mat):
        x0, y0, z0 = low
        x1, y1, z1 = high
        self.quad(V(x1, y0, z1), V(x1, y0, z0), V(x1, y1, z0), V(x1, y1, z1), mat)
        self.quad(V(x0, y0, z0), V(x0, y0, z1), V(x0, y1, z1), V(x0, y1, z0), mat)
        self.quad(V(x0, y1, z1), V(x1, y1, z1), V(x1, y1, z0), V(x0, y1, z0), mat)
        self.quad(V(x0, y0, z0), V(x1, y0, z0), V(x1, y0, z1), V(x0, y0, z1), mat)
        self.quad(V(x0, y0, z1), V(x1, y0, z1), V(x1, y1, z1), V(x0, y1, z1), mat)
        self.quad(V(x1, y0, z0), V(x0, y0, z0), V(x0, y1, z0), V(x1, y1, z0), mat)

    def block(self, centre, size, mat, turn=None):
        """A box about its centre; turned about the upright as the game's
        box(center:size:turn:) turns, if `turn` is given."""
        centre, size = Vector(centre), Vector(size)
        if turn is None:
            self.box(centre - size / 2, centre + size / 2, mat)
        else:
            with self.place(T(centre) @ RY(turn)):
                self.box(-size / 2, size / 2, mat)

    def lathe(self, profile, sides, mat, colours=None, twist=0.0, caps=(True, True)):
        step = 2 * math.pi / sides
        for band in range(len(profile) - 1):
            (r0, y0), (r1, y1) = profile[band], profile[band + 1]
            shade = colours[min(band, len(colours) - 1)] if colours else mat
            for side in range(sides):
                a0 = side * step + twist
                a1 = a0 + step
                self.quad(ring(r0, y0, a0), ring(r0, y0, a1), ring(r1, y1, a1), ring(r1, y1, a0), shade)
        bottom, top = profile[0], profile[-1]
        if caps[0] and bottom[0] > 1e-7:
            self.polygon([ring(bottom[0], bottom[1], k * step + twist) for k in reversed(range(sides))], colours[0] if colours else mat)
        if caps[1] and top[0] > 1e-7:
            self.polygon([ring(top[0], top[1], k * step + twist) for k in range(sides)], colours[-1] if colours else mat)

    def tube(self, profile, sides, mat, twist=0.0):
        self.lathe(profile, sides, mat, twist=twist, caps=(False, False))

    def cone(self, sides, radius, bottom, top, mat, twist=0.0):
        self.lathe([(radius, bottom), (0.0, top)], sides, mat, twist=twist)

    def sphere(self, centre, radius, rings, sides, mat, squash=1.0):
        profile = []
        for k in range(rings + 1):
            angle = math.pi * k / rings - math.pi / 2
            profile.append((radius * math.cos(angle), radius * squash * math.sin(angle)))
        with self.place(T(centre)):
            self.lathe(profile, sides, mat)

    def limb(self, a, b, radius, mat, top_radius=None, sides=4):
        """A limb or a haft, its ends open for the joints to hide."""
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        if length <= 0:
            return
        with self.place(T(a) @ aligning_up(b - a)):
            self.tube([(radius, 0.0), (radius if top_radius is None else top_radius, length)], sides, mat)

    def sheet(self, points, normal, mat, thickness=0.004):
        normal = Vector(normal)
        offset = normal.normalized() * (thickness / 2)
        self.face([Vector(p) + offset for p in points], normal, mat)
        self.face([Vector(p) - offset for p in points], -normal, mat)

    def beam(self, a, b, width, mat, depth=None):
        a, b = Vector(a), Vector(b)
        along = b - a
        length = along.length
        if length <= 0:
            return
        up = along / length
        reference = V(0, 0, 1) if abs(up.y) > 0.95 else UP
        side = up.cross(reference).normalized()
        front = side.cross(up)
        frame = Matrix(((side.x, up.x, front.x, a.x), (side.y, up.y, front.y, a.y), (side.z, up.z, front.z, a.z), (0, 0, 0, 1)))
        d = width if depth is None else depth
        with self.place(frame):
            self.box(V(-width / 2, 0, -d / 2), V(width / 2, length, d / 2), mat)

    def rock(self, centre, size, rings, sides, jitter, seed, mat):
        """A rough lump, each point pushed in or out as the game's noise
        pushes it for the seed."""
        centre = Vector(centre)
        grid = []
        for k in range(rings + 1):
            latitude = math.pi * k / rings - math.pi / 2
            pole = k == 0 or k == rings
            row = []
            for side in range(sides):
                longitude = 2 * math.pi * side / sides
                push = 1 + jitter * (2 * unit(k, 0 if pole else side, seed) - 1)
                d = (math.cos(latitude) * math.cos(longitude), math.sin(latitude), -math.cos(latitude) * math.sin(longitude))
                row.append(centre + V(d[0] * size[0], d[1] * size[1], d[2] * size[2]) * push)
            grid.append(row)
        for k in range(rings):
            for side in range(sides):
                n = (side + 1) % sides
                self.quad(grid[k][side], grid[k][n], grid[k + 1][n], grid[k + 1][side], mat)

    def log(self, a, c, radius):
        """A log lying from one end to the other, its cut ends pale."""
        a, c = Vector(a), Vector(c)
        with self.place(T(a) @ aligning_up(c - a)):
            length, step = (c - a).length, 2 * math.pi / 5
            self.tube([(radius, 0.0), (radius, length)], 5, bark)
            self.polygon([ring(radius, 0, k * step) for k in reversed(range(5))], timber_pale)
            self.polygon([ring(radius, length, k * step) for k in range(5)], timber_pale)

    def ladder(self, a, b, width, rungs, mat):
        a, b = Vector(a), Vector(b)
        along = b - a
        side = along.cross(UP).normalized() * (width / 2)
        rail = width * 0.12
        self.beam(a + side, b + side, rail, mat)
        self.beam(a - side, b - side, rail, mat)
        for index in range(1, max(rungs, 1) + 1):
            t = index / (rungs + 1)
            self.beam(a + along * t - side, a + along * t + side, rail * 0.8, mat)

    def flag(self, top, width, height, mat, turn=0.0):
        """A cloth hanging from the top of a pole, out along +x turned by
        `turn` and down, still at the pole and free at its end."""
        with self.swaying(1.0, 0.0, width):
            with self.place(T(top) @ RY(turn) @ RZ(-math.pi / 2)):
                outline = [V(0, 0, 0), V(0, width, 0), V(height, width, 0), V(height, 0, 0)]
                self.sheet(outline, V(0, 0, 1), mat, thickness=max(width * 0.03, 0.004))

    def tied_sack(self, at_point, size, mat):
        with self.place(T(at_point) @ S(size, size, size)):
            self.lathe([(0.0, 0.0), (0.022, 0.004), (0.027, 0.02), (0.021, 0.036), (0.008, 0.044), (0.011, 0.05), (0.0, 0.052)], 6, mat)

    def take(self):
        made, self.triangles = self.triangles, []
        return made


b = Builder()


def emit(name):
    """The piece built since the last, as one object of its materials, its
    triangles as the game built them."""
    triangles = b.take()
    if not triangles:
        raise ValueError("nothing built for %s" % name)
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    materials = []
    for _, mat, _ in triangles:
        if mat not in materials:
            materials.append(mat)
    bm = bmesh.new()
    swaying = any(s > 0 for _, _, sways in triangles for s in sways)
    layer = bm.verts.layers.float.new("_SWAY") if swaying else None
    for corners, mat, sways in triangles:
        verts = []
        for p, s in zip(corners, sways):
            v = bm.verts.new(at(p.x, p.y, p.z))
            if layer is not None:
                v[layer] = max(0.0, min(1.0, s))
            verts.append(v)
        f = bm.faces.new(verts)
        f.material_index = materials.index(mat)
        f.smooth = False
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    return obj


def piece(name, variant, fine=False):
    return emit(tagged(name, [variant]) + ("!fine" if fine else ""))


def surface(triangles, x, z):
    """The top of these triangles (as the builder keeps them) over a point
    of the ground, or None where they are not."""
    best = None
    for (a, c, d), _, _ in triangles:
        ux, uz, vx, vz = c.x - a.x, c.z - a.z, d.x - a.x, d.z - a.z
        det = ux * vz - uz * vx
        if abs(det) < 1e-12:
            continue
        px, pz = x - a.x, z - a.z
        s, t = (px * vz - pz * vx) / det, (ux * pz - uz * px) / det
        if s >= -1e-9 and t >= -1e-9 and s + t <= 1 + 1e-9:
            y = a.y + s * (c.y - a.y) + t * (d.y - a.y)
            best = y if best is None else max(best, y)
    return best


def resting(triangles, x, z, reach, sink=0.005):
    """How high a thing `reach` across stands at a point on these
    triangles: on the lowest of them under its foot, a little sunk so no
    edge of it floats; on the ground (zero) where any of its foot is off
    them."""
    lowest = None
    for k in range(9):
        dx, dz = (0.0, 0.0) if k == 0 else (reach * math.cos(k * math.pi / 4), reach * math.sin(k * math.pi / 4))
        y = surface(triangles, x + dx, z + dz)
        if y is None:
            return 0.0
        lowest = y if lowest is None else min(lowest, y)
    return max(lowest - sink, 0.0)


# MARK: Shared small things

def fire(at_point, size):
    """A fire of logs, its flames lit (still: lairs and gateholds stand
    still), tongues of flame licking up about its heart."""
    at_point = Vector(at_point)
    for index in range(4):
        angle = index * math.pi / 2 + 0.4
        b.log(at_point + ring(size, -0.01, angle), at_point + ring(size * 0.2, size * 0.6, angle + 0.3), size * 0.16)
    with b.place(T(at_point)):
        b.lathe([(size * 0.55, 0), (size * 0.75, size * 0.5), (size * 0.35, size * 1.1), (0, size * 1.7)], 6, flame)
    for index in range(5):
        angle = index * 1.26 + 0.6
        with b.place(T(at_point + ring(size * 0.42, size * 0.2, angle)) @ aligning_up(ring(0.35, 1, angle))):
            b.cone(4, size * 0.2, 0, size * (0.9 + 0.25 * (index % 2)), flame, twist=angle)


def wild_light(at_point, size):
    """A light of the wilds, pale and cold."""
    b.sphere(at_point, size, 3, 6, wild)


def stack(at_point, stones, jitter, sides, base=0.0):
    """Stones piled each on the last, from the bottom up, each (x offset,
    height of its middle, half-extents, seed, material) as the game laid
    them, but never so high that one stands clear of the stone below: its
    lower point sunk a third of its depth below the top point of that one,
    as the noise pushes their points (two bands, poles at bands 0 and 2)."""
    top = None
    for offset, height, size, seed, mat in stones:
        low_push = 1 + jitter * (2 * unit(0, 0, seed) - 1)
        high_push = 1 + jitter * (2 * unit(2, 0, seed) - 1)
        centre = base + height
        if top is not None:
            centre = min(centre, top + size[1] * low_push * 0.65)
        top = centre + size[1] * high_push
        b.rock(V(at_point[0] + offset, centre, at_point[2]), size, 2, sides, jitter, seed, mat)


def cairn(at_point, mat, seed, base=0.0):
    """A cairn of piled stones."""
    stones = []
    for index in range(5):
        size = 0.035 - index * 0.005
        stones.append((0.008 * (index % 2), 0.02 + index * 0.03, (size, size * 0.7, size), (seed + index * 13) & MASK, mat))
    stack(at_point, stones, 0.25, 6, base=base)


def crystal(radius, tall, mat=moonsalt):
    """A six-sided spar of moonsalt and its point, as one solid, about the
    placement's upright."""
    b.lathe([(radius, 0.0), (radius, tall * 0.75), (0.0, tall)], 6, mat)


def skull(at_point, facing, size, mat=bone):
    """A skull, its face toward `facing` (about the upright, as the ring's
    angles run), `size` its half-height."""
    with b.place(T(at_point) @ RY(facing)):
        b.sphere(V(0, 0, 0), size, 3, 6, mat)
        for side in (-1, 1):
            b.block((size * 0.85, size * 0.15, side * size * 0.38), (size * 0.35, size * 0.3, size * 0.3), soot)
        b.block((size * 0.5, -size * 0.75, 0), (size * 0.6, size * 0.4, size * 0.9), mat)


def horns(at_point, side, size, mat):
    """A pair of horns curling up and back from either side of a point,
    along `side` across the head."""
    at_point, side = Vector(at_point), Vector(side)
    for flank in (-1, 1):
        root = at_point + side * (flank * size * 0.6)
        bend = root + side * (flank * size * 1.2) + V(0, size * 1.1, 0)
        b.limb(root, bend, size * 0.28, mat, top_radius=size * 0.18)
        b.limb(bend, bend + side * (flank * size * 0.2) + V(0, size * 1.3, 0) - side.cross(UP) * (size * 0.6), size * 0.18, mat,
               top_radius=size * 0.04)


def raven(at_point, facing, seed):
    """A raven perched, looking along `facing`."""
    with b.place(T(at_point) @ RY(facing)):
        b.rock((0, 0.016, 0), (0.021, 0.013, 0.012), 3, 5, 0.06, seed, soot)
        b.sphere(V(0.018, 0.03, 0), 0.009, 3, 5, soot)
        with b.place(T((0.025, 0.029, 0)) @ RZ(-math.pi / 2)):
            b.cone(4, 0.0035, 0, 0.014, ash)
        b.sheet([V(-0.017, 0.014, -0.007), V(-0.017, 0.014, 0.007), V(-0.042, 0.006, 0.006), V(-0.042, 0.006, -0.006)], UP, soot)
        for z in (-0.004, 0.004):
            b.limb((0.002, 0.006, z), (0.004, 0.0, z), 0.0012, ash, sides=3)


def headstone(at_point, turn, lean):
    """A headstone leaning in the grass, moss on its face."""
    with b.place(T(at_point) @ RY(turn) @ RX(lean)):
        b.block((0, 0.035, 0), (0.05, 0.08, 0.014), stone)
        # Its rounded top a little thinner than the slab, so their faces
        # never lie in one plane.
        with b.place(T((0, 0.075, 0)) @ RX(math.pi / 2)):
            b.lathe([(0.025, -0.0066), (0.025, 0.0066)], 6, stone)
        b.block((-0.01, 0.012, 0.0075), (0.02, 0.016, 0.002), lichen)


def barrel(at_point, turn):
    """A barrel of timber hooped with iron (Stores.barrel)."""
    with b.place(T(at_point) @ RY(turn)):
        b.lathe([(0.026, 0), (0.032, 0.035), (0.026, 0.07)], 7, timber_pale)
        for y in (0.012, 0.058):
            b.lathe([(0.03, y - 0.004), (0.031, y + 0.004)], 7, iron)


def crystals(at_point, count, height, seed, ground=None):
    """Moonsalt grown in clustered six-sided spars (Land.crystals), each
    foot sunk into the ground under it (`ground(x, z)`, if given)."""
    at_point = Vector(at_point)
    for index in range(count):
        u, v = unit(index, 7, seed), unit(index, 8, seed)
        foot = at_point + V((u - 0.5) * 0.12, -0.02, (v - 0.5) * 0.12)
        if ground is not None:
            foot.y = ground(foot.x, foot.z) - 0.02
        lean = V((u - 0.5) * 0.8, 1, (v - 0.5) * 0.8)
        tall = height * (0.45 + 0.7 * unit(index, 9, seed))
        with b.place(T(foot) @ aligning_up(lean)):
            crystal(0.018 + 0.012 * u, tall)


def reeds(at_point, count, height, seed):
    """Reeds: thin blades rising from one root, bending in the wind (Land.reeds)."""
    at_point = Vector(at_point)
    with b.swaying(1.0, 0.0, height):
        for index in range(count):
            u, v = unit(index, 1, seed), unit(index, 2, seed)
            foot = at_point + V((u - 0.5) * 0.12, -0.03, (v - 0.5) * 0.12)
            tip = foot + V((u - 0.5) * 0.08, height * (0.7 + 0.5 * v), (v - 0.5) * 0.08)
            with b.place(T(foot) @ aligning_up(tip - foot)):
                b.cone(3, 0.009, 0, (tip - foot).length, reed if index % 3 == 0 else grass, twist=u * 3)


def tufts(at_point, count, spread, seed, ground=None):
    """Tufts of grey grass, each a few blades leaning out from its root
    (Land.grass), rooted in the ground under it (`ground(x, z)`, if given)."""
    at_point = Vector(at_point)
    with b.swaying(0.8, 0.0, 0.1):
        for index in range(count):
            u, v = unit(index, 5, seed), unit(index, 6, seed)
            root = at_point + V((u - 0.5) * 2 * spread, -0.015, (v - 0.5) * 2 * spread)
            if ground is not None:
                root.y = ground(root.x, root.z) - 0.015
            for blade in range(4):
                angle = blade * 1.7 + u * 6
                tip = root + ring(0.035, 0.07 + 0.04 * unit(index, blade, seed), angle)
                with b.place(T(root) @ aligning_up(tip - root)):
                    b.cone(3, 0.011, 0, (tip - root).length, grass if blade % 2 == 0 else reed, twist=angle)


def swift_round(x):
    """Rounded to the nearest, halves away from zero, as Swift rounds."""
    return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)


# MARK: The outskirts

RING = [ring(0.46, 0, k * math.pi / 4 + 0.2) for k in range(8)]
# The ground each lair's heart lays down (its hollow, floor, mound or
# rocks), as triangles, for what stands about it to stand on.
GROUND = {}


def outskirts(kind):
    """About each lair, the ground its wilds have made their own, each
    piece standing on the lair's own ground where it reaches under it (the
    game's sank many in the hollow's rim, the mound and the rocks)."""
    ground = GROUND.get(kind, [])

    def height(x, z):
        y = surface(ground, x, z)
        return 0.0 if y is None else y

    if kind == "saltwights":
        for index, p in enumerate(RING):
            crystals(p, 3 + index % 3, 0.08 + 0.02 * (index % 3), 700 + index, ground=height)
        for index in range(3):
            p = RING[index * 3 % 8] * 0.8
            cairn(p, crust, 710 + index, base=resting(ground, p.x, p.z, 0.035))
    elif kind == "reavers":
        for p in (RING[1], RING[3]):
            with b.place(T(p)):
                b.cone(7, 0.08, 0, 0.13, hide)
                b.limb((0, 0.1, 0), (0, 0.17, 0), 0.003, timber_dark)
        # The beached boat laid on its keel (the game stood it on end), sunk
        # in the floor to its widest, its deck flat and its mast up; drawn
        # in a little from the gateway it would have lain across.
        hull = RING[6] + V(0.06, 0, -0.04)
        with b.place(T((hull.x, height(hull.x, hull.z), hull.z)) @ RY(0.6)):
            with b.place(RZ(-math.pi / 2)):
                b.lathe([(0.0, -0.12), (0.035, -0.08), (0.045, 0.0), (0.035, 0.08), (0.0, 0.12)], 6, timber, twist=math.pi / 6)
            b.limb((0, 0, 0), (0, 0.14, 0), 0.004, timber_dark)
        # The loot heaped by it, on the floor (the game sank it in), its
        # bronze shining as metal (the game's was plain).
        for index in range(4):
            p = RING[7] + V(index * 0.03, 0, 0.02 * (index % 2))
            with b.place(T((p.x, height(p.x, p.z), p.z))):
                b.lathe([(0.018, 0), (0.022, 0.025), (0.018, 0.045)], 6, timber if index % 2 == 0 else bronze)
    elif kind == "barrowkin":
        for index in range(4):
            for p, mat, seed in ((RING[index * 2], stone, 720 + index), (RING[index * 2] * 0.82 + V(0.04, 0, 0), stone_dark, 725 + index)):
                cairn(p, mat, seed, base=resting(ground, p.x, p.z, 0.035))
        for index in range(8):
            p = RING[index] * (0.68 if index % 2 == 0 else 1)
            headstone((p.x, resting(ground, p.x, p.z, 0.026), p.z), float(index), 0.15 * (index % 3 - 1))
    elif kind == "spineHunters":
        for p in (RING[1], RING[2], RING[5], RING[6]):
            for x in (-0.05, 0.05):
                b.limb(p + V(x, 0, 0), p + V(x, 0.14, 0), 0.005, timber_dark)
            b.beam(p + V(-0.06, 0.13, 0), p + V(0.06, 0.13, 0), 0.006, timber_dark)
            b.block(p + V(0, 0.08, 0.004), (0.09, 0.08, 0.004), fur)
        for p in (RING[0], RING[3], RING[4], RING[7]):
            foot = V(p.x, resting(ground, p.x, p.z, 0.006, sink=0.012), p.z)
            b.limb(foot, foot + V(0, 0.2, 0), 0.006, bone)
            skull(foot + V(0, 0.21, 0), 0, 0.03)
            horns(foot + V(0, 0.16, 0), (1, 0, 0), 0.04, bone)
            c = p + V(0.05, 0, 0.03)
            cairn(c, bone, 740 + int(p.x * 100), base=resting(ground, c.x, c.z, 0.035))
    elif kind == "drowned":
        for index, p in enumerate(RING):
            at_point = p * (1 if index % 2 == 0 else 0.75)
            with b.place(T(at_point)):
                b.lathe([(0.03, 0), (0.026, 0.06 + 0.04 * (index % 3)), (0.024, 0.07 + 0.04 * (index % 3))], 8, mossy)
            b.limb(at_point + V(0.026, 0.06, 0), at_point + V(0.03, 0.0, 0.01), 0.004, moss, sides=3)
        for index, p in enumerate(RING):
            if index % 2 == 1:
                with b.place(T(p)):
                    b.lathe([(0.07, 0.002), (0.0, 0.004)], 9, slate)
                reeds(p + V(0.06, 0, 0), 4, 0.08, 730 + index)


# MARK: The Saltwights' hollow

PIT = [(0.0, -0.06), (0.3, -0.04), (0.42, 0.05), (0.52, 0.09), (0.62, 0.02)]


def pit_floor(radius):
    """The hollow's floor at a distance from its heart."""
    for index in range(1, len(PIT)):
        if radius <= PIT[index][0]:
            (r0, y0), (r1, y1) = PIT[index - 1], PIT[index]
            return y0 + (y1 - y0) * (radius - r0) / (r1 - r0)
    return 0.02


def salt_hollow():
    # A pit crusted white, its rim heaped up: rounder than the game's
    # eleven sides.
    b.lathe([(0.62, -0.1), (0.62, 0.02), (0.52, 0.09), (0.42, 0.05), (0.3, -0.04), (0.0, -0.06)], 22, crust,
            colours=[crust, crust, crust, ash, loam, loam])
    rim = GROUND["saltwights"] = list(b.triangles)
    # Spars of salt leaning out from the rim, the tallest by the pit, and
    # lesser spars grown at the foot of each, splayed to its sides.
    for index in range(9):
        angle = index / 9 * 2 * math.pi + 0.2
        lean = V(math.cos(angle) * 0.5, 1, -math.sin(angle) * 0.5)
        tall = 0.18 + 0.16 * unit(index, 2, 41)
        with b.place(T(ring(0.47, 0.04, angle)) @ aligning_up(lean)):
            b.lathe([(0.035, 0.0), (0.012, tall), (0.0, tall + 0.05)], 6, moonsalt)
        for flank in (-1, 1):
            u = unit(index, 3 + flank, 43)
            foot = ring(0.47 + 0.012 * flank, 0, angle + flank * (0.09 + 0.03 * u))
            foot.y = surface(rim, foot.x, foot.z) - 0.02
            with b.place(T(foot) @ aligning_up(lean + ring(0.35 * flank, 0, angle + math.pi / 2))):
                crystal(0.015 + 0.006 * u, 0.07 + 0.06 * u)
    # Bones about the pit, lying on its floor (the game's hung over it).
    for index in range(5):
        angle = index * 1.3 + 0.5
        p = ring(0.2 + 0.05 * (index % 2), -0.03, angle)
        q = p + ring(0.09, 0.01, angle + 1.2)
        p.y, q.y = surface(rim, p.x, p.z) + 0.005, surface(rim, q.x, q.z) + 0.005
        b.limb(p, q, 0.008, bone)
    # Its cold heart.
    wild_light((0, 0, 0), 0.07)


def hollow_near():
    def ground(x, z):
        return V(x, pit_floor(math.hypot(x, z)), z)
    # The beast, slid into the hollow head first: its spine along the
    # floor, its ribs rising from it and curling in, its horned skull at
    # the head.
    head, tail = ground(-0.29, -0.23), ground(-0.235, -0.02)
    along = (tail - head).normalized()
    side = along.cross(UP).normalized()
    for index in range(8):
        b.rock(head + (tail - head) * (0.1 + 0.115 * index) + V(0, 0.006, 0), (0.013, 0.011, 0.013), 2, 4, 0.15, index + 200, salt_bone)
    for index in range(5):
        p = head + (tail - head) * (0.22 + 0.11 * index) + V(0, 0.006, 0)
        reach = 0.085 - 0.008 * index
        for flank in (-1, 1):
            out = side * flank
            middle = p + out * (reach * 0.8) + V(0, reach * 0.7, 0)
            b.limb(p + out * 0.01, middle, 0.006, salt_bone, top_radius=0.005, sides=3)
            b.limb(middle, p + out * (reach * 0.45) + V(0, reach * 1.35, 0), 0.005, salt_bone, top_radius=0.003, sides=3)
    snout = math.atan2(along.z, -along.x)
    crown = head - along * 0.03 + V(0, 0.02, 0)
    with b.place(T(crown) @ RY(snout)):
        b.rock((0.012, 0, 0), (0.045, 0.024, 0.028), 3, 6, 0.08, 211, salt_bone)
        for flank in (-1, 1):
            b.block((0.018, 0.01, flank * 0.022), (0.012, 0.009, 0.006), soot)
    horns(crown + V(0, 0.012, 0) + along * 0.012, side, 0.035, horn_dark)
    # Husks the wights crawl out of, one split open along its back.
    for index, (x, z, turn) in enumerate(((0.08, 0.17, 0.4), (0.22, -0.02, 0.6), (-0.25, 0.17, 2.4))):
        with b.place(T(ground(x, z) + V(0, 0.018, 0)) @ RY(turn) @ RZ(-math.pi / 2 + 0.08)):
            b.lathe([(0.0, -0.055), (0.02, -0.045), (0.027, -0.01), (0.022, 0.03), (0.012, 0.05), (0.0, 0.058)], 6, husk)
            if index == 0:
                b.block((-0.024, 0, 0), (0.008, 0.07, 0.01), soot)
    # Moonsalt grown in two clusters on the floor, and skulls by its cold
    # heart.
    for cluster, centre in enumerate((ground(0.1, -0.125), ground(0.022, 0.118))):
        for index in range(4):
            angle = index * 1.9 + cluster
            tall = 0.035 + 0.025 * unit(index, cluster, 219)
            foot = centre + ring(0 if index == 0 else 0.022, -0.012, angle)
            with b.place(T(foot) @ aligning_up(ring(0.1 if index == 0 else 0.45, 1, angle))):
                crystal(0.011, tall)
    skull(ground(0.115, -0.035) + V(0, 0.012, 0), 2.6, 0.016, salt_bone)
    skull(ground(-0.108, 0.053) + V(0, 0.012, 0), 5.2, 0.016, salt_bone)
    # The arms of those who came for them: a spear stuck in the slope, a
    # shield sunk in it and a helm on the floor, all crusted white.
    foot, top = ring(0.4, pit_floor(0.4) - 0.01, 5.44), ring(0.33, pit_floor(0.4) + 0.25, 5.44)
    b.limb(foot, top, 0.006, salt_wood)
    with b.place(T(top) @ aligning_up(top - foot)):
        b.cone(4, 0.012, 0, 0.045, salt_iron)
    with b.place(T(ring(0.37, pit_floor(0.37) + 0.008, 3.34)) @ RY(3.34) @ RZ(0.65)):
        b.lathe([(0.045, -0.004), (0.045, 0.004), (0.0, 0.009)], 8, salt_madder)
    with b.place(T(ring(0.33, pit_floor(0.33) - 0.004, 5.0)) @ RZ(0.5)):
        b.lathe([(0.03, 0.0), (0.03, 0.012), (0.024, 0.03), (0.0, 0.036)], 7, salt_iron)


# MARK: The Reavers' stockade

def stake_height(index):
    return 0.26 + 0.05 * unit(index, 3, 17)


def stockade():
    b.lathe([(0.6, -0.1), (0.6, 0.0), (0.55, 0.012), (0.0, 0.015)], 12, earth)
    GROUND["reavers"] = list(b.triangles)
    # A ring of sharpened stakes, a gap for the gate toward +z.
    for index in range(22):
        angle = index / 22 * 2 * math.pi
        if abs(angle - 1.5 * math.pi) < 0.25:
            continue
        foot = ring(0.53, -0.04, angle)
        tall = stake_height(index)
        b.limb(foot, foot + V(0, tall, 0), 0.022, bark if index % 3 == 0 else timber_dark)
        with b.place(T(foot + V(0, tall, 0))):
            b.cone(4, 0.022, 0, 0.06, timber_pale)
    # Two hide tents, and a trophy pole hung with antlers.
    for p, turn in ((V(-0.25, 0, -0.18), 0.4), (V(0.24, 0, -0.2), -0.5)):
        with b.place(T(p) @ RY(turn)):
            b.cone(5, 0.15, 0, 0.24, leather)
            b.box(V(-0.03, 0, 0.11), V(0.03, 0.08, 0.13), leather_dark)
    b.limb((0.3, -0.02, 0.22), (0.3, 0.42, 0.22), 0.012, timber_dark)
    for side in (-1, 1):
        b.limb((0.3, 0.4, 0.22), (0.3 + side * 0.07, 0.48, 0.2), 0.007, bone)
        b.limb((0.3 + side * 0.04, 0.44, 0.215), (0.3 + side * 0.06, 0.5, 0.25), 0.005, bone)
    # Their fire, ringed with stones.
    for index in range(7):
        angle = index / 7 * 2 * math.pi
        b.rock(ring(0.11, 0.015, angle) + V(0, 0, 0.02), (0.03, 0.025, 0.03), 2, 4, 0.2, index + 70, stone_dark)
    fire((0, 0.01, 0.02), 0.07)


def stockade_near():
    g = 0.013
    # The spit on its forked posts, the beast on it, the crank.
    for x in (-0.11, 0.11):
        b.limb((x, g, 0.02), (x, 0.14, 0.02), 0.006, timber_dark)
        for z in (-0.015, 0.015):
            b.limb((x, 0.13, 0.02), (x, 0.165, 0.02 + z), 0.004, timber_dark, sides=3)
    b.limb((-0.14, 0.146, 0.02), (0.14, 0.146, 0.02), 0.004, iron)
    b.limb((0.14, 0.146, 0.02), (0.14, 0.12, 0.03), 0.003, iron)
    b.rock((0, 0.146, 0.02), (0.055, 0.028, 0.032), 3, 6, 0.12, 230, roast)
    # Bedrolls about the fire.
    for index, angle in enumerate((1.6, 4.0, 5.3)):
        along = ring(1, 0, angle + math.pi / 2)
        with b.place(T(ring(0.21, g + 0.016, angle) - along * 0.045) @ aligning_up(along)):
            b.lathe([(0.016, 0), (0.017, 0.045), (0.016, 0.09)], 6, fur if index == 1 else leather)
    # A rack of spears by the west tent.
    for x in (-0.4, -0.24):
        for z in (0.12, 0.18):
            b.limb((x, g, z), (x, 0.15, 0.15), 0.005, timber_dark, sides=3)
    b.limb((-0.42, 0.14, 0.15), (-0.22, 0.14, 0.15), 0.005, timber)
    for x in (-0.39, -0.35, -0.31, -0.27):
        foot, top = V(x, g, 0.21), V(x + 0.006, 0.26, 0.14)
        b.limb(foot, top, 0.004, timber_dark)
        with b.place(T(top) @ aligning_up(top - foot)):
            b.cone(4, 0.009, 0, 0.035, iron)
    # The plunder of the holds: barrels, crates, a sack and a chest.
    barrel((-0.05, g, -0.36), 0.3)
    barrel((0.02, g, -0.4), 1.1)
    b.block((0.07, g + 0.025, -0.33), (0.06, 0.05, 0.05), timber_pale, turn=0.4)
    b.block((0.07, g + 0.07, -0.33), (0.045, 0.04, 0.04), timber, turn=0.9)
    b.tied_sack((-0.1, g, -0.3), 1, canvas)
    b.block((0.13, g + 0.02, -0.41), (0.07, 0.04, 0.045), timber_dark, turn=-0.3)
    for offset in (-0.022, 0.022):
        with b.place(T((0.13, g + 0.02, -0.41)) @ RY(-0.3)):
            b.block((offset, 0, 0), (0.006, 0.042, 0.047), bronze)
    # A war drum, its head stretched over its body as one solid (the game's
    # head lay on a lid in all but the same plane), its sticks across it.
    with b.place(T((-0.17, g, 0.36))):
        b.lathe([(0.032, 0), (0.04, 0.035), (0.034, 0.07), (0.0, 0.072)], 7, timber, colours=[timber, timber, drumhead])
        b.limb((-0.03, 0.075, -0.01), (0.03, 0.078, 0.012), 0.003, timber_dark, sides=3)
        b.limb((-0.025, 0.075, 0.015), (0.035, 0.078, -0.005), 0.003, timber_dark, sides=3)
    # A chopping block, its cut top pale, its axe bitten in.
    with b.place(T((0.38, g, 0.06))):
        b.lathe([(0.035, 0), (0.035, 0.05), (0.0, 0.0505)], 7, bark, colours=[bark, timber_pale])
        b.limb((0.0, 0.055, 0.0), (0.04, 0.13, 0.01), 0.004, timber)
        b.block((-0.004, 0.056, -0.001), (0.03, 0.022, 0.005), iron)
    # Skulls on the stakes by the gate and one at the back, impaled on
    # their points (the game's sat lower, swallowed by the stakes).
    for index in (15, 18, 5):
        angle = index / 22 * 2 * math.pi
        skull(ring(0.53, -0.04 + stake_height(index) + 0.026, angle), angle, 0.024)
    # The gate's posts, its lintel and the horned skull over it.
    for angle in (1.5 * math.pi - 0.25, 1.5 * math.pi + 0.25):
        foot = ring(0.53, -0.04, angle)
        b.limb(foot, foot + V(0, 0.44, 0), 0.022, bark)
    b.beam((-0.155, 0.37, 0.514), (0.155, 0.37, 0.514), 0.035, timber_dark, depth=0.03)
    skull((0, 0.405, 0.52), 1.5 * math.pi, 0.02)
    horns((0, 0.415, 0.512), (1, 0, 0), 0.022, horn)


# MARK: The Barrowkin's hall

def barrow_hall():
    # The mound, long and low, grassed over (its grass rooted in it: the
    # game's was buried to its tips).
    with b.place(S(1.2, 1, 0.8)):
        b.lathe([(0.48, -0.1), (0.48, 0.0), (0.42, 0.12), (0.3, 0.22), (0.15, 0.27), (0.0, 0.28)], 12, moss)
    mound = GROUND["barrowkin"] = list(b.triangles)
    tufts((-0.2, 0.2, -0.1), 4, 0.15, 23, ground=lambda x, z: surface(mound, x, z) or 0.0)
    # Its kerb of stones, and the way in: dark between its posts.
    for index in range(10):
        angle = index / 10 * 2 * math.pi + 0.15
        b.rock(V(math.cos(angle) * 0.6, 0.0, -math.sin(angle) * 0.4), (0.05, 0.05, 0.04), 2, 4, 0.25, index + 90, stone)
    b.box((-0.11, -0.04, 0.24), (-0.07, 0.2, 0.36), stone_dark)
    b.box((0.07, -0.04, 0.24), (0.11, 0.2, 0.36), stone_dark)
    b.box((-0.13, 0.2, 0.24), (0.13, 0.25, 0.37), stone)
    b.box((-0.07, -0.02, 0.25), (0.07, 0.19, 0.27), soot)
    # Standing stones beside it, and the cold light within.
    for x, z, h in ((-0.42, 0.32, 0.32), (0.45, 0.3, 0.26)):
        with b.place(T((x, 0, z))):
            b.lathe([(0.05, -0.05), (0.055, h * 0.7), (0.0, h)], 4, stone_dark, twist=0.4)
    wild_light((0, 0.08, 0.3), 0.05)


def barrow_near():
    # Urns at its door, a shield and a sword on its threshold, a skull in
    # its passage and bones by it.
    for x, z in ((-0.2, 0.37), (0.17, 0.38)):
        with b.place(T((x, 0, z))):
            b.lathe([(0.0, 0.0), (0.02, 0.003), (0.03, 0.025), (0.022, 0.048), (0.013, 0.055), (0.017, 0.062), (0.0, 0.06)], 7, urn)
    with b.place(T((0.04, 0.004, 0.44)) @ RX(0.15)):
        b.lathe([(0.034, 0), (0.034, 0.005), (0.0, 0.008)], 8, leather_dark)
        b.cone(5, 0.009, 0.007, 0.015, iron)
    b.sheet([V(-0.12, 0.005, 0.455), V(-0.02, 0.005, 0.445), V(-0.02, 0.005, 0.453), V(-0.12, 0.005, 0.462)], UP, rust, thickness=0.002)
    b.block((-0.017, 0.006, 0.449), (0.006, 0.006, 0.04), rust)
    b.limb((-0.014, 0.006, 0.449), (0.012, 0.006, 0.447), 0.004, leather_dark)
    skull((0.035, 0.016, 0.345), 1.5 * math.pi + 0.3, 0.016)
    for a, c in (((0.09, 0.006, 0.47), (0.14, 0.006, 0.43)), ((0.1, 0.006, 0.44), (0.13, 0.008, 0.48))):
        b.limb(a, c, 0.005, bone, sides=3)
    # A rune along the lintel's face, glowing as the light within.
    b.block((0, 0.225, 0.3712), (0.15, 0.006, 0.003), wild)
    for x in (-0.06, -0.02, 0.02, 0.06):
        b.block((x, 0.228, 0.3712), (0.005, 0.018, 0.003), wild)
    # A dead tree on the mound, and the ravens.
    root = V(0.2, 0.235, -0.12)
    b.limb(root, root + V(0.02, 0.17, -0.01), 0.016, deadwood, top_radius=0.009, sides=5)
    for a, c in ((V(0.02, 0.12, -0.01), V(0.08, 0.2, -0.03)), (V(0.02, 0.15, -0.01), V(-0.05, 0.24, 0.02)),
                 (V(0.02, 0.17, -0.01), V(0.04, 0.26, -0.06)), (V(0.01, 0.09, -0.005), V(-0.06, 0.14, -0.04))):
        b.limb(root + a, root + c, 0.007, deadwood, top_radius=0.002, sides=3)
    raven(root + V(0.062, 0.176, -0.024), 0.4, 251)
    raven((-0.08, 0.25, 0.32), 1.5 * math.pi + 0.4, 252)
    # Headstones leaning before it, and a cairn by its western stone, its
    # stones resting on each other (the game's top stone floated).
    headstone((-0.2, 0, 0.5), 0.2, 0.18)
    headstone((0.28, 0, 0.47), -0.3, -0.12)
    headstone((0.12, 0, 0.53), 0.1, 0.25)
    stack((-0.32, 0, 0.44), [(0.004 * layer, 0.012 + 0.02 * layer, (size, size * 0.45, size * 0.85), layer + 260,
                              stone if layer % 2 == 0 else stone_dark) for layer, size in enumerate((0.03, 0.023, 0.016))], 0.15, 5)


# MARK: The Spine Hunters' eyrie

DECK = 0.4


def eyrie():
    # The rock it stands on.
    for p, size, seed in (((0, 0.12, -0.05), (0.42, 0.24, 0.36), 5), ((0.28, 0.06, 0.22), (0.2, 0.12, 0.18), 6),
                          ((-0.32, 0.05, 0.2), (0.18, 0.1, 0.16), 7)):
        b.rock(p, size, 3, 6, 0.18, seed, rough)
    GROUND["spineHunters"] = list(b.triangles)
    # A platform of timber on posts above the rock, and a ladder up from
    # the ground before the rock to the deck's edge by its front post (the
    # game's ran up inside the rock), a rung more for its length.
    for x, z in ((0.04, -0.2), (0.24, -0.2), (0.04, 0.0), (0.24, 0.0)):
        b.limb((x, 0.15, z), (x, DECK + 0.12, z), 0.012, timber)
    b.box((0.0, DECK, -0.24), (0.28, DECK + 0.02, 0.04), timber_pale)
    b.ladder(V(0.06, 0.0, 0.39), V(0.04, DECK, 0.04), 0.06, 6, timber)
    # Hide windbreaks on the deck, and pelts hung to dry.
    b.sheet([V(0.0, DECK, -0.24), V(0.28, DECK, -0.24), V(0.28, DECK + 0.12, -0.24), V(0.0, DECK + 0.14, -0.24)], (0, 0, 1), leather)
    for x in (0.06, 0.14, 0.22):
        b.sheet([V(x, DECK + 0.1, 0.04), V(x + 0.05, DECK + 0.1, 0.04), V(x + 0.04, DECK + 0.02, 0.04), V(x + 0.01, DECK + 0.02, 0.04)],
                (0, 0, 1), fur)
    # Their fire on the rock, set up to meet its slope (the game's flame
    # rose from inside the rock), smoke still rising from Lairs.fire's
    # point near its tip; and a spear stood by it.
    fire((-0.12, 0.262, 0.1), 0.05)
    b.limb((-0.22, 0.2, 0.0), (-0.2, 0.52, 0.02), 0.006, timber_dark)
    with b.place(T((-0.2, 0.52, 0.02))):
        b.cone(4, 0.012, 0, 0.05, iron)


def eyrie_near():
    top = 0.42
    # Its deck's planks and rails.
    for index in range(6):
        b.block((0.035 + 0.042 * index, top + 0.0005, -0.1), (0.003, 0.001, 0.276), timber_dark)
    for x in (0.04, 0.24):
        b.limb((x, 0.5, -0.2), (x, 0.5, 0.0), 0.006, timber)
        b.limb((x, 0.5, 0.0), (x, 0.502, 0.04), 0.005, timber)
    b.limb((0.02, 0.502, 0.04), (0.27, 0.502, 0.04), 0.005, timber)
    # The stag's skull and antlers on the windbreak.
    b.rock((0.14, 0.49, -0.226), (0.019, 0.026, 0.013), 3, 5, 0.08, 270, bone)
    for flank in (-1, 1):
        root = V(0.14 + flank * 0.012, 0.512, -0.226)
        beam = root + V(flank * 0.05, 0.085, 0.012)
        b.limb(root, beam, 0.004, antler, top_radius=0.0025, sides=3)
        b.limb(root + V(flank * 0.022, 0.035, 0.005), root + V(flank * 0.018, 0.075, 0.02), 0.0025, antler, top_radius=0.001, sides=3)
        b.limb(beam, beam + V(flank * 0.022, 0.025, -0.006), 0.0025, antler, top_radius=0.001, sides=3)
        b.limb(beam, beam + V(-flank * 0.008, 0.03, 0.004), 0.0025, antler, top_radius=0.001, sides=3)
    # A bow strung and leaning, and a quiver of arrows.
    bow = [V(0.235, top, -0.228), V(0.235, 0.46, -0.21), V(0.235, 0.52, -0.205), V(0.235, 0.565, -0.222)]
    for index in range(3):
        b.limb(bow[index], bow[index + 1], 0.003, timber_dark, sides=3)
    b.limb(bow[0], bow[3], 0.0009, linen, sides=3)
    with b.place(T((0.06, top, -0.215)) @ RX(-0.15)):
        b.lathe([(0.012, 0), (0.014, 0.07), (0.0, 0.0705)], 6, leather)
        for x, z in ((-0.004, 0.002), (0.005, -0.003), (0.0, 0.006)):
            b.limb((x, 0.07, z), (x * 1.5, 0.11, z * 1.5), 0.0015, timber_pale, sides=3)
            b.block((x * 1.5, 0.105, z * 1.5), (0.002, 0.012, 0.007), linen)
    # Furs on the deck to sleep on.
    b.rock((0.1, top + 0.004, -0.13), (0.06, 0.008, 0.045), 2, 6, 0.15, 271, fur)
    b.rock((0.19, top + 0.004, -0.09), (0.045, 0.007, 0.05), 2, 6, 0.15, 272, leather)
    # A horn hung by the ladder's head.
    b.limb((0.04, 0.49, 0.006), (0.04, 0.47, 0.014), 0.0012, leather_dark, sides=3)
    b.limb((0.055, 0.47, 0.016), (0.03, 0.455, 0.02), 0.008, bone, top_radius=0.005, sides=5)
    b.limb((0.03, 0.455, 0.02), (0.012, 0.468, 0.022), 0.005, bone, top_radius=0.002, sides=5)
    # A basket on a rope over the east edge, on a pole across the rail.
    b.limb((0.2, 0.505, -0.1), (0.36, 0.53, -0.1), 0.006, timber_dark)
    b.limb((0.355, 0.53, -0.1), (0.355, 0.365, -0.1), 0.0015, linen, sides=3)
    with b.place(T((0.355, 0.33, -0.1))):
        b.lathe([(0.0, 0.0), (0.025, 0.005), (0.03, 0.035)], 7, straw)
    # A hide stretched on its frame at the rock's foot.
    for x in (-0.18, -0.02):
        b.limb((x, 0, 0.42), (x, 0.2, 0.42), 0.006, timber)
    for y in (0.03, 0.185):
        b.limb((-0.19, y, 0.42), (-0.01, y, 0.42), 0.005, timber)
    b.sheet([V(-0.165, 0.045, 0.42), V(-0.035, 0.05, 0.42), V(-0.04, 0.17, 0.42), V(-0.16, 0.172, 0.42)], (0, 0, 1), rawhide)


# MARK: The drowned chapel

def chapel():
    # Still black water where its floor was, and two pillars, one leaning.
    b.lathe([(0.6, -0.1), (0.6, -0.005), (0.0, -0.004)], 12, loam)
    b.box((-0.34, -0.02, -0.2), (0.34, 0.0, 0.26), black_water)
    b.box((-0.3, -0.05, -0.05), (-0.2, 0.5, 0.05), stone_pale)
    with b.place(T((0.25, -0.05, 0)) @ RZ(-0.12)):
        b.box((-0.05, 0, -0.05), (0.05, 0.42, 0.05), stone_pale)
    # What is left of their arch, each stone turned to the curve (the
    # game's stood square), every other set a little back, and none with
    # its faces in the pillar's.
    for index in range(5):
        angle = math.pi - index * 0.32
        normal = math.atan2(math.sin(angle) / 0.18, math.cos(angle) / 0.25)
        with b.place(T((math.cos(angle) * 0.25, 0.5 + math.sin(angle) * 0.18, 0)) @ RZ(normal - math.pi / 2)):
            b.block((0, 0, 0), (0.08, 0.06, 0.104 if index % 2 == 0 else 0.096), stone if index % 2 == 0 else stone_pale)
    # Fallen stones, reeds through them, and pale lights over the water.
    for index, p in enumerate(((0.12, 0.02, 0.32), (-0.4, 0.02, 0.24), (0.42, 0.03, -0.22))):
        b.block(p, (0.12, 0.06, 0.08), stone, turn=index * 0.7)
    reeds((-0.42, 0, -0.3), 6, 0.2, 31)
    reeds((0.45, 0, 0.3), 5, 0.18, 32)
    for index, p in enumerate(((-0.1, 0.22, 0.1), (0.12, 0.3, -0.08), (0.02, 0.16, 0.18))):
        wild_light(p, 0.025 + 0.008 * index)


def chapel_near():
    # Its pews drowned in rows.
    for row, z in enumerate((-0.1, -0.02, 0.06, 0.14)):
        for side in (-1, 1):
            # One rotted quite away.
            if row == 2 and side > 0:
                continue
            sink = 0.01 * unit(row, 1 if side > 0 else 2, 263)
            with b.place(T((side * 0.1, -sink, z)) @ RZ(0.06 * side * ((row % 2) - 0.5))):
                b.block((0, 0.004, 0), (0.13, 0.01, 0.032), wet)
                b.block((0, 0.022, -0.017), (0.13, 0.04, 0.008), wet)
    # Its altar sunk at the head of them, and its bell fallen.
    b.block((0, 0.01, -0.165), (0.14, 0.06, 0.05), altar_stone)
    b.limb((-0.04, 0.044, -0.16), (0.03, 0.044, -0.17), 0.003, bronze)
    with b.place(T((0.24, 0.012, 0.18)) @ RY(0.7) @ RZ(1.35)):
        b.tube([(0.04, 0.0), (0.03, 0.03), (0.022, 0.06), (0.0, 0.07)], 8, bell_bronze)
    # A font, its bowl open on its black water (the game's lid hid it).
    with b.place(T((0.24, 0, -0.12))):
        b.lathe([(0.02, -0.02), (0.02, 0.05), (0.04, 0.06), (0.046, 0.085), (0.04, 0.085), (0.036, 0.074)], 7, stone_pale, caps=(True, False))
        b.lathe([(0.04, 0.08), (0.0, 0.081)], 7, black_water)
    # Steps going down into the water, the lower a little wider, so their
    # ends never lie in one plane.
    b.block((0, -0.008, 0.29), (0.22, 0.024, 0.05), stone_pale)
    b.block((0, -0.011, 0.252), (0.226, 0.026, 0.035), stone)
    # Lilies on the water, and its yard's graves on the bank.
    for index, (x, z) in enumerate(((-0.02, 0.21), (0.08, 0.2), (-0.13, 0.22), (-0.25, -0.14), (0.16, -0.16), (-0.27, 0.15))):
        with b.place(T((x, 0.001, z))):
            b.lathe([(0.022, 0.0), (0.022, 0.002), (0.0, 0.0025)], 6, lily)
            if index % 3 == 0:
                b.cone(5, 0.008, 0.002, 0.014, linen)
    headstone((-0.2, -0.004, 0.47), 0.3, 0.2)
    headstone((0.33, -0.004, 0.43), -0.4, -0.22)
    headstone((-0.47, -0.004, -0.08), 1.4, 0.3)


# MARK: The gatehold

TOWER = [(0.13, -0.04), (0.13, 0.0), (0.11, 0.34), (0.12, 0.36), (0.12, 0.38), (0.0, 0.38)]


def tower_radius(y):
    """The radius of a gatehold tower's wall at a height under its lip."""
    return 0.13 - 0.02 * y / 0.34


def gatehold():
    for side in (-1, 1):
        x = side * 0.3
        # A tower, a little narrower as it rises, its top ringed with
        # merlons squared to the ring (the game's stood askew) and set a
        # little into it.
        with b.place(T((x, 0, 0)) @ RY(side * 0.4)):
            b.lathe(TOWER, 7, stone, twist=0.12)
            for index in range(4):
                angle = index * math.pi / 2 + 0.3
                b.block(ring(0.095, 0.408, angle), (0.045, 0.06, 0.045), stone_dark, turn=angle)
        # A hide hung from its top toward the pass, clear of its wall (the
        # game's hung half inside it), and two shields hung on the hide
        # (the game's were buried in the wall behind it).
        top, low = x - side * 0.112, x - side * 0.126
        b.sheet([V(top, 0.34, 0.06), V(top, 0.34, -0.06), V(low, 0.16, -0.05), V(low, 0.17, 0.05)], (-side, 0, 0), leather)
        facing = V(-side * 0.18, 0.014, 0).normalized()
        for index, z in enumerate((0.031, -0.031)):
            on_hide = V(top + (low - top) * (0.34 - 0.255) / 0.18, 0.255, z)
            with b.place(T(on_hide + facing * 0.006) @ aligning_up(facing)):
                b.lathe([(0.03, -0.003), (0.03, 0.003)], 8, madder if index == 0 else leather)
        # Rubble fallen from the peaks.
        b.rock((x + side * 0.14, 0.03, 0.12), (0.1, 0.07, 0.09), 2, 5, 0.22, 41 if side > 0 else 42, rough)
    # The gate of stakes across the pass, the last leaning off the east
    # tower (the game's leaned into it), and the lintel above it.
    for index in range(7):
        x = index * 0.06 - 0.18
        lean = 0.02 if index % 2 == 0 and index < 6 else -0.02
        b.limb((x, -0.02, 0), (x + lean, 0.22, 0), 0.016, timber, top_radius=0.012)
        with b.place(T((x + lean, 0.22, 0))):
            b.cone(4, 0.012, 0, 0.04, timber_pale)
    b.beam((-0.21, 0.31, 0), (0.21, 0.31, 0), 0.03, timber_dark)
    b.limb((-0.19, 0.12, 0.012), (0.19, 0.12, 0.012), 0.01, timber_dark)
    # The hunters' fire before the gate, and a spear stood by it.
    fire((0.12, 0.0, 0.26), 0.05)
    b.limb((-0.08, 0.0, 0.3), (-0.06, 0.34, 0.31), 0.006, timber_dark)
    with b.place(T((-0.06, 0.34, 0.31))):
        b.cone(4, 0.012, 0, 0.05, iron)
    for side in (-1, 1):
        x = side * 0.3
        # The towers' courses of rough stone, ledges turned to the tower's
        # faces (the game's open bands were turned off them) and closed
        # back into its wall.
        for course in range(5):
            y, outer = 0.05 + course * 0.065, 0.133 - course * 0.004
            with b.place(T((x, 0, 0)) @ RY(side * 0.4)):
                b.lathe([(tower_radius(y) - 0.004, y), (outer, y + 0.001), (outer + 0.001, y + 0.008), (tower_radius(y + 0.009) - 0.004, y + 0.009)],
                        7, stone_dark, twist=0.12, caps=(False, False))
        # A wall running out from each into the peaks, footed below the
        # ground as the towers are, to stand on a slope.
        for index in range(4):
            along = x + side * (0.14 + index * 0.07)
            height = 0.18 - index * 0.0245
            b.block((along, (height - 0.04) / 2, -0.02), (0.075, height + 0.04, 0.07), stone if index % 2 == 0 else rough, turn=side * 0.1)
        # A stair up its inner side, each step built up from the ground and
        # run in to the wall (the game's floated a step apart).
        for step in range(5):
            front = -0.14 + step * 0.02
            back = front + (0.04 if step == 4 else 0.02)
            near, far = x - side * 0.09, x - side * 0.155
            b.box((min(near, far), -0.04, front), (max(near, far), 0.04 + step * 0.055, back), stone_pale)
    # A hunters' tent of hides behind the gate.
    with b.place(T((0.0, 0, -0.26))):
        b.cone(7, 0.1, 0, 0.18, leather)
        for index in range(4):
            b.limb((0, 0.15, 0), ring(0.025, 0.24, index * 1.6), 0.003, timber_dark)
    # Rubble along the way through, one stone rolled out of the fire it
    # lay in.
    for index in range(10):
        p = V(-0.45 + index * 0.1, 0, 0.18 + 0.12 * unit(index, 1, 61))
        if index == 6:
            p.z = 0.165
        b.rock(p + V(0, 0.015, 0), (0.03, 0.025, 0.03), 3, 6, 0.3, 60 + index, rough)


def gatehold_near():
    for side in (-1, 1):
        # The middle of the tower's face nearest each way.
        first, step = side * 0.4 + 0.12 + math.pi / 7, 2 * math.pi / 7
        for way in (0.5 * math.pi, 1.5 * math.pi):
            face = first + swift_round((way - first) / step) * step
            with b.place(T((side * 0.3, 0.22, 0)) @ RY(face)):
                b.block((0.1065, 0, 0), (0.006, 0.055, 0.012), soot)
        # A fire in each tower's top, set a hair into it.
        with b.place(T((side * 0.27, 0.378, 0.03))):
            b.lathe([(0.022, 0), (0.026, 0.018), (0.0, 0.055)], 5, flame)
    # A ladder up the west tower, the hunters' hide banner and antlers on a
    # pole over the east, a horned skull over the gate and wood stacked by
    # the fire.
    b.ladder(V(-0.3, 0, 0.21), V(-0.3, 0.37, 0.118), 0.06, 6, timber)
    b.limb((0.3, 0.38, -0.02), (0.3, 0.66, -0.02), 0.007, timber_dark)
    b.flag(V(0.302, 0.64, -0.02), 0.1, 0.12, leather)
    horns((0.3, 0.655, -0.02), (1, 0, 0), 0.02, antler)
    skull((0, 0.345, 0.004), 1.5 * math.pi, 0.02)
    horns((0, 0.355, -0.004), (1, 0, 0), 0.02, horn)
    for index, (y, z) in enumerate(((0.012, 0.33), (0.012, 0.36), (0.035, 0.345))):
        b.log((0.2, y, z), (0.3, y, z + 0.01 * (index % 2)), 0.012)


# MARK: Each lair and the gatehold, far and near

LAIRS = {"saltwights": (salt_hollow, hollow_near), "reavers": (stockade, stockade_near), "barrowkin": (barrow_hall, barrow_near),
         "spineHunters": (eyrie, eyrie_near), "drowned": (chapel, chapel_near)}
for kind, (heart, near) in LAIRS.items():
    heart()
    piece("lair", kind)
    outskirts(kind)
    piece("outskirts", kind)
    near()
    piece("lair close", kind, fine=True)
gatehold()
piece("gatehold", "gatehold")
gatehold_near()
piece("gatehold close", "gatehold", fine=True)

finish_building(out_path("Art/models/lairs.glb"), VARIANTS)
