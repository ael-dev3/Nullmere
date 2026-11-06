"""What a commander's skill looks like at work, each a variant of one file
by the look its archetype gives it (Sources/NullmereModels/Furies.swift):
- the ward, a warden's: a dome of pale light closing over the company,
  ribbed, on a ring of light on the ground, runes standing about its foot
  and rising as they turn;
- the blaze, a vanguard's: a ball of fire swelling at its heart and ten
  tongues of flame thrown out from it on a ring of scorched ground;
- the volley, an outrider's: seven shafts of light falling from on high and
  sinking into the ground, a flare spreading where they strike;
- the ring, a gleaner's: two rings of gold on the ground, marked with
  sigils, the outer spreading and turning, the inner turning against it
  about a star;
- the quake, a wallbreaker's: shards of rock thrust up through the ground
  about the company, the ground cracked and glowing between them, settling
  back as it ends.
Each stands on y = 0 about its middle, in the world's units, the company it
works on within it.

Each is made of light (glow) but the quake's rock, and moved by two bones
of its own over the idle, keyed at every frame of its four seconds: the
game plays it once over the two seconds a skill works, fading it out as it
ends (WorldStage.furies).

    python Art/blender/furies.py Art/models/furies.glb
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
from mathutils import Matrix, Quaternion, Vector

reset()
VARIANTS = ["ward", "blaze", "volley", "ring", "quake"]

ward = material("glow_ward", (0.62, 0.80, 1.0))
runes = material("glow_runes", (0.84, 0.93, 1.0))
flame = material("glow_flame", (1.0, 0.45, 0.16))
fire = material("glow_fire", (1.0, 0.68, 0.32))
ember = material("glow_ember", (0.95, 0.42, 0.18))
light = material("glow_light", (1.0, 0.94, 0.78))
gild = material("glow_gild", (1.0, 0.80, 0.38))
rock_stone = material("plain_stone_rock", (0.40, 0.40, 0.42))

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

# MARK: The rig: each look's two bones, standing at its middle

UP = (0, 1, 0)
PARTS = [("dome@ward", (0.0, 0.0, 0.0)), ("runes@ward", (0.0, 0.0, 0.0)),
         ("core@blaze", (0.0, 0.14, 0.0)), ("flames@blaze", (0.0, 0.0, 0.0)),
         ("shafts@volley", (0.0, 0.0, 0.0)), ("flare@volley", (0.0, 0.0, 0.0)),
         ("ring@ring", (0.0, 0.0, 0.0)), ("inner@ring", (0.0, 0.0, 0.0)),
         ("shards@quake", (0.0, 0.0, 0.0)), ("cracks@quake", (0.0, 0.0, 0.0))]


def blender(v):
    """A direction of the world's in Blender's axes."""
    return Vector((v[0], -v[2], v[1]))



rig = armature("Furies", [(bone, tuple(at(*pivot)), tuple(at(*pivot) + blender(UP).normalized() * 0.2), None)
                          for bone, pivot in PARTS])


def piece(name, shape, bone):
    """A shape made a piece, carried by its bone."""
    obj = shape.make(name)
    on(obj, rig, bone)
    return obj


def annulus(shape, inner, outer, y, mat, sides=24, twist=0.0):
    """A flat ring on the ground, looking up."""
    step = 2 * math.pi / sides
    for side in range(sides):
        a0, a1 = side * step + twist, (side + 1) * step + twist
        shape.face([ring(inner, y, a0), ring(outer, y, a0), ring(outer, y, a1), ring(inner, y, a1)], (0, 1, 0), mat)


def leaning(at_point, out, lean):
    """A placement at a point turned to lean `lean` radians outward, along
    `out` on the ground."""
    o = V(out)
    o.y = 0
    o = o.normalized() if o.length > 1e-6 else Vector((1, 0, 0))
    up = Vector((0, 1, 0)) * math.cos(lean) + o * math.sin(lean)
    return translation(*at_point) @ aligning_up(tuple(up))


# MARK: The ward

R, H = 0.5, 0.4
ARC = [(R * math.cos(k * math.pi / 10), H * math.sin(k * math.pi / 10)) for k in range(6)]
dome = Shape()
dome.lathe(ARC, 12, ward, caps=(False, False))
# Six ribs brighter than the shell, meeting at its crown.
for k in range(6):
    angle = k * math.pi / 3
    points = [ring(r * 1.02 + 0.004, y, angle) for r, y in ARC]
    for a, b in zip(points, points[1:]):
        dome.limb(a, b, 0.008, runes, sides=3)
annulus(dome, R - 0.035, R + 0.035, 0.006, runes, sides=24)
piece("ward dome@ward", dome, "dome@ward")
standing = Shape()
for k in range(8):
    angle = k * math.pi / 4 + math.pi / 8
    with standing.placed(translation(*ring(R + 0.08, 0.0, angle)) @ turn_y(angle - math.pi / 2)):
        standing.box((-0.024, 0.0, -0.006), (0.024, 0.085, 0.006), runes, leave=("bottom",))
        # Each rune's mark: a lozenge standing proud of its face.
        standing.face([(0, 0.028, 0.008), (0.012, 0.045, 0.008), (0, 0.062, 0.008), (-0.012, 0.045, 0.008)], (0, 0, 1), ward)
piece("ward runes@ward", standing, "runes@ward")

# MARK: The blaze

# A tongue of flame: broad at its foot, swelling a little above it and
# drawn up to a point, turned as it rises.
TONGUE = [(0.04, 0.0), (0.055, 0.05), (0.045, 0.11), (0.024, 0.18), (0.0, 0.27)]
core = Shape()
core.sphere((0, 0.14, 0), 0.09, 4, 7, flame)
for k in range(6):
    angle = k * math.pi / 3
    with core.placed(leaning((0, 0.14, 0), ring(1, 0, angle), 1.2) @ scale(0.55, 0.6, 0.55)):
        core.lathe(TONGUE, 4, fire, twist=0.5, caps=(False, False))
piece("blaze core@blaze", core, "core@blaze")
tongues = Shape()
for k in range(10):
    angle = k * math.pi / 5
    base = ring(0.3, 0.0, angle)
    tall = 0.85 + 0.3 * ((k * 3) % 5) / 4
    with tongues.placed(leaning(base, base, 0.4) @ turn_y(angle) @ scale(1.0, tall, 1.0)):
        tongues.lathe(TONGUE, 5, flame, twist=0.35, caps=(False, False))
        with tongues.placed(translation(0, 0.015, 0) @ scale(0.55, 0.72, 0.55)):
            tongues.lathe(TONGUE, 4, fire, twist=1.1, caps=(False, False))
annulus(tongues, 0.16, 0.44, 0.004, ember, sides=20)
piece("blaze flames@blaze", tongues, "flames@blaze")

# MARK: The volley

shafts = Shape()
SPOTS = [(0.0, 0.0)] + [(0.3 * math.cos(k * math.pi / 3 + 0.4), -0.3 * math.sin(k * math.pi / 3 + 0.4)) for k in range(6)]
for x, z in SPOTS:
    with shafts.placed(translation(x, 0, z)):
        shafts.prism(4, 0.016, 0.0, 1.4, light, top_radius=0.004, caps=(False, False))
        shafts.cone(4, 0.05, 0.0, 0.06, light, caps=(False, False))
piece("volley shafts@volley", shafts, "shafts@volley")
flare = Shape()
annulus(flare, 0.14, 0.34, 0.006, light, sides=20)
for k in range(12):
    angle = k * math.pi / 6
    a, b, c = ring(0.34, 0.006, angle - 0.06), ring(0.5, 0.006, angle), ring(0.34, 0.006, angle + 0.06)
    flare.face([a, b, c], (0, 1, 0), light)
piece("volley flare@volley", flare, "flare@volley")

# MARK: The ring

outer = Shape()
annulus(outer, 0.42, 0.5, 0.006, gild, sides=28)
annulus(outer, 0.53, 0.545, 0.006, gild, sides=28)
for k in range(12):
    angle = k * math.pi / 6
    with outer.placed(translation(*ring(0.46, 0.006, angle)) @ turn_y(angle)):
        outer.box((-0.014, 0.0, -0.022), (0.014, 0.02, 0.022), gild, leave=("bottom",))
piece("ring outer@ring", outer, "ring@ring")
inner = Shape()
annulus(inner, 0.2, 0.24, 0.008, gild, sides=20)
for k in range(6):
    angle = k * math.pi / 3 + math.pi / 6
    with inner.placed(translation(*ring(0.22, 0.008, angle)) @ turn_y(angle)):
        inner.box((-0.01, 0.0, -0.016), (0.01, 0.016, 0.016), gild, leave=("bottom",))
# The star at its heart, six points.
star = [ring(0.12 if k % 2 == 0 else 0.05, 0.01, k * math.pi / 6) for k in range(12)]
for k in range(12):
    inner.face([(0, 0.01, 0), star[k], star[(k + 1) % 12]], (0, 1, 0), gild)
piece("ring inner@ring", inner, "inner@ring")

# MARK: The quake

shards = Shape()
for k in range(9):
    angle = k * 2 * math.pi / 9 + 0.2
    reach = 0.2 + 0.24 * ((k * 5) % 9) / 8
    base = ring(reach, -0.02, angle)
    tall = 0.12 + 0.1 * ((k * 7) % 9) / 8
    with shards.placed(leaning(base, base, 0.35)):
        shards.rock((0, tall / 2, 0), (0.045, tall / 2, 0.04), 3, 5, 0.25, 40 + k, rock_stone)
        shards.cone(4, 0.03, -0.01, 0.03, ember, caps=(False, False))
piece("quake shards@quake", shards, "shards@quake")
cracks = Shape()
for k in range(7):
    angle = k * 2 * math.pi / 7
    points = []
    for step in range(5):
        r = 0.06 + step * 0.11
        wobble = 0.12 * (1 if step % 2 else -1)
        points.append(ring(r, 0.006, angle + wobble))
    for a, b in zip(points, points[1:]):
        d = (b - a)
        side = Vector((-d.z, 0, d.x)).normalized() * 0.011
        cracks.face([a - side, b - side, b + side, a + side], (0, 1, 0), ember)
piece("quake cracks@quake", cracks, "cracks@quake")


# MARK: How each works, keyed over the idle

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




def uniform(s):
    return (s, s, s)


clip("idle", 120, [
    # The dome closes over the company at once, holds and sinks a little.
    ("dome@ward", lambda u: {"scale": uniform(key_at(u, [(0, 0.15), (0.12, 1.08), (0.2, 1.0), (0.8, 1.0), (1, 0.92)]))}),
    ("runes@ward", lambda u: {"turn": world_turn(y=2 * math.pi * 0.35 * u),
                              "shift": (0.0, key_at(u, [(0, -0.09), (0.16, 0.0), (1, 0.05)]), 0.0)}),
    # The fire bursts out, swells and dies down.
    ("core@blaze", lambda u: {"scale": uniform(key_at(u, [(0, 0.2), (0.08, 1.5), (0.3, 1.0), (1, 0.15)]))}),
    ("flames@blaze", lambda u: {"scale": (key_at(u, [(0, 0.35), (0.25, 1.4), (1, 1.9)]),
                                          key_at(u, [(0, 0.2), (0.12, 1.25), (0.6, 0.8), (1, 0.05)]),
                                          key_at(u, [(0, 0.35), (0.25, 1.4), (1, 1.9)])),
                                "turn": world_turn(y=0.6 * u)}),
    # The shafts fall from on high and sink into the ground; the flare spreads.
    ("shafts@volley", lambda u: {"shift": (0.0, key_at(u, [(0, 1.3), (0.1, 0.0), (1, 0.0)]), 0.0),
                                 "scale": (1.0, key_at(u, [(0, 1.0), (0.14, 1.0), (0.5, 0.04), (1, 0.02)]), 1.0)}),
    ("flare@volley", lambda u: {"scale": uniform(key_at(u, [(0, 0.05), (0.1, 0.1), (0.3, 1.2), (1, 1.6)]))}),
    # The rings spread, the outer turning one way and the inner the other.
    ("ring@ring", lambda u: {"scale": uniform(key_at(u, [(0, 0.3), (0.25, 1.2), (1, 1.35)])),
                             "turn": world_turn(y=2 * math.pi * 0.2 * u), "shift": (0.0, 0.05 * u, 0.0)}),
    ("inner@ring", lambda u: {"scale": uniform(key_at(u, [(0, 0.2), (0.3, 1.0), (1, 1.1)])),
                              "turn": world_turn(y=-2 * math.pi * 0.4 * u), "shift": (0.0, 0.08 * u, 0.0)}),
    # The shards burst up, stand and settle back into the ground.
    ("shards@quake", lambda u: {"shift": (0.0, key_at(u, [(0, -0.26), (0.05, 0.02), (0.1, 0.0), (0.55, 0.0), (1, -0.22)]), 0.0)}),
    ("cracks@quake", lambda u: {"scale": (key_at(u, [(0, 0.15), (0.07, 1.0), (1, 1.06)]), 1.0,
                                          key_at(u, [(0, 0.15), (0.07, 1.0), (1, 1.06)]))}),
])

finish_building(out_path("Art/models/furies.glb"), VARIANTS)
