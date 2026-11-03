/// False reflections (an invention of Nullmere's own): what the black lake
/// mirrors at its Still Hour every House believes, for the lake has never
/// lied; but a House may teach it to. From a hold by the water it casts a
/// false reflection on a stretch of shore, for moonsalt: at the next Still
/// Hour the lake mirrors a company of its own standing there, as many as it
/// says, though none is. To every other House it is a glimpse like any
/// other; only one with eyes on that shore, or its own company there, sees
/// the shore lie empty. Three at most to a Still Hour, its House's secret.
public struct FalseReflection: Codable, Equatable, Sendable {
    public let house: Int
    public let at: Hex
    public let kind: UnitKind
    public let troops: Int
}

extension GameState {
    /// What a false reflection costs.
    public static let falseReflectionCost = Stock(moonsalt: 10)
    /// The most a House casts against one Still Hour.
    public static let falseReflectionsKept = 3
    /// How far from its hold a House may cast one.
    public static let falseReflectionReach = 6

    /// A House's false reflections waiting for the next Still Hour.
    public func falseReflections(of house: Int) -> [FalseReflection] {
        (reflections ?? []).filter { $0.house == house }
    }

    /// Why a House can't cast a false reflection of a company of a kind on
    /// a shore hex from a hold, if it can't.
    public func reflectionRefusal(from holdID: Int, at hex: Hex, kind: UnitKind, as house: Int) -> RuleError? {
        guard let hold = hold(holdID) else { return .unknownHold }
        guard hold.owner == house else { return .notYours }
        guard kind.isMilitary else { return .cannotFight }
        guard isShore(hex), hex.distance(to: hold.position) <= GameState.falseReflectionReach else { return .notOnTheShore }
        guard !falseReflections(of: house).contains(where: { $0.at == hex }) else { return .reflectionThere }
        guard falseReflections(of: house).count < GameState.falseReflectionsKept else { return .tooManyReflections(GameState.falseReflectionsKept) }
        guard houses[house].stock.covers(GameState.falseReflectionCost) else { return .shortOf(houses[house].stock.shortfall(for: GameState.falseReflectionCost)) }
        return nil
    }

    mutating func castReflection(from holdID: Int, at hex: Hex, kind: UnitKind, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = reflectionRefusal(from: holdID, at: hex, kind: kind, as: house) { throw refusal }
        houses[house].stock.debit(GameState.falseReflectionCost)
        // As many as a company of its kind newly mustered.
        let troops = troops(of: Unit(id: -1, kind: kind, owner: house, position: hex))
        reflections = (reflections ?? []) + [FalseReflection(house: house, at: hex, kind: kind, troops: troops)]
        return [.reflectionCast(house: house, at: hex)]
    }

    /// At the Still Hour, the false reflections are mirrored with the true,
    /// alike, and are spent.
    mutating func mirrorTheFalse() -> [StillHour.Glimpse] {
        let cast = reflections ?? []
        reflections = nil
        return cast.filter { !houses[$0.house].isEliminated && unit(at: $0.at) == nil }
            .map { StillHour.Glimpse(owner: $0.house, kind: $0.kind, at: $0.at, troops: $0.troops) }
    }
}
