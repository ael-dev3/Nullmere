/// Lairs of the wilds: strongholds of one kind of them, raised by the realm
/// far out in the country as the age goes on, too strong for any company
/// alone. Only a rally's host breaks one, striking it together; what falls
/// with it is shared among the host's Houses by the companies each sent,
/// and its caller finds gear among the ruins.
extension WildKind {
    /// What its lair is called.
    public var lairTitle: String {
        switch self {
        case .saltwights: return "Salt Hollow"
        case .reavers: return "Reavers' Stockade"
        case .barrowkin: return "Barrow Hall"
        case .spineHunters: return "Hunters' Eyrie"
        case .drowned: return "Drowned Chapel"
        }
    }
}

/// A lair of the wilds, of a level from I to V.
public struct Lair: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let kind: WildKind
    public let level: Int
    public let position: Hex
    /// What of it still stands: its might when whole, nothing when broken.
    public internal(set) var strength: Int
    /// The watch it rose.
    public let raised: Int
    /// Which of the Crown's gates it holds, if it holds one (see
    /// `Lair.gateQuarters`): a gate any company may strike alone.
    public let gate: Int?

    public init(id: Int, kind: WildKind, level: Int, position: Hex, raised: Int, gate: Int? = nil) {
        self.id = id
        self.kind = kind
        self.level = min(max(level, 1), Lair.highestLevel)
        self.position = position
        self.raised = raised
        self.gate = gate
        self.strength = Lair.might(level: self.level)
    }

    public static let highestLevel = 5
    /// The level the wilds hold the Crown's gates at.
    public static let gateLevel = 2
    /// The quarters the Crown's gates face, in turn.
    public static let gateQuarters = ["South-East", "South-West", "North-West", "North-East"]

    /// The strength a lair of a level stands with when whole.
    public static func might(level: Int) -> Int {
        [200, 450, 800, 1_250, 1_800][min(max(level, 1), highestLevel) - 1]
    }

    public var might: Int { Lair.might(level: level) }
    /// Its name: its kind's lair's, or the gate it holds.
    public var title: String { gate.map { "\(Lair.gateQuarters[$0 % Lair.gateQuarters.count]) Gate" } ?? kind.lairTitle }
    /// As a line names it: a lair by its kind and level, a gate of the Crown by its quarter.
    public var named: String { gate == nil ? "the \(title) of the \(ordinal(level)) level" : "the \(title) of the Crown" }

    /// Its defence against a company's blow: its kind's, the higher the
    /// lair the harder.
    public var defense: Int { kind.defense * (100 + 30 * (level - 1)) }

    /// The blow it deals back to a company striking it from beside it,
    /// before the company's body.
    public var blowBack: Int { 15 + 5 * level }

    /// What falls with it, to be shared among the host's Houses.
    public var spoils: Stock { kind.spoils * (8 * level) }

    /// What a striking company's commander learns from its blow, and from
    /// the lair's breaking.
    public var blowLessons: Int { 20 * level }
    public var breakLessons: Int { 60 * level }
}

/// A host's strike on a lair, as its side and those watching are told it.
public struct LairAssault: Codable, Equatable, Sendable {
    /// One company's blow on the lair.
    public struct Strike: Codable, Equatable, Sendable {
        public let unit: Int
        public let owner: Int
        public let kind: UnitKind
        /// Where it struck from.
        public let from: Hex
        public let dealt: Int
        public let taken: Int
        public let fell: Bool

        public init(unit: Int, owner: Int, kind: UnitKind, from: Hex, dealt: Int, taken: Int, fell: Bool) {
            self.unit = unit
            self.owner = owner
            self.kind = kind
            self.from = from
            self.dealt = dealt
            self.taken = taken
            self.fell = fell
        }
    }

    /// A House of the host, and what it carried off of the lair's spoils.
    public struct Share: Codable, Equatable, Sendable {
        public let house: Int
        public let spoils: Stock

        public init(house: Int, spoils: Stock) {
            self.house = house
            self.spoils = spoils
        }
    }

    public let rally: Int
    public let caller: Int
    public let lair: Int
    public let kind: WildKind
    public let level: Int
    public let at: Hex
    public let strikes: [Strike]
    /// What of it stood before the strike, and stands after: nothing if it broke.
    public let before: Int
    public let strength: Int
    public let might: Int
    /// The Houses of the host, its caller first, each with its share of
    /// the spoils if the lair broke.
    public let shares: [Share]
    /// The gate of the Crown it held, if it held one; struck by one
    /// company, `rally` is 0.
    public let gate: Int?

