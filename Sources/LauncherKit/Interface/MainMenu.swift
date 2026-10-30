import LauncherCore
import SwiftUI

/// Play, News, Settings, Repository and Quit, in a row on the water.
struct MainMenu: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    /// The word with keyboard focus, when keyboard navigation is on: the
    /// lit word follows it, and it the lit word, so Return and the focus
    /// ring always mean the same one.
    @FocusState private var focused: MenuItem?

    var body: some View {
        HStack(spacing: 54 * unit) {
            ForEach(MenuItem.allCases, id: \.self) { item in
                MenuButton(title: item.title, isSelected: model.menuSelection == item) {
                    model.activate(item)
                }
                .focused($focused, equals: item)
                .onPointer { inside in
                    if inside { model.menuSelection = item }
                }
                .accessibilityHint(hint(for: item))
            }
        }
        .onChange(of: focused) { _, item in if let item { model.menuSelection = item } }
        .onChange(of: model.menuSelection) { _, item in if focused != nil { focused = item } }
    }

    private func hint(for item: MenuItem) -> String {
        switch item {
        case .play: return "Crosses to the realm's front door when this Mac is ready"
        case .news: return "Shows the latest news"
        case .settings: return "Shows the launcher settings"
        case .repository: return "Opens the source code on GitHub in your browser"
        case .quit: return "Quits Nullmere Online"
        }
    }
}

/// A word in light, spaced capitals. When selected it brightens, glows
/// faintly and draws a hairline beneath itself. The realm's door offers its
/// choices with it too.
public struct MenuButton: View {
    let title: String
    let isSelected: Bool
    var size: CGFloat = 13
    /// A choice that can't be made yet stays faint and does nothing.
    var enabled = true
    let action: () -> Void

    @Environment(\.launcherUnit) private var unit
    @Environment(\.launcherRhythm) private var rhythm

    public init(title: String, isSelected: Bool, size: CGFloat = 13, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.size = size
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        let _ = PressableButtons.note(title, enabled: enabled, action)
        Button(action: action) {
            SpacedText(title, size: .launcherType(size, unit: unit), weight: .light, tracking: 0.42)
                .foregroundStyle(enabled ? Palette.text(isSelected ? 1 : 0.52) : Palette.ink.opacity(0.28))
                .shadow(color: Palette.glow.opacity(isSelected ? 0.55 : 0), radius: 12 * unit)
                .overlay(alignment: .bottom) {
                    Underline()
                        .scaleEffect(x: isSelected ? 1 : 0.2, y: 1)
                        .opacity(isSelected ? 1 : 0)
                        .offset(y: 11 * unit)
                }
                .padding(.vertical, 8 * unit * rhythm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.35), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
