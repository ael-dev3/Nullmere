/// How hard the rival Houses play.
public enum Difficulty: String, Codable, CaseIterable, Sendable {
    /// Rivals start with less, gather less, and are slow to make war on the player.
    case gentle
    /// Rivals play on the same footing as the player.
    case even
    /// Rivals start richer, gather more, and press the player hard.
    case merciless

    public var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .even: return "Even"
        case .merciless: return "Merciless"
        }
    }

    /// Rivals' starting stores and income, in percent.
    public var rivalYield: Int {
        switch self {
        case .gentle: return 80
        case .even: return 100
        case .merciless: return 125
        }
    }

    /// How readily rivals declare war on the player, in percent of the usual.
    public var rivalAggression: Int {
        switch self {
        case .gentle: return 50
        case .even: return 100
        case .merciless: return 170
        }
    }
}

/// How a new game is set up.
public struct GameSettings: Codable, Equatable, Sendable {
    /// Words that name the world; the same words make the same world.
    public var seedText: String
    public var houseCount: Int
    public var radius: Int
    /// The player's House, by name.
    public var playerHouse: String
    public var difficulty: Difficulty

    public init(seedText: String, houseCount: Int = 5, radius: Int = 24, playerHouse: String = "Aurel", difficulty: Difficulty = .even) {
        self.seedText = seedText
        self.houseCount = houseCount
        self.radius = radius
        self.playerHouse = playerHouse
        self.difficulty = difficulty
    }

    private enum CodingKeys: String, CodingKey {
        case seedText, houseCount, radius, playerHouse, difficulty
    }

    /// Games saved before difficulty was chosen play on even terms.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seedText = try container.decode(String.self, forKey: .seedText)
        houseCount = try container.decode(Int.self, forKey: .houseCount)
        radius = try container.decode(Int.self, forKey: .radius)
        playerHouse = try container.decode(String.self, forKey: .playerHouse)
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .even
    }

    public var seed: UInt64 { Seed.from(seedText) }
}

/// The whole state of one game. Every rule is a function of this value, so
/// saving is encoding it and the same commands replay the same history.
public struct GameState: Codable, Equatable, Sendable {
    public static let formatVersion = 1

    public var formatVersion: Int
    public let settings: GameSettings
    public internal(set) var watch: Int
    public internal(set) var map: WorldMap
    public internal(set) var houses: [House]
    public internal(set) var holds: [Hold]
    public internal(set) var units: [Unit]
    public internal(set) var relations: [Relation]
    public internal(set) var envoys: [Envoy]
    public internal(set) var chronicle: [ChronicleEntry]
    public internal(set) var outcome: Outcome?
    var nextID: Int
    /// Counts random draws within a watch so each draw is independent.
    var draws: UInt64
    /// One snapshot per watch; absent in saves from before it was kept.
    var recorded: [Snapshot]?

    public var player: Int { houses.first { $0.isPlayer }?.id ?? 0 }

    /// Starts a new game.
    public init(settings: GameSettings) {
        let seed = settings.seed
        let world = WorldGenerator(seed: seed, radius: settings.radius, houseCount: settings.houseCount).generate()
        var random = SeededRandom(seed: Seed.mix(seed, 100))

        formatVersion = GameState.formatVersion
        self.settings = settings
        watch = 1
        map = world.map
        houses = []
        holds = []
        units = []
        relations = []
        envoys = []
        chronicle = []
        outcome = nil
        nextID = 1
        draws = 0
        recorded = []

        var names = Names.houses.filter { $0 != settings.playerHouse }
        random.shuffle(&names)
        let temperaments = Temperament.allCases
        var usedHoldNames: Set<String> = []
        for (index, seat) in world.seats.enumerated() {
            let isPlayer = index == 0
            let name = isPlayer ? settings.playerHouse : names[index - 1]
            let temperament = isPlayer ? .steadfast : temperaments[(index - 1) % temperaments.count]
            let sigil = Names.houses.firstIndex(of: name) ?? index
            var house = House(id: index, name: name, sigil: sigil, isPlayer: isPlayer, temperament: temperament, tileCount: map.count)
            house.stock = Stock(grain: 60, timber: 50, stone: 40, moonsalt: 5)
                .scaled(percent: isPlayer ? 100 : settings.difficulty.rivalYield)
            houses.append(house)

            let holdName = Names.hold(using: &random, avoiding: usedHoldNames)
            usedHoldNames.insert(holdName)
            holds.append(Hold(id: takeID(), name: holdName, owner: index, position: seat, isSeat: true, foundedWatch: 1))
            placeUnit(.lantern, for: index, near: seat)
            placeUnit(.spear, for: index, near: seat)
        }
        for first in houses.indices {
            for second in houses.indices where second > first {
                relations.append(Relation(first: first, second: second))
            }
        }
        record(.beginning, houses.map(\.id), "The Houses take their seats around the Nullmere. The water lies still under a full moon.")
        // Every House knows the country around its own seat.
        for hold in holds {
            for hex in hold.position.spiral(GameState.knownAtStart) {
                if let tile = map.index(of: hex) {
                    houses[hold.owner].explored[tile] = true
                }
            }
        }
        refreshSight()
        takeSnapshot()
    }

