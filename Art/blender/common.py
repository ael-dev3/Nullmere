"""Shared helpers for Nullmere Online's models made in Blender.

Every model of the world made in Blender is made by one script in this
folder, run with Blender's Python (the bpy module):

    python Art/blender/<model>.py Art/models/<model>.glb

and exported as glTF binary, which Art/embed.py writes into the package for
the game to read (Sources/NullmereModels/Asset.swift). Blender's units are
the world's: a figure stands about 0.3 tall, on z = 0, facing -y (glTF's +z,
the world's facing). Materials are named as Asset.swift reads them: the
world's material first (plain, house, glow, foliage, cloth, crystal, metal),
then the grain drawn on it, if any (stone, timber, thatch, slate, earth).
Actions are named for the clips they play (idle, march, attack, hit, death,
gather), each as long as its clip's period at 30 frames a second.
"""
import math
import sys

import bpy
import bmesh
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
        export_materials="EXPORT",
        export_texcoords=False,
        export_tangents=False,
        export_morph=False,
        export_optimize_animation_size=False,
    )


def out_path(default):
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    return args[0] if args else default
