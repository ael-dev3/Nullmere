import Foundation

public extension Clip {
    /// How long a round of the clip lasts, in seconds, the same for every
    /// model. Idle, march, attack and gather loop with this period: a
    /// model at `t` stands as it does at `t + period`, so the renderer can
    /// phase figures by adding a fraction of it. The death plays once over
    /// this time and then lies still, its last moment held.
    var period: Float {
        switch self {
        case .idle: return 4
        case .march: return 1
        case .attack: return 1.5
        case .death: return 1.5
        case .gather: return 2
        case .hit: return 1.5
        }
    }

    /// Whether it plays over and over; the death plays once.
    var loops: Bool { self != .death }

    /// How far into the clip a moment lies, 0 up to 1: taken round for a
    /// looping clip, held at its ends for the death.
    func progress(at time: Float) -> Float {
        let u = time / period
        guard u.isFinite else { return 0 }
        if loops { return u - u.rounded(.down) }
        return min(max(u, 0), 1)
    }
}
