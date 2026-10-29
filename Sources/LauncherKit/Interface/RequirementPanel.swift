import LauncherCore
import SwiftUI

/// The only thing the launcher offers until Apple's on-device model is
/// ready: what is missing, a way to fix it where there is one, and Quit.
/// It gives way to the menu by itself once the model is available.
struct RequirementPanel: View {
    let model: LauncherModel

    var body: some View {
        let actions = model.readiness.actions
        RequirementView(readiness: model.readiness, choices: actions.map(\.title),
                        selection: Bindable(model).requirementSelection) { index in
            model.perform(actions[index])
        }
    }
}

/// What is missing, as the launcher shows it on the water: the heading, the
/// explanation, the requirements each lit when met, and a row of choices,
/// one lit at a time, the one Return performs. The realm's gate shows the
/// same, with its own choices.
public struct RequirementView: View {
    let readiness: ModelReadiness
    let choices: [String]
    @Binding var selection: Int
    let choose: (Int) -> Void

    @Environment(\.launcherUnit) private var unit

    public init(readiness: ModelReadiness, choices: [String], selection: Binding<Int>, choose: @escaping (Int) -> Void) {
        self.readiness = readiness
        self.choices = choices
        _selection = selection
        self.choose = choose
    }

    public var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: readiness.headline)

            Text(verbatim: readiness.explanation)
                .font(.system(size: .launcherType(13, unit: unit), weight: .light))
                .lineSpacing(6 * unit)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.text(0.68))
                .frame(maxWidth: 460 * unit)
                .fixedSize(horizontal: false, vertical: true)

            RequirementsLine(readiness: readiness)
                .padding(.top, 24 * unit)

            // One choice is lit at a time, and it is the one Return performs:
            // the pointer chooses by resting on a word, the arrows by moving.
            HStack(spacing: 48 * unit) {
                ForEach(choices.indices, id: \.self) { index in
                    MenuButton(title: choices[index], isSelected: index == selection) {
                        choose(index)
                    }
                    .onPointer { inside in
                        if inside { selection = index }
                    }
                }
            }
            .padding(.top, 22 * unit)
        }
        .animation(.easeInOut(duration: 0.4), value: readiness)
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
            SpacedText(title, size: .launcherType(9, unit: unit), weight: .regular, tracking: 0.3)
                .foregroundStyle(Palette.text(isMet ? 0.72 : 0.5))
        }
    }

    private var accessibilityText: String {
        let silicon = Self.isAppleSilicon ? "Apple silicon: yes" : "Apple silicon: no"
        let intelligence = readiness.allowsPlay ? "Apple Intelligence: ready" : "Apple Intelligence: \(readiness.status)"
        return "\(silicon). macOS 26: yes. \(intelligence)."
    }
}
