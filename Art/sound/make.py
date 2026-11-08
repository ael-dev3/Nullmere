"""Makes the score's recorded instruments from the VS Chamber Orchestra:
Community Edition (VSCO-2-CE, CC0 1.0, recorded by Sam Gossner and Simon
Dalzell, cut by Elan Hickler), and writes them into the package as base64 in
Swift, for Sources/NullmereSound/Recordings.swift to read: no resource bundle
to carry into the app, the same bytes on the Mac and on Linux.

    python3 -I Art/sound/make.py <VSCO-2-CE checkout> Sources/NullmereSound/Recorded

Only the files named below are read (a checkout of just those will do). Each
note is made mono at 24 kHz, begun where it sounds, measured for the pitch it
truly sounds (a held note's through its players' vibrato), given the loudness
of its fellows (as BS.1770 weighs it, so a low string is as loud to the ear as
a high one), its tail let go once it has died away and, for the strings, a
stretch of its sustain found that loops without a seam, the join crossfaded
into the note itself. Each is written in eight-bit blocks of differences (see
`encode`), as exact to decode as to write.

The files it writes are generated: run this again to change them.
"""
import base64
import os
import sys
import textwrap
import warnings

import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter, resample_poly

warnings.simplefilter("ignore", wavfile.WavFileWarning)

RATE = 24_000
BLOCK = 32
# The steps a block's differences are counted in, each the last times the
# square root of two (3 dB), in whole numbers, so the Swift that reads them
# adds up the same.
STEPS = [int(round(2 ** (k / 2))) for k in range(32)]

# What is made, family by family: the file, the note it sounds (MIDI, as
# measured: the sections' names are an octave below what they sound, the
# glockenspiel's an octave below), and how each family is cut.
HARP = [(f"Strings/Harp/KSHarp_{name}_mf.wav", note) for name, note in
        [("C3", 48), ("E3", 52), ("G3", 55), ("B3", 59), ("D4", 62), ("F4", 65), ("A4", 69), ("C5", 72), ("E5", 76),
         ("G5", 79), ("B5", 83)]]
GLOCK = [(f"Percussion/Glock/glock_medium_{name}.wav", note) for name, note in
         [("G4", 79), ("C5", 84), ("G5", 91), ("C6", 96), ("G6", 103)]]
CELLOS = [(f"Strings/Cello Section/susvib/susvib_{name}_v1_1.wav", note) for name, note in
          [("C1", 36), ("E1", 40), ("G1", 43), ("B1", 47), ("D2", 50), ("F2", 53), ("A2", 57)]]
VIOLAS = [(f"Strings/Viola Section/susvib/ViolaEns_susvib_{name}_v1_1.wav", note) for name, note in
          [("B2", 59), ("D3", 62), ("F3", 65)]]
BASSES = [(f"Strings/Solo Contrabass/SusVib/BKCtbss_SusVib_{name}_v1_rr1.wav", note) for name, note in
          [("A#0", 34), ("C1", 36), ("D1", 38), ("E1", 40)]]
# The war's drums: a great drum struck with a mallet, forte and mezzo-forte,
# and a field drum with its snares off, struck twice alike.
# The war's horns: a French horn held forte, six notes a third or so apart
# across the octave and a half the calls are blown in. The library names
# each horn note an octave below the one it sounds.
HORNS = [(f"Brass/F Horn/sus/MOHorn_sus_{name}_v3_1.wav", note) for name, note in
         [("G1", 43), ("A#1", 46), ("D2", 50), ("F2", 53), ("A2", 57), ("C3", 60)]]
# A clarinet held at middle strength, four notes about the octave the reed's
# calls are sung in, named, as the horn's are, an octave below where they
# sound.
CLARINET = [(f"Woodwinds/Clarinet/susLong/DCClar_susLong_{name}_v2_rr1_sum.wav", note) for name, note in
            [("A#2", 58), ("D3", 62), ("F3", 65), ("A#3", 70)]]
