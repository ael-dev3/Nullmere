/// Ferries of the Still: the black lake carries what the land can't. A
/// keeper may set a company of theirs, standing at a hold of their House
/// on the shore, on a barge poled across the still water to another of
/// their shore holds. It is out on the water through the watch, and as the
/// watch turns it lands, unless another company holds the landing; then it
/// turns back to where it set out. A way across the lake that no road
/// gives, and no other game of its kind: the water is no one's, but to
/// cross it a House needs holds on both its shores.
public struct Ferrying: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { unit }
    /// The company aboard.
    public let unit: Int
    public let owner: Int
    /// The holds it set out from and makes for.
    public let from: Int
    public let to: Int
    /// The water it pushed off from and makes for, beside each hold.
    public let pushOff: Hex
    public let landing: Hex
    /// The watch it set out.
    public let set: Int

    public init(unit: Int, owner: Int, from: Int, to: Int, pushOff: Hex, landing: Hex, set: Int) {
        self.unit = unit
        self.owner = owner
        self.from = from
        self.to = to
        self.pushOff = pushOff
        self.landing = landing
        self.set = set
    }
}

extension GameState {
    /// What the ferrymen ask for a crossing.
    public static let ferryCost = Stock(timber: 25)

    /// Every crossing under way.
    public var crossingsUnderWay: [Ferrying] { barges ?? [] }

    /// The crossing a company is on, if it is on the water.
    public func crossing(of unit: Int) -> Ferrying? {
        barges?.first { $0.unit == unit }
    }

    /// The holds a keeper's company may be ferried to from where it stands:
    /// the House's other holds with still water beside them.
    public func ferryLandings(for unitID: Int, as house: Int) -> [Hold] {
        guard let unit = unit(unitID), unit.owner == house, let from = hold(at: unit.position), from.owner == house,
              castingWater(beside: from) != nil else { return [] }
        return holds.filter { $0.owner == house && $0.id != from.id && castingWater(beside: $0) != nil }
    }

    /// Why a keeper can't set a company on the water for one of their holds
    /// now, if they can't.
    public func ferryRefusal(_ unitID: Int, to holdID: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        guard let unit = unit(unitID) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard crossing(of: unitID) == nil else { return .alreadyOnTheWater }
        guard let from = hold(at: unit.position), from.owner == house else { return .notAtAShoreHold }
        guard castingWater(beside: from) != nil else { return .noWaterBeside }
        guard let to = hold(holdID), to.owner == house, to.id != from.id else { return .unknownHold }
        guard castingWater(beside: to) != nil else { return .noWaterBeside }
        guard !unit.acted else { return .alreadyActed }
        let stock = houses[house].stock
        guard stock.covers(GameState.ferryCost) else { return .shortOf(stock.shortfall(for: GameState.ferryCost)) }
        return nil
    }

    /// A keeper sets a company on the water: it leaves the land for the
    /// barge, and is poled across through the watch.
    mutating func setOnTheWater(_ unitID: Int, to holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = ferryRefusal(unitID, to: holdID, as: house) { throw refusal }
        let index = unitIndex(unitID)!
        let from = hold(at: units[index].position)!, to = hold(holdID)!
        houses[house].stock.debit(GameState.ferryCost)
        units[index].destination = nil
        units[index].way = nil
        units[index].errand = nil
        units[index].fortified = false
        units[index].movesLeft = 0
        units[index].acted = true
        let crossing = Ferrying(unit: unitID, owner: house, from: from.id, to: to.id, pushOff: castingWater(beside: from)!,
                                landing: castingWater(beside: to)!, set: watch)
        barges = crossingsUnderWay + [crossing]
        return [.setOnTheWater(unit: unitID, house: house, from: from.id, to: to.id)]
    }

    /// As the watch turns, every barge out lands: its company stands at the
    /// hold it made for, unless another company stands there, or the hold
    /// is no longer its House's; then it turns back to where it set out.
    mutating func landCrossings() -> [GameEvent] {
        guard let all = barges, !all.isEmpty else { return [] }
        var events: [GameEvent] = []
        for crossing in all {
            guard let index = unitIndex(crossing.unit) else { continue }
            if let to = hold(crossing.to), to.owner == crossing.owner, unit(at: to.position) == nil {
                units[index].position = to.position
                events.append(.ferried(unit: crossing.unit, house: crossing.owner, to: to.id, landed: true))
            } else {
                events.append(.ferried(unit: crossing.unit, house: crossing.owner, to: crossing.to, landed: false))
            }
        }
        barges = nil
        return events
    }
}
