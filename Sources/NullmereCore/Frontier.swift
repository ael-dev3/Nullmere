/// The Frontier: the Lost Shore, a realm of its own where the kingdoms of
/// several realms meet. Its age is a season of `FrontierState.lasts`
/// watches; its seats are kept for keepers crossing from the realms that
/// border it, each seated as their home realm's kingdom and raised there
/// with a levy of the companies of war their House keeps at home. Troops
/// of another kingdom slain, its companies felled and its holds taken
/// count for the striker's kingdom and House; as the season ends the
/// kingdom that prevails, and every keeper's part in it, is told home, and
/// each realm gives its own keepers' Houses their spoils.
///
/// The realms never share a world: their stewards read each other's
/// status, as any keeper may. A home realm lists those crossing; the
/// Frontier seats no one it does not list, and tells its seasons' ends.

/// A company a House sends with its keeper to the Frontier.
public struct Levy: Codable, Equatable, Sendable {
    public let kind: UnitKind
    public let tier: Int
    /// The troops drilled into it beyond its first muster, if any: they
    /// cross with it.
    public let drilled: Int?

    public init(kind: UnitKind, tier: Int, drilled: Int? = nil) {
        self.kind = kind
        self.tier = tier
        self.drilled = drilled.flatMap { $0 > 0 ? $0 : nil }
    }
}

/// A keeper crossing to the Frontier, as their home realm tells it.
public struct Crossing: Codable, Equatable, Sendable {
    /// The identity they are known by, at home and at the Frontier alike.
    public let keeper: String
    public let name: String
    /// The realm they come from, whose kingdom they stand for.
    public let realm: String
    /// The season they cross for.
    public let season: Int
    public let heritage: Heritage?
    public let levy: [Levy]

    public init(keeper: String, name: String, realm: String, season: Int, heritage: Heritage?, levy: [Levy]) {
        self.keeper = keeper
        self.name = name
        self.realm = realm
        self.season = season
        self.heritage = heritage
        self.levy = levy
    }
}

/// How a kingdom stands at the Frontier: the realm it is, its points, and
/// how many of its keepers hold seats there.
public struct KingdomStanding: Codable, Equatable, Sendable {
    public let realm: String
    public let points: Int
    public let keepers: Int

    public init(realm: String, points: Int, keepers: Int) {
        self.realm = realm
        self.points = points
        self.keepers = keepers
    }
}

/// A keeper's part in a season at the Frontier.
public struct FrontierHonour: Codable, Equatable, Sendable {
    public let keeper: String
    public let realm: String
    public let points: Int

    public init(keeper: String, realm: String, points: Int) {
        self.keeper = keeper
        self.realm = realm
        self.points = points
    }
}

/// A season ended at the Frontier, as it is told home.
public struct FrontierResult: Codable, Equatable, Sendable {
    public let season: Int
    /// Best first.
    public let standings: [KingdomStanding]
    /// The realm whose kingdom prevailed; none when none led.
    public let prevailed: String?
    public let honours: [FrontierHonour]

    public init(season: Int, standings: [KingdomStanding], prevailed: String?, honours: [FrontierHonour]) {
        self.season = season
        self.standings = standings
        self.prevailed = prevailed
        self.honours = honours
    }
}

/// What a realm hears of the Frontier it borders, and what the Frontier
/// tells of itself.
public struct FrontierNews: Codable, Equatable, Sendable {
    /// Where its keepers cross to: the Frontier's address, as the realm's
    /// steward reads it there; the Frontier itself leaves it empty.
    public var address: String
    public let season: Int
    public let watch: Int
    /// The watch the season ends.
    public let lasts: Int
    /// Whether keepers may cross for this season.
    public let open: Bool
    /// Best first.
    public let standings: [KingdomStanding]
    /// The season before, ended.
    public let last: FrontierResult?

    public init(address: String, season: Int, watch: Int, lasts: Int, open: Bool, standings: [KingdomStanding], last: FrontierResult?) {
        self.address = address
        self.season = season
        self.watch = watch
        self.lasts = lasts
        self.open = open
        self.standings = standings
        self.last = last
    }
}

