/// What the mist hides out in the country (Rise of Kingdoms' tribal
/// villages and mysterious caves): hamlets of the free folk, who give what
/// they can spare to the Lanterns of each House that seek them out and tell
/// them of the land about, and barrows the years have opened, whose grave
/// goods a House's Lanterns bring up. Found as the world is made, out on
/// the land away from every seat; a House knows of each only once it has
/// seen its ground, and seeks each once. Nothing else stands in their way:
/// companies pass them and holds may be raised over them, and a hamlet or
/// barrow under a hold's walls is gone.
public struct Find: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable, PlainCases {
        /// A few homes of free folk about a well.
        case hamlet
        /// An old grave open to the sky.
        case barrow

        /// What one is called, unnamed.
        public var title: String {
            switch self {
            case .hamlet: return "hamlet"
            case .barrow: return "barrow"
            }
        }
    }

    public let id: Int
    public let kind: Kind
    public let position: Hex
    public let name: String

    public init(id: Int, kind: Kind, position: Hex, name: String) {
        self.id = id
        self.kind = kind
        self.position = position
        self.name = name
    }

    /// As a line names it: "the hamlet of Reedholt", "the Grey Howe".
    public var named: String {
        switch kind {
        case .hamlet: return "the hamlet of \(name)"
        case .barrow: return name
        }
    }

    /// The names hamlets take, a head and a tail.
    static let hamletHeads = [
        "Ash", "Reed", "Thorn", "Wych", "Mire", "Salt", "Cold", "Fern", "Sallow", "Brack",
        "Owl", "Moss", "Grey", "Hollin", "Rush", "Burr", "Sedge", "Heron", "Rook", "Fallow",
        "Hazel", "Tarn", "Crane", "Withy", "Bramble", "Nettle", "Lark", "Teasel", "Elder", "Marsh",
    ]
    static let hamletTails = [
        "by", "holt", "combe", "ley", "thorpe", "worth", "hope", "den", "hurst", "well",
        "cote", "field", "end", "hithe", "garth", "stow", "wold", "brook", "toft", "ings",
    ]
    /// The names barrows take: an old word for what lies in each.
    static let barrowNames = [
        "the Grey Howe", "the Long Barrow", "the Sleeper's Howe", "the Hollow Hill", "the Nine Stones",
        "the Old Howe", "the Moonward Howe", "the Barrow of Bones", "the Quiet Mound", "the Lantern Howe",
        "the Drowned King's Howe", "the Ravens' Mound", "the Salt Howe", "the Thorn Barrow", "the Weeping Howe",
        "the Elder Mound", "the Black Howe", "the Shield Barrow", "the Mere Howe", "the Last Howe",
        "the Whispering Mound", "the Twin Howes", "the Cairn of Ashes", "the Hound's Howe",
    ]
}

extension GameState {
    /// The fewest tiles from any seat, and from any hold, a find lies, and
    /// from another find.
    public static let findsFromHolds = 4
    public static let findsApart = 4
    /// How far about a hamlet its folk tell a House's Lanterns of the land.
    public static let hamletTells = 3
    /// How near a find a House's Lantern must stand to seek it: on it or
    /// beside it.
    public static let seekReach = 1

    /// Every find of the land, whether or not a hold stands over it.
    public var findsInLand: [Find] { finds ?? [] }

    /// The find at a hex, if one lies there and no hold stands over it.
    public func find(at hex: Hex) -> Find? {
        guard let find = finds?.first(where: { $0.position == hex }), hold(at: hex) == nil else { return nil }
        return find
    }

    /// The find by its number, if no hold stands over it.
    public func find(_ id: Int) -> Find? {
        guard let find = finds?.first(where: { $0.id == id }), hold(at: find.position) == nil else { return nil }
        return find
    }

    /// Whether a House has sought a find already.
    public func hasSought(_ find: Int, by house: Int) -> Bool {
        sought?[house].map { GameState.sortedContains($0, find) } ?? false
    }

