import Foundation
import XCTest
@testable import NullmereSound

/// The pitch of a steady, pitched sound near `near` hertz, by where it best
/// matches itself a period later, the lag found to a fraction of a sample.
func pitch(of x: ArraySlice<Float>, rate: Float, near: Float) -> Float {
    let samples = Array(x)
    let shortest = Int(rate / (near * 1.08)), longest = Int(rate / (near / 1.08)) + 1
    func match(_ lag: Int) -> Float {
        var together: Float = 0, first: Float = 0, second: Float = 0
        for i in 0..<(samples.count - lag) {
            together += samples[i] * samples[i + lag]
            first += samples[i] * samples[i]
            second += samples[i + lag] * samples[i + lag]
        }
        return together / max((first * second).squareRoot(), 1e-12)
    }
    let matches = (shortest...longest).map(match)
    let best = matches.indices.max { matches[$0] < matches[$1] }!
    var lag = Float(shortest + best)
    if best > 0 && best < matches.count - 1 {
        let a = matches[best - 1], b = matches[best], c = matches[best + 1]
        lag += 0.5 * (a - c) / (a - 2 * b + c)
    }
    return rate / lag
}

/// How far one frequency lies from another, in cents.
func cents(_ heard: Float, from wanted: Float) -> Float { 1_200 * log2(heard / wanted) }

/// How strongly a sound holds one frequency (Goertzel's single bin).
func strength(of x: ArraySlice<Float>, at frequency: Float, rate: Float) -> Float {
    let w = 2 * Float.pi * frequency / rate
    let k = 2 * cos(w)
    var a: Float = 0, b: Float = 0
    for value in x {
        let next = value + k * a - b
        b = a
        a = next
    }
    return (a * a + b * b - k * a * b).squareRoot() / Float(x.count)
}

/// The frequency near `near` a sound holds most strongly, to a fraction of
/// a cent: for a struck bar, whose overtones lie far from any harmonic, the
/// pitch it is heard at.
func peak(of x: ArraySlice<Float>, near: Float, rate: Float, by step: Float = 0.5) -> Float {
    let cents = Array(stride(from: Float(-60), through: 60, by: step))
    let held = cents.map { strength(of: x, at: near * pow(2, $0 / 1_200), rate: rate) }
    let best = held.indices.max { held[$0] < held[$1] }!
    var at = cents[best]
    if best > 0 && best < held.count - 1 {
        let a = log(held[best - 1]), b = log(held[best]), c = log(held[best + 1])
        at += step * 0.5 * (a - c) / (a - 2 * b + c)
    }
    return near * pow(2, at / 1_200)
}

/// Seconds a sound takes to fall sixty decibels, from its envelope in
/// twentieths of a second: from ten decibels below its loudest to forty
/// below, taken twice.
func ringing(_ x: [Float], rate: Float) -> Float {
    let window = Int(rate / 20)
    let levels = stride(from: 0, to: x.count - window, by: window).map { decibels(rms(x[$0..<($0 + window)])) }
    guard let loudest = levels.max(), let top = levels.firstIndex(of: loudest) else { return 0 }
    let from = levels[top...].firstIndex { $0 < loudest - 10 } ?? top
    let to = levels[from...].firstIndex { $0 < loudest - 40 } ?? levels.count - 1
    return Float(to - from) / 20 * 2
}

/// The instruments the score plays, each alone: in tune at any sample
/// rate, ringing as their kind rings, held as long as they are bowed, and
/// quiet when done.
final class InstrumentTests: XCTestCase {
    private func harp(_ frequency: Float, rate: Float = 48_000, seconds: Float = 1.5, strength: Float = 0.8) -> [Float] {
        let harp = Harp(sampleRate: rate)
        harp.pluck(frequency, strength: strength)
        return (0..<Int(seconds * rate)).map { _ in harp.sample(dt: 1 / rate).left }
    }

    /// Every string in tune, low and high, at every rate the Mac runs at,
    /// whichever recorded string sounds it.
    func testTheHarpIsInTune() {
        for rate: Float in [44_100, 48_000, 96_000] {
            for frequency: Float in [130.81, 220, 293.66, 440, 698.46, 987.77] {
                let sound = harp(frequency, rate: rate, seconds: 0.6)
                let heard = pitch(of: sound[Int(0.15 * rate)..<Int(0.4 * rate)], rate: rate, near: frequency)
                XCTAssertEqual(cents(heard, from: frequency), 0, accuracy: 5, "\(frequency) Hz at \(rate)")
            }
        }
    }

