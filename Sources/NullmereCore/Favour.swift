/// A keeper's favour with the lake: earned each watch they keep in the
/// realm, the more for every watch kept unbroken before it, and kept
/// across ages. It raises the House they hold by levels, I to X: more
/// gathered at the land's sites, works and studies sooner, companies
/// mustered sooner; and every tenth watch kept unbroken brings its House a
/// chest of items, the richer the higher it stands.
public enum Favour {
    /// The favour each level asks, in all, from the first to the tenth.
    public static let levels = [60, 180, 400, 750, 1250, 2000, 3000, 4500, 6500, 9000]
    /// Favour for a watch kept.
    public static let perWatch = 10
    /// The more for each watch kept unbroken before it, up to `streakMost`.
    public static let perStreak = 2
    public static let streakMost = 10
    /// Every so many watches kept unbroken, a favour chest.
    public static let chestEvery = 10

    /// The highest level.
    public static var highest: Int { levels.count }

    /// The level so much favour stands at: 0 below the first.
    public static func level(of favour: Int) -> Int {
        levels.lastIndex { favour >= $0 }.map { $0 + 1 } ?? 0
    }

    /// The favour the next level asks, if there is one.
    public static func next(after favour: Int) -> Int? {
        levels.first { favour < $0 }
    }

    /// The favour a watch kept earns, after so many kept unbroken.
    public static func earned(streak: Int) -> Int {
        perWatch + perStreak * min(max(streak, 0), streakMost)
    }

    /// What a level gives its House, in percent: two more gathered and
    /// two sooner for works and studies a level, one sooner for musters.
    public static func bonus(_ bonus: Bonus, level: Int) -> Int {
        switch bonus {
        case .gathering, .buildSpeed, .studySpeed: return 2 * level
        case .trainingSpeed: return level
        default: return 0
        }
    }

    /// What a level gives, in words.
    public static func effect(level: Int) -> String {
        guard level > 0 else { return "nothing yet" }
        return "\(2 * level)% more gathered, works and studies \(2 * level)% sooner, companies mustered \(level)% sooner"
    }

    /// What a favour chest holds at a level: a Salt Hourglass; from the
    /// fourth, caches of grain and timber; from the seventh, a cache of
    /// stone and a Mending Draught; at the tenth, a Ward Stone and a cache
    /// of moonsalt.
    public static func chest(level: Int) -> [(kind: ItemKind, count: Int)] {
        guard level > 0 else { return [] }
        var items: [(kind: ItemKind, count: Int)] = [(.hourglass, 1)]
        if level >= 4 { items += [(.grainCache, 1), (.timberCache, 1)] }
        if level >= 7 { items += [(.stoneCache, 1), (.mendingDraught, 1)] }
        if level >= highest { items += [(.wardStone, 1), (.moonsaltCache, 1)] }
        return items
    }
}

extension GameState {
    /// The favour level a House stands at: its keeper's; none for a
    /// steward's.
    public func favour(of house: Int) -> Int {
        houses.indices.contains(house) ? houses[house].favour ?? 0 : 0
    }

    /// A House stands as high as its keeper's favour: told when it rises,
    /// and its favour chest given when one is due.
    mutating func standInFavour(_ house: Int, level: Int, chest: Bool) -> [GameEvent] {
        guard houses.indices.contains(house), !houses[house].isEliminated else { return [] }
        let before = favour(of: house)
        houses[house].favour = level > 0 ? level : nil
        var events: [GameEvent] = level > before ? [.favourRose(house: house, level: level)] : []
        if chest {
            for item in Favour.chest(level: level) {
                events += give(item.kind, item.count, to: house)
            }
        }
        return events
    }
}

extension RealmState {
    /// As the watch turns, each keeper there keeps it: their favour grows,
    /// the more for every watch they kept unbroken before it; a keeper away
    /// breaks their streak. Their House stands as high as their favour, and
    /// every tenth watch kept unbroken brings it a favour chest.
    mutating func keepFavour() -> [GameEvent] {
        var events: [GameEvent] = []
        for index in keepers.indices {
            guard keepers[index].isOnline else {
                keepers[index].streak = nil
                continue
            }
            let streak = keepers[index].streak ?? 0
            let favour = (keepers[index].favour ?? 0) + Favour.earned(streak: streak)
            keepers[index].favour = favour
            keepers[index].streak = streak + 1
            if let house = keepers[index].house {
                events += world.standInFavour(house, level: Favour.level(of: favour), chest: (streak + 1) % Favour.chestEvery == 0)
            }
        }
        return events
    }

    /// A House taken up by a keeper stands as high as their favour.
    mutating func seatInFavour(_ index: Int) {
        guard let house = keepers[index].house, world.houses.indices.contains(house) else { return }
        let level = Favour.level(of: keepers[index].favour ?? 0)
        world.houses[house].favour = level > 0 ? level : nil
    }
}
