"""The importer's test model: an arm of two bones under a skin of smooth
weights, a block carried by the forearm, two materials and two actions,
and a strike of a variant's own.

    python Art/blender/fixture_arm.py Art/models/fixture-arm.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy
from common import *

reset()
rig = armature("Arm", [("upper", (0, 0, 0), (0, 0, 1), None), ("lower", (0, 0, 1), (0, 0, 2), "upper")])

arm = tube("Skin", 0.2, 0, 2, rings=9, segments=8, mat=material("house_timber_shaft", (0.5, 0.4, 0.3)))
skin(arm, rig)

bpy.ops.mesh.primitive_cube_add(size=0.3, location=(0, 0, 2.2))
block = bpy.context.active_object
block.name = "Block"
block.data.materials.append(material("metal_blade", (0.7, 0.7, 0.75)))
hang(block, rig, "lower")

action(rig, "idle", {0: {"upper": (0, 0, 0)}, 60: {"upper": (5, 0, 0)}, 120: {"upper": (0, 0, 0)}})
action(rig, "attack", {0: {"lower": (0, 0, 0)}, 22: {"lower": (90, 0, 0)}, 45: {"lower": (0, 0, 0)}})
# A variant's own strike, the elbow bent the other way.
action(rig, "attack@other", {0: {"lower": (0, 0, 0)}, 22: {"lower": (-90, 0, 0)}, 45: {"lower": (0, 0, 0)}})
export(out_path("Art/models/fixture-arm.glb"))
