import AVFoundation
import Foundation
import NullmereCore
import os

/// The game's sound, all of it made as it plays: a cold drone and the
/// night wind over the still water, and a few quiet cues. Nothing is
/// recorded or sampled.
/// Where a sound is heard from: across the view, -1 its left edge to 1 its
/// right, and how loud for how far off it lies. Each ear hears it by an
/// equal-power law, a sound in the middle at its full in both, one at the
/// edge leaning well into the nearer ear but never gone from the other.
public struct SoundPlace: Equatable, Sendable {
    public var pan: Float
    public var gain: Float

    public init(pan: Float, gain: Float) {
        self.pan = min(max(pan, -1), 1)
        self.gain = min(max(gain, 0), 1)
    }

    /// The middle of the view: orders, the watch's bell, what has no place.
    public static let middle = SoundPlace(pan: 0, gain: 1)

    private var angle: Float { (0.75 * pan + 1) * .pi / 4 }

    var left: Float { Float(2).squareRoot() * cos(angle) * gain }
    var right: Float { Float(2).squareRoot() * sin(angle) * gain }
}

@MainActor
public final class Ambience {
    public enum Cue: Sendable {
        /// Something chosen on the map.
        case select
        /// A company given its march.
        case order
        /// The watch turns: a low bell over the water.
        case watch
        /// Something raised: a hold founded, a work or a company ordered,
        /// and each finished.
        case rise
        /// War begun, a hold or a company lost, hunger.
        case dread
        /// An envoy at the gate: a soft call of two notes.
        case envoy
        /// A hold taken: a rising triad.
        case triumph
        /// Peace or a pact: a gentle sixth.
        case accord
        /// A House destroyed: a deep, long toll.
        case toll
        /// Steel meeting steel: a company strikes in close, or is struck.
        case clash
        /// A bowstring loosed, by a company or at one.
        case loose
        /// Riders sent off: hooves on hard ground.
        case ride
        /// A company digging in: two spades into stony earth.
        case dig
        /// Goods and gifts changing hands: a few coins counted out.
        case coin
        /// An envoy sent: a soft reed call that rises, asking.
        case parley
        /// A company halted or sent home: a drum's two strokes, the second softer.
        case stand
        /// A work finished: the last knocks of the mallet, and a bright chord.
        case complete
        /// Companies mustered and ready: a horn's call, rising.
        case muster
        /// An offer refused: two soft notes falling.
        case refusal
        /// A hold's walls battered: a heavy blow on timber and stone.
        case batter
        /// A study finished: glass bells rising, one after another.
        case lore
        /// A war horn: a rally called or setting out, a commander's skill.
        case horn
        /// Two stately chords: an alliance founded, joined or led.
        case banner
        /// The realm's crier: drums, then a bell, as a happening begins or ends.
        case herald
        /// A bright fanfare: a deed done, a charge kept, a commander risen.
        case honour
        /// The healers at work: a small bell over a warm, low hum, as the
        /// fallen are carried in and their healing paid for.
        case tend
        /// Salt running through an hourglass, then a small glass chime: an
        /// hourglass turned to hasten what is under way.
        case sift
        /// The smith's hammer on the anvil, three bright blows, the last
        /// left to ring: gear forged.
        case anvil
        /// A panel opened: a leaf turned, a brush of paper and a faint high note.
        case leaf
        /// A panel closed, or the keeper stepping back: the leaf laid down,
        /// lower and softer.
        case fold
        /// An order the rules refuse: two muted knocks on wood, the second lower.
        case deny

        /// Every cue, for tests and previews.
        public static let all: [Cue] = [.select, .order, .watch, .rise, .dread, .envoy, .triumph, .accord, .toll,
                                        .clash, .loose, .ride, .dig, .coin, .parley, .stand, .complete, .muster,
                                        .refusal, .batter, .lore, .horn, .banner, .herald, .honour, .tend, .sift, .anvil,
                                        .leaf, .fold, .deny]
    }

    private static let logger = Logger(subsystem: "online.nullmere.game", category: "sound")

    private let engine = AVAudioEngine()
    private let synth = Synth()
    private var started = false

    /// The player has sound turned on.
    public var isEnabled: Bool {
        didSet { apply() }
    }

    /// The game wants its sound now, from `start()` to `stop()`: at the
    /// realm's door and in the world, not in the launcher. Sound turned on
    /// meanwhile waits for it.
    public private(set) var isWanted = false

