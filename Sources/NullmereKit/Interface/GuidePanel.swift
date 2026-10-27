import SwiftUI

/// How the game is played, in a few short sections.
struct GuidePanel: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Guide", subtitle: "How the lake is held")
                CloseButton { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Guide.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Caps(section.title, size: 9, weight: .medium)
                                .foregroundStyle(Palette.glow)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(section.lines, id: \.self) { line in
                                Text(verbatim: line)
                                    .font(.nm(11.5, weight: .light))
                                    .foregroundStyle(Palette.ink.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(width: 380)
        .frame(maxHeight: 620)
        .panelBackground()
    }
}
