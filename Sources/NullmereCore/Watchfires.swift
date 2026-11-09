/// Watchfires (an invention of Nullmere's own, the answer to the march in
/// the dark): a keeper's House lights a fire on open ground of its own land,
/// for timber, and for eight watches it lights the ground about it: the
/// House and those whose sight it shares see within two tiles of it, and
/// make out there any company marching dark. Every House sees a watchfire
/// burn, so it tells a foe where a House keeps watch as well as lighting
/// the dark for it. A House keeps three burning at most, and stewards
/// light none, so a world they play alone is the same with this as
/// without it.
public struct Watchfire: Codable, Equatable, Sendable {
    /// Where it burns.
    public let at: Hex
    /// The House that lit it.
    public let by: Int
    /// The watch it was lit.
    public let lit: Int
    /// The watch it burns out.
    public let out: Int

    /// What it costs to light.
    public static let cost = Stock(timber: 12)
    /// How many watches it burns.
    public static let burns = 8
    /// How far about it its light reaches: the ground its House sees, and
    /// makes out a company marching dark on.
    public static let reach = 2
    /// The most a House keeps burning at once.
    public static let most = 3
    /// What a watchfire does, as the Mac and the phone say it beside the order.
    public static let explained = "A watchfire on your own land burns \(burns) watches for 12 timber: your House sees within "
        + "\(reach) tiles of it and makes out any company marching dark there. Every House sees it burn. Three at most."

    public init(at: Hex, by: Int, lit: Int, out: Int) {
        self.at = at
        self.by = by
        self.lit = lit
        self.out = out
    }
}

extension GameState {
    /// Every watchfire burning in the realm, which every House sees.
    public var watchfiresBurning: [Watchfire] { watchfires ?? [] }

    /// The watchfire burning there, if one is.
    public func watchfire(at hex: Hex) -> Watchfire? {
        watchfires?.first { $0.at == hex }
    }

    /// Why a House can't light a watchfire there, if it can't: only on open
    /// ground of its own land, where none burns, one of three at most, and
    /// with the timber for it.
    public func watchfireRefusal(at hex: Hex, as house: Int) -> RuleError? {
        guard outcome == nil else { return .gameOver }
        guard houses.indices.contains(house), !houses[house].isEliminated else { return .unknownHouse }
        guard let index = map.index(of: hex) else { return .outsideTheWorld }
        let terrain = map[index].terrain
        guard terrain.isPassable, !terrain.isWater, hold(at: hex) == nil else { return .unfitGround(terrain) }
        guard territoryOwner(of: hex) == house else { return .foreignTerritory }
        guard watchfire(at: hex) == nil else { return .watchfireBurning }
        guard watchfiresBurning.filter({ $0.by == house }).count < Watchfire.most else { return .watchfiresLit(Watchfire.most) }
        guard houses[house].stock.covers(Watchfire.cost) else { return .shortOf(houses[house].stock.shortfall(for: Watchfire.cost)) }
        return nil
    }

    /// A House lights a watchfire, paying its timber.
    mutating func lightWatchfire(at hex: Hex, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = watchfireRefusal(at: hex, as: house) { throw refusal }
        houses[house].stock.debit(Watchfire.cost)
        watchfires = watchfiresBurning + [Watchfire(at: hex, by: house, lit: watch, out: watch + Watchfire.burns)]
        return [.watchfireLit(at: hex, by: house)]
    }

    /// As the watch turns, the watchfires whose time is out burn out, and
    /// those of a House fallen with it.
    mutating func letWatchfiresBurnOut() {
        guard let burning = watchfires else { return }
        let kept = burning.filter { fire in
            fire.out > watch && houses.indices.contains(fire.by) && !houses[fire.by].isEliminated
        }
        watchfires = kept.isEmpty ? nil : kept
    }

    /// The watchfires whose light a House sees by: its own and those of the
    /// Houses whose sight it shares.
    func watchfiresLighting(for house: Int) -> [Watchfire] {
        guard let burning = watchfires, !burning.isEmpty else { return [] }
        let watching = Set(watchers(for: house))
        return burning.filter { watching.contains($0.by) }
    }
}
