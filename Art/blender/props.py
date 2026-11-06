"""What moves through the world apart from companies, each a variant of one
file, its origin and facing as the game has them (Props in
Sources/NullmereModels/Props.swift):
- the arrow in flight, its middle at the origin, pointing along +z: a shaft
  of pale timber nocked at its tail, a head of steel, three vanes of linen;
- the House's banner on its pole, on a footing of dark stone, a gilt
  finial over it; its cloth hangs from a yard and swings at idle;
- the night bird, black, its wings beating and gliding at idle and beating
  steadily on the wing;
- the carter's cart, its load under canvas in the House's colour, its bed
  on an axle-tree between two spoked wheels that roll on the march and
  stand still at idle;
- the iron brazier on three legs, its coals glowing in its open bowl, its
  fire leaping;
- the puff of smoke, three soft balls that rise and spread over the idle;
- the Mangonel's stone in flight, rough-hewn, its middle at the origin;
- the fisher's boat: an open hull of dark planks, its upper strake paler,
  floored and with three thwarts, a net heaped in the stern; its fisher
  hooded on the middle thwart at the oars, a lantern hung from a pole at
  the bow; it rocks and heaves, he leans into the oars, they dip and pull,
  the lantern swings on its hook;
- the builders' stores: sawn timber stacked on two bearers, squared stone
  blocks piled, a mallet laid on them;
- the waystone of the Spine's climb: a leaning slab on a cairn, cut with
  its stage's notches, its cap of moonsalt dark, or glowing once its stage
  is won (waystoneLit).
Close: the mallet's head, the cairn's loose stones, the boat's stem and
stern posts and the lantern's cap.

    python Art/blender/props.py Art/models/props.glb

Each is made as the game's MeshBuilder made it (MeshBuilder.swift and
Shapes.swift), in the world's axes and units and ten times larger, as every
building is. The moving parts are the rig's bones, each tagged for its
prop and named for the part it was in the game; every moving prop's first
part is its first bone (the cart's left wheel, the bird's left wing, the
puff's cloud). The base, which the banner's footing is skinned to so the
file carries a skeleton, is the banner's alone: the props that stand still
(the arrow, the stone, the stores and the waystones) have no bones at all,
and are drawn as still.
The idle is keyed at every frame of its four seconds, and the march, which
only the cart and the bird play their own way, at every frame of its one
("march@cart,bird"); the rest play the idle in the march's time.
"""
import math
import os
import sys
from contextlib import contextmanager

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import *

reset()
VARIANTS = ["arrow", "banner", "bird", "cart", "brazier", "puff", "stone", "boat", "materials", "waystone", "waystoneLit"]

stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
rock_stone = material("plain_stone_rock", (0.40, 0.40, 0.42))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
linen = material("plain_linen", (0.70, 0.67, 0.60))
bone_white = material("plain_bone", (0.80, 0.78, 0.70))
soot = material("plain_soot", (0.11, 0.10, 0.10))
wool = material("plain_wool", (0.39, 0.37, 0.33))
iron = material("metal_iron", (0.36, 0.37, 0.40), roughness=0.5, metallic=0.6)
steel = material("metal_steel", (0.62, 0.65, 0.70), roughness=0.4, metallic=0.7)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.4, metallic=0.8)
banner = material("cloth_banner", (0.78, 0.78, 0.78))
canvas = material("house_awning", (0.78, 0.78, 0.78))
fire = material("glow_fire", (1.0, 0.68, 0.32))
candle = material("glow_candle", (1.0, 0.80, 0.52))
moonsalt = material("glow_moonsalt", (0.88, 0.91, 0.95))
# Colours of the game's own that no shared name gives: the bird's black,
# the smoke, the fisher's dark wool and skin, the net (linen in shadow) and
# the unlit cap (salt crust dimmed).
feather = material("plain_feather", (0.12, 0.12, 0.13))
smoke = material("plain_smoke", (0.62, 0.63, 0.65))
dark_wool = material("plain_wooldark", (0.24, 0.24, 0.25))
skin = material("plain_skin", (0.74, 0.60, 0.50))
net = material("plain_net", (0.42, 0.402, 0.36))
dim_salt = material("plain_saltcrust_dim", (0.32, 0.332, 0.344))


# MARK: The game's MeshBuilder, in the world's axes and units

def V(p):
    return Vector((float(p[0]), float(p[1]), float(p[2])))


def translation(x, y, z):
    return Matrix.Translation((x, y, z))


def turn_x(a):
    return Matrix.Rotation(a, 4, "X")


