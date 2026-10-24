import LauncherCore
import SwiftUI

/// Play, Settings and Quit, centred on the water.
struct MainMenu: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        VStack(spacing: 20 * unit) {
            ForEach(MenuItem.allCases, id: \.self) { item in
                MenuRow(title: item.title, isSelected: model.menuSelection == item) {
                    model.activate(item)
                }
                .onHover { inside in
                    if inside { model.menuSelection = item }
                }
            }
        }
    }
}

/// One menu entry. The selected entry brightens, glows faintly and is framed
/// by two short rules.
struct MenuRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.launcherUnit) private var unit
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14 * unit) {
                SelectionTick(isVisible: isSelected, length: 22 * unit)
                SpacedText(title, size: 12.5 * unit, weight: .light, tracking: 0.48)
                SelectionTick(isVisible: isSelected, length: 22 * unit)
            }
            .foregroundStyle(Palette.ink.opacity(isSelected ? 1 : restingOpacity))
            .shadow(color: Palette.glow.opacity(isSelected ? 0.55 : 0), radius: 10 * unit)
            .padding(.vertical, 4 * unit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.35), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var restingOpacity: Double {
        contrast == .increased ? 0.75 : 0.5
    }
}
