import LauncherCore
import SwiftUI

/// Play, News, Settings, Repository and Quit, in a row on the water.
struct MainMenu: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        HStack(spacing: 54 * unit) {
            ForEach(MenuItem.allCases, id: \.self) { item in
                MenuButton(title: item.title, isSelected: model.menuSelection == item) {
                    model.activate(item)
                }
                .onHover { inside in
                    if inside { model.menuSelection = item }
                }
                .accessibilityHint(hint(for: item))
            }
        }
    }

    private func hint(for item: MenuItem) -> String {
        switch item {
        case .play: return "Crosses into Nullmere when this Mac is ready"
        case .news: return "Shows the latest news"
        case .settings: return "Shows the launcher settings"
        case .repository: return "Opens the source code on GitHub in your browser"
        case .quit: return "Quits the launcher"
        }
    }
}

/// A word in light, spaced capitals. When selected it brightens, glows
/// faintly and draws a hairline beneath itself.
struct MenuButton: View {
    let title: String
    let isSelected: Bool
    var size: CGFloat = 13
    let action: () -> Void

    @Environment(\.launcherUnit) private var unit
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            SpacedText(title, size: size * unit, weight: .light, tracking: 0.42)
                .foregroundStyle(Palette.ink.opacity(isSelected ? 1 : restingOpacity))
                .shadow(color: Palette.glow.opacity(isSelected ? 0.55 : 0), radius: 12 * unit)
                .overlay(alignment: .bottom) {
                    Underline()
                        .scaleEffect(x: isSelected ? 1 : 0.2, y: 1)
                        .opacity(isSelected ? 1 : 0)
                        .offset(y: 11 * unit)
                }
                .padding(.vertical, 8 * unit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.35), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var restingOpacity: Double {
        contrast == .increased ? 0.78 : 0.52
    }
}
