import Foundation
import NullmereCore

/// The synthesiser behind the Mac's `Ambience`: the night's drone and
/// wind, the din of battles in sight, the towns near the view, every cue,
/// and the score, the score and the cues heard in a hall of their own. It renders on the audio
/// thread; the main thread only queues cues, under a lock.
public final class Synth: @unchecked Sendable {
    private struct Partial {
        var frequency: Float
        var amplitude: Float
        var decay: Float
        /// Seconds after the cue begins that this partial sounds.
        var delay: Float = 0
        var phase: Float = 0
    }

    private struct Note {
        var partials: [Partial]
        var noise: Float
        var noiseDecay: Float
        /// How loud in each ear: where in the world it sounds.
        var left: Float = 1
        var right: Float = 1
        var age: Float = 0
        /// Seconds after the cue begins that this note sounds.
        var delay: Float = 0
        /// Its age when it has died below hearing, worked out as it is
        /// asked for (see `length`), not on the audio thread.
        var end: Float = 40
        /// The band its noise is heard in, its material's; white if none.
        var coloured = false
        var band = Bandpass()

        mutating func colour(_ band: (centre: Float, width: Float)?, sampleRate: Float) {
            guard let band else { return }
            coloured = true
            self.band = Bandpass(centre: band.centre, width: band.width, sampleRate: sampleRate)
        }

        /// How long after it begins the note has died below hearing: each
        /// partial rings until its decay brings it under a ten-thousandth,
        /// so a long toll rings out whole rather than being cut.
        var length: Float {
            let rings = partials.map { $0.delay + log(max($0.amplitude, 1e-4) / 1e-4) / max($0.decay, 0.01) }
            let hiss = noise > 0 ? log(max(noise, 1e-4) / 1e-4) / max(noiseDecay, 0.01) : 0
            return min(max(rings.max() ?? 0, hiss), 40)
        }
    }

    private let lock = NSLock()
    private var pending: [Note] = []
    private var notes: [Note] = []

    private var sampleRate: Float = 48_000
    /// Seconds since sound began, in double precision: a Float's would stop
    /// moving after eight and a half minutes, and the night with it.
    private var time: Double = 0
    private var level: Float = 0
    private var target: Float = 0
    /// How fast the level follows its target, per second: slowly in, as
    /// night falls; quickly out, with the picture.
    private var fadeRate: Float = 0.25
    private var seed: UInt32 = 0x1234_5678
    private var windLeft: Float = 0
    private var windRight: Float = 0
    private var gust: Float = 0
    private var dronePhases: [Float] = [0, 0, 0, 0]
    private var score = Score()
    /// The hall the score and the cues ring in, and how long it has heard
    /// nothing: once its echoes are long below hearing it rests.
    private var hall = Hall(sampleRate: 48_000)
    private var hallQuiet: Float = 99
    private var pendingMusic: (on: Bool, mood: Score.Mood)?
    private var volumes: (effects: Float, ambience: Float, music: Float) = (1, 1, 1)
    /// The volumes as they sound: easing toward `volumes` over a few
    /// hundredths of a second, so a slider dragged doesn't step; at once the
    /// first time, so sound begins at the volumes it was given.
    private var heard: (effects: Float, ambience: Float, music: Float) = (1, 1, 1)
    private var heardBegun = false
    private var pendingVolumes: (effects: Float, ambience: Float, music: Float)?
    /// The din of battle as heard, easing toward what it was last told, and
    /// what makes it: a clamour of voices, the tramp of feet, and steel
    /// ringing on steel, each clash a voice of its own until it rings out.
    private var din: (level: Float, pan: Float) = (0, 0)
    private var dinTarget: (level: Float, pan: Float) = (0, 0)
    private var pendingDin: (level: Float, pan: Float)?
    private var clamourLow: Float = 0
    private var clamourHigh: Float = 0
    private var tramp: Float = 0
    private var clashes: [(phase: Float, frequency: Float, amplitude: Float, age: Float)] = Array(repeating: (0, 0, 0, 1), count: 4)
    private var nextClash: Float = 0
    /// The towns near the view as heard, easing toward what they were last
    /// told, and what they sound.
    private var town: (level: Float, pan: Float) = (0, 0)
    private var townTarget: (level: Float, pan: Float) = (0, 0)
    private var pendingTown: (level: Float, pan: Float)?
    private var pendingSawing: Float?
    private var pendingChiselling: Float?
    private var pendingBurning: Float?
    private var pendingThreshing: Float?
    private var pendingQuarrying: Float?
    private var pendingRaking: Float?
    private var pendingDrilling: Float?
    private var towns = Town(sampleRate: 48_000)

    /// The drone's partials.
    private static let droneFrequencies: [Float] = [55, 82.41, 110, 164.81]

