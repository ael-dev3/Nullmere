import NullmereCore
import SwiftUI

/// The titles of the Spire on the Realm screen: who holds the broken Spire,
/// and so names the realm's titles; each title borne, and by which House;
/// and, for the keeper whose House holds it, folded until asked for, each
/// title to choose and the House to name to it.
struct TitlesSection: View {
    let session: GameSession

    @State private var open: Bool
    /// The title being named, chosen before the House it goes to.
    @State private var naming: Title?

    /// `open` and `naming` begin the section: folded, or open with a title
    /// already chosen to name a House to.
    init(session: GameSession, open: Bool = false, naming: Title? = nil) {
        self.session = session
        _open = State(initialValue: open)
        _naming = State(initialValue: naming)
    }

    /// Who names the realm's titles, in a line.
    static func giverLine(_ state: GameState, player: Int) -> String {
        guard let spire = state.holySites.first(where: { $0.kind == .brokenSpire }) else {
            return "No broken Spire stands this age, and no titles are named."
        }
        guard let holder = spire.holder, state.houses.indices.contains(holder) else {
            return "The broken Spire is held by none. A keeper's House that holds it names the realm's titles."
        }
        if state.titleGiver == player { return "Your House holds the broken Spire: you name the realm's titles." }
        if state.titleGiver == holder { return "\(state.houses[holder].title) holds the broken Spire, and names the realm's titles." }
        return "\(state.houses[holder].title) holds the broken Spire; its steward names no titles."
    }

    var body: some View {
        let state = session.state, me = session.player
        let giver = state.titleGiver == me
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Caps("Titles of the Spire", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                Spacer()
                if giver {
                    QuietButton(title: open ? "Fold the titles" : "Name a title…", size: 8.5,
                                name: open ? "Fold the titles away" : "Name a House to one of the realm's titles") {
                        open.toggle()
                        naming = nil
                    }
                }
            }
            Text(verbatim: TitlesSection.giverLine(state, player: me))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.7))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(state.titlesBorne, id: \.title) { borne in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: borne.title.title)
                            .font(.nm(11, weight: .medium))
                            .foregroundStyle(borne.title.isBoon ? Palette.good : Palette.bad)
                        Spacer()
                        Text(verbatim: borne.house == me ? "Your House" : state.houses[borne.house].title)
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.7))
                    }
                    Text(verbatim: borne.title.effect).font(.nm(10)).foregroundStyle(Palette.text(0.55))
                }
                .accessibilityElement(children: .combine)
            }
            if giver, open {
                // A title chosen, then the House named to it.
                FlowLayout(spacing: 6, lineSpacing: 4) {
                    ForEach(Title.allCases, id: \.self) { title in
                        QuietButton(title: title.title, size: 8.5, prominent: naming == title, name: "Name a House \(title.title)") {
                            naming = naming == title ? nil : title
                        }
                    }
                }
                if let naming {
                    Text(verbatim: "\(naming.title), \(naming.effect). Name a House to it:")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spacing: 6, lineSpacing: 4) {
                        ForEach(state.livingHouses.filter { $0.id != me }) { house in
                            let refusal = state.bestowRefusal(naming, on: house.id, as: me)
                            QuietButton(title: "Name \(house.title)", size: 8.5, enabled: refusal == nil,
                                        name: "Name \(house.title) \(naming.title)", why: refusal?.description) {
                                if session.perform(.bestow(naming, on: house.id)) { self.naming = nil }
                            }
                        }
                    }
                }
            }
        }
    }
}
