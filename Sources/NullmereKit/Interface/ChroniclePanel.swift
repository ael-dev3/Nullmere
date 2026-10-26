import NullmereCore
import SwiftUI

/// The lake's history, newest first.
struct ChroniclePanel: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Chronicle", subtitle: "What the lake remembers")
                CloseButton { session.panel = nil }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 11) {
                    ForEach(Array(state.chronicle.enumerated().reversed()), id: \.offset) { item in
                        let entry = item.element
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "\(entry.watch)")
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(Palette.ink.opacity(0.35))
                                .frame(width: 26, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 3) {
                                    ForEach(entry.houses, id: \.self) { id in
                                        if state.houses.indices.contains(id) {
                                            Circle().fill(Palette.house(state.houses[id])).frame(width: 4, height: 4)
                                        }
                                    }
                                }
                                Text(verbatim: entry.text)
                                    .font(.system(size: 11.5, weight: weight(entry.kind)))
                                    .foregroundStyle(Palette.ink.opacity(entry.kind == .ending ? 1 : 0.78))
                                    .fixedSize(horizontal: false, vertical: true)
                                if let spoken = session.spoken[.chronicle(item.offset)] {
                                    Text(verbatim: spoken)
                                        .font(.system(size: 11.5, weight: .light).italic())
                                        .foregroundStyle(Palette.glow.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Watch \(entry.watch). \(entry.text) \(session.spoken[.chronicle(item.offset)] ?? "")")
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(width: 380)
        .frame(maxHeight: 620)
        .panelBackground()
    }

    private func weight(_ kind: ChronicleEntry.Kind) -> Font.Weight {
        switch kind {
        case .war, .fall, .betrayal, .ending, .greatWork: return .medium
        default: return .light
        }
    }
}