    public init() {
        // Room enough up front that the audio thread never has to find more.
        notes.reserveCapacity(64)
        pending.reserveCapacity(24)
    }

    public func setVolumes(effects: Float, ambience: Float, music: Float) {
        let clamp = { (value: Float) in min(max(value, 0), 1) }
        lock.lock(); pendingVolumes = (clamp(effects), clamp(ambience), clamp(music)); lock.unlock()
    }

    /// What the score has played, for tests.
    var scoreSnapshot: Score {
        lock.lock(); defer { lock.unlock() }
        return score
    }

    public func setMusic(on: Bool, mood: Score.Mood) {
        lock.lock(); pendingMusic = (on, mood); lock.unlock()
    }

    public func setDin(level: Float, pan: Float) {
        lock.lock(); pendingDin = (min(max(level, 0), 1), min(max(pan, -1), 1)); lock.unlock()
    }

    /// How near the towns in the view are (0 none, 1 a busy seat close by)
    /// and where across the view, from the left (-1) to the right (1).
    public func setTown(level: Float, pan: Float) {
        lock.lock(); pendingTown = (min(max(level, 0), 1), min(max(pan, -1), 1)); lock.unlock()
    }

    /// How much of the towns heard is sawpits at work, 0 to 1.
    public func setSawing(_ share: Float) {
        lock.lock(); pendingSawing = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the towns heard is masons at work, 0 to 1.
    public func setChiselling(_ share: Float) {
        lock.lock(); pendingChiselling = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the towns heard is a beacon's fire, 0 to 1.
    public func setBurning(_ share: Float) {
        lock.lock(); pendingBurning = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the towns heard is a granary's threshing, 0 to 1.
    public func setThreshing(_ share: Float) {
        lock.lock(); pendingThreshing = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the towns heard is a quarry at work, 0 to 1.
    public func setQuarrying(_ share: Float) {
        lock.lock(); pendingQuarrying = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the towns heard is a saltworks, 0 to 1.
    public func setRaking(_ share: Float) {
        lock.lock(); pendingRaking = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the towns heard is a muster hall at drill, 0 to 1.
    public func setDrilling(_ share: Float) {
        lock.lock(); pendingDrilling = min(max(share, 0), 1); lock.unlock()
    }

    /// The towns as they are heard, for tests.
    var townHeard: (level: Float, pan: Float) {
        lock.lock(); defer { lock.unlock() }
        return town
    }

    /// The din as it is heard, for tests.
    var dinHeard: (level: Float, pan: Float) {
        lock.lock(); defer { lock.unlock() }
        return din
    }

    public func prepare(sampleRate: Float) {
        self.sampleRate = sampleRate
        if hall.sampleRate != sampleRate { hall = Hall(sampleRate: sampleRate) }
        if towns.sampleRate != sampleRate { towns = Town(sampleRate: sampleRate) }
        score.prepare(sampleRate: sampleRate)
    }

    public func fadeIn() {
        lock.lock(); target = 1; fadeRate = 0.25; lock.unlock()
    }

    public func fadeOut(rate: Float = 5) {
        lock.lock(); target = 0; fadeRate = rate; lock.unlock()
    }

    /// Silent, with nothing left sounding: called with the engine stopped.
    public func reset() {
        lock.lock()
        level = 0
        target = 0
        pending.removeAll()
        notes.removeAll()
        hall.clear()
        hallQuiet = 99
        lock.unlock()
    }

    /// Skips the fade, for measuring.
    func settle() {
        lock.lock(); target = 1; level = 1; lock.unlock()
    }

    /// Seconds since sound began, as the drone's and the wind's slow swells
    /// read them: for tests, which may also move it on.
    var clock: Double {
        lock.lock(); defer { lock.unlock() }
        return time
    }

    func advanceClock(by seconds: Double) {
        lock.lock(); time += seconds; lock.unlock()
    }

    /// How many notes are sounding, for tests.
    var sounding: Int {
        lock.lock(); defer { lock.unlock() }
        return notes.count
    }

    /// How long a cue sounds before the last of it has died below hearing,
    /// in seconds: for tests.
    func lasting(_ cue: SoundCue) -> Float {
        let made = notes(of: cue, after: 0, at: .middle)
        return made.map(\.end).max() ?? 0
    }

    public func trigger(_ cue: SoundCue, after delay: Float = 0, at place: SoundPlace = .middle) {
        let made = notes(of: cue, after: delay, at: place)
        lock.lock()
        if pending.count < 12 { pending.append(contentsOf: made) }
        lock.unlock()
    }

    /// The notes a cue sounds, each in its place and its band.
    private func notes(of cue: SoundCue, after delay: Float, at place: SoundPlace) -> [Note] {
        var note: Note
        var more: [Note] = []
        switch cue {
        case .select:
            note = Note(partials: [Partial(frequency: 1320, amplitude: 0.10, decay: 30)], noise: 0.03, noiseDecay: 90)
        case .order:
            note = Note(partials: [Partial(frequency: 660, amplitude: 0.09, decay: 14), Partial(frequency: 990, amplitude: 0.04, decay: 18)], noise: 0.02, noiseDecay: 60)
        case .watch:
            // An inharmonic bell, low and long.
            let f: Float = 98
            note = Note(partials: [
                Partial(frequency: f, amplitude: 0.175, decay: 0.45),
                Partial(frequency: f * 2.76, amplitude: 0.0875, decay: 0.8),
                Partial(frequency: f * 5.40, amplitude: 0.04, decay: 1.4),
                Partial(frequency: f * 8.93, amplitude: 0.0175, decay: 2.2),
            ], noise: 0, noiseDecay: 1)
        case .rise:
            note = Note(partials: [Partial(frequency: 392, amplitude: 0.09, decay: 2.2), Partial(frequency: 587.3, amplitude: 0.066, decay: 2.6), Partial(frequency: 784, amplitude: 0.036, decay: 3)], noise: 0, noiseDecay: 1)
        case .dread:
            // Low, and with overtones a laptop's small speakers can give, so
            // it is heard there too, its depth implied.
            note = Note(partials: [
                Partial(frequency: 46.25, amplitude: 0.14, decay: 0.7),
                Partial(frequency: 69.3, amplitude: 0.065, decay: 0.9),
                Partial(frequency: 97.99, amplitude: 0.04, decay: 1.2),
                Partial(frequency: 185, amplitude: 0.05, decay: 1.1),
                Partial(frequency: 277.2, amplitude: 0.032, decay: 1.4),
                Partial(frequency: 370, amplitude: 0.014, decay: 1.8),
            ], noise: 0.026, noiseDecay: 3)
        case .envoy:
            // A fifth, the lower note first: a horn across the water.
            note = Note(partials: [
                Partial(frequency: 220, amplitude: 0.07, decay: 1.6),
                Partial(frequency: 440, amplitude: 0.02, decay: 2.4),
                Partial(frequency: 329.6, amplitude: 0.06, decay: 1.2, delay: 0.55),
            ], noise: 0, noiseDecay: 1)
        case .triumph:
            note = Note(partials: [
                Partial(frequency: 293.7, amplitude: 0.07, decay: 1.4),
                Partial(frequency: 370, amplitude: 0.06, decay: 1.6, delay: 0.14),
                Partial(frequency: 440, amplitude: 0.06, decay: 1.8, delay: 0.28),
                Partial(frequency: 587.3, amplitude: 0.03, decay: 2.2, delay: 0.42),
            ], noise: 0, noiseDecay: 1)
        case .accord:
            note = Note(partials: [
                Partial(frequency: 523.3, amplitude: 0.06, decay: 1.5),
                Partial(frequency: 880, amplitude: 0.04, decay: 1.8, delay: 0.2),
                Partial(frequency: 1046.5, amplitude: 0.012, decay: 2.5),
            ], noise: 0, noiseDecay: 1)
        case .toll:
            // An inharmonic bell, very low and very long.
            let f: Float = 55
            note = Note(partials: [
                Partial(frequency: f, amplitude: 0.17, decay: 0.25),
                Partial(frequency: f * 2.76, amplitude: 0.08, decay: 0.45),
                Partial(frequency: f * 5.40, amplitude: 0.035, decay: 0.8),
                Partial(frequency: f * 8.93, amplitude: 0.015, decay: 1.3),
            ], noise: 0.01, noiseDecay: 6)
        case .clash:
            // Bright, inharmonic and short over a dull thud.
            note = Note(partials: [
                Partial(frequency: 80, amplitude: 0.07, decay: 10),
                Partial(frequency: 523, amplitude: 0.045, decay: 9),
                Partial(frequency: 1247, amplitude: 0.032, decay: 12),
                Partial(frequency: 1873, amplitude: 0.024, decay: 16),
                Partial(frequency: 2690, amplitude: 0.016, decay: 20),
            ], noise: 0.07, noiseDecay: 35)
        case .loose:
            // The string's low twang and its click, then the shaft's hiss.
            note = Note(partials: [
                Partial(frequency: 196, amplitude: 0.09, decay: 10),
                Partial(frequency: 392, amplitude: 0.035, decay: 14),
            ], noise: 0.07, noiseDecay: 80)
            more = [Note(partials: [], noise: 0.03, noiseDecay: 7, delay: 0.05)]
        case .ride:
            // Three hooves on hard ground, close together.
            func hoof(_ delay: Float, _ strength: Float) -> Note {
                Note(partials: [
                    Partial(frequency: 110, amplitude: 0.09 * strength, decay: 25),
                    Partial(frequency: 70, amplitude: 0.06 * strength, decay: 20),
                    // The knock of it, which small speakers give.
                    Partial(frequency: 240, amplitude: 0.04 * strength, decay: 32),
                ], noise: 0.06 * strength, noiseDecay: 50, delay: delay)
            }
            note = hoof(0, 1)
            more = [hoof(0.12, 0.8), hoof(0.21, 0.9)]
        case .dig:
            // The blade's dull bite, the grit it throws, a ring off a stone.
            func spade(_ delay: Float, _ strength: Float) -> Note {
                Note(partials: [
                    Partial(frequency: 82, amplitude: 0.08 * strength, decay: 22),
                    Partial(frequency: 164, amplitude: 0.04 * strength, decay: 26),
                    Partial(frequency: 1530, amplitude: 0.018 * strength, decay: 30),
                ], noise: 0.07 * strength, noiseDecay: 16, delay: delay)
            }
            note = spade(0, 1)
            more = [spade(0.34, 0.85)]
        case .coin:
            // Small bright metal, inharmonic, each coin a little higher.
            func clink(_ delay: Float, _ pitch: Float, _ strength: Float) -> Note {
                Note(partials: [
                    Partial(frequency: 2_350 * pitch, amplitude: 0.06 * strength, decay: 16),
                    Partial(frequency: 3_890 * pitch, amplitude: 0.04 * strength, decay: 22),
                    Partial(frequency: 5_630 * pitch, amplitude: 0.022 * strength, decay: 30),
                ], noise: 0.025 * strength, noiseDecay: 140, delay: delay)
            }
            note = clink(0, 1, 1)
            more = [clink(0.09, 1.07, 0.8), clink(0.17, 0.96, 0.9)]
        case .parley:
            // A fourth rising, with a reed's odd overtones: a question carried off.
            note = Note(partials: [
                Partial(frequency: 293.7, amplitude: 0.07, decay: 2.4),
                Partial(frequency: 881.1, amplitude: 0.022, decay: 3.2),
                Partial(frequency: 1468.5, amplitude: 0.01, decay: 4),
                Partial(frequency: 392, amplitude: 0.065, decay: 1.8, delay: 0.3),
                Partial(frequency: 1176, amplitude: 0.02, decay: 2.6, delay: 0.3),
            ], noise: 0.008, noiseDecay: 9)
        case .stand:
            // Two strokes on a skin drum, the second softer: stand down.
            func stroke(_ delay: Float, _ strength: Float) -> Note {
                Note(partials: [
                    Partial(frequency: 130.8, amplitude: 0.09 * strength, decay: 9),
                    Partial(frequency: 207.7, amplitude: 0.045 * strength, decay: 12),
                    Partial(frequency: 311, amplitude: 0.02 * strength, decay: 16),
                ], noise: 0.04 * strength, noiseDecay: 45, delay: delay)
            }
            note = stroke(0, 1)
            more = [stroke(0.26, 0.6)]
        case .complete:
            // Two knocks of the mallet, then a major chord rung bright.
            func knock(_ delay: Float) -> Note {
                Note(partials: [
                    Partial(frequency: 180, amplitude: 0.07, decay: 30),
                    Partial(frequency: 720, amplitude: 0.03, decay: 38),
                ], noise: 0.05, noiseDecay: 60, delay: delay)
            }
            note = knock(0)
            more = [knock(0.15), Note(partials: [
                Partial(frequency: 392, amplitude: 0.05, decay: 1.6),
                Partial(frequency: 493.9, amplitude: 0.04, decay: 1.8),
                Partial(frequency: 587.3, amplitude: 0.04, decay: 2),
                Partial(frequency: 784, amplitude: 0.015, decay: 2.6),
            ], noise: 0, noiseDecay: 1, delay: 0.32)]
        case .muster:
            // A horn's call up a fifth, its overtones rich and falling away.
            func horn(_ frequency: Float, _ delay: Float, _ length: Float) -> [Partial] {
                [1, 2, 3, 4].map { (harmonic: Float) in
                    Partial(frequency: frequency * harmonic, amplitude: 0.06 / (harmonic * harmonic * 0.6 + 0.4),
                            decay: length * (0.8 + harmonic * 0.4), delay: delay)
                }
            }
            note = Note(partials: horn(196, 0, 2.4) + horn(293.7, 0.32, 1.6), noise: 0.006, noiseDecay: 6)
        case .leaf:
            // A page turned: paper's brush, and the faintest high note.
            note = Note(partials: [Partial(frequency: 2_637, amplitude: 0.03, decay: 24)], noise: 0.055, noiseDecay: 36)
        case .fold:
            // The page laid down: lower, softer, and quicker gone.
            note = Note(partials: [Partial(frequency: 1_760, amplitude: 0.026, decay: 30)], noise: 0.045, noiseDecay: 44)
        case .deny:
            // Two knocks on muffled wood, the second a step lower: not so.
            note = Note(partials: [Partial(frequency: 196, amplitude: 0.07, decay: 24), Partial(frequency: 588, amplitude: 0.026, decay: 34)],
                        noise: 0.02, noiseDecay: 70)
            more = [Note(partials: [Partial(frequency: 165, amplitude: 0.06, decay: 24), Partial(frequency: 495, amplitude: 0.022, decay: 34)],
                         noise: 0.016, noiseDecay: 70, delay: 0.11)]
        case .refusal:
            // A minor third falling, soft and reedy: not this time.
            note = Note(partials: [
                Partial(frequency: 329.6, amplitude: 0.07, decay: 3.2),
                Partial(frequency: 988.8, amplitude: 0.018, decay: 4.4),
                Partial(frequency: 277.2, amplitude: 0.07, decay: 2, delay: 0.28),
                Partial(frequency: 831.6, amplitude: 0.018, decay: 3, delay: 0.28),
            ], noise: 0, noiseDecay: 1)
        case .batter:
            // A ram on the gate: the deep thud, the timber's crack, the dust.
            note = Note(partials: [
                Partial(frequency: 58, amplitude: 0.13, decay: 8),
                Partial(frequency: 92, amplitude: 0.07, decay: 10),
                Partial(frequency: 174, amplitude: 0.05, decay: 13),
                Partial(frequency: 1_130, amplitude: 0.025, decay: 34),
            ], noise: 0.09, noiseDecay: 22)
            more = [Note(partials: [], noise: 0.025, noiseDecay: 4, delay: 0.06)]
        case .lore:
            // Three glass bells, each a fifth or so above the last, ringing on.
            func bell(_ f: Float, _ delay: Float) -> [Partial] {
                [Partial(frequency: f, amplitude: 0.05, decay: 1.4, delay: delay),
                 Partial(frequency: f * 2.76, amplitude: 0.02, decay: 2.4, delay: delay),
                 Partial(frequency: f * 5.4, amplitude: 0.008, decay: 3.4, delay: delay)]
            }
            note = Note(partials: bell(659.3, 0) + bell(987.8, 0.13) + bell(1318.5, 0.26), noise: 0, noiseDecay: 1)
        case .horn:
            // A war horn's two notes, the second a fourth above, rich and rough.
            func blast(_ f: Float, _ delay: Float, _ length: Float) -> [Partial] {
                (1...6).map { (h: Int) in
                    let n = Float(h)
                    return Partial(frequency: f * n * (1 + 0.003 * n), amplitude: 0.075 / (n * 0.9 + 0.3),
                                   decay: (1.6 + 0.5 * n) / length, delay: delay)
                }
            }
            note = Note(partials: blast(110, 0, 1.3) + blast(146.8, 0.42, 1.1), noise: 0.012, noiseDecay: 5)
        case .banner:
            // Two chords, the second the first's fourth: a banner raised.
            func chord(_ root: Float, _ delay: Float) -> [Partial] {
                [Partial(frequency: root, amplitude: 0.05, decay: 1.5, delay: delay),
                 Partial(frequency: root * 1.26, amplitude: 0.04, decay: 1.7, delay: delay),
                 Partial(frequency: root * 1.5, amplitude: 0.04, decay: 1.9, delay: delay)]
            }
            note = Note(partials: chord(293.7, 0) + chord(392, 0.36), noise: 0, noiseDecay: 1)
        case .herald:
            // Three drum strokes, then a bell over the realm.
            func drum(_ delay: Float) -> Note {
                Note(partials: [Partial(frequency: 98, amplitude: 0.09, decay: 12), Partial(frequency: 156, amplitude: 0.04, decay: 15)],
                     noise: 0.05, noiseDecay: 40, delay: delay)
            }
            note = drum(0)
            more = [drum(0.14), drum(0.28), Note(partials: [
                Partial(frequency: 784, amplitude: 0.05, decay: 1.2),
                Partial(frequency: 784 * 2.76, amplitude: 0.018, decay: 2),
            ], noise: 0, noiseDecay: 1, delay: 0.46)]
        case .tend:
            // A warm hum a fifth deep, and over it a small bell struck
            // twice, the second softer: the healers at their work.
            note = Note(partials: [
                Partial(frequency: 174.6, amplitude: 0.04, decay: 1.4),
                Partial(frequency: 261.6, amplitude: 0.028, decay: 1.6),
                Partial(frequency: 349.2, amplitude: 0.01, decay: 1.9),
                Partial(frequency: 1046.5, amplitude: 0.04, decay: 2.6, delay: 0.05),
                Partial(frequency: 1046.5 * 2.76, amplitude: 0.01, decay: 4, delay: 0.05),
                Partial(frequency: 1174.7, amplitude: 0.026, decay: 2.8, delay: 0.32),
                Partial(frequency: 1174.7 * 2.76, amplitude: 0.007, decay: 4.2, delay: 0.32),
            ], noise: 0.004, noiseDecay: 8)
        case .sift:
            // A fine patter of salt grains through the glass's waist, swelling
            // and thinning, then a small glass chime as the last of it falls.
            func grains(_ delay: Float, _ strength: Float) -> Note {
                Note(partials: [
                    Partial(frequency: 4_700, amplitude: 0.012 * strength, decay: 60),
                    Partial(frequency: 6_300, amplitude: 0.008 * strength, decay: 70),
                ], noise: 0.03 * strength, noiseDecay: 55, delay: delay)
            }
            note = grains(0, 0.7)
            more = [grains(0.05, 0.9), grains(0.11, 1), grains(0.16, 0.85), grains(0.22, 0.7), grains(0.27, 0.5),
                    Note(partials: [
                        Partial(frequency: 1_568, amplitude: 0.05, decay: 1.6),
                        Partial(frequency: 1_568 * 2.76, amplitude: 0.016, decay: 2.6),
                        Partial(frequency: 2_093, amplitude: 0.02, decay: 2, delay: 0.08),
                    ], noise: 0, noiseDecay: 1, delay: 0.36)]
        case .anvil:
            // Three blows of the hammer, bright and out of tune with each
            // other as struck iron is, a dull knock under each; the last
            // left to ring.
            func blow(_ delay: Float, _ strength: Float, _ ring: Float) -> Note {
                Note(partials: [
                    Partial(frequency: 1_245, amplitude: 0.05 * strength, decay: ring),
                    Partial(frequency: 1_245 * 2.31, amplitude: 0.028 * strength, decay: ring * 1.4),
                    Partial(frequency: 1_245 * 3.87, amplitude: 0.014 * strength, decay: ring * 2),
                    Partial(frequency: 412, amplitude: 0.02 * strength, decay: 16),
                ], noise: 0.04 * strength, noiseDecay: 70, delay: delay)
            }
            note = blow(0, 0.8, 9)
            more = [blow(0.2, 0.9, 9), blow(0.4, 1, 2.5)]
        case .honour:
            // A quick fanfare up a major arpeggio to the octave.
            note = Note(partials: [
                Partial(frequency: 523.3, amplitude: 0.055, decay: 2.2),
                Partial(frequency: 659.3, amplitude: 0.05, decay: 2.2, delay: 0.09),
                Partial(frequency: 784, amplitude: 0.05, decay: 2.2, delay: 0.18),
                Partial(frequency: 1046.5, amplitude: 0.045, decay: 1.8, delay: 0.27),
                Partial(frequency: 2093, amplitude: 0.01, decay: 2.6, delay: 0.27),
            ], noise: 0, noiseDecay: 1)
        }
        note.delay += delay
        note.end = note.delay + note.length
        (note.left, note.right) = (place.left, place.right)
        let bands = Synth.bands(of: cue)
        note.colour(bands.first, sampleRate: sampleRate)
        for index in more.indices {
            more[index].delay += delay
            more[index].end = more[index].delay + more[index].length
            (more[index].left, more[index].right) = (place.left, place.right)
            more[index].colour(bands.rest ?? bands.first, sampleRate: sampleRate)
        }
        return [note] + more
    }

    private func random() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed >> 8) / Float(1 << 24) * 2 - 1
    }

    /// Renders the next `frames` samples of each ear into `left` and
    /// `right`: on the audio thread, finding no memory.
    public func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        lock.lock()
        notes.append(contentsOf: pending)
        pending.removeAll(keepingCapacity: true)
        let goal = target
        let rate = fadeRate
        if let music = pendingMusic {
            score.target = music.on ? 1 : 0
            score.mood = music.mood
            pendingMusic = nil
        }
        if let next = pendingVolumes {
            volumes = next
            pendingVolumes = nil
        }
        if let next = pendingDin {
            dinTarget = next
            pendingDin = nil
        }
        if let next = pendingTown {
            townTarget = next
            pendingTown = nil
        }
        if let next = pendingSawing {
            towns.sawing = next
            pendingSawing = nil
        }
        if let next = pendingChiselling {
            towns.chiselling = next
            pendingChiselling = nil
        }
        if let next = pendingBurning {
            towns.burning = next
            pendingBurning = nil
        }
        if let next = pendingThreshing {
            towns.threshing = next
            pendingThreshing = nil
        }
        if let next = pendingQuarrying {
            towns.quarrying = next
            pendingQuarrying = nil
        }
        if let next = pendingRaking {
            towns.raking = next
            pendingRaking = nil
        }
        if let next = pendingDrilling {
            towns.drilling = next
            pendingDrilling = nil
        }
        let volume = volumes
        lock.unlock()
        if !heardBegun {
            heard = volume
            heardBegun = true
        }

        let dt = 1 / sampleRate
        let tau: Float = 2 * .pi
        // The wind's noise, as loud at any sample rate: the filter below
        // passes the same band, so its noise is scaled to the rate.
        let windNoise = (sampleRate / 48_000).squareRoot()
        // The din's filters, their corners set in hertz: the clamour's band
        // of voices, and the low tramp of feet.
        let voicesLow = 1 - exp(-tau * 320 * dt), voicesHigh = 1 - exp(-tau * 1_600 * dt), feet = 1 - exp(-tau * 90 * dt)
        for frame in 0..<frames {
            time += Double(dt)
            level += (goal - level) * dt * rate
            heard.effects += (volume.effects - heard.effects) * min(dt * 30, 1)
            heard.ambience += (volume.ambience - heard.ambience) * min(dt * 30, 1)
            heard.music += (volume.music - heard.music) * min(dt * 30, 1)

            // The drone: a few cold partials, each swelling at its own pace.
            var drone: Float = 0
            for i in 0..<4 {
                dronePhases[i] += tau * Self.droneFrequencies[i] * dt
                if dronePhases[i] > tau { dronePhases[i] -= tau }
                let swell = 0.5 + 0.5 * Float(sin(time * (0.031 + Double(i) * 0.017) + Double(i) * 1.7))
                drone += sin(dronePhases[i]) * swell * (i == 0 ? 0.016 : 0.009)
            }

            // The wind: soft noise, gusting slowly, a little different in each
            // ear, through a filter whose corner is set in hertz (30 to 120,
            // as the gust rises), so it sounds the same at any sample rate.
            gust += (0.5 + 0.5 * Float(sin(time * 0.07) * sin(time * 0.023 + 1)) - gust) * dt * 0.5
            let corner = 30.6 + 91.7 * gust
            let cutoff = 1 - exp(-tau * corner * dt)
            windLeft += (random() * windNoise - windLeft) * cutoff
            windRight += (random() * windNoise - windRight) * cutoff
            let wind = 0.55 + 0.45 * gust

            var cueLeft: Float = 0
            var cueRight: Float = 0
            for n in notes.indices {
                var cue: Float = 0
                notes[n].age += dt
                let age = notes[n].age - notes[n].delay
                guard age > 0 else { continue }
                for p in notes[n].partials.indices {
                    notes[n].partials[p].phase += tau * notes[n].partials[p].frequency * dt
                    if notes[n].partials[p].phase > tau { notes[n].partials[p].phase -= tau }
                    let partial = notes[n].partials[p]
                    let sounding = age - partial.delay
                    guard sounding > 0 else { continue }
                    let attack = min(sounding * 400, 1)
                    cue += sin(partial.phase) * partial.amplitude * attack * exp(-sounding * partial.decay)
                }
                if notes[n].noise > 0 {
                    var hiss = random()
                    if notes[n].coloured { hiss = notes[n].band.process(hiss) }
                    cue += hiss * notes[n].noise * exp(-age * notes[n].noiseDecay)
                }
                cueLeft += cue * notes[n].left
                cueRight += cue * notes[n].right
            }

            // The din of battle: as loud as the fighting, from where it is.
            din.level += (dinTarget.level - din.level) * min(dt * 2, 1)
            din.pan += (dinTarget.pan - din.pan) * min(dt * 2, 1)
            var battle: Float = 0
            if din.level > 0.0005 {
                let noise = random()
                clamourLow += (noise - clamourLow) * voicesLow
                clamourHigh += (noise - clamourHigh) * voicesHigh
                let clamour = (clamourHigh - clamourLow) * (0.7 + 0.3 * Float(sin(time * 1.3)))
                tramp += (random() * windNoise - tramp) * feet
                let step = max(0, Float(sin(time * 2 * .pi * 2.1)))
                nextClash -= dt
                if nextClash <= 0 {
                    let slot = clashes.indices.max { clashes[$0].age < clashes[$1].age } ?? 0
                    clashes[slot] = (0, 1_800 + 1_400 * abs(random()), 0.5 + 0.5 * abs(random()), 0)
                    nextClash = (0.05 + 0.25 * abs(random())) / max(din.level, 0.2)
                }
                var ring: Float = 0
                for c in clashes.indices where clashes[c].age < 0.4 {
                    clashes[c].age += dt
                    clashes[c].phase += tau * clashes[c].frequency * dt
                    if clashes[c].phase > tau { clashes[c].phase -= tau }
                    let phase = clashes[c].phase
                    ring += (sin(phase) + 0.6 * sin(phase * 2.76)) * clashes[c].amplitude * exp(-clashes[c].age * 28)
                }
                battle = (clamour * 0.9 + tramp * step * 6 + ring * 0.05) * 0.2 * din.level
            }
            let dinAngle = (din.pan + 1) * .pi / 4
            let dinLeft = battle * cos(dinAngle) * 1.414 * heard.ambience * level
            let dinRight = battle * sin(dinAngle) * 1.414 * heard.ambience * level

            // The towns near the view: as near as the view comes, from where
            // they lie across it, out of doors as the din is.
            town.level += (townTarget.level - town.level) * min(dt * 1.5, 1)
            town.pan += (townTarget.pan - town.pan) * min(dt * 1.5, 1)
            var townLeft: Float = 0, townRight: Float = 0
            if town.level > 0.0005 {
                let heardTown = towns.sample(dt: dt) * Self.townGain * town.level * heard.ambience * level
                let townAngle = (0.75 * town.pan + 1) * .pi / 4
                townLeft = heardTown * cos(townAngle) * 1.414
                townRight = heardTown * sin(townAngle) * 1.414
            }

            cueLeft *= heard.effects
            cueRight *= heard.effects
            drone *= heard.ambience
            let air = 0.6 * wind * level * heard.ambience
            let played = score.sample(dt: dt)
            let musicLeft = played.left * level * heard.music, musicRight = played.right * level * heard.music
            // The cues sound whole while night falls, but go with the rest
            // as the sound fades out, so nothing rings on to be cut off.
            let cueLevel = goal > 0 ? 1 : level
            let heardLeft = 0.5 * cueLeft * cueLevel, heardRight = 0.5 * cueRight * cueLevel
            // The hall: the score sent to it well, the cues a little, the
            // night's drone and wind not at all, being out of doors.
            let sentLeft = musicLeft * Self.musicSend + heardLeft * Self.cueSend
            let sentRight = musicRight * Self.musicSend + heardRight * Self.cueSend
            var hallLeft: Float = 0, hallRight: Float = 0
            if sentLeft != 0 || sentRight != 0 { hallQuiet = 0 } else { hallQuiet += dt }
            if hallQuiet < hall.seconds * 3 {
                (hallLeft, hallRight) = hall.process(left: sentLeft, right: sentRight)
            }
            left[frame] = Self.softened(drone * level + musicLeft + hallLeft + heardLeft + windLeft * air + dinLeft + townLeft)
            right[frame] = Self.softened(drone * level + musicRight + hallRight + heardRight + windRight * air + dinRight + townRight)
        }
        notes.removeAll { $0.age > $0.end }
    }

    /// The band each cue's noise is heard in, its first sound's and the
    /// rest's, as centre (hertz) and width (the centre over the band's
    /// breadth): a page high and soft, grit and dust about the middle,
    /// hooves, skins and earth low, steel ringing bright and salt hissing
    /// brighter. A cue with no noise, or none named, is as it was.
    static func bands(of cue: SoundCue) -> (first: (centre: Float, width: Float)?, rest: (centre: Float, width: Float)?) {
        switch cue {
        case .select: return ((3_200, 0.9), nil)
        case .order: return ((2_200, 0.8), nil)
        case .dread: return ((220, 0.7), nil)
        case .toll: return ((500, 0.8), nil)
        case .clash: return ((3_400, 1.4), nil)
        // The string's click, then the shaft's hiss through the air.
        case .loose: return ((2_600, 1), (6_000, 1.6))
        case .ride: return ((380, 0.8), nil)
        case .dig: return ((1_400, 0.7), nil)
        case .coin: return ((6_800, 1.2), nil)
        case .parley: return ((1_100, 0.6), nil)
        case .stand: return ((420, 0.8), nil)
        case .complete: return ((1_100, 0.9), nil)
        case .muster: return ((800, 0.6), nil)
        // The timber's crack, then the dust settling.
        case .batter: return ((650, 0.8), (300, 0.6))
        case .horn: return ((600, 0.7), nil)
        case .herald: return ((450, 0.8), nil)
        case .tend: return ((1_000, 0.6), nil)
        case .sift: return ((6_400, 1.3), nil)
        case .anvil: return ((3_800, 1.2), nil)
        case .leaf: return ((4_800, 0.7), nil)
        case .fold: return ((3_000, 0.7), nil)
        case .deny: return ((850, 0.9), nil)
        case .watch, .rise, .envoy, .triumph, .accord, .refusal, .lore, .banner, .honour: return (nil, nil)
        }
    }

    /// How loud a town is, close by: about as loud as the night beneath it.
    static let townGain: Float = 0.15

    /// How much of the score, and of the cues, the hall is given.
    static let musicSend: Float = 0.45
    static let cueSend: Float = 0.14

    /// The sum kept under full scale: untouched while quiet, rounded off
    /// gently above three quarters, never clipped hard however many cues
    /// sound at once.
    static func softened(_ sample: Float) -> Float {
        let knee: Float = 0.75
        let size = abs(sample)
        guard size > knee else { return sample }
        let over = (size - knee) / (1 - knee)
        return (knee + (1 - knee) * tanh(over)) * (sample < 0 ? -1 : 1)
    }
}
