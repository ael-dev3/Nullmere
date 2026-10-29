import Foundation
import NullmereCore

/// The steward's answer to one request, as the client reads it.
public struct RealmReply: Codable, Equatable, Sendable {
    public let ok: Bool
    /// The keeper, after an arrival.
    public let keeper: Keeper?
    /// Why it was refused.
    public let refusal: String?
    /// What the keeper hears of their order, as the realm carried it out.
    public let events: [GameEvent]?

    public init(ok: Bool, keeper: Keeper?, refusal: String?, events: [GameEvent]? = nil) {
        self.ok = ok
        self.keeper = keeper
        self.refusal = refusal
        self.events = events
    }

    public static let done = RealmReply(ok: true, keeper: nil, refusal: nil)

    public static func refused(_ error: RealmError) -> RealmReply {
        RealmReply(ok: false, keeper: nil, refusal: error.description)
    }
}

/// What a keeper heard with one publication. A keeper's view carries the
/// last few, so a client that missed a publication (its own order on the
/// way, a slow poll) still hears what it brought, and each once: those up
/// to the version it last read are passed over.
public struct HeardBatch: Codable, Equatable, Sendable {
    public let version: UInt64
    public let events: [GameEvent]

    public init(version: UInt64, events: [GameEvent]) {
        self.version = version
        self.events = events
    }
}

/// The realm as published: its whole state, its status, and what the last
/// change brought.
public struct PublishedRealm: Equatable, Sendable {
    public let version: UInt64
    public let state: RealmState
    public let status: RealmStatus
    public let events: [GameEvent]
}

