import Foundation
import XCTest
import NullmereCore
@testable import NullmereSound

/// The score alone, as the synthesiser plays it: which instrument sings
/// each theme's line, the answers in the other voice, the drums' march at
/// war, and the same music at any rate made again.
final class ScoreTests: XCTestCase {
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

    /// At peace the harp sings the line, over the strings' chords, now and
    /// then rolling a chord as it changes; no bell and no drum.
    func testAtPeaceTheHarpSingsOverTheStrings() {
        let (score, left, right) = play(.peace, seconds: 60)
        XCTAssertGreaterThan(score.playedNotes.count, 5)
        XCTAssertEqual(score.harpPlucks - score.playedNotes.count, score.rolledNotes, "Every note the line's or a chord's rolled")
        XCTAssertGreaterThan(score.rolledNotes, 0, "A chord rolled now and then")
        XCTAssertEqual(score.bellsStruck, 0)
        XCTAssertEqual(score.drumStrokes, 0)
        XCTAssertNotEqual(left, right, "Heard across both ears")
        XCTAssertFalse(left.contains { $0.isNaN || $0.isInfinite })
        XCTAssertLessThan(left.map(abs).max() ?? 1, 0.3)
    }

    /// Over the Drowned Isles glass bells sing it; over the Twin Waters too,
    /// each note answered on the harp a fifth above.
    func testTheLakesSingInTheirOwnVoices() {
        let isles = play(.title(.isles), seconds: 60).0
        XCTAssertEqual(isles.bellsStruck, isles.playedNotes.count)
        XCTAssertEqual(isles.harpPlucks, isles.rolledNotes, "The harp only rolls the chords")
        let twin = play(.title(.twin), seconds: 60).0
        XCTAssertEqual(twin.bellsStruck, twin.playedNotes.count)
        XCTAssertEqual(twin.harpPlucks - twin.rolledNotes, twin.playedNotes.count, "Every note answered on the harp")
        let marches = play(.title(.marches), seconds: 60).0
        XCTAssertEqual(marches.bellsStruck, 0, "The Marches' harp alone")
    }

    /// While the drowned age walks the score turns strange: glass bells far
    /// apart, each answered on the harp a tritone above, no chord rolled
    /// and no drum, every note from the scale of tones and half tones.
    func testTheEatenMoonHasItsOwnStrangeMusic() {
        let (score, _, _) = play(.eclipse, seconds: 60)
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
        let (score, left, _) = play(.war, seconds: 24.1)
        XCTAssertEqual(score.drumStrokes, 40)
        XCTAssertEqual(Score.march.filter { $0 > 0 }.count, 4)
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
        XCTAssertEqual(play(.title(.crescent), seconds: 15).left, play(.title(.crescent), seconds: 15).left)
    }
}
