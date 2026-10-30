/// The hostile things of the far country, raised by the realm itself far
/// from every hold. They never march and take no hold; they stand where
/// they rose until some House strikes them down, and what falls with them
/// is stores for that House and lessons for its commander.
public enum WildKind: String, CaseIterable, Codable, Sendable {
    /// Pale husks that crawl out of the salt flats.
    case saltwights
    /// Outlaw bands of the blackwood.
    case reavers
    /// The restless dead of the barrows.
    case barrowkin
    /// Raiders come down from the Spine.
    case spineHunters
    /// The drowned, who walk the strand by night.
    case drowned

    public var title: String {
        switch self {
        case .saltwights: return "Saltwights"
        case .reavers: return "Blackwood Reavers"
        case .barrowkin: return "Barrowkin"
        case .spineHunters: return "Spine Hunters"
        case .drowned: return "the Drowned"
        }
    }

    /// Those that rise from a kind of ground.
    static func of(_ terrain: Terrain) -> WildKind {
        switch terrain {
        case .saltFlat: return .saltwights
        case .blackwood: return .reavers
        case .barrow: return .barrowkin
        case .strand, .shallows, .still: return .drowned
        case .greyfield, .spine: return .spineHunters
        }
    }

    /// Attack and defence at the first level.
    public var attack: Int {
        switch self {
        case .saltwights: return 4
        case .reavers: return 6
        case .barrowkin: return 5
        case .spineHunters: return 7
        case .drowned: return 5
        }
    }

    public var defense: Int {
        switch self {
        case .saltwights: return 4
        case .reavers: return 4
        case .barrowkin: return 7
        case .spineHunters: return 5
        case .drowned: return 5
        }
    }

    /// What falls with one of the first level.
    var spoils: Stock {
        switch self {
        case .saltwights: return Stock(grain: 5, moonsalt: 6)
        case .reavers: return Stock(grain: 15, timber: 20)
        case .barrowkin: return Stock(stone: 25, moonsalt: 2)
        case .spineHunters: return Stock(grain: 20, stone: 10)
        case .drowned: return Stock(grain: 10, timber: 10, stone: 10, moonsalt: 2)
        }
    }
}

/// A company of the wilds, of a level from I to X.
public struct Wild: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let kind: WildKind
    public let level: Int
    public let position: Hex
    /// 1...100.
    public internal(set) var health: Int
    /// The watch it rose.
    public let raised: Int

    public init(id: Int, kind: WildKind, level: Int, position: Hex, raised: Int) {
        self.id = id
        self.kind = kind
        self.level = min(max(level, 1), Wild.highestLevel)
        self.position = position
        self.health = 100
        self.raised = raised
    }

    public static let highestLevel = 10

    /// Attack and defence, in percent of the first level's.
    public var mightPercent: Int { 100 + 25 * (level - 1) }
    /// Body, in percent of the first level's.
    public var bodyPercent: Int { 100 + 10 * (level - 1) }

    /// What falls with it.
    public var spoils: Stock { kind.spoils * level }

    /// Experience its striker's commander learns from each blow, and from
    /// its fall.
    public var blowLessons: Int { 15 * level }
    public var fallLessons: Int { 50 * level }
}

/// One blow struck at a company of the wilds.
public struct Hunt: Codable, Equatable, Sendable {
    public let attacker: Int
    public let attackerOwner: Int
    public let attackerKind: UnitKind
    public let wild: Int
    public let wildKind: WildKind
    public let level: Int
    public let at: Hex
    public let damageDealt: Int
    public let damageTaken: Int
    public let attackerFell: Bool
    public let wildFell: Bool
    /// What fell with it, if it fell, and came to the striker's stores.
    public let spoils: Stock
}

extension GameState {
    /// Every company of the wilds standing.
    public var wildsStanding: [Wild] { wilds ?? [] }

    public func wild(_ id: Int) -> Wild? {
        wilds?.first { $0.id == id }
    }

    public func wild(at hex: Hex) -> Wild? {
        wilds?.first { $0.position == hex }
    }

    /// Whether a hex is free of everything that stands: companies, holds,
    /// the wilds.
    func isOccupied(_ hex: Hex) -> Bool {
        unit(at: hex) != nil || hold(at: hex) != nil || wild(at: hex) != nil
    }

    /// The fewest tiles from any hold at which the wilds rise.
    public static let wildsFromHolds = 6
    /// Health a wounded company of the wilds regains each watch.
    public static let wildsMending = 5
    /// The wilds of this level and above are chronicled as they fall.
    public static let notedWilds = 8

    /// How many of the wilds the far country holds at once: two for each
    /// seat of the lake.
    var wildsWanted: Int { houses.count * 2 }

    /// The wilds rise, up to their number, two a watch at most, each on a
    /// tile of the far country no one stands on: the further from every
    /// hold, and the later in the age, the stronger. The wounded mend.
    mutating func raiseWilds() {
        if wilds == nil { wilds = [] }
        for index in wilds!.indices where wilds![index].health < 100 {
            wilds![index].health = min(100, wilds![index].health + GameState.wildsMending)
        }
        guard wilds!.count < wildsWanted else { return }
        var random = random()
        var raised = 0
        for _ in 0..<12 where raised < 2 && wilds!.count < wildsWanted {
            let hex = map.hex(at: random.int(below: map.count))
            guard let tile = map[hex], tile.terrain.isPassable, !tile.terrain.isWater, tile.feature == nil,
                  !isOccupied(hex), site(at: hex) == nil else { continue }
            let far = holds.map { $0.position.distance(to: hex) }.min() ?? Int.max
            guard far >= GameState.wildsFromHolds else { continue }
            let level = 1 + (min(far, 40) - GameState.wildsFromHolds) / 2 + watch / 40 + random.int(below: 2)
            wilds!.append(Wild(id: takeID(), kind: WildKind.of(tile.terrain), level: level, position: hex, raised: watch))
            raised += 1
        }
    }

