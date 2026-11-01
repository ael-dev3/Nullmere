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
}
