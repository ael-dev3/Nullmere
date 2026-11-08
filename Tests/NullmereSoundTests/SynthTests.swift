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
            _ = rendered(plain, seconds: 0.3)
            _ = rendered(cued, seconds: 0.3)
            cued.trigger(cue)
            let a = rendered(plain, seconds: 0.7).left, b = rendered(cued, seconds: 0.7).left
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
        func bed(at rate: Float) -> Float { rms(rendered(settled(rate: rate), seconds: 3, rate: rate).left) }
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

        // A long toll rings out whole, well past eight seconds, and a short
        // cue is let go once it has died away.
        XCTAssertGreaterThan(settled().lasting(.toll), 25)
        let tolled = settled()
        tolled.trigger(.toll)
        _ = rendered(tolled, seconds: 9)
        XCTAssertEqual(tolled.sounding, 1, "Nine seconds on, the toll still rings")
        let clicked = settled()
        clicked.trigger(.select)
        _ = rendered(clicked, seconds: clicked.lasting(.select) + 0.05)
        XCTAssertEqual(clicked.sounding, 0, "let go once it has died away")
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

    /// Each cue's noise sounds in its material's band: a page's rustle
    /// high, a hoof's thud low, salt through a glass far brighter than a
    /// ram on a gate; and as loud at any sample rate.
    func testEachCuesNoiseSoundsInItsMaterialsBand() {
        func alone(_ cue: SoundCue, rate: Float = 48_000) -> [Float] {
            let synth = settled(rate: rate)
            synth.setVolumes(effects: 1, ambience: 0, music: 1)
            synth.trigger(cue)
            return rendered(synth, seconds: 0.3, rate: rate).left
        }
        func crossings(_ x: [Float]) -> Float {
            Float(zip(x, x.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count) / Float(x.count)
        }
        XCTAssertGreaterThan(crossings(alone(.leaf)), crossings(alone(.ride)) * 4)
        XCTAssertGreaterThan(crossings(alone(.sift)), crossings(alone(.batter)) * 3)
        XCTAssertEqual(decibels(rms(alone(.leaf, rate: 96_000)) / rms(alone(.leaf))), 0, accuracy: 1.5)
        XCTAssertEqual(decibels(rms(alone(.ride, rate: 44_100)) / rms(alone(.ride))), 0, accuracy: 1.5)
        XCTAssertNil(Synth.bands(of: .watch).first, "A bell has no noise to colour")
        XCTAssertNotNil(Synth.bands(of: .loose).rest, "The arrow's hiss its own")
    }

    /// The war horn's and the muster's cues are blown on the recorded horn,
    /// two notes each, as loud over a second and a half as the horns of
    /// overtones they took over from (-36.2 and -38.4 dB, measured on those
    /// before), and from where they happen; no other cue is.
    func testTheHornCuesAreBlownOnTheRecordedHorn() {
        func blown(_ cue: SoundCue, at place: SoundPlace = .middle) -> (synth: Synth, left: [Float], right: [Float]) {
            let synth = settled()
            synth.setVolumes(effects: 1, ambience: 0, music: 0)
            _ = rendered(synth, seconds: 0.2)
            synth.trigger(cue, at: place)
            let heard = rendered(synth, seconds: 1.5)
            return (synth, heard.left, heard.right)
        }
        for (cue, before) in [(SoundCue.horn, Float(-36.2)), (.muster, -38.4)] {
            let heard = blown(cue)
            XCTAssertEqual(heard.synth.cueHornsBlown, 2, "\(cue): two notes on the horn")
            print("SOUND \(cue) on the recorded horn \(decibels(rms(heard.left[...]))) dB, its horn of overtones \(before) dB")
            XCTAssertEqual(decibels(rms(heard.left[...])), before, accuracy: 2, "\(cue) as loud as it was")
        }
        let right = blown(.horn, at: SoundPlace(pan: 1, gain: 1))
        XCTAssertGreaterThan(rms(right.right[...]), rms(right.left[...]) * 3, "At the right edge, the right ear")
        XCTAssertEqual(blown(.clash).synth.cueHornsBlown, 0, "A clash is no horn's")
        XCTAssertEqual(Synth.call(of: .horn).map(\.frequency), [110, 146.8], "A, then the D a fourth above")
        XCTAssertEqual(Synth.call(of: .muster).map(\.frequency), [196, 293.7], "G, then the D a fifth above")
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
        XCTAssertLessThan(rms(rendered(silenced, seconds: 6).left), 0.0001, "No score with its volume down")
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

    /// The lake at its edge near the view laps at the strand, about as loud
    /// as the night beneath it, from where it lies across the view, wave by
    /// wave: each washing up in a moment and drawing back slowly, never on
    /// a beat, now and then a drop falling back; gone again once the view
    /// draws back. The night sounds as it did beneath it.
    func testTheShoreNearTheViewLapsFromWhereItLies() {
        let still = settled()
        let quiet = rendered(still, seconds: 10)
        let near = settled()
        near.setShore(level: 1, pan: 0.8)
        let heard = rendered(near, seconds: 10)
        let held = (3 * 48_000)..<(10 * 48_000)
        // The night the same beneath, so what differs is the shore's.
        let left = zip(heard.left[held], quiet.left[held]).map { $0 - $1 }
        let right = zip(heard.right[held], quiet.right[held]).map { $0 - $1 }
        let night = rms(quiet.right[held])
        print("SOUND shore \(String(format: "%.1f", decibels(rms(right)))) dBFS rms beside a night of \(String(format: "%.1f", decibels(night)))")
        XCTAssertGreaterThan(rms(right), night * 0.4, "Heard over the night")
        XCTAssertLessThan(rms(right), night * 2, "and no louder than about it")
        XCTAssertGreaterThan(rms(right), rms(left) * 1.5, "from the right, where it lies")
        // Wave by wave: its loudness in quarter seconds rises and falls.
        let quarters = stride(from: 0, to: right.count - 12_000, by: 12_000).map { rms(right[$0..<($0 + 12_000)]) }
        XCTAssertGreaterThan((quarters.max() ?? 0) / max(quarters.min() ?? 1, 1e-9), 3, "Each wave swells and ebbs")
        XCTAssertEqual(near.shoreHeard.level, 1, accuracy: 0.05)
        near.setShore(level: 0, pan: 0)
        _ = rendered(near, seconds: 6)
        _ = rendered(still, seconds: 6)
        XCTAssertEqual(near.shoreHeard.level, 0, accuracy: 0.01)
        let after = rendered(near, seconds: 2), bed = rendered(still, seconds: 2)
        let lingering = zip(after.right, bed.right).map { $0 - $1 }
        XCTAssertLessThan(rms(lingering), rms(bed.right) * 0.05, "Gone again with the view, the night as it was")

        var shore = Shore(sampleRate: 48_000)
        let sound = (0..<(48_000 * 20)).map { _ in shore.sample(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(shore.waves, 5, "Wave after wave comes in")
        XCTAssertGreaterThanOrEqual(shore.drops, 3, "Now and then a drop falls back")
        XCTAssertGreaterThan(shore.gaps.longest, shore.gaps.shortest + 0.5, "Never on a beat")
        XCTAssertGreaterThanOrEqual(shore.gaps.shortest, 2, "A wave at a time")
        XCTAssertFalse(sound.contains { $0.isNaN || $0.isInfinite })
        XCTAssertLessThan(sound.map(abs).max() ?? 1, 1)
        // The same at another rate: as loud, its waves as long.
        var faster = Shore(sampleRate: 96_000)
        let doubled = (0..<(96_000 * 20)).map { _ in faster.sample(dt: 1 / 96_000) }
        XCTAssertEqual(faster.waves, shore.waves)
        XCTAssertEqual(rms(doubled), rms(sound), accuracy: rms(sound) * 0.35, "As loud at any rate")
    }

    /// The towns near the view are heard talking and at work, about as
    /// loud as the night beneath them, from where they lie across the view,
    /// talk rising and falling and now and then a hammer's blow; gone again
    /// once the view draws back. The night sounds as it did beneath them.
    func testTheTownsNearTheViewAreHeardFromWhereTheyLie() {
        let quiet = rendered(settled(), seconds: 6)
        let near = settled()
        near.setTown(level: 1, pan: -0.8)
        let heard = rendered(near, seconds: 6)
        let held = (3 * 48_000)..<(6 * 48_000)
        // The night the same beneath, so what differs is the towns'.
        let left = zip(heard.left[held], quiet.left[held]).map { $0 - $1 }
        let right = zip(heard.right[held], quiet.right[held]).map { $0 - $1 }
        let night = rms(quiet.left[held])
        print("SOUND town \(String(format: "%.1f", decibels(rms(left)))) dBFS rms beside a night of \(String(format: "%.1f", decibels(night)))")
        XCTAssertGreaterThan(rms(left), night * 0.4, "Heard over the night")
        XCTAssertLessThan(rms(left), night * 2, "and no louder than about it")
        XCTAssertGreaterThan(rms(left), rms(right) * 1.5, "from the left, where it lies")
        // Talk rises and falls: its loudness in tenths of a second varies.
        let tenths = stride(from: 0, to: left.count - 4_800, by: 4_800).map { rms(left[$0..<($0 + 4_800)]) }
        XCTAssertGreaterThan((tenths.max() ?? 0) / max(tenths.min() ?? 1, 1e-9), 1.5)
        XCTAssertEqual(near.townHeard.level, 1, accuracy: 0.05)
        near.setTown(level: 0, pan: 0)
        _ = rendered(near, seconds: 5)
        XCTAssertEqual(near.townHeard.level, 0, accuracy: 0.01)

        var town = Town(sampleRate: 48_000)
        let sound = (0..<(48_000 * 7)).map { _ in town.sample(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(town.blows, 2, "Work goes on")
        XCTAssertFalse(sound.contains { $0.isNaN || $0.isInfinite })
        XCTAssertLessThan(sound.map(abs).max() ?? 1, 1)

        // A sawpit at work: the pit-saw's rasp, stroke by stroke, and none
        // where no sawpit is.
        var unsawn = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in unsawn.saw(dt: 1 / 48_000) }.map(abs).max(), 0)
        var sawn = Town(sampleRate: 48_000)
        sawn.sawing = 1
        let rasp = (0..<(48_000 * 2)).map { _ in sawn.saw(dt: 1 / 48_000) }
        let strokes = stride(from: 0, to: rasp.count - 2_400, by: 2_400).map { rms(rasp[$0..<($0 + 2_400)]) }
        XCTAssertGreaterThan(strokes.max() ?? 0, 0.01, "Heard")
        XCTAssertGreaterThan((strokes.max() ?? 0) / max(strokes.min() ?? 1, 1e-9), 3, "Stroke by stroke")
        XCTAssertFalse(rasp.contains { $0.isNaN || $0.isInfinite })
        let synth = settled()
        synth.setSawing(2)
        synth.setChiselling(1)
        _ = rendered(synth, seconds: 0.1)

        // Masons at work: a chisel's taps, several a second, and none where
        // no lodge is.
        var uncut = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in uncut.chisel(dt: 1 / 48_000) }.map(abs).max(), 0)
        var cut = Town(sampleRate: 48_000)
        cut.chiselling = 1
        let taps = (0..<(48_000 * 2)).map { _ in cut.chisel(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(cut.taps, 4, "Several taps in two seconds")
        XCTAssertGreaterThan(taps.map(abs).max() ?? 0, 0.05)
        XCTAssertFalse(taps.contains { $0.isNaN || $0.isInfinite })

        // A beacon's fire: its roar heard, now and then a crack.
        var unlit = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in unlit.burn(dt: 1 / 48_000) }.map(abs).max(), 0)
        var lit = Town(sampleRate: 48_000)
        lit.burning = 1
        let fire = (0..<(48_000 * 3)).map { _ in lit.burn(dt: 1 / 48_000) }
        XCTAssertGreaterThan(rms(fire), 0.005, "The roar heard")
        XCTAssertGreaterThanOrEqual(lit.cracks, 1, "A log splits in it")
        XCTAssertFalse(fire.contains { $0.isNaN || $0.isInfinite })
        synth.setBurning(1)
        synth.setThreshing(1)
        _ = rendered(synth, seconds: 0.05)

        // The threshing floor: flails falling in turn, and none where no
        // granary is.
        var unthreshed = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in unthreshed.thresh(dt: 1 / 48_000) }.map(abs).max(), 0)
        var threshed = Town(sampleRate: 48_000)
        threshed.threshing = 1
        let blows = (0..<(48_000 * 3)).map { _ in threshed.thresh(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(threshed.flails, 5, "Strokes falling in turn")
        XCTAssertGreaterThan(blows.map(abs).max() ?? 0, 0.1)
        XCTAssertFalse(blows.contains { $0.isNaN || $0.isInfinite })

        // A quarry at work: picks on rock, and none where no quarry is.
        var unhewn = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in unhewn.quarry(dt: 1 / 48_000) }.map(abs).max(), 0)
        var hewn = Town(sampleRate: 48_000)
        hewn.quarrying = 1
        let hewing = (0..<(48_000 * 3)).map { _ in hewn.quarry(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(hewn.picks, 2)
        XCTAssertGreaterThan(hewing.map(abs).max() ?? 0, 0.1)
        XCTAssertFalse(hewing.contains { $0.isNaN || $0.isInfinite })
        synth.setQuarrying(1)
        synth.setRaking(1)
        _ = rendered(synth, seconds: 0.05)

        // A saltworks: rakes hissing through the crust, stroke by stroke,
        // and none where no saltworks is.
        var unraked = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in unraked.rake(dt: 1 / 48_000) }.map(abs).max(), 0)
        var raked = Town(sampleRate: 48_000)
        raked.raking = 1
        let hiss = (0..<(48_000 * 3)).map { _ in raked.rake(dt: 1 / 48_000) }
        let strokeTenths = stride(from: 0, to: hiss.count - 4_800, by: 4_800).map { rms(hiss[$0..<($0 + 4_800)]) }
        XCTAssertGreaterThan(strokeTenths.max() ?? 0, 0.005, "Heard")
        XCTAssertLessThan(strokeTenths.min() ?? 1, (strokeTenths.max() ?? 0) * 0.3, "Stroke by stroke")
        XCTAssertFalse(hiss.contains { $0.isNaN || $0.isInfinite })

        // A muster hall at drill: the drum, two beats and a rest, and none
        // where no muster hall is.
        var undrilled = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in undrilled.drill(dt: 1 / 48_000) }.map(abs).max(), 0)
        var drilled = Town(sampleRate: 48_000)
        drilled.drilling = 1
        let drumming = (0..<(48_000 * 3)).map { _ in drilled.drill(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(drilled.beats, 4)
        XCTAssertGreaterThan(drumming.map(abs).max() ?? 0, 0.1)
        XCTAssertFalse(drumming.contains { $0.isNaN || $0.isInfinite })
        synth.setDrilling(1)
        synth.setGrinding(1)
        synth.setReading(1)
        synth.setForging(1)
        synth.setPosting(1)
        _ = rendered(synth, seconds: 0.05)

        // A wayhouse: a horse led across the yard, and none where no wayhouse is.
        var empty = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in empty.post(dt: 1 / 48_000) }.map(abs).max(), 0)
        var yard = Town(sampleRate: 48_000)
        yard.posting = 1
        let walking = (0..<(48_000 * 3)).map { _ in yard.post(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(yard.hoofFalls, 8)
        XCTAssertGreaterThan(walking.map(abs).max() ?? 0, 0.2)
        XCTAssertFalse(walking.contains { $0.isNaN || $0.isInfinite })

        // A forge: the hammer's rhythm on the anvil, and none where no forge is.
        var cold = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in cold.forge(dt: 1 / 48_000) }.map(abs).max(), 0)
        var smithy = Town(sampleRate: 48_000)
        smithy.forging = 1
        let ringing = (0..<(48_000 * 3)).map { _ in smithy.forge(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(smithy.strikes, 6)
        XCTAssertGreaterThan(ringing.map(abs).max() ?? 0, 0.2)
        XCTAssertFalse(ringing.contains { $0.isNaN || $0.isInfinite })

        // An archive: pages turning and quills, and none where no archive is.
        var unread = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in unread.read(dt: 1 / 48_000) }.map(abs).max(), 0)
        var archive = Town(sampleRate: 48_000)
        archive.reading = 1
        let rustle = (0..<(48_000 * 4)).map { _ in archive.read(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(archive.pages, 1)
        XCTAssertGreaterThan(rms(rustle), 0.001)
        XCTAssertFalse(rustle.contains { $0.isNaN || $0.isInfinite })

        // An infirmary: the pestle's knock and turn, and none where no
        // infirmary is.
        var ungrinding = Town(sampleRate: 48_000)
        XCTAssertEqual((0..<4_800).map { _ in ungrinding.grind(dt: 1 / 48_000) }.map(abs).max(), 0)
        var pestle = Town(sampleRate: 48_000)
        pestle.grinding = 1
        let ground = (0..<(48_000 * 3)).map { _ in pestle.grind(dt: 1 / 48_000) }
        XCTAssertGreaterThanOrEqual(pestle.knocks, 3)
        XCTAssertGreaterThan(ground.map(abs).max() ?? 0, 0.05)
        XCTAssertFalse(ground.contains { $0.isNaN || $0.isInfinite })
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
        _ = rendered(synth, seconds: 6)
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
        let withMusic = rendered(scored(.peace), seconds: 32).left
        let without = rendered(settled(), seconds: 32).left
        let music = zip(withMusic, without).map { $0 - $1 }.suffix(48_000 * 22)
        let dB = decibels(rms(music))
        print("SOUND music \(String(format: "%.1f", dB)) dBFS rms, peak \(String(format: "%.3f", music.map(abs).max() ?? 0))")
        XCTAssertGreaterThan(dB, -40, "The music should be heard")
        XCTAssertLessThan(dB, -24, "but leave the cues room")
        XCTAssertLessThan(withMusic.map(abs).max() ?? 0, 0.6)
    }

    func testTheSameSeedPlaysTheSameMusic() {
        let a = rendered(scored(.peace), seconds: 4), b = rendered(scored(.peace), seconds: 4)
        XCTAssertEqual(a.left, b.left)
        XCTAssertEqual(a.right, b.right)
    }
}

