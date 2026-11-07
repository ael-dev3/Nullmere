import NullmereCore
import SwiftUI

/// The Ring on the Commanders screen: the House's standing and the
/// challenges left it this watch, its last bouts; and, folded until asked
/// for, the line it stands, up to three of its commanders, and the other
/// keepers' lines to challenge, each with its standing and its weight.
struct RingSection: View {
    let session: GameSession

    @State private var open: Bool
    /// The commanders chosen for the House's line, in order.
    @State private var picked: [Int]

    /// The section begins folded, or open with a line already chosen.
    init(session: GameSession, open: Bool = false, picked: [Int]? = nil) {
        self.session = session
        _open = State(initialValue: open)
        _picked = State(initialValue: picked ?? session.state.ringLine(of: session.player) ?? [])
    }

    /// Where the House stands in the Ring, in the rules' words.
    static func standingLine(_ state: GameState, player: Int) -> String {
        state.ringStandingSaid(of: player)
    }

    /// A bout, in a line, as the House it touched reads it, in the rules' words.
    static func boutLine(_ bout: Ring.Bout, in state: GameState, player: Int) -> String {
        state.boutSaid(bout, to: player)
    }

    var body: some View {
        let state = session.state, me = session.player
        let mine = state.commanders(of: me)
        let bouts = (state.ring?.bouts ?? []).filter { $0.challenger == me || $0.defender == me }.suffix(3)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Caps("The Ring", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                Spacer()
                QuietButton(title: open ? "Fold the Ring" : "Enter the Ring…", size: 8.5,
                            name: open ? "Fold the Ring away" : "Stand a line in the Ring and challenge another keeper's") {
                    open.toggle()
                }
            }
            Text(verbatim: RingSection.standingLine(state, player: me))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.7))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(bouts.enumerated()), id: \.offset) { _, bout in
                Text(verbatim: RingSection.boutLine(bout, in: state, player: me))
                    .font(.nm(10))
                    .foregroundStyle(bout.winner == me ? Palette.good : Palette.text(0.55))
            }
            if open {
                Text(verbatim: "Your line, up to three: each weighs its level, its talents and its gear.")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                FlowLayout(spacing: 6, lineSpacing: 4) {
                    ForEach(mine) { commander in
                        let chosen = picked.contains(commander.id)
                        QuietButton(title: "\(commander.name) · \(state.ringWeight(of: commander))", size: 8.5, prominent: chosen,
                                    enabled: chosen || picked.count < GameState.ringLine,
                                    name: chosen ? "Take \(commander.name) from your line" : "Put \(commander.name) in your line") {
                            if chosen { picked.removeAll { $0 == commander.id } } else { picked.append(commander.id) }
                        }
                    }
                }
                let refusal = state.ringLineRefusal(picked, as: me)
                let standing = state.ringLine(of: me) == picked
                QuietButton(title: standing ? "This line stands" : "Stand this line", size: 8.5, enabled: refusal == nil && !standing,
                            name: "Stand the commanders chosen as your line in the Ring", why: standing ? nil : refusal?.description) {
                    session.perform(.standInTheRing(picked))
                }
                let rivals = state.ringRanks.filter { $0 != me }
                if rivals.isEmpty {
                    Text(verbatim: "No other keeper stands a line yet.")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.55))
                }
                ForEach(rivals, id: \.self) { other in
                    let why = state.challengeRefusal(of: other, as: me)
                    HStack(alignment: .firstTextBaseline) {
                        QuietButton(title: "Challenge \(state.houses[other].title)", size: 8.5, enabled: why == nil,
                                    name: "Challenge the line of \(state.houses[other].title)", why: why?.description) {
                            session.perform(.challenge(house: other))
                        }
                        Spacer()
                        Text(verbatim: state.ringLineSaid(of: other))
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.6))
                    }
                }
            }
        }
    }
}
