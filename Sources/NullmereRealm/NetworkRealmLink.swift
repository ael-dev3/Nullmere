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
    /// The realm's publication the keeper's view was last read against:
    /// views change only when the realm publishes, so it's read only then.
    private var viewReadAt: UInt64?
    /// How many times the view was read, for tests.
    private(set) var viewReads = 0
    private var view: RealmView?
    private var arrived = false
    private var lastHere = Date.distantPast
    /// What the keeper asked of the realm, waiting to be sent or answered,
    /// in the order they asked it: orders, and being ready, which comes
    /// after the orders before it. While any wait, changes from others
    /// wait too, so an order carried out at once on the keeper's copy
    /// isn't undone by news that came before it.
    private var outbox: [Outgoing] = []
    private var sending: Task<Void, Never>?
    /// The last poll failed: the next that succeeds says so.
    private var wasUnreachable = false
    /// Seconds before sending again what the realm didn't answer; doubles
    /// up to `retryLimit`.
    public let retryDelay: Double
    public static let retryLimit = 5.0
    /// An order not sent within this long is dropped: the world has moved
    /// on. Shorter than the steward keeps its answers, so an order sent
    /// again is never carried out twice.
    public static let orderLifetime = 300.0

    struct Outgoing {
        enum Kind { case order(Command), ready(Bool) }
        let kind: Kind
        let nonce: String
        let given: Date
    }

    /// Orders and readiness given and not yet answered.
    public var waiting: Int { outbox.count }

    public init(transport: any SpacetimeTransport, credentials: any IdentityStore, pollInterval: Double = 1,
                retryDelay: Double = 1) {
        self.transport = transport
        self.credentialStore = credentials
        self.pollInterval = pollInterval
        self.retryDelay = retryDelay
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
            if viewReadAt != statusVersion, try await readView(credentials) {
                viewReadAt = statusVersion
            }
        } catch {
            wasUnreachable = true
            onEvent?(.unreachable(String(describing: error)))
        }
    }

    /// The keeper's own view: `my_view` holds one row, theirs.
    private func fetchView(_ credentials: SpacetimeCredentials) async throws -> (UInt64, RealmView, [GameEvent])? {
        viewReads += 1
        let rows = try await transport.query("SELECT * FROM my_view", token: credentials.token)
        guard let row = rows.first, row.count == 4, let number = row[1].number, let text = row[2].string, let heard = row[3].string else {
            return nil
        }
        let decoder = JSONDecoder()
        let view = try decoder.decode(RealmView.self, from: Data(text.utf8))
        let events = (try? decoder.decode([GameEvent].self, from: Data(heard.utf8))) ?? []
        return (UInt64(number), view, events)
    }

    /// Reads the keeper's view, unless their own orders are on their way.
    /// Returns whether it was read.
    private func readView(_ credentials: SpacetimeCredentials) async throws -> Bool {
        guard outbox.isEmpty else { return false }
        guard let (number, fresh, events) = try await fetchView(credentials) else { return true }
        if number != viewVersion { deliver(fresh, version: number, events: events) }
        return true
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

    /// A request, and the steward's answer to it. Sent again with the same
    /// nonce, it is the same request.
    private func request(_ reducer: String, _ arguments: [ReducerArgument], nonce: String = NetworkRealmLink.nonce()) async throws -> RealmReply {
        let credentials = try await ensureCredentials()
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
        outbox.append(Outgoing(kind: .order(command), nonce: Self.nonce(), given: Date()))
        sendWaiting()
    }

    public func setReady(_ ready: Bool) {
        outbox.append(Outgoing(kind: .ready(ready), nonce: Self.nonce(), given: Date()))
        sendWaiting()
    }

    /// Sends what waits, one at a time and in order; what the realm doesn't
    /// answer is sent again, the same, until it does.
    private func sendWaiting() {
        guard sending == nil else { return }
        sending = Task { [weak self] in
            var delay = self?.retryDelay ?? 1
            while let self, let next = self.outbox.first {
                if case .order = next.kind, Date().timeIntervalSince(next.given) > Self.orderLifetime {
                    self.outbox.removeFirst()
                    if let world = self.view?.world {
                        self.onEvent?(.orderRefused(.refused("An order given while the realm was out of reach was too old to send."), world))
                    }
                    continue
                }
                do {
                    let reply: RealmReply
                    switch next.kind {
                    case .order(let command):
                        let text = String(decoding: try JSONEncoder().encode(command), as: UTF8.self)
                        reply = try await self.request("order", [.string(text)], nonce: next.nonce)
                    case .ready(let ready):
                        reply = try await self.request("ready", [.bool(ready)], nonce: next.nonce)
                    }
                    delay = self.retryDelay
                    self.outbox.removeFirst()
                    if self.wasUnreachable {
                        self.wasUnreachable = false
                        self.statusVersion = 0
                    }
                    switch next.kind {
                    case .order:
                        if reply.ok {
                            if self.outbox.isEmpty { try? await self.catchUp() }
                        } else if let world = self.view?.world {
                            // A refused order changed nothing: the world is as last seen.
                            self.onEvent?(.orderRefused(.refused(reply.refusal ?? "The realm refused the order."), world))
                        }
                    case .ready:
                        if self.outbox.isEmpty { await self.poll() }
                    }
                } catch {
                    if Task.isCancelled { break }
                    self.wasUnreachable = true
                    self.onEvent?(.unreachable(String(describing: error)))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay = min(delay * 2, Self.retryLimit)
                }
            }
            self?.sending = nil
        }
    }

    public func leave() {
        arrived = false
        polling?.cancel()
        polling = nil
        sending?.cancel()
        sending = nil
        outbox.removeAll()
        Task {
            _ = try? await request("leave", [])
        }
    }

    nonisolated static func nonce() -> String {
        KeeperIdentity.make()
    }
}