def turn_y(a):
    return Matrix.Rotation(a, 4, "Y")


def turn_z(a):
    return Matrix.Rotation(a, 4, "Z")


def scale(x, y, z):
    return Matrix.Diagonal((x, y, z, 1.0))


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
        return Matrix.Identity(4) if cosine > 0 else turn_x(math.pi)
    return Matrix.Rotation(math.acos(cosine), 4, axis.normalized())


def noise_unit(x, y, seed):
    """Noise.unit: a value from 0 up to 1 for a lattice point."""
    m = 0xFFFFFFFF
    h = ((x & m) * 0x8DA6B343 & m) ^ ((y & m) * 0xD8163841 & m) ^ ((seed & m) * 0xCB1AB31F & m)
    h ^= h >> 13
    h = (h * 0x5BD1E995) & m
    h ^= h >> 15
    return (h >> 8) / float(1 << 24)


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
        """A flat face turned, if need be, to look along `outward`."""
        p = [V(q) for q in points]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        self.polygon(p if n.dot(V(outward)) >= 0 else list(reversed(p)), mat)

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
        with self.placed(translation(*centre) @ turn_y(turn)):
            self.box(tuple(-s / 2 for s in size), tuple(s / 2 for s in size), mat, leave)

    def lathe(self, profile, sides, mat, twist=0.0, caps=(True, True), cap_mats=(None, None), band_mats=None):
        """A solid turned about the upright from its profile, bottom to
        top, (radius, height) a ring; ends with a radius capped."""
        step = 2 * math.pi / sides
        for band in range(len(profile) - 1):
            (r0, y0), (r1, y1) = profile[band], profile[band + 1]
            shade = band_mats[min(band, len(band_mats) - 1)] if band_mats else mat
            for side in range(sides):
                a0 = side * step + twist
                a1 = a0 + step
                self.quad(ring(r0, y0, a0), ring(r0, y0, a1), ring(r1, y1, a1), ring(r1, y1, a0), shade)
        if caps[0] and profile[0][0] > 0:
            r, y = profile[0]
            self.polygon([ring(r, y, s * step + twist) for s in reversed(range(sides))], cap_mats[0] or mat)
        if caps[1] and profile[-1][0] > 0:
            r, y = profile[-1]
            self.polygon([ring(r, y, s * step + twist) for s in range(sides)], cap_mats[1] or mat)

    def tube(self, profile, sides, mat, twist=0.0):
        self.lathe(profile, sides, mat, twist, caps=(False, False))

    def prism(self, sides, radius, bottom, top, mat, top_radius=None, twist=0.0, caps=(True, True)):
        self.lathe([(radius, bottom), (radius if top_radius is None else top_radius, top)], sides, mat, twist, caps)

    def cone(self, sides, radius, bottom, top, mat, twist=0.0, caps=(True, True)):
        self.lathe([(radius, bottom), (0.0, top)], sides, mat, twist, caps)

    def sphere(self, centre, radius, rings, sides, mat):
        profile = []
        for k in range(rings + 1):
            angle = math.pi * k / rings - math.pi / 2
            profile.append((0.0 if k in (0, rings) else radius * math.cos(angle), radius * math.sin(angle)))
        with self.placed(translation(*centre)):
            self.lathe(profile, sides, mat)

    def limb(self, a, b, radius, mat, sides=4, top_radius=None, caps=(False, False), cap_mats=(None, None)):
        """A haft from one point to another, its ends open unless capped."""
        a, b = V(a), V(b)
        length = (b - a).length
        if length <= 0:
            return
        with self.placed(Matrix.Translation(a) @ aligning_up(b - a)):
            self.lathe([(radius, 0.0), (radius if top_radius is None else top_radius, length)], sides, mat, caps=caps, cap_mats=cap_mats)

    def sheet(self, points, normal, mat, thickness=0.004):
        """A thin flat thing seen from both sides, as the game's sheet."""
        n = V(normal).normalized()
        offset = n * (thickness / 2)
        self.face([V(p) + offset for p in points], n, mat)
        self.face([V(p) - offset for p in points], -n, mat)

    def slab(self, outline, normal, thickness, mat):
        """A flat piece cut to `outline` (in one plane), raised `thickness`
        along `normal`, closed all round."""
        n = V(normal).normalized()
        low = [V(p) for p in outline]
        high = [p + n * thickness for p in low]
        self.face(high, n, mat)
        self.face(low, -n, mat)
        middle = sum(low, Vector()) / len(low)
        for i in range(len(low)):
            j = (i + 1) % len(low)
            out = (low[i] + low[j]) / 2 - middle
            self.face([low[i], low[j], high[j], high[i]], out - n * out.dot(n), mat)

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
        return obj


