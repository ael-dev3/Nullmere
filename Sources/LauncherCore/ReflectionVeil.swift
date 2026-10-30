/// How far an open panel has dimmed the moon's image in the lake.
///
/// A panel on the water veils the moon's reflection, dimming it to a ghost
/// of itself, so the panel's words lie on dark water and stars rather than
/// on a pale disc, while the moon is still given back; closing the panel
/// lets the image brighten again. The veil moves at an even pace between
/// 0 and 1 over `duration` seconds, and is drawn eased in and out.
public struct ReflectionVeil: Sendable, Equatable {
    public static let duration = 0.7

    public private(set) var value: Double

    public init(_ value: Double = 0) {
        self.value = min(max(value, 0), 1)
    }

    /// Moves toward `target` by `seconds` of the veil's pace. An infinite
    /// step, for a lake that isn't animating, settles it at once.
    public mutating func advance(toward target: Double, by seconds: Double) {
        let target = min(max(target, 0), 1)
        let reach = max(seconds, 0) / Self.duration
        if abs(target - value) <= reach {
            value = target
        } else {
            value += target > value ? reach : -reach
        }
    }

    /// The veil as the lake draws it: eased in and out.
    public var shown: Double {
        value * value * (3 - 2 * value)
    }
}