# The forge's anvil, struck at middle strength and hard, a blow of each;
# and a slit drum of wood, struck mezzo-piano twice alike.
ANVIL = [(f"Percussion/Anvil_Hit1_{v}_Sum.wav", 0) for v in ("v2", "v3")]
SLIT = [(f"VSCO 1 Percussion/varWood/log_drum/slitdrum0_mp_{n}.wav", 0) for n in (1, 2)]
# A gong struck softly, for the watch's bell over the water; a tambourine's
# jingles struck three times, two softly and one harder, for coins counted
# out; and a cabasa rolled, for salt running through an hourglass.
GONG = [("Percussion/gongHit_p.wav", 0)]
TAMBOURINE = [(f"Percussion/Tamb1-Hit_{v}_Sum.wav", 0) for v in ("v1_rr1", "v1_rr2", "v2_rr1")]
CABASA = [("VSCO 1 Percussion/varMetal/various/cabasa_roll1.wav", 0)]
# Steel struck on steel, four blows: for a company's blow struck in close,
# and the din of a battle's ringing steel.
STEEL = [(f"Miscellania Raw/Misc 1/metal_hit{n}.wav", 0) for n in (1, 2, 3, 4)]
# Wood knocked, three clicks, read slower for hooves on hard ground; a
# slapstick's crack, for a ram's timber; a brick scraped, for a spade in
# stony earth; and a bass drum rubbed and a cymbal bowed, for dread.
WOOD = [(f"VSCO 1 Percussion/varWood/{name}.wav", 0) for name in ("wood_click_f", "wood_click_f2", "wood_click3")]
SLAPSTICK = [("VSCO 1 Percussion/varWood/slapstick2.wav", 0)]
SCRAPE = [("Miscellania Raw/Misc 1/brick_scrape2.wav", 0)]
DREAD = [("Percussion/bassdrum_rub1_v1.wav", 0), ("Percussion/susCymb1-bow-2.wav", 0)]
DRUMS = [("VSCO 1 Percussion/drums/other/ethnic/giant/mallet/EthnicLargeMallet_hit_f_1.wav", 0),
         ("VSCO 1 Percussion/drums/other/ethnic/giant/mallet/EthnicLargeMallet_hit_mf_1.wav", 0),
         ("VSCO 1 Percussion/drums/snare/drum1/snare1_nosnare_mf_1.wav", 0),
         ("VSCO 1 Percussion/drums/snare/drum1/snare1_nosnare_mf_2.wav", 0)]


def read(root, name):
    rate, data = wavfile.read(os.path.join(root, name))
    x = data.astype(np.float64)
    if data.dtype == np.int16:
        x /= 32768
    elif data.dtype == np.int32:
        x /= 2 ** 31
    if x.ndim > 1:
        x = x.mean(axis=1)
    if rate != RATE:
        g = np.gcd(rate, RATE)
        x = resample_poly(x, RATE // g, rate // g)
    # Anything standing still taken away (below 8 Hz).
    keep = np.exp(-2 * np.pi * 8 / RATE)
    return lfilter([1, -1], [1, -keep], x)


def k_weighted(x):
    """The signal as loudness is weighed (ITU-R BS.1770's K curve): the
    highs a little lifted, as a head lifts them, and the deepest lows
    let go."""
    w0 = 2 * np.pi * 1681.974450955533 / RATE
    a = 10 ** (3.999843853973347 / 40)
    alpha = np.sin(w0) / (2 * 0.7071752369554196)
    shelf_b = [a * ((a + 1) + (a - 1) * np.cos(w0) + 2 * np.sqrt(a) * alpha), -2 * a * ((a - 1) + (a + 1) * np.cos(w0)),
               a * ((a + 1) + (a - 1) * np.cos(w0) - 2 * np.sqrt(a) * alpha)]
    shelf_a = [(a + 1) - (a - 1) * np.cos(w0) + 2 * np.sqrt(a) * alpha, 2 * ((a - 1) - (a + 1) * np.cos(w0)),
               (a + 1) - (a - 1) * np.cos(w0) - 2 * np.sqrt(a) * alpha]
    w0 = 2 * np.pi * 38.13547087602444 / RATE
    alpha = np.sin(w0) / (2 * 0.5003270373238773)
    high_b = [(1 + np.cos(w0)) / 2, -(1 + np.cos(w0)), (1 + np.cos(w0)) / 2]
    high_a = [1 + alpha, -2 * np.cos(w0), 1 - alpha]
    return lfilter(high_b, high_a, lfilter(shelf_b, shelf_a, x))


def envelope(x, frame=480):
    n = len(x) // frame
    return np.sqrt(np.mean(x[: n * frame].reshape(n, frame) ** 2, axis=1) + 1e-20), frame


def onset(x, below=40):
    """Where the note begins: a little before it first rises above `below`
    decibels under its peak, from nothing."""
    peak = np.max(np.abs(x))
    first = int(np.argmax(np.abs(x) > peak * 10 ** (-below / 20)))
    start = max(first - RATE // 500, 0)
    y = x[start:].copy()
    fade = RATE // 1000
    y[:fade] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fade) / fade)
    return y


