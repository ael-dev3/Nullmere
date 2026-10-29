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
    /// The last publication whose events the keeper has heard.
    private var heardThrough: UInt64 = 0
    /// The realm's publication the keeper's view was last read against:
    /// views change only when the realm publishes, so it's read only then.
    private var viewReadAt: UInt64?
    /// How many times the view was read, for tests.
    private(set) var viewReads = 0
    private var view: RealmView?
    private var arrived = false
    private var lastHere = -Double.infinity
    /// What the keeper asked of the realm, waiting to be sent or answered,
    /// in the order they asked it: orders, and being ready, which comes
    /// after the orders before it. While any wait, changes from others
    /// wait too, so an order carried out at once on the keeper's copy
    /// isn't undone by news that came before it.
    private var outbox: [Outgoing] = []
    private var sending: Task<Void, Never>?
    /// Which sender is the present one.
    private var senderNumber = 0
    /// The keeper was told the realm is out of reach: the next poll that
    /// succeeds says it answers again.
    private var wasUnreachable = false
    /// Polls failed in a row. One failure on a shaky line isn't told; two
    /// are, and the polls that follow come further apart, to thirty
    /// seconds, so a realm that is down isn't hammered by every keeper.
    private var failures = 0
    public static let longestPoll = 30.0
    /// Seconds before sending again what the realm didn't answer; doubles
    /// up to `retryLimit`.
    public let retryDelay: Double
    public static let retryLimit = 5.0
    /// An order not sent within this long is dropped: the world has moved
    /// on. Shorter than the steward keeps its answers, so an order sent
    /// again is never carried out twice.
    public static let orderLifetime = 300.0

    /// The link's clock, in seconds: a steady one, which a clock set
    /// back or forward doesn't move and which runs on while the Mac
    /// sleeps; or a test's.
    var now: () -> Double = { NetworkRealmLink.steadySeconds() }

    private static let origin = ContinuousClock.now
    nonisolated static func steadySeconds() -> Double {
        let elapsed = origin.duration(to: ContinuousClock.now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }

    struct Outgoing {
        /// An order, or being ready in the watch the keeper saw.
        enum Kind { case order(Command), ready(Bool, watch: Int?) }
        let kind: Kind
        let nonce: String
        let given: Double
        /// Sent at least once: the realm may have carried it out.
        var sent = false
    }
    /// What the keeper last asked about being ready, and in which watch.
    private var askedReady: (ready: Bool, watch: Int?)?

    /// Orders and readiness given and not yet answered.
    public var waiting: Int { outbox.count }

    /// The steward publishes at least every twenty seconds; a status that
    /// hasn't moved for this long means it has stopped.
    public let stewardSilence: Double
    private var statusMoved = NetworkRealmLink.steadySeconds()
    private var toldSilence = false

    public init(transport: any SpacetimeTransport, credentials: any IdentityStore, pollInterval: Double = 1,
                retryDelay: Double = 1, stewardSilence: Double = 60) {
        self.transport = transport
        self.credentialStore = credentials
        self.pollInterval = pollInterval
        self.retryDelay = retryDelay
        self.stewardSilence = stewardSilence
    }

    public static let silentSteward = "The realm's steward has been silent for a minute: the realm stands still, and orders wait until it returns."

    /// The server refused the keeper's key: it is forgotten, and a new one
    /// made at the next asking. Returns whether that was the trouble.
    @discardableResult
    func forgetKeyIfRefused(_ error: any Error) -> Bool {
        guard (error as? SpacetimeError)?.isUnauthorized == true else { return false }
        credentials = nil
        try? credentialStore.save("")
        arrived = false
        // The realm as it stands is told afresh, to the keeper at its door.
        statusVersion = 0
        view = nil
        viewVersion = 0
        viewReadAt = nil
        outbox.removeAll()
        return true
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
                try? await Task.sleep(nanoseconds: UInt64(self.nextPoll * 1_000_000_000))
            }
        }
    }

    /// Seconds to the next poll: the link's own interval while the realm
    /// answers; after failures, doubling to `longestPoll`, a little
    /// earlier or later at random so keepers don't all come back at once.
    var nextPoll: Double {
        guard failures > 1 else { return pollInterval }
        let backed = min(pollInterval * pow(2, Double(failures - 1)), max(pollInterval, Self.longestPoll))
        return backed * Double.random(in: 0.8...1.2)
    }

    /// The Mac woke, or found the network again: the realm is asked at
    /// once, not at the end of a long wait.
    public func wake() {
        guard polling != nil else { return }
        failures = 0
        polling?.cancel()
        polling = nil
        connect()
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
            failures = 0
            if UInt64(number) != statusVersion {
                statusMoved = now()
                toldSilence = false
            } else if !toldSilence, now() - statusMoved > stewardSilence {
                toldSilence = true
                wasUnreachable = true
                onEvent?(.unreachable(Self.silentSteward))
                return
            }
            if UInt64(number) != statusVersion || (wasUnreachable && !toldSilence) {
                wasUnreachable = false
                statusVersion = UInt64(number)
                let status = try JSONDecoder().decode(RealmStatus.self, from: Data(text.utf8))
                onEvent?(.status(status.aged(by: await age(of: UInt64(number), credentials))))
            }
            guard arrived else { return }
            // "Here" while the steward is silent would only pile up for it.
            if !toldSilence, now() - lastHere > Self.hereInterval {
                lastHere = now()
                try? await transport.call("here", [.string(Self.nonce())], token: credentials.token)
            }
            if viewReadAt != statusVersion, try await readView(credentials) {
                viewReadAt = statusVersion
            }
        } catch {
            if forgetKeyIfRefused(error) {
                // A new key, a new keeper: the front door asks for a name.
                onEvent?(.refused(.unknownKeeper))
                return
            }
            failures += 1
            guard failures > 1 else { return }
            wasUnreachable = true
            onEvent?(.unreachable(RealmTrouble.words(for: error)))
        }
    }

    /// Seconds since the server took this publication of the status, by
    /// the server's own clock; nothing if it can't say.
    private func age(of version: UInt64, _ credentials: SpacetimeCredentials) async -> Int {
        guard let (rows, date) = try? await transport.queryDated("SELECT version, at_micros FROM stamp", token: credentials.token),
              let date, let row = rows.first, row.count == 2, row[0].number.map(UInt64.init) == version, let micros = row[1].number
        else { return 0 }
        return Int((date.timeIntervalSince1970 - micros / 1_000_000).rounded(.down))
    }

    /// The keeper's own view: `my_view` holds one row, theirs.
    private func fetchView(_ credentials: SpacetimeCredentials) async throws -> (UInt64, RealmView, [HeardBatch])? {
        let rows = try await transport.query("SELECT * FROM my_view", token: credentials.token)
        guard let row = rows.first, row.count == 4, let number = row[1].number, let text = row[2].string, let heard = row[3].string else {
            return nil
        }
        let decoder = JSONDecoder()
        let view = try decoder.decode(RealmView.self, from: Data(text.utf8))
        let batches = (try? decoder.decode([HeardBatch].self, from: Data(heard.utf8))) ?? []
        return (UInt64(number), view, batches)
    }

    /// Reads the keeper's view, unless their own orders are on their way.
    /// Returns whether it was read.
    private func readView(_ credentials: SpacetimeCredentials) async throws -> Bool {
        guard outbox.isEmpty else { return false }
        viewReads += 1
        // The row's version first: the whole view, tens of kilobytes to
        // fetch and decode, only when it has moved. Most publications move
        // the status, not this keeper's view.
        let heads = try await transport.query("SELECT version FROM my_view", token: credentials.token)
        if let number = heads.first?.first?.number, UInt64(number) == viewVersion { return true }
        guard let (number, fresh, batches) = try await fetchView(credentials) else { return true }
        if number != viewVersion { deliver(fresh, version: number, heard: batches) }
        return true
    }

    /// Takes a fresh view, and tells what it brought: a new age, a turned
    /// watch, or a changed world, with what the keeper hasn't yet heard.
    private func deliver(_ fresh: RealmView, version number: UInt64, heard batches: [HeardBatch]) {
        let previous = view
        view = fresh
        viewVersion = number
        let events = batches.filter { $0.version > heardThrough }.flatMap(\.events)
        heardThrough = max(heardThrough, batches.map(\.version).max() ?? 0)
        guard let previous else { return }
        if fresh.age != previous.age {
            onEvent?(.arrived(fresh.keeper, fresh.world))
        } else if fresh.world.watch != previous.world.watch {
            onEvent?(.watchTurned(fresh.world, events))
        } else {
            if fresh.world != previous.world { onEvent?(.changed(fresh.world)) }
            if !events.isEmpty { onEvent?(.heard(events)) }
            // The realm's word on whether the keeper is ready stands over
            // the client's: readiness lost while away (taken to have left,
            // a steward begun again) is put right, once nothing about it
            // is still on its way.
            let readinessWaiting = outbox.contains { if case .ready = $0.kind { return true } else { return false } }
            if !readinessWaiting, let asked = askedReady, asked.watch == fresh.world.watch, asked.ready != fresh.keeper.isReady {
                askedReady = (fresh.keeper.isReady, fresh.world.watch)
                onEvent?(.readiness(fresh.keeper.isReady))
            }
        }
    }

    /// A request, and the steward's answer to it. Sent again with the same
    /// nonce, it is the same request.
    private func request(_ reducer: String, _ arguments: [ReducerArgument], nonce: String = NetworkRealmLink.nonce()) async throws -> RealmReply {
        let credentials = try await ensureCredentials()
        try await transport.call(reducer, [.string(nonce)] + arguments, token: credentials.token)
        // Asked often at first, when the steward most likely answers, then
        // less, for thirty seconds.
        let deadline = now() + 30
        var wait = 0.1
        for _ in 0..<60 where now() < deadline {
            if let reply = try await answer(to: nonce, credentials) { return reply }
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            wait = min(wait * 1.5, 1)
        }
        throw SpacetimeError("The realm didn't answer in time.")
    }

    /// The steward's answer to a request, if it has given one.
    private func answer(to nonce: String, _ credentials: SpacetimeCredentials) async throws -> RealmReply? {
        let rows = try await transport.query("SELECT * FROM my_replies", token: credentials.token)
        guard let row = rows.first(where: { $0.first?.string == nonce }), row.count == 3, let text = row[2].string else { return nil }
        return try JSONDecoder().decode(RealmReply.self, from: Data(text.utf8))
    }

    /// Waits for the steward to publish what came of a request, and takes
    /// the view it published.
    private func catchUp() async throws {
        let credentials = try await ensureCredentials()
        let seen = viewVersion
        for _ in 0..<50 {
            if let (number, fresh, batches) = try await fetchView(credentials), number != seen {
                deliver(fresh, version: number, heard: batches)
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
                lastHere = now()
                onEvent?(.arrived(view.keeper, view.world))
            } catch {
                if forgetKeyIfRefused(error) {
                    onEvent?(.refused(.unknownKeeper))
                    return
                }
                onEvent?(.refused(.refused(RealmTrouble.words(for: error))))
            }
        }
    }

    public func send(_ command: Command) {
        outbox.append(Outgoing(kind: .order(command), nonce: Self.nonce(), given: now()))
        sendWaiting()
    }

    public func setReady(_ ready: Bool) {
        let watch = view?.world.watch
        askedReady = (ready, watch)
        outbox.append(Outgoing(kind: .ready(ready, watch: watch), nonce: Self.nonce(), given: now()))
        sendWaiting()
    }

    /// Sends what waits, one at a time and in order; what the realm doesn't
    /// answer is sent again, the same, until it does.
    private func sendWaiting() {
        guard sending == nil else { return }
        senderNumber += 1
        let number = senderNumber
        sending = Task { [weak self] in
            var delay = self?.retryDelay ?? 1
            while let self, let next = self.outbox.first {
                var expired = false
                if case .order = next.kind { expired = self.now() - next.given > Self.orderLifetime }
                do {
                    let reply: RealmReply
                    if expired {
                        // Too old to send. If it was sent, the realm may have
                        // carried it out: its answer is kept longer than an
                        // order lives, so it is looked for before the order
                        // is said to be lost.
                        let credentials = try await self.ensureCredentials()
                        guard next.sent, let kept = try await self.answer(to: next.nonce, credentials) else {
                            self.outbox.removeFirst()
                            if let world = self.view?.world {
                                self.onEvent?(.orderRefused(.refused("An order given while the realm was out of reach was too old to send."), world))
                            }
                            continue
                        }
                        reply = kept
                    } else {
                        self.outbox[0].sent = true
                        switch next.kind {
                        case .order(let command):
                            let text = String(decoding: try JSONEncoder().encode(command), as: UTF8.self)
                            reply = try await self.request("order", [.string(text)], nonce: next.nonce)
                        case .ready(let ready, let watch?):
                            reply = try await self.request("ready_in_watch", [.bool(ready), .integer(UInt64(max(watch, 0)))], nonce: next.nonce)
                        case .ready(let ready, nil):
                            reply = try await self.request("ready", [.bool(ready)], nonce: next.nonce)
                        }
                    }
                    // The realm was begun anew and doesn't know this keeper:
                    // back to the door, not orders no one will carry out.
                    if reply.unknownKeeper == true {
                        self.arrived = false
                        self.outbox.removeAll()
                        self.onEvent?(.refused(.unknownKeeper))
                        break
                    }
                    // Left while the answer came: the outbox is gone, and
                    // so is this sender's errand.
                    guard !Task.isCancelled, self.outbox.first?.nonce == next.nonce else { break }
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
                            self.onEvent?(.answered(reply.events ?? []))
                        } else if let world = self.view?.world {
                            // A refused order changed nothing: the world is as last seen.
                            self.onEvent?(.orderRefused(.refused(reply.refusal ?? "The realm refused the order."), world))
                        }
                    case .ready:
                        if self.outbox.isEmpty { await self.poll() }
                    }
                } catch {
                    if Task.isCancelled { break }
                    if self.forgetKeyIfRefused(error) {
                        self.onEvent?(.refused(.unknownKeeper))
                        break
                    }
                    self.wasUnreachable = true
                    self.onEvent?(.unreachable(RealmTrouble.words(for: error)))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay = min(delay * 2, Self.retryLimit)
                }
            }
            // Only this sender's own handle: one started after a leave is
            // another's.
            if self?.senderNumber == number { self?.sending = nil }
        }
    }

    public func leave() {
        close()
        Task {
            _ = try? await request("leave", [])
        }
    }

    public func close() {
        onEvent = nil
        arrived = false
        polling?.cancel()
        polling = nil
        sending?.cancel()
        sending = nil
        outbox.removeAll()
    }

    nonisolated static func nonce() -> String {
        KeeperIdentity.make()
    }
}
