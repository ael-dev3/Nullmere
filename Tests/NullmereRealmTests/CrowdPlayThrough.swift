import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// Every seat of a realm taken at once, each by a keeper's own client, the
/// shipped link, as a full realm of keepers plays it: all come to the door
/// together and are seated, each shown their own House's view of the one
/// world; all make ready and every client sees the watch turn; one keeper
/// speaks to the realm and every other hears it. Timed as it goes. Played
/// over a database held in memory here, and over a real SpacetimeDB server
/// in CI (see `SpacetimeIntegrationTests`).
enum CrowdPlayThrough {
    /// What one client is told, kept to the last of each: a crowd's every
    /// view kept would be the realm over again for each of them.
    @MainActor
    final class Ear {
        private(set) var status: RealmStatus?
        private(set) var keeper: Keeper?
        private(set) var world: GameState?
        private(set) var refusals: [String] = []

        func listen(to link: NetworkRealmLink) {
            link.onEvent = { [weak self] event in self?.hear(event) }
        }

        private func hear(_ event: RealmEvent) {
            switch event {
            case .status(let told):
                status = told
            case .arrived(let arrived, let seen):
                keeper = arrived
                world = seen
            case .changed(let seen), .watchTurned(let seen, _), .orderRefused(_, let seen), .settled(let seen, _):
                world = seen
                if case .orderRefused(let error, _) = event { refusals.append(error.description) }
            case .refused(let error):
                refusals.append(error.description)
            default:
                break
            }
        }
    }

    /// What it took, as the play-through went.
    struct Timings: CustomStringConvertible {
        var seated = 0.0
        var turned = 0.0
        var heard = 0.0
        /// Every keeper's order given at once, carried out in every keeper's
        /// own view.
        var ordered = 0.0
        /// The realm's publications meanwhile, the calls they took and the
        /// megabytes those carried.
        var publications = 0
        var publicationCalls = 0
        var publicationBytes = 0
        /// Calls that sent a publication's world ahead of it.
        var callsSentAhead = 0

        var description: String {
            String(format: "all seated and shown the world in %.1f s, the realm taking in a quarter of its seats each watch; the watch turned for every keeper %.1f s after the last made ready; one keeper's words heard by every other in %.1f s; every keeper's order, given at once, carried out in their view in %.1f s; %d publications in %d calls (%d sending the world ahead), %.1f MB",
                   seated, turned, heard, ordered, publications, publicationCalls, callsSentAhead, Double(publicationBytes) / 1_048_576)
        }
    }

    @MainActor
    static func until(_ what: String, timeout: Double, standing: () -> String = { "" }, _ condition: () -> Bool) async throws {
        print("CROWD waiting for \(what)")
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what): \(standing())") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    /// Waits for every ear to come to `condition`, keeping when each first
    /// did, in seconds after `since`, earliest first.
    @MainActor
    static func untilEvery(_ what: String, of ears: [Ear], since: Date, timeout: Double, _ condition: (Ear) -> Bool) async throws -> [Double] {
        print("CROWD waiting for \(what)")
        var came: [Int: Double] = [:]
        let deadline = Date().addingTimeInterval(timeout)
        while came.count < ears.count {
            for (index, ear) in ears.enumerated() where came[index] == nil && condition(ear) {
                came[index] = Date().timeIntervalSince(since)
            }
            if came.count == ears.count { break }
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what): \(standing(ears))") }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return came.values.sorted()
    }

    /// When the first of a crowd came, half of them, nine in ten and the last.
    static func spread(_ times: [Double]) -> String {
        guard !times.isEmpty else { return "none" }
        func at(_ part: Double) -> Double { times[min(times.count - 1, Int(Double(times.count) * part))] }
        return String(format: "first %.1f s, half %.1f s, nine in ten %.1f s, last %.1f s", times[0], at(0.5), at(0.9), times[times.count - 1])
    }

    /// How the crowd stands, for a wait that times out.
    @MainActor
    static func standing(_ ears: [Ear]) -> String {
        let told = ears.filter { $0.status != nil }.count, keepers = ears.filter { $0.keeper != nil }.count
        let seated = ears.filter { $0.keeper?.house != nil }.count, seeing = ears.filter { $0.world != nil }.count
        let refused = ears.flatMap(\.refusals)
        return "\(told) told the realm, \(keepers) keepers, \(seated) seated, \(seeing) shown the world, watches "
            + "\(Set(ears.compactMap { $0.world?.watch }).sorted()); refused \(refused.count): \(Array(Set(refused)).prefix(3))"
    }