# MARK: The rig: every moving prop's parts, each its own bones

# One turn of the cart's wheels each march period covers a man's march
# (Gait().marchSpeed: two strides of 0.46 at 0.45 radians, a man 0.3 tall).
MARCH = 2 * 2 * 0.46 * math.sin(0.45) * 0.3 / 1.0
RADIUS = MARCH * 1.0 / (2 * math.pi)
AXLE = (0.0, RADIUS, -0.02)
BASE = "base@banner"
UP, ACROSS, ALONG = (0, 1, 0), (1, 0, 0), (0, 0, 1)
# Each part as (bone, pivot, the axis its bone runs along, parent), in the
# world's axes and units, at its pivot in the game.
PARTS = [(BASE, (0.0, 0.0, 0.0), UP, None),
         ("cloth@banner", (0.0, 0.6, 0.0), UP, None),
         ("wing left@bird", (0.012, 0.0, 0.0), ALONG, None),
         ("wing right@bird", (-0.012, 0.0, 0.0), ALONG, None),
         ("wheel left@cart", (0.1, RADIUS, -0.02), ACROSS, None),
         ("wheel right@cart", (-0.1, RADIUS, -0.02), ACROSS, None),
         ("fire@brazier", (0.0, 0.17, 0.0), UP, None),
         ("cloud@puff", (0.0, 0.0, 0.0), UP, None),
         ("hull@boat", (0.0, 0.0, 0.0), UP, None),
         ("fisher@boat", (0.0, 0.05, -0.01), UP, "hull@boat"),
         ("oar left@boat", (0.07, 0.06, 0.0), ACROSS, "fisher@boat"),
         ("oar right@boat", (-0.07, 0.06, 0.0), ACROSS, "fisher@boat"),
         # Hung from the pole's tip, where its hook is (the game turned it
         # about a point in the air beside the hook).
         ("lantern@boat", (0.0, 0.22, 0.22), UP, "hull@boat")]


def blender(v):
    """A direction of the world's in Blender's axes."""
    return Vector((v[0], -v[2], v[1]))


rig = armature("Props", [(bone, tuple(at(*pivot)), tuple(at(*pivot) + blender(axis).normalized() * 0.2), parent)
                         for bone, pivot, axis, parent in PARTS])


def piece(name, shape, bone=None):
    """A shape made a piece, carried by a bone if it moves."""
    obj = shape.make(name)
    if bone:
        on(obj, rig, bone)
    return obj


# MARK: The arrow

arrow = Shape()
arrow.limb((0, 0, -0.13), (0, 0, 0.11), 0.006, pale, sides=3, caps=(True, False))
with arrow.placed(translation(0, 0, 0.1) @ turn_x(math.pi / 2)):
    arrow.cone(3, 0.014, 0.0, 0.045, steel)
for angle in (0.0, 2 * math.pi / 3, 4 * math.pi / 3):
    with arrow.placed(turn_z(angle)):
        arrow.sheet([(0, 0.004, -0.13), (0, 0.022, -0.125), (0, 0.012, -0.08), (0, 0.004, -0.085)], (1, 0, 0), linen, thickness=0.002)
piece("arrow@arrow", arrow)

# MARK: The Mangonel's stone

hurled = Shape()
hurled.rock((0, 0, 0), (0.03, 0.027, 0.03), 3, 6, 0.15, 11, stone)
piece("stone@stone", hurled)

# MARK: The banner

# Its footing, skinned whole to the base: the skeleton's one still bone.
footing = Shape()
footing.lathe([(0.03, -0.05), (0.03, 0.02)], 5, dark_stone)
ground(footing.make("banner footing@banner"), rig).vertex_groups["base"].name = BASE
post = Shape()
post.limb((0, 0, 0), (0, 0.62, 0), 0.011, dark, sides=5)
with post.placed(translation(0, 0.62, 0)):
    post.cone(4, 0.018, 0.0, 0.05, gold)
piece("banner@banner", post)
yard = Shape()
yard.beam((0, 0.6, 0), (0, 0.6, -0.2), 0.012, dark)
TOP, WIDTH = (0.0, 0.595, -0.005), 0.2
cloth = flag("banner flag", TOP, WIDTH, 0.28, banner, turn=math.pi / 2, thickness=max(WIDTH * 0.03, 0.004))
# It moves as the game's did: from nothing at the pole to all of it at its
# end, as the square of the way out.
sway(cloth, lambda q: max(0.0, min(1.0, (q.y / UNIT + TOP[2]) / WIDTH)) ** 2)
on(join("banner cloth@banner", [cloth, yard.make("banner yard")]), rig, "cloth@banner")

