import Foundation
import NullmereCore

/// The game's music: an original score written as it plays. Slow chords in
/// D minor drift beneath a sparse line of bell-like notes from the minor
/// pentatonic; at war a low, distant drum keeps time and the chords darken.
/// Over the launcher, the title theme of the lake the keeper's realm last
/// lay on, each lake in its own mode. It renders on the audio thread inside
/// `Synth`, from its own seeded generator, so the same seed always plays
/// the same music.
struct Score {
    enum Mood: Equatable {
        case peace
        case war
        /// The title theme of a lake, over the launcher.
        case title(Lake)
    }

    /// MIDI notes of the chords the score moves among, and which may follow.
    static let chords: [[Int]] = [
        [50, 53, 57],  // D minor
        [46, 50, 53],  // B flat
        [53, 57, 60],  // F
        [48, 52, 55],  // C
        [43, 46, 50],  // G minor
    ]
    static let warChords: [[Int]] = [
        [38, 50, 53, 57],  // D minor, low
        [43, 46, 50],      // G minor
        [46, 49, 53],      // B flat minor
        [45, 49, 52],      // A, the dominant, unresolved
    ]
    /// The melody's notes: D minor pentatonic across two octaves.
    static let melody: [Int] = [62, 65, 67, 69, 72, 74, 77, 79, 81]

    static func frequency(_ midi: Int) -> Float {
        440 * pow(2, Float(midi - 69) / 12)
    }

    private struct Voice {
        var frequency: Float
        var phase: Float = 0
        var detunePhase: Float = 0
    }

    private struct Bell {
        var frequency: Float
        var age: Float = 0
        var phase: Float = 0
    }

    var mood: Mood = .peace
    /// How loud the music is, 0...1, eased toward `target`.
    var level: Float = 0
    var target: Float = 0

    private var seed: UInt32
    private var current: [Voice] = []
    private var previous: [Voice] = []
    private var crossfade: Float = 1
    private var chordClock: Float = 0
    private var chordLength: Float = 10
    private var bellClock: Float = 2
    private var bells: [Bell] = []
    private var lastNote = 69
    private var drumClock: Float = 0
    private var drumAge: Float = 99
    private var drumPhase: Float = 0

    /// What has been played, for tests: the melody's MIDI notes in order,
    /// chord changes, and drum strokes.
    private(set) var playedNotes: [Int] = []
    private(set) var chordChanges = 0
    private(set) var drumStrokes = 0

    init(seed: UInt32 = 0x0D15_EA5E) {
        self.seed = seed
        // Room enough up front that the audio thread never has to find more.
        current.reserveCapacity(4)
        previous.reserveCapacity(4)
        bells.reserveCapacity(16)
        playedNotes.reserveCapacity(4096)
        for note in Score.chords[0] { current.append(Voice(frequency: Score.frequency(note))) }
    }

    private mutating func random() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed >> 8) / Float(1 << 24)
    }

    private mutating func nextChord() {
        let theme = Theme.of(mood)
        let pool = theme.chords
        let chord = pool[Int(random() * Float(pool.count)) % pool.count]
        // The chord sounding becomes the one fading, as it was, phases and
        // all; the new one is written into the room the old fading one
        // leaves, so nothing is allocated on the audio thread.
        swap(&previous, &current)
        current.removeAll(keepingCapacity: true)
        for note in chord { current.append(Voice(frequency: Score.frequency(note))) }
        crossfade = 0
        chordLength = theme.chordLength + random() * theme.chordSpread
        chordChanges += 1
    }

    private mutating func nextBell() {
        // A small step from the last note, now and then a leap.
        let theme = Theme.of(mood)
        let melody = theme.melody
        let index = melody.firstIndex(of: lastNote) ?? 3
        let step = random() < 0.8 ? Int(random() * 5) - 2 : Int(random() * 9) - 4
        let next = melody[min(max(index + step, 0), melody.count - 1)]
        lastNote = next
        bells.append(Bell(frequency: Score.frequency(next)))
        // A theme that answers itself: the same note again, higher, a
        // breath later, as one water answers the other.
        if let echo = theme.echo {
            bells.append(Bell(frequency: Score.frequency(next + echo), age: -Theme.echoDelay))
        }
        if playedNotes.count < 4096 { playedNotes.append(next) }
        // Silence matters as much as the notes.
        bellClock = theme.bellGap + random() * 5
        if random() < 0.25 { bellClock += 6 }
    }

    /// One sample of music, before the master level.
    mutating func sample(dt: Float) -> Float {
        level += (target - level) * dt / 3
        guard level > 0.0005 else { return 0 }
        let tau: Float = 2 * .pi

        chordClock += dt
        if chordClock >= chordLength {
            chordClock = 0
            nextChord()
        }
        crossfade = min(1, crossfade + dt / 4)

        // The pads: two soft partials a voice, gently detuned. The chord
        // fading out sounds just as it did while it was the chord, so the
        // change is a crossfade and never a step.
        func voice(_ voice: inout Voice) -> Float {
            voice.phase += tau * voice.frequency * dt
            voice.detunePhase += tau * voice.frequency * 1.003 * dt
            if voice.phase > tau { voice.phase -= tau }
            if voice.detunePhase > tau { voice.detunePhase -= tau }
            return sin(voice.phase) + sin(voice.detunePhase) * 0.6 + sin(voice.phase * 2) * 0.15
        }
        var pad: Float = 0
        for i in current.indices {
            pad += voice(&current[i]) * crossfade
        }
        if crossfade < 1 {
            for i in previous.indices {
                pad += voice(&previous[i]) * (1 - crossfade)
            }
        }
        let breath = 0.75 + 0.25 * sin(chordClock / chordLength * .pi)
        pad *= 0.015 * breath

        // The bells.
        bellClock -= dt
        if bellClock <= 0 { nextBell() }
        var bell: Float = 0
        for i in bells.indices {
            bells[i].age += dt
            bells[i].phase += tau * bells[i].frequency * dt
            if bells[i].phase > tau { bells[i].phase -= tau }
            let b = bells[i]
            // An echo waiting its breath sounds nothing yet.
            let envelope = b.age < 0 ? 0 : min(b.age * 25, 1) * exp(-b.age * 0.55)
            bell += (sin(b.phase) + 0.25 * sin(b.phase * 2) + 0.08 * sin(b.phase * 3.01)) * envelope
        }
        bells.removeAll { $0.age > 9 }
        bell *= 0.06

        // At war, a distant drum.
        var drum: Float = 0
        if mood == .war {
            drumClock += dt
            if drumClock >= 2.4 {
                drumClock = 0
                drumAge = 0
                drumPhase = 0
                drumStrokes += 1
            }
        }
        if drumAge < 3 {
            drumAge += dt
            let pitch: Float = 52 * (1 + 0.6 * exp(-drumAge * 18))
            drumPhase += tau * pitch * dt
            drum = sin(drumPhase) * exp(-drumAge * 5) * 0.12
        }

        return (pad + bell + drum) * level
    }
}

