import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereRealm

/// What the realm said when it would not do what was asked: its own
/// words, to show the player as they are.
public struct LiveRefusal: Error, Equatable, CustomStringConvertible, Sendable {
    public let words: String
    public var description: String { words }
}

/// A player's line to the realm: who they are there, what they ask of it,
/// and the realm's rows as it pushes them.
///
/// Everything the game decides is decided in the realm. The client asks
/// (each method here is one reducer) and reads; where the realm refuses,
/// it says why in words of its own, and they are thrown as `LiveRefusal`.
public final class LiveClient: @unchecked Sendable {
    public let credentials: SpacetimeCredentials
    private let transport: SpacetimeHTTP
    private let lock = NSLock()
    private var watching: (any RealmWatch)?

    public init(transport: SpacetimeHTTP, credentials: SpacetimeCredentials) {
        self.transport = transport
        self.credentials = credentials
    }

    /// A line to a realm's database on a server, as the identity given, or
    /// as a new one the server makes: keep its credentials to come back
    /// as the same player.
    public static func open(server: URL, database: String, credentials: SpacetimeCredentials? = nil) async throws -> LiveClient {
        let transport = SpacetimeHTTP(server: server, database: database)
        let known: SpacetimeCredentials
        if let credentials { known = credentials } else { known = try await transport.createIdentity() }
        return LiveClient(transport: transport, credentials: known)
    }

    // MARK: Reading

    /// Begins watching the realm: its rows as they stand, then every
    /// change as it happens; `changed` is told each time. False where no
    /// subscription can be opened (the client can still read with `read`).
    @discardableResult
    public func watch(changed: @escaping @Sendable () -> Void = {}) async -> Bool {
        let watch = await transport.watch(LiveSchema.queries, token: credentials.token, tables: LiveSchema.tables, changed: changed)
        keep(watch)
        return watch != nil
    }

    /// Keeps a subscription in place of the one kept, which is stopped.
    private func keep(_ watch: (any RealmWatch)?) {
        lock.lock()
        defer { lock.unlock() }
        watching?.stop()
        watching = watch
    }

    /// Whether the realm's rows are coming as they change.
    public var isLive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return watching?.mirror?.isLive ?? false
    }

    /// The realm as the subscription has it now; empty until it takes.
    public var world: LiveWorld {
        lock.lock()
        let mirror = watching?.mirror
        lock.unlock()
        return LiveWorld(snapshot: mirror?.snapshot() ?? [:])
    }

    /// The realm read afresh, table by table, without a subscription.
    public func read() async throws -> LiveWorld {
        var snapshot: [String: [[JSONValue]]] = [:]
        for table in LiveSchema.tables.keys.sorted() {
            snapshot[table] = try await transport.query("SELECT * FROM \(table)", token: credentials.token)
        }
        return LiveWorld(snapshot: snapshot)
    }

    /// Stops watching.
    public func close() {
        keep(nil)
    }

    // MARK: Asking

    /// Calls a reducer; the realm's refusal is thrown in its own words.
    private func ask(_ reducer: String, _ arguments: [ReducerArgument]) async throws {
        do {
            try await transport.call(reducer, arguments, token: credentials.token)
        } catch let error as SpacetimeError where error.status == 530 || error.status == 400 {
            throw LiveRefusal(words: error.description)
        }
    }

    /// Joins the realm under a name: a city is founded for the player.
    public func join(name: String) async throws { try await ask("join", [.string(name)]) }

    /// Builds a building the player's city has not got, by its kind.
    public func build(_ kind: Int) async throws { try await ask("build", [.integer(UInt64(kind))]) }

    /// Raises one of the player's buildings a level.
    public func upgrade(building: UInt64) async throws { try await ask("upgrade", [.integer(building)]) }

    /// Trains a batch of soldiers of a tier in a training building.
    public func train(building: UInt64, tier: Int, count: UInt64) async throws {
        try await ask("train", [.integer(building), .integer(UInt64(tier)), .integer(count)])
    }

    /// Sends soldiers from the player's city to gather at a hex.
    public func gather(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws {
        let records = soldiers.map { ["kind": UInt64($0.kind), "tier": UInt64($0.tier), "count": $0.count] }
        try await ask("send", [.signed(Int64(hex.q)), .signed(Int64(hex.r)), .integer(1), .records(records)])
    }

    /// Calls one of the player's armies home.
    public func recall(march: UInt64) async throws { try await ask("recall", [.integer(march)]) }
}
