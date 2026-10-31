/// A place in the land where one store lies thick enough to be worked by a
/// company sent there: finite, and when worked out, gone, while the land
/// brings others up elsewhere.
public struct Site: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    /// The store it yields.
    public let store: Resource
    /// I to V: the higher, the more it holds.
    public let level: Int
    public let position: Hex
    /// What is left in it.
    public internal(set) var remaining: Int
    /// The watch it was found.
    public let found: Int
    /// The alliance whose yard it is, raised on its land for its companies
    /// alone; absent for the land's own.
    public let alliance: Int?

    public init(id: Int, store: Resource, level: Int, position: Hex, found: Int, alliance: Int? = nil) {
        self.id = id
        self.store = store
        self.level = min(max(level, 1), Site.highestLevel)
        self.position = position
        self.remaining = alliance == nil ? Site.richness(of: store, level: self.level) : Yard.richness(of: store)
        self.found = found
        self.alliance = alliance
    }

    public static let highestLevel = 5

    /// What a site of a store and level holds when found.
    public static func richness(of store: Resource, level: Int) -> Int {
        (store == .moonsalt ? 60 : 300) * level
    }

    /// Its name on the map.
    public var title: String { alliance == nil ? Site.title(of: store) : Yard.title(of: store) }

    /// Whether it is an alliance's yard.
    public var isYard: Bool { alliance != nil }

    public static func title(of store: Resource) -> String {
        switch store {
        case .grain: return "Fallow Field"
        case .timber: return "Deadfall"
        case .stone: return "Scree"
        case .moonsalt: return "Salt Pan"
        }
    }

    /// The store a kind of ground holds, if it holds one to work.
    static func store(of terrain: Terrain) -> Resource? {
        switch terrain {
        case .greyfield, .strand: return .grain
        case .blackwood: return .timber
        case .barrow: return .stone
        case .saltFlat: return .moonsalt
        case .still, .shallows, .spine, .ford: return nil
        }
    }
}

/// What a company has been sent to do beyond a march.
public enum Errand: Codable, Equatable, Sendable {
    /// Work a site until it carries all it can, or the site is worked out.
    case gather(site: Int)
    /// Bring what it carries to the nearest of its House's holds.
    case homeward
    /// Gather at a rally's muster, and march and strike with its host.
    case rally(Int)
    /// Keep the gates of an ally's hold, striking back at those who strike it.
    case reinforce(hold: Int)
}

extension GameState {
    /// The sites of the land.
    public var sitesInLand: [Site] { sites ?? [] }

    public func site(_ id: Int) -> Site? {
        sites?.first { $0.id == id }
    }

    public func site(at hex: Hex) -> Site? {
        sites?.first { $0.position == hex }
    }

    /// The fewest tiles from any hold at which sites are found.
    public static let sitesFromHolds = 3

    /// How many sites the land holds at once: three for each seat.
    var sitesWanted: Int { houses.count * 3 }

    /// Sites come up in the land, up to their number, three a watch at
    /// most: a store as the ground gives, the richer the further from
    /// every hold.
    mutating func raiseSites() {
        if sites == nil { sites = [] }
        // An alliance's yards are its own, not the land's.
        var count = sites!.count { $0.alliance == nil }
        guard count < sitesWanted else { return }
        var random = random()
        var raised = 0
        for _ in 0..<12 where raised < 3 && count < sitesWanted {
            let hex = map.hex(at: random.int(below: map.count))
            guard let tile = map[hex], tile.terrain.isPassable, tile.feature == nil, let store = Site.store(of: tile.terrain),
                  !isOccupied(hex), site(at: hex) == nil, shrine(at: hex) == nil else { continue }
            let far = holds.map { $0.position.distance(to: hex) }.min() ?? Int.max
            guard far >= GameState.sitesFromHolds else { continue }
            let level = 1 + (min(far, 30) - GameState.sitesFromHolds) / 3 + random.int(below: 2)
            sites!.append(Site(id: takeID(), store: store, level: level, position: hex, found: watch))
            raised += 1
            count += 1
        }
    }

