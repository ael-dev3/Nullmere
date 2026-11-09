import NullmereCore
import NullmereModels
import NullmereWorld
import SwiftUI

/// A plea the folk of one of the keeper's holds bring to their gate, beside
/// the world where envoys come: the petitioner painted from the world's own
/// townsfolk in the House's colours, their own words where this Mac's model
/// gave them (the model shown at work with its seconds, or why it gave
/// none), the plea in the realm's words, how long it waits, and Grant or
/// Turn away, what turning it away costs said on Turn away itself.
/// Nothing while no plea waits.
struct PetitionCard: View {
    let session: GameSession

    @Environment(\.worldMotion) private var motion

    var body: some View {
        if let petition = session.state.petition(of: session.player) {
            let state = session.state
            let refusal = state.petitionRefusal(petition.id, grant: true, as: session.player)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Portrait(key: .folk(variant: PetitionCard.variant(of: petition.plea)),
                             colour: Portrait.colour(of: session.player, in: state), size: PetitionCard.portrait)
                    VStack(alignment: .leading, spacing: 3) {
                        Caps("A plea at the gate", size: 9, weight: .medium).foregroundStyle(Palette.ink)
                        Text(verbatim: state.petitioner(of: petition))
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        // How long it waits, beside the petitioner rather than
                        // on a line of its own under the plea.
                        Text(verbatim: PetitionCard.waits(petition, at: state.watch))
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.4))
                    }
                }
                VoicingLine(session: session, key: .petition(petition.id), who: "the petitioner")
                if let spoken = session.spoken[.petition(petition.id)] {
                    Text(verbatim: "\"\(spoken)\"")
                        .font(.nm(12, weight: .light).italic())
                        .foregroundStyle(Palette.text(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                Text(verbatim: state.asked(by: petition))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(session.spoken[.petition(petition.id)] == nil ? 0.7 : 0.5))
                    .fixedSize(horizontal: false, vertical: true)
                // What turning it away costs is said on Turn away itself, as
                // its help and to VoiceOver, not as a paragraph of its own.
                // What came of the hold's last plea, as its folk remember it.
                if let remembered = state.rememberedPlea(petition) {
                    Text(verbatim: remembered)
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The answers on a row of their own, one above the other
                // where the row can't hold both (larger type), so the price
                // never runs into the refusal.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        answers(petition, refusal: refusal)
                    }
                    VStack(alignment: .trailing, spacing: 6) {
                        answers(petition, refusal: refusal)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(14)
            .frame(width: PanelWidth.record)
            .panelBackground()
            // Below full motion it fades in where it rests.
            .transition(motion == .full ? .move(edge: .trailing).combined(with: .opacity) : .opacity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("A plea at the gate, from \(state.petitioner(of: petition))")
        }
    }

    /// Turn away, and Grant with its price, off while the House can't.
    @ViewBuilder
    private func answers(_ petition: Petition, refusal: RuleError?) -> some View {
        QuietButton(title: "Turn away", size: 8.5) { session.perform(.answerPetition(petition.id, grant: false)) }
            .help(GameState.turnedAwaySaid)
            .accessibilityHint(GameState.turnedAwaySaid)
        QuietButton(title: PetitionCard.grant(petition), size: 8.5, prominent: true, enabled: refusal == nil) {
            session.perform(.answerPetition(petition.id, grant: true))
        }
        .help(refusal.map { PetitionCard.why($0) } ?? "")
    }

    /// The petitioner's portrait's side in points.
    static let portrait: CGFloat = 40

    /// Which of the townsfolk brings a plea, as the world stands them at
    /// the hold's gate (`Petition.Plea.folk`).
    static func variant(of plea: Petition.Plea) -> Int { plea.folk }

    /// How long the plea waits for its answer: "Waits 3 watches".
    static func waits(_ petition: Petition, at watch: Int) -> String {
        let left = max(Petition.patience - (watch - petition.arrived), 1)
        return left == 1 ? "Waits this watch" : "Waits \(left) watches"
    }

    /// The way to grant it, with its price: "Grant, for 30 stone".
    static func grant(_ petition: Petition) -> String { "Grant, for \(petition.price)" }

    /// Why it can't be granted now, in the realm's words.
    static func why(_ refusal: RuleError) -> String {
        refusal == .notApplicable ? "Their need has passed." : refusal.description
    }
}
