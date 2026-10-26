import Foundation
import NullmereCore

/// A keeper's line to the realm proper, through SpacetimeDB: requests go
/// in by reducer; the realm's status, and the keeper's own view of its
/// world, are read back as often as `pollInterval`, whenever they move on.
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
    private var statusVersion: UInt64 = 0
    private var viewVersion: UInt64 = 0
    private var view: RealmView?
    private var arrived = false
    private var lastHere = Date.distantPast
    /// The keeper's own orders sent and not yet answered. While any are,
    /// changes from others wait, so an order carried out at once on the
    /// keeper's copy isn't undone by news that came before it.
    private var inFlight = 0
    /// The last poll failed: the next that succeeds says so.
    private var wasUnreachable = false

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
            statusVersion = 0
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

    /// Reads the realm's status and the keeper's view if they have moved
    /// on, and tells what changed.
    func poll() async {
        do {
            let credentials = try await ensureCredentials()
            let heads = try await transport.query("SELECT version, status FROM status", token: credentials.token)
            guard let head = heads.first, head.count == 2, let number = head[0].number, let text = head[1].string else {
                onEvent?(.unreachable("The realm hasn't opened yet."))
                return
            }
            if UInt64(number) != statusVersion || wasUnreachable {
                wasUnreachable = false
                statusVersion = UInt64(number)
                onEvent?(.status(try JSONDecoder().decode(RealmStatus.self, from: Data(text.utf8))))
            }
            guard arrived else { return }
            if Date().timeIntervalSince(lastHere) > Self.hereInterval {
                lastHere = Date()
                try? await transport.call("here", [.string(Self.nonce())], token: credentials.token)
            }
            try await readView(credentials)
        } catch {
            wasUnreachable = true
            onEvent?(.unreachable(String(describing: error)))
        }
    }

    /// The keeper's own view: `my_view` holds one row, theirs.
    private func fetchView(_ credentials: SpacetimeCredentials) async throws -> (UInt64, RealmView, [GameEvent])? {
        let rows = try await transport.query("SELECT * FROM my_view", token: credentials.token)
        guard let row = rows.first, row.count == 4, let number = row[1].number, let text = row[2].string, let heard = row[3].string else {
            return nil
        }
        let decoder = JSONDecoder()
        let view = try decoder.decode(RealmView.self, from: Data(text.utf8))
        let events = (try? decoder.decode([GameEvent].self, from: Data(heard.utf8))) ?? []
        return (UInt64(number), view, events)
    }

    private func readView(_ credentials: SpacetimeCredentials) async throws {
        guard inFlight == 0, let (number, fresh, events) = try await fetchView(credentials), number != viewVersion else { return }
        deliver(fresh, version: number, events: events)
    }

    /// Takes a fresh view, and tells what it brought: a new age, a turned
    /// watch, or a changed world.
    private func deliver(_ fresh: RealmView, version number: UInt64, events: [GameEvent]) {
        let previous = view
        view = fresh
        viewVersion = number
        guard let previous else { return }
        if fresh.age != previous.age {
            onEvent?(.arrived(fresh.keeper, fresh.world))
        } else if fresh.world.watch != previous.world.watch {
            onEvent?(.watchTurned(fresh.world, events))
        } else if fresh.world != previous.world {
            onEvent?(.changed(fresh.world))
        }
    }

    /// A request, and the steward's answer to it.
    private func request(_ reducer: String, _ arguments: [ReducerArgument]) async throws -> RealmReply {
        let credentials = try await ensureCredentials()
        let nonce = Self.nonce()
        try await transport.call(reducer, [.string(nonce)] + arguments, token: credentials.token)
        for _ in 0..<300 {
            let rows = try await transport.query("SELECT * FROM my_replies", token: credentials.token)
            if let row = rows.first(where: { $0.first?.string == nonce }), row.count == 3, let text = row[2].string {
                return try JSONDecoder().decode(RealmReply.self, from: Data(text.utf8))
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw SpacetimeError("The realm didn't answer in time.")
    }

    /// Waits for the steward to publish what came of a request, and takes
    /// the view it published.
    private func catchUp() async throws {
        let credentials = try await ensureCredentials()
        let seen = viewVersion
        for _ in 0..<50 {
            if let (number, fresh, events) = try await fetchView(credentials), number != seen {
                deliver(fresh, version: number, events: events)
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    public func arrive(name: String?) {
        Task {
            do {
                let reply = try await request("arrive", [.string(name ?? "")])
                guard reply.ok, reply.keeper != nil else {
                    onEvent?(.refused(.refused(reply.refusal ?? "The realm wouldn't take you in.")))
                    return
                }
                try await catchUp()
                guard let view else {
                    onEvent?(.refused(.refused("The realm took you in, but hasn't shown you the world yet. Try again.")))
                    return
                }
                arrived = true
                lastHere = Date()
                onEvent?(.arrived(view.keeper, view.world))
            } catch {
                onEvent?(.refused(.refused(String(describing: error))))
            }
        }
    }

    public func send(_ command: Command) {
        inFlight += 1
        Task {
            do {
                let text = String(decoding: try JSONEncoder().encode(command), as: UTF8.self)
                let reply = try await request("order", [.string(text)])
                inFlight -= 1
                if reply.ok {
                    try await catchUp()
                } else if let world = view?.world {
                    // A refused order changed nothing: the world is as last seen.
                    onEvent?(.orderRefused(.refused(reply.refusal ?? "The realm refused the order."), world))
                }
            } catch {
                inFlight -= 1
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
