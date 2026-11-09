/// Fire in the blackwood (an invention of Nullmere's own): a keeper's
/// company of war standing in the blackwood may set it alight, on its own
/// House's land, on land no hold's, or on the land of a House at war with
/// its own. The fire burns three watches, and as each watch turns it
/// catches the blackwood beside it, most of all downwind: the watch's wind,
/// the same over the whole lake, blows from the realm's own seed. No wind
/// blows on a Still Night, and the fire keeps where it is; Rising Mist lies
/// on every shore and puts every fire out. A company standing in fire as
/// the watch turns loses a sixth of its full strength. Burnt, the wood lies
/// as ash for thirty watches, yielding nothing to the hold whose land it
/// is, and then grows back. Fire takes nothing but the blackwood, never a
/// hold's heart or a site's clearing, and every House sees its smoke.
/// Stewards set none, so a world they play alone burns nothing.
public struct Wildfire: Codable, Equatable, Sendable {
    /// Where it burns, or burned.
    public let at: Hex
    /// The House whose company set the fire it came of.
    public let by: Int
    /// The watch it caught.
    public let caught: Int
    /// The watch it burns out, or was put out; ash from then until it grows
    /// back.
    public internal(set) var out: Int

    /// How many watches a fire burns.
    public static let burns = 3
    /// How many watches its ash lies before the wood grows back.
    public static let ash = 30
    /// The health a company standing in fire loses as the watch turns: a
    /// sixth of its full strength.
    public static let toll = 16
    /// The chance in a hundred that a fire catches the blackwood beside it
    /// as the watch turns: downwind; a sixth of a turn off it; a third of a
    /// turn off it; and upwind, never. Measured on a hex forest without
    /// end (a sketch of the rules, 400 fires, the wind turning each watch at
    /// random): a fire takes 14 tiles at the median, 62 at the ninetieth
    /// share, 206 at the most, where at 55, 30, 10 and 4 nearly every one
    /// ran on past 3,000.
    public static let downwind = 30
    public static let besideTheWind = 12
    public static let acrossTheWind = 3
    public static let upwind = 0

    public init(at: Hex, by: Int, caught: Int, out: Int) {
        self.at = at
        self.by = by
        self.caught = caught
        self.out = out
    }

    /// Whether it is burning in that watch, rather than lying as ash.
    public func isBurning(at watch: Int) -> Bool { watch < out }
    /// The watch its ash is gone and the wood stands again.
    public var regrows: Int { out + Wildfire.ash }

    /// The chance in a hundred that it catches the blackwood that way (an
    /// index into `Hex.directions`) under a wind blowing toward `wind`; with
    /// no wind, none.
    public static func chance(toward way: Int, wind: Int?) -> Int {
        guard let wind else { return 0 }
        let off = min((way - wind + 6) % 6, (wind - way + 6) % 6)
        return [downwind, besideTheWind, acrossTheWind, upwind][off]
    }
}

extension GameState {
    /// The fire burning there, or the ash lying there, if any.
    public func wildfire(at hex: Hex) -> Wildfire? {
        wildfires?.first { $0.at == hex }
    }

    /// Every fire burning in the blackwood and every stretch of ash it left.
    public var firesAndAsh: [Wildfire] { wildfires ?? [] }

    /// Where the blackwood lies burnt, as ash, this watch.
    public var ash: Set<Hex> {
        Set((wildfires ?? []).filter { !$0.isBurning(at: watch) }.map(\.at))
    }

