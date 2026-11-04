import Foundation

/// Frame times taken over several passes of the same frames: what the
/// stage's own work costs is what every pass pays, so each frame's
/// steadiest time is kept and a moment's interruption in one pass is not.
enum StagingTimes {
    /// Each frame's least time over the passes, frame by frame.
    static func steadiest(_ passes: [[Double]]) -> [Double] {
        guard let first = passes.first else { return [] }
        return first.indices.map { frame in passes.map { $0[frame] }.min() ?? first[frame] }
    }

    /// The time below which `share` of the frames fall: the median at a
    /// half, the slowest twentieth's floor at 0.95.
    static func percentile(_ times: [Double], _ share: Double) -> Double {
        let sorted = times.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[min(Int(Double(sorted.count) * share), sorted.count - 1)]
    }

    /// The four slowest frames of a pass, by their place in it.
    static func slowest(_ times: [Double]) -> String {
        times.enumerated().sorted { $0.element > $1.element }.prefix(4)
            .map { "frame \($0.offset + 1) \(String(format: "%.2f", $0.element))" }.joined(separator: ", ")
    }

    /// One round of the calibration's plain work (NullmereCoreTests'
    /// CalibrationTests.plainWork, the same code): numbers drawn, sorted,
    /// counted and folded, none of it the game's.
    static func plainWork(seed: UInt64) -> Int {
        var state = 0x9E37_79B9_7F4A_7C15 &+ seed
        var numbers: [Int] = []
        numbers.reserveCapacity(40_000)
        for _ in 0..<40_000 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            numbers.append(Int(truncatingIfNeeded: state >> 33) % 10_000)
        }
        numbers.sort()
        var counts: [Int: Int] = [:]
        for number in numbers { counts[number, default: 0] += 1 }
        var fold = 0.0
        for (key, count) in counts.sorted(by: { $0.key < $1.key }) {
            fold += sin(Double(key)) * Double(count)
        }
        return Int(fold * 1_000) ^ counts.count
    }
}
