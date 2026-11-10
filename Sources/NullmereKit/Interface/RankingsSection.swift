import NullmereCore
import SwiftUI

/// The Rankings, as Rise of Kingdoms keeps its boards of power and of kill
/// points: every House, or every alliance by its Houses, by might or by the
/// foes it has slain this age; the foremost ten and the keeper's own
/// beneath them where it stands lower. Folded to a line of where their
/// House stands, so the Realm panel stays quiet until it is asked.
struct RankingsSection: View {
    let session: GameSession
    @State private var open: Bool
    @State private var by: RankedBy
    @State private var alliances: Bool

    /// Folded, the Houses by might, unless asked otherwise.
    init(session: GameSession, open: Bool = false, by: RankedBy = .might, alliances: Bool = false) {
        self.session = session
        _open = State(initialValue: open)
        _by = State(initialValue: by)
        _alliances = State(initialValue: alliances)
    }

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: open ? 8 : 4) {
            // Its title and its button on one line where both fit, the button
            // beneath where they don't, as a folded list's are.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    heading
                    Spacer(minLength: 12)
                    toggle
                }
                VStack(alignment: .leading, spacing: 4) {
                    heading
                    toggle
                }
            }
            if open {
                let ranking = state.ranking(by, alliances: alliances, for: session.player)
                FlowLayout(spacing: 4, lineSpacing: 2) {
                    QuietButton(title: "Houses", size: 8.5, prominent: !alliances, name: "Rank the Houses") { alliances = false }
                    QuietButton(title: "Alliances", size: 8.5, prominent: alliances, name: "Rank the alliances") { alliances = true }
                    ForEach(RankedBy.allCases) { each in
                        QuietButton(title: each.title, size: 8.5, prominent: by == each, name: "Rank \(each.said)") { by = each }
                    }
                }
                if let standing = ranking.standing {
                    Text(verbatim: standing)
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ranking.lines.isEmpty {
                    Text(verbatim: ranking.none)
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(ranking.lines) { line in
                        RankingRow(line: line, by: by)
                    }
                    if let own = ranking.own {
                        Rule(opacity: 0.12)
                        RankingRow(line: own, by: by)
                    }
                }
            } else {
                Text(verbatim: state.rankingsSaid(for: session.player) ?? RankingsSection.unranked)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Folded, for a keeper of no House.
    static let unranked = "Every House and alliance by might and by foes slain."

    private var heading: some View {
        Caps("Rankings", size: 9, weight: .medium)
            .foregroundStyle(Palette.text(0.7))
            .lineLimit(1)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    private var toggle: some View {
        QuietButton(title: open ? "Fold the rankings" : "Show the rankings", size: 8.5,
                    name: open ? "Fold the rankings away" : "Show the rankings") {
            open.toggle()
        }
        .fixedSize()
    }
}

/// A line of a ranking: its place, whose it is with its alliance or its
/// Houses beneath, and its figure; the keeper's own in the glow of their
/// words, and the whole line one thing to VoiceOver.
struct RankingRow: View {
    let line: RankingLine
    let by: RankedBy

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(line.place)")
                .font(.nm(10).monospacedDigit())
                .foregroundStyle(Palette.text(line.place <= 3 ? 0.85 : 0.5))
                .frame(minWidth: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: line.name)
                    .font(.nm(10.5, weight: line.isOwn ? .medium : .regular))
                    .foregroundStyle(line.isOwn ? Palette.glowWords : Palette.text(0.82))
                    .lineLimit(1)
                if let note = line.note {
                    Text(verbatim: note)
                        .font(.nm(9))
                        .foregroundStyle(Palette.text(0.45))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(verbatim: GameState.counted(line.figure))
                .font(.nm(10).monospacedDigit())
                .foregroundStyle(Palette.text(line.isOwn ? 0.9 : 0.72))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.said(by))
    }
}
