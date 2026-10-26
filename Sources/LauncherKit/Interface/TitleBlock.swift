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
