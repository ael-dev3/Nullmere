/// Animation time for the backdrop.
///
/// The clock advances at a rate set by the motion preference, so slowing or
/// stopping motion never makes the scene jump, and long gaps between frames
/// (sleep, a hidden window) are not replayed.
public struct SceneClock: Sendable {
    /// The longest real-time step the clock accepts between two frames.
    public static let maximumStep = 0.1

    /// Scene time starts over after this many seconds, nearly three hours.
    /// The shader reads time as a 32-bit float, which is precise to about a
    /// millisecond up to here; starting over keeps the lake smooth however
    /// long the launcher stays open. It is a whole number of the falling
    /// star's 47-second chances and the moon's 9-second breath, so neither
    /// jumps as it starts over.
    public static let period: Double = 47 * 9 * 25

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
            time = (time + step * max(rate, 0)).truncatingRemainder(dividingBy: Self.period)
        }
        lastTimestamp = timestamp
        return time
    }

    /// Forgets the previous timestamp, so the next frame starts a new interval.
    public mutating func resetInterval() {
        lastTimestamp = nil
    }
}
