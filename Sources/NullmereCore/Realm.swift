/// A person on the realm, known only by the name they chose.
public struct Keeper: Codable, Equatable, Identifiable, Sendable {
    /// The keeper's identity: an opaque token the realm knows them by.
    public let id: String
    /// The name they go by; it names the House they hold.
    public let name: String
    /// The House they hold this age, if a seat was free.
    public internal(set) var house: Int?
    /// Done with this watch's orders.
    public internal(set) var isReady: Bool
    public internal(set) var isOnline: Bool
    /// The order they arrived in, for seats in a new age.
    public let arrival: Int
    /// When they left, if they are away.
    public internal(set) var awaySince: Double?
    /// Watches turned since they left, if they are away.
    public internal(set) var watchesAway: Int?
    /// They have given an order or been ready for a watch: they came to play.
    public internal(set) var hasPlayed: Bool?
}

/// What anyone may know of the realm before entering it.
public struct RealmStatus: Codable, Equatable, Sendable {
    public let name: String
    public let age: Int
    public let watch: Int
    public let seats: Int
    public let freeSeats: Int
    public let keepers: Int
    public let online: Int
    public let ready: Int
    /// Seconds until the watch turns of its own accord.
    public let secondsLeft: Int
    /// The age is over and the next begins when the watch turns.
    public let isEnding: Bool
    /// The names of the keepers there now, the first `presentShown`.
    public let present: [String]?
    /// The lake of this age, by name.
    public let lake: String?

    public static let presentShown = 24

    public init(name: String, age: Int, watch: Int, seats: Int, freeSeats: Int, keepers: Int, online: Int, ready: Int,
                secondsLeft: Int, isEnding: Bool, present: [String]? = nil, lake: String? = nil) {
        self.name = name
        self.age = age
        self.watch = watch
        self.seats = seats
        self.freeSeats = freeSeats
        self.keepers = keepers
        self.online = online
        self.ready = ready
        self.secondsLeft = secondsLeft
        self.isEnding = isEnding
        self.present = present
        self.lake = lake
    }
}

extension RealmStatus {
    /// The status as it stands `seconds` after it was made: the watch's
    /// time that much shorter.
    public func aged(by seconds: Int) -> RealmStatus {
        RealmStatus(name: name, age: age, watch: watch, seats: seats, freeSeats: freeSeats, keepers: keepers, online: online,
                    ready: ready, secondsLeft: max(0, secondsLeft - max(0, seconds)), isEnding: isEnding, present: present, lake: lake)
    }
}

public enum RealmError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownKeeper
    case nameInvalid
    case nameTaken
    /// An order from a keeper who holds no standing House.
    case noSeat
    case rule(RuleError)
    /// Refused across the network, for the reason the realm gave.
    case refused(String)

    public var description: String {
        switch self {
        case .unknownKeeper: return "The realm doesn't know you yet."
        case .nameInvalid: return "A name is two to twenty letters, spaces, hyphens or apostrophes."
        case .nameTaken: return "A keeper or a House already goes by that name."
        case .noSeat: return "You hold no House standing on the lake."
        case .rule(let error): return error.description
        case .refused(let reason): return reason
        }
    }
}

/// The realm: one persistent world shared by every keeper, and the
/// authority over it. Keepers claim seats and give orders for their own
/// House; seats no keeper holds are played by stewards. The watch turns
/// when every keeper online is ready, or when its time runs out, but only
/// while someone is there: an empty realm sleeps. When an age ends in
/// victory, the next begins on a fresh lake.
public struct RealmState: Codable, Equatable, Sendable {
    public let name: String
    /// The realm's private words; each age's world grows from them.
    let seedText: String
    public let seats: Int
    let radius: Int
    /// Seconds a watch lasts before it turns of its own accord.
    public let watchLength: Double
    public internal(set) var age: Int
    public internal(set) var world: GameState
    public internal(set) var keepers: [Keeper]
    /// When the current watch began, in seconds.
    public internal(set) var watchBegan: Double