/// The steward: the trusted process that runs the realm's rules. It reads
/// the keepers' requests from SpacetimeDB in the order they came, carries
/// them out with the rules core, answers each, and publishes the realm.
/// SpacetimeDB lets no one else write the world.
public actor RealmSteward {
    private let transport: any SpacetimeTransport
    private let token: String
    public private(set) var state: RealmState
    public private(set) var version: UInt64
    private var lastStatus: RealmStatus?
    /// When each keeper was last heard from.
    private var heard: [String: Double] = [:]
    /// Requests carried out whose answers wait for the next publication,
    /// which keeps the world and gives them in one transaction.
    private var unanswered: [(id: UInt64, nonce: String, reply: String)] = []
    /// The world changed since it was last published.
    private var worldChanged = false
    /// Events since the last publication, for the keepers to hear.
    private var pendingEvents: [GameEvent] = []
    /// What keepers' orders did since the last publication, and whose:
    /// each other keeper hears what reaches them; no one is told their own.
    private var pendingActs: [(by: String, events: [GameEvent])] = []
    /// When the steward last said how the realm stands, and failed.
    private var lastReport = 0.0
    private var failures = 0
    private var lastHealth = 0.0
    private var lastPublished = 0.0
    /// This steward's own name for itself, for its hold on the realm.
    public let holder = KeeperIdentity.make()
    /// Another steward holds the realm: this one has stopped.
    public private(set) var isDisplaced = false
    /// The longest a steward goes without publishing, so its hold on the
    /// realm (a minute) never lapses while it runs.
    public static let heartbeat = 20.0
    /// How often a running steward says how the realm stands.
    public static let healthEvery = 600.0
    /// Answers given, and when, until they are forgotten.
    private var answered: [(nonce: String, at: Double)] = []
    private var lastForgotten = 0.0
    /// Each keeper's view as last published, to send only what changed.
    private var published: [String: String] = [:]
    /// What each keeper there heard lately, and when: published with their
    /// view until it is old enough to have been read.
    private var recentlyHeard: [String: [(at: Double, batch: HeardBatch)]] = [:]
    /// How long what a keeper heard is published with their view.
    public static let heardKept = 120.0

    /// Seconds of silence after which a keeper is taken to have left.
    public static let silence = 90.0
    /// Most requests of one keeper carried out in a round.
    public static let requestsPerRound = 8
    /// How long an answer is kept: longer than a client keeps an order
    /// waiting to be sent again, so an order sent twice is carried out once.
    public static let answerKept = 600.0

    /// Takes up the realm where SpacetimeDB holds it, or begins a new one.
    public init(transport: any SpacetimeTransport, token: String, name: String, seed: String, seats: Int = RealmState.defaultSeats,
                watchLength: Double = RealmState.defaultWatchLength, now: Double) async throws {
        self.transport = transport
        self.token = token
        let rows = try await transport.query("SELECT version, state FROM world", token: token)
        if let row = rows.first, row.count == 2, let version = row[0].number, let text = row[1].string,
           let state = try? JSONDecoder().decode(RealmState.self, from: Data(text.utf8)) {
            self.state = state
            // Versions run on past the last status, never back.
            let status = try await transport.query("SELECT version FROM status", token: token)
            self.version = max(UInt64(version), status.first?.first?.number.map { UInt64($0) } ?? 0)
        } else {
            self.state = RealmState(name: name, seed: seed, seats: seats, watchLength: watchLength, now: now)
            self.version = 0
        }
        // Whoever was there when the steward last stopped is gone now.
        for keeper in state.keepers where keeper.isOnline {
            state.depart(keeper.id, now: now)
        }
        worldChanged = true
        try await publish(now: now)
    }

    /// One round: every waiting request, then the clock. Returns whether
    /// the realm changed.
    @discardableResult
    public func step(now: Double) async throws -> Bool {
        var changed = false
        let rows = try await transport.query("SELECT id, keeper, kind, nonce, payload FROM request", token: token)
        let requests = rows.compactMap { row -> (id: UInt64, keeper: String, kind: String, nonce: String, payload: String)? in
            guard row.count == 5, let id = row[0].number, let keeper = row[1].string, let kind = row[2].string,
                  let nonce = row[3].string, let payload = row[4].string else { return nil }
            return (UInt64(id), keeper, kind, nonce, payload)
        }.sorted { $0.id < $1.id }

        // A few of each keeper's requests a round, so no one keeper can
        // crowd out the rest; the others wait for the next.
        var taken: [String: Int] = [:]
        let fair = requests.filter { request in
            taken[request.keeper, default: 0] += 1
            return taken[request.keeper]! <= RealmSteward.requestsPerRound
        }
        let waiting = Set(unanswered.map(\.id))
        for request in fair where !waiting.contains(request.id) {
            heard[request.keeper] = now
            // A keeper taken to have left (by silence, or a steward
            // starting anew) who is still playing is back: any request but
            // leaving says so, so their readiness counts again.
            if request.kind != "arrive", request.kind != "leave", state.keeper(request.keeper)?.isOnline == false {
                _ = try? state.arrive(request.keeper, name: nil, now: now, reseatsTheFallen: false)
                changed = true
            }
            let (reply, didChange, turned) = handle(kind: request.kind, keeper: request.keeper, payload: request.payload, now: now)
            changed = changed || didChange
            pendingEvents += turned
            unanswered.append((request.id, request.nonce, String(decoding: try JSONEncoder().encode(reply), as: UTF8.self)))
        }

        // The silent have left.
        for keeper in state.keepers where keeper.isOnline && now - (heard[keeper.id] ?? now) > RealmSteward.silence {
            state.depart(keeper.id, now: now)
            changed = true
        }
        if let turned = state.tick(now: now) {
            pendingEvents += turned
            changed = true
            // A world gone wrong is said at once, for whoever runs the realm.
            let problems = state.world.problems()
            if !problems.isEmpty {
                report("The world is unsound at watch \(state.world.watch): " + problems.prefix(3).joined(separator: "; "))
            }
        }
        if changed { worldChanged = true }
        let status = state.status(now: now)
        if worldChanged || !unanswered.isEmpty || status.online != lastStatus?.online || status.ready != lastStatus?.ready
            || status.present != lastStatus?.present || now - lastPublished > RealmSteward.heartbeat {
            // Should it fail, the next round publishes all of it again.
            try await publish(now: now)
        }
        // Answers old enough to have been read are forgotten.
        let old = answered.prefix { now - $0.at > RealmSteward.answerKept }
        if !old.isEmpty, old.count >= 64 || now - lastForgotten > 30 {
            try await transport.call("forget", [.strings(old.map(\.nonce))], token: token)
            answered.removeFirst(old.count)
            lastForgotten = now
        }
        return changed
    }

    private func handle(kind: String, keeper: String, payload: String, now: Double) -> (RealmReply, Bool, [GameEvent]) {
        switch kind {
        case "arrive":
            do {
                let arrived = try state.arrive(keeper, name: payload.isEmpty ? nil : payload, now: now)
                return (RealmReply(ok: true, keeper: arrived, refusal: nil), true, [])
            } catch {
                return (.refused(error), false, [])
            }
        case "order":
            guard let command = try? JSONDecoder().decode(Command.self, from: Data(payload.utf8)) else {
                return (.refused(.refused("The order couldn't be read.")), false, [])
            }
            do {
                let done = try state.perform(command, by: keeper)
                // The others hear of it with the next publication; the
                // keeper, with the answer.
                if !done.isEmpty { pendingActs.append((keeper, done)) }
                let heard = state.keeper(keeper)?.house.map { state.world.events(done, heardBy: $0) } ?? []
                return (RealmReply(ok: true, keeper: nil, refusal: nil, events: heard.isEmpty ? nil : heard), true, [])
            } catch {
                return (.refused(error), false, [])
            }
        case "ready":
            if let turned = state.setReady(keeper, payload == "true", now: now) {
                return (.done, true, turned)
            }
            return (.done, true, [])
        case "here":
            return (.done, false, [])
        case "leave":
            state.depart(keeper, now: now)
            return (.done, true, [])
        default:
            return (.refused(.refused("The realm doesn't know that request.")), false, [])
        }
    }

    /// The realm refused a publication because another steward holds it.
    public static func isHeldByAnother(_ error: any Error) -> Bool {
        String(describing: error).contains("Another steward holds the realm")
    }

    /// "Age 1, watch 40: 3 keepers there of 5, 7 seats free of 12."
    public static func health(_ status: RealmStatus) -> String {
        "Age \(status.age), watch \(status.watch): \(status.online) keeper\(status.online == 1 ? "" : "s") there of \(status.keepers), "
            + "\(status.freeSeats) seat\(status.freeSeats == 1 ? "" : "s") free of \(status.seats)."
    }

    /// What the steward has to say, for whoever runs it.
    public var onReport: (@Sendable (String) -> Void)?

    public func setReporter(_ reporter: @escaping @Sendable (String) -> Void) {
        onReport = reporter
    }

    private func report(_ line: String) {
        onReport?(line)
    }

    /// Publishes the realm: the world if it changed, the status, the views
    /// that changed with what each keeper heard lately, and the answers
    /// waiting. Only the keepers there are shown their view: one who comes
    /// back is shown it as they arrive. Nothing is taken as published until
    /// the server has it.
    private func publish(now: Double = Date().timeIntervalSince1970) async throws {
        let encoder = JSONEncoder()
        let status = state.status(now: now)
        var keepers: [String] = [], views: [String] = [], heard: [String] = []
        var shown: [String: String] = [:]
        var lately: [String: [(at: Double, batch: HeardBatch)]] = [:]
        for keeper in state.keepers where keeper.isOnline {
            guard let view = state.view(for: keeper.id) else { continue }
            let text = String(decoding: try encoder.encode(view), as: UTF8.self)
            let others = pendingActs.filter { $0.by != keeper.id }.flatMap(\.events)
            let events = keeper.house.map { state.world.events(others + pendingEvents, heardBy: $0) } ?? []
            var batches = (recentlyHeard[keeper.id] ?? []).filter { now - $0.at <= RealmSteward.heardKept }
            lately[keeper.id] = batches
            guard text != published[keeper.id] || !events.isEmpty else { continue }
            if !events.isEmpty { batches.append((now, HeardBatch(version: version + 1, events: events))) }
            lately[keeper.id] = batches
            shown[keeper.id] = text
            keepers.append(keeper.id)
            views.append(text)
            heard.append(String(decoding: try encoder.encode(batches.map(\.batch)), as: UTF8.self))
        }
        let answers = unanswered
        do {
            try await transport.call("publish", [
                .integer(version + 1),
                .string(worldChanged ? String(decoding: try encoder.encode(state), as: UTF8.self) : ""),
                .string(String(decoding: try encoder.encode(status), as: UTF8.self)),
                .strings(keepers),
                .strings(views),
                .strings(heard),
                .integers(answers.map(\.id)),
                .strings(answers.map(\.reply)),
                .string(holder),
            ], token: token)
        } catch {
            if RealmSteward.isHeldByAnother(error) { isDisplaced = true }
            throw error
        }
        lastPublished = now
        version += 1
        lastStatus = status
        published.merge(shown) { $1 }
        recentlyHeard = lately
        pendingEvents = []
        pendingActs = []
        worldChanged = false
        unanswered.removeFirst(answers.count)
        answered += answers.map { ($0.nonce, now) }
    }

    /// Runs the realm until cancelled, a step every quarter second.
    public func run(clock: @Sendable () -> Double = { Date().timeIntervalSince1970 }) async {
        while !Task.isCancelled, !isDisplaced {
            let now = clock()
            do {
                try await step(now: now)
                if failures > 0 {
                    report("The server answers again after \(failures) failed round\(failures == 1 ? "" : "s").")
                    failures = 0
                }
                if now - lastHealth > RealmSteward.healthEvery {
                    lastHealth = now
                    report(RealmSteward.health(state.status(now: now)))
                }
            } catch where isDisplaced {
                report("Another steward holds the realm; this one stops. \(error)")
            } catch {
                // The server will be there again; the next round tries anew,
                // with all that waits. Said once a minute at most.
                failures += 1
                if now - lastReport > 60 {
                    lastReport = now
                    report("A round failed (\(failures) so far): \(error)")
                }
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }
}
