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

    public init(name: String, age: Int, watch: Int, seats: Int, freeSeats: Int, keepers: Int, online: Int, ready: Int,
                secondsLeft: Int, isEnding: Bool) {
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
    }
}

public enum RealmError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownKeeper
    case nameInvalid
    case nameTaken
    /// Every seat is held; the keeper waits for one to fall free.
    case noSeat
    case rule(RuleError)
    /// Refused across the network, for the reason the realm gave.
    case refused(String)

    public var description: String {
        switch self {
        case .unknownKeeper: return "The realm doesn't know you yet."
        case .nameInvalid: return "A name is two to twenty letters, spaces, hyphens or apostrophes."
        case .nameTaken: return "Another keeper already goes by that name."
        case .noSeat: return "Every seat around the lake is held. You'll hold the next that falls free."
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

    public init(name: String, seed: String, seats: Int = 8, radius: Int = 30, watchLength: Double = RealmState.defaultWatchLength,
                now: Double) {
        self.name = name
        self.seedText = seed
        self.seats = min(max(seats, 2), Names.houses.count)
        self.radius = radius
        self.watchLength = watchLength
        age = 1
        world = RealmState.world(seed: seed, age: 1, seats: self.seats, radius: radius)
        keepers = []
        watchBegan = now
    }

    /// A realm around a world already made, its first kept House held by
    /// one keeper: one House's game, hosted to rehearse or to test.
    public init(name: String, world: GameState, keeper id: String, now: Double, watchLength: Double = 1e9) {
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
        GameState(settings: GameSettings(seedText: "\(seed) · age \(age)", houseCount: seats, radius: radius, keepers: 0))
    }

    public func keeper(_ id: String) -> Keeper? {
        keepers.first { $0.id == id }
    }

    public func status(now: Double) -> RealmStatus {
        let held = Set(keepers.compactMap(\.house))
        let free = world.livingHouses.filter { !held.contains($0.id) && !$0.isPlayer }.count
        let online = keepers.filter(\.isOnline)
        return RealmStatus(name: name, age: age, watch: world.watch, seats: seats, freeSeats: free,
                           keepers: keepers.count, online: online.count, ready: online.filter(\.isReady).count,
                           secondsLeft: max(0, Int((watchLength - (now - watchBegan)).rounded(.up))),
                           isEnding: world.outcome != nil)
    }

    // MARK: Keepers

    /// Whether a name will do: two to twenty letters, with spaces, hyphens
    /// or apostrophes between them.
    public static func isValidName(_ name: String) -> Bool {
        let trimmed = trim(name)
        guard (2...20).contains(trimmed.count), trimmed.first?.isLetter == true, trimmed.last?.isLetter == true else { return false }
        return trimmed.allSatisfy { $0.isLetter || $0 == " " || $0 == "-" || $0 == "'" }
    }

    static func trim(_ name: String) -> String {
        String(name.drop(while: { $0 == " " }).reversed().drop(while: { $0 == " " }).reversed())
    }

    /// A keeper arrives: a returning one by their identity, a new one with
    /// the name they chose. Either takes a seat if they have none and one
    /// is free.
    @discardableResult
    public mutating func arrive(_ id: String, name: String?, now: Double) throws(RealmError) -> Keeper {
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
        if keepers[index].house == nil {
            claimSeat(for: index)
        }
        return keepers[index]
    }

    /// A keeper leaves; their House stands as they left it.
    public mutating func depart(_ id: String) {
        guard let index = keepers.firstIndex(where: { $0.id == id }) else { return }
        keepers[index].isOnline = false
        keepers[index].isReady = false
    }

    /// Gives a keeper the first free seat: a living House no keeper holds.
    private mutating func claimSeat(for index: Int) {
        guard world.outcome == nil,
              let seat = world.livingHouses.first(where: { !$0.isPlayer && $0.liege == nil }) else { return }
        world.houses[seat.id].isPlayer = true
        world.houses[seat.id].name = keepers[index].name
        keepers[index].house = seat.id
        world.record(.founding, [seat.id], "\(world.houses[seat.id].title) takes its seat by the still water.")
    }

    // MARK: Orders and watches

    /// A keeper's order, for the House they hold.
    public mutating func perform(_ command: Command, by id: String) throws(RealmError) -> [GameEvent] {
        guard let keeper = keeper(id) else { throw .unknownKeeper }
        guard let house = keeper.house, !world.houses[house].isEliminated else { throw .noSeat }
        do {
            return try world.perform(command, as: house)
        } catch {
            throw .rule(error)
        }
    }

    /// A keeper is done with their orders, or not. When every keeper
    /// online is ready, the watch turns; its events are returned.
    public mutating func setReady(_ id: String, _ ready: Bool, now: Double) -> [GameEvent]? {
        guard let index = keepers.firstIndex(where: { $0.id == id }), keepers[index].house != nil else { return nil }
        keepers[index].isReady = ready
        let online = keepers.filter { $0.isOnline && $0.house != nil }
        guard ready, !online.isEmpty, online.allSatisfy(\.isReady) else { return nil }
        return turn(now: now)
    }

    /// A steward gives this watch's orders for a keeper's House: while
    /// they're away, or when they ask it to.
    @discardableResult
    public mutating func stewardOrders(for id: String) -> [GameEvent] {
        guard let house = keeper(id)?.house, world.outcome == nil else { return [] }
        return world.stewardTurn(for: house)
    }

    /// Turns the watch once its time is up, if anyone is there to see it.
    public mutating func tick(now: Double) -> [GameEvent]? {
        guard keepers.contains(where: \.isOnline), now - watchBegan >= watchLength else { return nil }
        return turn(now: now)
    }

    private mutating func turn(now: Double) -> [GameEvent] {
        watchBegan = now
        for index in keepers.indices { keepers[index].isReady = false }
        if world.outcome != nil {
            beginAge()
            return []
        }
        return world.endWatch()
    }

    /// The next age: a fresh lake, and every keeper seated again in the
    /// order they first came.
    private mutating func beginAge() {
        age += 1
        world = RealmState.world(seed: seedText, age: age, seats: seats, radius: radius)
        for index in keepers.indices { keepers[index].house = nil }
        for index in keepers.indices.sorted(by: { keepers[$0].arrival < keepers[$1].arrival }) {
            claimSeat(for: index)
        }
    }
}