    public static let defaultWatchLength = 180.0

    /// The realm proper: twelve seats around a wide lake.
    public static let defaultSeats = 12
    public static let defaultRadius = 36

    public init(name: String, seed: String, seats: Int = RealmState.defaultSeats, radius: Int = RealmState.defaultRadius, watchLength: Double = RealmState.defaultWatchLength,
                now: Double) {
        self.name = name
        self.seedText = seed
        self.seats = min(max(seats, 2), Names.houses.count, WorldGenerator.mostHouses)
        self.radius = radius
        self.watchLength = watchLength
        age = 1
        world = RealmState.world(seed: seed, age: 1, seats: self.seats, radius: radius)
        keepers = []
        watchBegan = now
    }

    /// A realm around a world already made, its first kept House held by
    /// one keeper: one House's game, for tests to rehearse with.
    init(name: String, world: GameState, keeper id: String, now: Double, watchLength: Double = 1e9) {
        self.name = name
        self.seedText = world.settings.seedText
        self.seats = world.houses.count
        self.radius = world.settings.radius
        self.watchLength = watchLength
        age = 1
        self.world = world
        keepers = [Keeper(id: id, name: world.houses[world.player].name, house: world.player, isReady: false, isOnline: true, arrival: 0)]
        watchBegan = now
    }

    static func world(seed: String, age: Int, seats: Int, radius: Int) -> GameState {
        GameState(settings: GameSettings(seedText: "\(seed) · age \(age)", houseCount: seats, radius: radius, keepers: 0,
                                         lake: Lake.of(age: age)))
    }

    /// A realm kept from before the moon's water was found as the world was
    /// made: found now, on the whole map.
    public mutating func fillIn() {
        if world.moonWater == nil { world.moonWater = world.map.deepestWater() }
    }

    public func keeper(_ id: String) -> Keeper? {
        keepers.first { $0.id == id }
    }

    public func status(now: Double) -> RealmStatus {
        let held = Set(keepers.compactMap(\.house))
        // As a seat is claimed: a House open to a keeper, which no keeper holds.
        let free = openSeats.filter { !held.contains($0.id) }.count
        let online = keepers.filter(\.isOnline)
        return RealmStatus(name: name, age: age, watch: world.watch, seats: seats, freeSeats: free,
                           keepers: keepers.count, online: online.count, ready: online.filter(\.isReady).count,
                           secondsLeft: max(0, Int((watchLength - (now - watchBegan)).rounded(.up))),
                           isEnding: world.outcome != nil,
                           present: Array(online.sorted { $0.arrival < $1.arrival }.map(\.name).prefix(RealmStatus.presentShown)),
                           lake: world.settings.lake.title)
    }

    // MARK: Keepers

    /// Whether a name will do: two to twenty letters, with spaces, hyphens
    /// or apostrophes between them.
    public static func isValidName(_ name: String) -> Bool {
        nameProblem(name) == nil && !trim(name).isEmpty
    }

    /// What is wrong with a name as it is being typed, in a few words; nil
    /// when it will do, or when nothing has been typed yet.
    public static func nameProblem(_ name: String) -> String? {
        let trimmed = trim(name)
        if trimmed.isEmpty { return nil }
        if !trimmed.allSatisfy({ $0.isLetter || $0 == " " || $0 == "-" || $0 == "'" }) {
            return "Only letters, with spaces, hyphens or apostrophes between them."
        }
        if trimmed.first?.isLetter != true || trimmed.last?.isLetter != true {
            return "A name begins and ends with a letter."
        }
        if trimmed.count < 2 { return "At least two letters." }
        // Counted as written too, so letters stacked with marks can't
        // carry a name far past twenty.
        if trimmed.count > 20 || trimmed.unicodeScalars.count > 40 { return "No more than twenty letters." }
        return nil
    }

