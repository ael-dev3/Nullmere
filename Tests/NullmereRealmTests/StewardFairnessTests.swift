import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// The steward fair to keepers whose connection falters: one taken to have
/// left who is still playing counts again as soon as they are heard, what
/// a keeper heard is kept with their view until they can have read it, the
/// keepers away cost nothing to publish, one silent too long is taken to
/// have left, and a link left with an answer on its way doesn't trip over it.
final class StewardFairnessTests: XCTestCase {
    private func stewarded(_ seed: String) async throws
        -> (FakeSpacetime, RealmSteward, SpacetimeCredentials, SpacetimeCredentials, SpacetimeCredentials) {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: seed, seats: 4, watchLength: 600, now: 0)
        let ama = try await db.createIdentity()
        let bel = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama")], token: ama.token)
        try await db.call("arrive", [.string("b1"), .string("Bel")], token: bel.token)
        try await steward.step(now: 1)
        return (db, steward, ama, bel, key)
    }

    private func heard(_ db: FakeSpacetime, _ keeper: SpacetimeCredentials) async throws -> (version: UInt64, batches: [HeardBatch]) {
        let rows = try await db.query("SELECT * FROM my_view", token: keeper.token)
        let row = try XCTUnwrap(rows.first)
        let version = UInt64(try XCTUnwrap(row[1].number))
        return (version, try JSONDecoder().decode([HeardBatch].self, from: Data(try XCTUnwrap(row[3].string).utf8)))
    }

    func testAKeeperStillPlayingAfterARestartCountsAgain() async throws {
        let (db, _, ama, bel, key) = try await stewarded("a restart")
        await db.advance(61)
        let steward = try await RealmSteward(transport: db, token: key.token,
                                             name: "N", seed: "a restart", seats: 4, watchLength: 600, now: 100)
        let away = await steward.state.keepers
        XCTAssertTrue(away.allSatisfy { !$0.isOnline }, "Whoever was there is taken to have gone")
        // Their clients never knew: they say they're here, and are ready.
        try await db.call("here", [.string("a2")], token: ama.token)
        try await db.call("ready", [.string("b2"), .bool(true)], token: bel.token)
        try await steward.step(now: 101)
        let back = await steward.state.keepers
        XCTAssertTrue(back.allSatisfy(\.isOnline), "Heard from, so there")
        try await db.call("ready", [.string("a3"), .bool(true)], token: ama.token)
        try await steward.step(now: 102)
        let watch = await steward.state.world.watch
        XCTAssertEqual(watch, 2, "Both ready: the watch turns")
    }

    func testWhatAKeeperHeardOutlivesTheirOwnNextOrder() async throws {
        let (db, steward, ama, bel, _) = try await stewarded("a gift heard")
        let state = await steward.state
        let amaHouse = try XCTUnwrap(state.keepers[0].house)
        let belHouse = try XCTUnwrap(state.keepers[1].house)
        let order = Command.gift(to: amaHouse, resource: .grain, amount: 5)
        let back = Command.gift(to: belHouse, resource: .grain, amount: 1)
        try await db.call("order", [.string("b2"), .string(String(decoding: try JSONEncoder().encode(order), as: UTF8.self))], token: bel.token)
        try await steward.step(now: 2)
        let first = try await heard(db, ama)
        let gift = try XCTUnwrap(first.batches.last)
        XCTAssertTrue(gift.events.contains { if case .gifted = $0 { return true } else { return false } })

        // Ama orders before her client reads it: her view is published again,
        // the gift still with it, under the version it first came with.
        try await db.call("order", [.string("a2"), .string(String(decoding: try JSONEncoder().encode(back), as: UTF8.self))], token: ama.token)
        try await steward.step(now: 3)
        let second = try await heard(db, ama)
        XCTAssertGreaterThan(second.version, first.version)
        XCTAssertEqual(second.batches.first, gift)

        // Long after, it is no longer carried.
        try await db.call("here", [.string("a3")], token: ama.token)
        try await db.call("order", [.string("b3"), .string(String(decoding: try JSONEncoder().encode(order), as: UTF8.self))], token: bel.token)
        try await steward.step(now: 3 + RealmSteward.heardKept + 1)
        let later = try await heard(db, ama)
        XCTAssertFalse(later.batches.contains(gift))
        XCTAssertEqual(later.batches.count, 1, "The new gift alone")
    }

    func testAHereOnItsWayAsAKeeperLeftDoesntBringThemBack() async throws {
        let (db, steward, ama, _, _) = try await stewarded("a late here")
        try await db.call("leave", [.string("a2")], token: ama.token)
        try await steward.step(now: 2)
        try await db.call("here", [.string("a3")], token: ama.token)
        try await steward.step(now: 3)
        let state = await steward.state
        XCTAssertEqual(state.keepers.first { $0.name == "Ama" }?.isOnline, false, "Still gone")
        // Heard from long after, she is back.
        try await db.call("here", [.string("a4")], token: ama.token)
        try await steward.step(now: 3 + RealmSteward.leavingGrace)
        let later = await steward.state
        XCTAssertEqual(later.keepers.first { $0.name == "Ama" }?.isOnline, true)
    }

    func testAKeeperSilentTooLongIsTakenToHaveLeft() async throws {
        let (db, steward, ama, bel, _) = try await stewarded("a silence")
        func online() async -> [String: Bool] {
            Dictionary(uniqueKeysWithValues: await steward.state.keepers.map { ($0.name, $0.isOnline) })
        }
        // Bel is heard from; Ama, last heard as she arrived, is not.
        try await db.call("here", [.string("b2")], token: bel.token)
        try await steward.step(now: 1 + RealmSteward.silence)
        let atTheEdge = await online()
        XCTAssertEqual(atTheEdge, ["Ama": true, "Bel": true], "Silent as long as allowed, and no longer: still there")
        try await steward.step(now: 1 + RealmSteward.silence + 1)
        let past = await online()
        XCTAssertEqual(past, ["Ama": false, "Bel": true])
        // Gone, she holds up no watch past a third of it: Bel's readiness
        // turns it then.
        let watch = await steward.state.world.watch
        try await db.call("ready", [.string("b3"), .bool(true)], token: bel.token)
        try await steward.step(now: 3 + RealmSteward.silence)
        let early = await steward.state.world.watch
        XCTAssertEqual(early, watch, "Not before a third of the watch")
        try await db.call("here", [.string("b4")], token: bel.token)
        try await steward.step(now: 1 + 600 / 3)
        let turned = await steward.state.world.watch
        XCTAssertEqual(turned, watch + 1)
        // Heard from again, she is back.
        try await db.call("here", [.string("a2")], token: ama.token)
        try await steward.step(now: 2 + 600 / 3)
        let back = await online()
        XCTAssertEqual(back["Ama"], true)
    }

    /// A view unchanged isn't sent again, however often the realm is
    /// published: its keys are written in one order on every platform.
    func testAViewUnchangedIsNotSentAgain() async throws {
        let (db, steward, ama, bel, _) = try await stewarded("unchanged")
        let first = try await heard(db, ama).version
        // Heard from, nothing done: the status moves, Ama's view doesn't.
        try await db.call("here", [.string("a2")], token: ama.token)
        try await db.call("here", [.string("b2")], token: bel.token)
        try await steward.step(now: 2 + RealmSteward.heartbeat)
        try await steward.step(now: 4 + 2 * RealmSteward.heartbeat)
        let status = try await db.query("SELECT version FROM status", token: ama.token)
        XCTAssertGreaterThan(UInt64(try XCTUnwrap(status.first?.first?.number)), first, "Published again")
        let now = try await heard(db, ama).version
        XCTAssertEqual(now, first, "Ama's view, unchanged, not sent again")
        let head = try await db.query("SELECT version FROM my_view", token: ama.token)
        XCTAssertEqual(head.first?.first?.number.map { UInt64($0) }, first, "Its version alone says so")
    }

    func testAKeeperAwayIsNotShownTheirView() async throws {
        let (db, steward, ama, bel, _) = try await stewarded("one away")
        try await db.call("leave", [.string("b2")], token: bel.token)
        try await steward.step(now: 2)
        let before = try await heard(db, bel).version
        let state = await steward.state
        let belHouse = try XCTUnwrap(state.keepers[1].house)
        let gift = Command.gift(to: belHouse, resource: .grain, amount: 1)
        try await db.call("order", [.string("a2"), .string(String(decoding: try JSONEncoder().encode(gift), as: UTF8.self))], token: ama.token)
        try await steward.step(now: 3)
        let after = try await heard(db, bel).version
        XCTAssertEqual(after, before, "Bel's view waits for Bel")
        // Back, and shown it at once.
        try await db.call("arrive", [.string("b3"), .string("")], token: bel.token)
        try await steward.step(now: 4)
        let back = try await heard(db, bel).version
        XCTAssertGreaterThan(back, after)
    }
}
