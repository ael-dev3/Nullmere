import SwiftUI

/// Version on the left, the website on the right, and a keyboard hint
/// between them while it is useful.
struct LauncherFooter: View {
    let version: String
    let hint: String?
    let openWebsite: () -> Void

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        ZStack {
            HStack(alignment: .firstTextBaseline) {
                SpacedText(version, size: 9.5 * unit, weight: .light, tracking: 0.32)
                    .accessibilityLabel("Version \(version)")
                Spacer()
                Button(action: openWebsite) {
                    SpacedText("nullmere.online", size: 9.5 * unit, weight: .light, tracking: 0.32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open nullmere.online")
            }
            if let hint {
                SpacedText(hint, size: 9.5 * unit, weight: .light, tracking: 0.32)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(Palette.ink.opacity(0.34))
        .padding(.horizontal, 36 * unit)
        .padding(.bottom, 26 * unit)
    }
}
