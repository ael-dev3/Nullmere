import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// The steward keeps the world in parts and sends only those that changed:
/// an order sends a few, and a steward taking the realm up again finds it
/// whole, and clears away what isn't the world's.
final class WorldPartsTests: XCTestCase {
    func testAnOrderSendsOnlyThePartsItChanged() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "parts sent", seats: 12, watchLength: 600, now: 0)
        let all = await db.worldParts.count
        XCTAssertGreaterThan(all, 8)
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama")], token: ama.token)
        try await steward.step(now: 1)
        let state = await steward.state
        let house = try XCTUnwrap(state.keepers[0].house)
        let spear = try XCTUnwrap(state.world.units(of: house).first { $0.kind == .spear })
        let sent = await db.partsSent
        let order = String(decoding: try JSONEncoder().encode(Command.fortify(unit: spear.id)), as: UTF8.self)
        try await db.call("order", [.string("a2"), .string(order)], token: ama.token)
        try await steward.step(now: 2)
        let fortified = await db.partsSent - sent
        XCTAssertGreaterThan(fortified, 0)
        XCTAssertLessThanOrEqual(fortified, 2, "A page of companies and the rest, not the \(all) parts of the world")

        // Taken up again, from its parts, it is the realm as it was.
        let parts = await db.worldParts
        let current = await steward.state
        XCTAssertEqual(try RealmState(parts: parts), current)
        await db.advance(61)
        let again = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "parts sent", seats: 12, watchLength: 600, now: 3)
        let unit = await again.state.world.unit(spear.id)
        XCTAssertEqual(unit?.fortified, true)
    }

    func testWhatIsntTheWorldsIsClearedAway() async throws {
        let db = FakeSpacetime()
        let realm = RealmState(name: "N", seed: "left over", seats: 4, watchLength: 600, now: 0)
        var parts = try realm.parts(using: JSONEncoder())
        parts["omens.0"] = "[]"
        await db.seed(world: parts, version: 7)
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "left over", seats: 4, watchLength: 600, now: 1)
        let kept = await db.worldParts
        XCTAssertNil(kept["omens.0"])
        let version = await steward.version
        XCTAssertEqual(version, 8, "Versions run on from what was kept")
        let map = await steward.state.world.map
        XCTAssertEqual(map, realm.world.map)
    }

    func testAWorldKeptButUnreadableIsRefusedNotBegunOver() async throws {
        let db = FakeSpacetime()
        var parts = try RealmState(name: "N", seed: "half kept", seats: 4, watchLength: 600, now: 0).parts(using: JSONEncoder())
        parts["units.0"] = nil
        await db.seed(world: parts, version: 5)
        let key = try await db.createIdentity()
        do {
            _ = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "half kept", seats: 4, watchLength: 600, now: 1)
            XCTFail("A steward began a new realm over one it couldn't read")
        } catch {
            XCTAssertEqual((error as? StewardError).map { if case .unreadableWorld = $0 { return true } else { return false } }, true, "\(error)")
        }
        let kept = await db.worldParts
        XCTAssertEqual(kept, parts, "What was kept is left as it was, for whoever runs the realm")
    }

    func testARealmKeptWholeFromBeforeIsTakenUpAndKeptInParts() async throws {
        let db = FakeSpacetime()
        var realm = RealmState(name: "N", seed: "kept whole", seats: 4, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 0)
        await db.seed(legacyWorld: String(decoding: try JSONEncoder().encode(realm), as: UTF8.self))
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "other", seats: 4, watchLength: 600, now: 1)
        let keepers = await steward.state.keepers.map(\.name)
        XCTAssertEqual(keepers, ["Ama"], "Ama's realm, not a new one")
        let parts = await db.worldParts
        XCTAssertEqual(try RealmState(parts: parts).keepers.map(\.name), ["Ama"], "now kept in parts")
    }

    func testAPublicationKeptWhoseAnswerWasLostDoesntStopTheSteward() async throws {
        let db = FakeSpacetime()
        let line = Flaky(db)
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: line, token: key.token, name: "N", seed: "answer lost", seats: 4, watchLength: 600, now: 0)
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama")], token: ama.token)
        // SpacetimeDB keeps the publication, but its answer never comes back.
        await line.loseAnswer(to: "publish")
        do {
            try await steward.step(now: 1)
            XCTFail("The lost answer is a failure to the steward")
        } catch {}
        // The next rounds go on: not refused for a version already kept.
        try await db.call("here", [.string("a2")], token: ama.token)
        try await steward.step(now: 2)
        try await steward.step(now: 2 + RealmSteward.heartbeat + 1)
        let state = await steward.state
        let kept = await db.worldParts
        XCTAssertEqual(try RealmState(parts: kept), state, "and what is kept is the realm as it stands")
    }
}
