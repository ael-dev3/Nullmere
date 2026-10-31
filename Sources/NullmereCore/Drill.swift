/// Drill: a company of war standing at or beside one of its House's holds
/// with a Muster Hall may drill there, taking on troops beyond its first
/// muster as each watch turns, as many as the hall drills, up to as many as
/// it can lead: as its House's best Muster Hall allows, and more with a
/// commander at its head. Each troop is paid for in grain, and no hall
/// drills troops its House's grain can't feed. Every troop counts: a
/// company fights others the harder the more its troops, as the square
/// root of its muster over its first, eats more for them, and its losses
/// are told in them; walls, wards and the wilds are struck as before. So a
/// realm's armies grow through an age from thousands to hundreds of
/// thousands, as a kingdom's do.
extension GameState {
    /// Grain that drilling one first muster's worth of troops costs at the
    /// first tier; dearer by tier as mustering is.
    public static let drillCost = Stock(grain: 12)

    /// A company's first muster: as many as its kind musters at its tier.
    public func firstMuster(of unit: Unit) -> Int {
        unit.kind.troops(tier: unit.tier)
    }

    /// How many it musters whole: its first muster and those drilled since.
    public func fullMuster(of unit: Unit) -> Int {
        firstMuster(of: unit) + max(unit.drilled ?? 0, 0)
    }

    /// Its whole muster in percent of its first: 100, undrilled.
    public func musterPercent(of unit: Unit) -> Int {
        fullMuster(of: unit) * 100 / max(firstMuster(of: unit), 1)
    }

    /// How much harder its troops make a company fight, in percent: as the
    /// square root of its muster over its first, so every troop counts and
    /// each the less the more there are. Nine times its first muster fights
    /// three times as hard.
    public func musterMight(of unit: Unit) -> Int {
        Int((Double(musterPercent(of: unit)) * 100).squareRoot().rounded())
    }

    /// The times its first muster a company may lead: once, four times
    /// more for each level of its House's best Muster Hall, and once more
    /// for every three levels of the commander at its head.
    public func drillTimes(of unit: Unit) -> Int {
        let hall = holds(of: unit.owner).map { $0.level(.musterHall) }.max() ?? 0
        let led = unit.leader.flatMap(commander).map { $0.level / 3 } ?? 0
        return 1 + 4 * hall + led
    }

    /// The most a company may muster.
    public func drillCapacity(of unit: Unit) -> Int {
        firstMuster(of: unit) * drillTimes(of: unit)
    }

    /// Troops a Muster Hall of a level drills into a company as a watch
    /// turns: half its first muster for each level.
    public func drillRate(of unit: Unit, hall level: Int) -> Int {
        firstMuster(of: unit) * max(level, 0) / 2
    }

    /// The hold whose Muster Hall drills a company where it stands: of its
    /// House's at or beside it, the one whose hall is highest.
    public func drillHold(for unit: Unit) -> Hold? {
        unit.position.spiral(1).compactMap { hold(at: $0) }
            .filter { $0.owner == unit.owner && $0.level(.musterHall) > 0 }
            .max { ($0.level(.musterHall), -$0.id) < ($1.level(.musterHall), -$1.id) }
    }

    /// What drilling so many troops into a company costs, rounded up.
    public func drillCost(of unit: Unit, troops: Int) -> Stock {
        let percent = Unit.tierCost[Unit.tierIndex(unit.tier, of: unit.kind)]
        let per = max(firstMuster(of: unit), 1) * 100
        func part(_ amount: Int) -> Int { (amount * percent * max(troops, 0) + per - 1) / per }
        return Stock(grain: part(GameState.drillCost.grain), moonsalt: part(GameState.drillCost.moonsalt))
    }

    /// The most troops a company could be drilled for with these stores.
    func troopsAffordable(for unit: Unit, with stock: Stock) -> Int {
        let percent = Unit.tierCost[Unit.tierIndex(unit.tier, of: unit.kind)]
        let per = max(firstMuster(of: unit), 1) * 100
        func most(_ have: Int, _ price: Int) -> Int { price <= 0 ? .max : max(have, 0) * per / (price * percent) }
        return min(most(stock.grain, GameState.drillCost.grain), most(stock.moonsalt, GameState.drillCost.moonsalt))
    }

    /// Why a company can't drill where it stands, if it can't.
    public func drillRefusal(of unit: Unit) -> RuleError? {
        guard unit.kind.hasTiers, drillHold(for: unit) != nil else { return .drillsAtMusterHall }
        guard fullMuster(of: unit) < drillCapacity(of: unit) else { return .drilledWhole }
        return nil
    }

    /// Whether a company drills where it stands now.
    public func isDrilling(_ unit: Unit) -> Bool {
        unit.drillAt == unit.position && drillRefusal(of: unit) == nil
    }

    mutating func drill(_ unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        if let refusal = drillRefusal(of: units[index]) { throw refusal }
        // Drilling is staying: a march in hand is let go.
        units[index].drillAt = units[index].position
        units[index].destination = nil
        return []
    }

    /// Troops to drill into a company now: what its hall drills, as many as
    /// may be led, as its House can pay for, and as many as the grain its
    /// House has to spare can feed, the hungrier for each.
    func drillNow(_ unit: Unit, hall level: Int, spare: Int) -> Int {
        var troops = min(drillCapacity(of: unit) - fullMuster(of: unit), drillRate(of: unit, hall: level),
                         troopsAffordable(for: unit, with: houses[unit.owner].stock))
        while troops > 0 {
            var drilled = unit
            drilled.drilled = (unit.drilled ?? 0) + troops
            if upkeep(of: drilled) - upkeep(of: unit) <= spare { break }
            troops = troops * 3 / 4
        }
        return max(troops, 0)
    }

    /// As the watch turns, each company drilling where it stands that kept
    /// still through the watch takes on what its hall drills: as many as its
    /// House can pay for, and no more than its grain can feed, the House's
    /// grain income still covering what its companies eat.
    mutating func drillCompanies(territory owners: [Int?]) -> [GameEvent] {
        var events: [GameEvent] = []
        var spareGrain: [Int: Int] = [:]
        func spare(of house: Int) -> Int {
            spareGrain[house] ?? (income(of: house, territory: owners).grain - upkeep(of: house))
        }
        for index in units.indices {
            guard let at = units[index].drillAt else { continue }
            let unit = units[index]
            guard unit.position == at, let hold = drillHold(for: unit), drillRefusal(of: unit) == nil else {
                // Gone from where it drilled, the hall lost, or whole.
                units[index].drillAt = nil
                continue
            }
            guard !unit.acted else { continue }
            let house = unit.owner
            let left = spare(of: house)
            let troops = drillNow(unit, hall: hold.level(.musterHall), spare: left)
            spareGrain[house] = left
            guard troops > 0 else { continue }
            let standing = self.troops(of: unit)
            houses[house].stock.debit(drillCost(of: unit, troops: troops))
            units[index].drilled = (unit.drilled ?? 0) + troops
            let whole = fullMuster(of: units[index])
            // The newly drilled stand whole beside those already standing.
            units[index].health = min(100, max(1, ((standing + troops) * 100 + whole / 2) / whole))
            spareGrain[house] = left - (upkeep(of: units[index]) - upkeep(of: unit))
            let full = whole >= drillCapacity(of: units[index])
            if full { units[index].drillAt = nil }
            events.append(.drilled(unit: unit.id, owner: house, troops: troops, whole: full))
        }
        return events
    }
}
