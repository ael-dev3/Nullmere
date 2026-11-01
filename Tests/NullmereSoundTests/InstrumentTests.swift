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
/// rate, ringing as their kind rings, and quiet when done.
final class InstrumentTests: XCTestCase {
    private func harp(_ frequency: Float, rate: Float = 48_000, seconds: Float = 1.5, strength: Float = 0.8) -> [Float] {
        let harp = Harp(sampleRate: rate)
        harp.pluck(frequency, strength: strength)
        return (0..<Int(seconds * rate)).map { _ in harp.sample(dt: 1 / rate).left }
    }

    /// Every string in tune, low and high, at every rate the Mac runs at.
    func testTheHarpIsInTune() {
        for rate: Float in [44_100, 48_000, 96_000] {
            for frequency: Float in [110, 220, 293.66, 440, 880, 1_318.5] {
                let sound = harp(frequency, rate: rate, seconds: 0.6)
                let heard = pitch(of: sound[Int(0.1 * rate)..<Int(0.35 * rate)], rate: rate, near: frequency)
                XCTAssertEqual(cents(heard, from: frequency), 0, accuracy: 4, "\(frequency) Hz at \(rate)")
            }
        }
    }

    /// The low strings ring longest, each about as long as it should, and a
    /// string done is let go.
    func testTheLowStringsRingLongest() {
        let low = ringing(harp(147, seconds: 8), rate: 48_000)
        let high = ringing(harp(1_175, seconds: 8), rate: 48_000)
        XCTAssertGreaterThan(low, high * 1.5, "\(low) s against \(high) s")
        XCTAssertEqual(low, Harp.ringing(147), accuracy: Harp.ringing(147) * 0.35)
        XCTAssertEqual(high, Harp.ringing(1_175), accuracy: Harp.ringing(1_175) * 0.35)

        let harp = Harp(sampleRate: 48_000)
        harp.pluck(440, strength: 0.5)
        XCTAssertEqual(harp.sounding, 1)
        for _ in 0..<Int(48_000 * (Harp.ringing(440) + 0.5)) { _ = harp.sample(dt: 1 / 48_000) }
        XCTAssertEqual(harp.sounding, 0, "Let go once it has rung out")
        harp.pluck(440, strength: 0.5)
        harp.clear()
        XCTAssertEqual(harp.sounding, 0)
    }

    /// A pluck leaves nothing but its note: it begins without a click, no
    /// offset rings on, and harder is louder.
    func testAPluckIsANoteAndNothingElse() {
        let sound = harp(330, seconds: 2)
        XCTAssertLessThan(abs(sound[0]), 0.05, "Begun where the string crosses nothing")
        let mean = sound.reduce(0, +) / Float(sound.count)
        XCTAssertLessThan(abs(mean), 0.001)
        let soft = rms(harp(330, strength: 0.3)), hard = rms(harp(330, strength: 0.9))
        XCTAssertEqual(hard / soft, 3, accuracy: 0.6)
        XCTAssertFalse(sound.contains { $0.isNaN || $0.isInfinite })
    }

    /// Every pluck carries its note, however its noise falls: of thirty
    /// plucks of a high string, each holds its own pitch above the octave
    /// and the twelfth over it.
    func testEveryPluckCarriesItsNote() {
        let harp = Harp(sampleRate: 48_000)
        for _ in 0..<30 {
            harp.pluck(1_175, strength: 0.8, brightness: 0.6)
            let sound = (0..<14_400).map { _ in harp.sample(dt: 1 / 48_000).left }
            let note = strength(of: sound[2_400...], at: 1_175, rate: 48_000)
            XCTAssertGreaterThan(note, strength(of: sound[2_400...], at: 2_350, rate: 48_000))
            XCTAssertGreaterThan(note, strength(of: sound[2_400...], at: 3_525, rate: 48_000))
            harp.clear()
        }
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

    /// A glass bell sounds its note above its other modes, and dies away.
    func testABellRingsItsNote() {
        let bells = Bells(sampleRate: 48_000)
        bells.strike(440, timbre: .glass, strength: 1, pan: 0.5)
        let sound = (0..<48_000).map { _ in bells.sample(dt: 1 / 48_000) }
        let left = sound.map(\.left), right = sound.map(\.right)
        XCTAssertGreaterThan(rms(right), rms(left), "Heard from the right")
        let note = strength(of: left[...], at: 440, rate: 48_000)
        XCTAssertGreaterThan(note, strength(of: left[...], at: 880, rate: 48_000) * 2)
        XCTAssertGreaterThan(note, strength(of: left[...], at: 466, rate: 48_000) * 20, "Its note, not the one beside it")
        XCTAssertEqual(ringing((0..<(48_000 * 14)).map { _ in bells.sample(dt: 1 / 48_000).left }, rate: 48_000), Timbre.glass.life, accuracy: 3)
        XCTAssertEqual(bells.sounding, 0, "Rung out")
        XCTAssertEqual(bells.struck, 1)
        // An answer waits its breath.
        bells.strike(660, timbre: .glass, strength: 1, wait: 0.5)
        XCTAssertEqual(rms((0..<Int(0.45 * 48_000)).map { _ in bells.sample(dt: 1 / 48_000).left }), 0)
        XCTAssertGreaterThan(rms((0..<4_800).map { _ in bells.sample(dt: 1 / 48_000).left }), 0.01)
        bells.clear()
        XCTAssertEqual(bells.sounding, 0)
    }

    /// The bowed strings sound their note, and lean apart in the ears.
    func testTheStringsAreBowedInTune() {
        for rate: Float in [48_000, 96_000] {
            var note = Bowed(frequency: 146.83, corner: 1_500, sampleRate: rate, seed: 2)
            let sound = (0..<Int(2 * rate)).map { _ in note.sample(dt: 1 / rate) }
            let left = sound.map(\.left), right = sound.map(\.right)
            let heard = pitch(of: left[Int(0.5 * rate)..<Int(0.8 * rate)], rate: rate, near: 146.83)
            XCTAssertEqual(cents(heard, from: 146.83), 0, accuracy: 12, "at \(rate)")
            XCTAssertNotEqual(left, right, "The players apart")
            XCTAssertEqual(rms(left), rms(right), accuracy: rms(left) * 0.2)
        }
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

    /// A drum struck sounds low and falls in pitch, and is quiet soon after.
    func testADrumSoundsLowAndFalls() {
        var drum = Drum(pitch: 55, sampleRate: 48_000)
        XCTAssertFalse(drum.isSounding)
        drum.strike(1)
        let sound = (0..<(48_000 * 3 + 480)).map { _ in drum.sample(dt: 1 / 48_000) }
        XCTAssertFalse(drum.isSounding, "Rung out")
        var high = Lowpass(corner: 1_000, sampleRate: 48_000)
        let above = sound.map { $0 - high.process($0) }
        XCTAssertLessThan(rms(above), rms(sound) * 0.2, "Its weight is low")
        func crossings(_ part: ArraySlice<Float>) -> Float {
            Float(zip(part, part.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count) / Float(part.count)
        }
        var smooth = Lowpass(corner: 300, sampleRate: 48_000)
        let body = sound.map { smooth.process($0) }
        XCTAssertGreaterThan(crossings(body[480..<2_400]), crossings(body[4_800..<14_400]), "The blow's pitch falls back")
        XCTAssertGreaterThan(rms(sound[..<4_800]), rms(sound[48_000...]) * 30, "and dies")
    }
}
