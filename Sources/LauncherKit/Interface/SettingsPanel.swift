import LauncherCore
import SwiftUI

/// Launcher settings, set in the same quiet type as the menu. Rows are chosen
/// with ↑ ↓ or the pointer; options change with ← → or a click.
struct SettingsPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @State private var isReturnHovered = false

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Settings")

            ForEach(SettingsRow.allCases, id: \.self) { row in
                SettingsRowView(
                    title: row.title,
                    options: model.settings.options(for: row),
                    selectedIndex: model.settings.selectedIndex(for: row),
                    isFocused: model.settingsSelection == row
                ) { index in
                    model.choose(index, for: row)
                }
                .onHover { inside in
                    if inside { model.settingsSelection = row }
                }

                if row != SettingsRow.allCases.last {
                    Hairline(width: 560 * unit, opacity: 0.16)
                }
            }

            MenuButton(title: "Return", isSelected: isReturnHovered) {
                model.returnToTitle()
            }
            .onHover { isReturnHovered = $0 }
            .padding(.top, 18 * unit)
        }
        .frame(width: 560 * unit)
    }
}

private struct SettingsRowView: View {
    let title: String
    let options: [String]
    let selectedIndex: Int
    let isFocused: Bool
    let choose: (Int) -> Void

    @Environment(\.launcherUnit) private var unit
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 0) {
            SelectionTick(isVisible: isFocused, length: 10 * unit)
                .padding(.trailing, isFocused ? 10 * unit : 0)
            SpacedText(title, size: 10.5 * unit, weight: .regular, tracking: 0.32)
                .opacity(isFocused ? 0.95 : labelOpacity)
            Spacer(minLength: 24 * unit)
            HStack(spacing: 18 * unit) {
                ForEach(options.indices, id: \.self) { index in
                    option(options[index], isSelected: index == selectedIndex) {
                        choose(index)
                    }
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.vertical, 13 * unit)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.3), value: isFocused)
        .animation(.easeOut(duration: 0.3), value: selectedIndex)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func option(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SpacedText(label, size: 10.5 * unit, weight: .light, tracking: 0.24)
                .opacity(isSelected ? 1 : optionOpacity)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1)
                        .opacity(isSelected ? 0.55 : 0)
                        .offset(y: 6 * unit)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var labelOpacity: Double { contrast == .increased ? 0.8 : 0.55 }
    private var optionOpacity: Double { contrast == .increased ? 0.7 : 0.38 }
}