    /// How long a seat waits for a keeper who is away before it goes to
    /// one who is waiting: a week.
    public static let seatHeldFor: Double = 7 * 24 * 3600
    /// A seat taken and never played is held only a day, so names made in
    /// passing can't hold the lake.
    public static let unplayedSeatHeldFor: Double = 24 * 3600

    func seatHeld(by keeper: Keeper) -> Double {
        keeper.hasPlayed == true ? RealmState.seatHeldFor : RealmState.unplayedSeatHeldFor
    }

    static func trim(_ name: String) -> String {
        String(name.drop(while: { $0 == " " }).reversed().drop(while: { $0 == " " }).reversed())
    }

    /// A keeper arrives: a returning one by their identity, a new one with
    /// the name they chose. Either takes a seat if they have none and one
    /// is free; one whose House has fallen takes up a free one when
    /// `reseatsTheFallen`, as when they ask to.
    @discardableResult
    public mutating func arrive(_ id: String, name: String?, now: Double, reseatsTheFallen: Bool = true) throws(RealmError) -> Keeper {
        let index: Int
        if let known = keepers.firstIndex(where: { $0.id == id }) {
            index = known
        } else {
            guard let name, RealmState.isValidName(name) else { throw .nameInvalid }
            let chosen = RealmState.trim(name)
            let lowered = chosen.lowercased()
            guard !keepers.contains(where: { $0.name.lowercased() == lowered }),
                  !world.houses.contains(where: { $0.name.lowercased() == lowered }) else { throw .nameTaken }
            keepers.append(Keeper(id: id, name: chosen, house: nil, isReady: false, isOnline: true, arrival: keepers.count))
            index = keepers.count - 1
        }
        // The realm wakes: a sleeping watch starts anew.
        if keepers.allSatisfy({ !$0.isOnline || $0.id == id }) {
            watchBegan = now
        }
        keepers[index].isOnline = true
        keepers[index].awaySince = nil
        keepers[index].watchesAway = nil
        // A keeper whose House has fallen may take up one standing free,
        // rather than look on until the age ends.
        if reseatsTheFallen, let house = keepers[index].house, world.houses[house].isEliminated, hasFreeSeat {
            keepers[index].house = nil
        }
        if keepers[index].house == nil {
            claimSeat(for: index)
        }
        if keepers[index].house == nil, releaseSeat(now: now) {
            claimSeat(for: index)
        }
        return keepers[index]
    }

    /// A keeper leaves; after two watches a caretaker keeps their House.
    public mutating func depart(_ id: String, now: Double) {
        guard let index = keepers.firstIndex(where: { $0.id == id }) else { return }
        if keepers[index].isOnline {
            keepers[index].awaySince = now
            keepers[index].watchesAway = 0
        }
        keepers[index].isOnline = false
        keepers[index].isReady = false
    }

    /// The seat of the keeper away longest, if a week or more, goes back to
    /// the stewards for a keeper who is waiting. Its House stands as it was.
    private mutating func releaseSeat(now: Double) -> Bool {
        let away = keepers.indices.filter {
            keepers[$0].house != nil && !keepers[$0].isOnline && now - (keepers[$0].awaySince ?? now) >= seatHeld(by: keepers[$0])
        }
        guard let index = away.min(by: { keepers[$0].awaySince ?? 0 < keepers[$1].awaySince ?? 0 }),
              let house = keepers[index].house else { return false }
        world.houses[house].isPlayer = false
        keepers[index].house = nil
        let span = keepers[index].hasPlayed == true ? "a week" : "a day"
        world.record(.seating, [house], "\(world.houses[house].title) has stood \(span) without its keeper; the stewards keep it for another.")
        return true
    }

    /// A House open to a keeper stands free, and the age goes on.
    var hasFreeSeat: Bool {
        world.outcome == nil && !openSeats.isEmpty
    }

