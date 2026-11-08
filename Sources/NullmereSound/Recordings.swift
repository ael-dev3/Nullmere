import Foundation

/// The score's instruments as they were recorded, and the cues' horn, reed,
/// anvil, wood, gong, jingles, rattle and steel: notes of a harp, a
/// glockenspiel, cellos, violas, a double bass, a French horn and the war's
/// drums, a clarinet, an anvil's blows, a slit drum's knocks, a gong's soft
/// stroke, a tambourine's jingles, a cabasa's roll and steel struck on
/// steel, from the VS Chamber Orchestra:
/// Community Edition (VSCO-2-CE, recorded by Sam
/// Gossner and Simon Dalzell, CC0 1.0), made into the package by
/// Art/sound/make.py (see Recorded/), and read here once, the first time the
/// score needs them, before it plays.
enum Recordings {
    /// A note as Art/sound/make.py writes it: the note it was played as, the
    /// pitch it truly sounds, how many samples it has at `rate`, where its
    /// loop begins (the loop runs to its end) if it is held, and its samples
    /// in eight-bit blocks of differences, as base64.
    struct Made {
        let note: Int
        let frequency: Float
        let count: Int
        let loop: Int?
        let text: String
    }

    /// The rate every note is kept at.
    static let rate: Float = 24_000
    /// The steps a block's differences are counted in, each the last times
    /// the square root of two (3 dB), in whole numbers, as Art/sound/make.py
    /// counts them.
    static let steps: [Int32] = (0..<32).map { Int32((pow(2, Double($0) / 2)).rounded()) }
    static let block = 32

    static let harpNotes = harp.map(Recording.init)
    static let glockenspielNotes = glockenspiel.map(Recording.init)
    static let celloNotes = cellos.map(Recording.init)
    static let violaNotes = violas.map(Recording.init)
    static let bassNotes = basses.map(Recording.init)
    /// The French horn held forte, the war's calls blown on it.
    static let hornNotes = horns.map(Recording.init)
    /// The clarinet held at middle strength, a reed's calls sung on it.
    static let clarinetNotes = clarinet.map(Recording.init)
    /// The anvil struck at middle strength and hard; and a slit drum of
    /// wood struck twice alike: the forge's blows and the knocks of an
    /// order refused.
    static let anvilNotes = anvil.map(Recording.init)
    static let slitDrumNotes = slitDrum.map(Recording.init)
    /// The great drum forte and mezzo-forte, then the field drum twice.
    static let drumNotes = drums.map(Recording.init)
    /// A gong struck softly, the watch's bell over the water; a tambourine's
    /// jingles struck softly twice and once harder, coins counted out; and
    /// a cabasa rolled, salt running through an hourglass.
    static let gongNotes = gong.map(Recording.init)
    static let tambourineNotes = tambourine.map(Recording.init)
    static let cabasaNotes = cabasa.map(Recording.init)
    /// Steel struck on steel, four blows: a company's blow struck in close,
    /// and the ringing steel of a battle's din.
    static let steelNotes = steel.map(Recording.init)

    /// Every note read, so the score never reads one as it plays.
    static func load() {
        _ = (harpNotes.count, glockenspielNotes.count, celloNotes.count, violaNotes.count, bassNotes.count, hornNotes.count,
             clarinetNotes.count, anvilNotes.count, slitDrumNotes.count, drumNotes.count, gongNotes.count, tambourineNotes.count,
             cabasaNotes.count, steelNotes.count)
    }

    /// The samples a note's blocks hold, from -1 to 1: each block a byte
    /// for how its differences are foretold and the step they are counted
    /// in, then a byte for each of its 32 samples, its difference from what
    /// was foretold (nothing, the last sample, or the line through the last
    /// two) in steps. In whole numbers, so they read back exactly as they
    /// were written.
    static func decode(_ data: [UInt8], count: Int) -> [Float] {
        var out = [Float](repeating: 0, count: count)
        var h1: Int32 = 0, h2: Int32 = 0
        var at = 0, written = 0
        while at < data.count, written < count {
            let head = data[at]
            let order = head >> 5, step = steps[Int(head & 31)]
            let end = min(at + 1 + block, data.count)
            for i in (at + 1)..<end {
                let difference = Int32(Int8(bitPattern: data[i]))
                let guess: Int32 = order == 0 ? 0 : order == 1 ? h1 : 2 &* h1 &- h2
                let value = guess &+ difference &* step
                h2 = h1
                h1 = value
                if written < count { out[written] = Float(value) / 32_768 }
                written += 1
            }
            at = end
        }
        return out
    }

    /// The note of `notes` that sounds nearest a frequency, and how much
    /// faster than it was recorded it is read to sound that frequency.
    static func nearest(_ notes: [Recording], to frequency: Float) -> (index: Int, ratio: Double) {
        var best = 0, distance = Float.infinity
        for (index, note) in notes.enumerated() {
            let apart = abs(log2(frequency / note.frequency))
            if apart < distance { best = index; distance = apart }
        }
        return (best, Double(frequency / notes[best].frequency))
    }
}

/// A note recorded, read back between its samples. Kept for as long as the
/// program runs (the score's notes are read once and never let go), so a
/// voice sounding it holds it unowned, as a pointer.
final class Recording {
    let note: Int
    /// The pitch it sounds, in hertz (nothing for a drum).
    let frequency: Float
    let count: Int
    /// Where its loop begins, if it is held: the loop runs to its end.
    let loop: Int?
    /// How loud its first quarter second is (its root mean square): what a
    /// drum's softer stroke is made up by to sound as hard as it is struck.
    let heard: Float
    /// Its samples, with one silent before them and three after: the loop's
    /// first three again if it loops, so reading across the join reads what
    /// follows it.
    private let storage: UnsafeMutablePointer<Float>

    init(_ made: Recordings.Made) {
        note = made.note
        frequency = made.frequency
        count = made.count
        loop = made.loop
        let bytes = Data(base64Encoded: made.text, options: .ignoreUnknownCharacters).map { [UInt8]($0) } ?? []
        let samples = Recordings.decode(bytes, count: made.count)
        let first = samples.prefix(Int(Recordings.rate / 4))
        heard = (first.reduce(0) { $0 + $1 * $1 } / Float(max(first.count, 1))).squareRoot()
        storage = .allocate(capacity: made.count + 4)
        storage.initialize(repeating: 0, count: made.count + 4)
        for (index, sample) in samples.enumerated() { storage[index + 1] = sample }
        if let loop = made.loop {
            for i in 0..<3 { storage[made.count + 1 + i] = samples[loop + i] }
        }
    }

    deinit {
        storage.deallocate()
    }

    /// The sample at a whole index, or silence outside the note.
    func sample(_ index: Int) -> Float {
        storage[min(max(index, -1), count + 2) + 1]
    }

    /// What it sounds at a place between two samples: the curve through
    /// the four about it (Catmull and Rom's), so a note read faster or
    /// slower than it was recorded keeps its highs and adds no grit.
    @inline(__always)
    func read(_ at: Double) -> Float {
        let whole = Int(at)
        let f = Float(at - Double(whole))
        let p = storage + whole
        let a = p[0], b = p[1], c = p[2], d = p[3]
        let c1 = 0.5 * (c - a)
        let c2 = a - 2.5 * b + 2 * c - 0.5 * d
        let c3 = 0.5 * (d - a) + 1.5 * (b - c)
        return ((c3 * f + c2) * f + c1) * f + b
    }
}
