import LauncherCore
import SwiftUI

/// The latest news: headlines on the left, the chosen story on the right.
struct NewsPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @State private var isReturnHovered = false

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "News")

            HStack(alignment: .top, spacing: 52 * unit) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.visibleNews) { item in
                        NewsHeadline(item: item, isSelected: item.id == model.selectedNews?.id) {
                            model.selectNews(item)
                        }
                        .onPointer { inside in
                            if inside { model.selectNews(item) }
                        }
                    }
                    NewsSourceLine(status: model.newsStatus)
                        .padding(.top, 14 * unit)
                }
                .frame(width: 250 * unit, alignment: .leading)

                NewsStory(item: model.selectedNews) {
                    model.openNewsLink()
                }
                .frame(width: 370 * unit, alignment: .topLeading)
            }

            MenuButton(title: "Back", isSelected: isReturnHovered) {
                model.returnToTitle()
            }
            .onPointer { isReturnHovered = $0 }
            .padding(.top, 16 * unit)
        }
    }
}

/// A date and a title in the list. The chosen one is marked by a short
/// vertical rule.
private struct NewsHeadline: View {
    let item: NewsItem
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        let _ = PressableButtons.note(item.title, enabled: true, action)
        Button(action: action) {
            HStack(alignment: .top, spacing: 12 * unit) {
                Rectangle()
                    .fill(Palette.line(0.7))
                    .frame(width: 1, height: 30 * unit)
                    .opacity(isSelected ? 1 : 0)
                VStack(alignment: .leading, spacing: 4 * unit) {
                    SpacedText(item.date.shortText, size: .launcherType(9, unit: unit), weight: .regular, tracking: 0.3, balanced: false)
                        .foregroundStyle(Palette.text(isSelected ? 0.68 : 0.5))
                    Text(verbatim: item.title.uppercased())
                        .font(.launcher(.launcherType(11.5, unit: unit), weight: .light))
                        .tracking(11.5 * unit * 0.2)
                        .lineSpacing(2 * unit)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(Palette.text(isSelected ? 1 : 0.55))
                }
            }
            .padding(.vertical, 7 * unit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.3), value: isSelected)
        .accessibilityLabel("\(item.title), \(item.date.spokenText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The chosen story in full, with a link when it has one.
private struct NewsStory: View {
    let item: NewsItem?
    let openLink: () -> Void

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let item {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: item.title)
                        .font(.launcher(.launcherType(18, unit: unit), weight: .light))
                        .tracking(18 * unit * 0.04)
                        .foregroundStyle(Palette.text(0.96))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(verbatim: item.body)
                        .font(.launcher(.launcherType(12.5, unit: unit), weight: .regular))
                        .lineSpacing(5 * unit)
                        .foregroundStyle(Palette.text(0.82))
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10 * unit)

                    if item.link != nil {
                        let _ = PressableButtons.note("Read more", enabled: true, openLink)
                        Button(action: openLink) {
                            SpacedText("Read more", size: .launcherType(9.5, unit: unit), weight: .regular, tracking: 0.36, balanced: false)
                                .foregroundStyle(Palette.glow)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .linkPointer()
                        .accessibilityLabel("Read more about \(item.title)")
                        .padding(.top, 14 * unit)
                    }
                }
                .id(item.id)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: item?.id)
    }
}

/// Where the news came from: the repository, or the copy saved earlier.
private struct NewsSourceLine: View {
    let status: LauncherModel.NewsStatus

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        SpacedText(text, size: .launcherType(9, unit: unit), weight: .regular, tracking: 0.28, balanced: false)
            .foregroundStyle(Palette.text(0.8))
            .padding(.leading, 13 * unit)
            .animation(.easeInOut(duration: 0.3), value: status)
    }

    private var text: String {
        switch status {
        case .saved: return "Saved news"
        case .updating: return "Checking for news"
        case .current: return "Latest from the repository"
        case .offline: return "Offline · saved news"
        case .unavailable: return "Feed unavailable · saved news"
        }
    }
}