final class GreatHostSoundTests: XCTestCase {
    /// A great host's din has a weight a skirmish's has not: the throng's
    /// roar deep under the clamour, and war horns; it never clips.
    func testAGreatHostRoarsDeeperThanASkirmish() {
        func play(host: Float) -> [Float] {
            let synth = Synth()
            synth.prepare(sampleRate: 48_000)
            synth.settle()
            synth.setDin(level: 1, pan: 0)
            synth.setHost(host)
            return Array(rendered(synth, seconds: 8).left[(5 * 48_000)...])
        }
        let skirmish = play(host: 0), host = play(host: 1)
        func rms(_ x: [Float]) -> Float { (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot() }
        // The low band: a simple running mean keeps what lies below ~150 Hz.
        func low(_ x: [Float]) -> [Float] {
            var out: [Float] = [], y: Float = 0
            let a: Float = 1 - exp(-2 * .pi * 150 / 48_000)
            for v in x { y += (v - y) * a; out.append(y) }
            return out
        }
        XCTAssertGreaterThan(rms(low(host)), rms(low(skirmish)) * 1.5, "the throng's roar, deep under the clamour")
        XCTAssertLessThan(host.map(abs).max() ?? 0, 0.95, "and never clips")
    }

    /// War horns call across a great host's battle now and then: a horn as
    /// it was recorded, held and falling away, as loud as the horn of
    /// overtones it took over from (three partials, a twentieth of full),
    /// and never across a skirmish.
    func testWarHornsCallAcrossAGreatHost() {
        func din(host: Float, seconds: Float) -> Synth {
            let synth = Synth()
            synth.prepare(sampleRate: 48_000)
            synth.settle()
            synth.setDin(level: 1, pan: 0)
            synth.setHost(host)
            _ = rendered(synth, seconds: seconds)
            return synth
        }
        XCTAssertEqual(din(host: 1, seconds: 4).warHornsBlown, 1, "A war horn two seconds in")
        XCTAssertEqual(din(host: 0, seconds: 4).warHornsBlown, 0, "None across a skirmish")
        let rate: Float = 48_000
        let horn = Horns(sampleRate: rate)
        horn.blow(146.8, strength: 1, hold: Synth.warHornHeld)
        let blown = (0..<Int(1.2 * rate)).map { _ in horn.sample(dt: 1 / rate).left * Synth.warHornGain }
        let overtones = Float((1 + 0.25 + 0.09) / 2).squareRoot() * 0.05
        print("SOUND war horn \(decibels(rms(blown[Int(0.2 * rate)...]))) dB, the horn of overtones \(decibels(overtones)) dB")
        XCTAssertEqual(decibels(rms(blown[Int(0.2 * rate)...]) / overtones), 0, accuracy: 3)
    }
}