    public init(rally: Int, caller: Int, lair: Int, kind: WildKind, level: Int, at: Hex, strikes: [Strike],
                before: Int, strength: Int, might: Int, shares: [Share], gate: Int? = nil) {
        self.gate = gate
        self.rally = rally
        self.caller = caller
        self.lair = lair
        self.kind = kind
        self.level = level
        self.at = at
        self.strikes = strikes
        self.before = before
        self.strength = strength
        self.might = might
        self.shares = shares
    }

    public var broken: Bool { strength == 0 }
    public var houses: [Int] { shares.map(\.house) }
    public var dealt: Int { before - strength }
    /// What it struck, as a line names it.
    public var named: String {
        gate.map { "the \(Lair.gateQuarters[$0 % Lair.gateQuarters.count]) Gate of the Crown" }
            ?? "the \(kind.lairTitle) of the \(ordinal(level)) level"
    }
}

extension GameState {
    /// From this watch on, the realm raises lairs.
    public static let lairsFrom = 12
    /// While fewer stand than are wanted, one rises every so many watches.
    public static let lairEvery = 5
    /// The fewest tiles from any hold a lair rises, and from another lair
    /// or a holy site.
    public static let lairsFromHolds = 7
    public static let lairsApart = 6

    /// How many lairs the far country holds at once: one for every three
    /// seats, two at least.
    var lairsWanted: Int { max(2, houses.count / 3) }

    /// Every lair standing.
    public var lairsStanding: [Lair] { lairs ?? [] }

    public func lair(_ id: Int) -> Lair? {
        lairs?.first { $0.id == id }
    }

    public func lair(at hex: Hex) -> Lair? {
        lairs?.first { $0.position == hex }
    }

    private func lairIndex(_ id: Int) -> Int? {
        lairs?.firstIndex { $0.id == id }
    }

    /// As the watch turns: lairs struck mend a twentieth of their might,
    /// and while fewer stand than are wanted, one rises now and then on
    /// open land far from every hold, holy site and other lair: the later
    /// in the age, the higher. Drawn apart from the world's other draws.
    mutating func raiseLairs() {
        // A gate of the Crown, struck, stays struck.
        if var standing = lairs {
            for index in standing.indices where standing[index].gate == nil && standing[index].strength < standing[index].might {
                standing[index].strength = min(standing[index].might, standing[index].strength + standing[index].might / 20)
            }
            lairs = standing
        }
        guard watch >= GameState.lairsFrom else { return }
        if lairs == nil { lairs = [] }
        // The Crown's gates are not of the far country's lairs.
        guard lairs!.filter({ $0.gate == nil }).count < lairsWanted, (watch - GameState.lairsFrom) % GameState.lairEvery == 0 else { return }
        var random = SeededRandom(seed: Seed.mix(settings.seed, 1_000 + UInt64(max(watch, 0))))
        for _ in 0..<40 {
            let hex = map.hex(at: random.int(below: map.count))
            guard let tile = map[hex], tile.terrain.isPassable, !tile.terrain.isWater, tile.feature == nil,
                  !isOccupied(hex), site(at: hex) == nil,
                  holds.allSatisfy({ $0.position.distance(to: hex) >= GameState.lairsFromHolds }),
                  holySites.allSatisfy({ $0.position.distance(to: hex) >= GameState.lairsApart }),
                  lairsStanding.allSatisfy({ $0.position.distance(to: hex) >= GameState.lairsApart }) else { continue }
            let level = min(Lair.highestLevel, 1 + watch / 50 + random.int(below: 2))
            lairs!.append(Lair(id: takeID(), kind: WildKind.of(tile.terrain), level: level, position: hex, raised: watch))
            return
        }
    }

    /// A company's blow on a lair, before chance: its attack against the
    /// lair's defence.
    func blow(of attacker: Unit, on lair: Lair) -> Int {
        var attack = attacker.kind.attack * (50 + attacker.health / 2) * (100 + Unit.rankBonus * attacker.rank) / 100
        attack = attack * attackPercent(of: attacker) / 100
        attack = attack * (100 + huntingEdge(of: attacker)) / 100
        return max(5, 90 * attack / max(attack + lair.defense, 1))
    }

