/// The lake's Monument (after Rise of Kingdoms' kingdom monument): one
/// stone at a time raised by every House of the realm together. Each stone
/// is a deed of the whole lake (so many works raised, companies mustered,
/// companies of the wilds struck down, stores brought home, grades of study
/// learned), counted by the realm as each House does its part; when the
/// last of it is done the stone is set as the watch turns, every standing
/// House given its gift and those that did their part a share of moonsalt
/// by what they did; and the next stone is begun. Seen by all.
public enum MonumentStone: Int, Codable, CaseIterable, Sendable {
    case foundations, musters, hunts, harvest, learning, towers, hosts, greatHunt, granaries, wisdom

    /// What the lake must do together, and how much of it.
    public var deed: LabourKind {
        switch self {
        case .foundations, .towers: return .raise
        case .musters, .hosts: return .muster
        case .hunts, .greatHunt: return .hunt
        case .harvest, .granaries: return .gather
        case .learning, .wisdom: return .study
        }
    }

    public var measure: Int {
        switch self {
        case .foundations: return 24
        case .musters: return 30
        case .hunts: return 30
        case .harvest: return 9_000
        case .learning: return 30
        case .towers: return 80
        case .hosts: return 90
        case .greatHunt: return 100
        case .granaries: return 40_000
        case .wisdom: return 90
        }
    }

    public var title: String {
        switch self {
        case .foundations: return "The Foundations: works raised round the lake"
        case .musters: return "The First Musters: companies mustered"
        case .hunts: return "The Clearing: companies of the wilds struck down"
        case .harvest: return "The Harvest: stores brought home from the land"
        case .learning: return "The Learning: grades of study learned"
        case .towers: return "The Towers: works raised round the lake"
        case .hosts: return "The Hosts: companies mustered"
        case .greatHunt: return "The Great Hunt: companies of the wilds struck down"
        case .granaries: return "The Granaries: stores brought home from the land"
        case .wisdom: return "The Wisdom of the Lake: grades of study learned"
        }
    }

    /// What every standing House is given when the stone is set.
    public var gift: (stock: Stock, items: [ItemKind]) {
        let grade = rawValue / 5 + 1
        switch self.deed {
        case .raise: return (Stock(timber: 150 * grade, stone: 150 * grade), [.hourglass])
        case .muster: return (Stock(grain: 200 * grade), [.mendingDraught])
        case .hunt: return (Stock(grain: 100 * grade, timber: 100 * grade), [.wardStone])
        case .gather: return (Stock(grain: 120 * grade, timber: 120 * grade, stone: 120 * grade), [.hourglass])
        case .study: return (Stock(moonsalt: 6 * grade), [.hourglass, .hourglass])
        }
    }

    /// Moonsalt shared among the Houses that did their part, by their part.
    public var share: Int { 40 * (rawValue / 5 + 1) }
}

/// The Monument as it stands: the stones set, the one being raised, and
/// each House's part in it.
public struct Monument: Codable, Equatable, Sendable {
    /// Stones set so far, in order.
    public internal(set) var set: Int
    /// How much of the stone being raised is done.
    public internal(set) var done: Int
    /// Each House's part in it.
    public internal(set) var parts: [Int: Int]

    /// The stone being raised; nil once every stone is set.
    public var raising: MonumentStone? { MonumentStone(rawValue: set) }
    public var isWhole: Bool { raising == nil }
}

extension GameState {
    /// The lake's Monument as it stands, begun at the first watch.
    public var lakeMonument: Monument { monument ?? Monument(set: 0, done: 0, parts: [:]) }

    /// What a House did toward the stone being raised.
    public func monumentPart(of house: Int) -> Int { lakeMonument.parts[house] ?? 0 }

    /// What the lake does counts toward the stone being raised.
    mutating func countMonument(_ events: [GameEvent]) {
        var monument = lakeMonument
        guard let stone = monument.raising, !events.isEmpty else { return }
        var changed = false
        for event in events {
            guard let share = stone.deed.share(of: event, in: self), share.amount > 0, houses.indices.contains(share.house) else { continue }
            monument.done += share.amount
            monument.parts[share.house, default: 0] += share.amount
            changed = true
        }
        if changed { self.monument = monument }
    }

    /// As the watch turns: a stone whose deed is done is set, every
    /// standing House given its gift and each that did its part a share of
    /// moonsalt by that part; and the next is begun.
    mutating func setMonumentStone() -> [GameEvent] {
        var monument = lakeMonument
        guard let stone = monument.raising, monument.done >= stone.measure else { return [] }
        var events: [GameEvent] = [.monumentStoneSet(stone: stone)]
        let total = max(monument.parts.values.reduce(0, +), 1)
        for house in houses.indices where !houses[house].isEliminated {
            store(stone.gift.stock, for: house)
            events += give(stone.gift.items, to: house)
            if let part = monument.parts[house], part > 0 {
                let share = max(1, stone.share * part / total)
                store(Stock(moonsalt: share), for: house)
            }
        }
        monument = Monument(set: monument.set + 1, done: 0, parts: [:])
        self.monument = monument
        return events
    }
}