/// What happens to a keeper's House about the Frontier.
public enum FrontierTiding: Codable, Equatable, Sendable {
    /// Its keeper crosses to the Frontier for a season, with a levy of so
    /// many companies.
    case crossed(house: Int, season: Int, levy: Int)
    /// At the Frontier: raised there for its home realm's kingdom.
    case raised(house: Int, realm: String, levy: Int)
    /// At home: a season's end told, how its kingdom fared, its keeper's
    /// part, and whether it was given its kingdom's spoils.
    case toldHome(house: Int, season: Int, prevailed: String?, points: Int, won: Bool)
}

/// The Frontier's own reckoning, kept by a realm that is one.
public struct FrontierState: Codable, Equatable, Sendable {
    /// The season: one an age.
    public internal(set) var season: Int
    /// Who may take a seat, by identity: as the realms it borders list them.
    public internal(set) var admitted: [String: Crossing]
    /// Each House's kingdom, by its id: the realm its keeper came from.
    public internal(set) var kingdoms: [String?]
    /// Each House's points, by its id.
    public internal(set) var points: [Int]
    /// The season before, ended.
    public internal(set) var last: FrontierResult?

    /// A season lasts this many watches.
    public static let lasts = 24
    /// The most companies a House sends.
    public static let levyMost = 6
    /// What a House of the kingdom that prevailed is given at home.
    public static let spoils = Stock(grain: 300, timber: 300, stone: 300, moonsalt: 20)
    public static let spoilsItems: [ItemKind] = [.hourglass, .hourglass, .wardStone, .mendingDraught]
    /// What a House whose keeper scored for a kingdom that didn't prevail is given.
    public static let share = Stock(grain: 100, timber: 100, stone: 100, moonsalt: 5)

    init(season: Int, houses: Int) {
        self.season = season
        admitted = [:]
        kingdoms = Array(repeating: nil, count: houses)
        points = Array(repeating: 0, count: houses)
        last = nil
    }

    /// A House's kingdom, if it stands for one.
    public func kingdom(of house: Int) -> String? {
        kingdoms.indices.contains(house) ? kingdoms[house] : nil
    }

    /// The House a deed scores for, and how much, when it is done against
    /// a House of another kingdom: troops slain, a company felled, a hold
    /// taken.
    func points(for event: GameEvent) -> (house: Int, points: Int)? {
        func across(_ house: Int, _ other: Int?) -> Bool {
            guard let other, let mine = kingdom(of: house), let theirs = kingdom(of: other) else { return false }
            return mine != theirs
        }
        switch event {
        case .battle(let battle) where battle.defenderKind != nil && across(battle.attackerOwner, battle.defenderOwner):
            return (battle.attackerOwner, (battle.slain ?? 0) / 100 + (battle.defenderFell ? 5 : 0))
        case .holdCaptured(_, let from, let by) where across(by, from):
            return (by, 25)
        default:
            return nil
        }
    }

    /// Every kingdom there, best first: those of the Houses seated, and
    /// those whose keepers are on their way.
    public func standings(seated keepers: [Keeper]) -> [KingdomStanding] {
        var realms = Set(kingdoms.compactMap { $0 })
        realms.formUnion(admitted.values.map(\.realm))
        return realms.map { realm in
            let houses = kingdoms.indices.filter { kingdoms[$0] == realm }
            return KingdomStanding(realm: realm, points: houses.reduce(0) { $0 + points[$1] },
                                   keepers: keepers.filter { $0.house.map(houses.contains) == true }.count)
        }.sorted { ($0.points, $1.realm) > ($1.points, $0.realm) }
    }
}

extension RealmState {
    // MARK: The Frontier, as a home realm

    /// The companies of war a House sends with its keeper: its strongest,
    /// by tier and then by the troops they stand with, up to `levyMost`;
    /// the troops drilled into them cross with them.
    public func levy(of house: Int) -> [Levy] {
        world.units.filter { $0.owner == house && $0.kind.isMilitary }
            .sorted { ($0.tier, world.troops(of: $0), -$0.id) > ($1.tier, world.troops(of: $1), -$1.id) }
            .prefix(FrontierState.levyMost)
            .map { Levy(kind: $0.kind, tier: $0.tier, drilled: $0.drilled) }
    }