    /// A company's attack and a company of the wilds' defence, before chance.
    func strengths(of attacker: Unit, against wild: Wild) -> (attack: Int, defense: Int) {
        var attack = attacker.kind.attack * (50 + attacker.health / 2) * (100 + Unit.rankBonus * attacker.rank) / 100
        attack = attack * attackPercent(of: attacker) / 100
        attack = attack * (100 + huntingEdge(of: attacker)) / 100
        let ground = 100 + (map[wild.position]?.terrain.defenseBonus ?? 0)
        let defense = max(1, wild.kind.defense * (50 + wild.health / 2) * ground / 100 * wild.mightPercent / 100)
        return (attack, defense)
    }

    /// What a company's commander adds to its blows on the wilds.
    func huntingEdge(of unit: Unit) -> Int {
        unit.leader.flatMap(commander).map { $0.edge(.hunting) } ?? 0
    }

    /// A company of the wilds' blow back, before chance: its own attack
    /// against the striker's, as a company's defence answers a blow.
    func wildBlow(_ wild: Wild, on attacker: Unit) -> Int {
        let attack = strengths(of: attacker, against: wild).attack
        let back = max(1, wild.kind.attack * (50 + wild.health / 2) * wild.mightPercent / 100)
        return 70 * back / (attack + back)
    }

    /// A blow's damage as a company of the wilds takes it.
    func bodily(_ damage: Int, on wild: Wild) -> Int {
        damage * 100 / wild.bodyPercent
    }

    /// A company strikes a company of the wilds: no war needed, for the
    /// wilds are every House's foe. It strikes back at a company beside it.
    mutating func strike(wild wildID: Int, with unitID: Int) -> [GameEvent] {
        guard let unitIndex = unitIndex(unitID), let wildIndex = wilds?.firstIndex(where: { $0.id == wildID }) else { return [] }
        var random = random()
        let attacker = units[unitIndex]
        let wild = wilds![wildIndex]
        let ranged = attacker.position.distance(to: wild.position) > 1
        let fired = furyReady(of: attacker)
        let furyOf = fury(of: attacker)
        let (attack, defense) = strengths(of: attacker, against: wild)

        let dealt = bodily(GameState.furious(max(5, 70 * attack / (attack + defense) * random.int(in: 80...120) / 100),
                                             dealtBy: furyOf, takenBy: GameState.calm), on: wild)
        let taken = ranged ? 0 : bodily(GameState.furious(wildBlow(wild, on: attacker) * random.int(in: 80...120) / 100,
                                                          dealtBy: GameState.calm, takenBy: furyOf), on: attacker)
        var events: [GameEvent] = []
        wilds![wildIndex].health -= dealt
        let wildFell = wilds![wildIndex].health <= 0
        var spoils = Stock.zero
        if wildFell {
            wilds!.remove(at: wildIndex)
            spoils = wild.spoils
            store(spoils, for: attacker.owner)
            if wild.level >= GameState.notedWilds {
                record(.hunt, [attacker.owner], "\(houses[attacker.owner].title) strikes down a company of \(wild.kind.title) of the \(ordinal(wild.level)) level in the far country.")
            }
        }
        let attackerFell = taken > 0 && applyDamage(taken, to: unitID, events: &events)
        if !attackerFell {
            events += gainExperience(unitID)
        }
        events += stirCommanders([Stir(unit: attacker, fired: fired, fell: attackerFell,
                                       experience: wild.blowLessons + (wildFell ? wild.fallLessons : 0))], at: wild.position)
        events.insert(.hunted(Hunt(attacker: unitID, attackerOwner: attacker.owner, attackerKind: attacker.kind, wild: wildID,
                                   wildKind: wild.kind, level: wild.level, at: wild.position, damageDealt: dealt, damageTaken: taken,
                                   attackerFell: attackerFell, wildFell: wildFell, spoils: spoils)), at: 0)
        return events
    }

    /// What a strike on a company of the wilds would most likely do: from
    /// where the company stands, or, planning a hunt, from its reach.
    func forecast(_ attacker: Unit, against wild: Wild, fromReach: Bool = false) -> Forecast {
        let ranged = fromReach ? attacker.kind.range > 1 : attacker.position.distance(to: wild.position) > 1
        let furyOf = fury(of: attacker)
        let (attack, defense) = strengths(of: attacker, against: wild)
        let dealt = 70 * attack / (attack + defense)
        let back = ranged ? 0 : wildBlow(wild, on: attacker)
        func onWild(_ blow: Int) -> Int { bodily(GameState.furious(blow, dealtBy: furyOf, takenBy: GameState.calm), on: wild) }
        func onAttacker(_ blow: Int) -> Int { ranged ? 0 : bodily(GameState.furious(blow, dealtBy: GameState.calm, takenBy: furyOf), on: attacker) }
        return Forecast(
            target: .wild(wild.kind, level: wild.level),
            dealt: onWild(max(5, dealt * 80 / 100))...onWild(max(5, dealt * 120 / 100)),
            taken: onAttacker(back * 80 / 100)...onAttacker(back * 120 / 100),
            defenderHealth: wild.health,
            attackerHealth: attacker.health,
            couldCapture: false
        )
    }
}
