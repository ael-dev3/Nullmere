import LauncherCore
import SwiftUI

/// What Play says on a ready Mac while there is no game to open: the first
/// realm hasn't opened yet, or the installed game didn't start.
struct PlayPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @State private var hovered: Action?

    private enum Action {
        case website
        case back
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: model.gameFailedToOpen ? "The crossing failed" : "The shore is quiet")

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
                MenuButton(title: "nullmere.online", isSelected: hovered == .website) {
                    model.openWebsite()
                }
                .onHover { hovered = $0 ? .website : nil }
                // Return answers the Return key, so it shows as chosen until
                // the pointer picks something else.
                MenuButton(title: "Return", isSelected: hovered == nil || hovered == .back) {
                    model.returnToTitle()
                }
                .onHover { hovered = $0 ? .back : nil }
            }
            .padding(.top, 22 * unit)
        }
    }

    private var explanation: String {
        if model.gameFailedToOpen {
            return "The Nullmere game is installed but didn't open. Try Play again, or reinstall the game."
        }
        return "This Mac is ready: Apple's on-device model is here. The first realm hasn't opened yet; when it does, Play will cross from here."
    }
}
