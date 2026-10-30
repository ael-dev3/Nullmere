/// What a House keeps in its satchel to use when it will: hourglasses that
/// hasten what a hold has under way, caches of stores, ward stones that
/// make a hold's ward whole, and draughts that mend its companies. They
/// come from lairs broken, happenings' marks and the charges kept.
public enum ItemKind: String, CaseIterable, Codable, Sendable {
    /// What a hold has under way, its work and its muster, comes a watch
    /// nearer; or the House's study, if it names no hold.
    case hourglass
    case grainCache
    case timberCache
    case stoneCache
    case moonsaltCache
    /// A hold's ward made whole.
    case wardStone
    /// Every company of the House mends.
    case mendingDraught

    public var title: String {
        switch self {
        case .hourglass: return "Salt Hourglass"
        case .grainCache: return "Cache of Grain"
        case .timberCache: return "Cache of Timber"
        case .stoneCache: return "Cache of Stone"
        case .moonsaltCache: return "Cache of Moonsalt"
        case .wardStone: return "Ward Stone"
        case .mendingDraught: return "Mending Draught"
        }
    }

    /// More than one.
    public var plural: String {
        switch self {
        case .hourglass: return "Salt Hourglasses"
        case .grainCache: return "Caches of Grain"
        case .timberCache: return "Caches of Timber"
        case .stoneCache: return "Caches of Stone"
        case .moonsaltCache: return "Caches of Moonsalt"
        case .wardStone: return "Ward Stones"
        case .mendingDraught: return "Mending Draughts"
        }
    }

    /// So many of it, in words: "a Ward Stone", "2 Salt Hourglasses".
    public func counted(_ count: Int) -> String {
        count == 1 ? "a \(title)" : "\(count) \(plural)"
    }

    /// What it does, in a line.
    public var effect: String {
        switch self {
        case .hourglass: return "a hold's work and muster a watch nearer, or the House's study"
        case .grainCache, .timberCache, .stoneCache, .moonsaltCache: return "\(stores) to the House's stores"
        case .wardStone: return "a hold's ward made whole"
        case .mendingDraught: return "\(GameState.draughtMending) health to every company of the House"
        }
    }

    /// The stores a cache holds; none for any other.
    public var stores: Stock {
        switch self {
        case .grainCache: return Stock(grain: 120)
        case .timberCache: return Stock(timber: 120)
        case .stoneCache: return Stock(stone: 120)
        case .moonsaltCache: return Stock(moonsalt: 20)
        case .hourglass, .wardStone, .mendingDraught: return .zero
        }
    }

    /// Whether it is used on one of the House's holds.
    public var needsHold: Bool { self == .wardStone }

    /// The cache of a store.
    public static func cache(of resource: Resource) -> ItemKind {
        switch resource {
        case .grain: return .grainCache
        case .timber: return .timberCache
        case .stone: return .stoneCache
        case .moonsalt: return .moonsaltCache
        }
    }
}

/// So many of one kind of item a House keeps.
public struct ItemStack: Codable, Equatable, Sendable {
    public let house: Int
    public let kind: ItemKind
    public internal(set) var count: Int

    public init(house: Int, kind: ItemKind, count: Int) {
        self.house = house
        self.kind = kind
        self.count = count
    }
}

extension GameState {
    /// Health a mending draught gives every company of the House.
    public static let draughtMending = 30
    /// The most of one kind of item a House keeps.
    public static let itemsKept = 20

    /// How many of a kind of item a House keeps.
    public func items(_ kind: ItemKind, of house: Int) -> Int {
        satchel?.first { $0.house == house && $0.kind == kind }?.count ?? 0
    }

    /// Every item a House keeps, a stack a kind, in the order of their kinds.
    public func satchel(of house: Int) -> [ItemStack] {
        ItemKind.allCases.compactMap { kind in
            let count = items(kind, of: house)
            return count > 0 ? ItemStack(house: house, kind: kind, count: count) : nil
        }
    }

