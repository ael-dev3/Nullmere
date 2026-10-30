import LauncherCore
import SwiftUI

/// Launcher settings, set in the same quiet type as the menu. Rows are chosen
/// with ↑ ↓ or the pointer; options change with ← → or a click.
struct SettingsPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @Environment(\.launcherRhythm) private var rhythm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReturnHovered = false
    /// The row whose option has keyboard focus, with keyboard navigation
    /// on: the ticked row follows it, so ← → and Return act where the focus
    /// ring is.
    @FocusState private var focusedRow: SettingsRow?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Settings")

            ForEach(SettingsRow.allCases, id: \.self) { row in
                SettingsRowView(
                    title: row.title,
                    options: model.settings.options(for: row),
                    selectedIndex: model.settings.selectedIndex(for: row),
                    isFocused: model.settingsSelection == row,
                    note: row == .frameRate ? model.frameRateNote(systemReducesMotion: reduceMotion) : nil,
                    focus: $focusedRow,
                    row: row
                ) { index in
                    model.choose(index, for: row)
                }
                .onPointer { inside in
                    if inside { model.settingsSelection = row }
                }

                if row != SettingsRow.allCases.last {
                    Hairline(width: 560 * unit, opacity: 0.16)
                }
            }

            MenuButton(title: "Back", isSelected: isReturnHovered) {
                model.returnToTitle()
            }
            .onPointer { isReturnHovered = $0 }
            .padding(.top, 18 * unit * rhythm)
        }
        .frame(width: 560 * unit)
        .onChange(of: focusedRow) { _, row in if let row { model.settingsSelection = row } }
    }
}

private struct SettingsRowView: View {
    let title: String
    let options: [String]
    let selectedIndex: Int
    let isFocused: Bool
    /// What the row's choice comes to now, where that isn't plain.
    let note: String?
    let focus: FocusState<SettingsRow?>.Binding
    let row: SettingsRow
    let choose: (Int) -> Void

    @Environment(\.launcherUnit) private var unit
    @Environment(\.launcherRhythm) private var rhythm

    var body: some View {
        HStack(spacing: 0) {
            SelectionTick(isVisible: isFocused, length: 10 * unit)
                .padding(.trailing, isFocused ? 10 * unit : 0)
            VStack(alignment: .leading, spacing: 4 * unit * rhythm) {
                SpacedText(title, size: .launcherType(10.5, unit: unit), weight: .regular, tracking: 0.32)
                    .foregroundStyle(Palette.text(isFocused ? 1 : 0.8))
                if let note {
                    Text(verbatim: note)
                        .font(.launcher(.launcherType(9, unit: unit), weight: .regular))
                        .foregroundStyle(Palette.text(0.75))
                }
            }
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
        .padding(.vertical, 13 * unit * rhythm)
        .onNight()
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.3), value: isFocused)
        .animation(.easeOut(duration: 0.3), value: selectedIndex)
        // One control to VoiceOver: the setting as a Mac's own pop-up menu
        // of its options, its value the one chosen, its note said with it.
        .accessibilityRepresentation {
            Picker(title, selection: Binding(get: { selectedIndex }, set: { choose($0) })) {
                ForEach(options.indices, id: \.self) { index in
                    Text(verbatim: options[index]).tag(index)
                }
            }
            .accessibilityHint(note ?? "")
        }
    }

    private func option(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        PressableButtons.note(label, enabled: true, action)
        return Button(action: action) {
            SpacedText(label, size: .launcherType(10.5, unit: unit), weight: .light, tracking: 0.24)
                .foregroundStyle(Palette.text(isSelected ? 1 : 0.5))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.line(0.55))
                        .frame(height: 1)
                        .opacity(isSelected ? 1 : 0)
                        .offset(y: 6 * unit)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused(focus, equals: row)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
