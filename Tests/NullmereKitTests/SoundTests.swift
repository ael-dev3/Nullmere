import AVFoundation
import XCTest
@testable import NullmereKit

/// The game's sound, rendered offline and measured: the bed of drone and
/// wind sits quietly, every cue is clearly heard above it, and nothing
/// clips, even with every cue at once.
final class SoundTests: XCTestCase {
    static let rate: Float = 48_000

    /// Renders `seconds` of sound, after `cue` (if any) is triggered, and
    /// returns the left channel.
    private func render(_ synth: Synth, seconds: Float) -> [Float] {
        let frames = Int(seconds * Self.rate)
        let chunk = 512
        var out: [Float] = []
        out.reserveCapacity(frames)
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        let left = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
        defer { left.deallocate(); right.deallocate() }
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: left)
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: right)
        var done = 0
        while done < frames {
            let n = min(chunk, frames - done)
            synth.render(frames: n, into: list)
            out.append(contentsOf: UnsafeBufferPointer(start: left, count: n))
            done += n
        }
        return out
    }

    private func settled() -> Synth {
        let synth = Synth()
        synth.prepare(sampleRate: Self.rate)
        synth.settle()
        return synth
    }

    private func rms(_ x: ArraySlice<Float>) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
    }

    func testTheBedIsQuietButThere() {
        let bed = render(settled(), seconds: 8)
        let level = rms(bed[...])
        let dB = 20 * log10(level)
        print("SOUND bed \(String(format: "%.1f", dB)) dBFS rms, peak \(String(format: "%.3f", bed.map(abs).max() ?? 0))")
        XCTAssertGreaterThan(dB, -40, "The night should be heard")
        XCTAssertLessThan(dB, -22, "but stay beneath everything else")
    }

    /// Two synthesisers render identical beds, so the difference is the cue.
    func testEveryCueIsHeardAboveTheBed() {
        let bedLevel = rms(render(settled(), seconds: 4)[...])
        var report: [String] = []
        for cue in Ambience.Cue.all {
            let plain = settled()
            let cued = settled()
            _ = render(plain, seconds: 1)
            _ = render(cued, seconds: 1)
            cued.trigger(cue)
            let a = render(plain, seconds: 1.0)
            let b = render(cued, seconds: 1.0)
            let peak = zip(a, b).map { abs($1 - $0) }.max() ?? 0
            report.append("\(cue) \(String(format: "%+.1f", 20 * log10(peak / bedLevel))) dB")
            XCTAssertGreaterThan(peak, bedLevel * 1.7, "\(cue) must stand out from the bed")
        }
        print("SOUND cues over the bed: " + report.joined(separator: ", "))
    }

    /// The night's slow swells read a clock that keeps moving however long
    /// the keeper stays: a single-precision clock stood still after eight
    /// and a half minutes, and the drone and the wind with it.
    func testTheNightKeepsMovingLongAfterEightMinutes() {
        let synth = settled()
        synth.advanceClock(by: 3_600)
        _ = render(synth, seconds: 1)
        XCTAssertEqual(synth.clock, 3_601, accuracy: 0.001, "An hour in, a second of sound is a second on its clock")
    }

    /// The wind sounds the same at any sample rate the Mac runs at: its
    /// filter's corner is set in hertz, and its noise scaled to the rate.
    func testTheBedSoundsTheSameAtAnySampleRate() {
        func bed(at rate: Float) -> Float {
            let synth = Synth()
            synth.prepare(sampleRate: rate)
            synth.settle()
            let frames = Int(6 * rate), chunk = 512
            let list = AudioBufferList.allocate(maximumBuffers: 2)
            defer { free(list.unsafeMutablePointer) }
            let left = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
            let right = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
            defer { left.deallocate(); right.deallocate() }
            list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: left)
            list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: right)
            var sum: Float = 0
            var done = 0
            while done < frames {
                let n = min(chunk, frames - done)
                synth.render(frames: n, into: list)
                for i in 0..<n { sum += left[i] * left[i] }
                done += n
            }
            return (sum / Float(frames)).squareRoot()
        }
        let usual = bed(at: 48_000), finer = bed(at: 96_000), coarser = bed(at: 44_100)
        XCTAssertEqual(20 * log10(finer / usual), 0, accuracy: 1.5, "At 96 kHz as at 48")
        XCTAssertEqual(20 * log10(coarser / usual), 0, accuracy: 1.5, "and at 44.1")
    }

    /// A cue asked to wait waits: a watch's sounds follow its bell one by
    /// one. And a long toll rings out whole, well past eight seconds.
    func testACueWaitsItsTurnAndATollRingsOut() {
        let plain = settled(), cued = settled()
        cued.trigger(.select, after: 0.5)
        let before = zip(render(plain, seconds: 0.45), render(cued, seconds: 0.45)).map { abs($1 - $0) }.max() ?? 0
        let after = zip(render(plain, seconds: 0.3), render(cued, seconds: 0.3)).map { abs($1 - $0) }.max() ?? 0
        XCTAssertLessThan(before, 0.0001, "Silent until its turn")
        XCTAssertGreaterThan(after, 0.01, "then heard")

        let tolled = settled()
        tolled.trigger(.toll)
        _ = render(tolled, seconds: 9)
        XCTAssertEqual(tolled.sounding, 1, "Nine seconds on, the toll still rings")
        _ = render(tolled, seconds: 32)
        XCTAssertEqual(tolled.sounding, 0, "and is let go once it has died away")
    }

    /// The sum is kept under full scale without a hard edge: untouched
    /// while quiet, rounded off above three quarters, the same either way.
    func testTheSumIsSoftenedNotClipped() {
        XCTAssertEqual(Synth.softened(0.5), 0.5)
        XCTAssertEqual(Synth.softened(-0.7), -0.7)
        XCTAssertLessThan(Synth.softened(1.5), 1)
        XCTAssertLessThan(Synth.softened(3), 1)
        XCTAssertGreaterThan(Synth.softened(3), Synth.softened(1.5), "Louder still sounds louder")
        XCTAssertEqual(Synth.softened(-1.2), -Synth.softened(1.2))
        XCTAssertEqual(Synth.softened(0.75), 0.75, accuracy: 0.0001, "No step at the knee")
        XCTAssertEqual(Synth.softened(0.7501), 0.7501, accuracy: 0.0002)
    }

    func testNothingClipsEvenWithEveryCueAtOnce() {
        let synth = settled()
        // The war's score playing beneath, the loudest the sound gets.
        synth.setMusic(on: true, mood: .war)
        _ = render(synth, seconds: 4)
        // Every cue within a few milliseconds, each taken up before the
        // next, so none is dropped for a full queue.
        var burst: [Float] = []
        for cue in Ambience.Cue.all {
            synth.trigger(cue)
            burst += render(synth, seconds: 0.005)
        }
        burst += render(synth, seconds: 3)
        let peak = burst.map(abs).max() ?? 0
        print("SOUND every cue at once peaks at \(String(format: "%.3f", peak))")
        XCTAssertLessThan(peak, 0.8)
        XCTAssertFalse(burst.contains { $0.isNaN || $0.isInfinite })
    }
}

