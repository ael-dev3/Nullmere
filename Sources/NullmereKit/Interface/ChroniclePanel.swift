import NullmereCore
import SwiftUI

/// The lake's history, newest first; or the House's own battle reports.
struct ChroniclePanel: View {
    let session: GameSession
    /// The House's battle reports shown, rather than the lake's history.
    @State private var showingReports: Bool

    init(session: GameSession, showingReports: Bool = false) {
        self.session = session
        _showingReports = State(initialValue: showingReports)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Chronicle", subtitle: showingReports ? "Your House's battles, the latest first" : "What the lake remembers")
                CloseButton(label: "Close the Chronicle") { session.panel = nil }
            }
            Picker("Show", selection: $showingReports) {
                Text(verbatim: "History").tag(false)
                Text(verbatim: "Battle reports").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Show")
            if showingReports {
                ReportList(session: session)
            } else {
                history
            }
        }
        .padding(16)
        .frame(width: 380)
        .frame(maxHeight: 620)
        .panelBackground()
    }

    private var history: some View {
        let state = session.state
        return ScrollView {
                LazyVStack(alignment: .leading, spacing: 11) {
                    ForEach(Array(state.chronicle.enumerated().reversed()), id: \.offset) { item in
                        let entry = item.element
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "\(entry.watch)")
                                .font(.nm(10).monospacedDigit())
                                .foregroundStyle(Palette.text(0.35))
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
                                    .font(.nm(11.5, weight: weight(entry.kind)))
                                    .foregroundStyle(Palette.text(entry.kind == .ending ? 1 : 0.78))
                                    .fixedSize(horizontal: false, vertical: true)
                                if let spoken = session.spoken[.chronicle(item.offset)] {
                                    Text(verbatim: spoken)
                                        .font(.nm(11.5, weight: .light).italic())
                                        .foregroundStyle(Palette.glowWords)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(["Watch \(entry.watch).", entry.text, session.spoken[.chronicle(item.offset)]]
                            .compactMap { $0 }.joined(separator: " "))
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Entries, newest first")
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.chronicle))
    }

    private func weight(_ kind: ChronicleEntry.Kind) -> Font.Weight {
        switch kind {
        case .war, .fall, .betrayal, .ending, .greatWork: return .medium
        default: return .light
        }
    }
}

/// The House's battle reports, the latest first: how each came out, when
/// and where, who struck whom, the blows and the fallen.
struct ReportList: View {
    let session: GameSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if session.reports.isEmpty {
                    Text(verbatim: "No battle of your House's yet. Each one it fights, and each blow on the wilds, is reported here.")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(session.reports) { report in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Caps(ReportList.outcome(report.outcome), size: 8.5, weight: .medium)
                                .foregroundStyle(report.outcome == .won ? Palette.good : report.outcome == .lost ? Palette.bad : Palette.text(0.7))
                            Text(verbatim: "Watch \(report.watch), \(report.place)")
                                .font(.nm(10))
                                .foregroundStyle(Palette.text(0.5))
                                .lineLimit(1)
                        }
                        Text(verbatim: report.title)
                            .font(.nm(11.5, weight: .medium))
                            .foregroundStyle(Palette.text(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(report.lines, id: \.self) { line in
                            Text(verbatim: line).font(.nm(10.5)).foregroundStyle(Palette.text(0.65))
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Battle reports, the latest first")
        }
        .scrollEdgeFade()
        .scrollIndicators(.never)
        .pagedByKeys(session, as: .panel(.chronicle))
    }

    static func outcome(_ outcome: BattleReport.Outcome) -> String {
        switch outcome {
        case .won: return "Won"
        case .lost: return "Lost"
        case .held: return "Both stood"
        }
    }
}
