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
        /// Blows exchanged.
        case battle
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

        /// Every cue, for tests and previews.
        public static let all: [Cue] = [.select, .order, .battle, .watch, .rise, .dread, .envoy, .triumph, .accord, .toll]
    }

    private static let logger = Logger(subsystem: "online.nullmere.game", category: "sound")

    private let engine = AVAudioEngine()
    private let synth = Synth()
    private var started = false

    public var isEnabled: Bool {
        didSet { apply() }
    }

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

    private func apply() {
        if isEnabled { start() } else { stop() }
    }

    public func start() {
        guard isEnabled, !started else { return }
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
        switch cue {
        case .select:
            note = Note(partials: [Partial(frequency: 1320, amplitude: 0.10, decay: 30)], noise: 0.03, noiseDecay: 90)
        case .order:
            note = Note(partials: [Partial(frequency: 660, amplitude: 0.09, decay: 14), Partial(frequency: 990, amplitude: 0.04, decay: 18)], noise: 0.02, noiseDecay: 60)
        case .battle:
            note = Note(partials: [Partial(frequency: 58, amplitude: 0.16, decay: 7), Partial(frequency: 91, amplitude: 0.06, decay: 9)], noise: 0.09, noiseDecay: 22)
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
        }
        lock.lock()
        if pending.count < 8 { pending.append(note) }
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
                let age = notes[n].age
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

            let music = score.sample(dt: dt) * level
            let bed = (drone + 0.5 * cue) * level + music
            left[frame] = bed + windLeft * 0.6 * wind * level + 0.5 * cue * (1 - level)
            right[frame] = bed + windRight * 0.6 * wind * level + 0.5 * cue * (1 - level)
        }
        notes.removeAll { $0.age > 8 }
        if time > 10_000 { time -= 10_000 }
    }
}