# MARK: The bird

bird = Shape()
with bird.placed(turn_x(math.pi / 2)):
    bird.lathe([(0.0, -0.06), (0.016, -0.03), (0.018, 0.0), (0.012, 0.03), (0.0, 0.05)], 4, feather)
bird.sheet([(0, 0, -0.05), (0.022, 0, -0.085), (-0.022, 0, -0.085)], (0, 1, 0), feather)
# Its beak set into its head (the game's stood off its tip).
bird.block((0, 0.002, 0.056), (0.006, 0.006, 0.014), bone_white)
piece("bird@bird", bird)
for side, name in ((1, "left"), (-1, "right")):
    wing = Shape()
    wing.sheet([(side * 0.012, 0, 0.022), (side * 0.07, 0, 0.012), (side * 0.13, 0, -0.03), (side * 0.06, 0, -0.035),
                (side * 0.012, 0, -0.02)], (0, 1, 0), feather, thickness=0.003)
    piece("bird wing %s@bird" % name, wing, "wing %s@bird" % name)

# MARK: The cart

R = RADIUS
cart = Shape()
cart.box((-0.085, R + 0.02, -0.15), (0.085, R + 0.04, 0.12), pale)
for x in (-0.088, 0.088):
    cart.box((x - 0.006, R + 0.04, -0.15), (x + 0.006, R + 0.09, 0.12), timber)
    cart.beam((x * 0.8, R + 0.03, 0.12), (x * 0.5, R - 0.01, 0.32), 0.012, timber, ends=(False, True))
# The load under its canvas, its floor hidden on the bed.
with cart.placed(translation(0, R + 0.04, -0.015) @ scale(1, 1, 1.5)):
    cart.lathe([(0.08, 0.0), (0.075, 0.05), (0.04, 0.09), (0.0, 0.1)], 6, canvas, caps=(False, False))
# The axle-tree under the bed, from wheel to wheel: the game's wheels were
# held by nothing.
cart.box((-0.09, R - 0.009, AXLE[2] - 0.009), (0.09, R + 0.02, AXLE[2] + 0.009), dark)
piece("cart@cart", cart)
WIDE = 0.018
for side, name in ((1, "left"), (-1, "right")):
    hub = (side * 0.1, R, AXLE[2])
    rolling = Shape()
    # Turned on its axle along x: its rim a ring, its three spokes through
    # the hub showing between (the game's solid rim hid them), its hub a
    # nave proud of the rim either side.
    with rolling.placed(translation(*hub) @ turn_z(-side * math.pi / 2)):
        rolling.lathe([(R - 0.007, -WIDE / 2), (R, -WIDE / 2), (R, WIDE / 2), (R - 0.007, WIDE / 2), (R - 0.007, -WIDE / 2)], 8, dark,
                    caps=(False, False))
        rolling.prism(4, 0.011, -0.012, 0.012, timber, twist=math.pi / 4)
    for spoke in range(3):
        angle = math.pi * spoke / 3
        d = Vector((0.0, math.cos(angle), math.sin(angle))) * R * 0.95
        rolling.beam(V(hub) - d, V(hub) + d, WIDE * 0.6, timber, ends=(False, False))
    piece("cart wheel %s@cart" % name, rolling, "wheel %s@cart" % name)

# MARK: The brazier

brazier = Shape()
for index in range(3):
    foot = ring(0.07, 0.0, index * 2 * math.pi / 3)
    brazier.limb(foot, (foot.x * 0.4, 0.14, foot.z * 0.4), 0.008, iron, sides=3)
# Its bowl open, its lip turned in over the coals glowing in it (the game's
# was lidded, the fire through its lid).
with brazier.placed(translation(0, 0.13, 0)):
    brazier.lathe([(0.03, 0.0), (0.07, 0.05), (0.075, 0.06), (0.069, 0.06), (0.064, 0.045)], 7, iron, cap_mats=(None, fire))
piece("brazier@brazier", brazier)
flame = Shape()
with flame.placed(translation(0, 0.165, 0)):
    # The game's cone of flame, its foot under the coals cut off: its
    # corners there stood out through the bowl's sides.
    flame.lathe([(0.055 * (0.12 - 0.007) / 0.12, 0.007), (0.0, 0.12)], 5, fire, caps=(False, False))
    flame.cone(4, 0.028, 0.02, 0.17, candle, twist=0.4, caps=(False, False))
