import AVFoundation
import Foundation
import os

/// The game's sound, all of it made as it plays: a cold drone and the
/// night wind over the still water, and a few quiet cues. Nothing is
/// recorded or sampled.
@MainActor
public final class Ambience {
    public enum Cue: Sendable {
        /// Something chosen on the map.
        case select
        /// A company given its march.
        case order
        /// The watch turns: a low bell over the water.
        case watch
        /// A hold founded, a work completed.
        case rise
        /// War declared, a hold lost.
        case dread
        /// An envoy at the gate: a soft call of two notes.
        case envoy
        /// A hold taken: a rising triad.
        case triumph
        /// Peace or a pact: a gentle sixth.
        case accord
        /// A House destroyed: a deep, long toll.
        case toll
        /// Steel meeting steel: a company strikes in close.
        case clash
        /// A bowstring loosed.
        case loose
        /// Riders sent off: hooves on hard ground.
        case ride

        /// Every cue, for tests and previews.
        public static let all: [Cue] = [.select, .order, .watch, .rise, .dread, .envoy, .triumph, .accord, .toll,
                                        .clash, .loose, .ride]
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

    /// The engine is running: for tests.
    var isPlaying: Bool { started }

    public init(enabled: Bool) {
        isEnabled = enabled
    }

    public func play(_ cue: Cue) {
        guard isEnabled, started else { return }
        synth.trigger(cue)
    }

    /// The score: on or off, and at peace or at war.
    public var isMusicOn = true {
        didSet { applyMusic() }
    }

    public var isAtWar = false {
        didSet { if isAtWar != oldValue { applyMusic() } }
    }

    private func applyMusic() {
        synth.setMusic(on: isMusicOn, mood: isAtWar ? .war : .peace)
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
        if isEnabled { begin() } else { end() }
    }

    public func start() {
        isWanted = true
        begin()
    }

    private func begin() {
        guard isEnabled, isWanted, !started else { return }
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
        end()
    }

    private func end() {
        guard started else { return }
        engine.stop()
        for node in engine.attachedNodes where node is AVAudioSourceNode {
            engine.detach(node)
        }
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
        var age: Float = 0
        /// Seconds after the cue begins that this note sounds.
        var delay: Float = 0
    }

    private let lock = NSLock()
    private var pending: [Note] = []
    private var notes: [Note] = []

    private var sampleRate: Float = 48_000
    private var time: Float = 0
    private var level: Float = 0
    private var target: Float = 0
    private var seed: UInt32 = 0x1234_5678
    private var windLeft: Float = 0
    private var windRight: Float = 0
    private var gust: Float = 0
    private var dronePhases: [Float] = [0, 0, 0, 0]
    private var score = Score()
    private var pendingMusic: (on: Bool, mood: Score.Mood)?
    private var volumes: (effects: Float, ambience: Float, music: Float) = (1, 1, 1)
    private var pendingVolumes: (effects: Float, ambience: Float, music: Float)?

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

    func prepare(sampleRate: Float) {
        self.sampleRate = sampleRate
    }

    func fadeIn() {
        lock.lock(); target = 1; lock.unlock()
    }

    /// Skips the fade, for measuring.
    func settle() {
        lock.lock(); target = 1; level = 1; lock.unlock()
    }

    func trigger(_ cue: Ambience.Cue) {
        let note: Note
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
            note = Note(partials: [Partial(frequency: 46.25, amplitude: 0.14, decay: 0.7), Partial(frequency: 69.3, amplitude: 0.065, decay: 0.9), Partial(frequency: 97.99, amplitude: 0.04, decay: 1.2)], noise: 0.026, noiseDecay: 3)
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
                ], noise: 0.06 * strength, noiseDecay: 50, delay: delay)
            }
            note = hoof(0, 1)
            more = [hoof(0.12, 0.8), hoof(0.21, 0.9)]
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
        if let music = pendingMusic {
            score.target = music.on ? 1 : 0
            score.mood = music.mood
            pendingMusic = nil
        }
        if let next = pendingVolumes {
            volumes = next
            pendingVolumes = nil
        }
        let volume = volumes
        lock.unlock()

        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
        else { return }

        let dt = 1 / sampleRate
        let tau: Float = 2 * .pi
        let droneFrequencies: [Float] = [55, 82.41, 110, 164.81]
        for frame in 0..<frames {
            time += dt
            level += (goal - level) * dt / 4

            // The drone: a few cold partials, each swelling at its own pace.
            var drone: Float = 0
            for i in 0..<4 {
                dronePhases[i] += tau * droneFrequencies[i] * dt
                if dronePhases[i] > tau { dronePhases[i] -= tau }
                let swell = 0.5 + 0.5 * sin(time * (0.031 + Float(i) * 0.017) + Float(i) * 1.7)
                drone += sin(dronePhases[i]) * swell * (i == 0 ? 0.016 : 0.009)
            }

            // The wind: soft noise, gusting slowly, a little different in each ear.
            gust += (0.5 + 0.5 * sin(time * 0.07) * sin(time * 0.023 + 1) - gust) * dt * 0.5
            let cutoff = 0.004 + 0.012 * gust
            windLeft += (random() - windLeft) * cutoff
            windRight += (random() - windRight) * cutoff
            let wind = 0.55 + 0.45 * gust

            var cue: Float = 0
            for n in notes.indices {
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
            }

            cue *= volume.effects
            drone *= volume.ambience
            let air = 0.6 * wind * level * volume.ambience
            let music = score.sample(dt: dt) * level * volume.music
            let bed = (drone + 0.5 * cue) * level + music
            left[frame] = bed + windLeft * air + 0.5 * cue * (1 - level)
            right[frame] = bed + windRight * air + 0.5 * cue * (1 - level)
        }
        notes.removeAll { $0.age - $0.delay > 8 }
        if time > 10_000 { time -= 10_000 }
    }
}
