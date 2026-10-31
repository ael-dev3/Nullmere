/// How a world is made.
public struct GameSettings: Codable, Equatable, Sendable {
    /// Words that name the world; the same words make the same world.
    public var seedText: String
    /// Seats around the lake: one House each.
    public var houseCount: Int
    public var radius: Int
    /// The first House's name, when a keeper holds it from the start.
    public var playerHouse: String
    /// Seats held by a keeper from the start: none in a realm, whose
    /// keepers claim seats as they arrive. Tests rehearse one House's
    /// game with one.
    public var keepers: Int
    /// The shape of the lake.
    public var lake: Lake

    public init(seedText: String, houseCount: Int = 5, radius: Int = 24, playerHouse: String = "Aurel", keepers: Int = 0,
                lake: Lake = .round) {
        self.seedText = seedText
        self.houseCount = houseCount
        self.radius = radius
        self.playerHouse = playerHouse
        self.keepers = min(max(keepers, 0), 1)
        self.lake = lake
    }

    private enum CodingKeys: String, CodingKey {
        case seedText, houseCount, radius, playerHouse, keepers, lake
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seedText = try container.decode(String.self, forKey: .seedText)
        houseCount = try container.decode(Int.self, forKey: .houseCount)
        radius = try container.decode(Int.self, forKey: .radius)
        playerHouse = try container.decode(String.self, forKey: .playerHouse)
        keepers = try container.decodeIfPresent(Int.self, forKey: .keepers) ?? 0
        lake = try container.decodeIfPresent(Lake.self, forKey: .lake) ?? .round
    }

    public var seed: UInt64 { Seed.from(seedText) }
}

/// The whole state of one age's world. Every rule is a function of this
/// value, so keeping it is encoding it, and the same commands replay the
/// same history.
public struct GameState: Codable, Equatable, Sendable {
    public static let formatVersion = 1

    public var formatVersion: Int
    public internal(set) var settings: GameSettings
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
    /// In a keeper's view, each House's strength as the realm reckons it:
    /// common knowledge, though their companies are out of sight.
    var reputed: [Int]?
    /// Gifts sent between Houses lately, remembered for goodwill.
    var gifts: [Gift]?
    /// The omen on the realm, and when the last lifted.
    var omen: Omen?
    var omenLifted: Int?
    /// Where the moon's reflection lies: found on the whole map as the world
    /// is made, so a keeper's view, the unexplored left as land, shows it
    /// in the same place from the first watch. Absent in older saves.
    public internal(set) var moonWater: DeepWater?
    /// Every commander of the realm, each at its id's place; absent in
    /// saves from before commanders, which raise them at the next watch.
    var commanders: [Commander]?
    /// The wilds of the far country; absent in saves from before them,
    /// which raise them as the watch turns.
    var wilds: [Wild]?
    /// The land's sites, where companies gather; absent in saves from
    /// before them, which find them as the watch turns.
    var sites: [Site]?
    /// The alliances standing; absent in saves from before them.
    var alliances: [Alliance]?
    /// The keepers' words, the latest last; absent before any were said.
    var words: [Word]?
    /// The rallies gathering or on the march; absent in saves from before them.
    var rallies: [Rally]?
    /// How far the watch has been walked, in a realm, whose watch passes
    /// pace by pace; absent in a world whose marches go as each watch turns.
    public internal(set) var pacing: Pacing?
    /// The fields of battle going on in a realm's watch; absent when none is.
    var fields: [Field]?
    /// The realm's holy sites; absent in saves from before them, which find
    /// them as the watch turns.
    var shrines: [Shrine]?
    /// The lairs of the wilds standing; absent in saves from before them,
    /// which find them as the watch turns.
    var lairs: [Lair]?
    /// The alliances' standards; absent before any was raised.
    var standards: [Standard]?
    /// The alliances' halls, standing or rising; absent before any was begun.
    var halls: [AllianceHall]?
    /// The alliances' storehouses, standing or rising; absent before any
    /// was begun.
    var storehouses: [Storehouse]?
    /// The gear the Houses hold, worn by their commanders or kept; absent
    /// in saves from before gear.
    var armoury: [Gear]?
    /// What the Houses keep in their satchels; absent before any was given.
    var satchel: [ItemStack]?
    /// The makings the Houses keep for their Forges; absent before any
    /// were found.
    var makings: [MakingStack]?
    /// The happening of the realm under way, if any.
    public internal(set) var happening: Happening?
    /// The Sundering under way, or the last, settled, until the next.
    public internal(set) var sundering: Sundering?
    /// A world whose shores never sunder: the Frontier's, whose kingdoms
    /// are the realms its keepers come from, not its shores. Absent
    /// elsewhere.
    var unsundered: Bool?
    /// The deeds the Houses have done this age; absent before any.
    public internal(set) var deedsDone: [DeedDone]?
    /// How many of their charges each House has done, by its id; absent
    /// in saves from before charges, which set every House its first.
    public internal(set) var chargesDone: [Int]?
    /// In a keeper's view, each House's might as the realm reckons it.
    var reputedMight: [Int]?
    /// In a keeper's view, the marches they may know of: where their
    /// companies are bound and when they should be there, and the way
    /// others in sight are going. Absent in the world itself.
    public internal(set) var marches: [March]?