    /// The low strings ring longest, and a string done is let go.
    func testTheLowStringsRingLongest() {
        let low = ringing(harp(130.81, seconds: 7), rate: 48_000)
        let high = ringing(harp(987.77, seconds: 7), rate: 48_000)
        XCTAssertGreaterThan(low, high * 1.5, "\(low) s against \(high) s")

        let harp = Harp(sampleRate: 48_000)
        harp.pluck(440, strength: 0.5)
        XCTAssertEqual(harp.sounding, 1)
        for _ in 0..<(48_000 * 7) { _ = harp.sample(dt: 1 / 48_000) }
        XCTAssertEqual(harp.sounding, 0, "Let go once it has rung out")
        harp.pluck(440, strength: 0.5)
        harp.clear()
        XCTAssertEqual(harp.sounding, 0)
    }

    /// A pluck leaves nothing but its note: it begins without a click, no
    /// offset rings on, harder is louder, and a duller pluck keeps less of
    /// the string's highs.
    func testAPluckIsANoteAndNothingElse() {
        let sound = harp(330, seconds: 2)
        XCTAssertLessThan(abs(sound[0]), 0.01, "Begun from silence")
        let steps = zip(sound, sound.dropFirst()).map { abs($1 - $0) }
        XCTAssertLessThan(steps.max() ?? 1, 0.25, "No click anywhere")
        let mean = sound.reduce(0, +) / Float(sound.count)
        XCTAssertLessThan(abs(mean), 0.001)
        let soft = rms(harp(330, strength: 0.3)), hard = rms(harp(330, strength: 0.9))
        XCTAssertEqual(hard / soft, 3, accuracy: 0.6)
        XCTAssertFalse(sound.contains { $0.isNaN || $0.isInfinite })
        XCTAssertLessThan(Harp.corner(brightness: 0.3, strength: 0.5), Harp.corner(brightness: 0.45, strength: 0.5))
        XCTAssertLessThan(Harp.corner(brightness: 0.45, strength: 0.3), Harp.corner(brightness: 0.45, strength: 0.9))
        func highs(_ brightness: Float) -> Float {
            let harp = Harp(sampleRate: 48_000)
            harp.pluck(440, strength: 0.8, brightness: brightness)
            let sound = (0..<24_000).map { _ in harp.sample(dt: 1 / 48_000).left }
            return strength(of: sound[...], at: 440 * 5, rate: 48_000) / strength(of: sound[...], at: 440, rate: 48_000)
        }
        XCTAssertLessThan(highs(0.3), highs(0.6), "The duller pluck the duller note")
    }

    /// A chord rolled waits its turn: each string sounds only when its wait is done.
    func testAStringWaitsItsTurn() {
        let harp = Harp(sampleRate: 48_000)
        harp.pluck(440, strength: 0.8, wait: 0.25)
        let before = (0..<Int(0.24 * 48_000)).map { _ in harp.sample(dt: 1 / 48_000).left }
        let after = (0..<Int(0.1 * 48_000)).map { _ in harp.sample(dt: 1 / 48_000).left }
        XCTAssertEqual(rms(before), 0)
        XCTAssertGreaterThan(rms(after), 0.01)
    }

    /// The tenth string plucked at once takes the place of the one nearest its end.
    func testTheHarpHasTenStrings() {
        let harp = Harp(sampleRate: 48_000)
        for note in 0..<12 { harp.pluck(220 * pow(2, Float(note) / 12), strength: 0.5) }
        XCTAssertEqual(harp.sounding, Harp.voices)
        XCTAssertEqual(harp.plucks, 12)
    }

    /// The glockenspiel sounds two octaves above the note written for it,
    /// from where it is heard, dies away, and an answer waits its breath.
    func testTheGlockenspielSoundsTwoOctavesAbove() {
        let bells = Glockenspiel(sampleRate: 48_000)
        bells.strike(440, strength: 1, pan: 0.5)
        let sound = (0..<48_000).map { _ in bells.sample(dt: 1 / 48_000) }
        let left = sound.map(\.left), right = sound.map(\.right)
        XCTAssertGreaterThan(rms(right), rms(left), "Heard from the right")
        let heard = peak(of: left[2_400..<24_000], near: 1_760, rate: 48_000)
        XCTAssertEqual(cents(heard, from: 1_760), 0, accuracy: 3)
        XCTAssertGreaterThan(strength(of: left[...], at: 1_760, rate: 48_000), strength(of: left[...], at: 1_864.7, rate: 48_000) * 10,
                             "Its note, not the one beside it")
        for _ in 0..<(48_000 * 4) { _ = bells.sample(dt: 1 / 48_000) }
        XCTAssertEqual(bells.sounding, 0, "Rung out")
        XCTAssertEqual(bells.struck, 1)
        bells.strike(660, strength: 1, wait: 0.5)
        XCTAssertEqual(rms((0..<Int(0.45 * 48_000)).map { _ in bells.sample(dt: 1 / 48_000).left }), 0)
        XCTAssertGreaterThan(rms((0..<4_800).map { _ in bells.sample(dt: 1 / 48_000).left }), 0.01)
        bells.clear()
        XCTAssertEqual(bells.sounding, 0)
    }

