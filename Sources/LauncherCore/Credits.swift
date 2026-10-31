/// The credits the launcher rolls: who made Nullmere Online, with what, and
/// under what licence, in the order they roll.
public enum Credits {
    public struct Line: Equatable, Sendable {
        public enum Kind: Sendable {
            /// The game's name, at the head.
            case title
            /// What the lines after it are, in small capitals.
            case heading
            /// A name or a short line under a heading.
            case entry
        }

        public let kind: Kind
        public let text: String

        public init(_ kind: Kind, _ text: String) {
            self.kind = kind
            self.text = text
        }
    }

    public static let lines: [Line] = [
        Line(.title, "Nullmere Online"),
        Line(.heading, "Made by"),
        Line(.entry, "ael, with Claude"),
        Line(.heading, "The world"),
        Line(.entry, "The lake, the moon, every model, sound and tune, made in code for this game alone"),
        Line(.heading, "The voices"),
        Line(.entry, "Apple's on-device model, on each keeper's own Mac"),
        Line(.heading, "The realm"),
        Line(.entry, "Kept by SpacetimeDB, played by the same Swift rules on every Mac and in the realm"),
        Line(.heading, "Made with"),
        Line(.entry, "Swift, SwiftUI and Metal"),
        Line(.heading, "Licence"),
        Line(.entry, "The code under the Apache License 2.0"),
        Line(.entry, "The art and the words dedicated to the public domain under CC0 1.0"),
        Line(.heading, "And"),
        Line(.entry, "Every keeper who has kept a House on the lake"),
    ]

    /// How fast the credits roll, in points a second at the launcher's own
    /// size, and the pause at the head before they begin and again at the end.
    public static let rollSpeed = 16.0
    public static let rollPause = 2.0

    /// How far the credits have rolled at a moment, for a roll of a height
    /// through a window of a height: still for the pause, then up at the
    /// roll's speed until the last line has passed, still again, and round.
    public static func offset(at seconds: Double, rollHeight: Double, windowHeight: Double, unit: Double = 1) -> Double {
        let distance = max(rollHeight + windowHeight, 0)
        let speed = rollSpeed * max(unit, 0.1)
        let cycle = rollPause * 2 + distance / speed
        guard cycle > 0, distance > 0 else { return 0 }
        let t = seconds.truncatingRemainder(dividingBy: cycle)
        if t < rollPause { return 0 }
        return min((t - rollPause) * speed, distance)
    }
}
