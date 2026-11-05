"""A hold's keep, or a seat's: a square tower over a hall, every people's
in one file. The tower is buttressed at its corners, its parapet corbelled
out and crenellated, under a roof of four slopes with dormers lit in it and
the House's pennant over it; the hall before it is roofed in the House's
colour, its chimney smoking, its door up two steps between lanterns, its
stores beside it. A seat's tower stands higher between two round towers
under the House's cones, a curtain behind, the House's great banner hung
down its face.

    python Art/blender/keep.py Art/models/keep.glb
    python Art/blender/keep.py Art/models/seat.glb seat

Each people builds it its own way, and the game gives each its colours and
grain by the materials it is made of (the stone of its walls, its dark
courses, its trim and its roof: Art.keep in Sources/NullmereModels/Art);
the pitch of its roof and its crown are its own pieces: the Saltborn's
moonsalt grown about the peak, the Strandfolk's beacon on the parapet.
Close, the keep is dressed in quoins, framed and shuttered windows, ribs
down the roof, the hall's frame, its gable and the House's arms, a bell in
its cote, ivy and the keeper's logs and handcart.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *

reset()
SEAT = "seat" in sys.argv[2:]
PEOPLES = ["common", "saltborn", "fenfolk", "blackwood", "spinewardens", "moundClans", "strandfolk"]
# How steep each people's tower roof is against the common keep's.
PITCH = {"common": 1.0, "saltborn": 1.0, "strandfolk": 1.0, "fenfolk": 1.5, "blackwood": 1.7, "spinewardens": 0.7, "moundClans": 0.6}
PITCHES = sorted({p: [n for n in PEOPLES if PITCH[n] == p] for p in PITCH.values()}.items())

# The materials a people's way of building recolours and regrains.
wall = material("plain_stone_wall", (0.52, 0.51, 0.49))
dark = material("plain_stone_dark", (0.37, 0.37, 0.38))
trim = material("plain_stone_trim", (0.68, 0.67, 0.64))
roof = material("plain_slate_roof", (0.23, 0.24, 0.28))
rib = material("plain_slate_rib", (0.16, 0.17, 0.2))
# And those every keep shares.
beam = material("plain_timber_dark", (0.19, 0.14, 0.11))
wood = material("plain_timber", (0.29, 0.21, 0.15))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
house = material("house_roof", (0.78, 0.78, 0.78))
house_dark = material("house_dark", (0.5, 0.5, 0.5))
banner = material("cloth_banner", (0.78, 0.78, 0.78))
candle = material("glow_candle", (1.0, 0.8, 0.52))
fire = material("glow_fire", (1.0, 0.68, 0.32))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
gold = material("metal_gold", (0.75, 0.62, 0.32), roughness=0.4, metallic=0.8)
salt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)
clay = material("plain_earth", (0.24, 0.21, 0.18))
ivy = material("foliage_ivy", (0.16, 0.24, 0.17))

TOWER = 0.92 if SEAT else 0.6
HALF = 0.17 if SEAT else 0.155
MIDDLE = -0.05
BACK, FRONT = -HALF + MIDDLE, HALF + MIDDLE
PARAPET = HALF + 0.025
HALL_FRONT = 0.34 if SEAT else 0.3
HALL_BACK = HALF - 0.06
RISE = 0.3 if SEAT else 0.22
# The top of the hall's chimney, where its smoke rises (Holds.chimney).
FLUE = (0.13, 0.43, (HALF - 0.06 + HALL_FRONT) / 2)

# MARK: The tower

pieces = [rings("plinth", [(0.37, -0.3), (0.37, 0.025), (0.34, 0.045)], 8, dark, twist=math.pi / 8)]
pieces.append(block("tower", (-HALF, 0.03, BACK), (HALF, TOWER, FRONT), wall))
# Buttresses at the corners, stepping in as they rise.
for x in (-HALF, HALF):
    for z in (BACK, FRONT):
        pieces.append(rings("buttress", [(0.045, 0.03), (0.04, TOWER * 0.3), (0.035, TOWER * 0.55), (0.0, TOWER * 0.62)], 4, dark,
                            twist=math.pi / 4, centre=(x, z)))
# The parapet corbelled out and crenellated.
pieces.append(block("parapet", (-PARAPET, TOWER - 0.01, -PARAPET + MIDDLE), (PARAPET, TOWER + 0.06, PARAPET + MIDDLE), trim))
corners = [(-PARAPET, MIDDLE - PARAPET), (PARAPET, MIDDLE - PARAPET), (PARAPET, MIDDLE + PARAPET), (-PARAPET, MIDDLE + PARAPET)]
for i in range(4):
    (ax, az), (bx, bz) = corners[i], corners[(i + 1) % 4]
    pieces.append(merlons("merlons", (ax, TOWER + 0.06, az), (bx, TOWER + 0.06, bz), 3, (0.06, 0.05, 0.035), trim))
# Courses girdling the tower, corbels under the parapet.
for level in (TOWER * 0.36, TOWER * 0.7):
    pieces.append(block("course", (-HALF - 0.008, level, BACK - 0.008), (HALF + 0.008, level + 0.016, FRONT + 0.008), trim))
for index in range(3):
    t = (index - 1) * HALF * 0.62
    y = TOWER - 0.045
    for low, high in (((t - 0.013, y - 0.015, FRONT), (t + 0.013, y + 0.015, FRONT + 0.024)),
                      ((t - 0.013, y - 0.015, BACK - 0.024), (t + 0.013, y + 0.015, BACK)),
                      ((HALF, y - 0.015, MIDDLE + t - 0.013), (HALF + 0.024, y + 0.015, MIDDLE + t + 0.013)),
                      ((-HALF - 0.024, y - 0.015, MIDDLE + t - 0.013), (-HALF, y - 0.015 + 0.03, MIDDLE + t + 0.013))):
        pieces.append(block("corbel", low, high, trim))
# Slits for its bows on the back and the sides.
slit = TOWER * 0.53
pieces.append(block("slit", (-0.006, slit - 0.035, BACK - 0.009), (0.006, slit + 0.035, BACK + 0.001), beam))
for x in (HALF + 0.004, -HALF - 0.004):
    pieces.append(block("slit", (x - 0.005, slit - 0.035, MIDDLE - 0.006), (x + 0.005, slit + 0.035, MIDDLE + 0.006), beam))
join("tower", pieces)

# The windows lit high on the tower: on every face, twice up a seat's, but
# where its banner hangs down the front.
FACES = [(0.0, (0, 0, FRONT)), (math.pi, (0, 0, BACK)), (math.pi / 2, (HALF, 0, MIDDLE)), (-math.pi / 2, (-HALF, 0, MIDDLE))]
WINDOWS = [(facing, (c[0], y, c[2])) for facing, c in FACES[(1 if SEAT else 0):] for y in ((0.45, 0.72) if SEAT else (0.42,))]
join("tower windows", [lit("window", faced(c, facing, 0, 0, 0.002), 0.035, 0.07, facing, candle) for facing, c in WINDOWS])

# MARK: Each people's roof

ROOF_BASE = TOWER + 0.04
for pitch, names in PITCHES:
    height = RISE * pitch
    group = []
    group.append(hip_roof("roof", (0, MIDDLE), HALF * 1.7, HALF * 1.7, ROOF_BASE, height, roof, overhang=0.012, thickness=0.012))
    # Dormers lit in the roof, front and back.
    for side in (1, -1):
        facing = 0.0 if side > 0 else math.pi
        z = MIDDLE + side * HALF * 0.36
        y = ROOF_BASE + height * 0.3
        group.append(block("dormer", faced((0, y, z), facing, -0.026, -0.02, -0.03), faced((0, y, z), facing, 0.026, 0.035, 0.012), wall))
        group.append(gable_roof("dormer roof", (0, z - side * 0.009), 0.042, 0.056, y + 0.035, 0.028, roof, overhang=0.006))
        group.append(lit("dormer window", faced((0, y + 0.008, z), facing, 0, 0, 0.013), 0.022, 0.026, facing, candle))
    join(tagged("roof", names), group)
    # Close: ribs down the hips and two courses across.
    reach, peak = HALF * 0.85, (0, ROOF_BASE + height, MIDDLE)
    ribs = [lath("rib", (x, ROOF_BASE, MIDDLE + z), peak, 0.012, 0.012, rib) for x, z in ((-reach, -reach), (reach, -reach), (reach, reach),
                                                                                            (-reach, reach))]
    for t in (0.22, 0.58):
        r, y = reach * (1 - t), ROOF_BASE + height * t
        square = [(-r, y, MIDDLE - r), (r, y, MIDDLE - r), (r, y, MIDDLE + r), (-r, y, MIDDLE + r)]
        ribs += [lath("course", square[i], square[(i + 1) % 4], 0.009, 0.009, rib) for i in range(4)]
    ribs.append(rings("finial", [(0.0, peak[1] - 0.005), (0.014, peak[1] + 0.012), (0.0, peak[1] + 0.03)], 6, gold, centre=(0, MIDDLE)))
    join(tagged("roof close", names) + "!fine", ribs)
    if "saltborn" in names:
        # Moonsalt grown about the peak, round the pennant's pole.
        crystals = [rings("crystal", [(0.016, peak[1] - 0.05), (0.0, peak[1] - 0.05 + 0.07 + 0.025 * i)], 5, salt, twist=float(i),
                          centre=(dx, MIDDLE + dz)) for i, (dx, dz) in enumerate(((0.03, 0.02), (-0.032, -0.01), (0.006, -0.038)))]
        join("moonsalt@saltborn", crystals)

# A brazier on the parapet's seaward corner, burning.
corner = (PARAPET - 0.03, TOWER + 0.06, PARAPET + MIDDLE - 0.03)
join("beacon@strandfolk", [block("brazier", (corner[0] - 0.025, corner[1], corner[2] - 0.025), (corner[0] + 0.025, corner[1] + 0.035,
                                                                                                corner[2] + 0.025), dark),
                           block("fire", (corner[0] - 0.018, corner[1] + 0.035, corner[2] - 0.018),
                                 (corner[0] + 0.018, corner[1] + 0.07, corner[2] + 0.018), fire)])

# MARK: The hall, its chimney and its door

hall = [block("hall", (-0.2, 0.03, HALL_BACK), (0.2, 0.25, HALL_FRONT), trim),
        block("chimney", (FLUE[0] - 0.026, 0.22, FLUE[2] - 0.026), (FLUE[0] + 0.026, FLUE[1] - 0.01, FLUE[2] + 0.026), dark),
        # Steps up to its door.
        block("step", (-0.06, 0.0, HALL_FRONT), (0.06, 0.045, HALL_FRONT + 0.025), trim),
        block("step", (-0.045, 0.0, HALL_FRONT + 0.025), (0.045, 0.025, HALL_FRONT + 0.045), trim),
        block("door", (-0.035, 0.035, HALL_FRONT), (0.035, 0.165, HALL_FRONT + 0.01), beam)]
for x in (-0.2, -0.055, 0.055, 0.2):
    hall.append(block("post", (x - 0.007, 0.03, HALL_FRONT), (x + 0.007, 0.25, HALL_FRONT + 0.012), beam))
join("hall", hall)
join("hall roof", [gable_roof("hall roof", (0, (HALL_BACK + HALL_FRONT) / 2), 0.4, HALL_FRONT - HALL_BACK, 0.25, 0.13, house,
                              overhang=0.025, thickness=0.008)])
lights = [lit("hall window", (x, 0.15, HALL_FRONT + 0.002), 0.03, 0.05, 0.0, candle) for x in (-0.12, 0.12)]
for x in (-0.075, 0.075):
    lights.append(block("lantern", (x - 0.007, 0.141, HALL_FRONT + 0.023), (x + 0.007, 0.163, HALL_FRONT + 0.037), candle))
join("hall lights", lights)
join("lantern arms", [lath("arm", (x, 0.17, HALL_FRONT + 0.005), (x, 0.17, HALL_FRONT + 0.03), 0.006, 0.006, iron) for x in (-0.075, 0.075)])
# The hall's stores beside it.
stores = [rings("barrel", [(0.022, 0.03), (0.026, 0.054), (0.022, 0.078)], 6, pale if i == 2 else wood, centre=(x, z))
          for i, (x, z) in enumerate(((-0.25, 0.17), (-0.25, 0.23), (0.27, 0.2)))]
stores.append(block("crate", (0.22, 0.03, 0.23), (0.26, 0.07, 0.27), grey, turn=0.3))
join("stores", stores)

# MARK: The pennant over the tower

POLE = TOWER + (0.62 if SEAT else 0.42)
join("pole", [rod("pole", (0, TOWER + 0.1, MIDDLE), (0, POLE, MIDDLE), 0.008, beam, sides=4)])
flag("pennant", (0, POLE - 0.01, MIDDLE), 0.34 if SEAT else 0.18, 0.22 if SEAT else 0.08, banner, turn=math.pi / 2, tail=not SEAT)

# MARK: A seat's round towers, its curtain and its banner

if SEAT:
    flanks = []
    cones = []
    for x in (-0.26, 0.26):
        flanks.append(rings("round tower", [(0.09, 0.03), (0.085, 0.65), (0.105, 0.67), (0.105, 0.73)], 8, wall, centre=(x, -0.08)))
        for k in range(6):
            angle = 2 * math.pi * (k + 0.5) / 6
            mx, mz = x + 0.098 * math.cos(angle), -0.08 + 0.098 * math.sin(angle)
            flanks.append(block("merlon", (mx - 0.02, 0.73, mz - 0.015), (mx + 0.02, 0.775, mz + 0.015), trim, turn=angle + math.pi / 2,
                                about=(mx, 0.73, mz)))
        cones.append(rings("cone", [(0.1, 0.72), (0.0, 1.01)], 8, house, centre=(x, -0.08)))
        flanks.append(lit("round window", (x, 0.48, -0.08 + 0.087), 0.03, 0.06, 0.0, candle))
    flanks.append(block("curtain", (-0.26, 0.03, -0.17), (0.26, 0.4, -0.08), dark))
    join("round towers", flanks)
    join("cones", cones)
    # The House's banner hung down the tower's face above the hall roof.
    drop = TOWER - 0.08 - 0.44
    top = TOWER - 0.08
    sheet = slab("banner", [(-0.045, top, FRONT + 0.006), (0.045, top, FRONT + 0.006), (0.045, top - drop, FRONT + 0.006),
                            (0.0, top - drop - 0.03, FRONT + 0.006), (-0.045, top - drop, FRONT + 0.006)], banner, 0.004)
    sway(sheet, lambda q: max(0.0, min(1.0, (top * UNIT - q.z) / (drop * UNIT) * 0.35)))
    join("banner rod", [lath("rod", (-0.055, top + 0.004, FRONT + 0.01), (0.055, top + 0.004, FRONT + 0.01), 0.01, 0.012, beam)])
    # A pennant over each cone.
    for x, side in ((-0.26, "R"), (0.26, "L")):
        join("cone pole " + side, [rod("pole", (x, 0.98, -0.08), (x, 1.11, -0.08), 0.006, beam, sides=4)])
        flag("cone pennant " + side, (x, 1.105, -0.08), 0.075, 0.032, banner, turn=math.pi if x < 0 else 0.0, tail=True)

# MARK: Close: what only the near view sees

close = []
# Quoins up the tower's corners above its buttresses, course by course.
y, course = TOWER * 0.6, 0
while y + 0.036 <= TOWER - 0.07:
    along, across = (0.07, 0.042) if course % 2 == 0 else (0.042, 0.07)
    for x in (-HALF, HALF):
        for z in (BACK, FRONT):
            sx, sz = (1 if x > 0 else -1), (1 if z > MIDDLE else -1)
            cx, cz = x + sx * (0.006 - along / 2), z + sz * (0.006 - across / 2)
            close.append(block("quoin", (cx - along / 2, y, cz - across / 2), (cx + along / 2, y + 0.036, cz + across / 2), trim, chamfer=0.003))
    y += 0.042
    course += 1
# Each tower window framed, a sill under it, a lintel over it and its
# shutters thrown back in the House's colour.
shutters = []
for facing, c in WINDOWS:
    close.append(block("sill", faced(c, facing, -0.027, -0.047, 0.0), faced(c, facing, 0.027, -0.035, 0.019), trim))
    close.append(block("lintel", faced(c, facing, -0.025, 0.035, 0.0), faced(c, facing, 0.025, 0.049, 0.014), trim))
    for side in (-1, 1):
        shutters.append(block("shutter", faced(c, facing, side * 0.03 - 0.0085, -0.034, 0.004),
                              faced(c, facing, side * 0.03 + 0.0085, 0.034, 0.01), house))
# The hall's frame: rails either side of the door, braces in the outer bays,
# rails and a post down each side.
face = HALL_FRONT + 0.004
for side in (-1, 1):
    close.append(lath("rail", (side * 0.193, 0.205, face), (side * 0.062, 0.205, face), 0.012, 0.012, beam))
    close.append(lath("brace", (side * 0.19, 0.045, face), (side * 0.143, 0.198, face), 0.01, 0.01, beam))
    for y in (0.07, 0.205):
        close.append(lath("rail", (side * 0.204, y, FRONT), (side * 0.204, y, HALL_FRONT), 0.012, 0.012, beam))
    close.append(block("post", (side * 0.204 - 0.006, 0.03, (FRONT + HALL_FRONT) / 2 - 0.007), (side * 0.204 + 0.006, 0.25,
                                                                                              (FRONT + HALL_FRONT) / 2 + 0.007), beam))
# The chimney capped, two pots on it.
close.append(block("cap", (FLUE[0] - 0.033, 0.407, FLUE[2] - 0.033), (FLUE[0] + 0.033, 0.423, FLUE[2] + 0.033), trim))
for dx in (-0.014, 0.014):
    close.append(rings("pot", [(0.009, 0.423), (0.0075, FLUE[1] + 0.015)], 5, clay, centre=(FLUE[0] + dx, FLUE[2])))
# The front gable plastered between bargeboards, a tie beam at its foot.
gable = HALL_FRONT + 0.025
close.append(slab("gable", [(-0.205, 0.25, gable + 0.002), (0.205, 0.25, gable + 0.002), (0, 0.3685, gable + 0.002)], trim, 0.002))
for side in (-1, 1):
    close.append(lath("bargeboard", (side * 0.229, 0.247, gable + 0.005), (0, 0.386, gable + 0.005), 0.008, 0.02, beam))
close.append(lath("tie", (-0.2, 0.254, gable + 0.004), (0.2, 0.254, gable + 0.004), 0.006, 0.012, beam))
# A bell-cote on the ridge over the gable, its bell hung in it.
cote = (0, 0.38, HALL_FRONT - 0.005)
for x in (-0.017, 0.017):
    close.append(rod("cote post", (x, cote[1] - 0.014, cote[2]), (x, cote[1] + 0.056, cote[2]), 0.004, beam, sides=4))
close.append(rod("cote beam", (-0.02, cote[1] + 0.045, cote[2]), (0.02, cote[1] + 0.045, cote[2]), 0.003, beam, sides=4))
metal = [rings("bell", [(0.004, cote[1] + 0.043), (0.008, cote[1] + 0.035), (0.013, cote[1] + 0.017), (0.0, cote[1] + 0.017)], 8, iron,
               centre=(0, cote[2])),
         # Iron on the door: straps and a ring.
         block("strap", (-0.03, 0.07, HALL_FRONT + 0.01), (0.03, 0.078, HALL_FRONT + 0.014), iron),
         block("strap", (-0.03, 0.125, HALL_FRONT + 0.01), (0.03, 0.133, HALL_FRONT + 0.014), iron),
         rings("ring", [(0.008, 0.1), (0.008, 0.104)], 6, iron, centre=(0.018, HALL_FRONT + 0.016))]
# The House's arms on the gable.
arms = (0, 0.302, gable + 0.006)
shutters.append(slab("arms", [(arms[0] + dx, arms[1] + dy, arms[2]) for dx, dy in ((-0.025, 0.026), (0.025, 0.026), (0.025, 0.004),
                                                                                   (0.018, -0.014), (0, -0.03), (-0.018, -0.014),
                                                                                   (-0.025, 0.004))], house, 0.003))
charge = [slab("charge", [(dx, arms[1] + dy, arms[2] + 0.0025) for dx, dy in ((-0.007, -0.022), (0.007, -0.022), (0.007, 0.026),
                                                                           (-0.007, 0.026))], house_dark, 0.001)]
# Windows lit down the hall's sides.
side_lights = []
for side in (-1, 1):
    for z in ((FRONT + HALL_FRONT) / 2 - 0.06, (FRONT + HALL_FRONT) / 2 + 0.06):
        side_lights.append(lit("hall side window", (side * 0.201, 0.15, z), 0.03, 0.05, side * math.pi / 2, candle))
# Boxes of flowers under the front windows, a bench by the door.
for x in (-0.12, 0.12):
    close.append(block("flower box", (x - 0.02, 0.112, HALL_FRONT), (x + 0.02, 0.124, HALL_FRONT + 0.016), wood))
close.append(block("bench", (0.08, 0.04, HALL_FRONT + 0.03), (0.17, 0.048, HALL_FRONT + 0.05), wood))
for x in (0.085, 0.165):
    close.append(block("bench leg", (x - 0.003, 0.03, HALL_FRONT + 0.033), (x + 0.003, 0.04, HALL_FRONT + 0.047), wood))
# Ivy up the tower's flank, potted shrubs by the steps, flowers in their boxes.
leaves = []
for i in range(14):
    fy = 0.06 + 0.032 * i
    fz = MIDDLE - 0.09 + 0.024 * math.sin(i * 1.7)
    leaves.append(block("ivy", (-HALF - 0.012, fy, fz - 0.03 + 0.004 * (i % 3)), (-HALF - 0.004, fy + 0.03, fz + 0.03), ivy))
for x in (-0.075, 0.075):
    close.append(rings("pot", [(0.012, 0.0), (0.016, 0.025)], 6, clay, centre=(x, HALL_FRONT + 0.06)))
    leaves.append(rings("shrub", [(0.0, 0.022), (0.022, 0.035), (0.016, 0.058), (0.0, 0.066)], 6, ivy, centre=(x, HALL_FRONT + 0.06)))
for x in (-0.12, 0.12):
    leaves.append(block("flowers", (x - 0.018, 0.124, HALL_FRONT + 0.002), (x + 0.018, 0.136, HALL_FRONT + 0.014), ivy))
# Spouts at the parapet's corners.
for x, z in ((-PARAPET, MIDDLE - PARAPET), (PARAPET, MIDDLE - PARAPET), (PARAPET, MIDDLE + PARAPET), (-PARAPET, MIDDLE + PARAPET)):
    close.append(lath("spout", (x * 0.92, TOWER + 0.015, MIDDLE + (z - MIDDLE) * 0.92), (x * 1.18, TOWER + 0.0, MIDDLE + (z - MIDDLE) * 1.18),
                      0.012, 0.012, trim))
# The tower's foot battered out over the plinth.
close.append(rings("batter", [(HALF * 1.414 + 0.03, 0.03), (HALF * 1.414 + 0.005, 0.1)], 4, dark, twist=math.pi / 4, centre=(0, MIDDLE),
                   caps=(False, False)))
# Logs by the tower's flank and a handcart on its other side.
logs = (0.035, 0.13) if SEAT else (-0.06, 0.06)
for x, y in ((-0.222, 0.047), (-0.256, 0.047), (-0.239, 0.075)):
    close.append(loft("log", [(tuple(at(x, y, logs[0])), 0.16, 0.16, {}), (tuple(at(x, y, logs[1])), 0.16, 0.16, {})], segments=6, mat=wood,
                      caps=(True, True), smooth=False))
cart = (0.27, 0.03, 0.065 if SEAT else -0.03)
close.append(block("cart bed", (cart[0] - 0.032, cart[1] + 0.05, cart[2] - 0.05), (cart[0] + 0.032, cart[1] + 0.062, cart[2] + 0.05), pale))
for side in (-1, 1):
    close.append(block("cart side", (cart[0] + side * 0.032 - 0.004, cart[1] + 0.062, cart[2] - 0.05),
                       (cart[0] + side * 0.032 + 0.004, cart[1] + 0.085, cart[2] + 0.05), wood))
    close.append(lath("cart shaft", (cart[0] + side * 0.024, cart[1] + 0.056, cart[2] + 0.05), (cart[0] + side * 0.024, cart[1] + 0.012,
                                                                                                 cart[2] + 0.1), 0.008, 0.008, wood))
    close.append(rings("cart wheel", [(0.038, -0.004), (0.038, 0.004)], 10, beam, centre=(0, 0)))
    wheel = close.pop()
    wheel.rotation_euler = (0, math.radians(90), 0)
    wheel.location = at(cart[0] + side * 0.044, cart[1] + 0.04, cart[2])
    apply_transforms(wheel)
    close.append(wheel)
if SEAT:
    for x in (-0.26, 0.26):
        close.append(rings("string course", [(0.086, 0.39), (0.097, 0.396), (0.097, 0.41), (0.086, 0.416)], 8, trim, centre=(x, -0.08),
                           caps=(False, False)))
        outward = (math.pi, math.pi * 0.75, math.pi * 1.25) if x < 0 else (0.0, math.pi * 0.25, -math.pi * 0.25)
        for angle in outward:
            sx, sz = x + 0.088 * math.cos(angle), -0.08 + 0.088 * math.sin(angle)
            close.append(block("slit", (sx - 0.006, 0.24, sz - 0.008), (sx + 0.006, 0.3, sz + 0.008), beam, turn=angle + math.pi / 2, about=(sx, 0.27, sz)))
        # Each cone ribbed and tipped, a door to the yard at its foot.
        for k in range(6):
            angle = 2 * math.pi * k / 6 + math.pi / 6
            close.append(lath("cone rib", (x + 0.1 * math.cos(angle), 0.72, -0.08 + 0.1 * math.sin(angle)), (x, 1.01, -0.08), 0.007, 0.007, beam))
        metal.append(rings("tip", [(0.0, 1.0), (0.012, 1.015), (0.0, 1.035)], 6, gold, centre=(x, -0.08)))
        close.append(block("yard door", (x - 0.022, 0.03, -0.08 + 0.083), (x + 0.022, 0.12, -0.08 + 0.093), beam))
join("keep close!fine", close)
join("keep shutters!fine", shutters)
join("keep charge!fine", charge)
join("keep lights!fine", side_lights)
join("keep iron!fine", metal)
join("keep leaves!fine", leaves)

finish_building(out_path("Art/models/keep.glb"), PEOPLES)
