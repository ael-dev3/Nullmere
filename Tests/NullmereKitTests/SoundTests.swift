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
        for cue in [Ambience.Cue.select, .order, .battle, .watch, .rise, .dread] {
            let plain = settled()
            let cued = settled()
            _ = render(plain, seconds: 1)
            _ = render(cued, seconds: 1)
            cued.trigger(cue)
            let a = render(plain, seconds: 0.4)
            let b = render(cued, seconds: 0.4)
            let peak = zip(a, b).map { abs($1 - $0) }.max() ?? 0
            report.append("\(cue) \(String(format: "%+.1f", 20 * log10(peak / bedLevel))) dB")
            XCTAssertGreaterThan(peak, bedLevel * 1.7, "\(cue) must stand out from the bed")
        }
        print("SOUND cues over the bed: " + report.joined(separator: ", "))
    }

    func testNothingClipsEvenWithEveryCueAtOnce() {
        let synth = settled()
        _ = render(synth, seconds: 1)
        for cue in [Ambience.Cue.select, .order, .battle, .watch, .rise, .dread] { synth.trigger(cue) }
        let burst = render(synth, seconds: 3)
        let peak = burst.map(abs).max() ?? 0
        print("SOUND every cue at once peaks at \(String(format: "%.3f", peak))")
        XCTAssertLessThan(peak, 0.8)
        XCTAssertFalse(burst.contains { $0.isNaN || $0.isInfinite })
    }
}
