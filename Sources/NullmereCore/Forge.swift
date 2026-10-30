/// The makings of gear, which a House's Forge works into it. The wilds
/// leave them as they fall, a lair broken leaves more, and a company
/// bringing in what it gathered at the land's sites brings some with it.
public enum Making: String, CaseIterable, Codable, Sendable {
    case hide, iron, heartwood, moonglass

    public var title: String {
        switch self {
        case .hide: return "Hide"
        case .iron: return "Iron"
        case .heartwood: return "Heartwood"
        case .moonglass: return "Moonglass"
        }
    }

    /// What each kind of the wilds leaves as it falls: a piece for each of
    /// its levels.
    public static func left(by wild: WildKind) -> Making {
        switch wild {
        case .saltwights, .drowned: return .moonglass
        case .reavers: return .heartwood
        case .barrowkin: return .iron
        case .spineHunters: return .hide
        }
    }

    /// What a store gathered at the land's sites brings in with it.
    public static func of(_ resource: Resource) -> Making {
        switch resource {
        case .grain: return .hide
        case .timber: return .heartwood
        case .stone: return .iron
        case .moonsalt: return .moonglass
        }
    }

    /// How much of a store gathered and brought in brings one piece with it.
    public static func per(_ resource: Resource) -> Int { resource == .moonsalt ? 8 : 40 }
}

/// So much of one making a House keeps for its Forge.
public struct MakingStack: Codable, Equatable, Sendable {
    public let house: Int
    public let making: Making
    public internal(set) var count: Int

    public init(house: Int, making: Making, count: Int) {
        self.house = house
        self.making = making
        self.count = count
    }
}

/// The sets a Forge makes gear in: each of a set's pieces a commander
/// wears with another of it gives the company it leads more besides.
public enum GearSet: String, CaseIterable, Codable, Sendable {
    /// For holding a line and a wall.
    case warden
    /// For the charge and the breach.
    case raider
    /// For the far country, its sites and its wilds.
    case pathfinder

    public var title: String {
        switch self {
        case .warden: return "the Warden's Harness"
        case .raider: return "the Raider's Kit"
        case .pathfinder: return "the Pathfinder's Gear"
        }
    }

    /// Its title as a heading names it.
    public var name: String { title.prefix(1).uppercased() + title.dropFirst() }

    /// Its pieces: weapon, armour and charm.
    public var pieces: [GearKind] {
        switch self {
        case .warden: return [.wardensBlade, .wardensMail, .wardensSeal]
        case .raider: return [.raidersSpear, .raidersLeathers, .raidersHorn]
        case .pathfinder: return [.pathfindersKnife, .pathfindersCloak, .pathfindersLodestone]
        }
    }

    /// What so many of its pieces worn together give, beyond each piece's
    /// own: something for two, more for all three.
    public func bonus(pieces worn: Int) -> [Edge: Int] {
        guard worn >= 2 else { return [:] }
        let all = worn >= pieces.count
        switch self {
        case .warden: return all ? [.defense: 4, .garrison: 6, .healing: 2] : [.defense: 4]
        case .raider: return all ? [.attack: 4, .wardDamage: 8, .moves: 1] : [.attack: 4]
        case .pathfinder: return all ? [.gathering: 6, .load: 6, .hunting: 6, .sight: 1] : [.gathering: 6, .load: 6]
        }
    }

    /// What its pieces together give, in words.
    public var effect: String {
        switch self {
        case .warden: return "two pieces: +4% defence; all three: +6% defence within its walls and heals 2 more besides"
        case .raider: return "two pieces: +4% attack; all three: +8% to blows on a ward and a move more besides"
        case .pathfinder: return "two pieces: +6% gathered and carried; all three: +6% against the wilds and sight a tile further besides"
        }
    }

    /// The set a commander of an archetype is best served by.
    public static func suiting(_ archetype: Archetype) -> GearSet {
        switch archetype {
        case .warden: return .warden
        case .vanguard, .wallbreaker: return .raider
        case .outrider, .gleaner: return .pathfinder
        }
    }
}

extension GearQuality {
    /// How many times a plain piece's makings and moonsalt forging one
    /// this fine takes.
    public var multiplier: Int {
        switch self {
        case .plain: return 1
        case .fine: return 2
        case .masterwork: return 4
        case .fabled: return 8
        }
    }

    /// The Forge's level that first forges gear this fine.
    public var forgeLevel: Int {
        switch self {
        case .plain: return 1
        case .fine: return 2
        case .masterwork: return 4
        case .fabled: return 5
        }
    }