    // MARK: Lookups

    public func house(_ id: Int) -> House? {
        houses.indices.contains(id) ? houses[id] : nil
    }

    public func unit(_ id: Int) -> Unit? {
        units.first { $0.id == id }
    }

    public func hold(_ id: Int) -> Hold? {
        holds.first { $0.id == id }
    }

    public func unit(at hex: Hex) -> Unit? {
        units.first { $0.position == hex }
    }

    public func hold(at hex: Hex) -> Hold? {
        holds.first { $0.position == hex }
    }

    public func holds(of house: Int) -> [Hold] {
        holds.filter { $0.owner == house }
    }

    public func units(of house: Int) -> [Unit] {
        units.filter { $0.owner == house }
    }

    public func seat(of house: Int) -> Hold? {
        holds.first { $0.owner == house && $0.isSeat }
    }

    public var livingHouses: [House] {
        houses.filter { !$0.isEliminated }
    }

    // MARK: Diplomacy

    public func relation(_ a: Int, _ b: Int) -> Relation? {
        let first = min(a, b)
        let second = max(a, b)
        return relations.first { $0.first == first && $0.second == second }
    }

    public func stance(_ a: Int, _ b: Int) -> Stance {
        guard a != b else { return .pact }
        return relation(a, b)?.stance ?? .peace
    }

    public func isAtWar(_ a: Int, _ b: Int) -> Bool {
        a != b && stance(a, b) == .war
    }

    mutating func setStance(_ stance: Stance, between a: Int, and b: Int, by actor: Int) {
        guard let index = relations.firstIndex(where: { $0.first == min(a, b) && $0.second == max(a, b) }) else { return }
        let previous = relations[index].stance
        relations[index].stance = stance
        relations[index].since = watch
        if stance == .war {
            relations[index].aggressor = actor
            if previous == .pact {
                relations[index].betrayals += 1
            }
        }
    }

    // MARK: Territory

    /// The hold that owns each tile, by map index. The older hold keeps a
    /// tile when two reach it.
    public func territory() -> [Int?] {
        var owners = [Int?](repeating: nil, count: map.count)
        for hold in holds.sorted(by: { ($0.foundedWatch, $0.id) < ($1.foundedWatch, $1.id) }) {
            for hex in hold.position.spiral(hold.territoryRadius) {
                guard let index = map.index(of: hex), owners[index] == nil else { continue }
                let terrain = map[index].terrain
                guard !terrain.isWater, terrain != .spine || hex == hold.position else { continue }
                owners[index] = hold.id
            }
        }
        return owners
    }

    /// The House whose territory covers a hex.
    public func territoryOwner(of hex: Hex, in territory: [Int?]? = nil) -> Int? {
        guard let index = map.index(of: hex) else { return nil }
        let owners = territory ?? self.territory()
        guard let holdID = owners[index] else { return nil }
        return hold(holdID)?.owner
    }

    // MARK: Economy

    /// What a hold brings in each watch.
    public func income(of hold: Hold, territory: [Int?]? = nil) -> Stock {
        let owners = territory ?? self.territory()
        var total = hold.isSeat ? Stock(grain: 3, timber: 2, stone: 2, moonsalt: 1) : Stock(grain: 2, timber: 1, stone: 1)
        for hex in hold.position.spiral(hold.territoryRadius) {
            guard let index = map.index(of: hex), owners[index] == hold.id else { continue }
            total = total + map[index].yield
        }
        for kind in BuildingKind.allCases {
            guard let resource = kind.boostedResource else { continue }
            let level = hold.level(kind)
            guard level > 0 else { continue }
            total[resource] = total[resource] * (100 + BuildingKind.yieldBoostPerLevel * level) / 100
        }
        return total
    }

