import Foundation

// The score's instruments, each modelled on how a real one makes its sound
// rather than drawn from recordings of one: strings plucked, a body of
// strings bowed, bells and drums struck. Each is set in hertz and seconds,
// so it sounds alike at any sample rate; each finds its memory as it is
// made and none on the audio thread. They are written sample by sample in
// plain arithmetic, which runs quickly in a test's unoptimised build too.

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

/// The modes of a struck thing: their ratios to its note, how loud each,
/// and how fast each dies away (per second).
struct Timbre {
    let ratios: [Float]
    let amplitudes: [Float]
    let decays: [Float]

    /// Bars of glass or bell-bronze over the lake: near the harmonics, a
    /// little out of them, the upper ones quick to fade.
    static let glass = Timbre(ratios: [1, 2.0, 3.01, 4.16, 5.43], amplitudes: [1, 0.32, 0.14, 0.07, 0.035],
                              decays: [0.6, 1.1, 1.9, 3.0, 4.2])

    /// How long it rings before it has died sixty decibels.
    var life: Float { 6.9 / max(decays.min() ?? 1, 0.01) }
}

/// Bells struck, up to eight ringing at once, each of up to eight modes.
final class Bells {
    struct Bell {
        var modes = 0
        var left: Float = 0
        var right: Float = 0
        /// Seconds until it sounds (an echo waits its breath), its age, and
        /// how long it rings.
        var wait: Float = 0
        var age: Float = 0
        var life: Float = 0
        var sounding = false
    }

    static let count = 8
    static let modes = 8

    let sampleRate: Float
    private let resonators: UnsafeMutablePointer<Resonator>
    private(set) var bells: [Bell]
    /// How many have been struck, for tests.
    private(set) var struck = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        resonators = .allocate(capacity: Bells.count * Bells.modes)
        resonators.initialize(repeating: Resonator(), count: Bells.count * Bells.modes)
        bells = Array(repeating: Bell(), count: Bells.count)
    }

    deinit {
        resonators.deallocate()
    }

    /// How many ring now.
    var sounding: Int { bells.filter(\.sounding).count }

    /// Strikes a bell of this note and timbre, this hard, from `pan`, after
    /// `wait` seconds.
    func strike(_ frequency: Float, timbre: Timbre, strength: Float, pan: Float = 0, wait: Float = 0) {
        // A bell let go, or the one nearest its end, rings the note.
        let index = bells.indices.min { a, b in
            let x = bells[a], y = bells[b]
            if x.sounding != y.sounding { return !x.sounding }
            return x.life - x.age < y.life - y.age
        } ?? 0
        let modes = min(timbre.ratios.count, Bells.modes)
        for mode in 0..<modes {
            resonators[index * Bells.modes + mode] = Resonator(frequency: frequency * timbre.ratios[mode], amplitude: timbre.amplitudes[mode] * strength,
                                                               decay: timbre.decays[mode], sampleRate: sampleRate)
        }
        let heard = ears(pan)
        bells[index] = Bell(modes: modes, left: heard.left, right: heard.right, wait: wait, age: 0, life: wait + timbre.life, sounding: true)
        struck += 1
    }

    /// The bells' next sample in each ear.
    @inline(__always)
    func sample(dt: Float) -> (left: Float, right: Float) {
        var left: Float = 0, right: Float = 0
        for index in bells.indices where bells[index].sounding {
            bells[index].age += dt
            let bell = bells[index]
            if bell.age > bell.life {
                bells[index].sounding = false
                continue
            }
            guard bell.age > bell.wait else { continue }
            var sum: Float = 0
            let base = resonators + index * Bells.modes
            for mode in 0..<bell.modes { sum += base[mode].next() }
            left += sum * bell.left
            right += sum * bell.right
        }
        return (left, right)
    }

    /// Silent again.
    func clear() {
        for index in bells.indices { bells[index].sounding = false }
    }
}

