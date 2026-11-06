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
    /// The version the publication giving this answer wrote the keeper's
    /// view at, 0 if it left their view as it was: a publication goes in
    /// several calls, and the client waits for this one, or for none.
    /// Nothing from a steward that doesn't say.
    public let viewAt: UInt64?

    public init(ok: Bool, keeper: Keeper?, refusal: String?, events: [GameEvent]? = nil, unknownKeeper: Bool? = nil,
                viewAt: UInt64? = nil) {
        self.ok = ok
        self.keeper = keeper
        self.refusal = refusal
        self.events = events
        self.unknownKeeper = unknownKeeper
        self.viewAt = viewAt
    }

    /// The same answer, telling where the keeper's view is written.
    func with(viewAt version: UInt64) -> RealmReply {
        RealmReply(ok: ok, keeper: keeper, refusal: refusal, events: events, unknownKeeper: unknownKeeper, viewAt: version)
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
    private var unanswered: [Answer] = []
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
    /// The world those parts are of, when this steward wrote them: a page
    /// of the world just as it was there is taken as written, not written
    /// again. Nil when they were read back from the server.
    private var keptWorld: GameState?
    /// The last publication failed: whether SpacetimeDB kept it is unknown.
    private var unsure = false
    /// The rows of pages told alike that the server keeps, by name
    /// ("~map.3#…", the page's name and its text's mark): each page every
    /// keeper is told alike is written once for all their views, when a
    /// view first names it, and let go once none does.
    private var alikeKept: Set<String> = []
    /// A publication failed part way, some of its calls kept and some not:
    /// the next works out every view there again, whatever changed, so the
    /// keepers in the calls never kept are shown theirs and what they heard.
    private var viewsOwed = false
    /// Most text one call of a publication carries, in bytes.
    private(set) var publicationBudget = RealmSteward.publicationBudget

    /// A smaller budget for a publication's calls, to try many calls with
    /// few keepers.
    func setPublicationBudget(_ bytes: Int) {
        publicationBudget = max(bytes, 1)
    }
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
    /// Publications sent, the calls they took and the bytes of text those
    /// carried, for tests.
    private(set) var publications = 0
    private(set) var publicationCalls = 0
    private(set) var publicationBytes = 0
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
    /// Sets a scene in the realm held, as a test does to play one out
    /// between keepers; published with the next round.
    func reshape(_ change: @Sendable (inout RealmState) -> Void) {
        change(&state)
        worldChanged = true
    }

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
            unanswered.append(Answer(id: request.id, nonce: request.nonce, keeper: request.keeper, reply: reply))
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
                let arrival = ArrivalPayload(decoding: payload)
                let arrived = try state.arrive(keeper, name: arrival.name, now: now, compact: arrival.compact)
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
        // Whether the world changed is taken as the publication begins: a
        // change made while it waits on its views or on the server (an
        // order of whoever runs the realm) is the next one's to send, not
        // cleared with this one. One that fails sends it all again.
        let changed = worldChanged
        worldChanged = false
        do {
            try await publish(now: now, worldChanged: changed)
        } catch {
            if changed { worldChanged = true }
            throw error
        }
    }

    private func publish(now: Double, worldChanged: Bool) async throws {
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
            keptWorld = nil
            // Which pages told alike the server keeps isn't known: those the
            // views name are written again.
            alikeKept = []
            lastAttempt = nil
            unsure = false
        }
        // Keys in a fixed order, so a view unchanged encodes the same and
        // isn't sent again: unsorted, Foundation on Linux orders them anew
        // each time, and every view went out with every publication.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let status = state.status(now: now)
        var lately: [String: [(at: Double, batch: HeardBatch)]] = [:]
        // Nothing changed since the last publication kept (a heartbeat, a
        // "here" answered): every view as published stands, and none is
        // worked out and written again only to be found the same.
        // What waits to be heard, taken now: what an order of whoever runs
        // the realm adds while this publication waits is the next one's.
        let acts = pendingActs, told = pendingEvents
        let unchanged = !worldChanged && told.isEmpty && acts.isEmpty && !viewsOwed
        // The way each company on the march goes, found once for every
        // keeper who sees a stretch of it.
        var ways: [Int: [Hex]]?
        // The world's parts, which the views take their shared lists from:
        // a page just as it was when last kept is taken as written then.
        let parts = worldChanged ? try state.parts(using: encoder, reusing: keptWorld.map { [($0, keptParts)] } ?? []) : keptParts
        // Each keeper's view to be shown, in parts, worked out side by side.
        let showing = state.keepers.filter { $0.isOnline && !(unchanged && published[$0.id] != nil) }.map(\.id)
        if !showing.isEmpty { ways = state.world.ways() }
        let worked = try await RealmSteward.views(of: showing, in: state, ways: ways, sharing: parts)
        var shown: [Shown] = []
        // The pages told alike the views there name as published: kept
        // until no view names them.
        var namedBefore: Set<String> = []
        for keeper in state.keepers where keeper.isOnline {
            namedBefore.formUnion((published[keeper.id] ?? [:]).keys.filter(AlikePages.isAlike))
        }
        var alikeNamed: [String: String] = [:]
        for keeper in state.keepers where keeper.isOnline {
            var batches = Array((recentlyHeard[keeper.id] ?? []).filter { now - $0.at <= RealmSteward.heardKept }
                .suffix(RealmSteward.heardBatches))
            lately[keeper.id] = batches
            if unchanged, published[keeper.id] != nil { continue }
            // Their view in parts: only those that changed are sent, with
            // the names of all it has now and the version each was written
            // at, so their Mac takes up the new and lets the gone go.
            guard let pages = worked.views[keeper.id] else { continue }
            viewsWorkedOut += 1
            // Each page as the view names it: its own, or, told just as a
            // keeper of no House is told it, the page every view that has
            // it shares, kept once.
            let viewParts = AlikePages.named(pages, alike: worked.alike)
            let was = published[keeper.id] ?? [:]
            let changed = viewParts.filter { !AlikePages.isAlike($0.key) && was[$0.key] != $0.value }.sorted { $0.key < $1.key }
            let others = acts.filter { $0.by != keeper.id }.flatMap(\.events)
            let events = keeper.house.map { state.world.events(others + told, heardBy: $0) } ?? []
            guard !changed.isEmpty || Set(was.keys) != Set(viewParts.keys) || !events.isEmpty else { continue }
            if !events.isEmpty { batches.append((now, HeardBatch(version: version + 1, events: events))) }
            batches = Array(batches.suffix(RealmSteward.heardBatches))
            lately[keeper.id] = batches
            var at = (publishedAt[keeper.id] ?? [:]).filter { viewParts[$0.key] != nil }
            for name in viewParts.keys where AlikePages.isAlike(name) {
                at[name] = 0
                alikeNamed[name] = viewParts[name]
            }
            shown.append(Shown(keeper: keeper.id, parts: viewParts, changed: changed, at: at,
                               heard: String(decoding: try encoder.encode(batches.map(\.batch)), as: UTF8.self)))
        }
        // And once it is: the views shown name these, the rest as they did.
        let showingNow = Set(shown.map(\.keeper))
        var namedAfter: Set<String> = []
        for keeper in state.keepers where keeper.isOnline && !showingNow.contains(keeper.id) {
            namedAfter.formUnion((published[keeper.id] ?? [:]).keys.filter(AlikePages.isAlike))
        }
        for view in shown { namedAfter.formUnion(view.parts.keys.filter(AlikePages.isAlike)) }
        // Those the server doesn't keep are written; the rest stand.
        let alike = alikeNamed.filter { !alikeKept.contains($0.key) }.sorted { $0.key < $1.key }
        let keepAlike = Alike(rows: alike, during: namedBefore.union(namedAfter).sorted(),
                              after: alike.isEmpty && namedAfter == alikeKept ? nil : namedAfter.sorted())
        // The world's parts that changed, and those no longer there.
        let changed = parts.filter { keptParts[$0.key] != $0.value }.sorted { $0.key < $1.key }
        let gone = keptParts.keys.filter { parts[$0] == nil }.sorted()
        // In as many calls as keep each under what the server takes in one.
        let calls = try RealmSteward.calls(world: changed, gone: gone, alike: keepAlike, shown: shown, answers: unanswered,
                                           from: version + 1, budget: publicationBudget)
        let statusText = String(decoding: try encoder.encode(status), as: UTF8.self)
        publications += 1
        for (index, call) in calls.enumerated() {
            let settling = Settling(version: call.version, at: now, status: status, shown: call.shown, shownAt: call.shownAt,
                                    world: index == 0 ? (parts, state.world, lately, told.count, acts.count) : nil,
                                    answers: call.answers.map { ($0.id, $0.nonce) },
                                    alike: (written: call.alikeWritten, kept: call.alikeKeeps, final: call.alikeFinal))
            do {
                try await transport.call("publish", [
                    .integer(call.version),
                    .strings(call.worldNames),
                    .strings(call.worldTexts),
                    .strings(call.gone),
                    .string(statusText),
                    .strings(call.keepers),
                    .strings(call.views),
                    .strings(call.heard),
                    .integers(call.answers.map(\.id)),
                    .strings(call.replies),
                    .string(holder),
                    .strings(call.partKeepers),
                    .strings(call.partNames),
                    .strings(call.partTexts),
                ], token: token)
            } catch {
                if RealmSteward.isHeldByAnother(error) { isDisplaced = true }
                unsure = true
                lastAttempt = settling
                viewsOwed = viewsOwed || calls.count > 1
                throw error
            }
            settle(settling)
            publicationCalls += 1
            publicationBytes += call.size
        }
        viewsOwed = false
    }

    /// A request answered, and whose it was.
    struct Answer {
        let id: UInt64
        let nonce: String
        let keeper: String
        let reply: RealmReply
    }

    /// A keeper's view to be shown: all its parts, those that changed, the
    /// version each of the rest was written at, and what they heard lately.
    struct Shown {
        let keeper: String
        let parts: [String: String]
        let changed: [(key: String, value: String)]
        let at: [String: UInt64]
        let heard: String
    }

    /// One call of a publication, as the module's `publish` takes it.
    struct Call {
        let version: UInt64
        var worldNames: [String] = [], worldTexts: [String] = [], gone: [String] = []
        var keepers: [String] = [], views: [String] = [], heard: [String] = []
        var partKeepers: [String] = [], partNames: [String] = [], partTexts: [String] = []
        var answers: [Answer] = []
        /// The answers as sent, each telling where its keeper's view is.
        var replies: [String] = []
        /// The rows of pages told alike it writes, and, if it says which
        /// to keep, those it keeps; once every view is written, the last
        /// keeps exactly the rows the views name.
        var alikeWritten: [String] = []
        var alikeKeeps: [String]?
        var alikeFinal = false
        /// What it shows, to be kept once it is: each keeper's parts, and the
        /// version each was written at.
        var shown: [String: [String: String]] = [:], shownAt: [String: [String: UInt64]] = [:]
        /// The text it carries, in bytes.
        var size = 0
    }

    /// Most text one call of a publication carries, in bytes: the server
    /// takes no request of over 2 MiB, and the text grows by its escapes as
    /// it is sent.
    static let publicationBudget = 1_000_000

    /// A publication in calls, each carrying at most `budget` bytes of text
    /// where it can, numbered on from `version`. The first carries the
    /// world's parts that changed and those gone, and every answer, whatever
    /// their size: the world and the answers that came of it are kept in one
    /// transaction, so a steward stopped between calls neither loses a
    /// request nor carries one out twice. Then the pages told alike the
    /// views name that the server doesn't keep, each written once for every
    /// view, before any view that names them; then each keeper's view whole
    /// in one call, its parts with its row, as the module asks. Each answer
    /// tells the version its keeper's view is written at, 0 if it isn't,
    /// and their Mac waits for that call, or for none. The rows of pages
    /// told alike that no view names are let go in the last call, once
    /// every view is written.
    static func calls(world changed: [(key: String, value: String)], gone: [String], alike: Alike = Alike(), shown: [Shown],
                      answers: [Answer], from version: UInt64, budget: Int) throws -> [Call] {
        let encoder = JSONEncoder()
        func encoded(_ reply: RealmReply) throws -> String { String(decoding: try encoder.encode(reply), as: UTF8.self) }
        func keeps(_ names: [String]) -> String { manifest(Dictionary(uniqueKeysWithValues: names.map { ($0, UInt64(0)) })) }
        var calls = [Call(version: version)]
        calls[0].worldNames = changed.map(\.key)
        calls[0].worldTexts = changed.map(\.value)
        calls[0].gone = gone
        calls[0].answers = answers
        // The answers' size as they will go, the version they tell aside.
        calls[0].size = changed.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count } + gone.reduce(0) { $0 + $1.utf8.count }
            + (try answers.reduce(0) { $0 + (try encoded($1.reply.with(viewAt: version))).utf8.count })
        /// A new call, if what comes next would take the last over budget.
        func room(for size: Int) {
            if calls[calls.count - 1].size > 0, calls[calls.count - 1].size + size > budget {
                calls.append(Call(version: calls[calls.count - 1].version + 1))
            }
        }
        let during = keeps(alike.during)
        for (name, text) in alike.rows {
            room(for: name.utf8.count + text.utf8.count + (calls[calls.count - 1].alikeKeeps == nil ? during.utf8.count : 0))
            let last = calls.count - 1
            if calls[last].alikeKeeps == nil {
                // Every row a view there names stays while the views are
                // written anew.
                calls[last].alikeKeeps = alike.during
                calls[last].keepers.append(AlikePages.keeper)
                calls[last].views.append(during)
                calls[last].heard.append("[]")
                calls[last].size += during.utf8.count
            }
            calls[last].partKeepers.append(AlikePages.keeper)
            calls[last].partNames.append(name)
            calls[last].partTexts.append(text)
            calls[last].alikeWritten.append(name)
            calls[last].size += name.utf8.count + text.utf8.count
        }
        var viewAt: [String: UInt64] = [:]
        for view in shown {
            var at = view.at
            for (name, _) in view.changed { at[name] = 0 }
            let size = view.changed.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count } + view.heard.utf8.count + manifest(at).utf8.count
            room(for: size)
            let last = calls.count - 1
            for (name, text) in view.changed {
                at[name] = calls[last].version
                calls[last].partKeepers.append(view.keeper)
                calls[last].partNames.append(name)
                calls[last].partTexts.append(text)
            }
            calls[last].keepers.append(view.keeper)
            calls[last].views.append(manifest(at))
            calls[last].heard.append(view.heard)
            calls[last].shown[view.keeper] = view.parts
            calls[last].shownAt[view.keeper] = at
            calls[last].size += size
            viewAt[view.keeper] = calls[last].version
        }
        // Once every view is written, the rows none names are let go.
        if let after = alike.after {
            let last = calls.count - 1
            if let index = calls[last].keepers.firstIndex(of: AlikePages.keeper) {
                calls[last].views[index] = keeps(after)
            } else {
                calls[last].keepers.append(AlikePages.keeper)
                calls[last].views.append(keeps(after))
                calls[last].heard.append("[]")
            }
            calls[last].alikeKeeps = after
            calls[last].alikeFinal = true
        }
        calls[0].replies = try answers.map { try encoded($0.reply.with(viewAt: viewAt[$0.keeper] ?? 0)) }
        return calls
    }

    /// The views of these keepers, in parts, worked out side by side: each
    /// from the same world and only its own, so the order they are worked
    /// out in changes nothing. A keeper with no House to see from has none.
    /// What every view takes alike is worked out once (the world as a
    /// keeper of no House is told it, in its parts), and each view takes
    /// every page just as it is there as written there: a keeper's view
    /// costs what is theirs alone, not the whole realm.
    static func views(of keepers: [String], in state: RealmState, ways: [Int: [Hex]]?,
                      sharing parts: [String: String]) async throws -> Worked {
        guard !keepers.isEmpty else { return Worked() }
        let commons = state.world.viewCommons(ways: ways)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let stranger = state.world.view(for: -1, commons: commons)
        let alike = try stranger.parts(using: encoder, reusing: [(state.world, parts)])
        let told: [GameState.Written] = [(stranger, alike), (state.world, parts)]
        let views = try await withThrowingTaskGroup(of: (String, [String: String]?).self) { group in
            for keeper in keepers {
                group.addTask {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .sortedKeys
                    guard let view = state.view(for: keeper, commons: commons) else { return (keeper, nil) }
                    return (keeper, try view.parts(using: encoder, reusing: told))
                }
            }
            var worked: [String: [String: String]] = [:]
            for try await (keeper, viewParts) in group {
                if let viewParts { worked[keeper] = viewParts }
            }
            return worked
        }
        return Worked(views: views, alike: alike)
    }

    /// Keepers' views in parts, and the pages a keeper of no House is told:
    /// those every view that has them is told alike.
    struct Worked {
        var views: [String: [String: String]] = [:]
        var alike: [String: String] = [:]
    }

    /// The pages told alike a publication writes, and the rows to keep:
    /// `during`, while views that named the old are written anew, and
    /// `after`, once they are, if the rows kept change.
    struct Alike {
        var rows: [(key: String, value: String)] = []
        var during: [String] = []
        var after: [String]?
    }


    /// A call of a publication, as sent: what it settles once it is known
    /// to be kept; the first of a publication also the world and what
    /// every keeper heard lately.
    private struct Settling {
        let version: UInt64
        let at: Double
        let status: RealmStatus
        let shown: [String: [String: String]]
        let shownAt: [String: [String: UInt64]]
        let world: (parts: [String: String], world: GameState, heard: [String: [(at: Double, batch: HeardBatch)]], events: Int, acts: Int)?
        let answers: [(id: UInt64, nonce: String)]
        /// The rows of pages told alike it wrote, those it kept, and
        /// whether those are every row the views name.
        let alike: (written: [String], kept: [String]?, final: Bool)
    }

    /// The call sent last, if whether it was kept is unknown.
    private var lastAttempt: Settling?

    /// Settles a call kept: its version and views are the steward's record
    /// now, the world and what was told with the first, and the answers it
    /// carried are given.
    private func settle(_ done: Settling) {
        lastPublished = done.at
        version = max(version, done.version)
        lastStatus = done.status
        // The views of those there alone: one who comes back is shown theirs
        // as they arrive.
        let there = Set(state.keepers.lazy.filter(\.isOnline).map(\.id))
        published = published.merging(done.shown) { $1 }.filter { there.contains($0.key) }
        publishedAt = publishedAt.merging(done.shownAt) { $1 }.filter { there.contains($0.key) }
        if let world = done.world {
            keptParts = world.parts
            keptWorld = world.world
            recentlyHeard = world.heard
            pendingEvents.removeFirst(min(world.events, pendingEvents.count))
            pendingActs.removeFirst(min(world.acts, pendingActs.count))
        }
        let given = Set(done.answers.map(\.id))
        unanswered.removeAll { given.contains($0.id) }
        // The server let go of the rows the call didn't keep, then wrote
        // those it carried; once every view is written, it keeps just the
        // rows they name, each written when a view first named it.
        if let kept = done.alike.kept { alikeKept = done.alike.final ? Set(kept) : alikeKept.intersection(kept) }
        alikeKept.formUnion(done.alike.written)
        answered += done.answers.map { ($0.nonce, done.at) }
    }

    /// Asked to stop: the round under way finishes, its requests with it,
    /// and no other begins. A request in flight is never cancelled, for
    /// FoundationNetworking can deadlock cancelling one as it finishes.
    private var stopping = false

    public func stop() { stopping = true }

    /// Runs the realm until stopped or cancelled, a step every quarter second.
    public func run(clock: @Sendable () -> Double = { Date().timeIntervalSince1970 }) async {
        while !Task.isCancelled, !isDisplaced, !stopping {
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
