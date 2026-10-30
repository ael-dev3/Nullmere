import Foundation

/// The game's music: an original score written as it plays. Slow chords in
/// D minor drift beneath a sparse line of bell-like notes from the minor
/// pentatonic; at war a low, distant drum keeps time and the chords darken.
/// It renders on the audio thread inside `Synth`, from its own seeded
/// generator, so the same seed always plays the same music.
struct Score {
    enum Mood: Equatable {
        case peace
        case war
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
        let pool = mood == .war ? Score.warChords : Score.chords
        let chord = pool[Int(random() * Float(pool.count)) % pool.count]
        // The chord sounding becomes the one fading, as it was, phases and
        // all; the new one is written into the room the old fading one
        // leaves, so nothing is allocated on the audio thread.
        swap(&previous, &current)
        current.removeAll(keepingCapacity: true)
        for note in chord { current.append(Voice(frequency: Score.frequency(note))) }
        crossfade = 0
        chordLength = (mood == .war ? 7 : 9) + random() * 6
        chordChanges += 1
    }

    private mutating func nextBell() {
        // A small step from the last note, now and then a leap.
        let index = Score.melody.firstIndex(of: lastNote) ?? 3
        let step = random() < 0.8 ? Int(random() * 5) - 2 : Int(random() * 9) - 4
        let next = Score.melody[min(max(index + step, 0), Score.melody.count - 1)]
        lastNote = next
        bells.append(Bell(frequency: Score.frequency(next)))
        if playedNotes.count < 4096 { playedNotes.append(next) }
        // Silence matters as much as the notes.
        bellClock = (mood == .war ? 2.5 : 3.5) + random() * 5
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
            let envelope = min(b.age * 25, 1) * exp(-b.age * 0.55)
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
