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
    public static let smallestLarger: CGFloat = 12.5
    /// The least size the realm's spaced capitals take: their strokes all
    /// full height, they read smaller than words in lower case.
    public static let smallest: CGFloat = 9.5
    /// The least size the realm's words in lower case take, whose full
    /// stops, commas and dots are a pixel or two across on a 1x display.
    public static let smallestWords: CGFloat = 11
    /// The least size the launcher's type takes, however small its window.
    public static let smallestLauncher: CGFloat = 10.5

    /// A weight that holds its contrast at a size: thin type is for display
    /// sizes only; below 14 points nothing is thinner than regular, and
    /// below 12 nothing lighter than medium, so even the smallest strokes
    /// and dots cover whole pixels.
    public nonisolated static func readable(_ weight: Font.Weight, at size: CGFloat) -> Font.Weight {
        let order: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        let least: Font.Weight = size < 12 ? .medium : size < 14 ? .regular : .ultraLight
        let asked = order.firstIndex(of: weight) ?? 3
        let floor = order.firstIndex(of: least) ?? 0
        return order[Swift.max(asked, floor)]
    }

    public var isLarger: Bool = UserDefaults.standard.bool(forKey: "text.larger") {
        didSet { UserDefaults.standard.set(isLarger, forKey: "text.larger") }
    }

    public var scale: CGFloat { isLarger ? TextSize.largerScale : 1 }

    /// A size of type as it is drawn: scaled by the reader's choice, and
    /// never under the least that reads (`words` for lower case).
    public func size(_ size: CGFloat, words: Bool = false) -> CGFloat {
        let least = isLarger ? TextSize.smallestLarger : (words ? TextSize.smallestWords : TextSize.smallest)
        return max(size * scale, least)
    }

    init() {
        #if DEBUG
        // For the smoke test: show the larger type without remembering it.
        if ProcessInfo.processInfo.environment["NULLMERE_TEXT"] == "larger" { isLarger = true }
        #endif
    }
}