/// The score, rendered offline: present beneath the cues, in its key,
/// moving, and at war joined by a drum.
final class MusicTests: XCTestCase {
    private func render(_ synth: Synth, seconds: Float) -> [Float] {
        let frames = Int(seconds * 48_000)
        let chunk = 1024
        var out: [Float] = []
        out.reserveCapacity(frames)
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        let left = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
        defer { left.deallocate(); right.deallocate() }
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: left)
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: right)
        var done = 0
        while done < frames {
            let n = min(chunk, frames - done)
            synth.render(frames: n, into: list)
            out.append(contentsOf: UnsafeBufferPointer(start: left, count: n))
            done += n
        }
        return out
    }

    private func synth(music: Bool, mood: Score.Mood = .peace) -> Synth {
        let synth = Synth()
        synth.prepare(sampleRate: 48_000)
        synth.settle()
        synth.setMusic(on: music, mood: mood)
        return synth
    }

    func testTheScoreSitsBeneathTheCuesAndAboveSilence() {
        let withMusic = render(synth(music: true), seconds: 60)
        let without = render(synth(music: false), seconds: 60)
        let music = zip(withMusic, without).map { $0 - $1 }.suffix(48_000 * 40)
        let rms = (music.reduce(0) { $0 + $1 * $1 } / Float(music.count)).squareRoot()
        let dB = 20 * log10(rms)
        print("SOUND music \(String(format: "%.1f", dB)) dBFS rms, peak \(String(format: "%.3f", music.map(abs).max() ?? 0))")
        XCTAssertGreaterThan(dB, -40, "The music should be heard")
        XCTAssertLessThan(dB, -24, "but leave the cues room")
        XCTAssertLessThan(withMusic.map(abs).max() ?? 0, 0.6)
    }

    func testTheScoreKeepsItsKeyAndMoves() {
        let s = synth(music: true)
        _ = render(s, seconds: 90)
        let score = s.scoreSnapshot
        XCTAssertGreaterThanOrEqual(score.playedNotes.count, 8)
        XCTAssertTrue(score.playedNotes.allSatisfy(Score.melody.contains), "Every note is in D minor pentatonic")
        XCTAssertGreaterThan(Set(score.playedNotes).count, 3, "The melody wanders")
        XCTAssertGreaterThanOrEqual(score.chordChanges, 5)
        XCTAssertEqual(score.drumStrokes, 0, "No drum in peace")
    }

    func testWarBringsTheDrum() {
        let s = synth(music: true, mood: .war)
        _ = render(s, seconds: 30)
        XCTAssertGreaterThanOrEqual(s.scoreSnapshot.drumStrokes, 10)
    }

    func testTheSameSeedPlaysTheSameMusic() {
        let a = synth(music: true), b = synth(music: true)
        XCTAssertEqual(render(a, seconds: 20), render(b, seconds: 20))
    }
}
