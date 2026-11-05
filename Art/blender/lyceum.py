"""The Lyceum's hall, where the realm's scholars sit, and the orrery that
turns over its dome, two variants of one file, both still (the stage turns
the orrery):
- "hall": a round house of pale stone on a stepped drum, ten columns about
  a lit inner wall under a ring of stone, a shallow dome of slate ribbed
  and open at its eye, the eye's light within; four doors, to +x, -x, +z
  and -z, each framed and facing out, lit windows between them, braziers
  burning on the steps between the doors and lecterns before them, a book
  open on each. It fills the heart of its hex.
- "orrery": three rings of moonsalt about a lit moon on its stem, each
  tilted its own way.
Close: the entablature's dentils, the dome's ribs, the doors' iron, the
candles on the lecterns.

    python Art/blender/lyceum.py Art/models/lyceum.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *
from works import on_ring, posed

reset()

pale = material("plain_stone_pale", (0.68, 0.67, 0.64))
stone = material("plain_stone", (0.52, 0.51, 0.49))
slate = material("plain_slate", (0.23, 0.24, 0.28))
timber = material("plain_timber", (0.29, 0.21, 0.15))
dark = material("plain_timber_dark", (0.19, 0.14, 0.11))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
ring_metal = material("metal_moonsalt", (0.7, 0.73, 0.76), roughness=0.3, metallic=0.7)
candle = material("glow_candle", (1.0, 0.8, 0.52))
page = material("glow_page", (0.6, 0.48, 0.31))
fire = material("glow_fire", (1.0, 0.68, 0.32))
moon = material("glow_moonsalt", (0.88, 0.91, 0.95))

# The hall's measures, as Sources/NullmereModels/LyceumHall.swift keeps them.
DRUM, COLUMNS, CELLA, EAVES, CROWN = 0.08, 0.3, 0.21, 0.34, 0.47
DOME = [(COLUMNS + 0.03, EAVES), (COLUMNS - 0.01, EAVES + 0.06), (0.2, EAVES + 0.1), (0.1, CROWN - 0.01), (0.05, CROWN)]
BRAZIERS = [k * math.pi / 2 + math.pi / 4 for k in range(4)]
HALL = ["hall"]


def hall():
    far, fine = [], []
    # The drum it stands on, deep for a slope, three steps about it.
    far.append(rings("drum", [(0.6, -0.3), (0.6, 0.0), (0.55, 0.0), (0.55, 0.03), (0.5, 0.03), (0.5, 0.055), (0.45, 0.055), (0.45, DRUM),
                              (0.0, DRUM)], 20, pale))
    # The inner wall.
    far.append(rings("cella", [(CELLA, DRUM), (CELLA, EAVES - 0.02), (0.0, EAVES - 0.02)], 16, stone, caps=(False, False)))
    # Ten columns, their bases and capitals square to the ring.
    for index in range(10):
        angle = index * math.pi / 5
        x, _, z = on_ring(COLUMNS, 0, angle)
        far.append(rings("column", [(0.018, DRUM + 0.016), (0.015, EAVES - 0.03)], 8, pale, centre=(x, z), caps=(False, False)))
        for y0, y1 in ((DRUM, DRUM + 0.016), (EAVES - 0.03, EAVES - 0.014)):
            far.append(block("column block", (x - 0.0225, y0, z - 0.0225), (x + 0.0225, y1, z + 0.0225), stone, turn=-angle))
    # The ring of stone the dome rests on.
    far.append(rings("entablature", [(COLUMNS + 0.035, EAVES - 0.014), (COLUMNS + 0.035, EAVES), (CELLA - 0.002, EAVES),
                                     (CELLA - 0.002, EAVES - 0.014), (COLUMNS + 0.035, EAVES - 0.014)], 20, pale, caps=(False, False)))
    for index in range(40):
        angle = (index + 0.5) * math.pi / 20
        x, y, z = on_ring(COLUMNS + 0.037, EAVES - 0.024, angle)
        fine.append(block("dentil", (x - 0.006, y, z - 0.004), (x + 0.006, y + 0.008, z + 0.004), pale, turn=-angle - math.pi / 2))
    # The dome of slate, open at its eye, and its ribs.
    far.append(rings("dome", DOME, 20, slate, caps=(False, False)))
    far.append(rings("dome underside", [(COLUMNS + 0.03, EAVES), (CELLA, EAVES)], 20, pale, caps=(False, False)))
    for index in range(10):
        angle = (index + 0.5) * math.pi / 5
        prev = None
        for r, y in DOME:
            p = on_ring(r + 0.004, y + 0.004, angle)
            if prev is not None:
                fine.append(lath("dome rib", prev, p, 0.008, 0.006, pale))
            prev = p
    # The eye's rim of stone, and its light within.
    far.append(rings("eye rim", [(0.06, CROWN - 0.005), (0.06, CROWN + 0.012), (0.045, CROWN + 0.012), (0.045, CROWN - 0.005)], 12, pale,
                     caps=(False, False)))
    far.append(rings("eye light", [(0.045, CROWN), (0.0, CROWN + 0.006)], 10, candle))
    # The four doors, each framed and facing out, and lit windows between.
    for index in range(4):
        angle = index * math.pi / 2
        out = angle + math.pi / 2  # as the game's .rotationY faces a door outward from the ring
        door = block("door", (-0.035, -0.065, -0.006), (0.035, 0.065, 0.006), dark)
        frame = block("door frame", (-0.043, -0.072, -0.004), (0.043, 0.072, 0.004), pale)
        for obj, lift in ((door, 0.003), (frame, 0.0)):
            x, _, z = on_ring(CELLA + lift, 0, angle)
            far.append(posed(obj, (x, DRUM + 0.07, z), (0, 1, 0), out))
        fine.append(posed(block("door band", (-0.036, -0.003, -0.002), (0.036, 0.003, 0.002), iron),
                          on_ring(CELLA + 0.01, DRUM + 0.1, angle), (0, 1, 0), out))
        fine.append(posed(block("door band", (-0.036, -0.003, -0.002), (0.036, 0.003, 0.002), iron),
                          on_ring(CELLA + 0.01, DRUM + 0.04, angle), (0, 1, 0), out))
        w = angle + math.pi / 4
        far.append(lit("window", on_ring(CELLA + 0.002, 0.24, w), 0.035, 0.06, w + math.pi / 2, candle))
        fine.append(posed(block("sill", (-0.024, -0.003, -0.008), (0.024, 0.003, 0.008), pale), on_ring(CELLA + 0.004, 0.207, w),
                          (0, 1, 0), w + math.pi / 2))
    # Lecterns before the doors on the drum, a book open on each, a candle by it.
    for index in range(4):
        angle = index * math.pi / 2
        x, _, z = on_ring(0.4, 0, angle)
        far.append(rod("lectern post", (x, DRUM, z), (x, DRUM + 0.07, z), 0.008, dark, sides=6))
        board = block("lectern", (-0.025, -0.004, -0.0175), (0.025, 0.004, 0.0175), timber)
        far.append(posed(board, (x, DRUM + 0.075, z), (0, 1, 0), angle))
        book = block("book", (-0.02, -0.002, -0.014), (0.02, 0.002, 0.014), page)
        far.append(posed(book, (x, DRUM + 0.081, z), (0, 1, 0), angle))
        cx, _, cz = on_ring(0.4, 0, angle + 0.05)
        fine.append(rings("candle", [(0.003, DRUM + 0.079), (0.003, DRUM + 0.095)], 5, page, centre=(cx, cz)))
        fine.append(rings("candle flame", [(0.0025, DRUM + 0.095), (0.0, DRUM + 0.105)], 4, fire, centre=(cx, cz)))
    # Braziers on the step between the doors, burning.
    for angle in BRAZIERS:
        x, _, z = on_ring(0.47, 0, angle)
        far.append(rod("brazier stem", (x, 0.055, z), (x, DRUM + 0.1, z), 0.008, iron, sides=5))
        far.append(rings("brazier", [(0.0, DRUM + 0.095), (0.035, DRUM + 0.1), (0.04, DRUM + 0.125)], 6, iron, centre=(x, z), caps=(True, False)))
        far.append(rings("brazier fire", [(0.03, DRUM + 0.115), (0.034, DRUM + 0.137), (0.0, DRUM + 0.185)], 5, fire, centre=(x, z)))
        fine.append(rings("brazier foot", [(0.016, 0.055), (0.012, 0.062)], 6, iron, centre=(x, z)))
    join(tagged("lyceum hall", HALL), far)
    join(tagged("lyceum hall close", HALL) + "!fine", fine)


def orrery():
    """Three rings of moonsalt about a lit moon on its stem, each tilted its
    own way, small enough to sit on the dome's eye."""
    pieces = [rod("orrery stem", (0, -0.02, 0), (0, 0.05, 0), 0.004, iron, sides=5),
              rings("orrery moon", [(0.0, 0.052), (0.0127, 0.0573), (0.018, 0.07), (0.0127, 0.0827), (0.0, 0.088)], 8, moon, smooth=True)]
    for index, tilt in enumerate((0.35, -0.6, 1.1)):
        r = 0.05 + 0.012 * index
        ring = rings("orrery ring", [(r - 0.0025, -0.0025), (r + 0.0025, -0.0025), (r + 0.0025, 0.0025), (r - 0.0025, 0.0025), (r - 0.0025, -0.0025)],
                     16, ring_metal, caps=(False, False))
        # Turned about the upright, then tipped about its own x, as the game
        # turned them; the world's y is Blender's z.
        ring.matrix_world = Matrix.Translation(at(0, 0.07, 0)) @ Matrix.Rotation(index * 1.2, 4, "Z") @ Matrix.Rotation(tilt, 4, "X")
        apply_transforms(ring)
        pieces.append(ring)
    join(tagged("orrery", ["orrery"]), pieces)


hall()
orrery()
finish_building(out_path("Art/models/lyceum.glb"), ["hall", "orrery"])