    /// How a House stands, to rank it: its realm, then its renown.
    private func standing(_ house: Int) -> [Int] {
        [world.realm(of: house), world.renown(of: house)]
    }

    /// The Houses a keeper may take up: living, kept by no keeper, sworn
    /// to no liege, and not near the end of the age. Never the House
    /// leading the lake, nor one within reach of dominion or with its
    /// Moonspire risen: a keeper coming under a new name, as often as they
    /// like, can't take a House on the point of winning.
    var openSeats: [House] {
        let living = world.livingHouses
        let best = living.map { standing($0.id) }.max { $0.lexicographicallyPrecedes($1) }
        let leaders = living.filter { standing($0.id) == best }
        let leader = leaders.count == 1 ? leaders.first?.id : nil
        return living.filter { house in
            !house.isPlayer && house.liege == nil && house.id != leader
                && world.realm(of: house.id) * 3 < world.dominionNeed * 2
                && (world.seat(of: house.id)?.level(.moonspire) ?? 0) < 3
        }
    }

    /// Gives a keeper a seat: a middling House of those open, or, at an
    /// age's start, all alike, the first.
    private mutating func claimSeat(for index: Int) {
        let open = openSeats
        let ranked = open.map { standing($0.id) }.sorted { $0.lexicographicallyPrecedes($1) }
        guard world.outcome == nil, !ranked.isEmpty,
              let seat = open.first(where: { standing($0.id) == ranked[(ranked.count - 1) / 2] }) else { return }
        world.houses[seat.id].isPlayer = true
        world.houses[seat.id].name = keepers[index].name
        keepers[index].house = seat.id
        // A House the stewards keep under the same name, as a keeper named
        // after one of the lake's Houses meets it in a new age, takes
        // another, so no two standing Houses share a name.
        let lowered = keepers[index].name.lowercased()
        for other in world.houses.indices where other != seat.id && !world.houses[other].isEliminated
            && world.houses[other].name.lowercased() == lowered {
            world.houses[other].name = unusedHouseName()
        }
        world.record(.seating, [seat.id], "\(world.houses[seat.id].title) takes its seat by the still water.")
    }

    /// Names held in reserve for a House whose own a keeper has taken.
    static let reserveNames = ["Corve", "Ashen", "Merrow", "Tarn", "Hollin", "Wyke"]

    private func unusedHouseName() -> String {
        let used = Set(world.houses.map { $0.name.lowercased() } + keepers.map { $0.name.lowercased() })
        let spare = (Names.houses + RealmState.reserveNames).first { !used.contains($0.lowercased()) }
        return spare ?? "Nameless \(world.houses.count)"
    }

    // MARK: Orders and watches

    /// A keeper's order, for the House they hold. One refused is refused in
    /// the words the keeper's own view of the world would give, whenever
    /// that view refuses it too: never for a reason only what their House
    /// can't see could give, such as a company out of its sight.
    public mutating func perform(_ command: Command, by id: String) throws(RealmError) -> [GameEvent] {
        guard let keeper = keeper(id) else { throw .unknownKeeper }
        guard let house = keeper.house, !world.houses[house].isEliminated else { throw .noSeat }
        // A strike only at what their House can see: one loosed into the
        // dark would tell them what stood there.
        if case .attack = command, let refusal = world.view(for: house).refusal(of: command, as: house) {
            throw .rule(refusal)
        }
        do {
            let events = try world.perform(command, as: house)
            if let index = keepers.firstIndex(where: { $0.id == id }) { keepers[index].hasPlayed = true }
            return events
        } catch {
            throw .rule(world.view(for: house).refusal(of: command, as: house) ?? error)
        }
    }

