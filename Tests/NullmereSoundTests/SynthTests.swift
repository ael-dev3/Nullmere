import Foundation
import XCTest
import NullmereCore
@testable import NullmereSound

/// Renders a synthesiser offline, as the Mac's audio engine would ask it,
/// a block at a time: both ears, `seconds` long.
func rendered(_ synth: Synth, seconds: Float, rate: Float = 48_000, block: Int = 512) -> (left: [Float], right: [Float]) {
    let frames = Int(seconds * rate)
    var left: [Float] = [], right: [Float] = []
    left.reserveCapacity(frames)
    right.reserveCapacity(frames)
    let l = UnsafeMutablePointer<Float>.allocate(capacity: block), r = UnsafeMutablePointer<Float>.allocate(capacity: block)
    defer { l.deallocate(); r.deallocate() }
    var done = 0
    while done < frames {
        let n = min(block, frames - done)
        synth.render(frames: n, left: l, right: r)
        left.append(contentsOf: UnsafeBufferPointer(start: l, count: n))
        right.append(contentsOf: UnsafeBufferPointer(start: r, count: n))
        done += n
    }
    return (left, right)
}

func rms<C: Collection>(_ x: C) -> Float where C.Element == Float {
    (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
}

func decibels(_ level: Float) -> Float { 20 * log10(max(level, 1e-12)) }

/// The game's sound, rendered and measured away from the Mac: the bed of
/// drone and wind quiet beneath everything, every cue heard above it, the
/// score between them, from where each sound happened, and nothing ever
/// clipped, whatever sounds at once.
final class SynthTests: XCTestCase {
    static let rate: Float = 48_000

    private func settled(rate: Float = SynthTests.rate) -> Synth {
        let synth = Synth()
        synth.prepare(sampleRate: rate)
        synth.settle()
        return synth
    }

    private func scored(_ mood: Score.Mood, ambience: Float = 1) -> Synth {
        let synth = settled()
        synth.setMusic(on: true, mood: mood)
        synth.setVolumes(effects: 1, ambience: ambience, music: 1)
        return synth
    }

    func testTheBedIsQuietButThere() {
        let bed = rendered(settled(), seconds: 8).left
        let dB = decibels(rms(bed))
        print("SOUND bed \(String(format: "%.1f", dB)) dBFS rms, peak \(String(format: "%.3f", bed.map(abs).max() ?? 0))")
        XCTAssertGreaterThan(dB, -40, "The night should be heard")
        XCTAssertLessThan(dB, -22, "but stay beneath everything else")
    }

    /// Two synthesisers render identical beds, so the difference is the cue.
    func testEveryCueIsHeardAboveTheBed() {
        let bedLevel = rms(rendered(settled(), seconds: 4).left)
        var report: [String] = []
        for cue in SoundCue.all {
            let plain = settled(), cued = settled()
            _ = rendered(plain, seconds: 1)
            _ = rendered(cued, seconds: 1)
            cued.trigger(cue)
            let a = rendered(plain, seconds: 1).left, b = rendered(cued, seconds: 1).left
            let peak = zip(a, b).map { abs($1 - $0) }.max() ?? 0
            report.append("\(cue) \(String(format: "%+.1f", decibels(peak / bedLevel))) dB")
            XCTAssertGreaterThan(peak, bedLevel * 1.7, "\(cue) must stand out from the bed")
        }
        print("SOUND cues over the bed: " + report.joined(separator: ", "))
    }

    func testTheNightKeepsMovingLongAfterEightMinutes() {
        let synth = settled()
        synth.advanceClock(by: 3_600)
        _ = rendered(synth, seconds: 1)
        XCTAssertEqual(synth.clock, 3_601, accuracy: 0.001, "An hour in, a second of sound is a second on its clock")
    }

    func testTheBedSoundsTheSameAtAnySampleRate() {
        func bed(at rate: Float) -> Float { rms(rendered(settled(rate: rate), seconds: 6, rate: rate).left) }
        let usual = bed(at: 48_000), finer = bed(at: 96_000), coarser = bed(at: 44_100)
        XCTAssertEqual(decibels(finer / usual), 0, accuracy: 1.5, "At 96 kHz as at 48")
        XCTAssertEqual(decibels(coarser / usual), 0, accuracy: 1.5, "and at 44.1")
    }

    func testACueWaitsItsTurnAndATollRingsOut() {
        let plain = settled(), cued = settled()
        cued.trigger(.select, after: 0.5)
        let before = zip(rendered(plain, seconds: 0.45).left, rendered(cued, seconds: 0.45).left).map { abs($1 - $0) }.max() ?? 0
        let after = zip(rendered(plain, seconds: 0.3).left, rendered(cued, seconds: 0.3).left).map { abs($1 - $0) }.max() ?? 0
        XCTAssertLessThan(before, 0.0001, "Silent until its turn")
        XCTAssertGreaterThan(after, 0.01, "then heard")

        let tolled = settled()
        tolled.trigger(.toll)
        _ = rendered(tolled, seconds: 9)
        XCTAssertEqual(tolled.sounding, 1, "Nine seconds on, the toll still rings")
        _ = rendered(tolled, seconds: 32)
        XCTAssertEqual(tolled.sounding, 0, "and is let go once it has died away")
    }

    func testTheSumIsSoftenedNotClipped() {
        XCTAssertEqual(Synth.softened(0.5), 0.5)
        XCTAssertEqual(Synth.softened(-0.7), -0.7)
        XCTAssertLessThan(Synth.softened(1.5), 1)
        XCTAssertLessThanOrEqual(Synth.softened(3), 1)
        XCTAssertGreaterThanOrEqual(Synth.softened(-30), -1)
        XCTAssertGreaterThan(Synth.softened(1.5), Synth.softened(1.1), "Louder still sounds louder")
        XCTAssertEqual(Synth.softened(-1.2), -Synth.softened(1.2))
        XCTAssertEqual(Synth.softened(0.75), 0.75, accuracy: 0.0001, "No step at the knee")
    }

    func testNothingClipsEvenWithEveryCueAtOnce() {
        let synth = scored(.war)
        _ = rendered(synth, seconds: 4)
        var burst: [Float] = []
        for cue in SoundCue.all {
            synth.trigger(cue)
            let heard = rendered(synth, seconds: 0.005)
            burst += heard.left + heard.right
        }
        let tail = rendered(synth, seconds: 3)
        burst += tail.left + tail.right
        let peak = burst.map(abs).max() ?? 0
        print("SOUND every cue at once peaks at \(String(format: "%.3f", peak))")
        XCTAssertLessThan(peak, 0.8)
        XCTAssertFalse(burst.contains { $0.isNaN || $0.isInfinite })
    }

    /// A cue in the middle is heard alike in both ears; at an edge, in the
    /// nearer one, never gone from the other; far off, quieter.
    func testACueIsHeardFromWhereItHappened() {
        func ears(at place: SoundPlace) -> (left: Float, right: Float) {
            let synth = settled()
            synth.setVolumes(effects: 1, ambience: 0, music: 1)
            synth.trigger(.clash, at: place)
            let heard = rendered(synth, seconds: 0.5)
            return (rms(heard.left), rms(heard.right))
        }
        let middle = ears(at: .middle)
        XCTAssertEqual(middle.left, middle.right, accuracy: middle.left * 0.02, "In the middle, both ears alike")
        let right = ears(at: SoundPlace(pan: 1, gain: 1))
        XCTAssertGreaterThan(right.right, right.left * 3, "At the right edge, the right ear")
        XCTAssertGreaterThan(right.left, 0, "never gone from the other")
        let left = ears(at: SoundPlace(pan: -1, gain: 1))
        XCTAssertGreaterThan(left.left, left.right * 3)
        let far = ears(at: SoundPlace(pan: 0, gain: 0.3))
        XCTAssertEqual(far.left / middle.left, 0.3, accuracy: 0.03, "Far off, quieter")
        XCTAssertEqual(SoundPlace(pan: 4, gain: -1), SoundPlace(pan: 1, gain: 0), "Kept within its bounds")
    }

    /// Each slider governs its own part: the cues, the night, the score.
    func testEachPartHasItsOwnVolume() {
        func cuePeak(effects: Float) -> Float {
            let plain = settled(), cued = settled()
            plain.setVolumes(effects: effects, ambience: 0, music: 1)
            cued.setVolumes(effects: effects, ambience: 0, music: 1)
            _ = rendered(plain, seconds: 0.5)
            _ = rendered(cued, seconds: 0.5)
            cued.trigger(.clash)
            return zip(rendered(plain, seconds: 0.6).left, rendered(cued, seconds: 0.6).left).map { abs($1 - $0) }.max() ?? 0
        }
        let full = cuePeak(effects: 1), half = cuePeak(effects: 0.5)
        XCTAssertEqual(half / full, 0.5, accuracy: 0.05)
        XCTAssertEqual(cuePeak(effects: 0), 0, accuracy: 0.0001)
        let quiet = settled()
        quiet.setVolumes(effects: 1, ambience: 0, music: 1)
        XCTAssertLessThan(rms(rendered(quiet, seconds: 2).left), 0.0001, "No drone, no wind")
        let silenced = scored(.peace, ambience: 0)
        silenced.setVolumes(effects: 1, ambience: 0, music: 0)
        XCTAssertLessThan(rms(rendered(silenced, seconds: 20).left), 0.0001, "No score with its volume down")
    }

    /// The din of a field of battle in sight: well above the night, from
    /// where it is, fainter for fewer and farther off; gone again once no
    /// battle is in sight, and never clipping.
    func testABattleIsHeardFromWhereItIsAboveTheNightAndNeverClips() {
        let rate = 48_000
        let held = (2 * rate)..<(4 * rate), after = (6 * rate)..<(8 * rate)
        let quiet = rendered(settled(), seconds: 8)
        let bed = (left: rms(quiet.left[held]), right: rms(quiet.right[held]))
        let bedAfter = rms(quiet.left[after])
        // How much of a channel is the din's, past the night's.
        func din(_ heard: Float, over night: Float) -> Float { max(heard * heard - night * night, 0) }

        let loud = settled()
        loud.setDin(level: 1, pan: 0.8)
        let battle = rendered(loud, seconds: 4)
        let left = rms(battle.left[held]), right = rms(battle.right[held])
        print("SOUND din \(String(format: "%.1f", decibels(max(left, right)))) dBFS rms beside a bed of \(String(format: "%.1f", decibels(bed.right)))")
        XCTAssertGreaterThan(right, bed.right * 2, "A great battle close by is heard well above the night")
        XCTAssertGreaterThan(din(right, over: bed.right), 4 * din(left, over: bed.left), "from the right, where it is")
        XCTAssertLessThan(max(battle.left.map(abs).max() ?? 0, battle.right.map(abs).max() ?? 0), 0.95, "and never clips")
        XCTAssertEqual(loud.dinHeard.level, 1, accuracy: 0.05)

        let faint = settled()
        faint.setDin(level: 0.35, pan: -1)
        let far = rendered(faint, seconds: 4)
        let farLeft = rms(far.left[held]), farRight = rms(far.right[held])
        XCTAssertLessThan(din(farLeft, over: bed.left), din(right, over: bed.right) / 2, "Fainter for fewer, farther off")
        XCTAssertGreaterThan(din(farLeft, over: bed.left), 4 * din(farRight, over: bed.right), "from the left")
        loud.setDin(level: 0, pan: 0)
        let gone = rendered(loud, seconds: 4)
        XCTAssertLessThan(rms(gone.left[(2 * rate)...]), bedAfter * 1.2, "Gone again with the battle")
        XCTAssertEqual(loud.dinHeard.level, 0, accuracy: 0.01)
    }

    /// Riders' hooves fall one after another, each landing once the one
    /// before has faded, the hall's echo between them no more than a murmur.
    func testTheHoovesFallInTurn() {
        let plain = settled(), cued = settled()
        plain.setVolumes(effects: 1, ambience: 0, music: 1)
        cued.setVolumes(effects: 1, ambience: 0, music: 1)
        cued.trigger(.ride)
        let difference = zip(rendered(plain, seconds: 0.4).left, rendered(cued, seconds: 0.4).left).map { abs($1 - $0) }
        func peak(_ from: Double, _ to: Double) -> Float {
            difference[Int(from * 48_000)..<Int(to * 48_000)].max() ?? 0
        }
        XCTAssertGreaterThan(peak(0, 0.03), peak(0.08, 0.115) * 2)
        XCTAssertGreaterThan(peak(0.12, 0.15), peak(0.08, 0.115) * 2)
        XCTAssertGreaterThan(peak(0.21, 0.24), peak(0.08, 0.115) * 2)
    }

    /// Faded in, it rises from silence; faded out, it falls to it; reset,
    /// nothing is left sounding.
    func testItFadesInAndOutAndIsResetToSilence() {
        let synth = Synth()
        synth.prepare(sampleRate: Self.rate)
        XCTAssertLessThan(rms(rendered(synth, seconds: 0.5).left), 0.0001, "Silent until faded in")
        synth.fadeIn()
        _ = rendered(synth, seconds: 12)
        XCTAssertGreaterThan(rms(rendered(synth, seconds: 1).left), 0.005)
        synth.trigger(.toll)
        _ = rendered(synth, seconds: 0.1)
        synth.fadeOut(rate: 12)
        _ = rendered(synth, seconds: 2)
        XCTAssertLessThan(rms(rendered(synth, seconds: 0.5).left), 0.0005, "Faded out")
        synth.reset()
        XCTAssertEqual(synth.sounding, 0)
    }

    // MARK: The score

    func testTheScoreSitsBeneathTheCuesAndAboveSilence() {
        let withMusic = rendered(scored(.peace), seconds: 60).left
        let without = rendered(settled(), seconds: 60).left
        let music = zip(withMusic, without).map { $0 - $1 }.suffix(48_000 * 40)
        let dB = decibels(rms(music))
        print("SOUND music \(String(format: "%.1f", dB)) dBFS rms, peak \(String(format: "%.3f", music.map(abs).max() ?? 0))")
        XCTAssertGreaterThan(dB, -40, "The music should be heard")
        XCTAssertLessThan(dB, -24, "but leave the cues room")
        XCTAssertLessThan(withMusic.map(abs).max() ?? 0, 0.6)
    }

    func testTheScoreKeepsItsKeyAndMoves() {
        let s = scored(.peace)
        _ = rendered(s, seconds: 90)
        let score = s.scoreSnapshot
        XCTAssertGreaterThanOrEqual(score.playedNotes.count, 8)
        XCTAssertTrue(score.playedNotes.allSatisfy(Score.melody.contains), "Every note is in D minor pentatonic")
        XCTAssertGreaterThan(Set(score.playedNotes).count, 3, "The melody wanders")
        XCTAssertGreaterThanOrEqual(score.chordChanges, 5)
        XCTAssertEqual(score.drumStrokes, 0, "No drum in peace")
    }

    func testWarBringsTheDrum() {
        let s = scored(.war)
        _ = rendered(s, seconds: 30)
        XCTAssertGreaterThanOrEqual(s.scoreSnapshot.drumStrokes, 10)
    }

    func testTheSameSeedPlaysTheSameMusic() {
        let a = rendered(scored(.peace), seconds: 20), b = rendered(scored(.peace), seconds: 20)
        XCTAssertEqual(a.left, b.left)
        XCTAssertEqual(a.right, b.right)
    }

    func testEachLakeHasItsOwnTitleTheme() {
        for lake in Lake.allCases {
            let s = scored(.title(lake))
            _ = rendered(s, seconds: 90)
            let score = s.scoreSnapshot
            let theme = Theme.of(.title(lake))
            XCTAssertGreaterThanOrEqual(score.playedNotes.count, 4, "\(lake)")
            XCTAssertTrue(score.playedNotes.allSatisfy(theme.melody.contains), "\(lake) keeps its mode")
            XCTAssertGreaterThanOrEqual(score.chordChanges, 3, "\(lake)")
            XCTAssertEqual(score.drumStrokes, 0, "No drum over the launcher")
        }
        XCTAssertEqual(Set(Lake.allCases.map { Theme.of(.title($0)).melody }).count, Lake.allCases.count, "Each lake its own")
        XCTAssertEqual(Theme.of(.title(.twin)).echo, 7)
        XCTAssertNil(Theme.of(.peace).echo)
        XCTAssertEqual(Theme.of(.peace).melody, Score.melody, "The realm's peace as it was")
        XCTAssertEqual(Theme.of(.war).chords, Score.warChords)
    }
}
