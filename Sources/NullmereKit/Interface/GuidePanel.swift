import SwiftUI

/// How the game is played, in a few short sections, each headed by a
/// picture of what it tells of, painted from the world's own models.
struct GuidePanel: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Guide", subtitle: "How the lake is held")
                CloseButton(label: "Close the Guide") { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Guide.sections) { section in
                        HStack(alignment: .top, spacing: 10) {
                            // Headed by what it tells of, painted from the
                            // world's own models.
                            if let picture = section.picture {
                                Portrait(key: picture, colour: section.housed ? Portrait.colour(of: session.player, in: session.state) : nil,
                                         size: GuidePanel.portrait)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Caps(section.title, size: 9, weight: .medium)
                                    .foregroundStyle(Palette.glowWords)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(section.lines, id: \.self) { line in
                                    Text(verbatim: line)
                                        .font(.nm(11.5, weight: .light))
                                        .foregroundStyle(Palette.text(0.82))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.guide))
        }
        .padding(16)
        .frame(width: PanelWidth.reading)
        .panelHeight()
        .panelBackground()
    }

    /// A section's picture's side in points.
    static let portrait: CGFloat = 34
}
