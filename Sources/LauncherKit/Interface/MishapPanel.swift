import LauncherCore
import SwiftUI

/// The page the launcher opens on after a run that stopped on a fault: what
/// happened, where and when, that nothing in the realm was lost, and the
/// ways on, one lit at a time, the one Return performs: into the world
/// again, a report to send, or back to the menu.
struct MishapPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @Environment(\.launcherRhythm) private var rhythm

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Stopped suddenly")

            VStack(spacing: 14 * unit * rhythm) {
                if let mishap = model.mishap {
                    Text(verbatim: mishap.account())
                        .font(.launcher(.launcherType(13, unit: unit), weight: .regular))
                        .foregroundStyle(Palette.text(0.85))
                }
                Text(verbatim: Mishap.reassurance)
                    .font(.launcher(.launcherType(12, unit: unit), weight: .regular))
                    .foregroundStyle(Palette.text(0.72))
            }
            .lineSpacing(6 * unit * rhythm)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460 * unit)
            .fixedSize(horizontal: false, vertical: true)
            .onNight()

            HStack(spacing: 48 * unit) {
                ForEach(LauncherModel.mishapChoices.indices, id: \.self) { index in
                    MenuButton(title: LauncherModel.mishapChoices[index], isSelected: index == model.mishapSelection) {
                        model.chooseOnMishap(index)
                    }
                    .onPointer { inside in
                        if inside { model.mishapSelection = index }
                    }
                    .accessibilityHint(Self.hints[index])
                }
            }
            .padding(.top, 24 * unit * rhythm)
        }
    }

    /// What each way on does, for VoiceOver.
    static let hints = ["Crosses to the realm's front door, as Play does",
                        "Opens a new report in the game's repository, written for you to read before sending",
                        "Returns to the menu"]
}