    /// Fading out before the engine stops: a hard stop clicks.
    private var winding: Task<Void, Never>?
    /// How long sound takes to fade out, as the picture fades.
    static let fadeOutSeconds = 0.8

    /// The engine is running and not fading out: for tests.
    var isPlaying: Bool { started && winding == nil }

    /// The engine is running, fading out or not: for tests.
    var isRunning: Bool { started }

    /// When each cue last sounded. The same cue again within a tenth of a
    /// second is one sound, not a pile of them: ten watches turned at once
    /// toll one bell.
    private var lastPlayed: [Cue: ContinuousClock.Instant] = [:]

    public init(enabled: Bool) {
        isEnabled = enabled
    }

    /// The cues asked for together, as a watch's turning asks for its bell
    /// and what the watch brought: when they began, and how many so far.
    private var batch: (start: ContinuousClock.Instant, count: Int)?
    /// How far apart cues asked for together sound: one after another, the
    /// bell first, not all at once.
    static let batchSpacing: Float = 0.38

    public func play(_ cue: Cue, at place: SoundPlace = .middle) {
        guard isEnabled, started, winding == nil else { return }
        let now = ContinuousClock.now
        if let last = lastPlayed[cue], now - last < .milliseconds(100) { return }
        lastPlayed[cue] = now
        var delay: Float = 0
        if let current = batch, now - current.start < .milliseconds(30) {
            delay = Float(current.count) * Self.batchSpacing
            batch = (current.start, current.count + 1)
        } else {
            batch = (now, 1)
        }
        synth.trigger(cue, after: delay, at: place)
    }

    /// Fades all of it out quickly, for the app quitting, and says how long
    /// to wait for it: a hard stop clicks. Nothing to wait for while silent
    /// or already fading.
    @discardableResult
    public func fadeForQuitting() -> Double {
        guard started, winding == nil else { return 0 }
        synth.fadeOut(rate: 12)
        return Self.quitFadeSeconds
    }

    /// Long enough at that pace for the sound to fall some thirty decibels.
    public static let quitFadeSeconds = 0.35

    /// The din of the fields of battle in sight: how loud, from nothing (0)
    /// to a great battle close by (1), and where across the view, from the
    /// left (-1) to the right (1).
    public func setDin(level: Float, pan: Float) {
        synth.setDin(level: level, pan: pan)
    }

    /// The score: on or off, and at peace or at war.
    public var isMusicOn = true {
        didSet { applyMusic() }
    }

    public var isAtWar = false {
        didSet { if isAtWar != oldValue { applyMusic() } }
    }

    /// The lake whose title theme plays, over the launcher; nil in the realm.
    public var titleLake: Lake? {
        didSet { if titleLake != oldValue { applyMusic() } }
    }

    /// What the score plays now: the title theme over the launcher, war or
    /// peace in the realm.
    var mood: Score.Mood {
        titleLake.map { .title($0) } ?? (isAtWar ? .war : .peace)
    }

    private func applyMusic() {
        synth.setMusic(on: isMusicOn, mood: mood)
    }

    /// How loud each part of the sound plays, from silent (0) to full (1):
    /// the cues, the night's drone and wind, and the score.
    public var effectsVolume: Float = 1 { didSet { applyVolumes() } }
    public var ambienceVolume: Float = 1 { didSet { applyVolumes() } }
    public var musicVolume: Float = 1 { didSet { applyVolumes() } }

    private func applyVolumes() {
        synth.setVolumes(effects: effectsVolume, ambience: ambienceVolume, music: musicVolume)
    }

    private func apply() {
        if isEnabled { begin() } else { windDown() }
    }

    public func start() {
        isWanted = true
        begin()
    }