/// What a mood plays: its chords and how long each lasts, its melody's
/// notes and the silence between them, and whether each note is answered.
/// The realm's peace and war, and a title theme for each lake, each lake in
/// a mode of its own.
struct Theme {
    let chords: [[Int]]
    let melody: [Int]
    /// Seconds a chord lasts at least, and as much more at most.
    let chordLength: Float
    let chordSpread: Float
    /// Seconds between bells at least, before chance adds more.
    let bellGap: Float
    /// Each bell answered this many semitones above, a breath later.
    var echo: Int?

    /// How long an answering bell waits, in seconds.
    static let echoDelay: Float = 0.6

    static let peace = Theme(chords: Score.chords, melody: Score.melody, chordLength: 9, chordSpread: 6, bellGap: 3.5)
    static let war = Theme(chords: Score.warChords, melody: Score.melody, chordLength: 7, chordSpread: 6, bellGap: 2.5)

    /// The Nullmere, the first lake: D dorian, the minor brightened by its
    /// sixth, slow and open.
    static let round = Theme(chords: [[50, 57, 60, 64], [43, 55, 59, 62], [45, 52, 55, 60], [41, 53, 57, 64]],
                             melody: [62, 64, 65, 69, 71, 74, 76, 77, 81], chordLength: 12, chordSpread: 6, bellGap: 4)
    /// The Twin Waters: A minor, every note answered a fifth above, as
    /// one water answers the other.
    static let twin = Theme(chords: [[45, 52, 57, 60], [41, 53, 57, 60], [48, 55, 60, 64], [43, 55, 59, 62]],
                            melody: [57, 60, 62, 64, 67, 69, 72, 74, 76], chordLength: 11, chordSpread: 5, bellGap: 4.5, echo: 7)
    /// The Sickle: E phrygian, its half step down to the home note sharp
    /// as the blade the land makes of the lake.
    static let crescent = Theme(chords: [[40, 52, 55, 59], [41, 53, 57, 60], [38, 50, 53, 57], [40, 52, 55, 65]],
                                melody: [64, 65, 67, 71, 72, 74, 76, 77, 79], chordLength: 10, chordSpread: 5, bellGap: 3)
    /// The Drowned Isles: F lydian, its raised fourth afloat, and long
    /// silences, as of water over roofs.
    static let isles = Theme(chords: [[41, 53, 57, 64], [43, 55, 59, 62], [40, 52, 55, 62], [45, 57, 60, 64]],
                             melody: [65, 67, 69, 71, 72, 76, 77, 79, 81], chordLength: 14, chordSpread: 8, bellGap: 5.5)

    static func of(_ mood: Score.Mood) -> Theme {
        switch mood {
        case .peace: return .peace
        case .war: return .war
        case .title(.round): return .round
        case .title(.twin): return .twin
        case .title(.crescent): return .crescent
        case .title(.isles): return .isles
        }
    }
}
