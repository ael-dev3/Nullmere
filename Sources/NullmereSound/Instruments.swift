import Foundation

// The score's instruments: a harp, a glockenspiel, a body of strings and
// the war's drums, each sounding notes recorded of a real one (Recordings),
// read faster or slower to sound true, and the small pieces of physics the
// cues and the towns are made of: noise, resonators and filters. Each is set
// in hertz and seconds, so it sounds alike at any sample rate; each finds
// its memory as it is made and none on the audio thread. They are written
// sample by sample in plain arithmetic, which runs quickly in a test's
// unoptimised build too.

/// A seeded generator of noise, the same every time from the same seed.
struct Noise {
    private var seed: UInt32

    init(seed: UInt32) {
        self.seed = seed
    }

    /// The next draw, from -1 to 1.
    mutating func next() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed >> 8) / Float(1 << 24) * 2 - 1
    }
}

/// How loud in each ear a sound across them is, from -1 (left) to 1
/// (right), by an equal-power law that never quite leaves the far ear.
func ears(_ pan: Float) -> (left: Float, right: Float) {
    let angle = (0.6 * min(max(pan, -1), 1) + 1) * .pi / 4
    return (cos(angle) * Float(2).squareRoot(), sin(angle) * Float(2).squareRoot())
}

/// One mode of something struck: a two-pole resonator, set ringing once
/// and left to die away. No oscillator runs; each mode is its own small
/// physics.
struct Resonator {
    private var turn: Float = 0
    private var keep: Float = 0
    private var last: Float = 0
    private var before: Float = 0

    init() {}

    /// Rings at `frequency`, this loud, dying away at `decay` (per second).
    init(frequency: Float, amplitude: Float, decay: Float, sampleRate: Float) {
        let omega = 2 * .pi * min(frequency, sampleRate * 0.45) / sampleRate
        let r = exp(-decay / sampleRate)
        turn = 2 * r * cos(omega)
        keep = r * r
        // Struck at rest: its first sample is its amplitude's sine.
        last = amplitude * r * sin(omega)
    }

    @inline(__always)
    mutating func next() -> Float {
        let value = turn * last - keep * before
        before = last
        last = value
        return value
    }
}

/// A two-pole low-pass, the state-variable filter in Zavalishin's
/// topology-preserving form, stable at every corner.
struct Lowpass {
    private var a1: Float = 1, a2: Float = 0, a3: Float = 0
    private var ic1: Float = 0, ic2: Float = 0

    init(corner: Float, resonance: Float = 0.7, sampleRate: Float) {
        let g = tan(.pi * min(corner, sampleRate * 0.45) / sampleRate)
        let k = 1 / resonance
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
    }

    @inline(__always)
    mutating func process(_ x: Float) -> Float {
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        return v2
    }
}

/// A band-pass, the same state-variable filter's band, as loud at its
/// centre as what it is given: the band a cue's noise is heard in, paper's
/// or grit's or a skin's. White noise loses most of itself to a narrow
/// band, so half that loss, in decibels, is made up, and the noise
/// sounds as loud at any sample rate.
struct Bandpass {
    private var a1: Float = 1, a2: Float = 0, a3: Float = 0
    private var k: Float = 1, makeup: Float = 1
    private var ic1: Float = 0, ic2: Float = 0

    init() {}

    init(centre: Float, width: Float, sampleRate: Float) {
        let g = tan(.pi * min(centre, sampleRate * 0.45) / sampleRate)
        k = 1 / width
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        let bandwidth = max(centre / width, 1)
        makeup = pow(24_000 / bandwidth, 0.25) * (sampleRate / 48_000).squareRoot()
    }

    @inline(__always)
    mutating func process(_ x: Float) -> Float {
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        return v1 * k * makeup
    }
}

/// A recorded note sounding: where in it, how many of its samples go by
/// for each sample heard, how loud it is in each ear, how bright (the share
/// of each new sample a one-pole low-pass takes), and how long it waits
/// before it sounds.
struct Reading {
    unowned(unsafe) let note: Recording
    var at: Double = 0
    var step: Double = 1
    var left: Float = 0
    var right: Float = 0
    var smooth: Float = 1
    var low: Float = 0
    var wait: Float = 0
    var sounding = false

    init(note: Recording) {
        self.note = note
    }

