import Foundation

/// What a happening of the realm sets every House striving at.
public enum HappeningKind: String, Codable, CaseIterable, Sendable {
    /// Companies of the wilds struck down, the greater the more.
    case longHunt
    /// Stores brought home from the sites of the land.
    case harvestFair
    /// Works raised, the higher the more.
    case raising
    /// Companies mustered, the higher their tier the more.
    case muster
    /// Grades of study learned.
    case learnedSeason

    public var title: String {
        switch self {
        case .longHunt: return "The Long Hunt"
        case .harvestFair: return "The Harvest Fair"
        case .raising: return "The Raising"
        case .muster: return "The Great Muster"
        case .learnedSeason: return "The Learned Season"
        }
    }

    /// What earns points, as the realm proclaims it.
    public var goal: String {
        switch self {
        case .longHunt: return "every company of the wilds struck down counts, the greater the more, and a lair broken for its rally's caller most of all"
        case .harvestFair: return "every store brought home from the sites of the land counts"
        case .raising: return "every work raised counts, the higher the more"
        case .muster: return "every company mustered counts, the higher its tier the more"
        case .learnedSeason: return "every grade of study learned counts"
        }
    }

    /// The House an event earns points for in a happening of this kind,
    /// and how many, read against the world after it.
    func points(for event: GameEvent, in state: GameState) -> (house: Int, points: Int)? {
        switch (self, event) {
        case (.longHunt, .hunted(let hunt)) where hunt.wildFell:
            return (hunt.attackerOwner, 2 * hunt.level)
        case (.longHunt, .lairAssaulted(let assault)) where assault.broken:
            return (assault.caller, 10 * assault.level)
        case (.harvestFair, .delivered(_, let owner, _, let load)):
            return (owner, (load.grain + load.timber + load.stone + 4 * load.moonsalt) / 20)
        case (.raising, .buildingCompleted(let holdID, _, let level)):
            return state.hold(holdID).map { ($0.owner, 2 * level) }
        case (.muster, .unitTrained(let unitID, _)):
            return state.unit(unitID).map { ($0.owner, 2 * $0.tier) }
        case (.learnedSeason, .studyCompleted(let house, _, let grade)):
            return (house, 3 + grade)
        default:
            return nil
        }
    }
}

/// A happening of the realm: for ten watches every House strives at one
/// thing and earns points by it. Each mark of points passed brings stores
/// at once; when it ends, the three foremost are honoured in the chronicle
/// and with stores. They come round on a fixed course from the tenth
/// watch, one every thirty, their kinds in an order the realm's seed sets.
public struct Happening: Codable, Equatable, Sendable {
    /// Its place in the age's course: the first is 0.
    public let number: Int
    public let kind: HappeningKind
    public let begins: Int
    /// The watch it ends, as that watch begins.
    public let ends: Int
    /// Each House's points, by its id.
    public internal(set) var points: [Int]
    /// How many marks each House has passed, by its id.
    public internal(set) var passed: [Int]

    public init(number: Int, kind: HappeningKind, begins: Int, houses: Int) {
        self.number = number
        self.kind = kind
        self.begins = begins
        self.ends = begins + Happening.lasts
        self.points = Array(repeating: 0, count: houses)
        self.passed = Array(repeating: 0, count: houses)
    }

    public static let first = 10
    public static let every = 30
    public static let lasts = 10
    /// The points at which a House is given stores.
    public static let marks = [10, 25, 50]
    /// What each mark brings.
    public static let markRewards = [
        Stock(grain: 30, timber: 30, stone: 0, moonsalt: 0),
        Stock(grain: 0, timber: 30, stone: 30, moonsalt: 2),
        Stock(grain: 40, timber: 0, stone: 40, moonsalt: 4),
    ]
    /// The items each mark brings beside its stores.
    public static let markItems: [[ItemKind]] = [
        [.hourglass],
        [.hourglass, .mendingDraught],
        [.hourglass, .hourglass, .wardStone],
    ]
    /// What the three foremost are given as it ends.
    public static let honours = [
        Stock(grain: 50, timber: 50, stone: 50, moonsalt: 6),
        Stock(grain: 35, timber: 35, stone: 35, moonsalt: 3),
        Stock(grain: 20, timber: 20, stone: 20, moonsalt: 0),
    ]
    /// The items the three foremost are given beside their stores.
    public static let honourItems: [[ItemKind]] = [
        [.hourglass, .hourglass, .hourglass, .wardStone],
        [.hourglass, .hourglass, .mendingDraught],
        [.hourglass],
    ]

