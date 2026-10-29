import LauncherCore
import SwiftUI

/// The only thing the launcher offers until Apple's on-device model is
/// ready: what is missing, a way to fix it where there is one, and Quit.
/// It gives way to the menu by itself once the model is available.
struct RequirementPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        let actions = model.readiness.actions
        VStack(spacing: 0) {
            PanelHeader(title: model.readiness.headline)

            Text(verbatim: model.readiness.explanation)
                .font(.system(size: 13 * unit, weight: .light))
                .lineSpacing(6 * unit)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.68))
                .frame(maxWidth: 460 * unit)
                .fixedSize(horizontal: false, vertical: true)

            RequirementsLine(readiness: model.readiness)
                .padding(.top, 24 * unit)

            // One choice is lit at a time, and it is the one Return performs:
            // the pointer chooses by resting on a word, the arrows by moving.
            HStack(spacing: 48 * unit) {
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    MenuButton(title: action.title, isSelected: index == model.requirementSelection) {
                        model.perform(action)
                    }
                    .onPointer { inside in
                        if inside { model.requirementSelection = index }
                    }
                }
            }
            .padding(.top, 22 * unit)
        }
        .animation(.easeInOut(duration: 0.4), value: model.readiness)
    }
}

/// Apple silicon · macOS 26 · Apple Intelligence, each lit when met.
struct RequirementsLine: View {
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
