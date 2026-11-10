/// A company raised a tier where it stands, by a Muster Hall of its House's
/// at or beside it (Rise of Kingdoms' troop upgrade), so a House need not
/// muster anew to field what its studies and its hall now allow. It pays
/// what the next tier's muster costs over this one's, as its House pays for
/// musters, as many times over as its whole muster is its first, and spends
/// the watch at it. It keeps its troops drilled since, its commanders, its
/// rank and its health; the next tier's first muster is the larger, so its
/// ranks fill out with it. Stewards don't raise their companies: their ages
/// play as they did.
extension GameState {
    /// What raising a company a tier costs its House: the next tier's
    /// muster less this one's, with the House's studies, for each first
    /// muster's worth of its whole muster, rounded up.
    public func raiseCost(of unit: Unit) -> Stock {
        let next = trainingCost(of: unit.kind, tier: unit.tier + 1, for: unit.owner)
        let now = trainingCost(of: unit.kind, tier: unit.tier, for: unit.owner)
        let percent = musterPercent(of: unit)
        var cost = Stock()
        for resource in Resource.allCases {
            cost[resource] = (max(next[resource] - now[resource], 0) * percent + 99) / 100
        }
        return cost
    }

    /// Why a company can't be raised a tier where it stands, if it can't:
    /// one of a kind of tiers, below its kind's highest, standing still and
    /// out of the fighting at or beside a hold of its House whose Muster
    /// Hall, and the House's studies, allow the next tier, and paid for.
    public func raiseRefusal(of unit: Unit, as house: Int) -> RuleError? {
        guard unit.owner == house else { return .notYours }
        guard unit.kind.hasTiers else { return .oneTierOnly(unit.kind) }
        guard unit.tier < unit.kind.highestTier else { return .atHighestTier }
        guard field(of: unit.id) == nil else { return .raisedOutOfBattle }
        guard unit.destination == nil, unit.errand == nil else { return .raisedStandingStill }
        guard let hold = drillHold(for: unit) else { return .raisedAtMusterHall }
        if let refusal = tierRefusal(of: unit.kind, tier: unit.tier + 1, at: hold, for: house) { return refusal }
        let cost = raiseCost(of: unit)
        guard houses[house].stock.covers(cost) else { return .shortOf(houses[house].stock.shortfall(for: cost)) }
        return nil
    }

    /// What a company would be a tier higher, as every line names it: its
    /// House's own company's name at the fifth tier of its heritage's kind.
    public func raisedName(of unit: Unit) -> String {
        named(unit.kind, tier: unit.tier + 1, of: unit.owner)
    }

    /// What raising a company would make it, said as its panel and the
    /// phone offer it: "Raise to Spears III: 240 grain, 180 timber".
    public func raiseSaid(of unit: Unit) -> String {
        "Raise to \(raisedName(of: unit)): \(raiseCost(of: unit).listedSaid)"
    }

    mutating func raiseTier(_ unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        if let refusal = raiseRefusal(of: units[index], as: house) { throw refusal }
        houses[house].stock.debit(raiseCost(of: units[index]))
        units[index].tier += 1
        units[index].movesLeft = 0
        return [.tierRaised(unit: unitID, owner: house, tier: units[index].tier)]
    }
}