    /// The host strikes the lair, every company in reach in turn, arrows
    /// first, until it breaks; those beside it take its blow back. Broken,
    /// it is gone, and its spoils are shared among the host's Houses by the
    /// companies each brought up to it, its caller finding gear among the
    /// ruins, and items fill the host's satchels. Then the rally is done,
    /// whatever came of it.
    mutating func strikeLair(_ rallyID: Int, at target: Lair) -> [GameEvent] {
        guard let rally = rally(rallyID), let lairAt = lairIndex(target.id) else { return [] }
        var random = random()
        let order = rally.companies.enumerated().sorted { a, b in
            let reachA = unit(a.element)?.kind.range ?? 0, reachB = unit(b.element)?.kind.range ?? 0
            return (-reachA, a.offset) < (-reachB, b.offset)
        }.map(\.element)
        var events: [GameEvent] = []
        var strikes: [LairAssault.Strike] = []
        var struck: [Int: Int] = [rally.caller: 0]
        var sides: [Int] = [rally.caller]
        let before = lairs![lairAt].strength
        for id in order {
            guard let index = unitIndex(id) else { continue }
            let unit = units[index]
            guard unit.position.distance(to: target.position) <= unit.kind.range else { continue }
            // Every company come up with the host shares in what falls,
            // whether or not its blow was needed.
            if !sides.contains(unit.owner) { sides.append(unit.owner) }
            struck[unit.owner, default: 0] += 1
            guard lairs![lairAt].strength > 0 else { continue }
            units[index].movesLeft = 0
            units[index].acted = true
            units[index].fortified = false
            let dealt = min(lairs![lairAt].strength, blow(of: unit, on: target) * random.int(in: 85...115) / 100)
            lairs![lairAt].strength -= dealt
            let taken = unit.position.distance(to: target.position) > 1 ? 0 : bodily(target.blowBack, on: unit)
            var fell = false
            if taken > 0 { fell = applyDamage(taken, to: id, events: &events) }
            strikes.append(LairAssault.Strike(unit: id, owner: unit.owner, kind: unit.kind, from: unit.position,
                                              dealt: dealt, taken: taken, fell: fell))
            if !fell {
                events += gainExperience(id)
                events += teach(unit, target.blowLessons)
            }
        }
        let broken = lairs![lairAt].strength == 0
        var shares: [LairAssault.Share] = []
        let companies = struck.values.reduce(0, +)
        for house in sides {
            var share = Stock.zero
            if broken, companies > 0, let count = struck[house], count > 0 {
                share = target.spoils.share(count, of: companies)
                store(share, for: house)
            }
            shares.append(LairAssault.Share(house: house, spoils: share))
        }
        if broken {
            lairs!.remove(at: lairAt)
            for strike in strikes where !strike.fell {
                if let unit = unit(strike.unit) { events += teach(unit, target.breakLessons) }
            }
            events += awardGear(from: target.kind, level: target.level * 2, to: rally.caller)
            for house in sides where (struck[house] ?? 0) > 0 {
                let count = GameState.sculpturesPerLairLevel * target.level * (house == rally.caller ? 2 : 1)
                events += giveSculptures(count, to: house)
            }
            let host = sides.map { houses[$0].title }
            let named = listed(host)
            record(.hunt, sides, target.gate == nil ? "A host of \(named) breaks \(target.named) \(placeName(of: target.position))."
                   : "A host of \(named) breaks \(target.named): the way to the Heartstone lies open there.")
        }
        let assault = LairAssault(rally: rallyID, caller: rally.caller, lair: target.id, kind: target.kind,
                                  level: target.level, at: target.position, strikes: strikes, before: before,
                                  strength: broken ? 0 : lairs![lairAt].strength, might: target.might, shares: shares, gate: target.gate)
        events.insert(.lairAssaulted(assault), at: 0)
        if broken {
            events += rewardLair(assault)
            events += climbTheLadder(assault)
        }
        return events
    }
}

// MARK: The ladder of the lairs

/// The ladder of the lairs (after Rise of Kingdoms' barbarian forts, each
/// level opened by breaking the one below): a House's rung is the highest
/// level of lair its hosts have broken, and its rallies may march on a
/// lair no more than one level above it. A House of a host that breaks a
/// lair above its rung climbs to it, and is given sculptures for the climb.
extension GameState {
    /// The highest level of lair a House's hosts have broken; 0 before any.
    public func lairRung(of house: Int) -> Int {
        lairLadder?[house] ?? 0
    }

    /// Sculptures for each rung climbed, by the level climbed to.
    public static let sculpturesPerRung = 3

    /// A host's Houses climb the ladder to a lair it broke above their rungs.
    mutating func climbTheLadder(_ assault: LairAssault) -> [GameEvent] {
        guard assault.broken else { return [] }
        var events: [GameEvent] = []
        var ladder = lairLadder ?? [:]
        for share in assault.shares where lairRung(of: share.house) < assault.level {
            ladder[share.house] = assault.level
            events.append(.lairRungClimbed(house: share.house, level: assault.level))
            lairLadder = ladder
            events += giveSculptures(GameState.sculpturesPerRung * assault.level, to: share.house)
        }
        lairLadder = ladder.isEmpty ? nil : ladder
        return events
    }
}
