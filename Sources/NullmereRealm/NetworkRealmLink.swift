import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereCore

/// A keeper's line to the realm proper, through SpacetimeDB: requests go
/// in by reducer; the realm's status, and the keeper's own view of its
/// world, are read back whenever they move on: at once, as the realm
/// pushes word that its status changed, and as often as `pollInterval`
/// besides, or every `watchedPoll` seconds while the word is coming.
@MainActor
public final class NetworkRealmLink: RealmLink {
    private let transport: any SpacetimeTransport
    private let credentialStore: any IdentityStore
    public var onEvent: ((RealmEvent) -> Void)?
    public private(set) var credentials: SpacetimeCredentials?

    public let pollInterval: Double
    /// How often the client tells the realm it is still there.
    public static let hereInterval = 30.0
    /// Seconds since the person at this Mac last used it, as the app can
    /// tell: nothing, by default, for a client that can't.
    public var idleSeconds: () -> Double = { 0 }
    /// The keeper is there while this Mac has been used within this long,
    /// and says so. An app left open with no one at it falls silent; the
    /// realm takes its keeper to have gone, and after two watches a
    /// caretaker keeps their House. Back at the Mac, they are there again.
    public static let presenceWindow = 300.0

    private var polling: Task<Void, Never>?
    /// The realm's word, pushed as it happens, that its status changed.
    private var watch: (any RealmWatch)?
    private var watchAsked = false
    /// While the realm's word is coming, the link reads on its own only this often.
    public static let watchedPoll = 5.0
    private var isPolling = false
    private var pushedWhilePolling = false
    /// How many times the realm's pushed word brought a read, for tests.
    private(set) var pushes = 0
    private var statusVersion: UInt64 = 0
    private var viewVersion: UInt64 = 0
    /// The parts of the keeper's view as last read, by name, each with the
    /// version it was written at, and the publication they were read
    /// through: a view read again takes only the parts written since.
    private var viewParts: [String: (version: UInt64, text: String)] = [:]
    private var partsThrough: UInt64 = 0
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
    /// The last "here" whose answer is still to be read: a realm begun anew
    /// answers that it doesn't know the keeper.
    private var hereAwaited: String?
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
    /// An order that hasn't reached the realm within this long is let go:
    /// the world has moved on. One that may have reached it is never let go
    /// on the client's word, and after this long it is no longer sent again,
    /// only asked after: shorter than the steward keeps its answers, so an
    /// order is never carried out twice.
    public static let orderLifetime = 300.0

    /// The link's clock, in seconds: a steady one, which a clock set
    /// back or forward doesn't move and which runs on while the Mac
    /// sleeps; or a test's.
    var now: () -> Double = { NetworkRealmLink.steadySeconds() }

    nonisolated private static let origin = ContinuousClock.now
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
        /// It may have reached the realm: sent, and not refused on the way
        /// out. Only the realm's word settles such an order.
        var mayHaveReached = false
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

    public static let silentSteward = "The realm has been silent for a minute: it stands still, and orders sent to it wait until it returns."

    /// The identity being made, while it is. The first poll, an arrival and
    /// an order may all ask for the keeper's credentials before any is made:
    /// they wait on the one making, or the realm would make an identity for
    /// each, and the keeper would arrive under one and read the world under
    /// another, which no keeper holds.
    private var making: Task<SpacetimeCredentials, any Error>?

