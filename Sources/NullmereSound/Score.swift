import Foundation
import NullmereCore

/// The game's music: an original score written as it plays, by real
/// instruments, recorded (Recordings), and heard in the synthesiser's hall.
/// Cellos and violas bow slow chords in D minor over a double bass; a
/// harp's sparse line wanders the minor pentatonic above them, and as the
/// chord changes the harp may roll the new one softly up; at war a great
/// drum and a field drum keep a slow march, the chords darken, and French
/// horns call over them as war begins and now and then as the chord
/// changes. Over the launcher, the title theme of the lake the keeper's
/// realm last lay on, each lake in its own mode and its own voice, harp or
/// glockenspiel. It renders on the audio thread inside `Synth`, from its own
/// seeded generator, so the same seed always plays the same music.
public struct Score {
    public enum Mood: Equatable, Sendable {
        case peace
        case war
        /// The moon eaten, and the drowned age walking.
        case eclipse
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

    /// How loud each part sounds in the score: the bowed chords, the harp,
    /// the bells and the drums.
    static let bowing: Float = 0.036
    static let plucking: Float = 0.25
    static let ringing: Float = 0.05
    static let drumming: Float = 0.11
    /// How loud the horns sound in the score.
    static let calling: Float = 0.09
    /// How likely the horns call as the chord changes at war: always as
    /// war begins.
    static let callChance: Float = 0.6
    /// The horns' call over a chord: its root, then its fifth, then its
    /// octave, rising, the last held long; each note's step above the
    /// root, when it is blown, how long it is held and how hard, in seconds.
    static let call: [(step: Int, at: Float, hold: Float, strength: Float)] = [
        (0, 0, 0.3, 0.8), (7, 0.42, 0.3, 0.85), (12, 0.84, 1.5, 1),
    ]
    /// The lowest note a call begins on: the chord's root is taken up by
    /// octaves to it, so every call lies where the horns were recorded.
    static let callFloor = 43
    /// The march the drums keep at war: eight steps a bar, each struck this
    /// hard (nothing is no stroke), the bar's first and middle on the low
    /// drum, the rest on the high.
    static let march: [Float] = [1, 0, 0, 0.35, 0.7, 0, 0.3, 0]
    /// Seconds a step of the march lasts.
    static let step: Float = 0.3

    var mood: Mood = .peace
    /// How loud the music is, 0...1, eased toward `target`.
    var level: Float = 0
    var target: Float = 0

    private var seed: UInt32
    private(set) var sampleRate: Float
    private var current: [Bowed] = []
    private var previous: [Bowed] = []
    private var crossfade: Float = 1
    private var chordClock: Float = 0
    private var chordLength: Float = 10
    private var bellClock: Float = 2
    private var lastNote = 69
    private var harp: Harp
    private var bells: Glockenspiel
    private var lowDrum: Drum
    private var highDrum: Drum
    private var horns: Horns
    private var drumClock: Float = 0
    private var drumStep = 0
    /// The mood the score last played in, so it knows when war begins.
    private var heardMood: Mood = .peace

    /// What has been played, for tests: the melody's MIDI notes in order,
    /// chord changes, and drum strokes.
    private(set) var playedNotes: [Int] = []
    private(set) var chordChanges = 0
    private(set) var drumStrokes = 0
    /// The horns' calls, and the notes blown in them, for tests.
    private(set) var hornCalls = 0
    private(set) var calledNotes: [Int] = []

    init(seed: UInt32 = 0x0D15_EA5E, sampleRate: Float = 48_000) {
        self.seed = seed
        self.sampleRate = sampleRate
        // Every recorded note read now, so none is read as the score plays.
        Recordings.load()
        harp = Harp(sampleRate: sampleRate)
        bells = Glockenspiel(sampleRate: sampleRate)
        lowDrum = Drum(.great, sampleRate: sampleRate)
        highDrum = Drum(.field, sampleRate: sampleRate)
        horns = Horns(sampleRate: sampleRate)
        // Room enough up front that the audio thread never has to find more.
        current.reserveCapacity(6)
        previous.reserveCapacity(6)
        playedNotes.reserveCapacity(4096)
        calledNotes.reserveCapacity(4096)
        bow(Score.chords[0], as: Theme.peace)
    }

