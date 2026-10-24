import SwiftUI

/// The title, resting above the far shore: NULLMERE set large and thin, and
/// ONLINE on its own line between two rules that reach the width of the word
/// above.
struct TitleBlock: View {
    /// Whether the title has faded in.
    var isRevealed: Bool
    /// Whether the letters draw together as the title appears.
    var settlesLetters: Bool

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        VStack(spacing: 4 * unit) {
            TitleWord(
                text: "NULLMERE",
                size: 92 * unit,
                tracking: isRevealed || !settlesLetters ? 0.40 : 0.62
            )
            .foregroundStyle(Palette.ink.opacity(0.96))
            .shadow(color: Palette.glow.opacity(0.42), radius: 26 * unit)
            .shadow(color: Palette.glow.opacity(0.28), radius: 3 * unit)

            HStack(spacing: 22 * unit) {
                TitleRule(fadesTowardLeading: true)
                SpacedText("Online", size: 23 * unit, weight: .light, tracking: 0.75)
                    .foregroundStyle(Palette.ink.opacity(0.84))
                    .shadow(color: Palette.glow.opacity(0.35), radius: 14 * unit)
                TitleRule(fadesTowardLeading: false)
            }
        }
        // The stack takes the width of the title word, and the rules stretch
        // to fill it.
        .fixedSize()
        .opacity(isRevealed ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nullmere Online")
        .accessibilityAddTraits(.isHeader)
    }
}

/// A hairline that fills its width and fades away from the word it frames.
private struct TitleRule: View {
    var fadesTowardLeading: Bool

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let line = Palette.ink.opacity(0.42)
        LinearGradient(
            colors: fadesTowardLeading ? [.clear, line] : [line, .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1 / displayScale)
        .frame(maxWidth: .infinity)
    }
}