piece("brazier fire@brazier", flame, "fire@brazier")

# MARK: The puff of smoke

cloud = Shape()
cloud.sphere((0, 0.04, 0), 0.045, 3, 5, smoke)
cloud.sphere((0.035, 0.03, 0.015), 0.032, 2, 5, smoke)
cloud.sphere((-0.03, 0.055, -0.01), 0.03, 2, 5, smoke)
piece("puff@puff", cloud, "cloud@puff")

# MARK: The boat

# The hull's breadth along it, as the game's lathe had it (z, half-breadth),
# below the water the game's flattened round, above it the upper strake
# rising to the gunwale, which sheers up toward the stem and the stern. The
# game closed its lathe over the top, burying the boards it was floored
# with and leaving the thwarts poking out of its sides.
HULL = [(-0.22, 0.0), (-0.2, 0.04), (-0.12, 0.07), (0.0, 0.08), (0.12, 0.07), (0.2, 0.045), (0.24, 0.0)]
FLARE, WALL, FLOOR = 0.05, 0.004, 0.016


def gunwale(z):
    return 0.042 + 0.024 * (z / (0.24 if z > 0 else 0.22)) ** 2


def outside(r, z, y):
    """The hull's half-breadth outside at height y over the water."""
    return r * (1 + FLARE * y / gunwale(z))


def inside(r, z, y):
    return max(outside(r, z, y) - WALL, 0.0)


