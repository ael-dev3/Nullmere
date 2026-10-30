/// The lake's two shores, which stand as kingdoms in a Sundering.
public enum Shore: String, Codable, CaseIterable, Sendable {
    case eastern, western

    public var title: String {
        switch self {
        case .eastern: return "the Eastern Shore"
        case .western: return "the Western Shore"
        }
    }

    public var other: Shore { self == .eastern ? .western : .eastern }

    /// The shore a seat stands on: east of the lake's heart, or west (as a
    /// hex's centre lies, its x the q and half the r).
    public static func of(_ hex: Hex) -> Shore {
        2 * hex.q + hex.r >= 0 ? .eastern : .western
    }
}

/// The Sundering: kingdom against kingdom. Every so often the lake's Houses
/// stand for twelve watches as two kingdoms, the Eastern and the Western
/// Shore, each by where its seat stands as it begins. Troops of the other
/// shore slain, its holds taken and its alliances' works torn down count for
/// the striker's kingdom and House; when it ends, every House of the kingdom
/// with more shares its spoils, and its foremost House is hailed.
public struct Sundering: Codable, Equatable, Sendable {
    /// The watch it began.
    public let begins: Int
    /// The watch it ends, as that watch begins.
    public let ends: Int
    /// Each House's shore, by its id; none for a House fallen before it began.
    public let shores: [Shore?]
    /// Each House's points, by its id.
    public internal(set) var points: [Int]
    /// Whether it has ended and its spoils were given; it is kept, settled,
    /// until the next begins.
    public internal(set) var settled: Bool

    public init(begins: Int, shores: [Shore?]) {
        self.begins = begins
        self.ends = begins + Sundering.lasts
        self.shores = shores
        self.points = Array(repeating: 0, count: shores.count)
        self.settled = false
    }

    /// The first begins at this watch, and another every `every` after.
    public static let first = 55
    public static let every = 90
    public static let lasts = 12

    /// What every House of the kingdom that prevails is given.
    public static let spoils = Stock(grain: 150, timber: 150, stone: 150, moonsalt: 10)
    public static let spoilsItems: [ItemKind] = [.hourglass, .hourglass, .wardStone]
    /// What its foremost House is given besides.
    public static let hailed = Stock(grain: 100, timber: 100, stone: 100, moonsalt: 10)

    /// Whether a Sundering begins at a watch.
    public static func begins(at watch: Int) -> Bool {
        watch >= first && (watch - first) % every == 0
    }

    /// The first watch at or after `watch` a Sundering begins.
    public static func next(from watch: Int) -> Int {
        guard watch > first else { return first }
        return first + ((watch - first + every - 1) / every) * every
    }

    /// The shore a House stands with, if any.
    public func shore(of house: Int) -> Shore? {
        shores.indices.contains(house) ? shores[house] : nil
    }

    /// A kingdom's points: its Houses' together.
    public func score(of shore: Shore) -> Int {
        points.indices.reduce(0) { shores[$1] == shore ? $0 + points[$1] : $0 }
    }

    /// The kingdom ahead, if one is.
    public var leading: Shore? {
        let east = score(of: .eastern), west = score(of: .western)
        return east == west ? nil : (east > west ? .eastern : .western)
    }

    /// The foremost House of a kingdom, ties to the lower id; none with no points.
    public func foremost(of shore: Shore) -> Int? {
        points.indices.filter { shores[$0] == shore && points[$0] > 0 }.min { (-points[$0], $0) < (-points[$1], $1) }
    }

    /// The House a deed scores for, and how much, when it is done against
    /// a House of the other shore: troops slain, a company felled, a hold
    /// taken, an alliance's work torn down.
    func points(for event: GameEvent, in state: GameState) -> (house: Int, points: Int)? {
        func across(_ house: Int, _ other: Int?) -> Bool {
            guard let other, let mine = shore(of: house), let theirs = shore(of: other) else { return false }
            return mine != theirs
        }
        switch event {
        case .battle(let battle) where battle.defenderKind != nil && across(battle.attackerOwner, battle.defenderOwner):
            return (battle.attackerOwner, (battle.slain ?? 0) / 100 + (battle.defenderFell ? 5 : 0))
        case .holdCaptured(_, let from, let by) where across(by, from):
            return (by, 25)
        case .standardTorn(_, let alliance, let by?, _) where across(by, state.alliance(alliance)?.leader):
            return (by, 5)
        case .hallTorn(_, let alliance, let by?, _) where across(by, state.alliance(alliance)?.leader):
            return (by, 30)
        case .storehouseTorn(_, let alliance, let by?, _, _) where across(by, state.alliance(alliance)?.leader):
            return (by, 20)
        default:
            return nil
        }
    }
}

extension GameState {
    /// Points to the Sundering under way for what was done across the shores.
    mutating func tallySundering(_ events: [GameEvent]) {
        guard var sundering, !sundering.settled, watch < sundering.ends else { return }
        var changed = false
        for event in events {
            guard let (house, points) = sundering.points(for: event, in: self), points > 0,
                  sundering.points.indices.contains(house) else { continue }
            sundering.points[house] += points
            changed = true
        }
        if changed { self.sundering = sundering }
    }

    /// As the watch turns: a Sundering at its end ended, its kingdom that
    /// prevailed given its spoils and its foremost hailed; one due begun,
    /// every standing House to the shore its seat stands on.
    mutating func turnSundering() -> [GameEvent] {
        var events: [GameEvent] = []
        if var sundering, !sundering.settled, watch >= sundering.ends {
            let east = sundering.score(of: .eastern), west = sundering.score(of: .western)
            let winner = sundering.leading
            var given: [GameEvent] = []
            var hailed: Int?
            if let winner {
                for house in houses.indices where sundering.shore(of: house) == winner && !houses[house].isEliminated {
                    store(Sundering.spoils, for: house)
                    given += give(Sundering.spoilsItems, to: house)
                }
                hailed = sundering.foremost(of: winner).flatMap { houses[$0].isEliminated ? nil : $0 }
                if let hailed { store(Sundering.hailed, for: hailed) }
                let foremost = hailed.map { "; \(houses[$0].title) is hailed its sword" } ?? ""
                record(.happening, hailed.map { [$0] } ?? [],
                       "The Sundering ends: \(winner.title) prevails, \(max(east, west)) to \(min(east, west))\(foremost).")
            } else {
                record(.happening, [], "The Sundering ends with neither shore ahead, \(east) to \(west).")
            }
            events.append(.sunderingEnded(winner: winner, eastern: east, western: west, hailed: hailed))
            events += given
            sundering.settled = true
            self.sundering = sundering
        }
        if sundering?.settled != false, Sundering.begins(at: watch) {
            let shores = houses.map { house -> Shore? in
                guard !house.isEliminated, let seat = seat(of: house.id) else { return nil }
                return Shore.of(seat.position)
            }
            let begun = Sundering(begins: watch, shores: shores)
            sundering = begun
            record(.happening, [], "The Sundering begins: the Eastern and the Western Shore war as kingdoms until the "
                   + "\(ordinal(begun.ends)) watch.")
            events.append(.sunderingBegun(ends: begun.ends))
        }
        return events
    }
}