    /// A House's income before upkeep.
    public func income(of house: Int) -> Stock {
        let owners = territory()
        return holds(of: house).reduce(Stock.zero) { $0 + income(of: $1, territory: owners) }
    }

    /// How much of each resource a House can keep. Holds add storehouses;
    /// whatever comes in beyond this is lost.
    public func storage(of house: Int) -> Int {
        GameState.baseStorage + GameState.storagePerHold * holds(of: house).count
    }

    /// How far around its seat each House knows the land when a game begins.
    public static let knownAtStart = 5

    public static let baseStorage = 300
    public static let storagePerHold = 200

    /// Adds income to a House's stock, up to its storage. Rivals gather
    /// more or less as the difficulty sets.
    mutating func store(_ income: Stock, for house: Int) {
        let yield = houses[house].isPlayer ? 100 : settings.difficulty.rivalYield
        houses[house].stock.credit(yield == 100 ? income : income.scaled(percent: yield))
        let room = storage(of: house)
        for resource in Resource.allCases where houses[house].stock[resource] > room {
            houses[house].stock[resource] = room
        }
    }

    /// Grain a House's units eat each watch.
    public func upkeep(of house: Int) -> Int {
        units(of: house).reduce(0) { $0 + $1.kind.upkeep }
    }

    /// A rough measure of military might, for rivals weighing war.
    public func strength(of house: Int) -> Int {
        let army = units(of: house).reduce(0) { total, unit in
            total + (unit.kind.attack + unit.kind.defense) * unit.health / 10
        }
        let walls = holds(of: house).reduce(0) { $0 + $1.ward / 2 }
        return army + walls
    }

    /// Renown, for ranking the Houses.
    public func renown(of house: Int) -> Int {
        let built = holds(of: house).reduce(0) { total, hold in
            total + hold.levels.values.reduce(0, +)
        }
        let spire = holds(of: house).map { $0.level(.moonspire) }.max() ?? 0
        return holds(of: house).count * 10 + built * 2 + units(of: house).count + spire * 15
    }

    // MARK: Sight

    /// The tiles a House sees right now, with its allies' sight.
    public func visibility(for house: Int) -> [Bool] {
        var visible = [Bool](repeating: false, count: map.count)
        let watchers = houses.filter { $0.id == house || stance($0.id, house) == .pact }.map(\.id)
        for watcher in watchers {
            for unit in units(of: watcher) {
                let range = unit.kind.sight + (map[unit.position]?.terrain.visionBonus ?? 0)
                for hex in unit.position.spiral(range) {
                    if let index = map.index(of: hex) { visible[index] = true }
                }
            }
            for hold in holds(of: watcher) {
                for hex in hold.position.spiral(hold.sight) {
                    if let index = map.index(of: hex) { visible[index] = true }
                }
            }
        }
        return visible
    }

    /// Adds what every House sees now to what it has explored.
    mutating func refreshSight() {
        for index in houses.indices where !houses[index].isEliminated {
            let visible = visibility(for: houses[index].id)
            for tile in visible.indices where visible[tile] {
                houses[index].explored[tile] = true
            }
        }
    }

    // MARK: Bookkeeping

    mutating func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    mutating func random() -> SeededRandom {
        draws += 1
        return SeededRandom(seed: Seed.mix(settings.seed, UInt64(watch), draws))
    }

    mutating func record(_ kind: ChronicleEntry.Kind, _ houses: [Int], _ text: String) {
        chronicle.append(ChronicleEntry(watch: watch, kind: kind, houses: houses, text: text))
    }

    /// Puts a new unit on the hex, or the nearest free passable hex.
    @discardableResult
    mutating func placeUnit(_ kind: UnitKind, for house: Int, near hex: Hex) -> Unit? {
        let spot = hex.spiral(3).first { candidate in
            guard let tile = map[candidate], tile.terrain.isPassable else { return false }
            return unit(at: candidate) == nil
        }
        guard let spot else { return nil }
        let placed = Unit(id: takeID(), kind: kind, owner: house, position: spot)
        units.append(placed)
        return placed
    }

    func unitIndex(_ id: Int) -> Int? {
        units.firstIndex { $0.id == id }
    }

    func holdIndex(_ id: Int) -> Int? {
        holds.firstIndex { $0.id == id }
    }
}