    /// A note bowed sounds its pitch, cellos below the violas and the bass
    /// beneath, and is held as long as it is bowed: round its loop for half
    /// a minute it neither dies nor swells, nor clicks where the loop joins.
    func testTheStringsAreBowedInTuneAndHeld() {
        for rate: Float in [48_000, 96_000] {
            for (frequency, bass) in [(Float(146.83), false), (Float(349.23), false), (Float(65.41), true)] {
                var note = Bowed(frequency: frequency, corner: 1_500, sampleRate: rate, bass: bass)
                let sound = (0..<Int(30 * rate)).map { _ in note.sample(dt: 1 / rate) }
                let left = sound.map(\.left), right = sound.map(\.right)
                let heard = pitch(of: left[Int(1.5 * rate)..<Int(2.5 * rate)], rate: rate, near: frequency)
                XCTAssertEqual(cents(heard, from: frequency), 0, accuracy: 15, "\(frequency) Hz at \(rate)")
                XCTAssertNotEqual(left, right, "Heard from where its players sit")
                let early = rms(left[Int(1.5 * rate)..<Int(4.5 * rate)]), late = rms(left[Int(26 * rate)..<Int(29 * rate)])
                XCTAssertEqual(decibels(late), decibels(early), accuracy: 3, "Held, \(frequency) Hz")
                let windows = stride(from: Int(rate), to: left.count - Int(rate / 10), by: Int(rate / 10)).map { rms(left[$0..<($0 + Int(rate / 10))]) }
                XCTAssertLessThan(decibels(windows.max()!) - decibels(windows.min()!), 12, "Even through the loop, \(frequency) Hz")
                let steps = zip(left, left.dropFirst()).map { abs($1 - $0) }
                let typical = steps.sorted()[steps.count * 99 / 100]
                XCTAssertLessThan(steps.max()!, typical * 4, "No click at the loop's join, \(frequency) Hz at \(rate)")
            }
        }
        XCTAssertTrue(Recordings.celloNotes.allSatisfy { $0.frequency < Bowed.violas })
        XCTAssertTrue(Recordings.violaNotes.allSatisfy { $0.frequency >= Bowed.violas * 0.99 })
    }

    /// The bodies' low-pass passes what is under its corner and takes away
    /// what is well over it.
    func testTheLowpassKeepsTheLowsAndTakesTheHighs() {
        func gain(_ frequency: Float) -> Float {
            var filter = Lowpass(corner: 1_000, sampleRate: 48_000)
            let out = (0..<48_000).map { filter.process(sin(2 * .pi * frequency * Float($0) / 48_000)) }
            return rms(out[24_000...]) / Float(0.5).squareRoot()
        }
        XCTAssertEqual(decibels(gain(250)), 0, accuracy: 1)
        XCTAssertLessThan(decibels(gain(4_000)), -20)
    }

    /// The great drum sounds low and as hard as it is struck, forte or
    /// mezzo-forte; the field drum higher, its two strokes in turn; a
    /// stroke rings on through the next, and each is quiet soon after.
    func testTheDrumsAreStruckAsHardAsAsked() {
        func stroke(_ kind: Drum.Kind, _ strength: Float, times: Int = 1) -> [Float] {
            var drum = Drum(kind, sampleRate: 48_000)
            XCTAssertFalse(drum.isSounding)
            var sound: [Float] = []
            for _ in 0..<times {
                drum.strike(strength)
                sound += (0..<14_400).map { _ in drum.sample(dt: 1 / 48_000) }
            }
            sound += (0..<(48_000 * 2)).map { _ in drum.sample(dt: 1 / 48_000) }
            XCTAssertFalse(drum.isSounding, "Rung out")
            return sound
        }
        let full = stroke(.great, 1), softer = stroke(.great, 0.7)
        XCTAssertEqual(rms(full[..<12_000]) / rms(softer[..<12_000]), 1 / 0.7, accuracy: 0.2)
        XCTAssertGreaterThan(rms(full[..<4_800]), rms(full[48_000...]) * 30, "and dies")
        var high = Lowpass(corner: 1_000, sampleRate: 48_000)
        let above = full.map { $0 - high.process($0) }
        XCTAssertLessThan(rms(above[..<12_000]), rms(full[..<12_000]) * 0.5, "The great drum's weight is low")
        let field = stroke(.field, 0.35, times: 2)
        XCTAssertNotEqual(Array(field[..<4_800]), Array(field[14_400..<19_200]), "Its two strokes in turn")
        func middle(_ x: [Float]) -> Float {
            var low = Lowpass(corner: 2_000, sampleRate: 48_000)
            let lows = x.map { low.process($0) }
            return zip(x, lows).map { abs($0 - $1) }.reduce(0, +) / max(x.map(abs).reduce(0, +), 1e-9)
        }
        XCTAssertGreaterThan(middle(Array(field[..<9_600])), middle(Array(full[..<9_600])), "The field drum the brighter")
    }
}
