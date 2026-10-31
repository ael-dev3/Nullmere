import NullmereCore
import SwiftUI

/// The realm's law, at the head of the Houses: the edict before the realm,
/// its tally and the keeper's vote; the edicts holding the realm and for
/// how long; and, folded until asked for, the edicts the keeper's House
/// may put to it.
struct EdictsSection: View {
    let session: GameSession

    /// The edicts that may be put, folded until asked for; the keeper's
    /// choice kept.
    @AppStorage(EdictsSection.proposingKey) private var proposing = false
    static let proposingKey = "edicts.open"

    /// An edict holding the realm, in a line: how long, what it forbids,
    /// and how often it was broken.
    static func inForce(_ edict: Edict, in state: GameState) -> String {
        let left = state.watchesLeft(of: edict), broken = edict.breaches.count
        let holds = left <= 1 ? "holds this last watch" : "holds \(left) more watches"
        let breaches = broken == 0 ? "" : broken == 1 ? " Broken once." : " Broken \(broken) times."
        return "\(edict.kind.heading) \(holds): \(edict.kind.law).\(breaches)"
    }

    /// The vote on an edict as it stands: the Houses and their might on
    /// each side, and when it closes.
    static func tally(_ edict: Edict, in state: GameState) -> String {
        let (aye, nay) = state.tally(of: edict)
        let left = state.watchesToVote(on: edict)
        let closes = left <= 1 ? "the vote closes as the watch turns" : "\(left) watches to vote"
        return "Aye \(edict.ayes.count), might \(GameState.counted(aye)) · Nay \(edict.nays.count), might \(GameState.counted(nay)) · \(closes)"
    }

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Caps("The realm's law", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
                Spacer()
                QuietButton(title: proposing ? "Fold the edicts" : "Put an edict…", size: 8.5,
                            name: proposing ? "Fold the edicts away" : "Put an edict to the realm") { proposing.toggle() }
            }
            if let edict = state.edictInVote {
                EdictVote(session: session, edict: edict)
            }
            ForEach(state.edictsInForce) { edict in
                Text(verbatim: EdictsSection.inForce(edict, in: state))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if state.edictInVote == nil, state.edictsInForce.isEmpty {
                Text(verbatim: "No edict holds the realm.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.45))
            }
            if proposing {
                ForEach(EdictKind.allCases, id: \.self) { kind in
                    EdictOffer(session: session, kind: kind)
                }
            }
        }
    }
}

/// The edict before the realm: what it forbids, the tally, and the
/// keeper's vote, cast or to cast.
private struct EdictVote: View {
    let session: GameSession
    let edict: Edict

    var body: some View {
        let state = session.state, me = session.player
        let by = state.houses.indices.contains(edict.proposer) ? (edict.proposer == me ? "your House" : state.houses[edict.proposer].title) : "a House"
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "Before the realm, put by \(by): \(edict.kind.title), \(edict.kind.law).")
                .font(.nm(10.5))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: EdictsSection.tally(edict, in: state))
                .font(.nm(10).monospacedDigit())
                .foregroundStyle(Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
            if edict.ayes.contains(me) || edict.nays.contains(me) {
                Text(verbatim: "Your House votes \(edict.ayes.contains(me) ? "aye" : "nay").")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
            } else {
                HStack(spacing: 6) {
                    QuietButton(title: "Aye", size: 9, prominent: true, name: "Vote aye on \(edict.kind.title)") {
                        session.perform(.voteEdict(edict: edict.id, aye: true))
                    }
                    QuietButton(title: "Nay", size: 9, name: "Vote nay on \(edict.kind.title)") {
                        session.perform(.voteEdict(edict: edict.id, aye: false))
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 4).fill(Palette.line(0.06)))
        .accessibilityElement(children: .contain)
    }
}

/// An edict the keeper's House may put to the realm: what it forbids, what
/// putting it costs, and why it can't be put now, if it can't.
private struct EdictOffer: View {
    let session: GameSession
    let kind: EdictKind

    var body: some View {
        let refusal = session.state.edictRefusal(kind, as: session.player)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Caps(kind.heading, size: 9, weight: .medium).foregroundStyle(Palette.text(0.85))
                Text(verbatim: "\(kind.law.prefix(1).uppercased())\(kind.law.dropFirst()).")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            QuietButton(title: "Propose", size: 8.5, enabled: refusal == nil, name: "Put \(kind.title) to the realm, for \(GameState.edictCost)",
                        why: refusal?.description) {
                session.perform(.proposeEdict(kind: kind))
            }
        }
    }
}