    /// The finest gear a Forge of a level forges; none without one.
    public static func forged(atLevel level: Int) -> GearQuality? {
        allCases.last { $0.forgeLevel <= level }
    }
}

extension GameState {
    /// The most of each making a House keeps; what comes in beyond is lost.
    public static let makingsKept = 200
    /// Moonsalt forging a plain piece takes, besides its makings.
    public static let forgingMoonsalt = 4
    /// Each level of a Forge above the first takes this share fewer makings
    /// for every piece, in percent.
    public static let forgeThrift = 10

    /// What a House keeps of a making.
    public func makings(_ making: Making, of house: Int) -> Int {
        makings?.first { $0.house == house && $0.making == making }?.count ?? 0
    }

    /// The highest Forge among a House's holds.
    public func forgeLevel(of house: Int) -> Int {
        holds.lazy.filter { $0.owner == house }.map { $0.level(.forge) }.max() ?? 0
    }

    /// What forging a piece of a kind this fine takes of each making, at a
    /// House's Forge.
    public func recipe(_ kind: GearKind, _ quality: GearQuality, for house: Int) -> [Making: Int] {
        let thrift = 100 - GameState.forgeThrift * max(forgeLevel(of: house) - 1, 0)
        return kind.recipe.mapValues { max(1, ($0 * quality.multiplier * thrift + 50) / 100) }
    }

    /// The moonsalt forging a piece this fine takes.
    public static func forgingCost(_ quality: GearQuality) -> Stock {
        Stock(moonsalt: forgingMoonsalt * quality.multiplier)
    }

    /// Makings a House is given, each kept up to what it may keep; the
    /// events of what it was given.
    mutating func give(makings given: [Making: Int], to house: Int) -> [GameEvent] {
        guard houses.indices.contains(house) else { return [] }
        var events: [GameEvent] = []
        for making in Making.allCases {
            guard let count = given[making], count > 0 else { continue }
            var list = makings ?? []
            if let index = list.firstIndex(where: { $0.house == house && $0.making == making }) {
                list[index].count = min(GameState.makingsKept, list[index].count + count)
            } else {
                list.append(MakingStack(house: house, making: making, count: min(GameState.makingsKept, count)))
            }
            makings = list
            events.append(.makingsFound(house: house, making: making, count: count))
        }
        return events
    }

    /// The makings a load brought in from the land's sites brings with it.
    static func makings(in load: Stock) -> [Making: Int] {
        var found: [Making: Int] = [:]
        for resource in Resource.allCases where load[resource] >= Making.per(resource) {
            found[Making.of(resource), default: 0] += load[resource] / Making.per(resource)
        }
        return found
    }

    /// Why a House can't forge a piece of a kind this fine now, if it can't.
    func forgeRefusal(_ kind: GearKind, _ quality: GearQuality, by house: Int) -> RuleError? {
        guard kind.set != nil else { return .notForged }
        let level = forgeLevel(of: house)
        guard level >= quality.forgeLevel else { return .needsForge(quality.forgeLevel) }
        guard gear(of: house).count < GameState.armouryLimit else { return .armouryFull }
        for (making, count) in recipe(kind, quality, for: house).sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let held = makings(making, of: house)
            if held < count { return .shortOfMakings(making, count - held) }
        }
        let cost = GameState.forgingCost(quality)
        return houses[house].stock.covers(cost) ? nil : .shortOf(houses[house].stock.shortfall(for: cost))
    }

    /// A House's smiths forge a piece of gear, for its makings and moonsalt:
    /// into its armoury.
    mutating func forge(_ kind: GearKind, _ quality: GearQuality, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = forgeRefusal(kind, quality, by: house) { throw refusal }
        for (making, count) in recipe(kind, quality, for: house) {
            let index = makings!.firstIndex { $0.house == house && $0.making == making }!
            makings![index].count -= count
        }
        makings!.removeAll { $0.count <= 0 }
        houses[house].stock.debit(GameState.forgingCost(quality))
        let piece = Gear(id: takeID(), kind: kind, quality: quality, owner: house)
        armoury = gear + [piece]
        return [.gearForged(house: house, gear: piece)]
    }

    /// What the sets among a commander's pieces give the company it leads.
    static func setBonus(_ edge: Edge, of pieces: [Gear]) -> Int {
        guard pieces.count >= 2 else { return 0 }
        return GearSet.allCases.reduce(0) { total, set in
            total + (set.bonus(pieces: pieces.filter { $0.kind.set == set }.count)[edge] ?? 0)
        }
    }
}