    /// Where the realm's rounds begin, as its seed sets them: kept so a
    /// keeper's copy, which has no seed, deals heritages and foretells
    /// happenings as the realm does. Absent in saves from before it, which
    /// find them from their seed.
    var dealing: Dealing?

    public var player: Int { houses.first { $0.isPlayer }?.id ?? 0 }

    /// Where the realm's rounds begin: as kept, or as a save from before
    /// they were kept finds them from its seed.
    var dealt: Dealing { dealing ?? Dealing(seed: settings.seed) }

    /// Makes an age's world: its lake, its Houses at their seats.
    public init(settings: GameSettings) {
        let seed = settings.seed
        let world = WorldGenerator(seed: seed, radius: settings.radius, houseCount: settings.houseCount, lake: settings.lake).generate()
        var random = SeededRandom(seed: Seed.mix(seed, 100))

        formatVersion = GameState.formatVersion
        self.settings = settings
        dealing = Dealing(seed: seed)
        watch = 1
        map = world.map
        moonWater = world.map.deepestWater()
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

        // The elder Houses take the seats in a shuffled order; a lake that
        // seats more than they fill gives the rest to the younger Houses,
        // shuffled after them.
        let open = { (names: [String]) in settings.keepers > 0 ? names.filter { $0 != settings.playerHouse } : names }
        var names = open(Names.elder)
        random.shuffle(&names)
        // A kept first seat takes its keeper's name, not one of these.
        let named = settings.keepers > 0 ? world.seats.count - 1 : world.seats.count
        if named > names.count {
            var younger = open(Names.younger)
            random.shuffle(&younger)
            names += younger
        }
        // Tempers dealt evenly and at random: no seat number always the
        // same kind of neighbour.
        var temperaments = world.seats.indices.map { Temperament.allCases[$0 % Temperament.allCases.count] }
        random.shuffle(&temperaments)
        var usedHoldNames: Set<String> = []
        for (index, seat) in world.seats.enumerated() {
            let isPlayer = index == 0 && settings.keepers > 0
            // The first seat, unkept, takes the name after all the others'.
            let name = index > 0 ? names[index - 1] : (isPlayer ? settings.playerHouse : names[world.seats.count - 1])
            let temperament = temperaments[index]
            let sigil = Names.houses.firstIndex(of: name) ?? index
            var house = House(id: index, name: name, sigil: sigil, isPlayer: isPlayer, temperament: temperament, tileCount: map.count)
            house.stock = Stock(grain: 60, timber: 50, stone: 40, moonsalt: 5)
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
        record(.beginning, houses.map(\.id), "The Houses take their seats around \(settings.lake.title). The water lies still under a full moon.")
        // Every House knows the country around its own seat.
        for hold in holds {
            for hex in hold.position.spiral(GameState.knownAtStart) {
                if let tile = map.index(of: hex) {
                    houses[hold.owner].explored[tile] = true
                }
            }
        }
        raiseFirstCommanders()
        raiseShrines()
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
        relationIndex(a, b).map { relations[$0] }
    }

    /// Where the relation between two Houses lies: in the order the
    /// relations are made, each House with every House after it, so found
    /// at once however many Houses sit around the lake; sought through them
    /// all only where they lie otherwise.
    func relationIndex(_ a: Int, _ b: Int) -> Int? {
        let first = min(a, b), second = max(a, b), count = houses.count
        guard first >= 0, first != second else { return nil }
        let index = first * (2 * count - first - 1) / 2 + (second - first - 1)
        if second < count, relations.indices.contains(index), relations[index].first == first, relations[index].second == second {
            return index
        }
        return relations.firstIndex { $0.first == first && $0.second == second }
    }

    public func stance(_ a: Int, _ b: Int) -> Stance {
        guard a != b else { return .pact }
        return relation(a, b)?.stance ?? .peace
    }

    public func isAtWar(_ a: Int, _ b: Int) -> Bool {
        a != b && stance(a, b) == .war
    }

    mutating func setStance(_ stance: Stance, between a: Int, and b: Int, by actor: Int) {
        guard let index = relationIndex(a, b) else { return }
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
        // Then what its House's studies add.
        let studied = yieldBonuses(for: hold.owner)
        for resource in Resource.allCases where studied[resource] > 0 {
            total[resource] = total[resource] * (100 + studied[resource]) / 100
        }
        return underOmen(total)
    }

    /// A House's income before upkeep.
    public func income(of house: Int) -> Stock {
        income(of: house, territory: territory())
    }

    /// A House's income before upkeep, its land's territory already found.
    public func income(of house: Int, territory owners: [Int?]) -> Stock {
        holds(of: house).reduce(Stock.zero) { $0 + income(of: $1, territory: owners) }
    }

    /// How much of each resource a House can keep. Holds add storehouses,
    /// and its studies deeper cellars; whatever comes in beyond this is lost.
    public func storage(of house: Int) -> Int {
        (GameState.baseStorage + GameState.storagePerHold * holds(of: house).count) * (100 + bonus(.storage, for: house)) / 100
    }

    /// How far around its seat each House knows the land when a game begins.
    public static let knownAtStart = 5

    public static let baseStorage = 300
    public static let storagePerHold = 200

    /// Adds income to a House's stock, up to its storage.
    mutating func store(_ income: Stock, for house: Int) {
        houses[house].stock.credit(income)
        let room = storage(of: house)
        for resource in Resource.allCases where houses[house].stock[resource] > room {
            houses[house].stock[resource] = room
        }
    }

    /// Grain a House's units eat each watch.
    public func upkeep(of house: Int) -> Int {
        units(of: house).reduce(0) { $0 + upkeep(of: $1) }
    }

    /// Every House's strength, by its id, as `strength(of:)` weighs each,
    /// from one pass over the companies and the holds.
    public func strengths() -> [Int] {
        var weighed = [[UnitKind: (attack: Int, defense: Int)]](repeating: [:], count: houses.count)
        var army = [Int](repeating: 0, count: houses.count)
        for unit in units where army.indices.contains(unit.owner) {
            let bonuses = weighed[unit.owner][unit.kind]
                ?? (bonus(.attack(unit.kind), for: unit.owner), bonus(.defense(unit.kind), for: unit.owner))
            weighed[unit.owner][unit.kind] = bonuses
            army[unit.owner] += strength(of: unit, house: bonuses)
        }
        for hold in holds where army.indices.contains(hold.owner) {
            army[hold.owner] += hold.ward / 2
        }
        return houses.indices.map { house in
            if let reputed, reputed.indices.contains(house) { return reputed[house] }
            return army[house]
        }
    }

    /// A rough measure of military might, for rivals weighing war.
    public func strength(of house: Int) -> Int {
        if let reputed, reputed.indices.contains(house) { return reputed[house] }
        // The House's own attack and defence for each kind, weighed once
        // for all its companies of that kind.
        var weighed: [UnitKind: (attack: Int, defense: Int)] = [:]
        let army = units(of: house).reduce(0) { total, unit in
            let bonuses = weighed[unit.kind] ?? (bonus(.attack(unit.kind), for: house), bonus(.defense(unit.kind), for: house))
            weighed[unit.kind] = bonuses
            return total + strength(of: unit, house: bonuses)
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

    /// The tiles a House sees right now, with its allies' sight: those in a
    /// pact with it, and those sworn to its alliance.
    public func visibility(for house: Int) -> [Bool] {
        var visible = [Bool](repeating: false, count: map.count)
        see(for: house) { visible[$0] = true }
        return visible
    }

    /// Each tile a House sees right now, by its index, with its allies'
    /// sight; a tile seen from two places is told twice.
    func see(for house: Int, _ seen: (Int) -> Void) {
        for watcher in watchers(for: house) {
            for unit in units(of: watcher) {
                let range = sight(of: unit)
                for hex in unit.position.spiral(range) {
                    if let index = map.index(of: hex) { seen(index) }
                }
            }
            for hold in holds(of: watcher) {
                for hex in hold.position.spiral(sight(of: hold)) {
                    if let index = map.index(of: hex) { seen(index) }
                }
            }
        }
    }

    /// The Houses whose sight a House sees with: its own, and its allies',
    /// those in a pact with it and those sworn to its alliance. A fallen
    /// House has none to lend or borrow.
    func watchers(for house: Int) -> [Int] {
        let fallen = houses.indices.contains(house) && houses[house].isEliminated
        let sworn = alliance(of: house)?.members ?? []
        return houses.filter { other in
            other.id == house || (!fallen && !other.isEliminated && (stance(other.id, house) == .pact || sworn.contains(other.id)))
        }.map(\.id)
    }

    /// Adds what every House sees now to what it has explored: each
    /// House's own sight found once, and lent to its allies from there,
    /// only the tiles in sight touched.
    mutating func refreshSight() {
        var own = [[Int]](repeating: [], count: houses.count)
        for unit in units where own.indices.contains(unit.owner) {
            for hex in unit.position.spiral(sight(of: unit)) {
                if let index = map.index(of: hex) { own[unit.owner].append(index) }
            }
        }
        for hold in holds where own.indices.contains(hold.owner) {
            for hex in hold.position.spiral(sight(of: hold)) {
                if let index = map.index(of: hex) { own[hold.owner].append(index) }
            }
        }
        for index in houses.indices where !houses[index].isEliminated {
            var explored = houses[index].explored
            for watcher in watchers(for: houses[index].id) {
                for tile in own[watcher] { explored[tile] = true }
            }
            houses[index].explored = explored
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

    /// Puts a new unit on the hex, or the nearest free passable hex within
    /// three, never in another House's hold.
    @discardableResult
    mutating func placeUnit(_ kind: UnitKind, tier: Int = 1, for house: Int, near hex: Hex) -> Unit? {
        let spot = hex.spiral(3).first { candidate in
            guard let tile = map[candidate], tile.terrain.isPassable else { return false }
            return unit(at: candidate) == nil && wild(at: candidate) == nil && lair(at: candidate) == nil
                && (hold(at: candidate).map { $0.owner == house } ?? true)
        }
        guard let spot else { return nil }
        let placed = Unit(id: takeID(), kind: kind, owner: house, position: spot, tier: tier)
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