    /// A realm of `seats` whose watch lasts `watchLength`, every seat taken
    /// by its own client at once; each turned away while the realm takes in
    /// its newcomers asks again within `newcomerWait`. A `budget` smaller
    /// than the steward's own puts its publications in more calls. Each
    /// client reaches the realm by `clients`, its own connections as a
    /// keeper's Mac has, or by the steward's `transport`.
    @MainActor
    static func play(_ transport: any SpacetimeTransport, token: String, seats: Int, watchLength: Double,
                     newcomerWait: ClosedRange<Double>, timeout: Double = 240, budget: Int? = nil,
                     clients: (() -> any SpacetimeTransport)? = nil, log: TimedTransport.Log? = nil) async throws -> Timings {
        func timed(_ transport: any SpacetimeTransport, _ who: String) -> any SpacetimeTransport {
            log.map { TimedTransport(transport, who: who, log: $0) } ?? transport
        }
        let steward = try await RealmSteward(transport: timed(transport, "steward"), token: token, name: "The Nullmere", seed: "a crowd at the door",
                                             seats: seats, watchLength: watchLength, budget: budget ?? RealmSteward.publicationBudget,
                                             now: Date().timeIntervalSince1970)
        // What the steward says of its rounds, as whoever runs the realm hears it.
        await steward.setReporter { print("CROWD the steward: \($0)") }
        let running = Task.detached { await steward.run() }
        // Stopped, not cancelled: its round under way finishes, so no
        // request in flight is cancelled.
        defer { Task { await steward.stop() } }
        var timings = Timings()
        let links = (0..<seats).map { index in
            let link = NetworkRealmLink(transport: timed(clients?() ?? transport, "keeper \(index)"), credentials: MemoryStore(), pollInterval: 0.5)
            link.newcomerWait = newcomerWait
            return link
        }
        let ears = links.map { link in
            let ear = Ear()
            ear.listen(to: link)
            return ear
        }
        defer { for link in links { link.close() } }
        for link in links { link.connect() }
        try await until("every client to hear the realm", timeout: timeout, standing: { standing(ears) }) { ears.allSatisfy { $0.status != nil } }

        // All to the door at once.
        let suffix = String(KeeperIdentity.make().filter(\.isLetter).prefix(4))
        let came = Date()
        // A name is letters: each keeper's its place told in two of them.
        func letters(_ index: Int) -> String {
            let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
            return String(alphabet[index / 26 % 26]).uppercased() + String(alphabet[index % 26])
        }
        for (index, link) in links.enumerated() { link.arrive(name: "Crowd \(letters(index)) " + suffix) }
        try await until("every keeper seated and shown the world", timeout: timeout, standing: { standing(ears) }) {
            ears.allSatisfy { $0.keeper?.house != nil && $0.world != nil }
        }
        timings.seated = Date().timeIntervalSince(came)
        let houses = ears.compactMap { $0.keeper?.house }
        XCTAssertEqual(Set(houses).count, seats, "Every keeper a House of their own")
        for ear in ears {
            let world = try XCTUnwrap(ear.world), house = try XCTUnwrap(ear.keeper?.house)
            XCTAssertEqual(world.houses.count, seats, "The one world, every House in it")
            XCTAssertNotNil(world.seat(of: house), "Their own seat")
            XCTAssertGreaterThan(world.houses[house].explored.setCount, 0, "What their own House has explored")
            XCTAssertTrue(world.houses.indices.allSatisfy { $0 == house || world.houses[$0].explored.setCount == 0 },
                          "No other House's ground")
        }
        // Turned away for a while, some of them, as the realm took them in a
        // quarter of its seats each watch; and nothing else.
        let refused = ears.flatMap(\.refusals)
        XCTAssertTrue(refused.allSatisfy { $0 == RealmError.manyNewcomers.description }, "\(refused.prefix(3))")
        XCTAssertLessThanOrEqual(seats - refused.count, max(RealmState.fewestNewcomersPerWatch, seats / 4),
                                 "No more taken in at once than the realm takes in a watch")

        // All make ready: the watch turns, and every client sees it turn.
        let watch = ears.compactMap { $0.world?.watch }.max() ?? 1
        for link in links { link.setReady(true) }
        let ready = Date()
        let turnedAt = try await untilEvery("the watch to turn for every keeper", of: ears, since: ready, timeout: timeout) {
            ($0.world?.watch ?? 0) > watch
        }
        timings.turned = Date().timeIntervalSince(ready)
        if let log {
            let from = ready.timeIntervalSince1970, to = Date().timeIntervalSince1970
            print("CROWD the watch turned for each keeper: \(spread(turnedAt))")
            print("CROWD requests as it turned: \(log.told(from: from, to: to))")
            print("CROWD the steward as it turned: \(log.stewardsRound(from: from, to: to))")
        }

        // One keeper speaks to the realm; every other hears it.
        let words = "The lake is full tonight " + suffix
        let speaker = try XCTUnwrap(houses.first)
        let spoke = Date()
        links[0].send(.say(words: words, toAlliance: false))
        let heardAt = try await untilEvery("every keeper to hear the words", of: ears, since: spoke, timeout: timeout) { ear in
            guard let house = ear.keeper?.house, let world = ear.world else { return false }
            return world.words(heardBy: house).contains { $0.from == speaker && $0.text == words }
        }
        timings.heard = Date().timeIntervalSince(spoke)
        if let log {
            let from = spoke.timeIntervalSince1970, to = Date().timeIntervalSince1970
            print("CROWD the words came to each keeper: \(spread(heardAt))")
            print("CROWD requests as they went: \(log.told(from: from, to: to))")
            print("CROWD the steward as they went: \(log.stewardsRound(from: from, to: to))")
        }

        // Every keeper gives an order at once, each a company of theirs dug
        // in; each sees it carried out in their own view.
        var digging: [ObjectIdentifier: Int] = [:]
        for (index, ear) in ears.enumerated() {
            guard let house = ear.keeper?.house, let unit = ear.world?.units.first(where: { $0.owner == house && !$0.fortified }) else { continue }
            digging[ObjectIdentifier(ear)] = unit.id
            links[index].send(.fortify(unit: unit.id))
        }
        let dug = digging
        XCTAssertEqual(dug.count, seats, "Every keeper a company to dig in")
        let ordered = Date()
        let carriedAt = try await untilEvery("every keeper's order carried out in their view", of: ears, since: ordered, timeout: timeout) { ear in
            guard let id = dug[ObjectIdentifier(ear)] else { return true }
            return ear.world?.unit(id)?.fortified == true
        }
        timings.ordered = Date().timeIntervalSince(ordered)
        if let log {
            let from = ordered.timeIntervalSince1970, to = Date().timeIntervalSince1970
            print("CROWD the orders were carried out for each keeper: \(spread(carriedAt))")
            print("CROWD requests as they went: \(log.told(from: from, to: to))")
            print("CROWD the steward as they went: \(log.stewardsRound(from: from, to: to))")
        }
        timings.publications = await steward.publications
        timings.publicationCalls = await steward.publicationCalls
        timings.publicationBytes = await steward.publicationBytes
        timings.callsSentAhead = await steward.callsSentAhead
        print("CROWD \(seats) keepers' clients at once: \(timings)")
        await steward.stop()
        await running.value
        return timings
    }
}