def inside_at(z, y):
    """The hull's half-breadth inside anywhere along it."""
    for (z0, r0), (z1, r1) in zip(HULL, HULL[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            return inside(r0, z0, y) * (1 - t) + inside(r1, z1, y) * t
    return 0.0


def section(z, r):
    """Round the hull at one place: from the gunwale on the left down the
    upper strake, round under the bottom and up to the right's gunwale."""
    g = gunwale(z)
    points = [(outside(r, z, g), g), (r, 0.0)]
    points += [(r * math.cos(math.radians(a)), 0.55 * r * math.sin(math.radians(a))) for a in (324, 288, 252, 216)]
    points += [(-r, 0.0), (-outside(r, z, g), g)]
    return [Vector((x, y, z)) for x, y in points]


def facing(shape, a, b, c, d, out, mat):
    """A quad, each of its triangles turned to look along out(its middle)."""
    for tri in ((a, b, c), (a, c, d)):
        shape.face(tri, out(sum(tri, Vector()) / 3), mat)


hull = Shape()
sections = [section(z, r) for z, r in HULL]
for i in range(len(HULL) - 1):
    for j in range(7):
        shade = timber if j in (0, 6) else dark
        facing(hull, sections[i][j], sections[i][j + 1], sections[i + 1][j + 1], sections[i + 1][j], lambda m: Vector((m.x, m.y - 0.01, 0)),
               shade)
    (z0, r0), (z1, r1) = HULL[i], HULL[i + 1]
    for s in (1, -1):
        low0, low1 = Vector((s * inside(r0, z0, FLOOR), FLOOR, z0)), Vector((s * inside(r1, z1, FLOOR), FLOOR, z1))
        g0, g1 = gunwale(z0), gunwale(z1)
        top0, top1 = Vector((s * inside(r0, z0, g0), g0, z0)), Vector((s * inside(r1, z1, g1), g1, z1))
        out0, out1 = Vector((s * outside(r0, z0, g0), g0, z0)), Vector((s * outside(r1, z1, g1), g1, z1))
        # The inside of the strake, from the floor up, and the gunwale over it.
        facing(hull, low0, top0, top1, low1, lambda m, s=s: Vector((-s, 0, 0)), timber)
        facing(hull, out0, top0, top1, out1, lambda m: Vector((0, 1, 0)), pale)
floor = [Vector((s * inside(r, z, FLOOR), FLOOR, z)) for s, stations in ((1, HULL), (-1, HULL[-2:0:-1])) for z, r in stations]
hull.face([p for i, p in enumerate(floor) if i == 0 or (p - floor[i - 1]).length > 1e-9], (0, 1, 0), timber)
# Three thwarts from side to side, cut to the hull's breadth, a little
# lower than the game's, under the gunwale where the oars cross it.
for z in (-0.1, 0.0, 0.12):
    near, far_end = z - 0.0125, z + 0.0125
    a, b = inside_at(near, 0.03) + 0.001, inside_at(far_end, 0.03) + 0.001
    hull.slab([(a, 0.03, near), (b, 0.03, far_end), (-b, 0.03, far_end), (-a, 0.03, near)], (0, 1, 0), 0.01, pale)
# The net heaped in the stern, down on the floor, which lies lower than the
# game's buried boards did.
lift = 0.02 * (1 + 0.2 * (2 * noise_unit(0, 0, 3) - 1))
hull.rock((0, FLOOR - 0.002 + lift, -0.15), (0.04, 0.02, 0.035), 2, 5, 0.2, 3, net)
# The lantern's pole, stepped through the floor at the bow.
hull.limb((0, 0.012, 0.18 - 0.018 * 0.04 / 0.19), (0, 0.22, 0.22), 0.004, dark, caps=(False, True))
piece("boat hull@boat", hull, "hull@boat")
posts = Shape()
for z, lean in ((0.24, 1), (-0.22, -1)):
    posts.beam((0, -0.004, z), (0, gunwale(z) + 0.01, z + lean * 0.004), 0.006, dark)
piece("boat posts@boat!fine", posts, "hull@boat")

lantern = Shape()
lantern.limb((0, 0.22, 0.22), (0, 0.19, 0.22), 0.002, iron, sides=3)
lantern.block((0, 0.175, 0.22), (0.022, 0.03, 0.022), iron)
lantern.block((0, 0.175, 0.22), (0.016, 0.022, 0.024), candle)
piece("boat lantern@boat", lantern, "lantern@boat")
cap = Shape()
with cap.placed(translation(0, 0.19, 0.22)):
    cap.cone(4, 0.02, 0.0, 0.012, iron, twist=math.pi / 4)
piece("boat lantern cap@boat!fine", cap, "lantern@boat")

fisher = Shape()
# Hunched in a hooded coat on the thwart, his face showing under his hood
# (the game's hood swallowed his head).
with fisher.placed(translation(0, 0.04, -0.01)):
    fisher.lathe([(0.035, 0.0), (0.04, 0.04), (0.03, 0.09), (0.0, 0.11)], 6, dark_wool)
fisher.sphere((0, 0.165, 0.0), 0.022, 3, 6, skin)
with fisher.placed(translation(0, 0.15, -0.013)):
    fisher.tube([(0.028, 0.0), (0.026, 0.03), (0.0, 0.05)], 6, wool)
for side in (1, -1):
    fisher.limb((0.03 * side, 0.12, 0), (0.07 * side, 0.08, 0.04), 0.008, dark_wool, caps=(False, True), cap_mats=(None, skin))
piece("boat fisher@boat", fisher, "fisher@boat")
for side, name in ((1, "left"), (-1, "right")):
    oar = Shape()
    oar.limb((0.05 * side, 0.08, 0.04), (0.26 * side, -0.01, 0.0), 0.004, pale, caps=(True, False))
    oar.block((0.27 * side, -0.012, 0.0), (0.05, 0.004, 0.02), pale)
    piece("boat oar %s@boat" % name, oar, "oar %s@boat" % name)

# MARK: The builders' stores

stores = Shape()
# The timber on two bearers laid across its planks (the game's lay along
# them, one under a plank and one in the stone).
for z in (-0.05, 0.05):
    stores.block((-0.06, 0.006, z), (0.16, 0.012, 0.02), dark)
for layer in range(3):
    for plank in range(4 - layer):
        x = (plank - (3 - layer) / 2) * 0.03
        stores.block((x - 0.06, 0.02 + layer * 0.02, 0), (0.026, 0.018, 0.18), pale)
for centre in ((0.07, 0.016, -0.04), (0.11, 0.016, -0.04), (0.07, 0.016, 0.0), (0.11, 0.016, 0.0), (0.09, 0.048, -0.02), (0.09, 0.016, 0.04)):
    stores.block(centre, (0.038, 0.032, 0.036), pale_stone)
stores.block((0.09, 0.07, -0.02), (0.012, 0.012, 0.06), dark)
piece("materials@materials", stores)
mallet = Shape()
mallet.block((0.09, 0.0735, -0.041), (0.022, 0.02, 0.022), dark)
piece("materials close@materials!fine", mallet)

# MARK: The waystone

STONES = ["waystone", "waystoneLit"]
LEAN = 0.06
standing = Shape()
standing.rock((0, 0.025, 0), (0.07, 0.03, 0.06), 2, 6, 0.2, 5, dark_stone)
# Leaning toward its cap, a face to the front where its notches are cut
# (the game's leant away from the cap and showed an edge, its notches
# standing off it upright).
with standing.placed(turn_z(-LEAN)):
    standing.prism(4, 0.026, 0.03, 0.2, rock_stone, top_radius=0.018, twist=math.pi / 4)
    for notch in range(3):
        y = 0.09 + notch * 0.03
        front = math.cos(math.pi / 4) * (0.026 - 0.008 * (y - 0.03) / 0.17)
        standing.block((0, y, front - 0.001), (0.022, 0.004, 0.004), soot)
piece(tagged("waystone", STONES), standing)
dim = Shape()
dim.sphere((0.008, 0.215, 0), 0.016, 2, 5, dim_salt)
piece("cap@waystone", dim)
glowing = Shape()
glowing.sphere((0.008, 0.215, 0), 0.018, 2, 5, moonsalt)
piece("cap lit@waystoneLit", glowing)
loose = Shape()
for index in range(4):
    angle = index * 1.7 + 0.4
    loose.rock((0.085 * math.cos(angle), 0.008, -0.07 * math.sin(angle)), (0.018, 0.011, 0.015), 2, 5, 0.25, 41 + index,
               rock_stone if index % 2 else dark_stone)
piece(tagged("waystone close", STONES) + "!fine", loose)

# MARK: The motion


def world_turn(x=0.0, y=0.0, z=0.0):
    """A turn of the game's (radians about x, then y, then z, in the
    world's axes) in Blender's axes."""
    return (Matrix.Rotation(z, 3, blender((0, 0, 1))) @ Matrix.Rotation(y, 3, blender((0, 1, 0))) @
            Matrix.Rotation(x, 3, blender((1, 0, 0))))


def clip(name, frames, parts):
    """An action `frames` long, keyed at every frame (works.idle's, named
    and with shifts): each part as (bone, pose(u)), the pose a dict of
    "turn" (a turn in Blender's axes about the bone's pivot), "shift" (the
    world's units) and "scale" (across, along the bone, across)."""
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    last = {}
    for frame in range(frames + 1):
        u = frame / frames
        for bone, pose in parts:
            p = pose(u)
            pb = rig.pose.bones[bone]
            rest = rig.data.bones[bone].matrix_local.to_3x3()
            if "turn" in p:
                q = (rest.inverted() @ p["turn"] @ rest).to_quaternion()
                # The same turn kept on the side of the last frame's, so a
                # wheel turned past a half goes on the short way round.
                if bone in last and q.dot(last[bone]) < 0:
                    q = -q
                last[bone] = q
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=frame)
            if "shift" in p:
                pb.location = rest.inverted() @ (blender(p["shift"]) * UNIT)
                pb.keyframe_insert("location", frame=frame)
            if "scale" in p:
                pb.scale = Vector(p["scale"])
                pb.keyframe_insert("scale", frame=frame)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, act)
    strip.name = name
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector((0, 0, 0))
        pb.scale = Vector((1, 1, 1))
    return act


