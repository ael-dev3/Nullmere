"""Shared helpers for Nullmere Online's models made in Blender.

Every model of the world made in Blender is made by one script in this
folder, run with Blender's Python (the bpy module):

    python Art/blender/<model>.py Art/models/<model>.glb

and exported as glTF binary, which Art/embed.py writes into the package for
the game to read (Sources/NullmereModels/Asset.swift). A figure is made
1.8 tall, standing on z = 0 and facing -y (glTF's +z, the world's facing),
and the game takes it at a sixth of that. Materials are named as Asset.swift reads them: the
world's material first (plain, house, glow, foliage, cloth, crystal, metal),
then the grain drawn on it, if any (stone, timber, thatch, slate, earth).
Actions are named for the clips they play (idle, march, attack, hit, death,
gather), each as long as its clip's period at 30 frames a second.
"""
import math
import sys

import bpy
import bmesh
import canonical
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30
# Each clip's period in seconds, as Sources/NullmereModels/Motion.swift has it.
PERIODS = {"idle": 4.0, "march": 1.0, "attack": 1.5, "death": 1.5, "gather": 2.0, "hit": 1.5}


def reset():
    """An empty scene at 30 frames a second."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 0
    return scene


def material(name, colour, roughness=0.8, metallic=0.0):
    """A material by the world's naming, its colour given in sRGB."""
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    linear = [srgb_to_linear(c) for c in colour]
    bsdf.inputs["Base Color"].default_value = (linear[0], linear[1], linear[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    m.diffuse_color = (linear[0], linear[1], linear[2], 1.0)
    return m


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(*objects, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objects[-1]


def apply_transforms(obj):
    select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def tube(name, radius, bottom, top, rings=9, segments=8, mat=None):
    """A closed tube standing along z from `bottom` to `top`, in rings for a
    skin to bend at; `radius` a number or a function of the height's share."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    loops = []
    for r in range(rings):
        t = r / (rings - 1)
        z = bottom + (top - bottom) * t
        rad = radius(t) if callable(radius) else radius
        loops.append([bm.verts.new((rad * math.cos(2 * math.pi * s / segments), rad * math.sin(2 * math.pi * s / segments), z))
                      for s in range(segments)])
    for a, b in zip(loops, loops[1:]):
        for s in range(segments):
            bm.faces.new((a[s], a[(s + 1) % segments], b[(s + 1) % segments], b[s]))
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    if mat:
        mesh.materials.append(mat)
    return obj


def armature(name, bones):
    """An armature of bones given as (name, head, tail, parent, roll)."""
    data = bpy.data.armatures.new(name)
    obj = link(bpy.data.objects.new(name, data))
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bone_name, head, tail, parent, *rest in bones:
        b = data.edit_bones.new(bone_name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.roll = rest[0] if rest else 0.0
        if parent:
            b.parent = made[parent]
            b.use_connect = (Vector(head) - made[parent].tail).length < 1e-5
        made[bone_name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def skin(mesh_obj, rig):
    """The mesh skinned to the armature with Blender's automatic weights."""
    select_only(mesh_obj, rig, active=rig)
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def hang(obj, rig, bone):
    """A rigid piece carried by a bone: a spear in the hand."""
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def fold(rig, into):
    """Bones folded into others, `into` as {bone: the bone that takes it
    over}: each mesh's weights for a folded bone added to its taker's, each
    piece hung from one hung from its taker, and the bone taken out of the
    armature. A figure's rig kept to the parts the game draws it with (a
    rider's legs carried by his seat, a hoof by its shin)."""
    def taker(bone):
        while bone in into:
            bone = into[bone]
        return bone
    for obj in sorted((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: o.name):
        if obj.parent == rig and obj.parent_type == "BONE" and obj.parent_bone in into:
            hang(obj, rig, taker(obj.parent_bone))
        for name in sorted(into):
            group = obj.vertex_groups.get(name)
            if group is None:
                continue
            shares = [(v.index, g.weight) for v in obj.data.vertices for g in v.groups if g.group == group.index]
            target = obj.vertex_groups.get(taker(name)) or obj.vertex_groups.new(name=taker(name))
            for index, share in shares:
                target.add([index], share, "ADD")
            obj.vertex_groups.remove(group)
    select_only(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    for name in sorted(into):
        for child in list(bones[name].children):
            child.use_connect = False
            child.parent = bones[taker(name)]
        bones.remove(bones[name])
    bpy.ops.object.mode_set(mode="OBJECT")


def action(rig, name, keys):
    """An action of the armature: keys as {frame: {bone: (rx, ry, rz) in degrees, or (rotation, location)}}."""
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"
    for frame in sorted(keys):
        for bone_name, value in keys[frame].items():
            pb = rig.pose.bones[bone_name]
            if isinstance(value[0], (tuple, list)):
                rotation, location = value
            else:
                rotation, location = value, None
            pb.rotation_euler = Euler([math.radians(a) for a in rotation], "XYZ")
            pb.keyframe_insert("rotation_euler", frame=frame)
            if location is not None:
                pb.location = Vector(location)
                pb.keyframe_insert("location", frame=frame)
    # Kept on its own NLA track, so every action is exported.
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(min(keys)), act)
    strip.name = name
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.rotation_euler = Euler((0, 0, 0))
        bone.location = Vector((0, 0, 0))
    return act


def export(path):
    """The scene written to `path` as glTF binary in one fixed order, each
    mesh named for its object (not for the shape Blender began it from)."""
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.data.users == 1:
            obj.data.name = obj.name
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_slide_to_zero=True,
        export_force_sampling=True,
        export_frame_step=1,
        export_skins=True,
        export_influence_nb=4,
        export_def_bones=False,
        export_vertex_color="NONE",
        export_attributes=True,
        export_materials="EXPORT",
        export_texcoords=False,
        export_tangents=False,
        export_morph=False,
        export_optimize_animation_size=True,
    )
    canonical.rewrite(path)


def out_path(default):
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    return args[0] if args else default


# MARK: Bodies of rings, for skin to bend at the joints

def loft(name, sections, segments=8, mat=None, caps=(True, True), smooth=True):
    """A body of rings along a path: each section (centre, rx, ry, weights),
    a ring of `segments` about the path's direction there, rx across the
    body (x) and ry front to back; weights {bone: share} for the ring, or a
    function of a vertex's position giving them (a skirt's left side going
    with the left thigh). The rings are joined in quads and the ends capped."""
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    bm = bmesh.new()
    rings = []
    weights_of = []
    count = len(sections)
    for i, (centre, rx, ry, weights) in enumerate(sections):
        c = Vector(centre)
        before = Vector(sections[max(i - 1, 0)][0])
        after = Vector(sections[min(i + 1, count - 1)][0])
        axis = (after - before).normalized()
        side = Vector((1, 0, 0))
        if abs(axis.dot(side)) > 0.9:
            side = Vector((0, 1, 0))
        u = (side - axis * side.dot(axis)).normalized()
        v = axis.cross(u).normalized()
        ring = []
        for s in range(segments):
            a = 2 * math.pi * s / segments
            p = c + u * (rx * math.cos(a)) + v * (ry * math.sin(a))
            vert = bm.verts.new(p)
            ring.append(vert)
            weights_of.append(weights(p) if callable(weights) else weights)
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(segments):
            bm.faces.new((a[s], a[(s + 1) % segments], b[(s + 1) % segments], b[s]))
    if caps[0]:
        bm.faces.new(list(reversed(rings[0])))
    if caps[1]:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if mat:
        mesh.materials.append(mat)
    weigh(obj, weights_of)
    return obj


def weigh(obj, weights_of):
    """Vertex groups from each vertex's {bone: share}, in vertex order."""
    for index, weights in enumerate(weights_of):
        for bone, share in weights.items():
            group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            group.add([index], share, "REPLACE")


def solid(name, kind, mat=None, weights=None, smooth=False, **shape):
    """A rigid shape for gear or a skinned body part: kind 'sphere' (radius
    as (rx, ry, rz), segments, rings), 'box' (size as (x, y, z)), or
    'cylinder' (radius, depth, vertices); placed at `location`, turned by
    `rotation` (degrees). Weighted wholly to `weights` if given."""
    loc = shape.pop("location", (0, 0, 0))
    rot = shape.pop("rotation", (0, 0, 0))
    if kind == "sphere":
        radii = shape.pop("radius")
        bpy.ops.mesh.primitive_uv_sphere_add(segments=shape.pop("segments", 8), ring_count=shape.pop("rings", 6), radius=1,
                                             location=loc)
        obj = bpy.context.active_object
        obj.scale = Vector(radii)
    elif kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        obj = bpy.context.active_object
        obj.scale = Vector(shape.pop("size"))
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=shape.pop("vertices", 8), radius=shape.pop("radius"),
                                            depth=shape.pop("depth"), location=loc)
        obj = bpy.context.active_object
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=shape.pop("vertices", 8), radius1=shape.pop("radius1"),
                                        radius2=shape.pop("radius2", 0), depth=shape.pop("depth"), location=loc)
        obj = bpy.context.active_object
    else:
        raise ValueError(kind)
    obj.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    obj.name = name
    apply_transforms(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    if mat:
        obj.data.materials.append(mat)
    if weights:
        weigh(obj, [weights] * len(obj.data.vertices))
    return obj


def shape_vertices(obj, change):
    """Each vertex moved by change(Vector) -> Vector, in place."""
    for v in obj.data.vertices:
        v.co = change(v.co.copy())


def join(name, objects):
    """Objects joined into one mesh, their materials and vertex groups kept."""
    select_only(*objects, active=objects[0])
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def bind(obj, rig):
    """A body weighted by its vertex groups, moved by the armature."""
    obj.parent = rig
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig


# MARK: Keying in the armature's own axes

def armature_turn(rig, bone, degrees):
    """A rotation about the bone's head in the armature's axes (x across,
    y back to front reversed, z up), given in degrees as (x, y, z) and
    applied x first, made the bone's own quaternion."""
    rest = rig.data.bones[bone].matrix_local.to_3x3()
    x, y, z = [math.radians(a) for a in degrees]
    world = (Matrix.Rotation(z, 3, "Z") @ Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X"))
    return (rest.inverted() @ world @ rest).to_quaternion()


def armature_shift(rig, bone, offset):
    """A shift of the bone in the armature's axes, made the bone's own."""
    rest = rig.data.bones[bone].matrix_local.to_3x3()
    return rest.inverted() @ Vector(offset)


def keyed(rig, name, frames, keys, hidden=(), shown=()):
    """An action `frames` long: keys {frame: {bone: turn (x, y, z) degrees,
    or {"turn": (...), "shift": (...), "scale": s}, or {"rotation": a 3x3
    matrix in the armature's axes, in place of a turn}}}; bones in `hidden` held
    at scale 0.001 throughout (put away), those in `shown` at 1. Every bone
    any key names is keyed at every key frame (unnamed: at rest), so each
    pose is whole; looping actions end on their first pose."""
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    named = sorted({bone for pose in keys.values() for bone in pose})
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    last = {}
    for frame in sorted(keys):
        pose = keys[frame]
        for bone in named:
            pb = rig.pose.bones[bone]
            value = pose.get(bone, (0, 0, 0))
            if not isinstance(value, dict):
                value = {"turn": value}
            if "rotation" in value:
                # A rotation already worked out in the armature's axes.
                rest = rig.data.bones[bone].matrix_local.to_3x3()
                q = (rest.inverted() @ value["rotation"] @ rest).to_quaternion()
            else:
                q = armature_turn(rig, bone, value.get("turn", (0, 0, 0)))
            # The same turn kept on the side of the last key's, so the keys
            # between go the short way round (a wheel turned past a half).
            if bone in last and q.dot(last[bone]) < 0:
                q = -q
            last[bone] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.location = armature_shift(rig, bone, value.get("shift", (0, 0, 0)))
            pb.keyframe_insert("location", frame=frame)
            if "scale" in value:
                s = value["scale"]
                pb.scale = Vector((s, s, s))
                pb.keyframe_insert("scale", frame=frame)
    for bone in list(hidden) + list(shown):
        pb = rig.pose.bones[bone]
        s = 0.001 if bone in hidden else 1.0
        pb.scale = Vector((s, s, s))
        pb.keyframe_insert("scale", frame=0)
        pb.keyframe_insert("scale", frame=frames)
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


def dome(name, radii, centre, segments=8, rings=4, mat=None, floor=None, smooth=True):
    """The upper half of an ellipsoid (a helm, a boss, a pauldron), cut
    clean at its middle, or at `floor` (a height above its centre), and
    closed beneath."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings * 2, radius=1, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    cut = (floor or 0.0) / radii[2]
    result = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-6,
                                    plane_co=(0, 0, cut), plane_no=(0, 0, 1), clear_inner=True)
    # Closed beneath by a face begun at the rim's vertex of least angle and
    # cut into triangles here, so it is cut the same way every time (the
    # cut's own order changes from run to run).
    rim = sorted({v for v in result["geom_cut"] if isinstance(v, bmesh.types.BMVert)},
                 key=lambda v: math.atan2(v.co.y, v.co.x))
    if len(rim) >= 3:
        floor_face = bm.faces.new(rim)
        bmesh.ops.triangulate(bm, faces=[floor_face], quad_method="FIXED", ngon_method="EAR_CLIP")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.scale = Vector(radii)
    obj.location = Vector(centre)
    apply_transforms(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    if mat:
        obj.data.materials.append(mat)
    return obj


def slanted_dome(name, radii, centre, segments=8, rings=3, mat=None, front=0.0, back=0.0, smooth=True):
    """The crown of an ellipsoid down to a plane that runs from `front`
    above its middle at its fore edge (toward -y) to `back` above it at its
    hind edge: a cap or a head of hair worn back from the face. Each
    meridian is cut where the plane meets it and ringed evenly above, so no
    face is folded, and the rim is left open."""
    rx, ry, rz = radii
    middle, tilt = (front + back) / 2, (front - back) / 2
    mesh = bpy.data.meshes.new(name)
    obj = link(bpy.data.objects.new(name, mesh))
    bm = bmesh.new()
    top = bm.verts.new((centre[0], centre[1], centre[2] + rz))
    meridians = []
    for j in range(segments):
        phi = 2 * math.pi * j / segments
        # On the meridian at phi, rz cos(t) = middle + tilt sin(t) cos(phi):
        # R cos(t + d) = middle, R and d from rz and tilt cos(phi).
        lean = tilt * math.cos(phi)
        rim = math.acos(max(-1.0, min(1.0, middle / math.hypot(rz, lean)))) - math.atan2(lean, rz)
        column = []
        for k in range(1, rings + 1):
            t = rim * k / rings
            column.append(bm.verts.new((centre[0] + rx * math.sin(t) * math.sin(phi), centre[1] - ry * math.sin(t) * math.cos(phi),
                                        centre[2] + rz * math.cos(t))))
        meridians.append(column)
    middle_point = Vector(centre)

    def face(corners):
        normal = (corners[1].co - corners[0].co).cross(corners[2].co - corners[0].co)
        if normal.dot(corners[0].co - middle_point) < 0:
            corners = list(reversed(corners))
        bm.faces.new(corners)

    for j in range(segments):
        n = (j + 1) % segments
        face([top, meridians[j][0], meridians[n][0]])
        for k in range(rings - 1):
            face([meridians[j][k], meridians[j][k + 1], meridians[n][k + 1], meridians[n][k]])
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if mat:
        mesh.materials.append(mat)
    return obj


def settle(bm):
    """Every face of more than three corners begun again at its least corner
    and cut into triangles from there, so a cut that orders its work
    differently from run to run (a bisect's) still makes the same triangles."""
    def least(v):
        return tuple(round(c, 5) for c in v.co)
    # Every corner on the ten-micrometre grid the file is written on, so a
    # cut's last bit of difference can't reach the normals through a sliver.
    for v in bm.verts:
        v.co = Vector(least(v))
    # Corners all but at one place (the cut's new corners by the old) moved
    # to the least of them and made one, so no merge later keeps whichever
    # it happens on first.
    corners = sorted(bm.verts, key=lambda v: (least(v), tuple(v.co)))
    for i, v in enumerate(corners):
        for w in corners[i + 1:]:
            if w.co.x - v.co.x > 1e-5:
                break
            if (w.co - v.co).length <= 1e-5:
                w.co = v.co.copy()
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-9)
    for face in [f for f in bm.faces if len(f.verts) > 3]:
        corners = list(face.verts)
        start = min(range(len(corners)), key=lambda i: least(corners[i]))
        ring = corners[start:] + corners[:start]
        material, smooth = face.material_index, face.smooth
        bm.faces.remove(face)
        made = bm.faces.new(ring)
        made.material_index, made.smooth = material, smooth
        bmesh.ops.triangulate(bm, faces=[made], quad_method="FIXED", ngon_method="EAR_CLIP")


def clean(obj):
    """Doubled vertices merged and triangles of no area dissolved."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def sway(obj, amount):
    """How far each vertex moves in the wind, 0 to 1, as amount(position):
    the _SWAY attribute the game reads (a cloak still at the shoulders, its
    hem free)."""
    attr = obj.data.attributes.get("_SWAY") or obj.data.attributes.new("_SWAY", "FLOAT", "POINT")
    for i, v in enumerate(obj.data.vertices):
        attr.data[i].value = max(0.0, min(1.0, amount(v.co)))
    return obj


def mix_weights(a, b, t):
    """Two rings' weights a share of the way between them."""
    if callable(a) or callable(b):
        fa = a if callable(a) else (lambda p, w=a: w)
        fb = b if callable(b) else (lambda p, w=b: w)
        def mixed(p, fa=fa, fb=fb, t=t):
            wa, wb = fa(p), fb(p)
            return {k: wa.get(k, 0) * (1 - t) + wb.get(k, 0) * t for k in set(wa) | set(wb)}
        return mixed
    return {k: a.get(k, 0) * (1 - t) + b.get(k, 0) * t for k in set(a) | set(b)}


def densified(sections, between):
    """The sections with `between` more rings eased in between each two."""
    out = []
    for (c0, rx0, ry0, w0), (c1, rx1, ry1, w1) in zip(sections, sections[1:]):
        out.append((c0, rx0, ry0, w0))
        for k in range(1, between + 1):
            t = k / (between + 1)
            e = t * t * (3 - 2 * t) * 0.35 + t * 0.65
            c = tuple(a + (b - a) * e for a, b in zip(c0, c1))
            out.append((c, rx0 + (rx1 - rx0) * e, ry0 + (ry1 - ry0) * e, mix_weights(w0, w1, e)))
    out.append(sections[-1])
    return out


def paired(rig, name, sections, far=6, near=12, between=1, mat=None, tags="", inflate=0.004, caps=(False, False), bound=True):
    """A body piece twice over: lean for afar (`far` sides, its rings as
    given) and, a little larger, round for near (`near` sides, `between`
    rings more between each two), drawn only close, over the lean one. Both
    weighted alike, so they bend as one."""
    lean = loft(name + tags, sections, segments=far, mat=mat, caps=caps)
    round_sections = [(c, rx + inflate, ry + inflate, w) for c, rx, ry, w in densified(sections, between)]
    full = loft(name + " close" + tags + "!fine", round_sections, segments=near, mat=mat, caps=caps)
    if bound:
        bind(lean, rig)
        bind(full, rig)
    return lean, full