    /// The instruments made again for the audio engine's rate, the chord
    /// sounding bowed afresh: called with the engine stopped.
    mutating func prepare(sampleRate: Float) {
        guard sampleRate != self.sampleRate else { return }
        self.sampleRate = sampleRate
        harp = Harp(sampleRate: sampleRate)
        bells = Glockenspiel(sampleRate: sampleRate)
        lowDrum = Drum(.great, sampleRate: sampleRate)
        highDrum = Drum(.field, sampleRate: sampleRate)
        horns = Horns(sampleRate: sampleRate)
        current = current.map { Bowed(frequency: $0.frequency, corner: $0.corner, sampleRate: sampleRate, bass: $0.bass) }
        previous.removeAll(keepingCapacity: true)
        crossfade = 1
    }

    /// How many strings the harp has plucked, how many of them rolled a
    /// chord, and how many bells have been struck, for tests.
    var harpPlucks: Int { harp.plucks }
    private(set) var rolledNotes = 0
    var bellsStruck: Int { bells.struck }

    private mutating func random() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed >> 8) / Float(1 << 24)
    }

    /// The strings take up a chord: each of its notes, and under a chord
    /// with no low note of its own, the bass on its root an octave down.
    private mutating func bow(_ chord: [Int], as theme: Theme) {
        current.removeAll(keepingCapacity: true)
        for note in chord {
            current.append(Bowed(frequency: Score.frequency(note), corner: theme.corner, sampleRate: sampleRate))
        }
        if let root = chord.first, root >= 45 {
            current.append(Bowed(frequency: Score.frequency(root - 12), corner: theme.corner * 0.4, sampleRate: sampleRate, bass: true))
        }
    }

    private mutating func nextChord(calling: Bool = false) {
        let theme = Theme.of(mood)
        let pool = theme.chords
        let chord = pool[Int(random() * Float(pool.count)) % pool.count]
        // The chord sounding becomes the one fading, as it was, phases and
        // all; the new one is written into the room the old fading one
        // leaves, so nothing is allocated on the audio thread.
        swap(&previous, &current)
        bow(chord, as: theme)
        crossfade = 0
        chordLength = theme.chordLength + random() * theme.chordSpread
        chordChanges += 1
        // Now and then the harp rolls the new chord softly up, an octave
        // above the strings, from the left ear to the right.
        if random() < theme.roll {
            for (index, note) in chord.enumerated() {
                harp.pluck(Score.frequency(note + 12), strength: 0.2 + 0.05 * Float(index), brightness: 0.35,
                           pan: -0.5 + 0.3 * Float(index), wait: 0.3 + 0.12 * Float(index))
                rolledNotes += 1
            }
        }
        // At war the horns call over the new chord, now and then.
        if mood == .war, calling || random() < Score.callChance {
            call(chord)
        }
    }

    /// The horns' call over a chord, from left of the middle, where the
    /// brass sit: its root taken up to where the horns were recorded.
    private mutating func call(_ chord: [Int]) {
        guard var root = chord.first else { return }
        while root < Score.callFloor { root += 12 }
        for (index, note) in Score.call.enumerated() {
            horns.blow(Score.frequency(root + note.step), strength: note.strength, hold: note.hold,
                       pan: -0.35 + 0.1 * Float(index), wait: note.at)
            if calledNotes.count < 4096 { calledNotes.append(root + note.step) }
        }
        hornCalls += 1
    }

    private mutating func nextBell() {
        // A small step from the last note, now and then a leap.
        let theme = Theme.of(mood)
        let melody = theme.melody
        let index = melody.firstIndex(of: lastNote) ?? 3
        let step = random() < 0.8 ? Int(random() * 5) - 2 : Int(random() * 9) - 4
        let next = melody[min(max(index + step, 0), melody.count - 1)]
        lastNote = next
        // The high notes lean right, the low left, as a harp's strings run.
        let pan = Float(next - 69) / 24
        let strength = 0.55 + 0.3 * random()
        switch theme.voice {
        case .harp: harp.pluck(Score.frequency(next), strength: strength, brightness: theme.brightness, pan: pan)
        case .bells: bells.strike(Score.frequency(next), strength: strength + 0.15, pan: pan)
        }
        // A theme that answers itself: the same note again, higher, a
        // breath later, as one water answers the other, in the other voice.
        if let echo = theme.echo {
            let answer = Score.frequency(next + echo)
            switch theme.voice {
            case .harp: bells.strike(answer, strength: 0.6, pan: -pan, wait: Theme.echoDelay)
            case .bells: harp.pluck(answer, strength: 0.45, brightness: theme.brightness, pan: -pan, wait: Theme.echoDelay)
            }
        }
        if playedNotes.count < 4096 { playedNotes.append(next) }
        // Silence matters as much as the notes.
        bellClock = theme.bellGap + random() * 5
        if random() < 0.25 { bellClock += 6 }
    }

    /// The score's own clock, moved on by `dt`: the chords changing, the
    /// line's next note sounding, and at war the drums' march struck. Every
    /// sample is drawn from it, and tests may run it alone.
    private mutating func advance(dt: Float) {
        if mood != heardMood {
            heardMood = mood
            if mood == .war {
                // War begun: the chords turn to war's at once, and the
                // horns call it.
                chordClock = 0
                nextChord(calling: true)
            }
        }
        chordClock += dt
        if chordClock >= chordLength {
            chordClock = 0
            nextChord()
        }
        crossfade = min(1, crossfade + dt / 4)
        bellClock -= dt
        if bellClock <= 0 { nextBell() }
        if mood == .war {
            drumClock += dt
            if drumClock >= Score.step {
                drumClock -= Score.step
                let strength = Score.march[drumStep]
                if strength > 0 {
                    if drumStep % 4 == 0 { lowDrum.strike(strength) } else { highDrum.strike(strength) }
                    drumStrokes += 1
                }
                drumStep = (drumStep + 1) % Score.march.count
            }
        }
    }

    /// For tests: the score as written over `seconds`, sample by sample at
    /// its rate, as it would be played but not sounded.
    mutating func compose(seconds: Float) {
        let dt = 1 / sampleRate
        for _ in 0..<Int(seconds * sampleRate) { advance(dt: dt) }
    }

    /// One sample of music in each ear, before the master level.
    mutating func sample(dt: Float) -> (left: Float, right: Float) {
        level += (target - level) * dt / 3
        guard level > 0.0005 else { return (0, 0) }
        advance(dt: dt)

        // The strings. The chord fading out sounds just as it did while it
        // was the chord, so the change is a crossfade and never a step.
        var left: Float = 0, right: Float = 0
        for i in current.indices {
            let bowed = current[i].sample(dt: dt)
            left += bowed.left * crossfade
            right += bowed.right * crossfade
        }
        if crossfade < 1 {
            for i in previous.indices {
                let bowed = previous[i].sample(dt: dt)
                left += bowed.left * (1 - crossfade)
                right += bowed.right * (1 - crossfade)
            }
        }
        let breath = (0.75 + 0.25 * sin(chordClock / chordLength * .pi)) * Score.bowing
        left *= breath
        right *= breath

        // The harp and the bells.
        let plucked = harp.sample(dt: dt)
        let rung = bells.sample(dt: dt)
        left += plucked.left * Score.plucking + rung.left * Score.ringing
        right += plucked.right * Score.plucking + rung.right * Score.ringing

        // At war, the horns' calls; what was blown falls away after.
        let blown = horns.sample(dt: dt)
        left += blown.left * Score.calling
        right += blown.right * Score.calling

        // At war, the drums' slow march; what was struck rings out after.
        if lowDrum.isSounding || highDrum.isSounding {
            let drums = (lowDrum.sample(dt: dt) + highDrum.sample(dt: dt) * 0.8) * Score.drumming
            left += drums
            right += drums
        }
        return (left * level, right * level)
    }
}