    // MARK: A company's work

    /// What a company gathers each watch at a site of a store, with its
    /// tier, its House's studies and its commander, and a fifth more on its
    /// alliance's land.
    public func gatheringRate(of unit: Unit, for store: Resource) -> Int {
        let base: Int
        switch unit.kind {
        case .spear: base = 30
        case .bow: base = 25
        case .rider: base = 40
        case .lantern, .founder: base = 0
        }
        let land = isOnOwnLand(unit) ? Standard.gathering : 0
        let rate = base * (100 + 15 * (unit.tier - 1)) / 100 * (100 + bonus(.gathering, for: unit) + land) / 100
        return store == .moonsalt ? rate / 4 : rate
    }

    /// What a company gathers each watch at a site: at an alliance's yard,
    /// a quarter more.
    public func gatheringRate(of unit: Unit, at site: Site) -> Int {
        gatheringRate(of: unit, for: site.store) * (100 + (site.isYard ? Yard.gathering : 0)) / 100
    }

    /// The most of a store a company carries, with its tier, its House's
    /// studies and its commander.
    public func capacity(of unit: Unit, for store: Resource) -> Int {
        let base: Int
        switch unit.kind {
        case .spear: base = 150
        case .bow: base = 120
        case .rider: base = 200
        case .lantern, .founder: base = 0
        }
        let load = base * (100 + 25 * (unit.tier - 1)) / 100 * (100 + bonus(.load, for: unit)) / 100
        return store == .moonsalt ? load / 4 : load
    }

    /// Why a House can't send a company to a site, if it can't.
    public func gatherRefusal(_ unitID: Int, at siteID: Int, as house: Int) -> RuleError? {
        guard let unit = unit(unitID) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard unit.kind.isMilitary else { return .cannotGather(unit.kind) }
        guard let site = site(siteID), isExplored(site.position, by: house) else { return .unknownSite }
        if let yard = site.alliance, alliance(of: house)?.id != yard { return .foreignYard }
        if let load = unit.load, !load.isZero {
            let carried = Resource.allCases.first { load[$0] > 0 } ?? site.store
            if carried != site.store || load[carried] >= capacity(of: unit, for: carried) { return .loadFull }
        }
        if unit.position != site.position, path(for: unit, to: site.position) == nil { return .noPath }
        return nil
    }

    mutating func gather(_ unitID: Int, at siteID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = gatherRefusal(unitID, at: siteID, as: house) { throw refusal }
        let index = unitIndex(unitID)!
        units[index].errand = .gather(site: siteID)
        units[index].fortified = false
        units[index].destination = units[index].position == site(siteID)!.position ? nil : site(siteID)!.position
        return [.sentToGather(unit: unitID, site: siteID)] + march(unitID)
    }

    /// The watch's work in the land: companies beside their own holds give
    /// up what they carry; those on their sites gather; full, or with their
    /// site worked out, they turn for home.
    mutating func workTheLand() -> [GameEvent] {
        var events: [GameEvent] = []
        for unit in units.sorted(by: { $0.id < $1.id }) {
            guard let index = unitIndex(unit.id) else { continue }
            events += deliver(index)
            guard case .gather(let siteID)? = units[index].errand else { continue }
            guard let siteIndex = sites?.firstIndex(where: { $0.id == siteID }) else {
                // Its site is worked out: home with what it has, if anything.
                events += turnHome(index)
                continue
            }
            let site = sites![siteIndex]
            // A yard of an alliance its House has left is no more its to work.
            if let yard = site.alliance, alliance(of: unit.owner)?.id != yard {
                events += turnHome(index)
                continue
            }
            guard units[index].position == site.position else { continue }
            let carried = units[index].load?[site.store] ?? 0
            let room = capacity(of: units[index], for: site.store) - carried
            let amount = min(gatheringRate(of: units[index], at: site), site.remaining, max(room, 0))
            if amount > 0 {
                var load = units[index].load ?? .zero
                load[site.store] += amount
                units[index].load = load
                sites![siteIndex].remaining -= amount
                // A yard's alliance takes its tithe besides.
                if let yard = site.alliance {
                    var tithe = Stock.zero
                    tithe[site.store] = (amount * Yard.tithe + 99) / 100
                    fill(coffersOf: yard, with: tithe)
                }
            }
            if sites![siteIndex].remaining <= 0 {
                sites!.remove(at: siteIndex)
                events.append(.siteWorkedOut(site: site.id, store: site.store, at: site.position))
            }
            if sites?.contains(where: { $0.id == siteID }) != true || amount >= room {
                events.append(.gathered(unit: unit.id, owner: unit.owner, load: units[index].load ?? .zero))
                events += turnHome(index)
            }
        }
        return events
    }