    /// The keepers crossing to the Frontier for the season open there, as
    /// this realm lists them for it.
    public var crossings: [Crossing] {
        guard frontier == nil, let news = frontierNews, news.open else { return [] }
        return keepers.compactMap { keeper in
            guard keeper.crossing == news.season, let house = keeper.house, !world.houses[house].isEliminated else { return nil }
            return Crossing(keeper: keeper.id, name: keeper.name, realm: name, season: news.season, heritage: world.heritage(of: house),
                            levy: levy(of: house))
        }
    }

    /// A keeper crosses to the Frontier for the season open there; their
    /// House stays, kept for them while they are away, and sends its levy.
    public mutating func cross(_ id: String) throws(RealmError) -> [GameEvent] {
        guard let index = keepers.firstIndex(where: { $0.id == id }) else { throw .unknownKeeper }
        guard frontier == nil else { throw .refused("You are at the Frontier already.") }
        guard let news = frontierNews, news.open else { throw .refused("No season is open at the Frontier.") }
        guard let house = keepers[index].house, !world.houses[house].isEliminated else { throw .noSeat }
        guard keepers[index].crossing != news.season else { throw .refused("You have crossed for this season already.") }
        let levy = levy(of: house)
        guard !levy.isEmpty else { throw .refused("Your House has no company of war to send with you.") }
        keepers[index].crossing = news.season
        keepers[index].hasPlayed = true
        world.record(.happening, [house], "\(world.houses[house].title) sends its keeper across to the Frontier for its "
                     + "\(ordinal(news.season)) season, with \(levy.count) \(levy.count == 1 ? "company" : "companies").")
        return [.frontier(.crossed(house: house, season: news.season, levy: levy.count))]
    }

    /// What the steward hears of the Frontier, kept for the keepers to
    /// see; a season's end is told home once, and each keeper who crossed
    /// for it is honoured: their House given its kingdom's spoils if their
    /// realm prevailed, a share if they scored for it, and they are home.
    @discardableResult
    public mutating func hearFrontier(_ news: FrontierNews) -> [GameEvent] {
        guard frontier == nil else { return [] }
        frontierNews = news
        guard let result = news.last, result.season > (frontierTold ?? 0) else { return [] }
        frontierTold = result.season
        let won = result.prevailed == name
        var events: [GameEvent] = []
        for honour in result.honours where honour.realm == name {
            guard let index = keepers.firstIndex(where: { $0.id == honour.keeper }),
                  let house = keepers[index].house, !world.houses[house].isEliminated else { continue }
            var line = "\(world.houses[house].title)'s keeper comes home from the Frontier's \(ordinal(result.season)) season"
            if won {
                world.store(FrontierState.spoils, for: house)
                events += world.give(FrontierState.spoilsItems, to: house)
                keepers[index].titles = (keepers[index].titles ?? []) + ["Of the Frontier, Age \(age)"]
                line += ": its kingdom prevailed, and its House shares the spoils."
            } else if honour.points > 0 {
                world.store(FrontierState.share, for: house)
                line += ", having struck for its kingdom."
            } else {
                line += "."
            }
            world.record(.happening, [house], line)
            events.append(.frontier(.toldHome(house: house, season: result.season, prevailed: result.prevailed, points: honour.points, won: won)))
        }
        for index in keepers.indices where (keepers[index].crossing ?? .max) <= result.season {
            keepers[index].crossing = nil
        }
        return events
    }

    // MARK: The Frontier itself

    /// A new Frontier: a realm whose seats only keepers crossing from the
    /// realms it borders take.
    public init(frontier name: String, seed: String, seats: Int = RealmState.defaultSeats, radius: Int? = nil,
                watchLength: Double = RealmState.defaultWatchLength, now: Double) {
        self.init(name: name, seed: seed, seats: seats, radius: radius, watchLength: watchLength, now: now)
        frontier = FrontierState(season: 1, houses: world.houses.count)
        // Its kingdoms are the realms its keepers come from: its shores
        // never sunder.
        world.unsundered = true
    }

    /// The Frontier as it tells the realms it borders.
    public var frontierReport: FrontierNews? {
        guard let frontier else { return nil }
        return FrontierNews(address: "", season: frontier.season, watch: world.watch, lasts: FrontierState.lasts,
                            open: world.outcome == nil && world.watch < FrontierState.lasts, standings: frontier.standings(seated: keepers),
                            last: frontier.last)
    }