    /// The finds a House knows of, nearest `hex` first, whether it has
    /// sought them or not.
    public func findsKnown(by house: Int, near hex: Hex? = nil) -> [Find] {
        let known = findsInLand.filter { isExplored($0.position, by: house) && hold(at: $0.position) == nil }
        guard let hex else { return known }
        return known.sorted { ($0.position.distance(to: hex), $0.id) < ($1.position.distance(to: hex), $1.id) }
    }

    /// The hamlet or barrow a company stands on or beside that its House
    /// knows of and has yet to seek, the nearest first: the one its
    /// Lanterns would seek (`seek`), whether the rules let them now or not.
    public func findToSeek(by unit: Unit, as house: Int) -> Find? {
        findsKnown(by: house, near: unit.position).first { find in
            find.position.distance(to: unit.position) <= GameState.seekReach && !hasSought(find.id, by: house)
        }
    }

    /// The land's hamlets and barrows, found as the world is made: a barrow
    /// for each seat out on the barrows' ground, and three hamlets for every
    /// two seats on the open land, two of each at least; away from every
    /// hold and from each other. Drawn apart from the world's other draws,
    /// and numbered apart, so the world is otherwise as it was.
    mutating func raiseFinds() {
        guard finds == nil else { return }
        var random = SeededRandom(seed: Seed.mix(settings.seed, 950))
        var blocked = Set<Hex>()
        for hold in holds {
            blocked.formUnion(hold.position.spiral(GameState.findsFromHolds - 1))
        }
        func open(_ hex: Hex) -> Bool {
            guard !blocked.contains(hex), let tile = map[hex], tile.terrain.isPassable, !tile.terrain.isWater,
                  tile.feature == nil else { return false }
            return unit(at: hex) == nil && lair(at: hex) == nil && shrine(at: hex) == nil && site(at: hex) == nil
        }
        var ground = map.hexes.filter(open)
        random.shuffle(&ground)
        var raised: [Find] = []
        var names = Set<String>()
        func raise(_ kind: Find.Kind, wanted: Int, on terrain: (Terrain) -> Bool) {
            var count = 0
            for hex in ground where count < wanted {
                guard !blocked.contains(hex), let tile = map[hex], terrain(tile.terrain) else { continue }
                let name = kind == .hamlet ? hamletName(using: &random, avoiding: names) : barrowName(using: &random, avoiding: names)
                names.insert(name)
                raised.append(Find(id: raised.count + 1, kind: kind, position: hex, name: name))
                blocked.formUnion(hex.spiral(GameState.findsApart - 1))
                count += 1
            }
        }
        raise(.barrow, wanted: max(2, houses.count), on: { $0 == .barrow })
        raise(.hamlet, wanted: max(2, houses.count * 3 / 2), on: { [.greyfield, .strand, .blackwood].contains($0) })
        finds = raised
    }

    private func hamletName(using random: inout SeededRandom, avoiding used: Set<String>) -> String {
        for _ in 0..<32 {
            let name = random.pick(Find.hamletHeads) + random.pick(Find.hamletTails)
            if !used.contains(name) { return name }
        }
        let base = random.pick(Find.hamletHeads) + random.pick(Find.hamletTails)
        var suffix = 2
        while used.contains("Upper \(base)") || used.contains("\(base) \(suffix)") { suffix += 1 }
        return used.contains("Upper \(base)") ? "\(base) \(suffix)" : "Upper \(base)"
    }

