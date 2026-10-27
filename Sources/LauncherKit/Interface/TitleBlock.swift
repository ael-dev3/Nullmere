import LauncherCore
import SwiftUI

/// The title, resting above the far shore: NULLMERE ONLINE, set wide and
/// thin on a single line, and nothing else.
struct TitleBlock: View {
    /// Whether the title has faded in.
    var isRevealed: Bool
    /// Whether the letters draw together as the title appears.
    var settlesLetters: Bool

    @Environment(\.launcherUnit) private var unit

    /// The words, exactly.
    static let text = "NULLMERE ONLINE"

    var body: some View {
        TitleWord(
            text: TitleBlock.text,
            size: 60 * unit,
            tracking: isRevealed || !settlesLetters ? 0.32 : 0.5
        )
        .foregroundStyle(Palette.ink.opacity(0.96))
        .shadow(color: Palette.glow.opacity(0.42), radius: 26 * unit)
        .shadow(color: Palette.glow.opacity(0.28), radius: 3 * unit)
        .opacity(isRevealed ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nullmere Online")
        .accessibilityAddTraits(.isHeader)
    }
}

/// The title as the launcher sets it, sized and placed for a window of
/// `size`, resting above the far shore. Every screen on the lake (the
/// launcher, the realm's front door, the model's gate) sets the title
/// through this, so the name never moves or changes between them.
public struct LakeTitle: View {
    let size: CGSize
    var isRevealed: Bool
    var settlesLetters: Bool

    public init(size: CGSize, isRevealed: Bool = true, settlesLetters: Bool = false) {
        self.size = size
        self.isRevealed = isRevealed
        self.settlesLetters = settlesLetters
    }

    /// The scale of the launcher's type for a window of this size.
    public static func unit(for size: CGSize) -> CGFloat {
        CGFloat(LakeComposition.unit(width: size.width, height: size.height))
    }

    /// Where the water begins, from the window's top.
    public static func waterline(for size: CGSize) -> CGFloat {
        CGFloat(LakeComposition.waterline(forHeight: size.height))
    }

    /// The height of the band the title rests at the foot of.
    public static func band(for size: CGSize) -> CGFloat {
        max(waterline(for: size) - 46 * unit(for: size), 0)
    }

    public var body: some View {
        TitleBlock(isRevealed: isRevealed, settlesLetters: settlesLetters)
            .frame(maxWidth: .infinity)
            .frame(height: LakeTitle.band(for: size), alignment: .bottom)
            .environment(\.launcherUnit, LakeTitle.unit(for: size))
    }
}
