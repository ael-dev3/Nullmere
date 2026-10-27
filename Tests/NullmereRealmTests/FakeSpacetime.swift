import Foundation
@testable import NullmereRealm

/// SpacetimeDB in memory, keeping the realm module's tables and following
/// its reducers' rules (`realm-server/src/lib.rs`), for testing the steward
/// and the network link without a server.
actor FakeSpacetime: SpacetimeTransport {
    struct Request { let id: UInt64; let keeper: String; let kind: String; let nonce: String; let payload: String }

    private var identities: [String: String] = [:] // token → identity
    private var steward: String?
    private var requests: [Request] = []
    private var nextID: UInt64 = 1
    private var replies: [String: (keeper: String, payload: String)] = [:] // by nonce
    private var world: (version: UInt64, state: String)?
    private var status: (version: UInt64, status: String)?
    private var stamp: (version: UInt64, at: Double)?
    /// The server's clock at the epoch's start, for its `Date` answers.
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)
    private var views: [String: (version: UInt64, view: String, events: String)] = [:] // by keeper
    private(set) var calls: [String] = []
    /// The server's clock, in seconds, moved on by tests.
    private var time = 0.0
    private var lease: (holder: String, until: Double)?

    func advance(_ seconds: Double) { time += seconds }

    /// The server forgets an identity, as when its database is made anew.
    func forget(token: String) { identities[token] = nil }

    /// Requests of each kind the steward has answered.
    private var settled: [String: Int] = [:]

    func handled(kind: String) -> Int { settled[kind] ?? 0 }

    func createIdentity() async throws -> SpacetimeCredentials {
        let identity = KeeperIdentity.make() + KeeperIdentity.make()
        let token = "token-" + identity
        identities[token] = identity
        // The first identity made publishes the module, and so stewards it.
        if steward == nil { steward = identity }
        return SpacetimeCredentials(identity: identity, token: token)
    }

    private func sender(_ token: String) throws -> String {
        guard let identity = identities[token] else { throw SpacetimeError.unauthorized }
        return identity
    }

    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        let me = try sender(token)
        calls.append(reducer)
        func string(_ index: Int) throws -> String {
            guard arguments.indices.contains(index), case .string(let value) = arguments[index] else { throw SpacetimeError("bad arguments") }
            return value
        }
        switch reducer {
        case "arrive", "order", "ready", "here", "leave":
            let nonce = try string(0)
            var payload = ""
            if reducer == "ready", case .bool(let ready)? = arguments.dropFirst().first { payload = ready ? "true" : "false" }
            else if reducer == "arrive" || reducer == "order" { payload = try string(1) }
            if requests.contains(where: { $0.nonce == nonce && $0.keeper == me }) || replies[nonce]?.keeper == me { return }
            guard requests.filter({ $0.keeper == me }).count < 32 else { throw SpacetimeError("Too many requests are waiting") }
            requests.append(Request(id: nextID, keeper: me, kind: reducer, nonce: nonce, payload: payload))
            nextID += 1
        case "settle":
            guard me == steward else { throw SpacetimeError("Only the steward settles requests.") }
            guard case .integer(let id)? = arguments.first else { throw SpacetimeError("bad arguments") }
            let reply = try string(1)
            if let index = requests.firstIndex(where: { $0.id == id }) {
                replies[requests[index].nonce] = (requests[index].keeper, reply)
                settled[requests[index].kind, default: 0] += 1
                requests.remove(at: index)
            }
        case "forget":
            guard me == steward else { throw SpacetimeError("Only the steward forgets answers.") }
            if case .strings(let nonces)? = arguments.first { nonces.forEach { replies[$0] = nil } }
        case "publish":
            guard me == steward else { throw SpacetimeError("Only the steward writes the world.") }
            guard case .integer(let version)? = arguments.first, arguments.count == 9, case .string(let holder) = arguments[8],
                  case .strings(let keepers) = arguments[3], case .strings(let shown) = arguments[4], case .strings(let heard) = arguments[5],
                  case .integers(let ids) = arguments[6], case .strings(let answers) = arguments[7]
            else { throw SpacetimeError("bad arguments") }
            guard keepers.count == shown.count, keepers.count == heard.count else { throw SpacetimeError("Every view needs its keeper and its events.") }
            guard ids.count == answers.count else { throw SpacetimeError("Every answer needs its request.") }
            if let lease, lease.holder != holder, lease.until > time {
                throw SpacetimeError("Another steward holds the realm for \(Int(lease.until - time) + 1) s more.")
            }
            lease = (holder, time + 60)
            if let status, version <= status.version { throw SpacetimeError("Version \(version) is not after \(status.version).") }
            let state = try string(1)
            if !state.isEmpty {
                world = (version, state)
            } else if world == nil {
                throw SpacetimeError("The first publication holds the world.")
            }
            status = (version, try string(2))
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

    /// Private tables are the owner's, the steward's, alone to read.
    func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        let me = try sender(token)
        func owner() throws {
            guard me == steward else { throw SpacetimeError("Table is private") }
        }
        switch sql {
        case "SELECT version, state FROM world":
            try owner()
            return world.map { [[.number(Double($0.version)), .string($0.state)]] } ?? []
        case "SELECT id, keeper, kind, nonce, payload FROM request":
            try owner()
            return requests.map { [.number(Double($0.id)), .string($0.keeper), .string($0.kind), .string($0.nonce), .string($0.payload)] }
        case "SELECT version FROM status":
            return status.map { [[.number(Double($0.version))]] } ?? []
        case "SELECT version, status FROM status":
            return status.map { [[.number(Double($0.version)), .string($0.status)]] } ?? []
        case "SELECT version, at_micros FROM stamp":
            return stamp.map { [[.number(Double($0.version)), .number((epoch.timeIntervalSince1970 + $0.at) * 1_000_000)]] } ?? []
        case "SELECT * FROM my_view":
            return views[me].map { [[.string(me), .number(Double($0.version)), .string($0.view), .string($0.events)]] } ?? []
        case "SELECT * FROM my_replies":
            return replies.filter { $0.value.keeper == me }.map { [.string($0.key), .string($0.value.keeper), .string($0.value.payload)] }
        case "SELECT * FROM world", "SELECT * FROM keeper_view", "SELECT * FROM reply", "SELECT * FROM request":
            try owner()
            return []
        default:
            throw SpacetimeError("Unexpected query: \(sql)")
        }
    }

    /// Answers dated by the server's clock, to the second, as HTTP dates are.
    func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?) {
        (try await query(sql, token: token), Date(timeIntervalSince1970: (epoch.timeIntervalSince1970 + time).rounded(.down)))
    }
}