    /// The watches a gatherer at its site still takes to fill its load, or
    /// to work the site out if that comes first; nil for a company not at
    /// work on its site.
    public func watchesToFill(_ unit: Unit) -> Int? {
        guard case .gather(let siteID)? = unit.errand, let site = site(siteID), unit.position == site.position else { return nil }
        let room = max(capacity(of: unit, for: site.store) - (unit.load?[site.store] ?? 0), 0)
        let rate = gatheringRate(of: unit, at: site)
        guard rate > 0 else { return nil }
        return max((min(room, site.remaining) + rate - 1) / rate, 1)
    }

    /// Whether a company is out at the land's work: gathering at a site, or
    /// on its way home with a load.
    public func isOutGathering(_ unit: Unit) -> Bool {
        switch unit.errand {
        case .gather?, .homeward?: return true
        case nil: return !(unit.load ?? .zero).isZero
        default: return false
        }
    }

    /// A company called home: it gives up what it carries at once if a hold
    /// of its House is beside it, and otherwise turns for the nearest with
    /// all it carries; carrying nothing, it is done gathering where it stands.
    mutating func recall(_ unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        guard isOutGathering(units[index]) else { throw .notGathering }
        var events = deliver(index)
        guard let after = unitIndex(unitID) else { return events }
        if units[after].load.map({ !$0.isZero }) == true {
            events += turnHome(after)
        } else {
            units[after].errand = nil
            units[after].destination = nil
        }
        events.append(.recalled(unit: unitID, owner: house))
        return events + march(unitID)
    }

    /// Every company of a House out at the land's work called home, the
    /// first mustered first.
    mutating func recallAll(of house: Int) throws(RuleError) -> [GameEvent] {
        let out = units.indices.filter { units[$0].owner == house && isOutGathering(units[$0]) }.map { units[$0].id }.sorted()
        guard !out.isEmpty else { throw .noneGathering }
        var events: [GameEvent] = []
        for id in out {
            events += (try? recall(id, as: house)) ?? []
        }
        return events
    }

    /// A company sets out for the nearest of its House's holds with what it
    /// carries, or, carrying nothing, is done.
    private mutating func turnHome(_ index: Int) -> [GameEvent] {
        guard let load = units[index].load, !load.isZero else {
            units[index].errand = nil
            return []
        }
        let unit = units[index]
        guard let home = holds(of: unit.owner).min(by: { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }) else {
            units[index].errand = nil
            return []
        }
        units[index].errand = .homeward
        units[index].destination = home.position == unit.position ? nil : home.position
        return []
    }

    /// A company at or beside one of its House's holds gives up what it
    /// carries to its stores.
    private mutating func deliver(_ index: Int) -> [GameEvent] {
        let unit = units[index]
        guard let load = unit.load, !load.isZero,
              let hold = holds(of: unit.owner).first(where: { $0.position.distance(to: unit.position) <= 1 }) else { return [] }
        store(load, for: unit.owner)
        units[index].load = nil
        if units[index].errand == .homeward {
            units[index].errand = nil
            units[index].destination = nil
        }
        // What was gathered brings makings for the Forge with it.
        return [.delivered(unit: unit.id, owner: unit.owner, hold: hold.id, load: load)]
            + give(makings: GameState.makings(in: load), to: unit.owner)
    }
}
