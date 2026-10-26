import Foundation
import NullmereCore
import XCTest
@testable import NullmereRealm

/// Credentials kept in memory, as the keychain would keep them.
final class MemoryStore: IdentityStore, @unchecked Sendable {
    var value: String?
    func load() -> String? { value }
    func save(_ identity: String) throws { value = identity }
}

/// Everything a link hears, on the main actor where links live.
@MainActor
final class Listener {
    var events: [RealmEvent] = []

    func listen(to link: NetworkRealmLink) {
        link.onEvent = { [weak self] in self?.events.append($0) }
    }

    var keeper: Keeper? {
        for event in events { if case .arrived(let keeper, _) = event { return keeper } }
        return nil
    }

    var world: GameState? {
        for event in events.reversed() {
            switch event {
            case .arrived(_, let world), .changed(let world), .watchTurned(let world, _), .orderRefused(_, let world), .settled(let world, _):
                return world
            default: continue
            }
        }
        return nil
    }

    var refusals: [String] {
        events.compactMap {
            switch $0 {
            case .orderRefused(let error, _), .refused(let error): return error.description
            default: return nil
            }
        }
    }

    var turned: Bool { events.contains { if case .watchTurned = $0 { return true } else { return false } } }
    var hasStatus: Bool { events.contains { if case .status = $0 { return true } else { return false } } }
}

