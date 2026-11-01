import Foundation
import XCTest
import NullmereCore
@testable import NullmereSound

/// The score alone, as the synthesiser plays it: which instrument sings
/// each theme's line, the answers in the other voice, the drums' march at
/// war, and the same music at any rate made again.
final class ScoreTests: XCTestCase {
    /// The score as written over `seconds`, not sounded: its chords, notes
    /// and drum strokes as they would be played.
    private func written(_ mood: Score.Mood, seconds: Float) -> Score {
        var score = Score()
        score.mood = mood
        score.compose(seconds: seconds)
        return score
    }

    private func play(_ mood: Score.Mood, seconds: Float, rate: Float = 48_000) -> (Score, left: [Float], right: [Float]) {
        var score = Score(sampleRate: rate)
        score.mood = mood
        score.target = 1
        score.level = 1
        var left: [Float] = [], right: [Float] = []
        for _ in 0..<Int(seconds * rate) {
            let heard = score.sample(dt: 1 / rate)
            left.append(heard.left)
            right.append(heard.right)
        }
        return (score, left, right)
    }

    /// At peace the harp sings the line in D minor pentatonic, wandering
    /// it, over the strings' chords as they change, now and then rolling a
    /// chord as it changes; no bell and no drum.
    func testAtPeaceTheHarpSingsOverTheStrings() {
        let score = written(.peace, seconds: 90)
        XCTAssertGreaterThanOrEqual(score.playedNotes.count, 8)
        XCTAssertTrue(score.playedNotes.allSatisfy(Score.melody.contains), "Every note in D minor pentatonic")
        XCTAssertGreaterThan(Set(score.playedNotes).count, 3, "The melody wanders")
        XCTAssertGreaterThanOrEqual(score.chordChanges, 5)
        XCTAssertEqual(score.harpPlucks - score.playedNotes.count, score.rolledNotes, "Every note the line's or a chord's rolled")
        XCTAssertGreaterThan(score.rolledNotes, 0, "A chord rolled now and then")
        XCTAssertEqual(score.bellsStruck, 0)
        XCTAssertEqual(score.drumStrokes, 0)
        // As it sounds: across both ears, and well under full.
        let (_, left, right) = play(.peace, seconds: 12)
        XCTAssertNotEqual(left, right, "Heard across both ears")
        XCTAssertFalse(left.contains { $0.isNaN || $0.isInfinite })
        XCTAssertLessThan(left.map(abs).max() ?? 1, 0.3)
    }

    /// Over the launcher each lake's title theme in its own mode and voice:
    /// every note from its own melody, the chords moving, no drum; the
    /// Drowned Isles and the Twin Waters sung by glass bells, the Twin
    /// Waters' each answered on the harp a fifth above, the rest on the harp.
    func testEachLakeSingsItsOwnTitleTheme() {
        for lake in Lake.allCases {
            let score = written(.title(lake), seconds: 90)
            let theme = Theme.of(.title(lake))
            XCTAssertGreaterThanOrEqual(score.playedNotes.count, 4, "\(lake)")
            XCTAssertTrue(score.playedNotes.allSatisfy(theme.melody.contains), "\(lake) keeps its mode")
            XCTAssertGreaterThanOrEqual(score.chordChanges, 3, "\(lake)")
            XCTAssertEqual(score.drumStrokes, 0, "No drum over the launcher")
            switch lake {
            case .isles:
                XCTAssertEqual(score.bellsStruck, score.playedNotes.count)
                XCTAssertEqual(score.harpPlucks, score.rolledNotes, "The harp only rolls the chords")
            case .twin:
                XCTAssertEqual(score.bellsStruck, score.playedNotes.count)
                XCTAssertEqual(score.harpPlucks - score.rolledNotes, score.playedNotes.count, "Every note answered on the harp")
            default:
                XCTAssertEqual(score.bellsStruck, 0, "\(lake)'s harp alone")
            }
        }
        XCTAssertEqual(Set(Lake.allCases.map { Theme.of(.title($0)).melody }).count, Lake.allCases.count, "Each lake its own")
        XCTAssertEqual(Theme.of(.title(.twin)).echo, 7)
        XCTAssertNil(Theme.of(.peace).echo)
        XCTAssertEqual(Theme.of(.peace).melody, Score.melody, "The realm's peace as it was")
        XCTAssertEqual(Theme.of(.war).chords, Score.warChords)
    }

    /// While the drowned age walks the score turns strange: glass bells far
    /// apart, each answered on the harp a tritone above, no chord rolled
    /// and no drum, every note from the scale of tones and half tones.
    func testTheEatenMoonHasItsOwnStrangeMusic() {
        let score = written(.eclipse, seconds: 60)
        let theme = Theme.of(.eclipse)
        XCTAssertGreaterThan(score.playedNotes.count, 3)
        XCTAssertTrue(score.playedNotes.allSatisfy(theme.melody.contains))
        XCTAssertEqual(score.bellsStruck, score.playedNotes.count)
        XCTAssertEqual(score.harpPlucks, score.playedNotes.count, "Each answered on the harp, no chord rolled")
        XCTAssertEqual(score.rolledNotes, 0)
        XCTAssertEqual(score.drumStrokes, 0)
        XCTAssertEqual(theme.echo, 6, "A tritone above")
        // The scale of tones and half tones: steps of one and two by turns.
        let steps = zip(theme.melody, theme.melody.dropFirst()).map { $1 - $0 }
        XCTAssertTrue(steps.allSatisfy { $0 == 1 || $0 == 2 })
    }

    /// At war two drums keep the march: four strokes a bar of eight steps,
    /// each step three tenths of a second.
    func testAtWarTheDrumsKeepTheMarch() {
        XCTAssertEqual(written(.war, seconds: 24.1).drumStrokes, 40)
        XCTAssertEqual(Score.march.filter { $0 > 0 }.count, 4)
        let (score, left, _) = play(.war, seconds: 6.1)
        XCTAssertEqual(score.drumStrokes, written(.war, seconds: 6.1).drumStrokes, "Sounded as written")
        XCTAssertEqual(score.drumStrokes, 10)
        XCTAssertLessThan(left.map(abs).max() ?? 1, 0.4)
    }

    /// Made again for another rate, it plays the same chord, in tune.
    func testItPlaysAlikeAtAnotherRate() {
        let usual = play(.peace, seconds: 1.2).left, finer = play(.peace, seconds: 1.2, rate: 96_000).left
        XCTAssertEqual(decibels(rms(finer[48_000...]) / rms(usual[24_000...])), 0, accuracy: 1.5)
        var score = Score()
        score.prepare(sampleRate: 96_000)
        XCTAssertEqual(score.sampleRate, 96_000)
        score.prepare(sampleRate: 96_000)
        score.target = 1
        score.level = 1
        let after = (0..<96_000).map { _ in score.sample(dt: 1 / 96_000).left }
        XCTAssertGreaterThan(rms(after), 0.001)
    }

    /// Silent until it is wanted, and the same music every time.
    func testItIsSilentUntilWantedAndTheSameEachTime() {
        var quiet = Score()
        XCTAssertEqual((0..<4_800).map { _ in quiet.sample(dt: 1 / 48_000).left }.map(abs).max(), 0)
        XCTAssertEqual(play(.title(.crescent), seconds: 6).left, play(.title(.crescent), seconds: 6).left)
    }
}