    /// Its next sample. A held note reads round its loop for as long as it
    /// sounds; any other is done at its end, and silent.
    @inline(__always)
    mutating func next() -> Float {
        if let loop = note.loop {
            if at >= Double(note.count) { at -= Double(note.count - loop) }
        } else if at >= Double(note.count - 1) {
            sounding = false
            return 0
        }
        let value = note.read(at)
        at += step
        low += (value - low) * smooth
        return low
    }

    /// The voice of `voices` to sound a new note: one silent, or the one
    /// with least of its note left to sound.
    static func free(_ voices: [Reading], rate: Float) -> Int {
        var best = 0, least = Float.infinity
        for (index, voice) in voices.enumerated() {
            guard voice.sounding else { return index }
            let rest = voice.wait + Float((Double(voice.note.count) - voice.at) / voice.step) / rate
            if rest < least {
                least = rest
                best = index
            }
        }
        return best
    }
}

/// The harp: eleven of its strings recorded, plucked mezzo-forte, from C3
/// to B5, each note read from the string nearest it, up to ten ringing at
/// once. How bright and how hard a pluck is sets how much of the string's
/// highs are heard, as a soft finger or a hard one leaves them.
final class Harp {
    static let voices = 10
    /// How loud a string plucked full is heard: as loud to the ear (as
    /// BS.1770 weighs it) as the score's harp was tuned to be.
    static let level: Float = 1.1

    let sampleRate: Float
    private(set) var strings: [Reading]
    /// How many strings have been plucked, for tests.
    private(set) var plucks = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        strings = Array(repeating: Reading(note: Recordings.harpNotes[0]), count: Harp.voices)
    }

    /// How many ring now.
    var sounding: Int { strings.filter(\.sounding).count }

    /// The corner, in hertz, of what a pluck this bright and this hard
    /// leaves of a string's highs: dull at 0.3, all of them by 0.6.
    static func corner(brightness: Float, strength: Float) -> Float {
        let bright = min(max(brightness, 0), 1), hard = min(max(strength, 0), 1)
        return 2_500 * pow(2, (bright - 0.3) * 10) * (0.7 + 0.6 * hard)
    }

    /// Plucks a string: how hard (0...1), how bright (0...1), where it is
    /// heard across the ears (-1 left to 1 right), and after how long.
    func pluck(_ frequency: Float, strength: Float, brightness: Float = 0.5, pan: Float = 0, wait: Float = 0) {
        let nearest = Recordings.nearest(Recordings.harpNotes, to: frequency)
        let slot = Reading.free(strings, rate: sampleRate)
        var voice = Reading(note: Recordings.harpNotes[nearest.index])
        voice.step = nearest.ratio * Double(Recordings.rate / sampleRate)
        let loud = min(max(strength, 0), 1) * Harp.level, heard = ears(pan)
        voice.left = heard.left * loud
        voice.right = heard.right * loud
        let corner = Harp.corner(brightness: brightness, strength: strength)
        voice.smooth = 1 - exp(-2 * .pi * min(corner, sampleRate * 0.45) / sampleRate)
        voice.wait = max(wait, 0)
        voice.sounding = true
        strings[slot] = voice
        plucks += 1
    }

    /// The strings' next sample in each ear.
    @inline(__always)
    func sample(dt: Float) -> (left: Float, right: Float) {
        var left: Float = 0, right: Float = 0
        for index in strings.indices where strings[index].sounding {
            if strings[index].wait > 0 {
                strings[index].wait -= dt
                continue
            }
            let value = strings[index].next()
            left += value * strings[index].left
            right += value * strings[index].right
        }
        return (left, right)
    }

    /// Silent again.
    func clear() {
        for index in strings.indices { strings[index].sounding = false }
    }
}

/// The glockenspiel: five of its bars recorded, struck with medium
/// mallets, from G5 to G7, each note read from the bar nearest it, up to
/// eight ringing at once. It sounds two octaves above the note written for
/// it, as a glockenspiel does.
final class Glockenspiel {
    static let bars = 8
    /// How loud a bar struck full is heard: as loud to the ear as the
    /// score's bells were tuned to be.
    static let level: Float = 4

