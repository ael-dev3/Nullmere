/// A company of war carried from the field to an Infirmary: kept in one of
/// its beds until its House pays for its healing, and lost if its hold
/// falls first.
public struct Wounded: Codable, Equatable, Sendable {
    public let kind: UnitKind
    public let tier: Int
    /// The battles it had lived through: it rises with its rank.
    public let experience: Int
    /// The watch it was carried in.
    public let since: Int
    /// Its healing is paid for: it rises whole as the watch turns.
    public internal(set) var healing: Bool

    public init(kind: UnitKind, tier: Int, experience: Int, since: Int, healing: Bool = false) {
        self.kind = kind
        self.tier = tier
        self.experience = experience
        self.since = since
        self.healing = healing
    }
}

extension GameState {
    /// What healing a company costs, in percent of what mustering it anew
    /// would.
    public static let healingPercent = 50

    /// What healing a wounded company costs its House.
    public func healingCost(of wounded: Wounded, for house: Int) -> Stock {
        trainingCost(of: wounded.kind, tier: wounded.tier, for: house).scaled(percent: GameState.healingPercent)
    }

    /// What healing every company in a hold's beds not yet being healed
    /// would cost its House.
    public func healingCost(at hold: Hold) -> Stock {
        (hold.wounded ?? []).filter { !$0.healing }.reduce(Stock.zero) { $0 + healingCost(of: $1, for: hold.owner) }
    }

    /// A company of war that falls is carried to the nearest of its House's
    /// holds with a bed free in its Infirmary, if one has, and kept there;
    /// none is carried into a hold with a foe at its gates.
    mutating func carryToInfirmary(_ unit: Unit) -> [GameEvent] {
        guard unit.kind.isMilitary, houses.indices.contains(unit.owner), !houses[unit.owner].isEliminated else { return [] }
        let open = holds.indices.filter { holds[$0].owner == unit.owner && holds[$0].freeBeds > 0 && !isBesieged(holds[$0]) }
        guard let index = open.min(by: { a, b in
            (holds[a].position.distance(to: unit.position), holds[a].id) < (holds[b].position.distance(to: unit.position), holds[b].id)
        }) else { return [] }
        let carried = Wounded(kind: unit.kind, tier: unit.tier, experience: unit.experience, since: watch)
        holds[index].wounded = (holds[index].wounded ?? []) + [carried]
        return [.carriedToInfirmary(kind: unit.kind, owner: unit.owner, hold: holds[index].id)]
    }

    /// Pays for the healing of as many of a hold's wounded as its House's
    /// stores cover, those carried in first healed first; they rise whole
    /// as the watch turns.
    mutating func heal(at holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let index = holdIndex(holdID) else { throw .unknownHold }
        guard holds[index].owner == house else { throw .notYours }
        let waiting = (holds[index].wounded ?? []).indices.filter { !holds[index].wounded![$0].healing }
        guard let first = waiting.first else { throw .noneWounded }
        var healed = 0
        for slot in waiting {
            let cost = healingCost(of: holds[index].wounded![slot], for: house)
            guard houses[house].stock.covers(cost) else { break }
            houses[house].stock.debit(cost)
            holds[index].wounded![slot].healing = true
            healed += 1
        }
        guard healed > 0 else { throw .shortOf(healingCost(of: holds[index].wounded![first], for: house)) }
        return [.healingBegun(hold: holdID, house: house, count: healed)]
    }

    /// As the watch turns, the companies whose healing is paid for rise
    /// whole beside their hold, as they were when they fell, its commander
    /// aside; one with no room beside it, or with a foe at the hold's
    /// gates, waits a watch.
    mutating func raiseTheHealed() -> [GameEvent] {
        var events: [GameEvent] = []
        for index in holds.indices {
            guard let wounded = holds[index].wounded, wounded.contains(where: \.healing), !isBesieged(holds[index]) else { continue }
            var kept: [Wounded] = []
            for company in wounded {
                guard company.healing,
                      let unit = placeUnit(company.kind, tier: company.tier, for: holds[index].owner, near: holds[index].position),
                      let placed = unitIndex(unit.id) else {
                    kept.append(company)
                    continue
                }
                units[placed].experience = company.experience
                events.append(.unitHealed(unit: unit.id, hold: holds[index].id))
            }
            holds[index].wounded = kept.isEmpty ? nil : kept
        }
        return events
    }

    /// A hold taken: those lying in its beds are lost with it.
    mutating func loseTheWounded(at index: Int, from house: Int) -> [GameEvent] {
        guard let count = holds[index].wounded?.count, count > 0 else { return [] }
        holds[index].wounded = nil
        return [.woundedLost(hold: holds[index].id, house: house, count: count)]
    }
}
