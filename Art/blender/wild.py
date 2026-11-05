"""What the things of the far country share: the body every person shares
(person.py) made over in ash, bark or stone, faceless and unbelted, with
eyes of a cold light, and the ways they move: a slow walk or a long prowl
or a heavy tread, a rake of the arms or a club brought down, a recoil, a
fall, and a crouched search of the ground where a man would gather.

Each is drawn at its own height (wildScale, in
Sources/NullmereModels/Art/Art.swift), and walks with its stride set so its
feet hold the ground at its own pace (Figures.wildGait's).
"""
import math

from common import *
from person import *

def eyes(man, glow, spread=0.036, forward=-0.104, lift=0.02):
    """Two cold eyes where a face would be."""
    pair = [solid("eye", "box", mat=glow, location=at_head(s * spread, forward, lift), size=(0.03, 0.012, 0.016)) for s in (1, -1)]
    hang(join("eyes", pair), man.rig, "head")


def clips(man, carry, pace_reach, stoop, strike, struck, search):
    """Every clip a thing of the far country plays: its idle and walk as
    `carry` holds it, stooped by `stoop`; `strike(frame)` its attack's pose
    at each frame; `struck(share)` the worst of a blow; `search(u)` its
    crouch over the ground."""
    rig = man.rig
    bent = merge(carry, {"torso": (stoop, 0, 0), "head": (-stoop * 0.7, 0, 0)})
    idle = {}
    for f in range(0, 121, 10):
        u = f / 120
        idle[f] = merge(bent, {"head": (-stoop * 0.7 + 4 * math.sin(4 * math.pi * u), 0, 26 * math.sin(2 * math.pi * u)),
                               "torso": (stoop + 2 * math.sin(2 * math.pi * u), 0, 4 * math.sin(2 * math.pi * u)),
                               "hips": {"turn": (0, 0, 0), "shift": (0.01 * math.sin(2 * math.pi * u), 0, 0)}})
    keyed(rig, "idle", 120, idle, hidden=["tool"])
    man.march(bent, lambda side: {"armL": (-6 + 10 * side, 0, -6), "armR": (-6 - 10 * side, 0, 6), "torso": (stoop + 4, 0, 0)},
              hidden=["tool"], shown=[], reach=pace_reach)
    keyed(rig, "attack", 45, {f: merge(bent, strike(f)) for f in [0, 6, 12, 16, 19, 22, 26, 30, 36, 45]}, hidden=["tool"])
    keyed(rig, "hit", 45, {0: merge(bent, struck(0)), 3: merge(bent, struck(0.15)), 6: merge(bent, struck(1.0)), 14: merge(bent, struck(0.7)),
                           25: merge(bent, struck(0.25)), 32: merge(bent, struck(0.05)), 36: merge(bent, struck(0)), 45: merge(bent, struck(0))},
          hidden=["tool"])
    man.death(bent, hidden=["tool"], shown=[])
    keyed(rig, "gather", 60, {f: merge(bent, search(f / 60)) for f in range(0, 61, 10)}, hidden=["tool"])


def raking(f):
    """The long arms flung back and raked forward and down, the head thrust
    after them, and drawn back again."""
    keys = [(0, 0.0, 0.0), (12, 1.0, 0.0), (19, 0.0, 1.0), (26, 0.0, 1.0), (36, 0.0, 0.3), (45, 0.0, 0.0)]
    for (f0, b0, r0), (f1, b1, r1) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            t = (f - f0) / (f1 - f0)
            t = t * t * (3 - 2 * t)
            back, rake = b0 + (b1 - b0) * t, r0 + (r1 - r0) * t
            break
    return {"armL": (35 * back - 105 * rake, 0, -18 * back - 8 * rake), "armR": (35 * back - 105 * rake, 0, 18 * back + 8 * rake),
            "forearmL": (-30 * back - 15 * rake, 0, 0), "forearmR": (-30 * back - 15 * rake, 0, 0),
            "torso": (-10 * back + 26 * rake, 0, 0), "head": (-8 * back + 14 * rake, 0, 0),
            "hips": {"turn": (0, 0, 0), "shift": (0, 0.03 * back - 0.05 * rake, -0.02 * rake)},
            "thighL": (-20 * rake, 0, 0), "shinL": (16 * rake, 0, 0), "thighR": (12 * rake, 0, 0), "shinR": (10 * rake, 0, 0)}


def recoiling(share):
    """A blow taken: rocked back and twisted from it, the arms thrown up."""
    return {"torso": (-18 * share, 0, 12 * share), "head": (-16 * share, 0, -18 * share),
            "hips": {"turn": (0, 0, 4 * share), "shift": (0, 0.05 * share, -0.02 * share)},
            "thighR": (14 * share, 0, 0), "shinR": (12 * share, 0, 0), "thighL": (-12 * share, 0, 0), "shinL": (18 * share, 0, 0),
            "armL": (-40 * share, 0, -26 * share), "armR": (-50 * share, 0, 22 * share), "forearmL": (-50 * share, 0, 0),
            "forearmR": (-40 * share, 0, 0)}


def searching(u):
    """Crouched over the ground, a hand raking at it, the head turning."""
    return {"hips": {"turn": (0, 0, 0), "shift": (0, -0.04, -0.20)}, "thighL": (-50, 0, 0), "shinL": (66, 0, 0), "footL": (-14, 0, 0),
            "thighR": (-38, 0, 0), "shinR": (58, 0, 0), "footR": (-18, 0, 0), "torso": (34, 0, 0),
            "head": (-10, 0, 30 * math.sin(2 * math.pi * u)),
            "armR": (-60 - 20 * math.sin(4 * math.pi * u), 0, 8), "forearmR": (-20, 0, 0), "armL": (-30, 0, -10), "forearmL": (-30, 0, 0)}