    /// The keepers a realm it borders lists as crossing for this season:
    /// taken as that realm's, in place of what it listed before.
    public mutating func admit(_ crossings: [Crossing], from realm: String) {
        guard var frontier else { return }
        let listed = crossings.filter { $0.realm == realm && $0.season == frontier.season }
        frontier.admitted = frontier.admitted.filter { $0.value.realm != realm }
        for crossing in listed where frontier.admitted[crossing.keeper] == nil {
            frontier.admitted[crossing.keeper] = crossing
        }
        self.frontier = frontier
    }

    /// The name a keeper crossing goes by at the Frontier: their own, or,
    /// if another goes by it, theirs of their realm.
    func frontierName(for crossing: Crossing) -> String? {
        let realm = crossing.realm.split(separator: " ").last.map(String.init) ?? crossing.realm
        let taken = Set(keepers.map { $0.name.lowercased() } + world.houses.map { $0.name.lowercased() })
        return [crossing.name, "\(crossing.name) of \(realm)"].first { RealmState.isValidName($0) && !taken.contains($0.lowercased()) }
    }

    /// A keeper newly seated at the Frontier: their House stands for their
    /// realm's kingdom, in its people's way, at war with every other
    /// realm's, its levy raised about its seat.
    mutating func raiseAtFrontier(_ index: Int) -> [GameEvent] {
        guard var frontier, let house = keepers[index].house, let crossing = frontier.admitted[keepers[index].id],
              frontier.kingdoms.indices.contains(house), frontier.kingdoms[house] == nil else { return [] }
        frontier.kingdoms[house] = crossing.realm
        self.frontier = frontier
        if let heritage = crossing.heritage { world.houses[house].heritage = heritage }
        // At war with every House of another realm's kingdom from the first.
        for other in frontier.kingdoms.indices where other != house && frontier.kingdoms[other].map({ $0 != crossing.realm }) == true {
            world.setStance(.war, between: house, and: other, by: house)
        }
        var raised = 0
        if let seat = world.seat(of: house) {
            for levy in crossing.levy.prefix(FrontierState.levyMost) {
                guard let unit = world.placeUnit(levy.kind, tier: levy.tier, for: house, near: seat.position) else { continue }
                if let index = world.unitIndex(unit.id) { world.units[index].drilled = levy.drilled }
                raised += 1
            }
        }
        world.record(.happening, [house], "\(world.houses[house].title) stands for \(crossing.realm) at the Frontier, "
                     + "with \(raised) \(raised == 1 ? "company" : "companies") sent from home.")
        return [.frontier(.raised(house: house, realm: crossing.realm, levy: raised))]
    }

    /// Points to the kingdoms for what was done across them.
    mutating func tallyFrontier(_ events: [GameEvent]) {
        guard var frontier else { return }
        var changed = false
        for event in events {
            guard let (house, points) = frontier.points(for: event), points > 0, frontier.points.indices.contains(house) else { continue }
            frontier.points[house] += points
            changed = true
        }
        if changed { self.frontier = frontier }
    }

    /// Whether the Frontier's season has run its watches.
    var isSeasonOver: Bool {
        frontier != nil && world.watch >= FrontierState.lasts
    }

    /// The season's end, as it is kept to be told home: each kingdom's
    /// points, the one that prevailed, and every keeper's part.
    mutating func endSeason() {
        guard var frontier else { return }
        let standings = frontier.standings(seated: keepers)
        let prevailed = standings.count > 1 && standings[0].points > standings[1].points ? standings[0].realm
            : standings.count == 1 && standings[0].points > 0 ? standings[0].realm : nil
        let honours = keepers.compactMap { keeper -> FrontierHonour? in
            guard let house = keeper.house, let realm = frontier.kingdom(of: house) else { return nil }
            return FrontierHonour(keeper: keeper.id, realm: realm, points: frontier.points[house])
        }
        frontier.last = FrontierResult(season: frontier.season, standings: standings, prevailed: prevailed, honours: honours)
        world.record(.happening, [], prevailed.map { "The Frontier's \(ordinal(frontier.season)) season ends: \($0) prevails." }
                     ?? "The Frontier's \(ordinal(frontier.season)) season ends with no kingdom ahead.")
        frontier.season += 1
        frontier.admitted = [:]
        self.frontier = frontier
    }
}
