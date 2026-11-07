/// The lake's two shores, which stand as kingdoms in a Sundering.
public enum Shore: String, Codable, CaseIterable, Sendable, PlainCases {
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
    /// The Houses its war set at war that the realm keeps a relation for,
    /// each pair the lower id first: those at peace with one across the
    /// water as it began that had dealt before, and those kept since, as
    /// they deal. Laid down as it ends, those still fought. Every other
    /// two Houses it set at war, the most of them, the realm knows by
    /// `alliances` and `lieges`, not pair by pair: it is the kingdoms' war.
    public internal(set) var wars: [[Int]]?
    /// Each House's alliance as it began, and its liege: two Houses across
    /// the water sworn to one alliance, or one the other's liege, it did
    /// not set at war. Absent in a Sundering begun while the realm kept a
    /// relation for every two Houses, whose every war is among `wars`.
    public internal(set) var alliances: [Int?]?
    public internal(set) var lieges: [Int?]?
    /// The watch its wars were laid down, as it ended.
    public internal(set) var laidDown: Int?

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

    /// Whether it set two Houses at war that the realm kept no relation
    /// for as it began: across the water from each other, neither sworn
    /// to one alliance with the other nor its liege or vassal. Such two
    /// were at peace, as every two Houses are that have never dealt, or
    /// as an earlier Sundering left them.
    func setsAtWar(_ first: Int, _ second: Int) -> Bool {
        // Read where they lie, none of its lists copied out: asked of every
        // two Houses whenever the rules ask whether two are at war.
        guard first >= 0, second >= 0, let sworn = alliances?.count, let sworeFealty = lieges?.count,
              max(first, second) < min(shores.count, sworn, sworeFealty),
              let mine = shores[first], let theirs = shores[second], mine != theirs else { return false }
        if let alliance = alliances?[first] ?? nil, alliance == alliances?[second] ?? nil { return false }
        return (lieges?[first] ?? nil) != second && (lieges?[second] ?? nil) != first
    }

    /// Whether it holds two Houses the realm keeps no relation for at war
    /// now: it set them at war, and its war is not yet laid down.
    func holdsAtWar(_ first: Int, _ second: Int) -> Bool {
        laidDown == nil && setsAtWar(first, second)
    }

    /// Two Houses it set at war as it left them: at war since it began
    /// while it goes on, at peace from the watch it laid its wars down.
    func left(_ relation: Relation) -> Relation {
        var relation = relation
        relation.stance = laidDown == nil ? .war : .peace
        relation.since = laidDown ?? begins
        return relation
    }

    /// As it is kept once it is over, for the relations of the Houses it
    /// set at war: its points given and its wars laid down, neither is.
    var past: Sundering {
        var past = self
        past.points = []
        past.wars = nil
        return past
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
    /// Whether two Houses' war is the Sundering's and still under way: one
    /// it began and they have fought since, which neither may end before
    /// the Sundering does.
    public func isSunderingWar(_ a: Int, _ b: Int) -> Bool {
        guard let sundering, !sundering.settled, watch < sundering.ends, let wars = sundering.wars,
              let relation = relation(a, b), relation.stance == .war, relation.since == sundering.begins else { return false }
        // Kept, it is among its wars; not kept, it stands as the Sundering
        // set it, if the Sundering set it at all.
        let first = min(a, b), second = max(a, b)
        return relationIndex(first, second) == nil ? sundering.setsAtWar(first, second) : wars.contains([first, second])
    }

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
        guard unsundered != true else { return [] }
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
            // The wars it began, still fought, laid down: those kept pair by
            // pair here, and every other at once, as the kingdoms' war ends.
            for pair in sundering.wars ?? [] where pair.count == 2 {
                guard let index = relationIndex(pair[0], pair[1]), relations[index].stance == .war,
                      relations[index].since == sundering.begins else { continue }
                relations[index].stance = .peace
                relations[index].since = watch
            }
            sundering.settled = true
            if sundering.alliances != nil { sundering.laidDown = watch }
            self.sundering = sundering
        }
        if sundering?.settled != false, Sundering.begins(at: watch) {
            let shores = houses.map { house -> Shore? in
                guard !house.isEliminated, let seat = seat(of: house.id) else { return nil }
                return Shore.of(seat.position)
            }
            var begun = Sundering(begins: watch, shores: shores)
            // The shores take up arms: every House at peace with one across
            // the water, neither sworn to one alliance with it nor its liege
            // or vassal, is at war with it until the Sundering ends. Neither
            // declared it: it is the kingdoms' war, no House's grudge. Two
            // Houses that have dealt are set at war pair by pair; every
            // other two, the most of them, by the kingdoms' war itself, the
            // realm keeping no relation for them.
            var sworn = [Int?](repeating: nil, count: houses.count)
            for alliance in alliancesStanding {
                for member in alliance.members where sworn.indices.contains(member) && sworn[member] == nil { sworn[member] = alliance.id }
            }
            begun.alliances = sworn
            begun.lieges = houses.map(\.liege)
            var wars: [[Int]] = []
            for index in relations.indices {
                let first = relations[index].first, second = relations[index].second
                guard relations[index].stance == .peace, begun.setsAtWar(first, second) else { continue }
                relations[index].stance = .war
                relations[index].since = watch
                wars.append([first, second])
            }
            begun.wars = wars
            // The last, its war over, is kept for the Houses it left at peace.
            if let last = sundering, last.alliances != nil {
                sunderings = (sunderings ?? []) + [last.past]
            }
            sundering = begun
            record(.happening, [], "The Sundering begins: the Eastern and the Western Shore war as kingdoms until the "
                   + "\(ordinal(begun.ends)) watch.")
            events.append(.sunderingBegun(ends: begun.ends))
        }
        return events
    }
}