    private func barrowName(using random: inout SeededRandom, avoiding used: Set<String>) -> String {
        let free = Find.barrowNames.filter { !used.contains($0) }
        if !free.isEmpty { return random.pick(free) }
        let base = random.pick(Find.barrowNames)
        var suffix = 2
        while used.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    /// What a hamlet's folk give a House's Lanterns: of what their ground
    /// grows, and a little of another store, the more the further they
    /// live from every seat. The same for the same House, however asked.
    public func gift(of find: Find, to house: Int) -> Stock {
        guard find.kind == .hamlet else { return .zero }
        var random = SeededRandom(seed: Seed.mix(settings.seed, 951, UInt64(find.id), UInt64(max(house, 0))))
        let far = holds.filter(\.isSeat).map { $0.position.distance(to: find.position) }.min() ?? 0
        let amount = 60 + 5 * min(far, 12) + 10 * random.int(below: 4)
        let grows = map[find.position].flatMap { Site.store(of: $0.terrain) } ?? .grain
        let others = Resource.allCases.filter { $0 != grows && $0 != .moonsalt }
        let besides = random.pick(others.isEmpty ? [Resource.grain] : others)
        var gift = Stock.zero
        gift[grows] += grows == .moonsalt ? amount / 4 : amount
        gift[besides] += amount / 2
        return gift
    }

    /// What a House's Lanterns bring up out of a barrow: one of the old
    /// things laid with the dead. The same for the same House, however
    /// asked.
    public func graveGoods(of find: Find, for house: Int) -> ItemKind? {
        guard find.kind == .barrow else { return nil }
        var random = SeededRandom(seed: Seed.mix(settings.seed, 952, UInt64(find.id), UInt64(max(house, 0))))
        let roll = random.int(below: 20)
        switch roll {
        case 0..<5: return .hourglass
        case 5..<8: return .wardStone
        case 8..<11: return .mendingDraught
        case 11..<14: return .stoneCache
        case 14..<16: return .moonsaltCache
        case 16..<18: return .timberCache
        default: return .grainCache
        }
    }

    /// Why a House's company may not seek a find, or nil if it may.
    public func seekRefusal(_ unitID: Int, find findID: Int, as house: Int) -> RuleError? {
        guard let unit = unit(unitID) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard unit.kind == .lantern else { return .notAScout }
        guard let find = find(findID), isExplored(find.position, by: house) else { return .unknownFind }
        guard !hasSought(findID, by: house) else { return .soughtAlready }
        guard unit.position.distance(to: find.position) <= GameState.seekReach else { return .outOfReach }
        guard unit.movesLeft > 0 else { return .noMovesLeft }
        return nil
    }

    /// A House's Lanterns on or beside a find seek it, for all their
    /// moves: a hamlet's folk give them what they can spare and tell them
    /// of the land about, a barrow gives up its grave goods. Only their own
    /// House is told.
    mutating func seek(_ findID: Int, with unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = seekRefusal(unitID, find: findID, as: house) { throw refusal }
        guard let index = unitIndex(unitID), let find = find(findID) else { throw .unknownFind }
        units[index].movesLeft = 0
        units[index].acted = true
        units[index].destination = nil
        var book = sought ?? [:]
        var list = book[house] ?? []
        list.append(findID)
        list.sort()
        book[house] = list
        sought = book
        let gift = gift(of: find, to: house)
        let goods = graveGoods(of: find, for: house)
        if find.kind == .hamlet {
            store(gift, for: house)
            reveal(around: find.position, range: GameState.hamletTells, for: house)
            record(.discovery, [house], "\(houses[house].title)'s Lanterns come to \(find.named), whose folk give them \(gift).")
        } else if let goods {
            record(.discovery, [house], "\(houses[house].title)'s Lanterns go down into \(find.named) and bring up \(goods.counted(1)).")
        }
        var events: [GameEvent] = [.findSought(find: findID, by: house, gift: gift, item: goods)]
        if let goods { events += give(goods, to: house) }
        return events
    }
}

extension Voicing {
    /// The eldest of a hamlet's folk, speaking to the keeper's Lanterns who
    /// sought them out.
    public static let hamletTask = "Speak as the eldest of the hamlet's folk, to the keeper's Lanterns who have come to them: a plain welcome, "
        + "naming what the folk gave them and what stands about their land, keeping every name and number as given. "
        + "One or two sentences, at most 40 words."

