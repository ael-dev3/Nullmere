import LauncherCore
import SwiftUI

/// What Play says when it can't cross yet: why this Mac isn't ready, or that
/// the first realm hasn't opened.
struct PlayPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @State private var hovered: Action?

    private enum Action {
        case settings
        case website
        case back
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: headline)

            Text(verbatim: explanation)
                .font(.system(size: 13 * unit, weight: .light))
                .lineSpacing(6 * unit)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.68))
                .frame(maxWidth: 460 * unit)
                .fixedSize(horizontal: false, vertical: true)

            RequirementsLine(readiness: model.readiness)
                .padding(.top, 24 * unit)

            HStack(spacing: 48 * unit) {
                if model.readiness.isFixedInSystemSettings {
                    MenuButton(title: "Open System Settings", isSelected: hovered == .settings) {
                        // System Settings comes to the front before the pointer
                        // leaves the button, so the hover never ends by itself.
                        hovered = nil
                        model.openAppleIntelligenceSettings()
                    }
                    .onHover { hovered = $0 ? .settings : nil }
                } else if model.readiness.allowsPlay {
                    MenuButton(title: "nullmere.online", isSelected: hovered == .website) {
                        model.openWebsite()
                    }
                    .onHover { hovered = $0 ? .website : nil }
                }
                // Return answers the Return key, so it shows as chosen until
                // the pointer picks something else.
                MenuButton(title: "Return", isSelected: hovered == nil || hovered == .back) {
                    model.returnToTitle()
                }
                .onHover { hovered = $0 ? .back : nil }
            }
            .padding(.top, 22 * unit)
        }
        .animation(.easeInOut(duration: 0.4), value: model.readiness)
    }

    private var headline: String {
        guard model.readiness.allowsPlay else { return model.readiness.headline }
        return model.gameFailedToOpen ? "The crossing failed" : "The shore is quiet"
    }

    private var explanation: String {
        guard model.readiness.allowsPlay else { return model.readiness.explanation }
        if model.gameFailedToOpen {
            return "The Nullmere game is installed but didn't open. Try Play again, or reinstall the game."
        }
        return "This Mac is ready: Apple's on-device model is here. The first realm hasn't opened yet; when it does, Play will cross from here."
    }
}

/// Apple silicon · macOS 26 · Apple Intelligence, each lit when met.
private struct RequirementsLine: View {
    let readiness: ModelReadiness

    @Environment(\.launcherUnit) private var unit

    /// The launcher is built only for Apple silicon, but `swift run` on an
    /// Intel Mac builds for the host.
    private static let isAppleSilicon: Bool = {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }()

    var body: some View {
        HStack(spacing: 28 * unit) {
            requirement("Apple silicon", isMet: Self.isAppleSilicon)
            // The launcher's minimum macOS version is 26, so this always holds.
            requirement("macOS 26", isMet: true)
            requirement("Apple Intelligence", isMet: readiness.allowsPlay)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func requirement(_ title: String, isMet: Bool) -> some View {
        HStack(spacing: 8 * unit) {
            StatusDot(isLit: isMet)
            SpacedText(title, size: 9 * unit, weight: .regular, tracking: 0.3)
                .foregroundStyle(Palette.ink.opacity(isMet ? 0.72 : 0.42))
        }
    }

    private var accessibilityText: String {
        let silicon = Self.isAppleSilicon ? "Apple silicon: yes" : "Apple silicon: no"
        let intelligence = readiness.allowsPlay ? "Apple Intelligence: ready" : "Apple Intelligence: \(readiness.status)"
        return "\(silicon). macOS 26: yes. \(intelligence)."
    }
}