    /// Every fire burning and every stretch of ash, by where it lies.
    public var wildfiresByHex: [Hex: Wildfire] {
        Dictionary((wildfires ?? []).map { ($0.at, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// The fires burning this watch.
    public var burning: [Wildfire] {
        (wildfires ?? []).filter { $0.isBurning(at: watch) }
    }

    /// Whether that ground is blackwood, as fire may take.
    public func isBlackwood(_ hex: Hex) -> Bool { map[hex]?.terrain == .blackwood }

    /// The fire or the ash there as a line says it: "ablaze, 2 watches
    /// more", "burnt, the wood back in 27 watches"; nil where there is
    /// neither.
    public func fireSaid(at hex: Hex) -> String? {
        guard let fire = wildfire(at: hex) else { return nil }
        if fire.isBurning(at: watch) { return "ablaze, \(GameState.watches(fire.out - watch)) more" }
        return "burnt, the wood back in \(GameState.watches(max(fire.regrows - watch, 1)))"
    }

    /// Whether the blackwood there is burning this watch.
    public func isBurning(_ hex: Hex) -> Bool {
        wildfire(at: hex)?.isBurning(at: watch) ?? false
    }

    /// The way the wind blows this watch, as an index into `Hex.directions`
    /// (the way it blows toward): the same over the whole lake, and none on
    /// a Still Night. The realm finds it as the watch turns and every keeper
    /// is told it (a keeper's view holds no seed to find it by); a world
    /// from before the wind finds it afresh.
    public var wind: Int? {
        if let kept = windOfWatch { return kept >= 0 ? kept : nil }
        return foundWind
    }

    /// The wind the realm finds for this watch, from its seed and the
    /// watch: drawing on nothing else it draws, so a watch with no fire
    /// turns as it would have.
    var foundWind: Int? {
        if omen?.kind == .stillNight { return nil }
        return Int(Seed.mix(settings.seed, UInt64(max(watch, 0)), GameState.windSalt) % 6)
    }

    /// Keeps the wind found for this watch, for every keeper to be told.
    mutating func keepTheWind() {
        windOfWatch = foundWind ?? -1
    }

    static let windSalt: UInt64 = 0x5749_4E44_5749_4E44

    /// Where a wind blowing that way comes from, as a line says it: "from
    /// the west".
    public static func windFrom(_ way: Int) -> String {
        // `Hex.directions`: east, north-east, north-west, west, south-west, south-east.
        let names = ["the east", "the north-east", "the north-west", "the west", "the south-west", "the south-east"]
        return "from " + names[((way % 6) + 9) % 6]
    }

    /// The wind of this watch as a line says it: "the wind is from the
    /// west", or that none blows.
    public var windSaid: String {
        guard let wind else { return "no wind blows" }
        return "the wind is \(GameState.windFrom(wind))"
    }

    /// Whether fire may take that ground: blackwood with no fire nor ash on
    /// it, no hold's heart, no site's clearing.
    func mayBurn(_ hex: Hex, sites: Set<Hex>, holdsAt: Set<Hex>, fires: [Hex: Wildfire]) -> Bool {
        guard let tile = map[hex], tile.terrain == .blackwood else { return false }
        return fires[hex] == nil && !sites.contains(hex) && !holdsAt.contains(hex)
    }

    /// The world as it would stand had the blackwood at `hexes` caught
    /// alight this watch, set by `house`: only what fire may take there
    /// (`mayBurn`), each tile once. For the Mac's voice check, which asks
    /// the on-device model for a woodward's plea where nothing burns yet.
    public func catching(_ hexes: [Hex], by house: Int) -> GameState {
        var world = self
        var fires = wildfiresByHex
        let sites = Set(sitesInLand.map(\.position)), holdsAt = Set(holds.map(\.position))
        for hex in hexes where mayBurn(hex, sites: sites, holdsAt: holdsAt, fires: fires) {
            let fire = Wildfire(at: hex, by: house, caught: watch, out: watch + Wildfire.burns)
            fires[hex] = fire
            world.wildfires = (world.wildfires ?? []) + [fire]
        }
        return world
    }

    /// Why a company can't set the blackwood where it stands alight, if it
    /// can't: only a keeper's company of war, with a move left this watch,
    /// in blackwood not already burning or burnt, on its own House's land,
    /// land no hold's, or a foe's.
    public func kindleRefusal(_ id: Int, as house: Int) -> RuleError? {
        guard outcome == nil else { return .gameOver }
        guard let unit = unit(id) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .keepersFire }
        guard unit.kind.isMilitary else { return .cannotFight }
        guard map[unit.position]?.terrain == .blackwood else { return .onlyBlackwood }
        guard wildfire(at: unit.position) == nil else { return .burntGround }
        guard hold(at: unit.position) == nil, !sitesInLand.contains(where: { $0.position == unit.position }) else { return .onlyBlackwood }
        guard unit.movesLeft > 0 else { return .noMovesLeft }
        if let owner = territoryOwner(of: unit.position), owner != house, stance(house, owner) != .war { return .notAtWar(owner) }
        return nil
    }

    /// A keeper's company sets the blackwood where it stands alight, for
    /// one of its moves, the fire burning from this watch: it may walk on
    /// out of it with what moves it has left, or pay the fire's toll as the
    /// watch turns.
    mutating func kindle(_ id: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = kindleRefusal(id, as: house) { throw refusal }
        guard let index = unitIndex(id) else { throw .unknownUnit }
        let at = units[index].position
        units[index].movesLeft -= 1
        units[index].acted = true
        let fire = Wildfire(at: at, by: house, caught: watch, out: watch + Wildfire.burns)
        wildfires = (wildfires ?? []) + [fire]
        return [.woodKindled(at: at, by: house, unit: id)]
    }

    /// As the watch turns: Rising Mist puts every fire out; otherwise each
    /// fire burning catches the blackwood beside it with the watch's wind;
    /// every company standing in fire pays its toll; fires past their time
    /// lie as ash, and ash past its time grows back into blackwood.
    mutating func turnWildfires() -> [GameEvent] {
        guard var fires = wildfires, !fires.isEmpty else { return [] }
        var events: [GameEvent] = []
        if omen?.kind == .risingMist || omen?.kind == .leanWatch {
            // The mist on every shore, or a lean watch's cold rain, puts out
            // every fire burning: what it burnt lies as ash.
            let doused = fires.indices.filter { fires[$0].isBurning(at: watch) }
            for index in doused { fires[index].out = watch }
            if !doused.isEmpty { events.append(.firesDoused(doused.map { fires[$0].at }, rain: omen?.kind == .leanWatch)) }
        } else if let wind {
            // What burned as the watch began catches what lies beside it; what
            // catches now burns from this watch, and spreads as the next turns.
            var byHex = Dictionary(fires.map { ($0.at, $0) }, uniquingKeysWith: { _, last in last })
            let sites = Set(sitesInLand.map(\.position))
            let holdsAt = Set(holds.map(\.position))
            var caught: [Int: [Hex]] = [:]
            for fire in fires.sorted(by: { $0.at < $1.at }) where fire.isBurning(at: watch - 1) && fire.caught < watch {
                for (way, step) in Hex.directions.enumerated() {
                    let next = fire.at + step
                    guard mayBurn(next, sites: sites, holdsAt: holdsAt, fires: byHex) else { continue }
                    let roll = Int(Seed.mix(settings.seed, UInt64(watch), UInt64(bitPattern: Int64(next.q)),
                                            UInt64(bitPattern: Int64(next.r)), GameState.windSalt &+ 1) % 100)
                    guard roll < Wildfire.chance(toward: way, wind: wind) else { continue }
                    let spread = Wildfire(at: next, by: fire.by, caught: watch, out: watch + Wildfire.burns)
                    byHex[next] = spread
                    fires.append(spread)
                    caught[fire.by, default: []].append(next)
                }
            }
            for (by, hexes) in caught.sorted(by: { $0.key < $1.key }) {
                events.append(.fireSpread(to: hexes, by: by, wind: wind))
            }
        }
        // Every company standing in fire as the watch turns pays its toll.
        let ablaze = Set(fires.filter { $0.isBurning(at: watch) }.map(\.at))
        if !ablaze.isEmpty {
            for unit in units.sorted(by: { $0.id < $1.id }) where ablaze.contains(unit.position) {
                guard let index = unitIndex(unit.id) else { continue }
                let before = troops(of: units[index])
                units[index].health -= Wildfire.toll
                if units[index].health <= 0 {
                    let lost = units.remove(at: index)
                    events.append(.burnedInFire(unit: lost.id, owner: lost.owner, at: lost.position, troops: before, lost: true))
                    events.append(.unitLost(unit: lost.id, kind: lost.kind, owner: lost.owner, at: lost.position))
                    events += woundCommander(of: lost)
                } else {
                    let after = troops(of: units[index])
                    events.append(.burnedInFire(unit: unit.id, owner: unit.owner, at: unit.position, troops: before - after, lost: false))
                }
            }
        }
        // Ash past its time grows back into blackwood.
        fires.removeAll { watch >= $0.regrows }
        wildfires = fires.isEmpty ? nil : fires
        return events
    }
}