/// What a mood plays: its chords and how long each lasts, its melody's
/// notes and the silence between them, the voice that sings them, whether
/// each note is answered, how bright the strings sound, and how often the
/// harp rolls a new chord. The realm's peace and war, the eaten moon, and a
/// title theme for each lake, each lake in a mode of its own.
struct Theme {
    enum Voice {
        case harp, bells
    }

    let chords: [[Int]]
    let melody: [Int]
    /// Seconds a chord lasts at least, and as much more at most.
    let chordLength: Float
    let chordSpread: Float
    /// Seconds between notes at least, before chance adds more.
    let bellGap: Float
    /// Each note answered this many semitones above, a breath later.
    var echo: Int?
    var voice: Voice = .harp
    /// The strings' brightness: the corner, in hertz, of their bodies.
    var corner: Float = 1_500
    /// How bright the harp's strings are plucked, 0...1.
    var brightness: Float = 0.45
    /// How likely a new chord is rolled on the harp.
    var roll: Float = 0.5

    /// How long an answering note waits, in seconds.
    static let echoDelay: Float = 0.6

    static let peace = Theme(chords: Score.chords, melody: Score.melody, chordLength: 9, chordSpread: 6, bellGap: 3.5)
    /// War: darker strings, the harp plucked harder and duller, seldom rolled.
    static let war = Theme(chords: Score.warChords, melody: Score.melody, chordLength: 7, chordSpread: 6, bellGap: 2.5,
                           corner: 900, brightness: 0.3, roll: 0.25)