    /// The happening that begins at a watch, by its number, if one does.
    public static func number(beginningAt watch: Int) -> Int? {
        guard watch >= first, (watch - first) % every == 0 else { return nil }
        return (watch - first) / every
    }

    /// The kind of an age's happening by its number: the kinds come round
    /// in turn, from one the seed chooses.
    public static func kind(number: Int, seed: UInt64) -> HappeningKind {
        let kinds = HappeningKind.allCases
        let start = Int(Seed.mix(seed, 0x4A99) % UInt64(kinds.count))
        return kinds[(start + number) % kinds.count]
    }

    /// The Houses with points, foremost first, ties to the lower id.
    public var leaderboard: [Int] {
        points.indices.filter { points[$0] > 0 }.sorted { (-points[$0], $0) < (-points[$1], $1) }
    }
}

extension GameState {
    /// Points to the happening under way for what was done.
    mutating func tally(_ events: [GameEvent]) {
        guard var happening, watch < happening.ends else { return }
        var changed = false
        for event in events {
            guard let (house, points) = happening.kind.points(for: event, in: self), points > 0,
                  happening.points.indices.contains(house) else { continue }
            happening.points[house] += points
            changed = true
        }
        if changed { self.happening = happening }
    }

    /// As the watch turns: marks passed rewarded, a happening at its end
    /// ended and its foremost honoured, and one due begun.
    mutating func turnHappenings() -> [GameEvent] {
        var events: [GameEvent] = []
        if var happening {
            for house in happening.points.indices where !houses[house].isEliminated {
                while happening.passed[house] < Happening.marks.count, happening.points[house] >= Happening.marks[happening.passed[house]] {
                    let reward = Happening.markRewards[happening.passed[house]]
                    let items = Happening.markItems[happening.passed[house]]
                    happening.passed[house] += 1
                    store(reward, for: house)
                    events.append(.happeningMark(house: house, kind: happening.kind, mark: happening.passed[house], reward: reward))
                    events += give(items, to: house)
                }
            }
            self.happening = happening
            if watch >= happening.ends {
                let leaders = Array(happening.leaderboard.filter { !houses[$0].isEliminated }.prefix(Happening.honours.count))
                var honoured: [GameEvent] = []
                for (place, house) in leaders.enumerated() {
                    store(Happening.honours[place], for: house)
                    honoured += give(Happening.honourItems[place], to: house)
                }
                let named = leaders.map { houses[$0].title }
                let text: String
                switch named.count {
                case 0: text = "\(happening.kind.title) ends with no House to honour."
                case 1: text = "\(happening.kind.title) ends: \(named[0]) takes the honours."
                case 2: text = "\(happening.kind.title) ends: \(named[0]) takes the honours, ahead of \(named[1])."
                default: text = "\(happening.kind.title) ends: \(named[0]) takes the honours, ahead of \(named[1]) and \(named[2])."
                }
                record(.happening, leaders, text)
                events.append(.happeningEnded(kind: happening.kind, leaders: leaders))
                events += honoured
                self.happening = nil
            }
        }
        if happening == nil, let number = Happening.number(beginningAt: watch) {
            let begun = Happening(number: number, kind: Happening.kind(number: number, seed: settings.seed), begins: watch, houses: houses.count)
            happening = begun
            record(.happening, [], "\(begun.kind.title) begins: \(begun.kind.goal), until the \(ordinal(begun.ends)) watch.")
            events.append(.happeningBegun(kind: begun.kind, ends: begun.ends))
        }
        return events
    }
}
