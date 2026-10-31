import NullmereCore
import SwiftUI

/// The lake's history, newest first; the House's own battle reports; or
/// the realm's songbook.
struct ChroniclePanel: View {
    let session: GameSession

    enum Shown: Hashable {
        case history, reports, songs
    }

    @State private var shown: Shown

    init(session: GameSession, showingReports: Bool = false, shown: Shown? = nil) {
        self.session = session
        _shown = State(initialValue: shown ?? (showingReports ? .reports : .history))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Chronicle", subtitle: ChroniclePanel.subtitle(shown))
                CloseButton(label: "Close the Chronicle") { session.panel = nil }
            }
            Picker("Show", selection: $shown) {
                Text(verbatim: "History").tag(Shown.history)
                Text(verbatim: "Reports").tag(Shown.reports)
                Text(verbatim: "Songs").tag(Shown.songs)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Show")
            switch shown {
            case .history: history
            case .reports: ReportList(session: session)
            case .songs: Songbook(session: session)
            }
        }
        .padding(16)
        .frame(width: PanelWidth.reading)
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
                        // A deed of the House's own: a ballad made of it here, and sung.
                        if session.makesBallads, state.isSingable(item.offset, by: session.player) {
                            BalladMaking(session: session, entry: item.offset)
                                .padding(.leading, 36)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Entries, newest first")
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.chronicle))
    }

    static func subtitle(_ shown: Shown) -> String {
        switch shown {
        case .history: return "What the lake remembers"
        case .reports: return "Your House's battles and scouting, the latest first"
        case .songs: return "The ballads the keepers have sung this age"
        }
    }

    private func weight(_ kind: ChronicleEntry.Kind) -> Font.Weight {
        switch kind {
        case .war, .fall, .betrayal, .ending, .greatWork: return .medium
        default: return .light
        }
    }
}

/// The House's reports, the latest first: of each battle, how it came out,
/// when and where, who struck whom, the blows and the fallen; of each hold
/// its Lanterns scouted, what they saw there.
struct ReportList: View {
    let session: GameSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if session.reports.isEmpty {
                    Text(verbatim: "No report yet. Each battle your House fights, each blow on the wilds and each hold its Lanterns scout is reported here.")
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
                        // A field's two sides: each one's troops as they came, the bar what stands of them.
                        ForEach(report.sides.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: ReportList.side(report.sides[index]))
                                    .font(.nm(10.5))
                                    .foregroundStyle(Palette.text(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                                Meter(fraction: Double(report.sides[index].standing) / Double(max(report.sides[index].troops, 1)),
                                      colour: index == 0 ? Palette.good : Palette.bad)
                            }
                            .padding(.vertical, 1)
                        }
                        ForEach(report.lines, id: \.self) { line in
                            Text(verbatim: line).font(.nm(10.5)).foregroundStyle(Palette.text(0.65))
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Reports of battles and scouting, the latest first")
        }
        .scrollEdgeFade()
        .scrollIndicators(.never)
        .pagedByKeys(session, as: .panel(.chronicle))
    }

    /// A side of a field of battle in a line: its companies and Houses, its
    /// troops as they came, those lost, and its companies fallen.
    static func side(_ side: BattleReport.Side) -> String {
        let companies = side.companies == 1 ? "1 company" : "\(side.companies) companies"
        let houses = side.houses > 1 ? " of \(side.houses) Houses" : ""
        let fallen = side.fallen == 0 ? "" : side.fallen == 1 ? ", 1 company fallen" : ", \(side.fallen) companies fallen"
        return "\(side.title): \(companies)\(houses), \(GameState.counted(side.troops)) troops; "
            + "\(GameState.counted(side.lost)) lost\(fallen)"
    }

    static func outcome(_ outcome: BattleReport.Outcome) -> String {
        switch outcome {
        case .won: return "Won"
        case .lost: return "Lost"
        case .held: return "Both stood"
        case .scouted: return "Scouted"
        }
    }
}

/// A ballad of a deed of the House's own, made by this Mac's model: asked
/// for, read, then sung to the realm or let be; once sung, its lines.
struct BalladMaking: View {
    let session: GameSession
    let entry: Int

    var body: some View {
        let sung = session.state.songbook.first { $0.house == session.player && $0.entry == entry }
        VStack(alignment: .leading, spacing: 4) {
            if let sung {
                BalladLines(lines: sung.lines)
            } else if let draft = session.balladDrafts[entry] {
                BalladLines(lines: draft.components(separatedBy: "\n"))
                HStack(spacing: 4) {
                    QuietButton(title: "Sing it", size: 8.5, prominent: true, name: "Sing the ballad to the realm") {
                        session.singBallad(of: entry)
                    }
                    QuietButton(title: "Another", size: 8.5, name: "Ask for another ballad") { session.makeBallad(of: entry) }
                    QuietButton(title: "Let it be", size: 8.5, name: "Let the ballad go unsung") { session.letBalladBe(of: entry) }
                }
            } else if session.composing.contains(entry) {
                Text(verbatim: "The verse comes…")
                    .font(.nm(10.5, weight: .light).italic())
                    .foregroundStyle(Palette.text(0.5))
            } else {
                QuietButton(title: "Make a ballad", size: 8.5, name: "Make a ballad of this on your Mac") { session.makeBallad(of: entry) }
                    .help("Your Mac's own model makes a few lines of verse of this deed; sing them to the realm if they please you.")
            }
        }
    }
}

/// A ballad's lines, as sung.
struct BalladLines: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(lines.enumerated()), id: \.offset) { line in
                Text(verbatim: line.element)
                    .font(.nm(11, weight: .light).italic())
                    .foregroundStyle(Palette.glowWords)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The realm's songbook, the latest ballad first: whose hall sang it, of
/// which deed, and its lines.
struct Songbook: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if state.songbook.isEmpty {
                    Text(verbatim: "No ballad yet. Make one of a deed of your House's in the History: your Mac's own model writes the verse, "
                         + "and you sing it to the realm.")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(state.songbook.reversed().filter { !session.isMuted($0.house) }) { ballad in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: Songbook.heading(ballad, in: state))
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                        BalladLines(lines: ballad.lines)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .scrollEdgeFade()
        .scrollIndicators(.never)
    }

    /// Whose hall sang a ballad, and of what: "House Aurel, of the 52nd
    /// watch: A battle at the Grey Ford…"
    static func heading(_ ballad: Ballad, in state: GameState) -> String {
        let who = state.houses.indices.contains(ballad.house) ? state.houses[ballad.house].title : "A House now gone"
        guard state.chronicle.indices.contains(ballad.entry) else { return who }
        let entry = state.chronicle[ballad.entry]
        let deed = entry.text.count > 70 ? String(entry.text.prefix(70)) + "…" : entry.text
        return "\(who), of the \(SeatBriefing.ordinal(entry.watch)) watch: \(deed)"
    }
}
