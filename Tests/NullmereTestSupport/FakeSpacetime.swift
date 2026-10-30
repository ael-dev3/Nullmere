import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereRealm

/// SpacetimeDB in memory, keeping the realm module's tables and following
/// its reducers' rules (`realm-server/src/lib.rs`), for testing the steward
/// and the network link without a server.
public actor FakeSpacetime: SpacetimeTransport {
    struct Request { let id: UInt64; let keeper: String; let kind: String; let nonce: String; let payload: String }

    private var identities: [String: String] = [:] // token → identity
    /// The identity that published the module, which owns the database
    /// and alone reads its private tables; and the steward, the publisher
    /// until the realm is handed to another.
    private var owner: String?
    private var steward: String?
    private var requests: [Request] = []
    private var nextID: UInt64 = 1
    private var replies: [String: (keeper: String, payload: String)] = [:] // by nonce
    private var parts: [String: String] = [:] // the world's, by name
    private var status: (version: UInt64, status: String)?
    private var stamp: (version: UInt64, at: Double)?
    /// The server's clock at the epoch's start, for its `Date` answers.
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)
    private var views: [String: (version: UInt64, view: String, events: String)] = [:] // by keeper
    public private(set) var calls: [String] = []
    /// Queries made, by statement and by statement and caller.
    private var queryCounts: [String: Int] = [:]

    /// A keeper's poll of the realm's status.
    public static let statusPoll = "SELECT version, status FROM status"
    /// A steward's round begins by reading the requests waiting.
    public static let stewardRound = "SELECT id, keeper, kind, nonce, payload FROM request"
    /// A keeper asks after one answer, or one request still waiting, by its
    /// nonce; counted as one statement, whatever the nonce.
    public static let answerAsked = "SELECT * FROM my_replies WHERE nonce = ?"
    public static let requestAsked = "SELECT nonce FROM my_requests WHERE nonce = ?"

    /// The module's bounds (`MAX_NONCE`, `MAX_PAYLOAD`, `MAX_WAITING`, in
    /// bytes and requests) and its steward's hold, in seconds.
    public static let maxNonce = 64
    public static let maxPayload = 4096
    public static let maxWaiting = 32
    public static let leaseSeconds = 60.0

    /// How many times a statement has been queried, by anyone or by the
    /// holder of one token.
    public func queried(_ sql: String, by token: String? = nil) -> Int {
        guard let token else { return queryCounts[sql] ?? 0 }
        guard let identity = identities[token] else { return 0 }
        return queryCounts[sql + "\u{0}" + identity] ?? 0
    }

    /// Waits until a statement has been queried `count` more times: for a
    /// test that something didn't happen, work done rather than time
    /// passed, so a slow machine can't pass it by luck.
    public func waitFor(_ count: Int, more sql: String, timeout: Double = 20) async throws {
        try await waitFor(count, more: sql, caller: nil, timeout: timeout)
    }

    /// The same, for one caller's queries alone.
    public func waitFor(_ count: Int, more sql: String, by token: String, timeout: Double = 20) async throws {
        try await waitFor(count, more: sql, caller: token, timeout: timeout)
    }

    private func waitFor(_ count: Int, more sql: String, caller token: String?, timeout: Double) async throws {
        let target = queried(sql, by: token) + count
        let deadline = Date().addingTimeInterval(timeout)
        while queried(sql, by: token) < target {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(count) more of \(sql)") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// How many of the world's parts publications have sent, all told.
    public private(set) var partsSent = 0
    /// The server's clock, in seconds, moved on by tests.
    private var time = 0.0
    private var lease: (holder: String, until: Double)?

    public init() {}

    public func advance(_ seconds: Double) { time += seconds }

    /// Whether the server answers at all: off, every request fails as one
    /// to a server that can't be reached does, never having left the Mac.
    private var reachable = true

    public func setReachable(_ reachable: Bool) { self.reachable = reachable }

    private func answering() throws {
        guard reachable else { throw URLError(.cannotConnectToHost) }
    }

    /// The steward forgets every answer it gave, as it does ten minutes on.
    public func forgetReplies() { replies.removeAll() }

    /// The server forgets an identity, as when it is made anew, or is out of
    /// sorts and refuses every key.
    public func forget(token: String) { identities[token] = nil }

    /// The server takes a key again.
    public func remember(_ credentials: SpacetimeCredentials) { identities[credentials.token] = credentials.identity }

    /// The database made anew, as a publication with `--delete-data` makes
    /// it: every table emptied, the publisher its steward again, and the
    /// identities the server knows kept.
    public func clear() {
        requests = []
        replies = [:]
        parts = [:]
        status = nil
        stamp = nil
        views = [:]
        lease = nil
        legacyWorld = nil
        nextID = 1
        steward = owner
    }

    /// A world already kept, as a realm's own steward left it.
    public func seed(world parts: [String: String], version: UInt64) {
        self.parts = parts
        status = (version, "{}")
    }

    /// A world kept whole, as a realm from before parts left it.
    public func seed(legacyWorld state: String) { legacyWorld = state }
    private var legacyWorld: String?

    /// The world's parts as kept, by name: for tests.
    public var worldParts: [String: String] { parts }

    /// Requests of each kind the steward has answered.
    private var settled: [String: Int] = [:]

    public func handled(kind: String) -> Int { settled[kind] ?? 0 }

    public func createIdentity() async throws -> SpacetimeCredentials {
        try answering()
        let identity = KeeperIdentity.make() + KeeperIdentity.make()
        let token = "token-" + identity
        identities[token] = identity
        // The first identity made publishes the module, and so owns the
        // database and stewards the realm.
        if owner == nil {
            owner = identity
            steward = identity
        }
        return SpacetimeCredentials(identity: identity, token: token)
    }

    private func sender(_ token: String) throws -> String {
        guard let identity = identities[token] else { throw SpacetimeError.unauthorized }
        return identity
    }

    public func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        try answering()
        let me = try sender(token)
        calls.append(reducer)
        func string(_ index: Int) throws -> String {
            guard arguments.indices.contains(index), case .string(let value) = arguments[index] else { throw SpacetimeError("bad arguments") }
            return value
        }
        switch reducer {
        case "arrive", "order", "ready", "ready_in_watch", "here", "leave":
            let nonce = try string(0)
            var payload = ""
            if reducer == "ready", case .bool(let ready)? = arguments.dropFirst().first { payload = ready ? "true" : "false" }
            else if reducer == "ready_in_watch", arguments.count == 3, case .bool(let ready) = arguments[1], case .integer(let watch) = arguments[2] {
                payload = "\(ready)@\(watch)"
            } else if reducer == "arrive" || reducer == "order" { payload = try string(1) }
            // As the module asks it: readiness in a watch is a "ready" request.
            let kind = reducer == "ready_in_watch" ? "ready" : reducer
            // Its bounds, in bytes, as the module counts them.
            guard !nonce.isEmpty, nonce.utf8.count <= Self.maxNonce else {
                throw SpacetimeError("A request needs a nonce of 1 to 64 characters.", status: 530)
            }
            guard payload.utf8.count <= Self.maxPayload else { throw SpacetimeError("The request is too long.", status: 530) }
            if requests.contains(where: { $0.nonce == nonce && $0.keeper == me }) || replies[nonce]?.keeper == me { return }
            guard requests.filter({ $0.keeper == me }).count < Self.maxWaiting else {
                throw SpacetimeError("Too many of your requests are waiting; give the realm a moment.", status: 530)
            }
            requests.append(Request(id: nextID, keeper: me, kind: kind, nonce: nonce, payload: payload))
            nextID += 1
        case "forget":
            guard me == steward else { throw SpacetimeError("Only the steward forgets answers.", status: 530) }
            if case .strings(let nonces)? = arguments.first { nonces.forEach { replies[$0] = nil } }
        case "hand_over":
            guard me == steward else { throw SpacetimeError("Only the steward hands over the realm.", status: 530) }
            steward = try string(0)
        case "publish":
            // A reducer that fails undoes all it did, its hold on the realm
            // with the rest: every check before anything is kept, in the
            // module's own order.
            guard me == steward else { throw SpacetimeError("Only the steward writes the world.", status: 530) }
            guard case .integer(let version)? = arguments.first, arguments.count == 11, case .string(let holder) = arguments[10],
                  case .strings(let names) = arguments[1], case .strings(let texts) = arguments[2], case .strings(let gone) = arguments[3],
                  case .string(let said) = arguments[4],
                  case .strings(let keepers) = arguments[5], case .strings(let shown) = arguments[6], case .strings(let heard) = arguments[7],
                  case .integers(let ids) = arguments[8], case .strings(let answers) = arguments[9]
            else { throw SpacetimeError("bad arguments", status: 400) }
            if let lease, lease.holder != holder, lease.until > time {
                throw SpacetimeError("Another steward holds the realm for \(Int(lease.until - time) + 1) s more.", status: 530)
            }
            guard keepers.count == shown.count, keepers.count == heard.count else {
                throw SpacetimeError("Every view needs its keeper and its events.", status: 530)
            }
            guard ids.count == answers.count else { throw SpacetimeError("Every answer needs its request.", status: 530) }
            guard names.count == texts.count else { throw SpacetimeError("Every part of the world needs its name.", status: 530) }
            let last = status?.version ?? 0
            guard version > last else { throw SpacetimeError("Version \(version) is not after \(last).", status: 530) }
            var kept = parts
            gone.forEach { kept[$0] = nil }
            zip(names, texts).forEach { kept[$0] = $1 }
            guard !kept.isEmpty else { throw SpacetimeError("The first publication holds the world.", status: 530) }
            lease = (holder, time + Self.leaseSeconds)
            parts = kept
            partsSent += names.count
            status = (version, said)
            stamp = (version, time)
            for (index, keeper) in keepers.enumerated() {
                views[keeper] = (version, shown[index], heard[index])
            }
            for (id, answer) in zip(ids, answers) {
                if let index = requests.firstIndex(where: { $0.id == id }) {
                    replies[requests[index].nonce] = (requests[index].keeper, answer)
                    settled[requests[index].kind, default: 0] += 1
                    requests.remove(at: index)
                }
            }
        default:
            throw SpacetimeError("No such reducer: \(reducer)")
        }
    }

    /// Private tables are the owner's alone to read: the publisher's, steward
    /// or not.
    public func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        try answering()
        let me = try sender(token)
        // A row asked for by its nonce: the statement with the nonce taken out.
        let byNonce = [Self.answerAsked, Self.requestAsked].lazy.compactMap { pattern -> (String, String)? in
            let prefix = String(pattern.dropLast())
            guard sql.hasPrefix(prefix) else { return nil }
            let literal = sql.dropFirst(prefix.count)
            guard literal.count >= 2, literal.hasPrefix("'"), literal.hasSuffix("'") else { return nil }
            return (pattern, String(literal.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'"))
        }.first
        let counted = byNonce?.0 ?? sql
        queryCounts[counted, default: 0] += 1
        queryCounts[counted + "\u{0}" + me, default: 0] += 1
        func ownerOnly() throws {
            guard me == self.owner else { throw SpacetimeError("Table is private", status: 400) }
        }
        if let (pattern, nonce) = byNonce {
            if pattern == Self.answerAsked {
                return replies[nonce].flatMap { $0.keeper == me ? [[.string(nonce), .string($0.keeper), .string($0.payload)]] : nil } ?? []
            }
            return requests.filter { $0.keeper == me && $0.nonce == nonce }.map { [.string($0.nonce)] }
        }
        switch sql {
        case "SELECT version, state FROM world":
            try ownerOnly()
            return legacyWorld.map { [[.number(1), .string($0)]] } ?? []
        case "SELECT name, text FROM world_part":
            try ownerOnly()
            return parts.map { [.string($0.key), .string($0.value)] }
        case "SELECT id, keeper, kind, nonce, payload FROM request":
            try ownerOnly()
            return requests.map { [.number(Double($0.id)), .string($0.keeper), .string($0.kind), .string($0.nonce), .string($0.payload)] }
        case "SELECT nonce FROM reply":
            try ownerOnly()
            return replies.keys.sorted().map { [.string($0)] }
        case "SELECT version FROM status":
            return status.map { [[.number(Double($0.version))]] } ?? []
        case "SELECT version, status FROM status":
            return status.map { [[.number(Double($0.version)), .string($0.status)]] } ?? []
        case "SELECT version, at_micros FROM stamp":
            return stamp.map { [[.number(Double($0.version)), .number((epoch.timeIntervalSince1970 + $0.at) * 1_000_000)]] } ?? []
        case "SELECT version FROM my_view":
            return views[me].map { [[.number(Double($0.version))]] } ?? []
        case "SELECT * FROM my_view":
            return views[me].map { [[.string(me), .number(Double($0.version)), .string($0.view), .string($0.events)]] } ?? []
        case "SELECT nonce FROM my_requests":
            return requests.filter { $0.keeper == me }.map { [.string($0.nonce)] }
        case "SELECT * FROM my_replies":
            return replies.filter { $0.value.keeper == me }.map { [.string($0.key), .string($0.value.keeper), .string($0.value.payload)] }
        case "SELECT * FROM world", "SELECT * FROM world_part", "SELECT * FROM keeper_view", "SELECT * FROM reply", "SELECT * FROM request":
            try ownerOnly()
            return []
        default:
            throw SpacetimeError("Unexpected query: \(sql)")
        }
    }

    /// Answers dated by the server's clock, to the second, as HTTP dates are.
    public func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?) {
        (try await query(sql, token: token), Date(timeIntervalSince1970: (epoch.timeIntervalSince1970 + time).rounded(.down)))
    }
}

/// Credentials kept in memory, as the keychain would keep them.
public final class MemoryStore: IdentityStore, @unchecked Sendable {
    public var value: String?
    public init(value: String? = nil) { self.value = value }
    public func load() -> String? { value }
    public func save(_ identity: String) throws { value = identity }
}
