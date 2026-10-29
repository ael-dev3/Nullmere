import LauncherCore
import SwiftUI

/// What Play says on a ready Mac when this launcher has no way into a realm.
struct PlayPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "The shore is quiet")

            Text(verbatim: explanation)
                .font(.system(size: 13 * unit, weight: .light))
                .lineSpacing(6 * unit)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.68))
                .frame(maxWidth: 460 * unit)
                .fixedSize(horizontal: false, vertical: true)

            RequirementsLine(readiness: model.readiness)
                .padding(.top, 24 * unit)

            // The lit choice is the one the Return key performs. ← → or the
            // pointer move it; the panel opens with Return lit.
            HStack(spacing: 48 * unit) {
                ForEach(LauncherModel.PlayChoice.allCases, id: \.self) { choice in
                    MenuButton(title: title(for: choice), isSelected: model.playSelection == choice) {
                        model.choose(choice)
                    }
                    .onPointer { inside in
                        if inside { model.playSelection = choice }
                    }
                }
            }
            .padding(.top, 22 * unit)
        }
    }

    private func title(for choice: LauncherModel.PlayChoice) -> String {
        switch choice {
        case .website: return "nullmere.online"
        case .back: return "Back"
        }
    }

    private var explanation: String {
        "This Mac is ready: Apple's on-device model is here. This build of the launcher can't enter the realm; Nullmere Online itself is on the website."
    }
}
