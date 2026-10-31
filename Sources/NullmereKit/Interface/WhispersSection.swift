import NullmereCore
import SwiftUI

/// Whispers on the water on the Realm screen: each whisper the realm
/// remembers, unsigned, and how it stands for the keeper: unproven, tried
/// by their Lanterns, or found false and its teller named; and, folded
/// until asked for, a whisper of the keeper's own: what it says, of which
/// House, at which hold for a host, and let loose for its moonsalt.
struct WhispersSection: View {
    let session: GameSession

    /// What a whisper being made says, before its House is chosen.
    enum Kind: CaseIterable {
        case host, granaries, walls

        var title: String {
            switch self {
            case .host: return "A host gathered"
            case .granaries: return "Granaries low"
            case .walls: return "Walls broken"
            }
        }
    }

    /// The whispers shown, the latest first.
    static let shown = 5

    @State private var composing: Bool
    @State private var kind: Kind?
    @State private var house: Int?

    /// The section begins folded, or, for a whisper being made, open with
    /// as much of it chosen as is given.
    init(session: GameSession, composing: Bool = false, kind: Kind? = nil, house: Int? = nil) {
        self.session = session
        _composing = State(initialValue: composing)
        _kind = State(initialValue: kind)
        _house = State(initialValue: house)
    }

    /// The whisper the choices make, once they are enough: a host, at a
    /// hold of its House.
    static func claim(_ kind: Kind, house: Int?, hold: Int? = nil) -> Whisper.Claim? {
        guard let house else { return nil }
        switch kind {
        case .host: return hold.map { .hostGathered(house: house, hold: $0) }
        case .granaries: return .granariesLow(house: house)
        case .walls: return .seatBreached(house: house)
        }
    }

    /// How a whisper stands for the keeper, in a line.
    static func standing(_ whisper: Whisper, in state: GameState, player: Int) -> String {
        if whisper.unmasked, let teller = whisper.by {
            return "Found false: it was \(teller == player ? "yours" : state.houses[teller].title + "'s")."
        }
        let yours = whisper.by == player ? "Yours. " : ""
        switch whisper.truth {
        case true?: return yours + "True, as your Lanterns found."
        case false?: return yours + "False, as your Lanterns found."
        case nil:
            let until = whisper.spoken + GameState.whisperReach
            guard state.watch <= until, whisper.claim.house != player else { return yours + "Unproven." }
            return yours + "Unproven: your Lanterns may try it at any hold of that House until watch \(until)."
        }
    }

    var body: some View {
        let state = session.state, me = session.player
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Caps("Whispers on the water", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                Spacer()
                QuietButton(title: composing ? "Fold the whisper" : "Whisper…", size: 8.5,
                            name: composing ? "Fold the whisper away" : "Let a whisper loose about another House, unsigned") {
                    composing.toggle()
                    kind = nil
                    house = nil
                }
            }
            if state.whispersHeard.isEmpty {
                Text(verbatim: "No whisper is abroad. Let one loose about another House, unsigned: the realm hears it but not whose it is. "
                     + "Lanterns that scout that House's holds learn whether it is true, and one found false names its teller.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(state.whispersHeard.suffix(WhispersSection.shown).reversed())) { whisper in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Watch \(whisper.spoken): \(state.told(whisper.claim)).")
                        .font(.nm(11))
                        .foregroundStyle(Palette.text(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: WhispersSection.standing(whisper, in: state, player: me))
                        .font(.nm(10))
                        .foregroundStyle(whisper.unmasked ? Palette.bad : Palette.text(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if composing {
                composer(in: state, player: me)
            }
        }
    }

    /// A whisper of the keeper's own: what it says, of which House, and, for
    /// a host, at which of its holds; then let loose.
    @ViewBuilder
    private func composer(in state: GameState, player me: Int) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 4) {
            ForEach(Kind.allCases, id: \.self) { choice in
                QuietButton(title: choice.title, size: 8.5, prominent: kind == choice) {
                    kind = choice
                    house = nil
                }
            }
        }
        if let kind {
            Text(verbatim: "Of which House?")
                .font(.nm(10))
                .foregroundStyle(Palette.text(0.6))
            FlowLayout(spacing: 6, lineSpacing: 4) {
                ForEach(state.livingHouses.filter { $0.id != me }) { other in
                    QuietButton(title: "Of \(other.title)", size: 8.5, prominent: house == other.id) {
                        house = other.id
                    }
                }
            }
            if let house {
                // A host at one of the holds of that House the keeper knows; else the House's own word.
                let holds: [Int?] = kind == .host ? state.holds.filter { $0.owner == house }.map { Optional($0.id) } : [nil]
                ForEach(holds, id: \.self) { hold in
                    if let claim = WhispersSection.claim(kind, house: house, hold: hold) {
                        let refusal = state.whisperRefusal(claim, as: me)
                        QuietButton(title: "Whisper that \(state.told(claim))", size: 8.5, enabled: refusal == nil,
                                    name: "Whisper that \(state.told(claim)), for \(GameState.whisperCost)", why: refusal?.description) {
                            if session.perform(.whisper(claim)) { composing = false }
                        }
                    }
                }
            }
        }
    }
}
