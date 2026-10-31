import NullmereCore
import SwiftUI

/// The Augury on the Realm screen: each prophecy open, what it foretells
/// and by when, what is laid on either side and until when, with a stake
/// to lay backing it or against it; those lately judged; and, folded until
/// asked for, a prophecy of the keeper's own: what it foretells, of which
/// House or Houses, and spoken with its stake.
struct AugurySection: View {
    let session: GameSession

    /// What a prophecy being made foretells, before its Houses are chosen.
    enum Kind: CaseIterable {
        case falls, takesAHold, war, spireRises

        var title: String {
            switch self {
            case .falls: return "A House falls"
            case .takesAHold: return "A House takes a hold"
            case .war: return "Two Houses at war"
            case .spireRises: return "A Moonspire rises"
            }
        }
    }

    /// How many watches ahead a prophecy made here looks, and the moonsalt
    /// each stake laid here is.
    static let span = 12
    static let stake = 10

    @State private var composing: Bool
    @State private var kind: Kind?
    @State private var first: Int?
    @State private var second: Int?

    /// The section begins folded, or, for a prophecy being made, open with
    /// as much of it chosen as is given.
    init(session: GameSession, composing: Bool = false, kind: Kind? = nil, first: Int? = nil, second: Int? = nil) {
        self.session = session
        _composing = State(initialValue: composing)
        _kind = State(initialValue: kind)
        _first = State(initialValue: first)
        _second = State(initialValue: second)
    }

    /// The prophecy the choices make, once they are enough: a Moonspire's
    /// next stage, war between two Houses.
    static func claim(_ kind: Kind, first: Int?, second: Int?, in state: GameState) -> Prophecy.Claim? {
        guard let first else { return nil }
        switch kind {
        case .falls: return .falls(house: first)
        case .takesAHold: return .takesAHold(house: first)
        case .war: return second.map { .war(first, $0) }
        case .spireRises: return .spireRises(house: first, stage: state.highest(.moonspire, of: first) + 1)
        }
    }

    /// How a prophecy stands, in a line: what is laid on each side, and
    /// until when; or how the realm judged it.
    static func standing(_ prophecy: Prophecy, at watch: Int) -> String {
        let laid = "\(prophecy.laid(backing: true)) moonsalt backing it, \(prophecy.laid(backing: false)) against"
        switch prophecy.cameToPass {
        case true?: return "Came to pass. \(laid)."
        case false?: return "Failed. \(laid)."
        case nil:
            return watch <= prophecy.stakesClose ? "\(laid); stakes close at watch \(prophecy.stakesClose)." : "\(laid); stakes are closed."
        }
    }

    var body: some View {
        let state = session.state, me = session.player
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Caps("The Augury", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                Spacer()
                QuietButton(title: composing ? "Fold the prophecy" : "Foretell…", size: 8.5,
                            name: composing ? "Fold the prophecy away" : "Foretell a turn of the realm's course") {
                    composing.toggle()
                    kind = nil
                    first = nil
                    second = nil
                }
            }
            if state.prophecies.isEmpty {
                Text(verbatim: "No prophecy is spoken. Foretell a turn of the realm's course by a watch to come and stake moonsalt on it: "
                     + "others back it or stand against it, and the realm judges it, the side that saw true sharing every stake.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(state.prophecies.reversed())) { prophecy in
                line(prophecy, in: state, player: me)
            }
            if composing {
                composer(in: state, player: me)
            }
        }
    }

    /// A prophecy: who foretold what and by when, how it stands, and the
    /// stakes the keeper may lay on it.
    private func line(_ prophecy: Prophecy, in state: GameState, player me: Int) -> some View {
        let prophet = prophecy.by == me ? "You foretold" : "\(state.houses[prophecy.by].title) foretells"
        let open = prophecy.isOpen && state.stakeRefusal(on: prophecy.id, moonsalt: AugurySection.stake, as: me) == nil
        return VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: "\(prophet) that \(state.told(prophecy.claim)) by watch \(prophecy.until).")
                .font(.nm(11))
                .foregroundStyle(Palette.text(prophecy.isOpen ? 0.88 : 0.6))
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: AugurySection.standing(prophecy, at: state.watch))
                .font(.nm(10))
                .foregroundStyle(prophecy.cameToPass == true ? Palette.good : Palette.text(0.55))
            if open {
                HStack(spacing: 8) {
                    QuietButton(title: "Back it", size: 8.5, name: "Back the prophecy with \(AugurySection.stake) moonsalt") {
                        session.perform(.stake(prophecy: prophecy.id, backs: true, moonsalt: AugurySection.stake))
                    }
                    QuietButton(title: "Stand against it", size: 8.5, name: "Stand against the prophecy with \(AugurySection.stake) moonsalt") {
                        session.perform(.stake(prophecy: prophecy.id, backs: false, moonsalt: AugurySection.stake))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// A prophecy of the keeper's own: what it foretells, then of which
    /// House, or which two, then spoken with its stake.
    @ViewBuilder
    private func composer(in state: GameState, player me: Int) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 4) {
            ForEach(Kind.allCases, id: \.self) { choice in
                QuietButton(title: choice.title, size: 8.5, prominent: kind == choice) {
                    kind = choice
                    first = nil
                    second = nil
                }
            }
        }
        if let kind {
            let picking = kind == .war && first != nil
            Text(verbatim: picking ? "At war with which House?" : "Of which House?")
                .font(.nm(10))
                .foregroundStyle(Palette.text(0.6))
            FlowLayout(spacing: 6, lineSpacing: 4) {
                ForEach(state.livingHouses.filter { !picking || $0.id != first }) { house in
                    let named = house.id == me ? "Your House" : house.title
                    QuietButton(title: picking ? "With \(named)" : "Of \(named)", size: 8.5,
                                prominent: (picking ? second : first) == house.id) {
                        if picking { second = house.id } else { first = house.id }
                    }
                }
            }
            if let claim = AugurySection.claim(kind, first: first, second: second, in: state) {
                let until = state.watch + AugurySection.span
                let refusal = state.prophecyRefusal(claim, until: until, moonsalt: AugurySection.stake, as: me)
                Text(verbatim: "That \(state.told(claim)) by watch \(until), staking \(AugurySection.stake) moonsalt.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                QuietButton(title: "Foretell", size: 8.5, enabled: refusal == nil, name: "Foretell it, staking \(AugurySection.stake) moonsalt",
                            why: refusal?.description) {
                    if session.perform(.prophesy(claim, until: until, moonsalt: AugurySection.stake)) {
                        composing = false
                    }
                }
            }
        }
    }
}
