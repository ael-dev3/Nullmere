extension GameState {
    /// What raising a seat anew costs: Rise of Kingdoms' teleport, here
    /// within a House's own land.
    public static let seatMoveCost = Stock(moonsalt: 40)
    /// How many watches after a seat is raised anew before it may be again.
    public static let seatMoveRest = 30
    /// How near a foe at war keeps a seat where it stands.
    public static let seatMoveFoeReach = 3

    /// What raising a seat anew does, said beside it on the Mac and the phone.
    public static var seatMoveSaid: String {
        "Raise your seat anew here: its works, walls and ward as they stand, and the company at its gates with it. "
            + "Once in \(seatMoveRest) watches, and never while it is beset."
    }

    /// Why a keeper can't raise their House's seat anew on a hex now, if
    /// they can't: the ground must be open and settleable, of the House's
    /// own land, three tiles from every other hold and clear of holy sites,
    /// alliance ground and others' companies; the seat's ward whole, no foe
    /// at war within three tiles of it, rested thirty watches since it was
    /// last raised anew, and the moonsalt for it.
    public func seatMoveRefusal(to hex: Hex, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        guard let seat = seat(of: house) else { return .unknownHold }
        if let raised = seat.raisedAnew, watch < raised + GameState.seatMoveRest {
            return .seatRaisedLately(until: raised + GameState.seatMoveRest)
        }
        guard hex != seat.position else { return .notApplicable }
        guard let tile = map[hex] else { return .outsideTheWorld }
        guard tile.terrain.isSettleable else { return .cannotSettle(tile.terrain) }
        guard territoryOwner(of: hex) == house else { return .foreignTerritory }
        if holds.contains(where: { $0.id != seat.id && $0.position.distance(to: hex) < 3 }) { return .tooCloseToHold }
        if shrine(at: hex) != nil { return .holySite }
        if standard(at: hex) != nil || hall(at: hex) != nil || storehouse(at: hex) != nil || site(at: hex)?.isYard == true {
            return .allianceGround
        }
        if let standing = unit(at: hex), standing.owner != house { return .occupiedGround }
        guard seat.ward >= seat.maximumWard else { return .seatBeset }
        if units.contains(where: { isAtWar(house, $0.owner) && $0.position.distance(to: seat.position) <= GameState.seatMoveFoeReach }) {
            return .seatBeset
        }
        let stock = houses[house].stock
        guard stock.covers(GameState.seatMoveCost) else { return .shortOf(stock.shortfall(for: GameState.seatMoveCost)) }
        return nil
    }

    /// A keeper raises their House's seat anew on its own land: its works,
    /// walls, ward and wounded as they stood, and the company keeping its
    /// gates with it, if the new ground is clear.
    mutating func raiseSeatAnew(at hex: Hex, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = seatMoveRefusal(to: hex, as: house) { throw refusal }
        guard let seat = seat(of: house), let index = holdIndex(seat.id) else { throw .unknownHold }
        houses[house].stock.debit(GameState.seatMoveCost)
        let from = seat.position
        if unit(at: hex) == nil, let keeper = units.firstIndex(where: { $0.owner == house && $0.position == from }) {
            units[keeper].position = hex
            units[keeper].destination = nil
            units[keeper].way = nil
        }
        holds[index].position = hex
        holds[index].raisedAnew = watch
        reveal(around: hex, range: 2, for: house)
        record(.founding, [house], "\(houses[house].title) raises its seat, \(seat.name), anew \(placeName(of: hex)).")
        return [.seatRaisedAnew(hold: seat.id, house: house, from: from, to: hex)]
    }
}