    /// The eaten moon, while the drowned age walks: chords of stacked minor
    /// thirds and tritones, low and slow; a line from the scale of tones
    /// and half tones that never settles, on the glockenspiel far apart, each
    /// answered on the harp a tritone above; the strings dark, and no
    /// chord rolled.
    static let eclipse = Theme(chords: [[38, 44, 50, 53], [37, 43, 49, 52], [40, 46, 49, 55], [36, 42, 48, 51]],
                               melody: [62, 64, 65, 67, 68, 70, 71, 73, 74], chordLength: 15, chordSpread: 8, bellGap: 6, echo: 6,
                               voice: .bells, corner: 850, roll: 0)

    /// The Nullmere, the first lake: D dorian, the minor brightened by its
    /// sixth, slow and open.
    static let round = Theme(chords: [[50, 57, 60, 64], [43, 55, 59, 62], [45, 52, 55, 60], [41, 53, 57, 64]],
                             melody: [62, 64, 65, 69, 71, 74, 76, 77, 81], chordLength: 12, chordSpread: 6, bellGap: 4,
                             corner: 1_700, roll: 0.6)
    /// The Twin Waters: A minor, sung by the glockenspiel, every note answered
    /// on the harp a fifth above, as one water answers the other.
    static let twin = Theme(chords: [[45, 52, 57, 60], [41, 53, 57, 60], [48, 55, 60, 64], [43, 55, 59, 62]],
                            melody: [57, 60, 62, 64, 67, 69, 72, 74, 76], chordLength: 11, chordSpread: 5, bellGap: 4.5, echo: 7,
                            voice: .bells, corner: 1_600)
    /// The Sickle: E phrygian, its half step down to the home note sharp
    /// as the blade the land makes of the lake.
    static let crescent = Theme(chords: [[40, 52, 55, 59], [41, 53, 57, 60], [38, 50, 53, 57], [40, 52, 55, 65]],
                                melody: [64, 65, 67, 71, 72, 74, 76, 77, 79], chordLength: 10, chordSpread: 5, bellGap: 3,
                                corner: 1_300, brightness: 0.6)
    /// The Drowned Isles: F lydian, its raised fourth afloat, sung by the
    /// glockenspiel, and long silences, as of water over roofs.
    static let isles = Theme(chords: [[41, 53, 57, 64], [43, 55, 59, 62], [40, 52, 55, 62], [45, 57, 60, 64]],
                             melody: [65, 67, 69, 71, 72, 76, 77, 79, 81], chordLength: 14, chordSpread: 8, bellGap: 5.5,
                             voice: .bells, corner: 1_400, roll: 0.3)

    /// The Marches: G mixolydian, a major mode with its seventh lowered,
    /// bright and martial, its chords stepping down a tone and back as
    /// companies march, quicker than any lake's, the harp bright and often rolled.
    static let marches = Theme(chords: [[43, 55, 59, 62], [41, 53, 57, 60], [36, 48, 55, 64], [38, 50, 57, 65]],
                               melody: [62, 65, 67, 69, 71, 72, 74, 77, 79], chordLength: 9, chordSpread: 4, bellGap: 3.5,
                               corner: 1_800, brightness: 0.6, roll: 0.7)

    static func of(_ mood: Score.Mood) -> Theme {
        switch mood {
        case .peace: return .peace
        case .war: return .war
        case .eclipse: return .eclipse
        case .title(.round): return .round
        case .title(.twin): return .twin
        case .title(.crescent): return .crescent
        case .title(.isles): return .isles
        case .title(.marches): return .marches
        }
    }
}
