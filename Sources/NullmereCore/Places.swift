extension Hold {
    /// How many places a hold's works may be set in round its keep: twelve
    /// about it, and six further out.
    public static let placeCount = 18

    /// Where a work stands if its keeper has set it.
    public func place(of kind: BuildingKind) -> Int? {
        places?[kind]
    }
}

extension GameState {
    /// Why a work of a hold can't be set in a place now, if it can't: the
    /// hold must be the House's, the work raised or rising in it, and the
    /// place one of the hold's. The walls ring the keep, set by none.
    public func placeRefusal(_ kind: BuildingKind, of holdID: Int, at place: Int, as house: Int) -> RuleError? {
        guard let hold = hold(holdID) else { return .unknownHold }
        guard hold.owner == house else { return .notYours }
        guard kind != .walls, hold.level(kind) > 0 || hold.project?.kind == kind,
              (0..<Hold.placeCount).contains(place) else { return .notApplicable }
        return nil
    }

    /// A keeper sets a work of a hold in a place; a work set there before
    /// takes the moved work's place, or, had it none, stands where the
    /// hold's ground suits it again.
    mutating func set(_ kind: BuildingKind, of holdID: Int, at place: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = placeRefusal(kind, of: holdID, at: place, as: house) { throw refusal }
        let index = try ownedHold(holdID, of: house)
        var places = holds[index].places ?? [:]
        let before = places[kind]
        if let other = places.first(where: { $0.key != kind && $0.value == place })?.key {
            places[other] = before
        }
        places[kind] = place
        holds[index].places = places
        return [.workPlaced(hold: holdID, kind: kind, place: place)]
    }
}
