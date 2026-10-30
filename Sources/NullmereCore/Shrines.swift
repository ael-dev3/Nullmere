/// The kind of a holy site of the lake, and what it gives the side that holds it.
public enum ShrineKind: String, CaseIterable, Codable, Sendable {
    /// A well that holds the moon: the blows of its holders' companies fall harder.
    case moonwell
    /// A stone that never stirs in the wind: its holders' companies stand firmer.
    case stillStone
    /// An altar of moonsalt: its holders gather more from the land's sites.
    case saltAltar

    public var title: String {
        switch self {
        case .moonwell: return "Moonwell"
        case .stillStone: return "Still Stone"
        case .saltAltar: return "Salt Altar"
        }
    }

    /// What it gives its holders, in a line.
    public var effect: String {
        switch self {
        case .moonwell: return "+8% attack to every company of its holders' side"
        case .stillStone: return "+8% defence to every company of its holders' side"
        case .saltAltar: return "+15% gathered at the land's sites by its holders' side"
        }
    }

    /// What it adds to a figure of its holders'.
    func bonus(_ bonus: Bonus) -> Int {
        switch (self, bonus) {
        case (.moonwell, .attack): return 8
        case (.stillStone, .defense): return 8
        case (.saltAltar, .gathering): return 15
        default: return 0
        }
    }
}

/// A holy site of the lake: held by the House whose company of war stands
/// on it as the watch turns, with no foe at war beside it; what it gives,
/// it gives that House and its alliance.
public struct Shrine: Codable, Equatable, Identifiable, Sendable {
    /// Its place among the realm's shrines, from one.
    public let id: Int
    public let kind: ShrineKind
    public let position: Hex
    /// The House that holds it, if any does.
    public internal(set) var holder: Int?
    /// The watch it was last taken.
    public internal(set) var since: Int?

    public init(id: Int, kind: ShrineKind, position: Hex, holder: Int? = nil, since: Int? = nil) {
        self.id = id
        self.kind = kind
        self.position = position
        self.holder = holder
        self.since = since
    }

    public var title: String { kind.title }
}

extension GameState {
    /// The fewest tiles from any hold a shrine lies.
    public static let shrinesFromHolds = 5
    /// The fewest tiles between two shrines.
    public static let shrinesApart = 7

    /// The realm's holy sites.
    public var holySites: [Shrine] { shrines ?? [] }

    /// The shrine at a hex, if one stands there.
    public func shrine(at hex: Hex) -> Shrine? {
        shrines?.first { $0.position == hex }
    }

    /// The realm's holy sites, found as the world is made: one for every
    /// two seats, two at least, on open land far from every hold and from
    /// each other, each kind in turn. Drawn apart from the world's other
    /// draws, and numbered apart, so the world is otherwise as it was.
    mutating func raiseShrines() {
        guard shrines == nil else { return }
        var random = SeededRandom(seed: Seed.mix(settings.seed, 900))
        let wanted = max(2, houses.count / 2)
        var open = map.hexes.filter { hex in
            guard let tile = map[hex], tile.terrain.isPassable, !tile.terrain.isWater, tile.feature == nil else { return false }
            return unit(at: hex) == nil && holds.allSatisfy { $0.position.distance(to: hex) >= GameState.shrinesFromHolds }
        }
        random.shuffle(&open)
        var raised: [Shrine] = []
        for hex in open where raised.count < wanted {
            guard raised.allSatisfy({ $0.position.distance(to: hex) >= GameState.shrinesApart }) else { continue }
            raised.append(Shrine(id: raised.count + 1, kind: ShrineKind.allCases[raised.count % ShrineKind.allCases.count], position: hex))
        }
        shrines = raised
    }

    /// What the shrines held by a House's side add to one of its figures.
    func shrineBonus(_ bonus: Bonus, for house: Int) -> Int {
        guard let shrines, !shrines.isEmpty else { return 0 }
        let side = Set([house] + (alliance(of: house)?.members ?? []))
        return shrines.reduce(0) { total, shrine in
            total + (shrine.holder.map(side.contains) == true ? shrine.kind.bonus(bonus) : 0)
        }
    }

    /// As the watch turns: a shrine whose holder has fallen is held by none;
    /// one with a company of war standing on it, and no foe at war with its
    /// House beside it, is taken by that House.
    mutating func holdShrines() -> [GameEvent] {
        guard var list = shrines else { return [] }
        var events: [GameEvent] = []
        for index in list.indices {
            let shrine = list[index]
            if let holder = shrine.holder, !houses.indices.contains(holder) || houses[holder].isEliminated {
                list[index].holder = nil
                list[index].since = nil
            }
            guard let keeper = units.first(where: { $0.position == shrine.position && $0.kind.isMilitary }),
                  list[index].holder != keeper.owner else { continue }
            let contested = units.contains { other in
                other.kind.isMilitary && other.position.distance(to: shrine.position) <= 1 && isAtWar(other.owner, keeper.owner)
            }
            guard !contested else { continue }
            // Heard by every House as it happens, and kept in the Realm's
            // list of holy sites; the chronicle, the age's story, is spared
            // a line for every company that stands on one.
            let from = list[index].holder
            list[index].holder = keeper.owner
            list[index].since = watch
            events.append(.shrineTaken(shrine: shrine.id, house: keeper.owner, from: from))
        }
        shrines = list
        return events
    }
}
