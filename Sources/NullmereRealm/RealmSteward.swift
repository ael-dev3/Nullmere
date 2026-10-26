import Foundation
import NullmereCore

/// The steward's answer to one request, as the client reads it.
public struct RealmReply: Codable, Equatable, Sendable {
    public let ok: Bool
    /// The keeper, after an arrival.
    public let keeper: Keeper?
    /// Why it was refused.
    public let refusal: String?

    public static let done = RealmReply(ok: true, keeper: nil, refusal: nil)

    public static func refused(_ error: RealmError) -> RealmReply {
        RealmReply(ok: false, keeper: nil, refusal: error.description)
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
    private var lastEvents: [GameEvent] = []
    private var lastStatus: RealmStatus?
    /// When each keeper was last heard from.
    private var heard: [String: Double] = [:]
    /// Answers given, and when, until they are forgotten.
    private var answered: [(nonce: String, at: Double)] = []
    private var lastForgotten = 0.0
    /// Each keeper's view as last published, to send only what changed.
    private var published: [String: String] = [:]

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
            self.version = UInt64(version)
        } else {
            self.state = RealmState(name: name, seed: seed, seats: seats, watchLength: watchLength, now: now)
            self.version = 0
        }
        // Whoever was there when the steward last stopped is gone now.
        for keeper in state.keepers where keeper.isOnline {
            state.depart(keeper.id, now: now)
        }
        try await publish()
    }

    /// One round: every waiting request, then the clock. Returns whether
    /// the realm changed.
    @discardableResult
    public func step(now: Double) async throws -> Bool {
        var changed = false
        var events: [GameEvent] = []
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
        for request in fair {
            heard[request.keeper] = now
            let (reply, didChange, turned) = handle(kind: request.kind, keeper: request.keeper, payload: request.payload, now: now)
            changed = changed || didChange
            events += turned
            let text = String(decoding: try JSONEncoder().encode(reply), as: UTF8.self)
            try await transport.call("settle", [.integer(request.id), .string(text)], token: token)
            answered.append((request.nonce, now))
        }

        // The silent have left.
        for keeper in state.keepers where keeper.isOnline && now - (heard[keeper.id] ?? now) > RealmSteward.silence {
            state.depart(keeper.id, now: now)
            changed = true
        }
        if let turned = state.tick(now: now) {
            events += turned
            changed = true
        }
        lastEvents = events
        let status = state.status(now: now)
        if changed || status.online != lastStatus?.online || status.ready != lastStatus?.ready {
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
                _ = try state.perform(command, by: keeper)
                return (.done, true, [])
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

    /// Publishes the realm: whole, for the steward; its status, for
    /// everyone; and each keeper's own view, where it changed, with the
    /// events they heard.
    private func publish(now: Double = Date().timeIntervalSince1970) async throws {
        version += 1
        let encoder = JSONEncoder()
        let status = state.status(now: now)
        lastStatus = status
        var keepers: [String] = [], views: [String] = [], heard: [String] = []
        for keeper in state.keepers {
            guard let view = state.view(for: keeper.id) else { continue }
            let text = String(decoding: try encoder.encode(view), as: UTF8.self)
            let events = keeper.house.map { state.world.events(lastEvents, heardBy: $0) } ?? []
            guard text != published[keeper.id] || !events.isEmpty else { continue }
            published[keeper.id] = text
            keepers.append(keeper.id)
            views.append(text)
            heard.append(String(decoding: try encoder.encode(events), as: UTF8.self))
        }
        try await transport.call("publish", [
            .integer(version),
            .string(String(decoding: try encoder.encode(state), as: UTF8.self)),
            .string(String(decoding: try encoder.encode(status), as: UTF8.self)),
            .strings(keepers),
            .strings(views),
            .strings(heard),
        ], token: token)
        lastEvents = []
    }

    /// Runs the realm until cancelled, a step every quarter second.
    public func run(clock: @Sendable () -> Double = { Date().timeIntervalSince1970 }) async {
        while !Task.isCancelled {
            do {
                try await step(now: clock())
            } catch {
                // The server will be there again; the next step tries anew.
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }
}
