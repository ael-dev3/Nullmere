import SwiftUI

/// What Play shows until the first realm opens.
struct PlayPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        VStack(spacing: 0) {
            SpacedText("The shore is quiet", size: 11 * unit, weight: .regular, tracking: 0.8)
                .foregroundStyle(Palette.ink.opacity(0.75))
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: "Nullmere has not opened yet. The first realm is still being shaped; when it opens, you will cross from here.")
                .font(.system(size: 13 * unit, weight: .light))
                .lineSpacing(7 * unit)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.6))
                .frame(maxWidth: 420 * unit)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24 * unit)

            Button {
                model.openWebsite()
            } label: {
                SpacedText("nullmere.online", size: 10 * unit, weight: .regular, tracking: 0.4)
                    .foregroundStyle(Palette.glow.opacity(0.85))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open nullmere.online")
            .padding(.top, 22 * unit)

            MenuRow(title: "Return", isSelected: true) {
                model.returnToTitle()
            }
            .padding(.top, 36 * unit)
        }
    }
}
