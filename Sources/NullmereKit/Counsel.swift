import NullmereCore

/// A steward's quiet advice for the opening of a game: the next sensible
/// thing to do, until the House has found its feet.
enum Counsel {
    /// Advice stops once the House has this many holds, or after this watch.
    static let holdsToStop = 3
    static let lastWatch = 40

    static func advice(for state: GameState, player: Int) -> String? {
        guard state.outcome == nil else { return nil }
        if let warning = race(in: state, player: player) { return warning }
        guard state.watch <= lastWatch else { return nil }
        let holds = state.holds(of: player)
        guard holds.count < holdsToStop, let seat = state.seat(of: player) else { return nil }
        let units = state.units(of: player)
        let stock = state.houses[player].stock

        if state.watch == 1, units.contains(where: { $0.kind == .lantern && $0.destination == nil && $0.movesLeft > 0 }) {
            return "Your seat, \(seat.name), stands by the dead water. Send your Lantern into the mist: select it, then right-click where it should go. Press ? for the guide."
        }
        if let founder = units.first(where: { $0.kind == .founder }) {
            if state.canFound(at: founder.position, for: player) == nil {
                return "Your Founders stand on good ground. Select them and choose Found Hold, or press B."
            }
            return "March your Founders to open land at least three tiles from any hold, then found a new hold there."
        }
        if seat.training?.kind == .founder {
            return "Founders are mustering at \(seat.name). While they gather, raise works at the seat."
        }
        if holds.count == 1, seat.training == nil {
            let cost = state.trainingCost(of: .founder, for: player)
            return stock.covers(cost)
                ? "A House with one hold is a small House. Select \(seat.name) and train Founders to raise a second."
                : "Gather for Founders: they cost \(cost). Raise a Granary or Sawpit while you wait."
        }
        if holds.contains(where: { $0.project == nil }) {
            return "A hold stands idle. Select it and raise a work: each level brings in more of what its land yields."
        }
        return "End the watch with ⌘↩ when every company has its orders. The game keeps itself after every watch."
    }

    /// Later, counsel speaks only when the race for the lake is close.
    static func race(in state: GameState, player: Int) -> String? {
        let standings = state.standings()
        if let rival = standings.first(where: { $0.house != player && $0.threat != nil }) {
            let name = state.houses[rival.house].title
            if rival.threat == .ascendancy {
                let seat = state.seat(of: rival.house)?.name ?? "its seat"
                return "\(name) is one stage from finishing its Moonspire at \(seat). Break that seat's ward and take it, and the tower falls with it."
            }
            return "\(name) rules \(rival.realm) of the \(rival.needed) holds it needs for dominion. Take its holds, or free its vassals by making war on it."
        }
        if let mine = standings.first(where: { $0.house == player }), let threat = mine.threat {
            if threat == .ascendancy {
                return "One stage more on your Moonspire and the lake is yours. Every rival will march on your seat: keep its walls manned."
            }
            let short = max(mine.needed - mine.realm, 0)
            return "Your realm holds \(mine.realm) of the \(mine.needed) holds dominion needs. \(short == 0 ? "Hold them" : "Take \(short) more") and the lake is yours."
        }
        return nil
    }
}