/// Strings plucked, as a harp's or a lyre's are, after Karplus and Strong:
/// a burst of noise, shaped by where and how hard the string is plucked,
/// runs round a loop as long as the note's period, each time round a
/// little quieter and duller, so the note rings bright and mellows as it
/// dies, the low strings ringing longest. A one-pole all-pass makes up the
/// loop's fraction of a sample, so every string is in tune.
final class Harp {
    struct Voice {
        var start = 0
        var length = 1
        var cursor = 0
        /// The all-pass's coefficient, and what it last took and gave.
        var coefficient: Float = 0
        var taken: Float = 0
        var given: Float = 0
        /// The last sample round the loop, for its two-point average.
        var last: Float = 0
        /// What the loop keeps each time round.
        var keep: Float = 1
        var left: Float = 0
        var right: Float = 0
        /// Seconds until it is plucked (a chord rolled waits its turn),
        /// seconds since it was asked for, and how long until it is let go.
        var wait: Float = 0
        var age: Float = 0
        var life: Float = 0
        var sounding = false
    }

    static let voices = 10
    /// The lowest note a string can sound, in hertz.
    static let lowest: Float = 55
    /// How fast a note comes in, per second: whole in half a millisecond.
    static let onset: Float = 2_000

    let sampleRate: Float
    private let storage: UnsafeMutablePointer<Float>
    private let capacity: Int
    private(set) var strings: [Voice]
    private var noise = Noise(seed: 0x4A72_9E11)
    /// How many strings have been plucked, for tests.
    private(set) var plucks = 0

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        let room = Int(sampleRate / Harp.lowest) + 4
        capacity = room
        storage = .allocate(capacity: room * Harp.voices)
        storage.initialize(repeating: 0, count: room * Harp.voices)
        strings = (0..<Harp.voices).map { Voice(start: $0 * room) }
    }

    deinit {
        storage.deallocate()
    }

    /// How many ring now.
    var sounding: Int { strings.filter(\.sounding).count }

    /// Seconds a string of this pitch rings before it has died sixty
    /// decibels: the low ones longest, as on a harp.
    static func ringing(_ frequency: Float) -> Float {
        min(max(5.5 * (220 / frequency).squareRoot(), 1.6), 7)
    }

    /// Plucks a string: how hard (0...1), how bright (0...1), where it is
    /// heard across the ears (-1 left to 1 right), and after how long.
    func pluck(_ frequency: Float, strength: Float, brightness: Float = 0.5, pan: Float = 0, wait: Float = 0) {
        let period = sampleRate / max(frequency, Harp.lowest)
        // The loop's whole delay is its length, half a sample for the
        // average, and the all-pass's fraction, kept between 0.1 and 1.1.
        let length = min(max(Int(period - 0.6), 2), capacity)
        let fraction = period - 0.5 - Float(length)
        // A string let go, or the one nearest its end, takes the note.
        let index = strings.indices.min { a, b in
            let x = strings[a], y = strings[b]
            if x.sounding != y.sounding { return !x.sounding }
            return x.life - x.age < y.life - y.age
        } ?? 0
        var voice = Voice(start: strings[index].start)
        voice.length = length
        voice.coefficient = (1 - fraction) / (1 + fraction)
        let life = Harp.ringing(frequency)
        // What the average loses at the note itself is made up, so the
        // note rings its full length.
        let averaged = cos(.pi * frequency / sampleRate)
        voice.keep = min(exp(-6.9 / (frequency * life)) / averaged, 0.999_95)
        voice.wait = wait
        voice.life = wait + life + 0.2
        voice.sounding = true
        (voice.left, voice.right) = ears(pan)

        // The pluck: the string drawn aside and let go, a triangle round
        // the loop (its first harmonic strong, the rest falling away as a
        // plucked string's do, so every note carries its pitch, high or
        // low), begun where it crosses nothing so the note starts without a
        // click, and roughened by noise smoothed as soft fingers smooth it,
        // the more the brighter and harder the pluck.
        let string = storage + voice.start
        let bright = min(max(brightness, 0), 1), hard = min(max(strength, 0), 1)
        let corner = 600 + 5_000 * bright * (0.5 + 0.5 * hard)
        let smooth = 1 - exp(-2 * .pi * corner / sampleRate)
        let rough = 0.4 + 1.2 * bright
        var low: Float = 0
        for i in 0..<length {
            low += (noise.next() - low) * smooth
            let along = (Float(i) / Float(length) + 0.25).truncatingRemainder(dividingBy: 1)
            string[i] = (along < 0.5 ? 4 * along - 1 : 3 - 4 * along) + rough * low
        }
        // Plucked a seventh of the way along: that overtone and its kin are
        // not stirred.
        let pick = max(1, length / 7)
        for i in stride(from: length - 1, through: pick, by: -1) {
            string[i] -= string[i - pick]
        }
        // Its mean taken away, so nothing but the note is left ringing, and
        // its level set by how hard it was plucked.
        var sum: Float = 0
        for i in 0..<length { sum += string[i] }
        let mean = sum / Float(length)
        var energy: Float = 0
        for i in 0..<length {
            string[i] -= mean
            energy += string[i] * string[i]
        }
        let scale = strength * 0.25 / max((energy / Float(length)).squareRoot(), 1e-6)
        for i in 0..<length { string[i] *= scale }
        strings[index] = voice
        plucks += 1
    }

    /// The strings' next sample in each ear.
    @inline(__always)
    func sample(dt: Float) -> (left: Float, right: Float) {
        var left: Float = 0, right: Float = 0
        for index in strings.indices where strings[index].sounding {
            var voice = strings[index]
            voice.age += dt
            if voice.age > voice.life {
                strings[index].sounding = false
                continue
            }
            guard voice.age > voice.wait else {
                strings[index].age = voice.age
                continue
            }
            let string = storage + voice.start
            let out = string[voice.cursor]
            let averaged = voice.keep * 0.5 * (out + voice.last)
            voice.last = out
            let tuned = voice.coefficient * averaged + voice.taken - voice.coefficient * voice.given
            voice.taken = averaged
            voice.given = tuned
            string[voice.cursor] = tuned
            voice.cursor = voice.cursor + 1 == voice.length ? 0 : voice.cursor + 1
            // Heard over its first half-millisecond, as a finger leaves the
            // string, so no note begins with a click.
            let heard = out * min((voice.age - voice.wait) * Harp.onset, 1)
            left += heard * voice.left
            right += heard * voice.right
            strings[index] = voice
        }
        return (left, right)
    }

    /// Silent again.
    func clear() {
        for index in strings.indices { strings[index].sounding = false }
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

/// A note of a body of strings bowed: three players a few cents apart,
/// each a sawtooth (as a bowed string's wave is, the bow catching and
/// letting go) kept from aliasing by polyBLEP, each with a slow vibrato of
/// their own coming in after the bow sets, and all three through a
/// low-pass standing for the instruments' bodies. One player leans left,
/// one right, one between.
struct Bowed {
    let frequency: Float
    /// The corner of the bodies' low-pass, in hertz.
    let corner: Float
    private var first: Float, second: Float, third: Float
    private var sway1: Float, sway2: Float, sway3: Float
    private var body: Lowpass
    private var age: Float = 0

    init(frequency: Float, corner: Float, sampleRate: Float, seed: Int) {
        self.frequency = frequency
        self.corner = corner
        let s = Float(seed % 7)
        first = 0.11 * s
        second = 0.37 + 0.05 * s
        third = 0.71
        sway1 = 0.3 * s
        sway2 = 1.9
        sway3 = 4.1 + 0.2 * s
        body = Lowpass(corner: corner, resonance: 0.8, sampleRate: sampleRate)
    }

    /// Seven cents flat, and seven sharp.
    static let flat: Float = 0.995_96, sharp: Float = 1.004_05

    /// The polyBLEP: a sawtooth's step smoothed over a sample either side.
    @inline(__always)
    private static func blep(_ t: Float, _ dt: Float) -> Float {
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        }
        if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    @inline(__always)
    private static func saw(_ phase: inout Float, _ step: Float) -> Float {
        phase += step
        if phase >= 1 { phase -= 1 }
        return 2 * phase - 1 - blep(phase, step)
    }

    @inline(__always)
    private static func sway(_ phase: inout Float, _ rate: Float, _ dt: Float) -> Float {
        phase += 2 * .pi * rate * dt
        if phase > 2 * .pi { phase -= 2 * .pi }
        return sin(phase)
    }

    /// The next sample in each ear.
    @inline(__always)
    mutating func sample(dt: Float) -> (left: Float, right: Float) {
        age += dt
        // The vibrato comes in over the first second and a half, a quarter
        // of a semitone at its widest.
        let depth = 0.0025 * min(age / 1.5, 1)
        let step = frequency * dt
        let a = Bowed.saw(&first, step * Bowed.flat * (1 + depth * Bowed.sway(&sway1, 4.9, dt)))
        let b = Bowed.saw(&second, step * (1 + depth * Bowed.sway(&sway2, 5.4, dt)))
        let c = Bowed.saw(&third, step * Bowed.sharp * (1 + depth * Bowed.sway(&sway3, 5.8, dt)))
        let heard = body.process((a + b + c) * 0.33)
        // The players apart in the ears, the body of them between.
        let spread = (a - c) * 0.06
        return (heard + spread, heard - spread)
    }
}

/// A drum of skin, struck: its head's first mode falling in pitch as the
/// skin's stretch eases after the blow, its higher modes (at the ratios a
/// round membrane's are) dying sooner, and the slap of the stick, noise
/// through the band a skin sounds in.
struct Drum {
    private var phase: Float = 0
    private var age: Float = 99
    private var upper: (Resonator, Resonator, Resonator) = (Resonator(), Resonator(), Resonator())
    private var low: Float = 0
    private var high: Float = 0
    /// The blow's pitch falling back, the head dying, and the slap gone.
    private var bend: Float = 0
    private var body: Float = 0
    private var slap: Float = 0
    private var noise = Noise(seed: 0x0D2E_7A51)
    let pitch: Float
    let sampleRate: Float
    /// How much of each the drum keeps from one sample to the next, and the
    /// slap's band.
    private let bendKeep: Float, bodyKeep: Float, slapKeep: Float
    private let lowCorner: Float, highCorner: Float

    init(pitch: Float, sampleRate: Float) {
        self.pitch = pitch
        self.sampleRate = sampleRate
        bendKeep = exp(-22 / sampleRate)
        bodyKeep = exp(-4.5 / sampleRate)
        slapKeep = exp(-38 / sampleRate)
        // The stick's slap: noise between about 150 and 900 hertz.
        lowCorner = 1 - exp(-2 * .pi * 900 / sampleRate)
        highCorner = 1 - exp(-2 * .pi * 150 / sampleRate)
    }

    /// Struck this hard (0...1).
    mutating func strike(_ strength: Float) {
        age = 0
        phase = 0
        bend = 1
        body = strength
        slap = strength * 0.9
        // A round membrane's higher modes, to its first.
        upper = (Resonator(frequency: pitch * 1.59, amplitude: 0.45 * strength, decay: 9, sampleRate: sampleRate),
                 Resonator(frequency: pitch * 2.14, amplitude: 0.25 * strength, decay: 14, sampleRate: sampleRate),
                 Resonator(frequency: pitch * 2.65, amplitude: 0.12 * strength, decay: 20, sampleRate: sampleRate))
    }

    var isSounding: Bool { age < 3 }

    @inline(__always)
    mutating func sample(dt: Float) -> Float {
        guard age < 3 else { return 0 }
        age += dt
        bend *= bendKeep
        body *= bodyKeep
        slap *= slapKeep
        phase += 2 * .pi * pitch * (1 + 0.5 * bend) * dt
        if phase > 2 * .pi { phase -= 2 * .pi }
        let n = noise.next()
        low += (n - low) * lowCorner
        high += (n - high) * highCorner
        return sin(phase) * body + upper.0.next() + upper.1.next() + upper.2.next() + (low - high) * slap
    }
}
