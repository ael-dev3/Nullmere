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
                        .onHover { inside in
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

            MenuButton(title: "Return", isSelected: isReturnHovered) {
                model.returnToTitle()
            }
            .onHover { isReturnHovered = $0 }
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
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12 * unit) {
                Rectangle()
                    .frame(width: 1, height: 30 * unit)
                    .opacity(isSelected ? 0.7 : 0)
                VStack(alignment: .leading, spacing: 4 * unit) {
                    SpacedText(item.date.shortText, size: 9 * unit, weight: .regular, tracking: 0.3, balanced: false)
                        .opacity(0.6)
                    Text(verbatim: item.title.uppercased())
                        .font(.system(size: 11.5 * unit, weight: .light))
                        .tracking(11.5 * unit * 0.2)
                        .lineSpacing(2 * unit)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(Palette.ink)
            .opacity(isSelected ? 1 : restingOpacity)
            .padding(.vertical, 7 * unit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.3), value: isSelected)
        .accessibilityLabel("\(item.title), \(item.date.spokenText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var restingOpacity: Double {
        contrast == .increased ? 0.75 : 0.45
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
                        .font(.system(size: 18 * unit, weight: .light))
                        .tracking(18 * unit * 0.04)
                        .foregroundStyle(Palette.ink.opacity(0.96))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(verbatim: item.body)
                        .font(.system(size: 12.5 * unit, weight: .light))
                        .lineSpacing(5 * unit)
                        .foregroundStyle(Palette.ink.opacity(0.7))
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10 * unit)

                    if item.link != nil {
                        Button(action: openLink) {
                            SpacedText("Read more", size: 9.5 * unit, weight: .regular, tracking: 0.36, balanced: false)
                                .foregroundStyle(Palette.glow.opacity(0.9))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
        SpacedText(text, size: 8.5 * unit, weight: .regular, tracking: 0.28, balanced: false)
            .foregroundStyle(Palette.ink.opacity(0.38))
            .padding(.leading, 13 * unit)
            .animation(.easeInOut(duration: 0.3), value: status)
    }

    private var text: String {
        switch status {
        case .saved: return "Saved news"
        case .updating: return "Checking for news"
        case .current: return "Latest from the repository"
        case .offline: return "Offline · saved news"
        }
    }
}
