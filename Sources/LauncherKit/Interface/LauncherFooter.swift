import LauncherCore
import SwiftUI

/// The on-device model's status on the left, the website and version on the
/// right, and a keyboard hint between them while it helps.
struct LauncherFooter: View {
    let version: String
    let readiness: ModelReadiness
    let hint: String?
    let openWebsite: () -> Void

    @Environment(\.launcherUnit) private var unit
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 10 * unit) {
                    StatusDot(isLit: readiness.allowsPlay)
                    SpacedText(readiness.status, size: 9.5 * unit, weight: .light, tracking: 0.3)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(readiness.status)
                .animation(.easeInOut(duration: 0.4), value: readiness)

                Spacer(minLength: 24 * unit)

                let _ = PressableButtons.note("nullmere.online", enabled: true, openWebsite)
                Button(action: openWebsite) {
                    SpacedText("nullmere.online", size: 9.5 * unit, weight: .light, tracking: 0.3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .linkPointer()
                .accessibilityLabel("Open nullmere.online")

                SpacedText(version, size: 9.5 * unit, weight: .light, tracking: 0.3)
                    .padding(.leading, 16 * unit)
                    .accessibilityLabel("Version \(version)")
            }
            if let hint {
                SpacedText(hint, size: 9.5 * unit, weight: .light, tracking: 0.3)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(Palette.ink.opacity(contrast == .increased ? 0.7 : 0.38))
        .padding(.horizontal, 36 * unit)
        .padding(.bottom, 26 * unit)
    }
}
