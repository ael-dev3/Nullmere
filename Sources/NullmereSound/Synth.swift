import Foundation
import NullmereCore

/// The synthesiser behind the Mac's `Ambience`: the night's drone and
/// wind, the din of battles in sight, the towns and the lake's edge near
/// the view, every cue,
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

    /// A note a cue blows on the recorded horn, waiting to be blown on the
    /// audio thread: its frequency, when it sounds after the cue begins,
    /// how long it is held, how hard, and how loud in each ear.
    private struct Blown {
        var frequency: Float
        var wait: Float
        var hold: Float
        var strength: Float
        var left: Float
        var right: Float
    }
    private var pendingBlown: [Blown] = []

    /// A blow a cue strikes on a recorded instrument, waiting to be struck
    /// on the audio thread: the note recorded, when it sounds after the cue
    /// begins, how hard, how much faster than it was recorded it is read,
    /// and how loud in each ear.
    private struct Strike {
        unowned(unsafe) let note: Recording
        var wait: Float
        var strength: Float
        var ratio: Double
        var left: Float
        var right: Float
    }
    private var pendingStrikes: [Strike] = []
    /// The cues' recorded blows ringing: the anvil's, the field drum's and
    /// the slit drum's.
    private var struck = [Reading](repeating: Reading(note: Recordings.anvilNotes[0]), count: 12)
    /// How many blows the cues have struck on recorded instruments, for tests.
    private(set) var cueStrikes = 0
    /// The horn the cues' calls are blown on: the war horn, the muster's,
    /// the envoy's, a hold taken and a deed honoured, enough voices for two
    /// fanfares at once.
    private var cueHorns = Horns(sampleRate: 48_000, voices: 8)
    /// How many notes the cues have blown on the horn, for tests.
    var cueHornsBlown: Int { cueHorns.blown }

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
    /// How great a host the din is of, from a skirmish (0) to a battle of
    /// hundreds of thousands (1): the deep roar of the throng, clash on
    /// clash, and war horns calling across it.
    private var host: Float = 0
    private var hostTarget: Float = 0
    private var pendingHost: Float?
    private var roarLow: Float = 0, roarHigh: Float = 0
    private var nextHorn: Float = 2
    /// The war horns calling across a great host's battle: the horn the
    /// score's calls are blown on, recorded.
    private var dinHorns = Horns(sampleRate: 48_000)
    /// How many war horns have called across battles, for tests.
    var warHornsBlown: Int { dinHorns.blown }
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
    private var pendingGrinding: Float?
    private var pendingReading: Float?
    private var pendingForging: Float?
    private var pendingPosting: Float?
    private var towns = Town(sampleRate: 48_000)
    /// The lake at its edge near the view as heard, easing toward what it
    /// was last told, and what it sounds.
    private var shore: (level: Float, pan: Float) = (0, 0)
    private var shoreTarget: (level: Float, pan: Float) = (0, 0)
    private var pendingShore: (level: Float, pan: Float)?
    private var shores = Shore(sampleRate: 48_000)

    /// The drone's partials.
    private static let droneFrequencies: [Float] = [55, 82.41, 110, 164.81]

    public init() {
        // Room enough up front that the audio thread never has to find more.
        notes.reserveCapacity(64)
        pending.reserveCapacity(24)
        pendingBlown.reserveCapacity(24)
        pendingStrikes.reserveCapacity(24)
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

    /// How great the host in the din is, 0 to 1.
    public func setHost(_ mass: Float) {
        lock.lock(); pendingHost = min(max(mass, 0), 1); lock.unlock()
    }

    /// The host as it is heard, for tests.
    var hostHeard: Float {
        lock.lock(); defer { lock.unlock() }
        return host
    }

    public func setDin(level: Float, pan: Float) {
        lock.lock(); pendingDin = (min(max(level, 0), 1), min(max(pan, -1), 1)); lock.unlock()
    }

    /// How near the towns in the view are (0 none, 1 a busy seat close by)
    /// and where across the view, from the left (-1) to the right (1).
    public func setTown(level: Float, pan: Float) {
        lock.lock(); pendingTown = (min(max(level, 0), 1), min(max(pan, -1), 1)); lock.unlock()
    }

    /// How near the lake's edge is to the view (0 none, 1 the strand all
    /// about its middle, close) and where across it, from the left (-1) to
    /// the right (1).
    public func setShore(level: Float, pan: Float) {
        lock.lock(); pendingShore = (min(max(level, 0), 1), min(max(pan, -1), 1)); lock.unlock()
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

    /// How much of the towns heard is an infirmary at work, 0 to 1.
    public func setGrinding(_ share: Float) {
        lock.lock(); pendingGrinding = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the towns heard is an archive, 0 to 1.
    public func setReading(_ share: Float) {
        lock.lock(); pendingReading = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the town heard is a forge at work, 0 to 1.
    public func setForging(_ share: Float) {
        lock.lock(); pendingForging = min(max(share, 0), 1); lock.unlock()
    }

    /// How much of the town heard is a wayhouse at work, 0 to 1.
    public func setPosting(_ share: Float) {
        lock.lock(); pendingPosting = min(max(share, 0), 1); lock.unlock()
    }

    /// The towns as they are heard, for tests.
    var townHeard: (level: Float, pan: Float) {
        lock.lock(); defer { lock.unlock() }
        return town
    }

    /// The shore as it is heard, for tests.
    var shoreHeard: (level: Float, pan: Float) {
        lock.lock(); defer { lock.unlock() }
        return shore
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
        if shores.sampleRate != sampleRate { shores = Shore(sampleRate: sampleRate) }
        if dinHorns.sampleRate != sampleRate { dinHorns = Horns(sampleRate: sampleRate) }
        if cueHorns.sampleRate != sampleRate { cueHorns = Horns(sampleRate: sampleRate, voices: 8) }
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
        pendingBlown.removeAll()
        pendingStrikes.removeAll()
        for index in struck.indices { struck[index].sounding = false }
        cueHorns.clear()
        dinHorns.clear()
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
        let calling = Synth.callLevel(of: cue)
        let blown = Synth.call(of: cue).map {
            Blown(frequency: $0.frequency, wait: delay + $0.at, hold: $0.hold, strength: $0.strength,
                  left: place.left * calling, right: place.right * calling)
        }
        let loud = Synth.strikeLevel(of: cue)
        let strikes = Synth.strikes(of: cue).map {
            Strike(note: $0.note, wait: delay + $0.at, strength: $0.strength * loud, ratio: $0.ratio, left: place.left, right: place.right)
        }
        lock.lock()
        if pending.count < 12 { pending.append(contentsOf: made) }
        if pendingBlown.count + blown.count <= 24 { pendingBlown.append(contentsOf: blown) }
        if pendingStrikes.count + strikes.count <= 24 { pendingStrikes.append(contentsOf: strikes) }
        lock.unlock()
    }

    /// The blows a cue strikes on recorded instruments, if it is struck:
    /// each blow's note, when it falls, how hard, and how much faster than
    /// it was recorded it is read. The forge's three blows on the anvil,
    /// the last the hardest, left to ring; the field drum's two strokes,
    /// the second softer, as a company stands down; and two knocks on the
    /// slit drum, the second a third lower, as the rules refuse an order.
    static func strikes(of cue: SoundCue) -> [(note: Recording, at: Float, strength: Float, ratio: Double)] {
        switch cue {
        case .anvil:
            let anvil = Recordings.anvilNotes
            return [(anvil[0], 0, 0.8, 1), (anvil[0], 0.2, 0.9, 0.97), (anvil[1], 0.4, 1, 1)]
        case .stand:
            let drums = Recordings.drumNotes
            return [(drums[2], 0, 1, 1), (drums[3], 0.26, 0.6, 1)]
        case .deny:
            let slit = Recordings.slitDrumNotes
            return [(slit[0], 0, 1, 1), (slit[1], 0.11, 0.85, 0.84)]
        case .lore:
            // Three glass bells, each a fifth or so above the last.
            return [bell(659.3, 0, 0.9), bell(987.8, 0.13, 0.9), bell(1318.5, 0.26, 1)]
        case .herald:
            // The great drum three times, then a bell over the realm.
            let drums = Recordings.drumNotes
            return [(drums[1], 0, 0.8, 1), (drums[1], 0.14, 0.8, 1.03), (drums[0], 0.28, 1, 1), bell(784, 0.46, 1)]
        case .complete:
            // Two knocks of the mallet, then a major chord on the harp.
            let slit = Recordings.slitDrumNotes
            return [(slit[0], 0, 0.9, 1.12), (slit[1], 0.15, 0.9, 1.12)] + [392, 493.9, 587.3, 784].map { pluck($0, 0.32, 0.8) }
        case .rise:
            // A chord rising on the harp: G, its fifth, its octave.
            return [pluck(392, 0, 0.9), pluck(587.3, 0.04, 0.85), pluck(784, 0.08, 0.8)]
        case .accord:
            // A gentle sixth on the harp.
            return [pluck(523.3, 0, 0.85), pluck(880, 0.2, 0.75)]
        default: return []
        }
    }

    /// A string of the recorded harp, or a bar of the recorded
    /// glockenspiel, read to sound a frequency: the note recorded nearest
    /// it, when it is struck, how hard, and how much faster it is read.
    private static func pluck(_ frequency: Float, _ at: Float, _ strength: Float) -> (note: Recording, at: Float, strength: Float, ratio: Double) {
        let nearest = Recordings.nearest(Recordings.harpNotes, to: frequency)
        return (Recordings.harpNotes[nearest.index], at, strength, nearest.ratio)
    }

    private static func bell(_ frequency: Float, _ at: Float, _ strength: Float) -> (note: Recording, at: Float, strength: Float, ratio: Double) {
        let nearest = Recordings.nearest(Recordings.glockenspielNotes, to: frequency)
        return (Recordings.glockenspielNotes[nearest.index], at, strength, nearest.ratio)
    }

    /// The call a cue blows on the recorded horn, if it is a horn's: each
    /// note's frequency, when it is blown, how long it is held and how hard.
    /// The war horn (a rally called, setting out, a commander's skill) on A
    /// and then the D a fourth above; the muster's call up a fifth, G to D;
    /// an envoy at the gate, a fifth across the water, soft; a hold taken,
    /// a triad rising to its octave, D major; a deed honoured, a quick
    /// fanfare up C major to the octave; a banner raised, two stately
    /// chords, D major and then G, its fourth.
    static func call(of cue: SoundCue) -> [(frequency: Float, at: Float, hold: Float, strength: Float)] {
        switch cue {
        case .horn: return [(110, 0, 0.45, 0.9), (146.8, 0.42, 0.75, 1)]
        case .muster: return [(196, 0, 0.3, 1), (293.7, 0.32, 0.9, 1)]
        case .envoy: return [(110, 0, 0.5, 0.75), (164.8, 0.55, 0.6, 0.8)]
        case .triumph: return [(146.8, 0, 0.25, 0.9), (185, 0.14, 0.25, 0.9), (220, 0.28, 0.25, 0.95), (293.7, 0.42, 0.9, 1)]
        case .honour: return [(130.8, 0, 0.12, 0.9), (164.8, 0.09, 0.12, 0.9), (196, 0.18, 0.12, 0.95), (261.6, 0.27, 0.8, 1)]
        case .banner:
            return [(146.8, 0, 0.3, 0.85), (185, 0, 0.3, 0.75), (220, 0, 0.3, 0.75),
                    (196, 0.36, 0.9, 0.9), (246.9, 0.36, 0.9, 0.8), (293.7, 0.36, 0.9, 0.8)]
        default: return []
        }
    }

    /// How loud a cue's call is beside the war horn's: each as loud as the
    /// partials it took over from.
    static func callLevel(of cue: SoundCue) -> Float {
        switch cue {
        case .envoy: return 1.6
        case .triumph: return 1.25
        case .honour: return 1.05
        default: return 1
        }
    }

    /// How loud a struck cue's blows are, struck full: each as loud over its
    /// first moments as the struck partials it took over from.
    static func strikeLevel(of cue: SoundCue) -> Float {
        switch cue {
        case .anvil: return 4
        case .stand: return 1.8
        case .lore: return 2.1
        case .herald: return 3.1
        case .complete: return 1.3
        case .rise: return 2.45
        case .accord: return 2.2
        default: return 1.6
        }
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
        case .muster, .horn:
            // Blown on the recorded horn (`call(of:)`): no note of its own.
            return []
        case .anvil, .stand, .deny, .lore, .herald, .complete, .rise, .accord:
            // Struck on recorded instruments (`strikes(of:)`).
            return []
        case .envoy, .triumph, .honour, .banner:
            // Blown on the recorded horn (`call(of:)`).
            return []
        case .leaf:
            // A page turned: paper's brush, and the faintest high note.
            note = Note(partials: [Partial(frequency: 2_637, amplitude: 0.03, decay: 24)], noise: 0.055, noiseDecay: 36)
        case .fold:
            // The page laid down: lower, softer, and quicker gone.
            note = Note(partials: [Partial(frequency: 1_760, amplitude: 0.026, decay: 30)], noise: 0.045, noiseDecay: 44)
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
        for note in pendingBlown {
            cueHorns.blow(note.frequency, strength: note.strength, hold: note.hold, heard: (note.left, note.right), wait: note.wait)
        }
        pendingBlown.removeAll(keepingCapacity: true)
        for strike in pendingStrikes {
            let slot = Reading.free(struck, rate: sampleRate)
            var voice = Reading(note: strike.note)
            voice.step = strike.ratio * Double(Recordings.rate / sampleRate)
            voice.left = strike.left * strike.strength
            voice.right = strike.right * strike.strength
            voice.wait = strike.wait
            voice.sounding = true
            struck[slot] = voice
            cueStrikes += 1
        }
        pendingStrikes.removeAll(keepingCapacity: true)
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
        if let next = pendingHost {
            hostTarget = next
            pendingHost = nil
        }
        if let next = pendingTown {
            townTarget = next
            pendingTown = nil
        }
        if let next = pendingShore {
            shoreTarget = next
            pendingShore = nil
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
        if let next = pendingGrinding {
            towns.grinding = next
            pendingGrinding = nil
        }
        if let next = pendingReading {
            towns.reading = next
            pendingReading = nil
        }
        if let next = pendingForging {
            towns.forging = next
            pendingForging = nil
        }
        if let next = pendingPosting {
            towns.posting = next
            pendingPosting = nil
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
        // The roar of a great host: the band below the voices.
        let roarBottom = 1 - exp(-tau * 45 * dt), roarTop = 1 - exp(-tau * 180 * dt)
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
            // The cues' calls on the recorded horn, from where they sound.
            let called = cueHorns.sample(dt: dt)
            cueLeft += called.left * Self.hornCueGain
            cueRight += called.right * Self.hornCueGain
            // And their recorded blows.
            for index in struck.indices where struck[index].sounding {
                if struck[index].wait > 0 {
                    struck[index].wait -= dt
                    continue
                }
                let blow = struck[index].next() * Self.strikeGain
                cueLeft += blow * struck[index].left
                cueRight += blow * struck[index].right
            }

            // The din of battle: as loud as the fighting, from where it is.
            din.level += (dinTarget.level - din.level) * min(dt * 2, 1)
            din.pan += (dinTarget.pan - din.pan) * min(dt * 2, 1)
            host += (hostTarget - host) * min(dt * 0.8, 1)
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
                    nextClash = (0.05 + 0.25 * abs(random())) / max(din.level, 0.2) / (1 + 3 * host)
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
                if host > 0.001 {
                    // The throng's roar, swelling and ebbing as the lines surge.
                    let deep = random()
                    roarLow += (deep - roarLow) * roarBottom
                    roarHigh += (deep - roarHigh) * roarTop
                    let surge = 0.65 + 0.35 * Float(sin(time * 0.37)) * Float(sin(time * 0.11 + 1))
                    // Now and then a war horn across the field, on A or on
                    // D: a horn as it was recorded, held, falling away.
                    nextHorn -= dt
                    if nextHorn <= 0 {
                        dinHorns.blow(abs(random()) > 0.5 ? 110 : 146.8, strength: 1, hold: Self.warHornHeld)
                        nextHorn = 5 + 6 * abs(random())
                    }
                    let call = dinHorns.sample(dt: dt).left * Self.warHornGain
                    battle += ((roarHigh - roarLow) * 3.2 * surge + call) * host * din.level
                }
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

            // The lake at its edge near the view: as near as the view
            // comes to the strand, from where it lies across the view.
            shore.level += (shoreTarget.level - shore.level) * min(dt * 1.2, 1)
            shore.pan += (shoreTarget.pan - shore.pan) * min(dt * 1.2, 1)
            var shoreLeft: Float = 0, shoreRight: Float = 0
            if shore.level > 0.0005 {
                let lapping = shores.sample(dt: dt) * Self.shoreGain * shore.level * heard.ambience * level
                let shoreAngle = (0.75 * shore.pan + 1) * .pi / 4
                shoreLeft = lapping * cos(shoreAngle) * 1.414
                shoreRight = lapping * sin(shoreAngle) * 1.414
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
            left[frame] = Self.softened(drone * level + musicLeft + hallLeft + heardLeft + windLeft * air + dinLeft + townLeft + shoreLeft)
            right[frame] = Self.softened(drone * level + musicRight + hallRight + heardRight + windRight * air + dinRight + townRight + shoreRight)
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
        // The timber's crack, then the dust settling.
        case .batter: return ((650, 0.8), (300, 0.6))
        case .tend: return ((1_000, 0.6), nil)
        case .sift: return ((6_400, 1.3), nil)
        case .leaf: return ((4_800, 0.7), nil)
        case .fold: return ((3_000, 0.7), nil)
        case .watch, .rise, .envoy, .triumph, .accord, .refusal, .lore, .banner, .honour, .muster, .horn, .anvil, .stand, .deny,
             .complete, .herald:
            return (nil, nil)
        }
    }

    /// How loud a town is, close by: about as loud as the night beneath it.
    static let townGain: Float = 0.15
    /// How loud the shore is, at its nearest: about as loud as the night.
    static let shoreGain: Float = 0.2
    /// How loud a cue's call on the recorded horn is: as loud as the horns
    /// of overtones the war horn's and the muster's cues were.
    static let hornCueGain: Float = 0.15
    /// How loud a cue's recorded blow is struck full.
    static let strikeGain: Float = 0.1
    /// How loud a war horn across a great host's battle is, and how long
    /// it is held: as loud as the horn of overtones it took over from.
    static let warHornGain: Float = 0.19
    static let warHornHeld: Float = 1.4

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