/// The crowd over a database held in memory.
final class CrowdPlayThroughTests: XCTestCase {
    @MainActor
    func testEverySeatOfARealmTakenAtOnce() async throws {
        let db = FakeSpacetime()
        let steward = try await db.createIdentity()
        let timings = try await CrowdPlayThrough.play(db, token: steward.token, seats: 24, watchLength: 4, newcomerWait: 0.3...0.6, timeout: 90)
        XCTAssertGreaterThan(timings.seated, 0)
        let largest = await db.largestCall
        XCTAssertLessThan(largest, FakeSpacetime.largestBody, "No call the server wouldn't take")
    }

    /// The same, the realm's publications each in many calls, as a realm of
    /// hundreds of keepers sends them: every keeper is seated, shown their
    /// world, sees the watch turn and hears the words all the same.
    @MainActor
    func testACrowdShownTheRealmInPublicationsOfManyCalls() async throws {
        let db = FakeSpacetime()
        let steward = try await db.createIdentity()
        let timings = try await CrowdPlayThrough.play(db, token: steward.token, seats: 12, watchLength: 4, newcomerWait: 0.3...0.6,
                                                      timeout: 90, budget: 20_000)
        XCTAssertGreaterThan(timings.publicationCalls, timings.publications, "Publications in more calls than one")
        XCTAssertGreaterThan(timings.callsSentAhead, 1, "The world, too big for one call, sent ahead of the call that publishes it")
    }

    /// The same over a realm that pushes the rows each keeper reads, as
    /// SpacetimeDB's subscriptions carry them: every keeper is seated, shown
    /// their world, sees the watch turn and hears the words, none of them
    /// asking after their view.
    @MainActor
    func testACrowdShownTheRealmByTheRowsItPushes() async throws {
        let db = FakeSpacetime()
        await db.setPushing(true, rows: true)
        let steward = try await db.createIdentity()
        let timings = try await CrowdPlayThrough.play(db, token: steward.token, seats: 12, watchLength: 4, newcomerWait: 0.3...0.6, timeout: 90)
        XCTAssertGreaterThan(timings.seated, 0)
        let asked = await db.queried(FakeSpacetime.viewPartsAsked)
        XCTAssertEqual(asked, 0, "Every view taken as pushed")
        let pushed = await db.rowsPushed
        XCTAssertGreaterThan(pushed, 12)
    }
}
