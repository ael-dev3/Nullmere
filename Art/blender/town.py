"""The town about a hold, each piece a variant of one file, small and lean
for a hold has dozens, each facing +z toward the lane it stands on:
- the cottage, whitewashed under a steep thatch, its corner posts and sill
  dark, its chimney of stone; close, its window shuttered over a box of
  flowers, a step at its door, a pot on its chimney and firewood at its
  gable;
- the longhouse, long and low, of weathered planks under thatch, its
  woodpile at the gable; close, shutters, a step, a barrel by the door and
  a hood over the smoke hole in its ridge;
- the townhouse, stone below and timber-framed above, jutting over the
  lane, under slate; close, its sign hung out in the House's colour, boxes
  of flowers under its upper windows, a step and a chimney pot;
- the roundhouse, of wattle under a cone of thatch; close, posts and a
  lintel at its door, firewood against it and a cap on its smoke hole;
- the well, a ring of stone with dark water, a windlass under a little
  roof, a bucket on its rope;
- the field, ridged furrows of grain swaying in the wind, fenced about;
- a length of lane, a unit long, trodden earth with flat stones set in it,
  stretched to the length it runs;
- a market stall, its awning in the House's colour, a sack, a basket of
  salt and loaves on its board.
Every door is in the House's colour, every window lit at night; the stage
gives their stone, timber and slate the hold's people's colours.

    python Art/blender/town.py Art/models/town.glb
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building import *
from common import *

reset()
PIECES = ["cottage", "longhouse", "townhouse", "roundhouse", "well", "field", "lane", "stall"]

white = material("plain_stone_white", (0.84, 0.84, 0.82))
stone = material("plain_stone", (0.52, 0.51, 0.49))
dark_stone = material("plain_stone_dark", (0.37, 0.37, 0.38))
pale_stone = material("plain_stone_pale", (0.68, 0.67, 0.64))
beam = material("plain_timber_dark", (0.19, 0.14, 0.11))
timber = material("plain_timber", (0.29, 0.21, 0.15))
pale = material("plain_timber_pale", (0.45, 0.37, 0.28))
grey = material("plain_timber_grey", (0.42, 0.39, 0.35))
bark = material("plain_timber_bark", (0.21, 0.17, 0.14))
thatch = material("plain_thatch", (0.47, 0.41, 0.29))
thatch_cap = material("plain_thatch_cap", (0.39, 0.33, 0.24))
slate = material("plain_slate", (0.23, 0.24, 0.28))
loam = material("plain_earth_loam", (0.29, 0.22, 0.16))
yard = material("plain_earth_yard", (0.43, 0.37, 0.29))
water = material("plain_water", (0.1, 0.13, 0.16))
door = material("house_door", (0.78, 0.78, 0.78))
awning = material("house_awning", (0.78, 0.78, 0.78))
window = material("glow_candle", (1.0, 0.8, 0.52))
iron = material("metal_iron", (0.36, 0.37, 0.4), roughness=0.5, metallic=0.6)
clay = material("plain_clay", (0.48, 0.3, 0.24))
madder = material("plain_madder", (0.62, 0.26, 0.2))
weld = material("plain_weld", (0.8, 0.7, 0.3))
grain = material("foliage_grain", (0.68, 0.6, 0.3))
straw = material("foliage_straw", (0.72, 0.64, 0.4))
linen = material("plain_linen", (0.7, 0.67, 0.6))
reed = material("plain_reed", (0.47, 0.45, 0.33))
salt = material("crystal_moonsalt", (0.88, 0.91, 0.95), roughness=0.1)
bread = material("plain_bread", (0.62, 0.45, 0.25))
sack = material("plain_sack", (0.62, 0.54, 0.4))


def logs(name, ends, radius):
    return join(name, [loft("log", [(tuple(at(*a)), radius * UNIT, radius * UNIT, {}), (tuple(at(*b)), radius * UNIT, radius * UNIT, {})],
                            segments=5, mat=bark, caps=(True, True), smooth=False) for a, b in ends])


def shutters(centre, apart, height):
    return [block("shutter", (centre[0] + side * apart - 0.005, centre[1] - height / 2, centre[2]),
                  (centre[0] + side * apart + 0.005, centre[1] + height / 2, centre[2] + 0.003), timber) for side in (-1, 1)]


def flower_box(centre, width):
    parts = [block("flower box", (centre[0] - width / 2, centre[1] - 0.004, centre[2] - 0.005),
                   (centre[0] + width / 2, centre[1] + 0.004, centre[2] + 0.005), beam)]
    for index, colour in enumerate((madder, weld, madder)):
        x = centre[0] + (index - 1) * width * 0.3
        parts.append(rings("flower", [(0.005, centre[1] + 0.004), (0.0, centre[1] + 0.012)], 3, colour, twist=index, centre=(x, centre[2])))
    return parts


# MARK: The cottage

tag = ["cottage"]
join(tagged("cottage", tag), [
    block("walls", (-0.085, -0.05, -0.055), (0.085, 0.07, 0.055), white),
    gable_roof("thatch", (0, 0), 0.11, 0.17, 0.07, 0.08, thatch, overhang=0.014, along="x", thickness=0.01),
    block("chimney", (0.043, 0.07, -0.032), (0.067, 0.16, -0.008), stone),
] + [block("post", (x - 0.007, 0.0, 0.049), (x + 0.007, 0.07, 0.061), beam) for x in (-0.085, 0.085)] + [
    block("sill", (-0.09, 0.064, 0.049), (0.09, 0.076, 0.061), beam)])
join(tagged("cottage door", tag), [block("door", (-0.044, 0.0, 0.055), (-0.016, 0.052, 0.059), door)])
join(tagged("cottage window", tag), [lit("window", (0.037, 0.038, 0.056), 0.026, 0.022, 0.0, window)])
join(tagged("cottage close", tag) + "!fine", shutters((0.037, 0.038, 0.058), 0.019, 0.024) + flower_box((0.037, 0.024, 0.062), 0.03) + [
    block("step", (-0.048, 0.0, 0.057), (-0.012, 0.008, 0.073), pale_stone),
    rings("pot", [(0.007, 0.16), (0.0055, 0.174)], 5, clay, centre=(0.055, -0.02)),
    logs("firewood", [((0.094, y, z - 0.002), (0.118, y, z + 0.002)) for y, z in ((0.008, -0.02), (0.008, 0.0), (0.008, 0.02), (0.024, -0.01),
                                                                                (0.024, 0.01))], 0.008)])

# MARK: The longhouse

tag = ["longhouse"]
join(tagged("longhouse", tag), [
    block("walls", (-0.12, -0.05, -0.045), (0.12, 0.058, 0.045), grey),
    gable_roof("thatch", (0, 0), 0.09, 0.24, 0.058, 0.07, thatch, overhang=0.016, along="x", thickness=0.01),
    logs("woodpile", [((-0.128, 0.012, -0.044), (-0.128, 0.012, 0.016)), ((-0.128, 0.012, -0.016), (-0.128, 0.012, 0.044)),
                      ((-0.128, 0.03, -0.03), (-0.128, 0.03, 0.03))], 0.009)])
join(tagged("longhouse door", tag), [block("door", (0.036, 0.0, 0.045), (0.064, 0.046, 0.049), door)])
join(tagged("longhouse windows", tag), [lit("window", (x, 0.034, 0.046), 0.02, 0.016, 0.0, window) for x in (-0.035, -0.085)])
hood = [gable_roof("hood", (0.02, 0), 0.026, 0.03, 0.124, 0.014, thatch_cap, overhang=0.004, along="x")]
join(tagged("longhouse close", tag) + "!fine", shutters((-0.035, 0.034, 0.048), 0.015, 0.018) + shutters((-0.085, 0.034, 0.048), 0.015, 0.018) + [
    block("step", (0.033, 0.0, 0.047), (0.067, 0.008, 0.061), pale_stone),
    rings("barrel", [(0.012, 0.0), (0.015, 0.016), (0.012, 0.032)], 6, timber, centre=(0.098, 0.068))] + hood)

# MARK: The townhouse

tag = ["townhouse"]
frame = [block("stone", (-0.065, -0.05, -0.055), (0.065, 0.07, 0.055), stone),
         block("upper", (-0.07, 0.07, -0.058), (0.07, 0.15, 0.068), white),
         gable_roof("slate", (0, 0.005), 0.126, 0.14, 0.15, 0.075, slate, overhang=0.01, along="x", thickness=0.008),
         block("chimney", (-0.062, 0.15, -0.042), (-0.038, 0.235, -0.018), dark_stone)]
frame += [block("stud", (x - 0.005, 0.07, 0.068), (x + 0.005, 0.15, 0.072), beam) for x in (-0.07, -0.024, 0.024, 0.07)]
frame += [block("rail", (-0.072, y - 0.005, 0.068), (0.072, y + 0.005, 0.072), beam) for y in (0.072, 0.148)]
join(tagged("townhouse", tag), frame)
join(tagged("townhouse door", tag), [block("door", (-0.04, 0.0, 0.055), (-0.01, 0.06, 0.059), door)])
join(tagged("townhouse windows", tag), [lit("window", (0.03, 0.04, 0.056), 0.024, 0.026, 0.0, window)] +
     [lit("window", (x, 0.112, 0.07), 0.022, 0.03, 0.0, window) for x in (-0.047, 0.047)])
join(tagged("townhouse sign", tag) + "!fine", [block("sign", (0.0485, 0.075, 0.079), (0.0515, 0.095, 0.101), door)])
join(tagged("townhouse close", tag) + "!fine", [lath("bracket", (0.05, 0.1, 0.068), (0.05, 0.1, 0.1), 0.003, 0.003, iron)] +
     flower_box((-0.047, 0.093, 0.075), 0.024) + flower_box((0.047, 0.093, 0.075), 0.024) + [
    block("step", (-0.044, 0.0, 0.056), (-0.006, 0.008, 0.072), pale_stone),
    rings("pot", [(0.007, 0.235), (0.0055, 0.249)], 5, clay, centre=(-0.05, -0.03))])

# MARK: The roundhouse

tag = ["roundhouse"]
join(tagged("roundhouse", tag), [rings("wall", [(0.06, -0.05), (0.06, 0.055)], 8, grey, twist=math.pi / 8),
                                 rings("thatch", [(0.076, 0.05), (0.076, 0.055), (0.0, 0.145)], 8, thatch, twist=math.pi / 8)])
join(tagged("roundhouse door", tag), [block("door", (-0.014, 0.0, 0.056), (0.014, 0.048, 0.062), door)])
angle = 0.4
join(tagged("roundhouse window", tag), [lit("window", (0.061 * math.sin(angle), 0.032, 0.061 * math.cos(angle)), 0.016, 0.014, angle, window)])
close = [rod("door post", (x, 0.0, 0.066), (x, 0.05, 0.066), 0.003, beam, sides=4) for x in (-0.019, 0.019)]
close.append(block("lintel", (-0.023, 0.049, 0.062), (0.023, 0.055, 0.07), beam))
close.append(logs("firewood", [((0.068 * math.sin(a) - 0.02 * math.cos(a), y, 0.068 * math.cos(a) + 0.02 * math.sin(a)),
                                (0.068 * math.sin(a) + 0.02 * math.cos(a), y, 0.068 * math.cos(a) - 0.02 * math.sin(a)))
                               for y, a in ((0.008, -2.3 + math.pi / 2), (0.008, -2.6 + math.pi / 2), (0.022, -2.45 + math.pi / 2))], 0.007))
close.append(rings("smoke cap", [(0.014, 0.136), (0.014, 0.15), (0.0, 0.158)], 6, thatch_cap))
join(tagged("roundhouse close", tag) + "!fine", close)

# MARK: The well

tag = ["well"]
join(tagged("well", tag), [
    rings("ring", [(0.042, -0.04), (0.042, 0.036), (0.032, 0.036), (0.032, 0.012)], 8, stone, caps=(True, False)),
    rings("water", [(0.032, 0.012), (0.0, 0.012)], 8, water, caps=(False, False)),
    rod("post", (-0.036, 0.03, 0), (-0.036, 0.115, 0), 0.006, timber, sides=4),
    rod("post", (0.036, 0.03, 0), (0.036, 0.115, 0), 0.006, timber, sides=4),
    rod("windlass", (-0.036, 0.085, 0), (0.036, 0.085, 0), 0.006, pale, sides=4),
    rod("rope", (0, 0.085, 0), (0, 0.059, 0), 0.0015, linen, sides=3),
    rings("bucket", [(0.009, 0.045), (0.011, 0.059)], 5, beam),
    gable_roof("roof", (0, 0), 0.06, 0.1, 0.115, 0.035, slate, overhang=0.008, along="x", thickness=0.005)])

# MARK: The field

tag = ["field"]
join(tagged("field", tag), [block("loam", (-0.19, -0.06, -0.12), (0.19, 0.004, 0.12), loam)])
rows = []
for row in range(5):
    z = row * 0.046 - 0.092
    rows.append(block("furrow", (-0.17, 0.004, z - 0.013), (0.17, 0.034, z + 0.013), grain if row % 2 == 0 else straw))
furrows = join(tagged("grain", tag), rows)
sway(furrows, lambda q: max(0.0, min(1.0, (q.z - 0.004 * UNIT) / (0.03 * UNIT))) * 0.6)
fence = []
corners = [(-0.19, -0.12), (0.19, -0.12), (0.19, 0.12)]
for (ax, az), (bx, bz) in zip(corners, corners[1:]):
    length = math.hypot(bx - ax, bz - az)
    posts = max(int(round(length / 0.08)), 1)
    for i in range(posts + 1):
        t = i / posts
        fence.append(rod("fence post", (ax + (bx - ax) * t, -0.01, az + (bz - az) * t), (ax + (bx - ax) * t, 0.05, az + (bz - az) * t), 0.004,
                         timber, sides=3))
    for y in (0.022, 0.042):
        fence.append(lath("fence rail", (ax, y, az), (bx, y, bz), 0.004, 0.004, timber))
join(tagged("fence", tag), fence)

# MARK: The lane

tag = ["lane"]
# Trodden earth a unit long, crowned along its middle and worn down to the
# grass at its edges, so lengths laid end to end read as one way; a few
# flat stones set low in it near its middle, never at its ends (made long,
# for a length of lane is laid squeezed to a third or less of a unit).
section = [(-0.05, -0.05), (-0.05, -0.002), (-0.032, 0.004), (0.032, 0.004), (0.05, -0.002), (0.05, -0.05)]


def lane_strip(bm):
    ends = []
    for x in (-0.5, 0.5):
        ends.append([bm.verts.new(at(x, y, z)) for z, y in section])
    a, b = ends
    n = len(section)
    for i in range(n - 1):
        bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)


lane = [mesh_object("earth", lane_strip, yard)]
for index, (x, dz) in enumerate(((-0.17, -0.012), (0.04, 0.01), (0.21, -0.006))):
    lane.append(block("stone", (x - 0.07, 0.003, dz - 0.016), (x + 0.07, 0.006, dz + 0.016), stone if index % 2 == 0 else pale_stone))
join(tagged("lane", tag), lane)

# MARK: The stall

tag = ["stall"]
stall = [block("board", (-0.05, 0.03, -0.028), (0.05, 0.038, 0.028), pale)]
for x in (-0.045, 0.045):
    for z in (-0.024, 0.024):
        stall.append(rod("leg", (x, 0.0, z), (x, 0.03, z), 0.004, timber, sides=3))
    stall.append(rod("awning post", (x, 0.0, -0.034), (x, 0.1, -0.034), 0.004, timber, sides=3))
join(tagged("stall", tag), stall)
tilt = 0.32
cover = [(-0.06, 0.09 + 0.04 * math.sin(tilt), 0.004 - 0.04 * math.cos(tilt)), (0.06, 0.09 + 0.04 * math.sin(tilt), 0.004 - 0.04 * math.cos(tilt)),
         (0.06, 0.09 - 0.04 * math.sin(tilt), 0.004 + 0.04 * math.cos(tilt)), (-0.06, 0.09 - 0.04 * math.sin(tilt), 0.004 + 0.04 * math.cos(tilt))]
join(tagged("awning", tag), [slab("awning", cover, awning, 0.005, normal=(0, math.cos(tilt), math.sin(tilt)))])
join(tagged("wares", tag), [rings("sack", [(0.012, 0.038), (0.014, 0.046), (0.008, 0.058), (0.0, 0.062)], 5, sack, centre=(-0.025, 0)),
                            rings("basket", [(0.012, 0.038), (0.016, 0.05)], 5, reed, centre=(0.02, 0)),
                            rings("salt", [(0.012, 0.05), (0.008, 0.056), (0.0, 0.06)], 5, salt, centre=(0.02, 0)),
                            rings("loaf", [(0.0, 0.038), (0.008, 0.041), (0.006, 0.047), (0.0, 0.049)], 5, bread, centre=(-0.003, 0.016))])

finish_building(out_path("Art/models/town.glb"), PIECES)
