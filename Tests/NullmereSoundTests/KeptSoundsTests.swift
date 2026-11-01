import Foundation
import XCTest
import NullmereCore
@testable import NullmereSound

/// Sixteen-bit stereo PCM, as a WAVE file holds it.
func wave(_ sound: (left: [Float], right: [Float]), rate: Float) -> Data {
    var data = Data()
    func put<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let frames = min(sound.left.count, sound.right.count)
    data.append(contentsOf: Array("RIFF".utf8))
    put(UInt32(36 + frames * 4))
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    put(UInt32(16))
    put(UInt16(1))
    put(UInt16(2))
    put(UInt32(rate))
    put(UInt32(rate) * 4)
    put(UInt16(4))
    put(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    put(UInt32(frames * 4))
    for frame in 0..<frames {
        for sample in [sound.left[frame], sound.right[frame]] {
            put(Int16((min(max(sample, -1), 1) * 32_767).rounded()))
        }
    }
    return data
}

/// The score's themes and every cue, kept as sound files to be listened to
/// when NULLMERE_KEEP_RENDERS names a folder: CI keeps them with its run.
final class KeptSoundsTests: XCTestCase {
    func testAWaveHoldsWhatWasRendered() {
        let data = wave(([0, 1, -1, 2], [0.5, -0.5, 0, -2]), rate: 44_100)
        XCTAssertEqual(data.count, 44 + 4 * 4)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<16], as: UTF8.self), "WAVEfmt ")
        let samples = data[44...].withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }.map { Int16(littleEndian: $0) }
        XCTAssertEqual(samples, [0, 16_384, 32_767, -16_384, -32_767, 0, 32_767, -32_767])
    }

    func testTheScoreAndTheCuesAreKeptToListenTo() throws {
        guard let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] else { return }
        let folder = URL(fileURLWithPath: path).appendingPathComponent("sounds")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let rate: Float = 44_100
        let moods: [(String, Score.Mood)] = [("peace", .peace), ("war", .war), ("eclipse", .eclipse)] + Lake.allCases.map { ("title-\($0)", .title($0)) }
        for (name, mood) in moods {
            let synth = Synth()
            synth.prepare(sampleRate: rate)
            synth.settle()
            synth.setMusic(on: true, mood: mood)
            try wave(rendered(synth, seconds: 20, rate: rate), rate: rate).write(to: folder.appendingPathComponent("score-\(name).wav"))
        }
        // Every cue in turn over the night, a second and a half apart.
        let synth = Synth()
        synth.prepare(sampleRate: rate)
        synth.settle()
        var cues: (left: [Float], right: [Float]) = ([], [])
        for cue in SoundCue.all {
            synth.trigger(cue)
            let heard = rendered(synth, seconds: 1.5, rate: rate)
            cues.left += heard.left
            cues.right += heard.right
        }
        try wave(cues, rate: rate).write(to: folder.appendingPathComponent("cues.wav"))
        print("SOUND kept \(moods.count + 1) sound files in \(folder.path)")
    }
}
