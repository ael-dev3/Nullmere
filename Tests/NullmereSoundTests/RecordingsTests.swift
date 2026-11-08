import Foundation
import XCTest
@testable import NullmereSound

/// The recorded notes the score's instruments sound: read back as they
/// were written, each sounding the pitch it says it does, begun from
/// silence, the struck and plucked ones dying to silence and the bowed
/// ones looping where they say.
final class RecordingsTests: XCTestCase {
    private let sets: [(String, [Recording])] = [("harp", Recordings.harpNotes), ("glockenspiel", Recordings.glockenspielNotes),
                                                 ("cellos", Recordings.celloNotes), ("violas", Recordings.violaNotes),
                                                 ("basses", Recordings.bassNotes), ("horns", Recordings.hornNotes),
                                                 ("clarinet", Recordings.clarinetNotes),
                                                 ("anvil", Recordings.anvilNotes), ("slit drum", Recordings.slitDrumNotes),
                                                 ("drums", Recordings.drumNotes)]
    /// The sets struck with no pitch to sound.
    private let unpitched: Set = ["drums", "anvil", "slit drum"]
    /// The sets held round a loop for as long as they sound.
    private let held: Set = ["cellos", "violas", "basses", "horns", "clarinet"]

    /// Blocks read back exactly: foretold from nothing, from the last
    /// sample, and from the line through the last two, each counted in its
    /// step, from one block into the next, the last block's spare samples
    /// left unread.
    func testBlocksReadBackAsTheyWereWritten() {
        XCTAssertEqual(Recordings.steps.prefix(8), [1, 1, 2, 3, 4, 6, 8, 11])
        XCTAssertEqual(Recordings.steps.last, 46_341)
        func block(_ order: UInt8, _ step: UInt8, _ differences: [Int8]) -> [UInt8] {
            [order << 5 | step] + (differences + [Int8](repeating: 0, count: 32 - differences.count)).map { UInt8(bitPattern: $0) }
        }
        // Nothing foretold, in steps of 4: the differences are the samples.
        let plain = Recordings.decode(block(0, 4, [10, -20, 127, -127]), count: 4)
        XCTAssertEqual(plain, [40, -80, 508, -508].map { Float($0) / 32_768 })
        // The last sample foretold, in steps of 2: the differences add up.
        let step = Recordings.decode(block(1, 2, [5, 5, -3]), count: 3)
        XCTAssertEqual(step, [10, 20, 14].map { Float($0) / 32_768 })
        // The line through the last two: a ramp needs nothing past its start.
        let line = Recordings.decode(block(2, 0, [3, 0, 0, 0]), count: 4)
        XCTAssertEqual(line, [3, 6, 9, 12].map { Float($0) / 32_768 })
        // What a block ends on is foretold into the next, and only as many
        // samples as there are are read.
        let two = Recordings.decode(block(1, 0, [7]) + block(1, 0, [1, 1]), count: 34)
        XCTAssertEqual(two.count, 34)
        XCTAssertEqual(two[31], 7 / 32_768)
        XCTAssertEqual(two[32], 8 / 32_768)
        XCTAssertEqual(two[33], 9 / 32_768)
        XCTAssertEqual(Recordings.decode([], count: 2), [0, 0])
    }

    /// Every note read back whole: as many samples as written, within full
    /// scale, nothing amiss, begun from silence; a note let go dies to
    /// silence, and a held one loops over a stretch of its sustain long
    /// enough not to be heard turning.
    func testEveryNoteIsReadBackWhole() {
        for (name, notes) in sets {
            XCTAssertFalse(notes.isEmpty, name)
            for note in notes {
                let samples = (0..<note.count).map(note.sample)
                XCTAssertEqual(samples.count, note.count)
                XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 }, "\(name) \(note.note)")
                XCTAssertGreaterThan(rms(samples[...]), 0.005, "\(name) \(note.note) is heard")
                XCTAssertLessThan(abs(samples[0]), 0.001, "\(name) \(note.note) begins from silence")
                XCTAssertGreaterThan(note.heard, 0)
                XCTAssertEqual(note.sample(-1), 0)
                if let loop = note.loop {
                    XCTAssertTrue(held.contains(name), name)
                    XCTAssertGreaterThan(loop, Int(0.3 * Recordings.rate), "\(name) \(note.note) loops after the bow sets")
                    XCTAssertGreaterThan(Float(note.count - loop), 2.3 * Recordings.rate, "\(name) \(note.note) loops long")
                    // Across the join the loop's start follows its end.
                    XCTAssertEqual(note.sample(note.count), note.sample(loop))
                    XCTAssertEqual(note.sample(note.count + 1), note.sample(loop + 1))
                } else {
                    XCTAssertFalse(held.contains(name), name)
                    let tail = samples.suffix(Int(Recordings.rate / 100))
                    XCTAssertLessThan(tail.map(abs).max() ?? 1, 0.002, "\(name) \(note.note) dies to silence")
                    XCTAssertEqual(note.sample(note.count), 0)
                }
            }
        }
    }

    /// Each note sounds the pitch it says it does, a few cents from the
    /// note it was played as, and the notes of each set rise in order.
    func testEveryNoteSoundsItsPitch() {
        for (name, notes) in sets where !unpitched.contains(name) {
            var last: Float = 0
            for note in notes {
                XCTAssertGreaterThan(note.frequency, last, "\(name) in order")
                last = note.frequency
                let named = Score.frequency(note.note)
                XCTAssertEqual(cents(note.frequency, from: named), 0, accuracy: 40, "\(name) \(note.note) as it was played")
                // A plucked or struck note by its strongest frequency over
                // its first second; a held one through its players' vibrato,
                // stretch by stretch of its loop, the middle of what is heard.
                let heard: Float
                if let loop = note.loop {
                    let frame = Int(Recordings.rate / note.frequency * 8)
                    let samples = (0..<note.count).map(note.sample)
                    let stretches = stride(from: loop, to: note.count - 2 * frame, by: frame).map {
                        cents(pitch(of: samples[$0..<($0 + frame)], rate: Recordings.rate, near: note.frequency), from: note.frequency)
                    }
                    heard = note.frequency * pow(2, stretches.sorted()[stretches.count / 2] / 1_200)
                } else {
                    let start = Int(0.05 * Recordings.rate), length = min(Int(Recordings.rate), note.count - start)
                    heard = peak(of: (start..<(start + length)).map(note.sample)[...], near: note.frequency, rate: Recordings.rate, by: 1)
                }
                XCTAssertEqual(cents(heard, from: note.frequency), 0, accuracy: name == "harp" || name == "glockenspiel" ? 4 : 12,
                               "\(name) \(note.note)")
            }
        }
    }

    /// The note nearest a frequency is found, and how much faster it is
    /// read to sound it.
    func testTheNearestNoteIsRead() {
        let harp = Recordings.harpNotes
        let a = Recordings.nearest(harp, to: 440)
        XCTAssertEqual(harp[a.index].note, 69)
        XCTAssertEqual(Float(a.ratio) * harp[a.index].frequency, 440, accuracy: 0.001)
        XCTAssertEqual(harp[Recordings.nearest(harp, to: 20).index].note, 48, "Below them all, the lowest")
        XCTAssertEqual(harp[Recordings.nearest(harp, to: 9_000).index].note, 83, "Above them all, the highest")
        // Every note the score's harp plays lies within two semitones of a
        // string that was recorded.
        for midi in 48...85 {
            let nearest = Recordings.nearest(harp, to: Score.frequency(midi))
            XCTAssertLessThan(abs(12 * log2(nearest.ratio)), 2.6, "Note \(midi)")
        }
    }
}
