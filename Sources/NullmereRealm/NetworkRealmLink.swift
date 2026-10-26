import Foundation
import NullmereCore

/// A keeper's line to the realm proper, through SpacetimeDB: requests go
/// in by reducer, and the realm the steward publishes is read back, as
/// often as `pollInterval`, whenever its version moves on.
@MainActor
public final class NetworkRealmLink: RealmLink {
    private let transport: any SpacetimeTransport
    private let credentialStore: any IdentityStore
    public var onEvent: ((RealmEvent) -> Void)?
    public private(set) var credentials: SpacetimeCredentials?

    public let pollInterval: Double
    /// How often the client tells the realm it is still there.
    public static let hereInterval = 30.0

    private var polling: Task<Void, Never>?
    private var version: UInt64 = 0
    private var realm: RealmState?
    private var arrived = false
    private var lastHere = Date.distantPast

    public init(transport: any SpacetimeTransport, credentials: any IdentityStore, pollInterval: Double = 1) {
        self.transport = transport
        self.credentialStore = credentials
        self.pollInterval = pollInterval
    }

    /// The keeper's credentials, made once and kept.
    private func ensureCredentials() async throws -> SpacetimeCredentials {
        if let credentials { return credentials }
        if let kept = credentialStore.load(), let data = kept.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(SpacetimeCredentials.self, from: data) {
            credentials = decoded
            return decoded
        }
        let made = try await transport.createIdentity()
        try credentialStore.save(String(decoding: try JSONEncoder().encode(made), as: UTF8.self))
        credentials = made
        return made
    }

    public func connect() {
        guard polling == nil else {
            if let realm { onEvent?(.status(realm.status(now: Date().timeIntervalSince1970))) }
            return
        }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.poll()
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            }
        }
    }

    /// Reads the realm if it has moved on, and tells what changed.
    func poll() async {
        do {
            let credentials = try await ensureCredentials()
            let heads = try await transport.query("SELECT version, status FROM world", token: credentials.token)
            guard let head = heads.first, head.count == 2, let number = head[0].number else {
                onEvent?(.unreachable("The realm hasn't opened yet."))
                return
            }
            if arrived, Date().timeIntervalSince(lastHere) > Self.hereInterval {
                lastHere = Date()
                try? await transport.call("here", [.string(Self.nonce())], token: credentials.token)
            }
            let latest = UInt64(number)
            guard latest != version else { return }
            let rows = try await transport.query("SELECT state, status, events FROM world", token: credentials.token)
            guard let row = rows.first, row.count == 3, let stateText = row[0].string, let statusText = row[1].string,
                  let eventsText = row[2].string else { return }
            let decoder = JSONDecoder()
            let state = try decoder.decode(RealmState.self, from: Data(stateText.utf8))
            let status = try decoder.decode(RealmStatus.self, from: Data(statusText.utf8))
            let events = (try? decoder.decode([GameEvent].self, from: Data(eventsText.utf8))) ?? []
            let previous = realm
            realm = state
            version = latest
            onEvent?(.status(status))
            guard arrived, let previous, let keeper = state.keeper(credentials.identity) else { return }
            if state.age != previous.age {
                onEvent?(.arrived(keeper, state.world))
            } else if state.world.watch != previous.world.watch {
                onEvent?(.watchTurned(state.world, events))
            } else if state.world != previous.world {
                onEvent?(.changed(state.world))
            }
        } catch {
            onEvent?(.unreachable(String(describing: error)))
        }
    }

    /// A request, and the steward's answer to it.
    private func request(_ reducer: String, _ arguments: [ReducerArgument]) async throws -> RealmReply {
        let credentials = try await ensureCredentials()
        let nonce = Self.nonce()
        try await transport.call(reducer, [.string(nonce)] + arguments, token: credentials.token)
        for _ in 0..<200 {
            let rows = try await transport.query("SELECT payload FROM reply WHERE nonce = \(sqlString(nonce))", token: credentials.token)
            if let text = rows.first?.first?.string {
                return try JSONDecoder().decode(RealmReply.self, from: Data(text.utf8))
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw SpacetimeError("The realm didn't answer in time.")
    }

    /// Waits until the published realm has caught up with an answer.
    private func freshRealm() async -> RealmState? {
        let seen = version
        for _ in 0..<50 {
            await poll()
            if version != seen { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return realm
    }

    public func arrive(name: String?) {
        Task {
            do {
                let reply = try await request("arrive", [.string(name ?? "")])
                guard reply.ok, let keeper = reply.keeper else {
                    onEvent?(.refused(.refused(reply.refusal ?? "The realm wouldn't take you in.")))
                    return
                }
                guard let realm = await freshRealm() else { return }
                arrived = true
                lastHere = Date()
                onEvent?(.arrived(realm.keeper(keeper.id) ?? keeper, realm.world))
            } catch {
                onEvent?(.refused(.refused(String(describing: error))))
            }
        }
    }

    public func send(_ command: Command) {
        Task {
            do {
                let text = String(decoding: try JSONEncoder().encode(command), as: UTF8.self)
                let reply = try await request("order", [.string(text)])
                if !reply.ok, let world = await freshRealm()?.world {
                    onEvent?(.orderRefused(.refused(reply.refusal ?? "The realm refused the order."), world))
                }
            } catch {
                onEvent?(.unreachable(String(describing: error)))
            }
        }
    }

    public func setReady(_ ready: Bool) {
        Task {
            _ = try? await request("ready", [.bool(ready)])
            await poll()
        }
    }

    public func leave() {
        arrived = false
        polling?.cancel()
        polling = nil
        Task {
            _ = try? await request("leave", [])
        }
    }

    static func nonce() -> String {
        KeeperIdentity.make()
    }
}