def ease(t):
    c = min(max(t, 0.0), 1.0)
    return c * c * (3 - 2 * c)


def key_at(u, frames):
    """Motion.key: a value through keys at moments of a clip, eased from
    one to the next and held past the first and the last."""
    previous = frames[0]
    if u <= previous[0]:
        return previous[1]
    for frame in frames[1:]:
        if u <= frame[0]:
            return previous[1] + (frame[1] - previous[1]) * ease((u - previous[0]) / max(frame[0] - previous[0], 1e-6))
        previous = frame
    return previous[1]


def wave(u, cycles=1.0, phase=0.0):
    return math.sin(2 * math.pi * (u * cycles + phase))


def flapping(beats, glides):
    """The bird's wings at a share of a clip: beats, the idle's gliding
    between, lifted a little above level."""
    def flap(u):
        glide = key_at(u, [(0, 1), (0.6, 1), (0.7, 0.15), (0.9, 0.15), (1, 1)]) if glides else 1.0
        return 0.75 * glide * wave(u, beats) + 0.1
    return flap


def spline(keys, u):
    """Track.value of a looping clip: through keys (moment, (x, y, z)) on a
    cardinal spline, its tangents from the keys either side, flat on an
    axis where a key holds a neighbour's value."""
    count = len(keys)

    def key(index):
        wraps = math.floor(index / count)
        t, value = keys[index - wraps * count]
        return t + wraps, Vector(value)

    def tangent(index):
        here, before, after = key(index), key(index - 1), key(index + 1)
        if before[0] == here[0] or after[0] == here[0]:
            return Vector((0, 0, 0))
        slope = (after[1] - before[1]) / (after[0] - before[0])
        for axis in range(3):
            if here[1][axis] == before[1][axis] or here[1][axis] == after[1][axis]:
                slope[axis] = 0.0
        return slope

    v = u - math.floor(u)
    i = -1 if v < keys[0][0] else 0
    while i < count - 1 and keys[i + 1][0] <= v:
        i += 1
    (ta, a), (tb, b) = key(i), key(i + 1)
    span = max(tb - ta, 1e-5)
    t = min(max((v - ta) / span, 0.0), 1.0)
    da, db = tangent(i) * span, tangent(i + 1) * span
    t2, t3 = t * t, t * t * t
    return a * (2 * t3 - 3 * t2 + 1) + da * (t3 - 2 * t2 + t) + b * (-2 * t3 + 3 * t2) + db * (t3 - t2)