def pitch(x, note, start, length):
    """The frequency the note truly sounds near `note`: the spectrum's peak
    within a semitone of it, over a steady stretch, to a hundredth of a
    hertz."""
    seg = x[start: start + length]
    n = 1 << int(np.ceil(np.log2(len(seg) * 8)))
    s = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), n))
    f = np.fft.rfftfreq(n, 1 / RATE)
    want = 440 * 2 ** ((note - 69) / 12)
    band = np.where((f > want * 2 ** (-1 / 12)) & (f < want * 2 ** (1 / 12)))[0]
    i = band[np.argmax(s[band])]
    a, b, c = np.log(s[i - 1: i + 2] + 1e-12)
    shift = 0.5 * (a - c) / (a - 2 * b + c)
    return (i + shift) * RATE / n


def tracked(x, note, start, length):
    """The pitch a held note sounds through its players' vibrato: where each
    stretch of six periods best matches itself a period later (within a
    semitone of `note`), averaged in cents, the louder stretches the more."""
    want = 440 * 2 ** ((note - 69) / 12)
    frame = int(RATE / want * 6)
    shortest, longest = int(RATE / (want * 2 ** (1 / 12))), int(RATE / (want * 2 ** (-1 / 12))) + 1
    heard, weights = [], []
    for at in range(start, start + length - frame - longest, frame // 2):
        a = x[at: at + frame]
        scores = np.array([np.dot(a, x[at + lag: at + lag + frame])
                           / np.sqrt(np.dot(a, a) * np.dot(x[at + lag: at + lag + frame], x[at + lag: at + lag + frame]) + 1e-20)
                           for lag in range(shortest, longest + 1)])
        i = int(np.argmax(scores))
        lag = shortest + i
        if 0 < i < len(scores) - 1:
            p, q, r = scores[i - 1: i + 2]
            lag += 0.5 * (p - r) / (p - 2 * q + r)
        heard.append(np.log2(RATE / lag))
        weights.append(np.dot(a, a))
    return 2 ** np.average(heard, weights=weights)


def cut(x, below, longest, fade=0.6):
    """Its tail let go once it has died for good `below` decibels under its
    loudest (the last it rises above them: a string's ring swells and fades
    as its partials beat), or after `longest` seconds, fading out over the
    last part of what is kept."""
    env, frame = envelope(x)
    loud = np.where(env > env.max() * 10 ** (-below / 20))[0]
    end = min((loud[-1] + 1) * frame, int(longest * RATE), len(x))
    y = x[:end].copy()
    out = min(int(fade * RATE), int(end * 0.4))
    y[end - out:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(out) / out)
    return y


def looped(x, shortest=2.4, longest=3.4, join=0.35):
    """A stretch of the sustain that loops: after the bow has set and
    before it lifts, where the sound just before the stretch's end is most
    like that just before its start, so the end leads back to the start; the
    end then crossfaded into what came before the start, so the loop's join
    is the note itself. Returns the note cut at the loop's end, and where the
    loop starts."""
    env, frame = envelope(x)
    middle = np.median(env[len(env) // 5: len(env) * 3 // 5])
    set_ = int(np.argmax(env > 0.8 * middle)) * frame + int(0.3 * RATE)
    lifted = (len(env) - int(np.argmax(env[::-1] > 0.7 * middle))) * frame - int(0.2 * RATE)
    f = int(join * RATE)
    best = None
    for length in range(int(shortest * RATE), int(longest * RATE) + 1, RATE // 200):
        # Soon after the bow has set, so little is kept before the loop.
        for start in range(max(set_, f), min(lifted - length, set_ + int(1.2 * RATE)), RATE // 100):
            a = x[start - f: start]
            b = x[start + length - f: start + length]
            score = np.dot(a, b) / np.sqrt(np.dot(a, a) * np.dot(b, b) + 1e-20)
            level = abs(np.log(env[start // frame] / env[(start + length) // frame]))
            score -= level
            if best is None or score > best[0]:
                best = (score, start, length)
    _, start, length = best
    # Finer, a sample at a time about the best.
    for length2 in range(length - RATE // 200, length + RATE // 200):
        a = x[start - f: start]
        b = x[start + length2 - f: start + length2]
        score = np.dot(a, b) / np.sqrt(np.dot(a, a) * np.dot(b, b) + 1e-20)
        level = abs(np.log(env[start // frame] / env[(start + length2) // frame]))
        if score - level > best[0]:
            best = (score - level, start, length2)
    score, start, length = best
    end = start + length
    a = x[start - f: start]
    b = x[end - f: end]
    alike = np.dot(a, b) / np.sqrt(np.dot(a, a) * np.dot(b, b) + 1e-20)
    w = (np.arange(f) + 0.5) / f
    # Alike, the two sum as one: a straight crossfade; unlike, as two, by
    # equal power.
    if alike > 0.7:
        keep, take = 1 - w, w
    else:
        keep, take = np.cos(0.5 * np.pi * w), np.sin(0.5 * np.pi * w)
    y = x[:end].copy()
    y[end - f:] = b * keep + a * take
    return y, start, alike


def encode(x):
    """Eight-bit blocks of differences: each block of 32 samples, in
    sixteen-bit counts, as the step it is counted in (one of STEPS) and how
    it is foretold from what came before (nothing, the last sample, or the
    line through the last two), then each sample's difference from what was
    foretold in steps, -127 to 127. Foretold from what the reader will have
    read, so what is read is never more than half a step from what was
    written."""
    t = np.round(np.clip(x, -1, 1) * 32767).astype(np.int64)
    out = bytearray()
    h1 = h2 = 0
    for at in range(0, len(t), BLOCK):
        block = [int(v) for v in t[at: at + BLOCK]]
        block += [block[-1]] * (BLOCK - len(block))
        # The way that leaves least to count, as written.
        best = None
        for order in range(3):
            p1, p2, worst = h1, h2, 0
            for v in block:
                guess = 0 if order == 0 else p1 if order == 1 else 2 * p1 - p2
                worst = max(worst, abs(v - guess))
                p2, p1 = p1, v
            if best is None or worst < best[1]:
                best = (order, worst)
        order, worst = best
        k = next(i for i, s in enumerate(STEPS) if s * 127 >= worst)
        while True:
            step = STEPS[k]
            p1, p2, counts = h1, h2, []
            for v in block:
                guess = 0 if order == 0 else p1 if order == 1 else 2 * p1 - p2
                q = int(round((v - guess) / step))
                if abs(q) > 127:
                    break
                counts.append(q)
                p2, p1 = p1, guess + q * step
            else:
                break
            k += 1
        out.append(order << 5 | k)
        out.extend(bytes((q & 0xFF) for q in counts))
        h1, h2 = p1, p2
    return bytes(out)


def decode(data, count):
    """What the Swift reads: for tests of `encode` here."""
    h1 = h2 = 0
    out = []
    for at in range(0, len(data), BLOCK + 1):
        order, k = data[at] >> 5, data[at] & 31
        step = STEPS[k]
        for b in data[at + 1: at + 1 + BLOCK]:
            q = b - 256 if b > 127 else b
            guess = 0 if order == 0 else h1 if order == 1 else 2 * h1 - h2
            v = guess + q * step
            h2, h1 = h1, v
            out.append(v)
    return np.array(out[:count], dtype=np.float64) / 32768


def loudness(x, start, length):
    seg = k_weighted(x)[start: start + length]
    return np.sqrt(np.mean(seg ** 2))


def family(root, files, kind):
    made = []
    for name, note in files:
        x = read(root, name)
        if kind == "plucked":
            x = onset(x, below=40)
            x = cut(x, below=45, longest=6 if note < 60 else 5 if note < 72 else 4, fade=1)
            heard = (0, int(0.5 * RATE))
            sounded = pitch(x, note, int(0.05 * RATE), int(1.5 * RATE))
            loop = None
        elif kind == "struck":
            x = onset(x, below=40)
            x = cut(x, below=45, longest=4, fade=1)
            heard = (0, int(0.4 * RATE))
            sounded = pitch(x, note, int(0.02 * RATE), int(1.0 * RATE))
            loop = None
        elif kind in ("bowed", "blown"):
            x = onset(x, below=50)
            x, start, alike = looped(x)
            heard = (start, len(x) - start)
            sounded = tracked(x, note, start, len(x) - start)
            loop = (start, alike)
        elif kind == "rung":
            # Unpitched and let ring, as struck iron rings.
            x = onset(x, below=40)
            x = cut(x, below=50, longest=3, fade=0.8)
            heard = (0, int(0.25 * RATE))
            sounded = 0.0
            loop = None
        elif kind == "tolled":
            # A gong's long ring, seven seconds of it, fading over the last
            # two and a half.
            x = onset(x, below=40)
            x = cut(x, below=55, longest=7, fade=2.5)
            heard = (0, RATE)
            sounded = 0.0
            loop = None
        elif kind == "jingled":
            # Small metal shaken: let go once forty decibels down, at most
            # six tenths of a second on.
            x = onset(x, below=40)
            x = cut(x, below=40, longest=0.6, fade=0.2)
            heard = (0, int(0.1 * RATE))
            sounded = 0.0
            loop = None
        elif kind == "clanged":
            # Steel's clang, let go once forty-five decibels down, at most
            # six tenths of a second on.
            x = onset(x, below=40)
            x = cut(x, below=45, longest=0.6, fade=0.25)
            heard = (0, int(0.1 * RATE))
            sounded = 0.0
            loop = None
        elif kind == "knocked":
            # A knock or a crack: let go once forty decibels down, at most
            # three tenths of a second on.
            x = onset(x, below=40)
            x = cut(x, below=40, longest=0.3, fade=0.1)
            heard = (0, int(0.05 * RATE))
            sounded = 0.0
            loop = None
        elif kind == "scraped":
            # A scrape: its first six tenths of a second, the last quarter
            # of a second fading out.
            x = onset(x, below=40)
            x = cut(x, below=60, longest=0.6, fade=0.25)
            heard = (0, int(0.2 * RATE))
            sounded = 0.0
            loop = None
        elif kind == "swelled":
            # A swell rubbed or bowed, rising and dying away, three and a
            # half seconds of it at most.
            x = onset(x, below=40)
            x = cut(x, below=50, longest=3.5, fade=1.2)
            heard = (0, int(1.5 * RATE))
            sounded = 0.0
            loop = None
        elif kind == "shaken":
            # A rattle rolled: the first eight tenths of a second of it.
            x = onset(x, below=40)
            x = cut(x, below=60, longest=0.8, fade=0.3)
            heard = (0, int(0.5 * RATE))
            sounded = 0.0
            loop = None
        else:
            x = onset(x, below=40)
            x = cut(x, below=55, longest=1.5, fade=0.3)
            heard = (0, int(0.25 * RATE))
            sounded = 0.0
            loop = None
        made.append(dict(name=name, note=note, x=x, heard=heard, frequency=sounded, loop=loop))
    return made


def even(made, together=False):
    """Every note as loud to the ear as its fellows, and the loudest peak
    of them all just under full; `together` keeps them as loud as they
    were played, one to another."""
    levels = [loudness(m["x"], *m["heard"]) for m in made]
    for m, level in zip(made, levels):
        m["x"] = m["x"] / (np.mean(levels) if together else level)
    peak = max(np.max(np.abs(m["x"])) for m in made)
    for m in made:
        m["x"] = m["x"] * (0.97 / peak)


def swift(made, enum_name, title, out):
    lines = [f"// Generated by Art/sound/make.py from the VS Chamber Orchestra: Community Edition",
             "// (VSCO-2-CE, CC0 1.0). Don't edit it: run Art/sound/make.py again.", "", "extension Recordings {"]
    entries = []
    for i, m in enumerate(made):
        data = encode(m["x"])
        back = decode(data, len(m["x"]))
        error = np.max(np.abs(back - m["x"]))
        loop = m["loop"]
        label = f"{enum_name}{i}"
        text = textwrap.wrap(base64.b64encode(data).decode("ascii"), 100)
        lines.append(f"    /// {m['name']}: {len(m['x']) / RATE:.2f} s, sounding {m['frequency']:.2f} Hz"
                     + (f", looped from {loop[0] / RATE:.2f} s ({loop[1]:.2f} alike at the join)" if loop else "")
                     + f", read back within {error * 32768:.1f} of 32,768.")
        lines.append(f"    static let {label} = \"\"\"")
        lines += [f"        {line}" for line in text]
        lines.append("        \"\"\"")
        entries.append(f"        Made(note: {m['note']}, frequency: {m['frequency']:.3f}, count: {len(m['x'])}, "
                       f"loop: {loop[0] if loop else 'nil'}, text: {label}),")
        print(f"{m['name'].split('/')[-1]:44s} {len(m['x']) / RATE:5.2f}s {m['frequency']:8.2f}Hz "
              f"err {error * 32768:6.1f} {'loop %.2f alike %.2f' % (loop[0] / RATE, loop[1]) if loop else ''}")
    lines.append(f"    /// {title}")
    lines.append(f"    static let {enum_name}: [Made] = [")
    lines += entries
    lines.append("    ]")
    lines.append("}")
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{out}: {os.path.getsize(out)} bytes")


def main():
    root, out = sys.argv[1:3]
    os.makedirs(out, exist_ok=True)
    harp = family(root, HARP, "plucked")
    even(harp)
    swift(harp, "harp", "The harp, plucked mezzo-forte: eleven strings, C3 to B5.", os.path.join(out, "HarpFile.swift"))
    glock = family(root, GLOCK, "struck")
    even(glock)
    swift(glock, "glockenspiel", "The glockenspiel, struck with medium mallets: five bars, G5 to G7.",
          os.path.join(out, "GlockenspielFile.swift"))
    strings = family(root, CELLOS, "bowed") + family(root, VIOLAS, "bowed") + family(root, BASSES, "bowed")
    even(strings)
    swift(strings[: len(CELLOS)], "cellos", "The cellos, bowed with vibrato, softly: seven notes, C2 to A3.",
          os.path.join(out, "CellosFile.swift"))
    swift(strings[len(CELLOS): len(CELLOS) + len(VIOLAS)], "violas",
          "The violas, bowed with vibrato, softly: three notes, B3 to F4.", os.path.join(out, "ViolasFile.swift"))
    swift(strings[len(CELLOS) + len(VIOLAS):], "basses",
          "The double bass, bowed with vibrato, softly: four notes, A sharp 1 to E2.", os.path.join(out, "BassesFile.swift"))
    horns = family(root, HORNS, "blown")
    even(horns)
    swift(horns, "horns", "The French horn, held forte: six notes, G2 to C4.", os.path.join(out, "HornsFile.swift"))
    clarinet = family(root, CLARINET, "blown")
    even(clarinet)
    swift(clarinet, "clarinet", "The clarinet, held at middle strength: four notes, A sharp 3 to A sharp 4.",
          os.path.join(out, "ClarinetFile.swift"))
    anvil = family(root, ANVIL, "rung")
    even(anvil, together=True)
    swift(anvil, "anvil", "The anvil, struck at middle strength and hard.", os.path.join(out, "AnvilFile.swift"))
    slit = family(root, SLIT, "drum")
    even(slit, together=True)
    swift(slit, "slitDrum", "A slit drum of wood, struck mezzo-piano twice.", os.path.join(out, "SlitDrumFile.swift"))
    gong = family(root, GONG, "tolled")
    even(gong)
    swift(gong, "gong", "A gong, struck softly.", os.path.join(out, "GongFile.swift"))
    tambourine = family(root, TAMBOURINE, "jingled")
    even(tambourine, together=True)
    swift(tambourine, "tambourine", "A tambourine's jingles, struck softly twice and once harder.",
          os.path.join(out, "TambourineFile.swift"))
    cabasa = family(root, CABASA, "shaken")
    even(cabasa)
    swift(cabasa, "cabasa", "A cabasa, rolled.", os.path.join(out, "CabasaFile.swift"))
    steel = family(root, STEEL, "clanged")
    even(steel)
    swift(steel, "steel", "Steel struck on steel, four blows.", os.path.join(out, "SteelFile.swift"))
    wood = family(root, WOOD, "knocked")
    even(wood)
    swift(wood, "wood", "Wood knocked, three clicks.", os.path.join(out, "WoodFile.swift"))
    slapstick = family(root, SLAPSTICK, "knocked")
    even(slapstick)
    swift(slapstick, "slapstick", "A slapstick's crack.", os.path.join(out, "SlapstickFile.swift"))
    scrape = family(root, SCRAPE, "scraped")
    even(scrape)
    swift(scrape, "scrape", "A brick scraped.", os.path.join(out, "ScrapeFile.swift"))
    dread = family(root, DREAD, "swelled")
    even(dread)
    swift(dread, "dread", "A bass drum rubbed, and a suspended cymbal bowed.", os.path.join(out, "DreadFile.swift"))
    drums = family(root, DRUMS, "drum")
    great, field = drums[:2], drums[2:]
    even(great, together=True)
    even(field, together=True)
    swift(great + field, "drums", "The war's drums: the great drum forte and mezzo-forte, then the field drum twice.",
          os.path.join(out, "DrumsFile.swift"))


if __name__ == "__main__":
    main()
