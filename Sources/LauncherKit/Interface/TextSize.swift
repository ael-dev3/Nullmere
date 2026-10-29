import Foundation
import Observation
import SwiftUI

/// The size of the type, in the launcher and in the realm alike: Standard,
/// or Larger for those who want it bigger. The launcher's type and the
/// realm's `Font.nm` both read it, so changing it redraws them all.
@MainActor
@Observable
public final class TextSize {
    public static let shared = TextSize()

    public static let largerScale: CGFloat = 1.22
    /// The least size any text takes with Larger type.
    public static let smallestLarger: CGFloat = 11
    /// The least size any text takes at all: the smallest captions still read.
    public static let smallest: CGFloat = 8

    public var isLarger: Bool = UserDefaults.standard.bool(forKey: "text.larger") {
        didSet { UserDefaults.standard.set(isLarger, forKey: "text.larger") }
    }

    public var scale: CGFloat { isLarger ? TextSize.largerScale : 1 }

    /// A size of type as it is drawn: scaled by the reader's choice, and
    /// never under the least that reads.
    public func size(_ size: CGFloat) -> CGFloat {
        max(size * scale, isLarger ? TextSize.smallestLarger : TextSize.smallest)
    }

    init() {
        #if DEBUG
        // For the smoke test: show the larger type without remembering it.
        if ProcessInfo.processInfo.environment["NULLMERE_TEXT"] == "larger" { isLarger = true }
        #endif
    }
}
