"""What every wheeled thing a person pushes or pulls shares: a square beam
from one point to another, and a pair of wheels on their axle, lean far off
and true close, made to turn once a march period at the pace every company
on foot keeps.
"""
import math

from common import *

# Every company on foot marches at one pace (Gait.spear's in the game:
# two strides of 0.46 at 0.45 radians, a figure 0.3 tall); a stocky carter
# or crewman is drawn at 0.28/1.8 of a unit to Blender's, so his wheels are
# this big to turn once a period, and his stride this much longer.
PACE = 2 * 2 * 0.46 * math.sin(0.45) * 0.3
STOCKY = 0.28 / 1.8
WHEEL = PACE / (2 * math.pi * STOCKY)
REACH = 0.3 / 0.28


def beam(name, start, end, width, mat):
    """A square beam from one point to another."""
    return loft(name, [(tuple(start), width / 2, width / 2, {}), (tuple(end), width / 2, width / 2, {})], segments=4, mat=mat,
                caps=(True, True), smooth=False)


def wheel_pair(rig, p, axle, spread, tags, wood, rimmed, hub, radius=WHEEL):
    """Two wheels on their axle `spread` either side of it, on the bones
    wheelL and wheelR: a spoke across each far off; close, four about a
    hub, the felloes shod in iron."""
    WHEEL = radius
    for s, side in ((1, "L"), (-1, "R")):
        centre = (axle.x + s * spread, axle.y, axle.z)
        rim = loft("wheel %s%s" % (side, tags), [((centre[0] - 0.036, centre[1], centre[2]), WHEEL, WHEEL, {}),
                                               ((centre[0] + 0.036, centre[1], centre[2]), WHEEL, WHEEL, {})],
                   segments=6, mat=p.iron if rimmed else wood, caps=(False, False))
        spokes = [solid("spoke", "box", mat=wood, location=centre, size=(0.04, 2 * WHEEL * 0.96, 0.05), rotation=(angle, 0, 0))
                  for angle in (0,)]
        hang(join("wheel %s%s" % (side, tags), [rim] + spokes), rig, "wheel" + side)
        close = [loft("felloe", [((centre[0] - 0.041, centre[1], centre[2]), WHEEL * 1.02, WHEEL * 1.02, {}),
                                 ((centre[0] + 0.041, centre[1], centre[2]), WHEEL * 1.02, WHEEL * 1.02, {})],
                      segments=16, mat=p.iron, caps=(False, False)),
                 solid("hub", "cylinder", mat=hub, vertices=10, radius=0.07, depth=0.15, location=centre, rotation=(0, 90, 0))]
        close += [solid("spoke", "box", mat=wood, location=centre, size=(0.03, 2 * WHEEL * 0.98, 0.036), rotation=(angle, 0, 0))
                  for angle in (45, 90, 135)]
        hang(join("wheel close %s%s!fine" % (side, tags), close), rig, "wheel" + side)


def rolling(frame, turns=1.0):
    """Both wheels `turns` round each march period of 30 frames (a whole
    turn, or a half for wheels the same across their middle)."""
    turn = 360 * turns * frame / 30
    return {"wheelL": (turn, 0, 0), "wheelR": (turn, 0, 0)}


def roll_evenly(rig, name, turns=1.0, frames=30):
    """The wheels of the walk keyed `name` keyed afresh at every frame and
    stepped evenly between, so they roll at one rate over the ground
    walked: keyed only a quarter-period apart and eased between, they would
    turn faster and slower by turns, and skid."""
    from bpy_extras import anim_utils
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    last = {}
    for frame in range(frames + 1):
        for bone in ("wheelL", "wheelR"):
            q = armature_turn(rig, bone, (360 * turns * frame / frames, 0, 0))
            if bone in last and q.dot(last[bone]) < 0:
                q = -q
            last[bone] = q
            pb = rig.pose.bones[bone]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=frame)
    wheels = {'pose.bones["wheelL"].rotation_quaternion', 'pose.bones["wheelR"].rotation_quaternion'}
    for curve in anim_utils.action_get_channelbag_for_slot(act, rig.animation_data.action_slot).fcurves:
        if curve.data_path in wheels:
            for point in curve.keyframe_points:
                point.interpolation = "LINEAR"
    rig.animation_data.action = None
    for bone in ("wheelL", "wheelR"):
        rig.pose.bones[bone].rotation_quaternion = Quaternion()


def handcart(rig, p, name, grips, bed_front, bed_back, bed, wood, pale):
    """A handcart on the extra bone: shafts from the hands at `grips` back
    along the bed's sides to its tail, its rails, its bed of planks, and a
    prop at its tail to stand it level when it is let go."""
    cart = []
    for s in (1, -1):
        cart.append(beam("shaft", Vector((s * grips[0], grips[1], grips[2])), Vector((s * 0.396, bed_back, bed + 0.06)), 0.05, wood))
        cart.append(solid("rail", "box", mat=wood, location=(s * 0.414, (bed_front + bed_back) / 2, bed + 0.13),
                          size=(0.07, bed_back - bed_front, 0.13)))
    cart.append(solid("bed", "box", mat=pale, location=(0, (bed_front + bed_back) / 2, bed), size=(0.86, bed_back - bed_front, 0.10)))
    cart.append(beam("prop", Vector((-0.324, bed_back - 0.08, bed - 0.04)), Vector((-0.324, bed_back - 0.02, 0.0)), 0.045, wood))
    hang(join(name, cart), rig, "extra")