def k(t, x, y=0.0, z=0.0):
    return (t, (x, y, z))


# The boat's stroke and swell, keyed as the game keyed them: a stroke each
# half-period, dip, pull, lift and swing forward; a slow heave, a roll and
# a pitch under it.
ROWING = {
    "oar left@boat": [k(0, 0, -0.5, 0.2), k(0.15, 0, 0.0, 0.25), k(0.3, 0, 0.5, 0.15), k(0.4, 0, 0.45, -0.1), k(0.5, 0, -0.5, 0.2),
                      k(0.65, 0, 0.0, 0.25), k(0.8, 0, 0.5, 0.15), k(0.9, 0, 0.45, -0.1)],
    "oar right@boat": [k(0, 0, 0.5, -0.2), k(0.15, 0, 0.0, -0.25), k(0.3, 0, -0.5, -0.15), k(0.4, 0, -0.45, 0.1), k(0.5, 0, 0.5, -0.2),
                       k(0.65, 0, 0.0, -0.25), k(0.8, 0, -0.5, -0.15), k(0.9, 0, -0.45, 0.1)],
    "fisher@boat": [k(0, 0.25), k(0.3, -0.2), k(0.42, -0.1), k(0.5, 0.25), k(0.8, -0.2), k(0.92, -0.1)],
    "hull@boat": [k(0, 0.03, 0, 0.05), k(0.25, -0.02, 0, -0.01), k(0.5, -0.03, 0, -0.05), k(0.75, 0.02, 0, 0.01)],
    "lantern@boat": [k(0, 0.12, 0, -0.08), k(0.25, -0.05, 0, 0.1), k(0.5, -0.12, 0, 0.08), k(0.75, 0.05, 0, -0.1)],
}
HEAVE = [k(0, 0, 0.006), k(0.25, 0, -0.004), k(0.5, 0, 0.006), k(0.75, 0, -0.004)]


def rowing(bone):
    def pose(u, bone=bone):
        p = {"turn": world_turn(*spline(ROWING[bone], u))}
        if bone == "hull@boat":
            p["shift"] = tuple(spline(HEAVE, u))
        return p
    return pose


def leaping_flame(u):
    return {"scale": leaping(u)}


def puffing(u):
    """Rising and growing over most of the idle, shrunk back to its start
    at the end, unseen."""
    life = key_at(u, [(0, 0), (0.92, 1), (1, 0)])
    s = 0.6 + 1.6 * life
    return {"shift": (0.03 * life, 0.35 * life, 0.0), "scale": (s, s, s)}


def wings(beats, glides):
    flap = flapping(beats, glides)
    return [("wing left@bird", lambda u, flap=flap: {"turn": world_turn(z=flap(u))}),
            ("wing right@bird", lambda u, flap=flap: {"turn": world_turn(z=-flap(u))})]


clip("idle", 120, wings(12, True) + [
    ("cloth@banner", lambda u: {"turn": world_turn(y=0.22 * swing(u))}),
    ("fire@brazier", leaping_flame),
    ("cloud@puff", puffing)] + [(bone, rowing(bone)) for bone in ROWING])
# On the march the cart's wheels roll a turn each period and the bird beats
# its wings steadily; everything else plays its idle in the march's time.
clip("march@cart,bird", 30, wings(4, False) + [
    ("wheel %s@cart" % side, lambda u: {"turn": world_turn(x=wheel_turns(1)(u))}) for side in ("left", "right")])

finish_building(out_path("Art/models/props.glb"), VARIANTS)
