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
    /// The companies of other Houses marching dark its light has made out
    /// as it burns, each once, the first made out first; none, nil.
    public var seen: [Sighting]? = nil

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

    /// A company of another House marching dark that a watchfire's light
    /// made out within its reach: which and whose, of what kind and tier
    /// and how many, where it was made out and in which watch, as the
    /// watchman at the fire tells it to the House that lit it.
    public struct Sighting: Codable, Equatable, Sendable {
        public let unit: Int
        public let owner: Int
        public let kind: UnitKind
        public let tier: Int
        public let troops: Int
        public let at: Hex
        public let watch: Int

        public init(unit: Int, owner: Int, kind: UnitKind, tier: Int, troops: Int, at: Hex, watch: Int) {
            self.unit = unit
            self.owner = owner
            self.kind = kind
            self.tier = tier
            self.troops = troops
            self.at = at
            self.watch = watch
        }

        /// What the watchman's word on it is kept by on the keeper's
        /// device: a company made out in a watch, told once, whichever of
        /// the House's watchfires made it out.
        public var key: Int { watch * 1_000_000 + unit }
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
        // Its light makes out at once what marches dark about it.
        return [.watchfireLit(at: hex, by: house)] + keepWatchByFire()
    }

    /// Each watchfire makes out the companies of other Houses marching dark
    /// within its reach that it hasn't made out already as it burns, at
    /// each pace of the watch and as it turns: each kept on the fire, and
    /// told to the House that lit it.
    mutating func keepWatchByFire() -> [GameEvent] {
        guard var fires = watchfires, !fires.isEmpty, let unlit, !unlit.isEmpty else { return [] }
        var events: [GameEvent] = []
        for index in fires.indices {
            let fire = fires[index]
            var seen = fire.seen ?? []
            for hex in fire.at.spiral(Watchfire.reach) {
                for id in units.ids(at: hex) where isUnlit(id) && !seen.contains(where: { $0.unit == id }) {
                    guard let unit = unit(id), unit.owner != fire.by, houses.indices.contains(unit.owner) else { continue }
                    let sighting = Watchfire.Sighting(unit: id, owner: unit.owner, kind: unit.kind, tier: unit.tier,
                                                      troops: troops(of: unit), at: hex, watch: watch)
                    seen.append(sighting)
                    events.append(.madeOutByWatchfire(sighting, fire: fire.at, by: fire.by))
                }
            }
            if !seen.isEmpty { fires[index].seen = seen }
        }
        if !events.isEmpty { watchfires = fires }
        return events
    }

    /// What a watchfire made out marching dark, plainly, as the Mac's panel
    /// and the phone's chart say it: "Made out in watch 12: House Arden's
    /// Spears I, 1,200 troops, marching dark by the Hagstones." and, where
    /// it has made out more than one as it burns, how many.
    public func sightingSaid(_ sighting: Watchfire.Sighting, of fire: Watchfire) -> String {
        let whose = houses.indices.contains(sighting.owner) ? houses[sighting.owner].title : "A fallen House"
        let count = fire.seen?.count ?? 1
        return "Made out in watch \(sighting.watch): \(whose)'s \(named(sighting.kind, tier: sighting.tier, of: sighting.owner)), "
            + "\(GameState.counted(sighting.troops)), marching dark \(placeName(of: sighting.at))."
            + (count > 1 ? " \(count) made out as it burns." : "")
    }

    /// The latest company a House's watchfires have made out marching dark
    /// that still burns, and the fire that made it out: what the watchman
    /// at the fire tells the keeper.
    public func latestSighting(by house: Int) -> (fire: Watchfire, sighting: Watchfire.Sighting)? {
        var latest: (fire: Watchfire, sighting: Watchfire.Sighting)?
        for fire in watchfiresBurning where fire.by == house {
            guard let last = fire.seen?.last else { continue }
            if latest.map({ ($0.sighting.watch, $0.sighting.unit) < (last.watch, last.unit) }) ?? true { latest = (fire, last) }
        }
        return latest
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
