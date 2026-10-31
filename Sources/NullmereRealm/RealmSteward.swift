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
    /// The realm doesn't know this keeper (it was begun anew): the client
    /// goes back to the door rather than giving orders no one will carry.
    public let unknownKeeper: Bool?

    public init(ok: Bool, keeper: Keeper?, refusal: String?, events: [GameEvent]? = nil, unknownKeeper: Bool? = nil) {
        self.ok = ok
        self.keeper = keeper
        self.refusal = refusal
        self.events = events
        self.unknownKeeper = unknownKeeper
    }

    public static let done = RealmReply(ok: true, keeper: nil, refusal: nil)

    public static func refused(_ error: RealmError) -> RealmReply {
        RealmReply(ok: false, keeper: nil, refusal: error.description, unknownKeeper: error == .unknownKeeper ? true : nil)
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

/// Why a steward can't take up its realm.
public enum StewardError: Error, Equatable, CustomStringConvertible {
    /// SpacetimeDB keeps a world this steward can't read: a part missing,
    /// or from a version of the rules it doesn't know.
    case unreadableWorld(String)

    public var description: String {
        switch self {
        case .unreadableWorld(let why):
            return "The realm's world is kept but can't be read (\(why)); the steward won't begin a new one over it."
        }
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
    /// When each keeper last left by their own request.
    private var left: [String: Double] = [:]
    /// How long after leaving a keeper's "here" is taken as one already on
    /// its way when they left, not as their return.
    public static let leavingGrace = 15.0
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
    /// Each keeper's view as last published, in its parts, to send only
    /// the parts that changed; and the version each part was written at.
    private var published: [String: [String: String]] = [:]
    private var publishedAt: [String: [String: UInt64]] = [:]
    /// The world's parts as SpacetimeDB keeps them, to send only those
    /// that changed.
    private var keptParts: [String: String] = [:]
    /// The last publication failed: whether SpacetimeDB kept it is unknown.
    private var unsure = false
    /// What each keeper there heard lately, and when: published with their
    /// view until it is old enough to have been read.
    private var recentlyHeard: [String: [(at: Double, batch: HeardBatch)]] = [:]
    /// How long what a keeper heard is published with their view.
    public static let heardKept = 120.0
    /// The most publications' worth of what a keeper heard that goes with
    /// their view, however busy the realm: the latest.
    public static let heardBatches = 16
    /// Views worked out and written for publication, for tests.
    private(set) var viewsWorkedOut = 0
    /// Keepers the steward keeps anything of, for tests: those there alone.
    var keepersRemembered: Int { Set(heard.keys).union(left.keys).union(published.keys).union(recentlyHeard.keys).count }

    /// The realms this one borders, by their addresses: the Frontier, for a
    /// home realm; the home realms, for the Frontier. Their status is read
    /// as any keeper may read it.
    private var borders: [(address: String, transport: any SpacetimeTransport)] = []
    private var lastBorders = -Double.infinity
    /// How often the realms it borders are read.
    public static let bordersEvery = 5.0

    /// Seconds of silence after which a keeper is taken to have left.
    public static let silence = 90.0
    /// Most requests of one keeper carried out in a round.
    public static let requestsPerRound = 8
    /// How long an answer is kept: longer than a client keeps an order
    /// waiting to be sent again, so an order sent twice is carried out once.
    public static let answerKept = 600.0
    /// Most answers forgotten in one call.
    public static let forgottenAtOnce = 512

    /// Takes up the realm where SpacetimeDB holds it, or begins a new one:
    /// the Frontier where the realms meet, when `frontier`.
    public init(transport: any SpacetimeTransport, token: String, name: String, seed: String, seats: Int = RealmState.defaultSeats,
                watchLength: Double = RealmState.defaultWatchLength, frontier: Bool = false, now: Double) async throws {
        self.transport = transport
        self.token = token
        let parts = try await RealmSteward.keptParts(transport, token: token)
        keptParts = parts
        // Versions run on past the last status, never back.
        self.version = try await RealmSteward.statusVersion(transport, token: token)
        if !parts.isEmpty {
            // A world kept that can't be read is refused, never begun anew
            // over: that would wipe every keeper's House. Whoever runs the
            // realm is told, and steps in.
            do {
                self.state = try RealmState(parts: parts)
            } catch {
                throw StewardError.unreadableWorld(String(describing: error))
            }
            self.state.fillIn()
        } else if let legacy = try await transport.query("SELECT version, state FROM world", token: token).first {
            // A realm kept whole, from before the world was kept in parts:
            // taken up, and kept in parts from now on. As with parts, one
            // that can't be read is refused, never begun anew over; and a
            // failure to ask is a failure, not an empty realm.
            guard legacy.count == 2, let text = legacy[1].string,
                  let state = try? JSONDecoder().decode(RealmState.self, from: Data(text.utf8)) else {
                throw StewardError.unreadableWorld("the world kept whole, from before parts")
            }
            self.state = state
            self.state.fillIn()
        } else if frontier {
            self.state = RealmState(frontier: name, seed: seed, seats: seats, watchLength: watchLength, now: now)
        } else {
            self.state = RealmState(name: name, seed: seed, seats: seats, watchLength: watchLength, now: now)
        }
        // Whoever was there when the steward last stopped is gone now.
        for keeper in state.keepers where keeper.isOnline {
            state.depart(keeper.id, now: now)
        }
        // Answers an earlier steward gave are forgotten in their time too,
        // not kept for ever.
        let kept = try await transport.query("SELECT nonce FROM reply", token: token)
        answered = kept.compactMap { $0.first?.string }.map { ($0, now) }
        worldChanged = true
        try await publish(now: now)
    }

    /// A realm this one borders, at its address.
    public func border(_ transport: any SpacetimeTransport, at address: String) {
        borders.append((address, transport))
    }

    /// Reads the realms it borders, every `bordersEvery` seconds: a home
    /// realm hears how the Frontier stands, and is told once of each season
    /// ended there; the Frontier hears who each realm lists as crossing.
    /// One that can't be read now is read next time. Returns whether the
    /// realm changed.
    func hearBorders(now: Double) async -> Bool {
        guard !borders.isEmpty, now - lastBorders >= RealmSteward.bordersEvery else { return false }
        lastBorders = now
        var changed = false
        for border in borders {
            guard let row = try? await border.transport.query("SELECT version, status FROM status", token: token).first,
                  row.count == 2, let text = row[1].string,
                  let status = try? JSONDecoder().decode(RealmStatus.self, from: Data(text.utf8)) else { continue }
            if state.frontier != nil {
                let before = state.frontier?.admitted
                state.admit(status.crossings ?? [], from: status.name)
                changed = changed || state.frontier?.admitted != before
            } else if var news = status.frontier, news.address.isEmpty {
                news.address = border.address
                let before = state.frontierNews
                let told = state.hearFrontier(news)
                if !told.isEmpty { pendingActs.append(("", told)) }
                changed = changed || state.frontierNews != before || !told.isEmpty
            }
        }
        return changed
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
            let justLeft = now - (left[request.keeper] ?? -.infinity) < RealmSteward.leavingGrace
            if request.kind != "arrive", request.kind != "leave", !(request.kind == "here" && justLeft),
               state.keeper(request.keeper)?.isOnline == false {
                _ = try? state.arrive(request.keeper, name: nil, now: now, reseatsTheFallen: false)
                let raised = state.takeArrivals()
                if !raised.isEmpty { pendingActs.append((request.keeper, raised)) }
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
        // Those long gone without a seat are forgotten; and of keepers the
        // steward keeps only what it needs of those there, so neither the
        // realm nor the steward grows with every identity ever heard from.
        if state.forgetTheLongGone(now: now) { changed = true }
        if await hearBorders(now: now) { changed = true }
        let there = Set(state.keepers.lazy.filter(\.isOnline).map(\.id))
        heard = heard.filter { there.contains($0.key) }
        left = left.filter { now - $0.value < RealmSteward.leavingGrace }
        if let turned = state.tick(now: now) {
            pendingEvents += turned
            changed = true
            // A world gone wrong is said at once, for whoever runs the realm.
            let problems = state.world.problems()
            if !problems.isEmpty {
                report("The world is unsound at watch \(state.world.watch): " + problems.prefix(3).joined(separator: "; "))
            }
        } else {
            // The watch walked on a pace: what came of it is heard by every
            // keeper there, as another's orders are, and the pace kept, so a
            // steward starting anew doesn't walk it twice.
            let walked = state.world.pacing
            let paced = state.pace(now: now)
            if !paced.isEmpty { pendingActs.append(("", paced)) }
            if state.world.pacing != walked { changed = true }
        }
        if changed { worldChanged = true }
        let status = state.status(now: now)
        if worldChanged || !unanswered.isEmpty || status.online != lastStatus?.online || status.ready != lastStatus?.ready
            || status.present != lastStatus?.present || now - lastPublished > RealmSteward.heartbeat {
            // Should it fail, the next round publishes all of it again.
            try await publish(now: now)
        }
        // Answers old enough to have been read are forgotten, a few hundred
        // at a time: those an earlier steward left may be many.
        let old = answered.prefix { now - $0.at > RealmSteward.answerKept }.prefix(RealmSteward.forgottenAtOnce)
        if !old.isEmpty, old.count >= 64 || now - lastForgotten > 30 {
            try await transport.call("forget", [.strings(old.map(\.nonce))], token: token)
            answered.removeFirst(old.count)
            lastForgotten = now
        }
        return changed
    }

    /// An order of whoever runs the realm, in plain words, carried out now
    /// and heard by the keepers with the next publication: "remove 123"
    /// takes line 123 out of the Words; "bar 4 20" bars House 4 from them
    /// for twenty watches. What was done, or why nothing was, in a line.
    public func obey(_ order: String) -> String {
        let words = order.split(separator: " ").map(String.init)
        switch (words.first?.lowercased(), words.dropFirst().compactMap { Int($0) }) {
        case ("remove", let numbers) where numbers.count == 1:
            let done = state.removeWord(numbers[0])
            guard !done.isEmpty else { return "No line \(numbers[0]) is kept in the Words." }
            pendingActs.append(("", done))
            worldChanged = true
            return "Took line \(numbers[0]) out of the Words."
        case ("bar", let numbers) where numbers.count == 2:
            let done = state.bar(numbers[0], fromWordsFor: numbers[1])
            guard case .barredFromWords(_, let until)? = done.first else { return "No House \(numbers[0]) to bar, or no watches to bar it for." }
            pendingActs.append(("", done))
            worldChanged = true
            return "Barred \(state.world.houses[numbers[0]].title) from the Words until watch \(until)."
        case ("forget", _) where words.count > 1:
            // A keeper who asked to be forgotten, by the name they go by.
            let name = words.dropFirst().joined(separator: " ")
            guard let gone = state.forget(keeperNamed: name) else { return "No keeper goes by \(name)." }
            worldChanged = true
            let house = gone.house.map { " \(state.world.houses[$0].title) is the stewards' to keep." } ?? ""
            return "Forgot \(gone.name) and their identity.\(house)"
        default:
            return "Not an order the steward knows: \(order). Orders: remove <line>, bar <House> <watches>, forget <keeper>."
        }
    }

    /// A line reported, told to whoever runs the realm with what was said
    /// round it, as the realm keeps it.
    private func tellReports(_ events: [GameEvent]) {
        for case .wordReported(let id, let by) in events {
            guard let kept = state.world.wordReports.last(where: { $0.word == id && $0.by == by }) else { continue }
            let houses = state.world.houses
            func name(_ house: Int) -> String { houses.indices.contains(house) ? "\(houses[house].title) (\(house))" : "House \(house)" }
            let lines = kept.context.map { "\($0.id == id ? ">" : " ") \($0.id) \(name($0.from)): \($0.text)" }
            report("REPORT by \(name(by)) of line \(id), watch \(kept.watch):\n" + lines.joined(separator: "\n"))
        }
    }

    private func handle(kind: String, keeper: String, payload: String, now: Double) -> (RealmReply, Bool, [GameEvent]) {
        switch kind {
        case "arrive":
            do {
                let arrived = try state.arrive(keeper, name: payload.isEmpty ? nil : payload, now: now)
                // A House raised at the Frontier: its keeper hears it with
                // the answer, the others with the next publication.
                let raised = state.takeArrivals()
                if !raised.isEmpty { pendingActs.append((keeper, raised)) }
                let heard = arrived.house.map { state.world.events(raised, heardBy: $0) } ?? []
                return (RealmReply(ok: true, keeper: arrived, refusal: nil, events: heard.isEmpty ? nil : heard), true, [])
            } catch {
                return (.refused(error), false, [])
            }
        case "order":
            guard let command = try? JSONDecoder().decode(Command.self, from: Data(payload.utf8)) else {
                return (.refused(.refused("The order couldn't be read.")), false, [])
            }
            do {
                let done = try state.perform(command, by: keeper)
                tellReports(done)
                // The others hear of it with the next publication; the
                // keeper, with the answer.
                if !done.isEmpty { pendingActs.append((keeper, done)) }
                let heard = state.keeper(keeper)?.house.map { state.world.events(done, heardBy: $0) } ?? []
                return (RealmReply(ok: true, keeper: nil, refusal: nil, events: heard.isEmpty ? nil : heard), true, [])
            } catch {
                return (.refused(error), false, [])
            }
        case "ready":
            guard state.keeper(keeper) != nil else { return (.refused(.unknownKeeper), false, []) }
            // "true@12": ready in watch 12. Readiness sent for a watch
            // already gone (sent before the line dropped, and carried only
            // now) is not readiness for this one.
            let parts = payload.split(separator: "@")
            if parts.count == 2, Int(parts[1]) != state.world.watch { return (.done, false, []) }
            if let turned = state.setReady(keeper, parts.first == "true", now: now) {
                return (.done, true, turned)
            }
            return (.done, true, [])
        case "here":
            guard state.keeper(keeper) != nil else { return (.refused(.unknownKeeper), false, []) }
            return (.done, false, [])
        case "leave":
            left[keeper] = now
            state.depart(keeper, now: now)
            return (.done, true, [])
        case "seal":
            do {
                try state.seal(keeper, proof: payload)
                return (.done, true, [])
            } catch {
                return (.refused(error), false, [])
            }
        case "reclaim":
            // The keeper the words seal, taken up by this Mac's identity
            // and arrived by it, as "arrive" answers.
            do {
                let arrived = try state.reclaim(keeper, proof: payload, now: now)
                return (RealmReply(ok: true, keeper: arrived, refusal: nil, events: nil), true, [])
            } catch {
                return (.refused(error), false, [])
            }
        default:
            return (.refused(.refused("The realm doesn't know that request.")), false, [])
        }
    }

    /// The parts of a keeper's view and the version each was written at,
    /// as their row of `keeper_view` carries them: "head:12,map:3,units.0:12".
    static func manifest(_ versions: [String: UInt64]) -> String {
        versions.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ",")
    }

    /// The world's parts as SpacetimeDB keeps them, by name.
    private static func keptParts(_ transport: any SpacetimeTransport, token: String) async throws -> [String: String] {
        let rows = try await transport.query("SELECT name, text FROM world_part", token: token)
        return Dictionary(rows.compactMap { row -> (String, String)? in
            guard row.count == 2, let name = row[0].string, let text = row[1].string else { return nil }
            return (name, text)
        }, uniquingKeysWith: { $1 })
    }

    private static func statusVersion(_ transport: any SpacetimeTransport, token: String) async throws -> UInt64 {
        let status = try await transport.query("SELECT version FROM status", token: token)
        return status.first?.first?.number.map { UInt64($0) } ?? 0
    }

    /// The realm refused a publication because another steward holds it.
    public static func isHeldByAnother(_ error: any Error) -> Bool {
        String(describing: error).contains("Another steward holds the realm")
    }

    /// "Age 1, watch 40: 3 keepers there of 5, 7 seats open of 12."
    public static func health(_ status: RealmStatus) -> String {
        "Age \(status.age), watch \(status.watch): \(status.online) keeper\(status.online == 1 ? "" : "s") there of \(status.keepers), "
            + "\(status.freeSeats) seat\(status.freeSeats == 1 ? "" : "s") open of \(status.seats)."
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
        // A publication that failed may have been kept all the same, its
        // answer lost on the way back: what SpacetimeDB holds is read
        // again first, so this publication's version, and the version of
        // what keepers hear with it, run on from it, and the parts sent are
        // those that differ from it.
        if unsure {
            let kept = try await RealmSteward.statusVersion(transport, token: token)
            let parts = try await RealmSteward.keptParts(transport, token: token)
            // Kept: it is done as if its answer had come, so what it carried
            // isn't carried again under a new version and heard twice.
            if let attempt = lastAttempt, kept >= attempt.version { settle(attempt) }
            version = max(version, kept)
            keptParts = parts
            lastAttempt = nil
            unsure = false
        }
        // Keys in a fixed order, so a view unchanged encodes the same and
        // isn't sent again: unsorted, Foundation on Linux orders them anew
        // each time, and every view went out with every publication.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let status = state.status(now: now)
        var keepers: [String] = [], views: [String] = [], heard: [String] = []
        var partKeepers: [String] = [], partNames: [String] = [], partTexts: [String] = []
        var shown: [String: [String: String]] = [:], shownAt: [String: [String: UInt64]] = [:]
        var lately: [String: [(at: Double, batch: HeardBatch)]] = [:]
        // Nothing changed since the last publication kept (a heartbeat, a
        // "here" answered): every view as published stands, and none is
        // worked out and written again only to be found the same.
        let unchanged = !worldChanged && pendingEvents.isEmpty && pendingActs.isEmpty
        // The way each company on the march goes, found once for every
        // keeper who sees a stretch of it.
        var ways: [Int: [Hex]]?
        // The world's parts, which the views take their shared lists from.
        let parts = worldChanged ? try state.parts(using: encoder) : keptParts
        for keeper in state.keepers where keeper.isOnline {
            var batches = Array((recentlyHeard[keeper.id] ?? []).filter { now - $0.at <= RealmSteward.heardKept }
                .suffix(RealmSteward.heardBatches))
            lately[keeper.id] = batches
            if unchanged, published[keeper.id] != nil { continue }
            if ways == nil { ways = state.world.ways() }
            guard let view = state.view(for: keeper.id, ways: ways) else { continue }
            viewsWorkedOut += 1
            // Their view in parts: only those that changed are sent, with
            // the names of all it has now and the version each was written
            // at, so their Mac takes up the new and lets the gone go.
            let viewParts = try view.parts(using: encoder, sharing: (state.world, parts))
            let was = published[keeper.id] ?? [:]
            let changed = viewParts.filter { was[$0.key] != $0.value }.sorted { $0.key < $1.key }
            let others = pendingActs.filter { $0.by != keeper.id }.flatMap(\.events)
            let events = keeper.house.map { state.world.events(others + pendingEvents, heardBy: $0) } ?? []
            guard !changed.isEmpty || Set(was.keys) != Set(viewParts.keys) || !events.isEmpty else { continue }
            if !events.isEmpty { batches.append((now, HeardBatch(version: version + 1, events: events))) }
            batches = Array(batches.suffix(RealmSteward.heardBatches))
            lately[keeper.id] = batches
            var at = (publishedAt[keeper.id] ?? [:]).filter { viewParts[$0.key] != nil }
            for (name, text) in changed {
                at[name] = version + 1
                partKeepers.append(keeper.id)
                partNames.append(name)
                partTexts.append(text)
            }
            shown[keeper.id] = viewParts
            shownAt[keeper.id] = at
            keepers.append(keeper.id)
            views.append(RealmSteward.manifest(at))
            heard.append(String(decoding: try encoder.encode(batches.map(\.batch)), as: UTF8.self))
        }
        let answers = unanswered
        // The world's parts that changed, and those no longer there.
        let changed = parts.filter { keptParts[$0.key] != $0.value }.sorted { $0.key < $1.key }
        let gone = keptParts.keys.filter { parts[$0] == nil }.sorted()
        let attempt = Attempt(version: version + 1, at: now, status: status, shown: shown, shownAt: shownAt, parts: parts, heard: lately,
                              events: pendingEvents.count, acts: pendingActs.count, answers: answers.map(\.nonce))
        do {
            try await transport.call("publish", [
                .integer(version + 1),
                .strings(changed.map(\.key)),
                .strings(changed.map(\.value)),
                .strings(gone),
                .string(String(decoding: try encoder.encode(status), as: UTF8.self)),
                .strings(keepers),
                .strings(views),
                .strings(heard),
                .integers(answers.map(\.id)),
                .strings(answers.map(\.reply)),
                .string(holder),
                .strings(partKeepers),
                .strings(partNames),
                .strings(partTexts),
            ], token: token)
        } catch {
            if RealmSteward.isHeldByAnother(error) { isDisplaced = true }
            unsure = true
            lastAttempt = attempt
            throw error
        }
        settle(attempt)
        worldChanged = false
    }

    /// A publication, as sent: what it settles once it is known to be kept.
    private struct Attempt {
        let version: UInt64
        let at: Double
        let status: RealmStatus
        let shown: [String: [String: String]]
        let shownAt: [String: [String: UInt64]]
        let parts: [String: String]
        let heard: [String: [(at: Double, batch: HeardBatch)]]
        /// How many of the pending events, acts and answers it carried.
        let events: Int
        let acts: Int
        let answers: [String]
    }

    /// The publication sent last, if whether it was kept is unknown.
    private var lastAttempt: Attempt?

    /// Settles a publication kept: its version, views, parts and what it
    /// told are the steward's record now, and what it carried is done.
    private func settle(_ attempt: Attempt) {
        lastPublished = attempt.at
        version = max(version, attempt.version)
        lastStatus = attempt.status
        // The views of those there alone: one who comes back is shown theirs
        // as they arrive.
        let there = Set(state.keepers.lazy.filter(\.isOnline).map(\.id))
        published = published.merging(attempt.shown) { $1 }.filter { there.contains($0.key) }
        publishedAt = publishedAt.merging(attempt.shownAt) { $1 }.filter { there.contains($0.key) }
        keptParts = attempt.parts
        recentlyHeard = attempt.heard
        pendingEvents.removeFirst(min(attempt.events, pendingEvents.count))
        pendingActs.removeFirst(min(attempt.acts, pendingActs.count))
        unanswered.removeFirst(min(attempt.answers.count, unanswered.count))
        answered += attempt.answers.map { ($0, attempt.at) }
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
