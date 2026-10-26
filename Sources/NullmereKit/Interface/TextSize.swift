import Foundation
import Observation
import SwiftUI

/// The size of the interface's type: Standard, or Larger for those who
/// want it bigger. Every label reads it through `Font.nm`, so changing it
/// redraws them all.
@MainActor
@Observable
public final class TextSize {
    public static let shared = TextSize()

    public static let largerScale: CGFloat = 1.22

    public var isLarger: Bool = UserDefaults.standard.bool(forKey: "text.larger") {
        didSet { UserDefaults.standard.set(isLarger, forKey: "text.larger") }
    }

    public var scale: CGFloat { isLarger ? TextSize.largerScale : 1 }

    init() {
        #if DEBUG
        // For the smoke test: show the larger type without remembering it.
        if ProcessInfo.processInfo.environment["NULLMERE_TEXT"] == "larger" { isLarger = true }
        #endif
    }
}

extension Font {
    /// The interface's type at a size, scaled by the reader's choice.
    @MainActor
    static func nm(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * TextSize.shared.scale, weight: weight)
    }
}