    /// Items given a House: kept, up to the most of a kind it may keep.
    mutating func give(_ kind: ItemKind, _ count: Int = 1, to house: Int) -> [GameEvent] {
        guard count > 0, houses.indices.contains(house), !houses[house].isEliminated else { return [] }
        var list = satchel ?? []
        let held = items(kind, of: house)
        let kept = min(GameState.itemsKept, held + count) - held
        guard kept > 0 else { return [] }
        if let index = list.firstIndex(where: { $0.house == house && $0.kind == kind }) {
            list[index].count += kept
        } else {
            list.append(ItemStack(house: house, kind: kind, count: kept))
            list.sort { ($0.house, ItemKind.allCases.firstIndex(of: $0.kind)!) < ($1.house, ItemKind.allCases.firstIndex(of: $1.kind)!) }
        }
        satchel = list
        return [.itemsGiven(house: house, kind: kind, count: kept)]
    }

    /// Items given a House, so many of each kind as the list names.
    mutating func give(_ items: [ItemKind], to house: Int) -> [GameEvent] {
        var events: [GameEvent] = []
        for kind in ItemKind.allCases {
            events += give(kind, items.filter { $0 == kind }.count, to: house)
        }
        return events
    }

    /// A lair broken fills its host's satchels: its caller gains an
    /// hourglass for each of its levels, and every House of the host a
    /// cache of the store its wilds carry most of, and makings for its
    /// Forge, three for each of the lair's levels.
    mutating func rewardLair(_ assault: LairAssault) -> [GameEvent] {
        let spoils = assault.kind.spoils
        let cache = ItemKind.cache(of: Resource.allCases.max { spoils[$0] < spoils[$1] }!)
        var events = give(.hourglass, assault.level, to: assault.caller)
        for share in assault.shares {
            events += give(cache, to: share.house)
            events += give(makings: [Making.left(by: assault.kind): 3 * assault.level], to: share.house)
        }
        return events
    }

    /// A House uses one of its items: on one of its holds for a ward stone
    /// or an hourglass naming one, otherwise on the House.
    mutating func use(_ kind: ItemKind, on holdID: Int?, as house: Int) throws(RuleError) -> [GameEvent] {
        guard items(kind, of: house) > 0 else { throw .noItem }
        var hold: Hold?
        if let holdID {
            guard let index = holdIndex(holdID) else { throw .unknownHold }
            guard holds[index].owner == house else { throw .notYours }
            hold = holds[index]
        } else if kind.needsHold {
            throw .unknownHold
        }
        switch kind {
        case .hourglass:
            if let hold {
                guard hasten(hold.id) else { throw .nothingToHasten }
            } else {
                guard var pursuit = houses[house].research.pursuit, pursuit.watchesLeft > 1 else { throw .nothingToHasten }
                pursuit.watchesLeft -= 1
                houses[house].research.pursuit = pursuit
            }
        case .grainCache, .timberCache, .stoneCache, .moonsaltCache:
            guard !storageFull(for: house, of: kind.stores) else { throw .storageFull }
            store(kind.stores, for: house)
        case .wardStone:
            guard let hold, let index = holdIndex(hold.id), holds[index].ward < holds[index].maximumWard else { throw .wardWhole }
            holds[index].ward = holds[index].maximumWard
        case .mendingDraught:
            let hurt = units.indices.filter { units[$0].owner == house && units[$0].health < 100 }
            guard !hurt.isEmpty else { throw .noneHurt }
            for index in hurt {
                units[index].health = min(100, units[index].health + GameState.draughtMending)
            }
        }
        let index = satchel!.firstIndex { $0.house == house && $0.kind == kind }!
        satchel![index].count -= 1
        if satchel![index].count == 0 { satchel!.remove(at: index) }
        return [.itemUsed(house: house, kind: kind, hold: hold?.id)]
    }

    /// What a hold has under way comes a watch nearer: its work and its
    /// muster each lose a watch, so long as one is left after; its
    /// healing, paid for, has nothing to wait on. Whether anything did.
    private mutating func hasten(_ holdID: Int) -> Bool {
        guard let index = holdIndex(holdID) else { return false }
        var hastened = false
        if var project = holds[index].project, project.watchesLeft > 1 {
            project.watchesLeft -= 1
            holds[index].project = project
            hastened = true
        }
        if var training = holds[index].training, training.watchesLeft > 1 {
            training.watchesLeft -= 1
            holds[index].training = training
            hastened = true
        }
        return hastened
    }

    /// Whether a House's stores could take none of what is given.
    private func storageFull(for house: Int, of stock: Stock) -> Bool {
        let room = storage(of: house)
        return Resource.allCases.allSatisfy { stock[$0] == 0 || houses[house].stock[$0] >= room }
    }
}
