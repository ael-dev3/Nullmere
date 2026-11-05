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


def wheel_pair(rig, p, axle, spread, tags, wood, rimmed, hub):
    """Two wheels on their axle `spread` either side of it, on the bones
    wheelL and wheelR: a spoke across each far off; close, four about a
    hub, the felloes shod in iron."""
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


def rolling(frame):
    """Both wheels a turn each march period of 30 frames."""
    turn = 360 * frame / 30
    return {"wheelL": (turn, 0, 0), "wheelR": (turn, 0, 0)}
