import SwiftUI

/// "NULLMERE", a hairline, and "ONLINE", resting just above the far shore.
struct TitleBlock: View {
    /// Whether the title has faded in.
    var isRevealed: Bool
    /// Whether the letters draw together as the title appears.
    var settlesLetters: Bool

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        VStack(spacing: 0) {
            TitleWord(
                text: "NULLMERE",
                size: 50 * unit,
                tracking: isRevealed || !settlesLetters ? 0.62 : 0.9
            )
            .foregroundStyle(Palette.ink.opacity(0.95))
            .shadow(color: Palette.glow.opacity(0.45), radius: 18 * unit)
            .shadow(color: Palette.glow.opacity(0.3), radius: 2 * unit)

            Hairline(width: 64 * unit)
                .padding(.top, 18 * unit)
                .padding(.bottom, 14 * unit)

            SpacedText("Online", size: 10.5 * unit, weight: .light, tracking: 1.1)
                .foregroundStyle(Palette.ink.opacity(0.62))
        }
        .opacity(isRevealed ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nullmere Online")
        .accessibilityAddTraits(.isHeader)
    }
}
