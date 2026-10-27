import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// The link at the realm's edges: a database with no realm in it yet, a
/// server out of reach as a keeper arrives, and a key the realm has
/// forgotten, at the door and in play.
@MainActor
final class LinkEdgeTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
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
            ear.events.contains { if case .unreachable("The realm hasn't opened yet.") = $0 { return true } else { return false } }
        }
    }

    func testAServerOutOfReachAsAKeeperArrivesIsSaidPlainly() async throws {
        let db = FakeSpacetime()
        await db.setReachable(false)
        let (link, ear) = link(db)
        link.arrive(name: "Ama")
        try await until("the refusal") { !ear.refusals.isEmpty }
        XCTAssertEqual(ear.refusals.first, "No answer from the realm's server.")
        link.leave()
    }

    func testAForgottenKeyAtTheDoorAsksForANameAgain() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db)
        defer { running.cancel() }
        let kept = try await db.createIdentity()
        await db.forget(token: kept.token)
        let store = MemoryStore(value: String(decoding: try JSONEncoder().encode(kept), as: UTF8.self))
        let (link, ear) = link(db, store: store)
        link.arrive(name: nil)
        try await until("the realm not to know the keeper") {
            ear.events.contains { if case .refused(.unknownKeeper) = $0 { return true } else { return false } }
        }
        XCTAssertEqual(store.value, "", "The forgotten key is let go")
        link.leave()
    }

    func testAKeyForgottenInPlayIsTold() async throws {
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
        let kept = try JSONDecoder().decode(SpacetimeCredentials.self, from: Data(try XCTUnwrap(store.value).utf8))
        await db.forget(token: kept.token)
        link.send(.fortify(unit: spear.id))
        try await until("the realm not to know the keeper") {
            ear.events.contains { if case .refused(.unknownKeeper) = $0 { return true } else { return false } }
        }
        link.leave()
    }
}