    /// A keeper is done with their orders, or not. When every keeper
    /// online is ready, the watch turns; its events are returned.
    public mutating func setReady(_ id: String, _ ready: Bool, now: Double) -> [GameEvent]? {
        guard let index = keepers.firstIndex(where: { $0.id == id }), keepers[index].house != nil else { return nil }
        keepers[index].isReady = ready
        if ready { keepers[index].hasPlayed = true }
        // Those whose House has fallen look on; the watch doesn't wait for
        // them, unless none still standing is there.
        guard ready, everyoneThereIsReady, now - watchBegan >= shortestWatch else { return nil }
        return turn(now: now)
    }

    /// Whether every keeper there is ready. Those whose House has fallen
    /// look on; the watch doesn't wait for them, unless none still
    /// standing is there.
    private var everyoneThereIsReady: Bool {
        let seated = keepers.filter { $0.isOnline && $0.house != nil }
        let standing = seated.filter { keeper in keeper.house.map { !world.houses[$0].isEliminated } == true }
        let online = standing.isEmpty ? seated : standing
        return !online.isEmpty && online.allSatisfy(\.isReady)
    }

    /// The least a watch lasts, however ready those there are: nothing,
    /// unless fewer than half the keepers whose Houses stand are there,
    /// when a third of a watch, so the few can't hurry the lake past the
    /// many away.
    var shortestWatch: Double {
        let standing = keepers.filter { keeper in keeper.house.map { !world.houses[$0].isEliminated } == true }
        let there = standing.filter(\.isOnline).count
        return there * 2 < standing.count ? watchLength / 3 : 0
    }

    /// Watches a keeper is away before a caretaker keeps their House.
    public static let caretakerAfter = 2

    /// A steward gives this watch's orders for a keeper's House, as a realm
    /// hosted on one Mac does when its keeper lets the watches run.
    @discardableResult
    public mutating func stewardOrders(for id: String) -> [GameEvent] {
        guard let house = keeper(id)?.house, world.outcome == nil else { return [] }
        return world.stewardTurn(for: house)
    }

    /// Turns the watch once its time is up, if anyone is there to see it.
    public mutating func tick(now: Double) -> [GameEvent]? {
        guard keepers.contains(where: \.isOnline) else { return nil }
        let elapsed = now - watchBegan
        // Its time up, or everyone there ready and the shortest watch past.
        guard elapsed >= watchLength || (everyoneThereIsReady && elapsed >= shortestWatch) else { return nil }
        return turn(now: now)
    }

    private mutating func turn(now: Double) -> [GameEvent] {
        watchBegan = now
        for index in keepers.indices { keepers[index].isReady = false }
        if world.outcome != nil {
            beginAge(now: now)
            return []
        }
        // A House whose keeper has been away two watches is kept for them,
        // in its turn among the stewards, so it doesn't stand idle while
        // its neighbours act. Counted in watches, not minutes: however
        // quickly the watches turn, it is kept from the second to turn
        // after its keeper left.
        for index in keepers.indices where !keepers[index].isOnline {
            keepers[index].watchesAway = (keepers[index].watchesAway ?? 0) + 1
        }
        let absent = keepers.filter { keeper in
            !keeper.isOnline && (keeper.watchesAway ?? 0) >= RealmState.caretakerAfter
        }.compactMap(\.house)
        return world.endWatch(keptFor: Set(absent))
    }

    /// The next age: a fresh lake, and every keeper seated again in the
    /// order they first came, but for those away longer than a seat is
    /// held: they are seated as they come back, if a seat is free.
    private mutating func beginAge(now: Double) {
        age += 1
        world = RealmState.world(seed: seedText, age: age, seats: seats, radius: radius)
        for index in keepers.indices { keepers[index].house = nil }
        let staying = keepers.indices.filter { index in
            keepers[index].isOnline || now - (keepers[index].awaySince ?? now) < seatHeld(by: keepers[index])
        }
        for index in staying.sorted(by: { keepers[$0].arrival < keepers[$1].arrival }) {
            claimSeat(for: index)
        }
    }
}
