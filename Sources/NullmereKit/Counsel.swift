import NullmereCore

/// A steward's quiet advice for the opening of a game: the next sensible
/// thing to do, until the House has found its feet.
enum Counsel {
    /// Advice stops once the House has this many holds, or after this watch.
    static let holdsToStop = 3
    static let lastWatch = 40

    static func advice(for state: GameState, player: Int) -> String? {
        guard state.outcome == nil, state.watch <= lastWatch else { return nil }
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
}