    /// The words cut at a barrow's mouth, as the keeper's Lanterns read them
    /// going down among its dead.
    public static let barrowTask = "Give the words cut on the stones at the mouth of this barrow, as the keeper's Lanterns read them going down "
        + "among its dead: old and plain, naming what was laid with them, keeping every name as given. One or two lines, at most 30 words."
}

extension GameState {
    /// What the chronicle keeps of a House's Lanterns seeking a hamlet or a
    /// barrow: the entry the realm wrote as they sought it, with what the
    /// folk gave them or what the barrow gave up. Nil while that House
    /// hasn't sought it, or where nothing came of it to be written.
    public func discovery(of find: Find, by house: Int) -> ChronicleEntry? {
        guard houses.indices.contains(house), hasSought(find.id, by: house) else { return nil }
        let opening = find.kind == .hamlet ? "\(houses[house].title)'s Lanterns come to \(find.named),"
            : "\(houses[house].title)'s Lanterns go down into \(find.named) and"
        return chronicle.last { $0.kind == .discovery && $0.houses == [house] && $0.text.hasPrefix(opening) }
    }

    /// A hamlet's folk, or a barrow's stones, for the device's model to give
    /// words to once the House's Lanterns have sought it: what the realm's
    /// chronicle says came of it, where it lies, and for a hamlet the holds
    /// that stand within the reach of what its folk told them.
    public func voiced(_ find: Find, by house: Int) -> Voicing.Moment? {
        guard let entry = discovery(of: find, by: house) else { return nil }
        var facts = [entry.text, "\(find.named.lineBegun) lies \(placeName(of: find.position))."]
        if find.kind == .hamlet {
            let near = holds.filter { $0.position.distance(to: find.position) <= GameState.hamletTells }
                .sorted { ($0.position.distance(to: find.position), $0.id) < ($1.position.distance(to: find.position), $1.id) }
            if near.isEmpty {
                facts.append("No hold stands within \(GameState.hamletTells) tiles of it.")
            } else {
                let named = near.prefix(3).map { hold in
                    houses.indices.contains(hold.owner) ? "\(hold.name), a hold of \(houses[hold.owner].title)" : hold.name
                }
                facts.append("Within \(GameState.hamletTells) tiles of it stand\(near.count == 1 ? "s" : "") \(listed(named)).")
            }
        }
        return Voicing.Moment(task: find.kind == .hamlet ? Voicing.hamletTask : Voicing.barrowTask, facts: facts)
    }
}

extension GameState {
    /// The world as it would stand had the House's Lanterns sought `find`
    /// this watch: one of them beside it, fresh (one mustered there if the
    /// House has none), and the find sought as the rules seek it, gift,
    /// goods and the chronicle's line and all. For the Mac's voice check,
    /// which asks the on-device model for a hamlet's folk's words or a
    /// barrow's where none has been sought yet. The world as it was for no
    /// House of the realm, a find a hold stands over, or one with no open
    /// ground beside it.
    public func seeking(_ find: Find, by house: Int) -> GameState {
        var world = self
        guard houses.indices.contains(house), self.find(find.id) != nil else { return world }
        guard let lantern = world.units(of: house).first(where: { $0.kind == .lantern })?.id
                ?? world.placeUnit(.lantern, for: house, near: find.position)?.id,
              let index = world.unitIndex(lantern) else { return world }
        func open(_ hex: Hex) -> Bool {
            world.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && world.hold(at: hex) == nil
                && (world.unit(at: hex) == nil || world.unit(at: hex)?.id == lantern)
        }
        guard let beside = find.position.neighbors.first(where: open) else { return world }
        world.units[index].position = beside
        world.units[index].movesLeft = max(world.units[index].movesLeft, 1)
        world.refreshSight()
        _ = try? world.perform(.seek(unit: lantern, find: find.id), as: house)
        return world
    }
}
