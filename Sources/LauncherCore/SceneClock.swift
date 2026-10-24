/// Animation time for the backdrop.
///
/// The clock advances at a rate set by the motion preference, so slowing or
/// stopping motion never makes the scene jump, and long gaps between frames
/// (sleep, a hidden window) are not replayed.
public struct SceneClock: Sendable {
    /// The longest real-time step the clock accepts between two frames.
    public static let maximumStep = 0.1

    public private(set) var time: Double
    private var lastTimestamp: Double?

    public init(time: Double = 0) {
        self.time = time
    }

    /// Advances to `timestamp` (seconds, monotonic) at `rate` and returns the scene time.
    @discardableResult
    public mutating func advance(to timestamp: Double, rate: Double) -> Double {
        if let lastTimestamp {
            let step = min(max(timestamp - lastTimestamp, 0), Self.maximumStep)
            time += step * max(rate, 0)
        }
        lastTimestamp = timestamp
        return time
    }

    /// Forgets the previous timestamp, so the next frame starts a new interval.
    public mutating func resetInterval() {
        lastTimestamp = nil
    }
}