    /// The keeper's credentials, made once and kept. A key the server won't
    /// take is kept all the same, never erased nor made anew: the server may
    /// be out of sorts for a while, and the key is the keeper's only way back
    /// to their House. It is offered again as the realm is asked again.
    private func ensureCredentials() async throws -> SpacetimeCredentials {
        if let credentials { return credentials }
        if let kept = credentialStore.load(), let data = kept.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(SpacetimeCredentials.self, from: data) {
            credentials = decoded
            return decoded
        }
        if let making { return try await making.value }
        let task = Task { () async throws -> SpacetimeCredentials in
            let made = try await self.transport.createIdentity()
            try self.credentialStore.save(String(decoding: try JSONEncoder().encode(made), as: UTF8.self))
            return made
        }
        making = task
        defer { making = nil }
        let made = try await task.value
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
                // Word pushed during the read is read now.
                if self.pushedWhilePolling {
                    self.pushedWhilePolling = false
                    continue
                }
                try? await Task.sleep(nanoseconds: UInt64(self.nextPoll * 1_000_000_000))
            }
        }
    }

    /// The realm said its status changed: it is read now, not at the next poll.
    func pushed() {
        guard polling != nil else { return }
        pushes += 1
        if isPolling {
            pushedWhilePolling = true
            return
        }
        polling?.cancel()
        polling = nil
        connect()
    }

    /// Asks the realm to push word of its status, once; the transport keeps
    /// it open, and opens it again when it drops.
    private func startWatching(_ credentials: SpacetimeCredentials) async {
        guard !watchAsked else { return }
        watchAsked = true
        watch = await transport.watch(["SELECT * FROM status"], token: credentials.token) { [weak self] in
            Task { @MainActor [weak self] in self?.pushed() }
        }
    }

    /// Seconds to the next poll: the link's own interval while the realm
    /// answers; after failures, doubling to `longestPoll`, a little
    /// earlier or later at random so keepers don't all come back at once.
    var nextPoll: Double {
        guard failures > 1 else { return watch?.isAlive == true ? max(pollInterval, Self.watchedPoll) : pollInterval }
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
        isPolling = true
        defer { isPolling = false }
        do {
            let credentials = try await ensureCredentials()
            await startWatching(credentials)
            let heads = try await transport.query("SELECT version, status FROM status", token: credentials.token)
            guard let head = heads.first, head.count == 2, let number = head[0].number, let text = head[1].string else {
                onEvent?(.unreachable("The realm isn't open yet."))
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
            // "Here" while the steward is silent would only pile up for it;
            // and it is said only while someone is at this Mac.
            if !toldSilence, idleSeconds() < Self.presenceWindow, now() - lastHere > Self.hereInterval {
                lastHere = now()
                let nonce = Self.nonce()
                if (try? await transport.call("here", [.string(nonce)], token: credentials.token)) != nil {
                    hereAwaited = nonce
                }
            }
            // The realm's word on the last "here": a realm begun anew no
            // longer knows the keeper, who goes back to its door rather than
            // look on at a world that is gone.
            if let nonce = hereAwaited, let reply = try? await answer(to: nonce, credentials) {
                hereAwaited = nil
                if reply.unknownKeeper == true {
                    forgottenByTheRealm()
                    return
                }
            }
            if viewReadAt != statusVersion, try await readView(credentials) {
                viewReadAt = statusVersion
            }
        } catch {
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

    /// The keeper's own view: `my_view` holds one row, theirs, naming the
    /// parts of their view and the version each was written at; the parts
    /// written since those last read come from `my_view_parts`, so a pace
    /// that moved a few companies brings a page of them, not the whole
    /// world again. A view whose parts don't all match its row, published
    /// again between the two reads, is read again.
    private func fetchView(_ credentials: SpacetimeCredentials) async throws -> (UInt64, RealmView, [HeardBatch])? {
        for _ in 0..<3 {
            let rows = try await transport.query("SELECT * FROM my_view", token: credentials.token)
            guard let row = rows.first, row.count == 4, let number = row[1].number, let names = row[2].string, let heard = row[3].string,
                  let named = Self.parts(named: names) else {
                return nil
            }
            // A realm kept anew counts its publications from the start: its
            // parts are all read again.
            if UInt64(number) < partsThrough {
                viewParts = [:]
                partsThrough = 0
            }
            let written = try await transport.query("SELECT name, version, text FROM my_view_parts WHERE version > \(partsThrough)",
                                                    token: credentials.token)
            for part in written {
                guard part.count == 3, let name = part[0].string, let at = part[1].number, let text = part[2].string else { continue }
                viewParts[name] = (UInt64(at), text)
            }
            guard named.allSatisfy({ viewParts[$0.key]?.version == $0.value }) else { continue }
            viewParts = viewParts.filter { named[$0.key] != nil }
            partsThrough = max(partsThrough, UInt64(number))
            let texts = viewParts.mapValues(\.text)
            // Tens of kilobytes of world, read away from the main thread, so
            // the map doesn't falter while it is.
            let (view, batches) = try await Task.detached(priority: .userInitiated) { try Self.decode(parts: texts, heard: heard) }.value
            return (UInt64(number), view, batches)
        }
        // Never once whole: the next read takes every part afresh.
        viewParts = [:]
        partsThrough = 0
        return nil
    }

    /// The parts a view's row names, each with the version it was written
    /// at: "head:12,map:3,units.0:12". Nothing if the row says otherwise.
    nonisolated static func parts(named text: String) -> [String: UInt64]? {
        var parts: [String: UInt64] = [:]
        for entry in text.split(separator: ",") {
            guard let colon = entry.lastIndex(of: ":"), let version = UInt64(entry[entry.index(after: colon)...]) else { return nil }
            parts[String(entry[..<colon])] = version
        }
        return parts.isEmpty ? nil : parts
    }

    nonisolated static func decode(parts: [String: String], heard: String) throws -> (RealmView, [HeardBatch]) {
        let view = try RealmView(parts: parts)
        return (view, (try? JSONDecoder().decode([HeardBatch].self, from: Data(heard.utf8))) ?? [])
    }

    /// The version of the keeper's own view, if the realm shows them one.
    private func viewHead(_ credentials: SpacetimeCredentials) async throws -> UInt64? {
        let heads = try await transport.query("SELECT version FROM my_view", token: credentials.token)
        return heads.first?.first?.number.map { UInt64($0) }
    }

    /// Reads the keeper's view, unless their own orders are on their way.
    /// Returns whether it was read.
    private func readView(_ credentials: SpacetimeCredentials) async throws -> Bool {
        guard outbox.isEmpty else { return false }
        viewReads += 1
        // The row's version first: the whole view, tens of kilobytes to
        // fetch and decode, only when it has moved on. Most publications
        // move the status, not this keeper's view.
        if let number = try await viewHead(credentials), number <= viewVersion { return true }
        guard let (number, fresh, batches) = try await fetchView(credentials) else { return true }
        deliver(fresh, version: number, heard: batches)
        return true
    }

    /// Takes a fresh view, and tells what it brought: a new age, a turned
    /// watch, or a changed world, with what the keeper hasn't yet heard.
    /// Only a newer view: one read out of turn, while a later one was on its
    /// way, never stands over it.
    private func deliver(_ fresh: RealmView, version number: UInt64, heard batches: [HeardBatch]) {
        guard number > viewVersion else { return }
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
    /// nonce, it is the same request. `mayReach` is told when the request
    /// may have reached the realm: always, unless the call failed in a way
    /// that proves it never left this Mac, or was turned away at the
    /// server's door with the key.
    private func request(_ reducer: String, _ arguments: [ReducerArgument], nonce: String = NetworkRealmLink.nonce(),
                         mayReach: (() -> Void)? = nil) async throws -> RealmReply {
        let credentials = try await ensureCredentials()
        do {
            try await transport.call(reducer, [.string(nonce)] + arguments, token: credentials.token)
        } catch {
            if !Self.neverLeftThisMac(error), (error as? SpacetimeError)?.isUnauthorized != true { mayReach?() }
            throw error
        }
        mayReach?()
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

    /// Whether an error proves a request never left this Mac: no network,
    /// no such server, or no connection made. A request lost on the way
    /// back, or one the server was slow to take, may have reached it.
    nonisolated static func neverLeftThisMac(_ error: any Error) -> Bool {
        guard let url = error as? URLError else { return false }
        switch url.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .cannotFindHost, .dnsLookupFailed,
             .cannotConnectToHost, .secureConnectionFailed, .badURL, .unsupportedURL:
            return true
        default:
            return false
        }
    }

    /// Whether a request still waits at the realm for its steward.
    private func isWaitingAtRealm(_ nonce: String, _ credentials: SpacetimeCredentials) async throws -> Bool {
        let rows = try await transport.query("SELECT nonce FROM my_requests WHERE nonce = \(sqlString(nonce))", token: credentials.token)
        return rows.contains { $0.first?.string == nonce }
    }

    /// The steward's answer to a request, if it has given one: that answer's
    /// row alone, not every answer still kept for the keeper.
    private func answer(to nonce: String, _ credentials: SpacetimeCredentials) async throws -> RealmReply? {
        let rows = try await transport.query("SELECT * FROM my_replies WHERE nonce = \(sqlString(nonce))", token: credentials.token)
        guard let row = rows.first(where: { $0.first?.string == nonce }), row.count == 3, let text = row[2].string else { return nil }
        return try JSONDecoder().decode(RealmReply.self, from: Data(text.utf8))
    }

    /// Waits for the steward to publish what came of a request, and takes
    /// the view it published.
    private func catchUp() async throws {
        let credentials = try await ensureCredentials()
        let seen = viewVersion
        for _ in 0..<50 {
            // Taken meanwhile, by a poll.
            if viewVersion > seen { return }
            // Its version first: the whole view only once it has moved on.
            if let number = try await viewHead(credentials), number > seen,
               let (version, fresh, batches) = try await fetchView(credentials), version > seen {
                deliver(fresh, version: version, heard: batches)
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    /// The realm was begun anew and doesn't know this keeper: what was asked
    /// of it and what was read from it go, and the keeper goes back to the
    /// door, not orders no one will carry out.
    private func forgottenByTheRealm() {
        arrived = false
        outbox.removeAll()
        hereAwaited = nil
        view = nil
        viewVersion = 0
        viewParts = [:]
        partsThrough = 0
        viewReadAt = nil
        heardThrough = 0
        askedReady = nil
        onEvent?(.refused(.unknownKeeper))
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
                // Told as it may reach the realm, while it is still this
                // sender's errand.
                let reached = { [weak self] in
                    guard let self, self.outbox.first?.nonce == next.nonce else { return }
                    self.outbox[0].mayHaveReached = true
                }
                do {
                    let reply: RealmReply
                    if expired, !next.mayHaveReached {
                        // Too old to send, and it never reached the realm:
                        // let go, and the keeper told so.
                        self.outbox.removeFirst()
                        if let world = self.view?.world {
                            self.onEvent?(.orderRefused(.refused(Self.tooOldToSend), world))
                        }
                        continue
                    } else if expired {
                        // Past its time, and it may have reached the realm:
                        // never sent again, which could carry it out twice,
                        // only asked after. Waiting there, its steward will
                        // answer it; answered, the answer is taken; neither,
                        // and what came of it is the world's to show.
                        let credentials = try await self.ensureCredentials()
                        if try await self.isWaitingAtRealm(next.nonce, credentials) {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            delay = min(delay * 2, Self.retryLimit)
                            continue
                        }
                        guard let kept = try await self.answer(to: next.nonce, credentials) else {
                            // Left, or forgotten by the realm, while it was
                            // asked after: the outbox is gone, and so is
                            // this sender's errand.
                            guard !Task.isCancelled, self.outbox.first?.nonce == next.nonce else { break }
                            self.outbox.removeFirst()
                            if let world = self.view?.world {
                                self.onEvent?(.orderRefused(.refused(Self.unanswered), world))
                            }
                            continue
                        }
                        reply = kept
                    } else {
                        switch next.kind {
                        case .order(let command):
                            let text = String(decoding: try JSONEncoder().encode(command), as: UTF8.self)
                            reply = try await self.request("order", [.string(text)], nonce: next.nonce, mayReach: reached)
                        case .ready(let ready, let watch?):
                            reply = try await self.request("ready_in_watch", [.bool(ready), .integer(UInt64(max(watch, 0)))], nonce: next.nonce, mayReach: reached)
                        case .ready(let ready, nil):
                            reply = try await self.request("ready", [.bool(ready)], nonce: next.nonce, mayReach: reached)
                        }
                    }
                    // The realm was begun anew and doesn't know this keeper.
                    if reply.unknownKeeper == true {
                        self.forgottenByTheRealm()
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

    /// Leaves the realm. What the keeper ordered and hasn't yet seen answered
    /// is sent first, as it would be in the world, then the leaving: an
    /// order given just before leaving is carried out, not dropped. The link
    /// stays until both are done, though nothing more is told.
    public func leave() {
        onEvent = nil
        arrived = false
        polling?.cancel()
        polling = nil
        stopWatching()
        let waiting = sending
        Task { [self] in
            await waiting?.value
            _ = try? await request("leave", [])
        }
    }

    public func close() {
        onEvent = nil
        arrived = false
        polling?.cancel()
        polling = nil
        stopWatching()
        sending?.cancel()
        sending = nil
        outbox.removeAll()
    }

    private func stopWatching() {
        watch?.stop()
        watch = nil
        watchAsked = false
    }

    nonisolated static func nonce() -> String {
        KeeperIdentity.make()
    }

    /// An order that never reached the realm, let go when its time ran out.
    public static let tooOldToSend = "An order given while the realm was out of reach was too old to send."
    /// An order that may have reached the realm, past its time, neither
    /// waiting there nor answered: the realm won't carry it out from now
    /// on, and the world shows whether it did.
    public static let unanswered = "An order sent as the realm went out of reach was never answered; the world shows whether it was carried out."
}