    let sampleRate: Float
    private(set) var ringing: [Reading]
    /// How many bars have been struck, for tests.
    private(set) var struck = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        ringing = Array(repeating: Reading(note: Recordings.glockenspielNotes[0]), count: Glockenspiel.bars)
    }

    /// How many ring now.
    var sounding: Int { ringing.filter(\.sounding).count }

    /// Strikes the bar for a note written at `frequency`, this hard (0...1),
    /// from `pan`, after `wait` seconds.
    func strike(_ frequency: Float, strength: Float, pan: Float = 0, wait: Float = 0) {
        let nearest = Recordings.nearest(Recordings.glockenspielNotes, to: frequency * 4)
        let slot = Reading.free(ringing, rate: sampleRate)
        var voice = Reading(note: Recordings.glockenspielNotes[nearest.index])
        voice.step = nearest.ratio * Double(Recordings.rate / sampleRate)
        let loud = min(max(strength, 0), 1) * Glockenspiel.level, heard = ears(pan)
        voice.left = heard.left * loud
        voice.right = heard.right * loud
        voice.wait = max(wait, 0)
        voice.sounding = true
        ringing[slot] = voice
        struck += 1
    }

    /// The bars' next sample in each ear.
    @inline(__always)
    func sample(dt: Float) -> (left: Float, right: Float) {
        var left: Float = 0, right: Float = 0
        for index in ringing.indices where ringing[index].sounding {
            if ringing[index].wait > 0 {
                ringing[index].wait -= dt
                continue
            }
            let value = ringing[index].next()
            left += value * ringing[index].left
            right += value * ringing[index].right
        }
        return (left, right)
    }

    /// Silent again.
    func clear() {
        for index in ringing.indices { ringing[index].sounding = false }
    }
}

/// The horns: a French horn recorded held forte on six notes from G2 to
/// C4, each note read from the one nearest it, round the stretch of its
/// sustain that loops for as long as it is held; up to four sounding at
/// once. A note swells in as the player's breath fills the horn and falls
/// away when it is let go, so it never starts or stops on a click.
final class Horns {
    static let voices = 4
    /// How loud a note blown full is heard.
    static let level: Float = 1
    /// Seconds a note takes to swell in, and to fall away once let go.
    static let swell: Float = 0.08
    static let fall: Float = 0.5

    struct Voice {
        var reading: Reading
        /// Seconds it is still held, before it falls away.
        var held: Float
        /// How far it has swelled, 0 to 1.
        var breath: Float = 0
    }

    let sampleRate: Float
    private(set) var voices: [Voice]
    /// How many notes have been blown, for tests.
    private(set) var blown = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        voices = Array(repeating: Voice(reading: Reading(note: Recordings.hornNotes[0]), held: 0), count: Horns.voices)
    }

    /// How many sound now.
    var sounding: Int { voices.filter(\.reading.sounding).count }

    /// Blows a note: how hard (0...1), held how many seconds before it is
    /// let go, where it is heard across the ears (-1 left to 1 right), and
    /// after how long.
    func blow(_ frequency: Float, strength: Float, hold: Float, pan: Float = 0, wait: Float = 0) {
        let nearest = Recordings.nearest(Recordings.hornNotes, to: frequency)
        // A silent voice, or the one nearest done.
        var slot = 0, least = Float.infinity
        for (index, voice) in voices.enumerated() {
            guard voice.reading.sounding else {
                slot = index
                break
            }
            let rest = voice.reading.wait + max(voice.held, 0) + voice.breath * Horns.fall
            if rest < least {
                least = rest
                slot = index
            }
        }
        var reading = Reading(note: Recordings.hornNotes[nearest.index])
        reading.step = nearest.ratio * Double(Recordings.rate / sampleRate)
        let loud = min(max(strength, 0), 1) * Horns.level, heard = ears(pan)
        reading.left = heard.left * loud
        reading.right = heard.right * loud
        reading.wait = max(wait, 0)
        reading.sounding = true
        voices[slot] = Voice(reading: reading, held: max(hold, 0))
        blown += 1
    }

    /// The horns' next sample in each ear.
    @inline(__always)
    func sample(dt: Float) -> (left: Float, right: Float) {
        var left: Float = 0, right: Float = 0
        for index in voices.indices where voices[index].reading.sounding {
            if voices[index].reading.wait > 0 {
                voices[index].reading.wait -= dt
                continue
            }
            if voices[index].held > 0 {
                voices[index].held -= dt
                voices[index].breath = min(1, voices[index].breath + dt / Horns.swell)
            } else {
                voices[index].breath -= dt / Horns.fall
                if voices[index].breath <= 0 {
                    voices[index].reading.sounding = false
                    continue
                }
            }
            // Eased, so the swell and the fall have no corners.
            let b = voices[index].breath
            let value = voices[index].reading.next() * b * b * (3 - 2 * b)
            left += value * voices[index].reading.left
            right += value * voices[index].reading.right
        }
        return (left, right)
    }
}