    private func begin() {
        guard isEnabled, isWanted else { return }
        if let winding {
            // Wanted again while fading out: it fades back in.
            winding.cancel()
            self.winding = nil
            synth.fadeIn()
            return
        }
        guard !started else { return }
        let format = engine.outputNode.inputFormat(forBus: 0)
        let rate = format.sampleRate > 0 ? format.sampleRate : 48_000
        let stereo = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        synth.prepare(sampleRate: Float(rate))
        let source = Ambience.makeSource(format: stereo, synth: synth)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: stereo)
        engine.mainMixerNode.outputVolume = 0.9
        do {
            try engine.start()
            started = true
            synth.fadeIn()
            applyMusic()
        } catch {
            Ambience.logger.notice("No sound: \(error.localizedDescription, privacy: .public)")
            engine.detach(source)
        }
    }

    /// Built outside the main actor: the render block runs on the audio thread.
    nonisolated private static func makeSource(format: AVAudioFormat, synth: Synth) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, buffers in
            synth.render(frames: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(buffers))
            return noErr
        }
    }

    public func stop() {
        isWanted = false
        windDown()
    }

    /// Fades out, then stops the engine.
    private func windDown() {
        guard started, winding == nil else { return }
        synth.fadeOut()
        winding = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Ambience.fadeOutSeconds))
            guard let self, !Task.isCancelled else { return }
            self.winding = nil
            self.end()
        }
    }

    private func end() {
        guard started else { return }
        engine.stop()
        for node in engine.attachedNodes where node is AVAudioSourceNode {
            engine.detach(node)
        }
        // Begun again, it fades in from silence, with no tail of before.
        synth.reset()
        started = false
    }
}

/// The synthesiser behind `Ambience`. It renders on the audio thread; the
/// main thread only queues cues, under a lock.
final class Synth: @unchecked Sendable {
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

    /// The drone's partials.
    private static let droneFrequencies: [Float] = [55, 82.41, 110, 164.81]

    init() {
        // Room enough up front that the audio thread never has to find more.
        notes.reserveCapacity(64)
        pending.reserveCapacity(24)
    }

    func setVolumes(effects: Float, ambience: Float, music: Float) {
        let clamp = { (value: Float) in min(max(value, 0), 1) }
        lock.lock(); pendingVolumes = (clamp(effects), clamp(ambience), clamp(music)); lock.unlock()
    }

    /// What the score has played, for tests.
    var scoreSnapshot: Score {
        lock.lock(); defer { lock.unlock() }
        return score
    }

    func setMusic(on: Bool, mood: Score.Mood) {
        lock.lock(); pendingMusic = (on, mood); lock.unlock()
    }

    func setDin(level: Float, pan: Float) {
        lock.lock(); pendingDin = (min(max(level, 0), 1), min(max(pan, -1), 1)); lock.unlock()
    }

    /// The din as it is heard, for tests.
    var dinHeard: (level: Float, pan: Float) {
        lock.lock(); defer { lock.unlock() }
        return din
    }

    func prepare(sampleRate: Float) {
        self.sampleRate = sampleRate
    }

    func fadeIn() {
        lock.lock(); target = 1; fadeRate = 0.25; lock.unlock()
    }

    func fadeOut(rate: Float = 5) {
        lock.lock(); target = 0; fadeRate = rate; lock.unlock()
    }

    /// Silent, with nothing left sounding: called with the engine stopped.
    func reset() {
        lock.lock()
        level = 0
        target = 0
        pending.removeAll()
        notes.removeAll()
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

    func trigger(_ cue: Ambience.Cue, after delay: Float = 0, at place: SoundPlace = .middle) {
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
        for index in more.indices {
            more[index].delay += delay
            more[index].end = more[index].delay + more[index].length
            (more[index].left, more[index].right) = (place.left, place.right)
        }
        lock.lock()
        if pending.count < 12 { pending.append(note); pending.append(contentsOf: more) }
        lock.unlock()
    }

    private func random() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed >> 8) / Float(1 << 24) * 2 - 1
    }

    func render(frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
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
        let volume = volumes
        lock.unlock()
        if !heardBegun {
            heard = volume
            heardBegun = true
        }

        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
        else { return }

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
                    cue += random() * notes[n].noise * exp(-age * notes[n].noiseDecay)
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

            cueLeft *= heard.effects
            cueRight *= heard.effects
            drone *= heard.ambience
            let air = 0.6 * wind * level * heard.ambience
            let music = score.sample(dt: dt) * level * heard.music
            // The cues sound whole while night falls, but go with the rest
            // as the sound fades out, so nothing rings on to be cut off.
            let cueLevel = goal > 0 ? 1 : level
            let bed = drone * level + music
            left[frame] = Self.softened(bed + 0.5 * cueLeft * cueLevel + windLeft * air + dinLeft)
            right[frame] = Self.softened(bed + 0.5 * cueRight * cueLevel + windRight * air + dinRight)
        }
        notes.removeAll { $0.age > $0.end }
    }

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
