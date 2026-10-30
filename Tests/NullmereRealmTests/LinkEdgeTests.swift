import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// The link at the realm's edges: a database with no realm in it yet, a
/// server out of reach as a keeper arrives, a key the server won't take,
/// at the door and in play, kept all the same, and a keeper leaving with an
/// order still on its way.
@MainActor
final class LinkEdgeTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 15, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func link(_ db: FakeSpacetime, store: MemoryStore = MemoryStore()) -> (NetworkRealmLink, Listener) {
        let link = NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05, retryDelay: 0.05)
        let listener = Listener()
        listener.listen(to: link)
        return (link, listener)
    }

    private func steward(_ db: FakeSpacetime) async throws -> Task<Void, Never> {
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "edges",
                                             seats: 4, watchLength: 600, now: 0)
        return Task { await steward.run(clock: { 1 }) }
    }

    func testADatabaseWithNoRealmYetIsSaidSo() async throws {
        let (link, ear) = link(FakeSpacetime())
        link.connect()
        defer { link.leave() }
        try await until("word of the realm") {
            ear.events.contains { if case .unreachable("The realm isn't open yet.") = $0 { return true } else { return false } }
        }
    }

    func testAServerOutOfReachAsAKeeperArrivesIsSaidPlainly() async throws {
        let db = FakeSpacetime()
        await db.setReachable(false)
        let (link, ear) = link(db)
        link.arrive(name: "Ama")
        try await until("the refusal") { !ear.refusals.isEmpty }
        XCTAssertEqual(ear.refusals.first, "The realm can't be reached.")
        link.leave()
    }

    func testAKeyTheServerWontTakeAtTheDoorIsKeptAndSaidPlainly() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db)
        defer { running.cancel() }
        let kept = try await db.createIdentity()
        await db.forget(token: kept.token)
        let key = String(decoding: try JSONEncoder().encode(kept), as: UTF8.self)
        let store = MemoryStore(value: key)
        let (link, ear) = link(db, store: store)
        link.arrive(name: nil)
        try await until("the refusal") { !ear.refusals.isEmpty }
        XCTAssertEqual(ear.refusals.first, SpacetimeError.unauthorized.description)
        XCTAssertEqual(store.value, key, "The key is kept, never erased")
        XCTAssertEqual(link.credentials, kept, "nor made anew")
        link.close()
    }

    func testAKeyTheServerWontTakeInPlayIsToldAndTheOrderWaits() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db)
        defer { running.cancel() }
        let store = MemoryStore()
        let (link, ear) = link(db, store: store)
        link.connect()
        link.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        let key = try XCTUnwrap(store.value)
        let kept = try JSONDecoder().decode(SpacetimeCredentials.self, from: Data(key.utf8))
        await db.forget(token: kept.token)
        link.send(.fortify(unit: spear.id))
        try await until("the keeper told") {
            ear.events.contains { if case .unreachable(SpacetimeError.unauthorized.description) = $0 { return true } else { return false } }
        }
        XCTAssertFalse(ear.events.contains { if case .refused = $0 { return true } else { return false } }, "Still in the world")
        XCTAssertEqual(link.waiting, 1, "The order waits")
        XCTAssertEqual(store.value, key, "and the key is kept")
        // The server takes the key again: the order goes, once.
        await db.remember(kept)
        try await until("the order carried out") { await db.handled(kind: "order") == 1 }
        try await until("the outbox empty") { link.waiting == 0 }
        XCTAssertEqual(link.credentials, kept)
        link.close()
    }

    /// A keeper leaves the world with an order still on its way: it is sent
    /// first, then the leaving, though the app lets the link go at once.
    func testLeavingSendsWhatWaitsFirst() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db)
        defer { running.cancel() }
        // Held here alone, as the app holds its link.
        let ear = Listener()
        var ama: NetworkRealmLink? = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05, retryDelay: 0.05)
        if let ama { ear.listen(to: ama) }
        ama?.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        await db.setReachable(false)
        ama?.send(.fortify(unit: spear.id))
        XCTAssertEqual(ama?.waiting, 1)
        ama?.leave()
        ama = nil
        await db.setReachable(true)
        try await until("the order carried out") { await db.handled(kind: "order") == 1 }
        try await until("then the leaving") { await db.handled(kind: "leave") == 1 }
        let calls = await db.calls
        XCTAssertLessThan(try XCTUnwrap(calls.firstIndex(of: "order")), try XCTUnwrap(calls.lastIndex(of: "leave")),
                          "The order before the leaving")
        XCTAssertTrue(ear.events.allSatisfy { if case .answered = $0 { return false } else { return true } },
                      "Nothing told once gone")
    }
}

/// The link on its own clock: an order kept through a long outage is let
/// go, not sent stale; and a keeper in the world says they are still
/// there, every half minute.
@MainActor
final class LinkClockTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 15, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func arrived(_ db: FakeSpacetime) async throws -> (NetworkRealmLink, Listener, Task<Void, Never>, () -> Void) {
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "on its own clock",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        let link = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05, retryDelay: 0.05)
        var clock = 1_000.0
        link.now = { clock }
        let ear = Listener()
        ear.listen(to: link)
        link.connect()
        link.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        return (link, ear, running, { clock += NetworkRealmLink.orderLifetime + 1 })
    }

    func testAnOrderTooOldToSendIsLetGo() async throws {
        let db = FakeSpacetime()
        let (link, ear, running, later) = try await arrived(db)
        defer { running.cancel(); link.leave() }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })

        await db.setReachable(false)
        link.send(.fortify(unit: spear.id))
        try await until("the realm out of reach") {
            ear.events.contains { if case .unreachable = $0 { return true } else { return false } }
        }
        later()
        await db.setReachable(true)
        try await until("the stale order let go") {
            ear.refusals.contains("An order given while the realm was out of reach was too old to send.")
        }
        let carried = await db.handled(kind: "order")
        XCTAssertEqual(carried, 0, "Never carried out")
        XCTAssertEqual(link.waiting, 0)
    }

    func testAKeeperInTheWorldSaysTheyAreHere() async throws {
        let db = FakeSpacetime()
        let (link, _, running, _) = try await arrived(db)
        defer { running.cancel(); link.leave() }
        let before = await db.calls.filter { $0 == "here" }.count
        // Past the interval, though not so long that the steward (whose
        // clock stands still here) seems silent.
        let now = link.now()
        link.now = { now + NetworkRealmLink.hereInterval + 1 }
        try await until("the keeper to say they are here") { await db.calls.filter { $0 == "here" }.count > before }
    }
}
