import Foundation
import XCTest
@testable import NullmereSound

/// The hall the score and the cues ring in: its echoes die away in the
/// time it is given, alike at any rate, the highs the sooner; its tail is
/// wide; it holds what it is given and never runs away; cleared, it is
/// silent.
final class HallTests: XCTestCase {
    /// The hall's answer to one click, both ears, `seconds` long.
    private func answer(rate: Float = 48_000, seconds: Float = 6) -> (left: [Float], right: [Float]) {
        let hall = Hall(sampleRate: rate)
        var left: [Float] = [], right: [Float] = []
        for i in 0..<Int(seconds * rate) {
            let heard = hall.process(left: i == 0 ? 1 : 0, right: i == 0 ? 1 : 0)
            left.append(heard.left)
            right.append(heard.right)
        }
        return (left, right)
    }

    /// Seconds for the answer's energy to fall sixty decibels, read from
    /// its fall from five decibels down to thirty-five (Schroeder's
    /// backward integral), as measured halls are.
    private func decay(_ answer: (left: [Float], right: [Float]), rate: Float) -> Float {
        var remaining: [Double] = Array(repeating: 0, count: answer.left.count)
        var sum = 0.0
        for i in stride(from: answer.left.count - 1, through: 0, by: -1) {
            sum += Double(answer.left[i] * answer.left[i] + answer.right[i] * answer.right[i])
            remaining[i] = sum
        }
        let whole = remaining[0]
        let level = remaining.map { 10 * log10(max($0 / whole, 1e-30)) }
        let from = level.firstIndex { $0 < -5 } ?? 0
        let to = level.firstIndex { $0 < -35 } ?? level.count - 1
        return Float(to - from) / rate * 2
    }

    func testItsEchoesDieInTheirTimeAtAnyRate() {
        let usual = decay(answer(), rate: 48_000)
        XCTAssertEqual(usual, Hall(sampleRate: 48_000).seconds, accuracy: 0.6, "\(usual) s")
        let finer = decay(answer(rate: 96_000), rate: 96_000)
        let coarser = decay(answer(rate: 44_100), rate: 44_100)
        XCTAssertEqual(finer, usual, accuracy: usual * 0.12, "At 96 kHz as at 48")
        XCTAssertEqual(coarser, usual, accuracy: usual * 0.12, "and at 44.1")
    }

    /// The hall gives nothing back before a sound's breath has passed,
    /// then fills, the echoes thick by the tail.
    func testItWaitsABreathThenFills() {
        let heard = answer(seconds: 1)
        let breath = Int(Hall.predelay * 48_000)
        XCTAssertEqual(heard.left[..<breath].map(abs).max() ?? 1, 0)
        XCTAssertGreaterThan(rms(heard.left[breath..<4_800]), 0)
        // Thick: most stretches of the tail a millisecond long hold an echo.
        let tail = heard.left[9_600..<24_000]
        let filled = stride(from: tail.startIndex, to: tail.endIndex - 48, by: 48).filter { start in
            tail[start..<(start + 48)].contains { abs($0) > 1e-5 }
        }
        XCTAssertGreaterThan(Float(filled.count) / Float(tail.count / 48), 0.95)
    }

    /// The two ears hear different echoes, so the tail is wide.
    func testItsTailIsWide() {
        let heard = answer(seconds: 2)
        let left = heard.left[4_800..<72_000], right = heard.right[4_800..<72_000]
        var together: Float = 0, first: Float = 0, second: Float = 0
        for (l, r) in zip(left, right) {
            together += l * r
            first += l * l
            second += r * r
        }
        XCTAssertLessThan(abs(together / (first * second).squareRoot()), 0.3)
        XCTAssertEqual(decibels(rms(left) / rms(right)), 0, accuracy: 1.5, "and alike in each")
    }

    /// The highs die sooner than the lows, so the tail darkens as it fades.
    func testItsTailDarkens() {
        let heard = answer(seconds: 2).left
        func brightness(_ part: ArraySlice<Float>) -> Float {
            var low = Lowpass(corner: 2_000, sampleRate: 48_000)
            let highs = part.map { $0 - low.process($0) }
            return rms(highs) / max(rms(part), 1e-12)
        }
        XCTAssertGreaterThan(brightness(heard[2_400..<14_400]), brightness(heard[48_000..<72_000]) * 1.3)
    }

    /// Given noise without end, it holds about what it is given, never more
    /// and more; cleared, it is silent at once.
    func testItHoldsWhatItIsGivenAndIsClearedToSilence() {
        let hall = Hall(sampleRate: 48_000)
        var noise = Noise(seed: 7)
        var given: [Float] = [], heard: [Float] = []
        for _ in 0..<(48_000 * 12) {
            let x = noise.next() * 0.5
            given.append(x)
            heard.append(hall.process(left: x, right: x).left)
        }
        XCTAssertFalse(heard.contains { $0.isNaN || $0.isInfinite })
        let late = rms(heard[(48_000 * 8)...]), early = rms(heard[(48_000 * 4)..<(48_000 * 8)])
        XCTAssertEqual(decibels(late / early), 0, accuracy: 1, "Steady, not growing")
        XCTAssertEqual(decibels(late / rms(given)), 0, accuracy: 6, "About what it is given")
        hall.clear()
        XCTAssertEqual((0..<4_800).map { _ in hall.process(left: 0, right: 0).left }.map(abs).max(), 0)
    }
}
