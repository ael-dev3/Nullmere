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
    private var replies: [String: String] = [:] // nonce → payload
    private var world: (version: UInt64, state: String, status: String, events: String)?
    private(set) var calls: [String] = []

    func createIdentity() async throws -> SpacetimeCredentials {
        let identity = KeeperIdentity.make() + KeeperIdentity.make()
        let token = "token-" + identity
        identities[token] = identity
        // The first identity made publishes the module, and so stewards it.
        if steward == nil { steward = identity }
        return SpacetimeCredentials(identity: identity, token: token)
    }

    private func sender(_ token: String) throws -> String {
        guard let identity = identities[token] else { throw SpacetimeError("401 Unauthorized") }
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
            guard requests.filter({ $0.keeper == me }).count < 32 else { throw SpacetimeError("Too many requests are waiting") }
            requests.append(Request(id: nextID, keeper: me, kind: reducer, nonce: nonce, payload: payload))
            nextID += 1
        case "settle":
            guard me == steward else { throw SpacetimeError("Only the steward settles requests.") }
            guard case .integer(let id)? = arguments.first else { throw SpacetimeError("bad arguments") }
            let reply = try string(1)
            if let index = requests.firstIndex(where: { $0.id == id }) {
                replies[requests[index].nonce] = reply
                requests.remove(at: index)
            }
        case "forget":
            guard me == steward else { throw SpacetimeError("Only the steward forgets answers.") }
            if case .strings(let nonces)? = arguments.first { nonces.forEach { replies[$0] = nil } }
        case "publish":
            guard me == steward else { throw SpacetimeError("Only the steward writes the world.") }
            guard case .integer(let version)? = arguments.first else { throw SpacetimeError("bad arguments") }
            if let world, version <= world.version { throw SpacetimeError("Version \(version) is not after \(world.version).") }
            world = (version, try string(1), try string(2), try string(3))
        default:
            throw SpacetimeError("No such reducer: \(reducer)")
        }
    }

    func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        _ = try sender(token)
        switch sql {
        case "SELECT version, state FROM world":
            return world.map { [[.number(Double($0.version)), .string($0.state)]] } ?? []
        case "SELECT version, status FROM world":
            return world.map { [[.number(Double($0.version)), .string($0.status)]] } ?? []
        case "SELECT state, status, events FROM world":
            return world.map { [[.string($0.state), .string($0.status), .string($0.events)]] } ?? []
        case "SELECT id, keeper, kind, nonce, payload FROM request":
            return requests.map { [.number(Double($0.id)), .string($0.keeper), .string($0.kind), .string($0.nonce), .string($0.payload)] }
        default:
            let prefix = "SELECT payload FROM reply WHERE nonce = '"
            if sql.hasPrefix(prefix) {
                let nonce = String(sql.dropFirst(prefix.count).dropLast())
                return replies[nonce].map { [[.string($0)]] } ?? []
            }
            throw SpacetimeError("Unexpected query: \(sql)")
        }
    }
}
