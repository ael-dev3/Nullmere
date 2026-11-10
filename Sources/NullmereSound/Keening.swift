import Foundation

/// The unquiet dead heard where they lie unburied near the view: two thin
/// voices keening, each sliding slowly from note to note of a low lament,
/// swelling through a phrase and falling all but silent between, never
/// together, and now and then a whisper, breathy and high, gone almost as
/// soon as it is heard.
/// Quieter than fire, close by. It draws on noise of its own, so the night
/// sounds as it did whether the dead are heard or not.
struct Keening {
    let sampleRate: Float
    private var noise = Noise(seed: 0x00DE_ADA1)
    /// The draws that choose each voice's next note and breath and each
    /// whisper, apart from the noise drawn every sample, so the dead keen
    /// alike at any sample rate.
    private var choosing = Noise(seed: 0x0C01_DCA1)
    /// The noise scaled so a whisper sounds as loud at any rate: the filter
    /// passes the same band of it.
    private let loudness: Float
    /// The notes the voices slide among, a lament's in a low voice.
    static let notes: [Float] = [329.63, 349.23, 392.00, 415.30, 466.16, 523.25]

    private struct Voice {
        /// Where it sings and where it slides toward.
        var frequency: Float
        var target: Float
        /// How full its breath, and toward what it swells or sinks; and
        /// whether it is keening a phrase or drawing breath between.
        var breath: Float
        var breathTarget: Float
        var singing: Bool
        /// How long until it leaves its note, and until its next breath.
        var untilNote: Float
        var untilBreath: Float
        var phase: Float = 0
        var tremble: Float = 0
        /// How fast its voice trembles, how loud it is beside the other, and
        /// how its notes lie against the lament's (the lower a fifth down).
        let trembling: Float
        let gain: Float
        let ratio: Float
    }
    private var voices: [Voice]
    /// The whisper sounding: how long since it began and how loud; and how
    /// long until the next.
    private var whisper: (age: Float, amplitude: Float) = (1, 0)
    private var untilWhisper: Float = 1.2
    private var hush: Bandpass
    /// How many times a voice has left its note, and how many whispers, for
    /// tests.
    private(set) var glides = 0
    private(set) var whispers = 0

    /// How long a whisper's breath takes to come, and to fade.
    static let whisperRise: Float = 0.06
    static let whisperFade: Float = 0.22

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        loudness = (sampleRate / 48_000).squareRoot()
        hush = Bandpass(centre: 3_200, width: 1.2, sampleRate: sampleRate)
        voices = [Voice(frequency: Keening.notes[2], target: Keening.notes[2], breath: 0.4, breathTarget: 0.8, singing: true,
                        untilNote: 1.1, untilBreath: 2.2, trembling: 4.6, gain: 1, ratio: 1),
                  Voice(frequency: Keening.notes[0] * 2 / 3, target: Keening.notes[0] * 2 / 3, breath: 0.05, breathTarget: 0.05,
                        singing: false, untilNote: 2.3, untilBreath: 1.3, trembling: 3.9, gain: 0.6, ratio: 2.0 / 3.0)]
    }

    /// A draw from 0 to 1.
    private static func draw(_ from: inout Noise) -> Float { 0.5 + 0.5 * from.next() }

    /// The dead's next sample, at full; the synthesiser sets how near.
    @inline(__always)
    mutating func sample(dt: Float) -> Float {
        var sound: Float = 0
        for index in voices.indices {
            var voice = voices[index]
            voice.untilNote -= dt
            if voice.untilNote <= 0 {
                let pick = min(Int(Keening.draw(&choosing) * Float(Keening.notes.count)), Keening.notes.count - 1)
                voice.target = Keening.notes[pick] * voice.ratio
                voice.untilNote = 2.5 + 3 * Keening.draw(&choosing)
                glides += 1
            }
            voice.untilBreath -= dt
            if voice.untilBreath <= 0 {
                // A phrase keened, swelling, for a few seconds; then breath
                // drawn, all but silent, for a second or so.
                voice.singing.toggle()
                voice.breathTarget = voice.singing ? 0.55 + 0.45 * Keening.draw(&choosing) : 0.02 * Keening.draw(&choosing)
                voice.untilBreath = voice.singing ? 1.6 + 1.8 * Keening.draw(&choosing) : 1 + 1.6 * Keening.draw(&choosing)
            }
            // A slide, never a step: eased toward its note over most of a
            // second; its breath swelling in over half of one, and dying
            // away a little quicker.
            voice.frequency += (voice.target - voice.frequency) * min(dt * 1.6, 1)
            voice.breath += (voice.breathTarget - voice.breath) * min(dt * (voice.singing ? 2.2 : 2.8), 1)
            voice.tremble += dt * voice.trembling * 2 * .pi
            if voice.tremble > 2 * .pi { voice.tremble -= 2 * .pi }
            voice.phase += dt * voice.frequency * (1 + 0.006 * sin(voice.tremble)) * 2 * .pi
            if voice.phase > 2 * .pi { voice.phase -= 2 * .pi }
            // A thin voice: its note, and a little of the octave above.
            sound += (sin(voice.phase) + 0.18 * sin(2 * voice.phase)) * voice.breath * voice.gain
            voices[index] = voice
        }
        // Now and then a whisper: breath through the teeth, high and brief.
        untilWhisper -= dt
        if untilWhisper <= 0 {
            whisper = (0, 0.35 + 0.65 * Keening.draw(&choosing))
            untilWhisper = 1.6 + 3.2 * Keening.draw(&choosing)
            whispers += 1
        }
        if whisper.age < 1 {
            whisper.age += dt
            let rise = min(whisper.age / Keening.whisperRise, 1)
            sound += hush.process(noise.next() * loudness) * whisper.amplitude * rise * exp(-whisper.age / Keening.whisperFade) * 2.4
        }
        return sound * 0.32
    }
}
