/// The Lantern Inn (after Rise of Kingdoms' tavern): where the lake's
/// sell-swords and storytellers drink, a keeper opens chests with keys.
/// A silver key comes each watch, a gold one every few; a gold chest may
/// also be opened for moonsalt. Silver chests hold sculptures and the
/// lesser items; gold chests more sculptures, the greater items, and now
/// and then a commander who comes to the House, surely by the tenth gold
/// chest since the last. The realm draws every chest, from its seed.
public enum InnChest: String, Codable, CaseIterable, Sendable, PlainCases {
    case silver, gold

    public var named: String { self == .silver ? "silver" : "gold" }
}

/// What a chest held.
public enum InnDraw: Codable, Equatable, Sendable {
    case sculptures(Int)
    case item(ItemKind, Int)
    case commander(Int)
}

/// A keeper's House's keys at the Inn.
public struct InnKeys: Codable, Equatable, Sendable {
    public internal(set) var silver: Int
    public internal(set) var gold: Int
    /// Gold chests opened since the last that held a commander.
    public internal(set) var sinceCommander: Int
    /// Chests of each kind opened, for the draw.
    public internal(set) var opened: Int

    /// The most keys of a kind kept; more are lost.
    public static let mostKeys = 5
    /// A gold key comes each this many watches.
    public static let goldEvery = 6
    /// What a gold chest costs without a key.
    public static let goldPrice = Stock(moonsalt: 25)
    /// The gold chest that surely holds a commander, counting since the last.
    public static let surelyBy = 10
    /// In a hundred, how often a gold chest holds a commander.
    public static let commanderChance = 12
}

extension GameState {
    /// A House's keys at the Inn, if it has been.
    public func innKeys(of house: Int) -> InnKeys {
        innBook?[house] ?? InnKeys(silver: 0, gold: 0, sinceCommander: 0, opened: 0)
    }

    /// Why a House can't open a chest now, if it can't.
    public func innRefusal(_ chest: InnChest, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notYours }
        let keys = innKeys(of: house)
        switch chest {
        case .silver:
            return keys.silver > 0 ? nil : .noInnKey(.silver)
        case .gold:
            if keys.gold > 0 { return nil }
            let price = InnKeys.goldPrice
            return houses[house].stock.covers(price) ? nil : .shortOf(houses[house].stock.shortfall(for: price))
        }
    }

    /// What a chest holds: the same for the same realm, House and count.
    func innDraw(_ chest: InnChest, for house: Int, keys: InnKeys) -> InnDraw {
        var random = SeededRandom(seed: Seed.mix(settings.seed, 7_700, UInt64(house), UInt64(keys.opened), chest == .gold ? 1 : 0))
        let roll = random.int(below: 100)
        switch chest {
        case .silver:
            if roll < 55 { return .sculptures(1) }
            if roll < 70 { return .sculptures(2) }
            return .item(random.pick([.hourglass, .grainCache, .timberCache, .stoneCache]), 1)
        case .gold:
            let room = commanders(of: house).count < GameState.rosterLimit
            if room, keys.sinceCommander + 1 >= InnKeys.surelyBy || roll < InnKeys.commanderChance { return .commander(0) }
            if roll < 70 { return .sculptures(3 + random.int(below: 3)) }
            return .item(random.pick([.wardStone, .mendingDraught, .moonsaltCache, .hourglass]), 2)
        }
    }

    /// A House opens a chest at the Inn with its key, or a gold one for
    /// moonsalt; what it holds is the House's.
    mutating func openInnChest(_ chest: InnChest, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = innRefusal(chest, as: house) { throw refusal }
        var keys = innKeys(of: house)
        switch chest {
        case .silver: keys.silver -= 1
        case .gold:
            if keys.gold > 0 { keys.gold -= 1 } else { houses[house].stock.debit(InnKeys.goldPrice) }
        }
        var draw = innDraw(chest, for: house, keys: keys)
        keys.opened += 1
        var events: [GameEvent] = []
        switch draw {
        case .sculptures(let count):
            events += giveSculptures(count, to: house)
        case .item(let kind, let count):
            events += give(kind, count, to: house)
        case .commander:
            var random = SeededRandom(seed: Seed.mix(settings.seed, 7_701, UInt64(house), UInt64(keys.opened)))
            if let joined = raiseCommander(for: house, using: &random) {
                record(.commander, [house], "\(joined.name), \(joined.archetype.named), comes from the Lantern Inn to \(houses[house].title).")
                events.append(.commanderJoined(commander: joined.id, house: house))
                draw = .commander(joined.id)
            }
        }
        if chest == .gold {
            if case .commander = draw { keys.sinceCommander = 0 } else { keys.sinceCommander += 1 }
        }
        var book = innBook ?? [:]
        book[house] = keys
        innBook = book
        return [.innChestOpened(house: house, chest: chest, drew: draw)] + events
    }

    /// As the watch turns: a silver key to every keeper's House, and a gold
    /// one each few watches; no more than five of either kept.
    mutating func turnInn() {
        var book = innBook ?? [:]
        for house in houses.indices where houses[house].isPlayer && !houses[house].isEliminated {
            var keys = innKeys(of: house)
            keys.silver = min(InnKeys.mostKeys, keys.silver + 1)
            if (watch + house) % InnKeys.goldEvery == 0 { keys.gold = min(InnKeys.mostKeys, keys.gold + 1) }
            book[house] = keys
        }
        innBook = book.isEmpty ? nil : book
    }
}