/// Keepers, a steward and SpacetimeDB (in memory): the realm as it runs
/// across the network.
final class NetworkRealmTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 15, _ condition: @escaping @MainActor @Sendable () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !MainActor.run(body: condition) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func steward(_ db: FakeSpacetime) async throws -> (RealmSteward, Task<Void, Never>, SpacetimeCredentials) {
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "network test",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        return (steward, running, credentials)
    }

    @MainActor
    private func keeper(_ db: FakeSpacetime, store: MemoryStore = MemoryStore()) -> (NetworkRealmLink, Listener) {
        let link = NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05)
        let listener = Listener()
        listener.listen(to: link)
        link.connect()
        return (link, listener)
    }

    func testKeepersMeetThroughTheSteward() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (a, earA) = await MainActor.run { keeper(db) }
        let (b, earB) = await MainActor.run { keeper(db) }
        try await until("the realm's status") { earA.hasStatus && earB.hasStatus }

        await MainActor.run {
            a.arrive(name: "Ama")
            b.arrive(name: "Bel")
        }
        try await until("both keepers to arrive") { earA.keeper != nil && earB.keeper != nil }
        let (houseA, houseB) = await MainActor.run { (earA.keeper!.house!, earB.keeper!.house!) }
        XCTAssertNotEqual(houseA, houseB)
        let worldA = try await MainActor.run { try XCTUnwrap(earA.world) }
        XCTAssertEqual(worldA.houses[houseA].title, "House Ama")

        // Ama's order is carried out; Bel's view never holds Ama's company,
        // out of sight, nor Ama's stores.
        let spear = try XCTUnwrap(worldA.units(of: houseA).first { $0.kind == .spear })
        await MainActor.run { a.send(.fortify(unit: spear.id)) }
        try await until("Ama's order to be carried out") { earA.world?.unit(spear.id)?.fortified == true }
        let belsWorld = try await MainActor.run { try XCTUnwrap(earB.world) }
        XCTAssertNil(belsWorld.unit(spear.id))
        XCTAssertEqual(belsWorld.houses[houseA].stock, .zero)
        XCTAssertEqual(belsWorld.settings.seedText, "")

        // Nor can a keeper read the world, or anyone's requests, directly.
        let stranger = try await db.createIdentity()
        for table in ["world", "request", "keeper_view", "reply"] {
            do {
                _ = try await db.query("SELECT * FROM \(table)", token: stranger.token)
                XCTFail("A keeper read the private \(table) table")
            } catch {}
        }

        // An order for another's company is refused, with the world as it stands.
        let theirs = try XCTUnwrap(belsWorld.units(of: houseB).first { $0.kind == .spear })
        await MainActor.run { a.send(.fortify(unit: theirs.id)) }
        try await until("the refusal") { !earA.refusals.isEmpty }

        // The watch turns when both are ready.
        await MainActor.run { a.setReady(true) }
        try await Task.sleep(nanoseconds: 300_000_000)
        let early = await MainActor.run { earA.turned }
        XCTAssertFalse(early, "Bel isn't ready yet")
        await MainActor.run { b.setReady(true) }
        try await until("the watch to turn") { earA.turned && earB.turned }
        let watch = await MainActor.run { earB.world?.watch }
        XCTAssertEqual(watch, 2)
    }

    func testAKeeperReturnsByIdentityAlone() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let store = MemoryStore()
        let (first, earFirst) = await MainActor.run { keeper(db, store: store) }
        await MainActor.run { first.arrive(name: "Ama") }
        try await until("arrival") { earFirst.keeper != nil }
        let house = await MainActor.run { earFirst.keeper?.house }
        XCTAssertNotNil(store.value, "The credentials are kept")
        await MainActor.run { first.leave() }

        let (again, earAgain) = await MainActor.run { keeper(db, store: store) }
        await MainActor.run { again.arrive(name: nil) }
        try await until("return") { earAgain.keeper != nil }
        let returned = await MainActor.run { earAgain.keeper?.house }
        XCTAssertEqual(returned, house, "Back to the same House")

        let (stranger, earStranger) = await MainActor.run { keeper(db) }
        await MainActor.run { stranger.arrive(name: nil) }
        try await until("refusal") { !earStranger.refusals.isEmpty }
    }

    func testOrdersGivenOutOfReachGoInOrderOnceItAnswers() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let line = Flaky(db)
        let (ama, ear) = await MainActor.run { () -> (NetworkRealmLink, Listener) in
            let link = NetworkRealmLink(transport: line, credentials: MemoryStore(), pollInterval: 0.05, retryDelay: 0.05)
            let listener = Listener()
            listener.listen(to: link)
            link.connect()
            link.arrive(name: "Ama")
            return (link, listener)
        }
        try await until("arrival") { ear.keeper != nil }
        let world = try await MainActor.run { try XCTUnwrap(ear.world) }
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })

        // The line goes down; two orders, whose order matters, and ready.
        await line.setDown(true)
        await MainActor.run {
            ama.send(.fortify(unit: spear.id))
            ama.send(.disband(unit: spear.id))
            ama.setReady(true)
        }
        try await until("the realm out of reach") {
            ear.events.contains { if case .unreachable = $0 { return true } else { return false } }
        }
        let waiting = await MainActor.run { ama.waiting }
        XCTAssertEqual(waiting, 3, "Nothing is lost")
        await line.setDown(false)
        try await until("the orders, carried out in turn") { ear.world?.unit(spear.id) == nil && ear.turned }
        let refusals = await MainActor.run { ear.refusals }
        XCTAssertEqual(refusals, [], "Fortified, then disbanded: in the order given")
        let after = await MainActor.run { ama.waiting }
        XCTAssertEqual(after, 0)
    }

    func testAnOrderWhoseAnswerWasLostIsCarriedOutOnce() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let line = Flaky(db)
        let (ama, ear) = await MainActor.run { () -> (NetworkRealmLink, Listener) in
            let link = NetworkRealmLink(transport: line, credentials: MemoryStore(), pollInterval: 0.05, retryDelay: 0.05)
            let listener = Listener()
            listener.listen(to: link)
            link.connect()
            link.arrive(name: "Ama")
            return (link, listener)
        }
        try await until("arrival") { ear.keeper != nil }
        let world = try await MainActor.run { try XCTUnwrap(ear.world) }
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let before = world.houses[house].stock
        // The order reaches the realm, but its answer is lost on the way back.
        await line.loseNextCall()
        await MainActor.run { ama.send(.barter(give: .timber, take: .grain, amount: 10)) }
        try await until("the barter") { ear.world?.houses[house].stock != before && ama.waiting == 0 }
        try await Task.sleep(nanoseconds: 400_000_000)
        let orders = await db.handled(kind: "order")
        XCTAssertEqual(orders, 1, "Sent twice, carried out once")
        let stock = await MainActor.run { ear.world?.houses[house].stock }
        XCTAssertEqual(stock?.grain, before.grain + 10, "Ten grain bought, once")
    }

    func testOneKeepersFloodDoesNotCrowdOutAnother() async throws {
        let db = FakeSpacetime()
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "flood",
                                             seats: 4, watchLength: 600, now: 0)
        let loud = try await db.createIdentity()
        let quiet = try await db.createIdentity()
        for index in 0..<30 {
            try await db.call("here", [.string("loud-\(index)")], token: loud.token)
        }
        try await db.call("arrive", [.string("quiet-arrives"), .string("Ama")], token: quiet.token)
        try await steward.step(now: 1)
        let answered = try await db.query("SELECT * FROM my_replies", token: quiet.token)
        XCTAssertTrue(answered.contains { $0.first?.string == "quiet-arrives" }, "The quiet keeper is heard in the first round")
        let loudAnswered = try await db.query("SELECT * FROM my_replies", token: loud.token)
        XCTAssertEqual(loudAnswered.count, RealmSteward.requestsPerRound, "The loud one a few at a time")
        try await steward.step(now: 2)
        let more = try await db.query("SELECT * FROM my_replies", token: loud.token)
        XCTAssertEqual(more.count, RealmSteward.requestsPerRound * 2)
    }

    func testANewStewardTakesUpTheRealmWhereItStands() async throws {
        let db = FakeSpacetime()
        let (first, running, credentials) = try await steward(db)
        let (link, ear) = await MainActor.run { keeper(db) }
        await MainActor.run { link.arrive(name: "Ama") }
        try await until("arrival") { ear.keeper != nil }
        await MainActor.run { link.setReady(true) }
        try await until("the watch") { ear.turned }
        running.cancel()
        let watch = await first.state.world.watch
        let version = await first.version

        // The steward starts again, as after a restart.
        let resumed = try await RealmSteward(transport: db, token: credentials.token, name: "ignored", seed: "ignored", now: 2)
        let resumedWatch = await resumed.state.world.watch
        let resumedVersion = await resumed.version
        XCTAssertEqual(resumedWatch, watch)
        XCTAssertGreaterThan(resumedVersion, version)
        let anyoneThere = await resumed.state.keepers.contains { $0.isOnline }
        XCTAssertFalse(anyoneThere, "No one is there until they say so")
    }
}

/// A line to SpacetimeDB that can go down, or lose an answer on the way back.
actor Flaky: SpacetimeTransport {
    private let db: FakeSpacetime
    private var down = false
    private var losing = false

    init(_ db: FakeSpacetime) { self.db = db }

    func setDown(_ value: Bool) { down = value }
    func loseNextCall() { losing = true }

    func createIdentity() async throws -> SpacetimeCredentials {
        if down { throw SpacetimeError("The network is down.") }
        return try await db.createIdentity()
    }

    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        if down { throw SpacetimeError("The network is down.") }
        try await db.call(reducer, arguments, token: token)
        if losing, reducer == "order" {
            losing = false
            throw SpacetimeError("The answer was lost.")
        }
    }

    func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        if down { throw SpacetimeError("The network is down.") }
        return try await db.query(sql, token: token)
    }
}