/// A note of a body of strings bowed, as it was recorded: the cellos' up to
/// B flat 3 and the violas' from B3, softly with vibrato, or under a chord
/// the double bass's; the recorded note nearest it read to sound true, and
/// round the stretch of its sustain that loops, so it is held as long as
/// the chord is. Heard through a low-pass standing for how brightly the
/// mood bows, and from where its players sit: the violas left of the middle,
/// the cellos right of it, lower further right, and the bass furthest.
struct Bowed {
    let frequency: Float
    /// The corner of the mood's low-pass, in hertz: the strings are heard
    /// through one this many times higher.
    let corner: Float
    let bass: Bool
    private var reading: Reading
    private var body: Lowpass

    /// The lowest note the violas play.
    static let violas = Score.frequency(59)
    /// How loud a note is heard, and the bass beneath a chord: as loud to
    /// the ear as the score's strings were tuned to be.
    static let level: Float = 1.4
    static let bassLevel: Float = 1.15
    /// How many times higher than the mood's corner the strings are heard
    /// through a low-pass: recorded strings are darker than the saws they
    /// stand for.
    static let brightening: Float = 3

    init(frequency: Float, corner: Float, sampleRate: Float, bass: Bool = false) {
        self.frequency = frequency
        self.corner = corner
        self.bass = bass
        let violas = !bass && frequency >= Bowed.violas
        let notes = bass ? Recordings.bassNotes : violas ? Recordings.violaNotes : Recordings.celloNotes
        let nearest = Recordings.nearest(notes, to: frequency)
        reading = Reading(note: notes[nearest.index])
        reading.step = nearest.ratio * Double(Recordings.rate / sampleRate)
        reading.sounding = true
        let note = 69 + 12 * log2(frequency / 440)
        let pan: Float = bass ? 0.55 : violas ? -0.1 - (note - 59) / 40 : 0.5 - (note - 36) / 60
        let heard = ears(pan), loud = bass ? Bowed.bassLevel : Bowed.level
        reading.left = heard.left * loud
        reading.right = heard.right * loud
        body = Lowpass(corner: corner * Bowed.brightening, resonance: 0.7, sampleRate: sampleRate)
    }

    /// The next sample in each ear.
    @inline(__always)
    mutating func sample(dt: Float) -> (left: Float, right: Float) {
        let heard = body.process(reading.next())
        return (heard * reading.left, heard * reading.right)
    }
}

/// The war's drums as they were recorded: the great drum, struck with a
/// mallet forte, or mezzo-forte for a softer stroke, or the field drum with
/// its snares off, its two strokes in turn. A stroke rings on through the
/// next, so a drum has two voices.
struct Drum {
    enum Kind {
        case great, field
    }

    let kind: Kind
    let sampleRate: Float
    private var first: Reading
    private var second: Reading
    private var strokes = 0

    /// How loud a full stroke is heard: as loud to the ear as the score's
    /// drums were tuned to be.
    static let level: Float = 2.9

    init(_ kind: Kind, sampleRate: Float) {
        self.kind = kind
        self.sampleRate = sampleRate
        first = Reading(note: Recordings.drumNotes[0])
        second = first
    }

    /// Struck this hard (0...1): the recording of the stroke nearest it,
    /// as loud as the stroke.
    mutating func strike(_ strength: Float) {
        let notes = Recordings.drumNotes
        let index = kind == .great ? (strength >= 0.85 ? 0 : 1) : 2 + strokes % 2
        let full = notes[kind == .great ? 0 : 2]
        var voice = Reading(note: notes[index])
        voice.step = Double(Recordings.rate / sampleRate)
        voice.left = min(max(strength, 0), 1) * Drum.level * full.heard / max(notes[index].heard, 1e-6)
        voice.sounding = true
        if strokes % 2 == 0 { first = voice } else { second = voice }
        strokes += 1
    }

    var isSounding: Bool { first.sounding || second.sounding }

    @inline(__always)
    mutating func sample(dt: Float) -> Float {
        var sum: Float = 0
        if first.sounding { sum += first.next() * first.left }
        if second.sounding { sum += second.next() * second.left }
        return sum
    }
}
