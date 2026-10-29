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

    func testARealmKeptWholeButUnreadableIsRefusedToo() async throws {
        let db = FakeSpacetime()
        await db.seed(legacyWorld: "{\"from\": \"rules this steward doesn't know\"}")
        let key = try await db.createIdentity()
        do {
            _ = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "s", seats: 4, watchLength: 600, now: 1)
            XCTFail("A steward began a new realm over one kept whole that it couldn't read")
        } catch {
            XCTAssertTrue(error is StewardError, "\(error)")
        }
        let parts = await db.worldParts
        XCTAssertTrue(parts.isEmpty, "Nothing written over it")
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

    /// What a keeper's client reads of their view: its version, and the
    /// batches of what they heard.
    private func heard(_ db: FakeSpacetime, _ keeper: SpacetimeCredentials) async throws -> (version: UInt64, batches: [HeardBatch]) {
        let rows = try await db.query("SELECT * FROM my_view", token: keeper.token)
        let row = try XCTUnwrap(rows.first)
        return (UInt64(try XCTUnwrap(row[1].number)), try JSONDecoder().decode([HeardBatch].self, from: Data(try XCTUnwrap(row[3].string).utf8)))
    }

    func testWhatAKeptPublicationToldIsNotToldAgainUnderANewVersion() async throws {
        let db = FakeSpacetime()
        let line = Flaky(db)
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: line, token: key.token, name: "N", seed: "told once", seats: 4, watchLength: 600, now: 0)
        let ama = try await db.createIdentity(), bel = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama")], token: ama.token)
        try await db.call("arrive", [.string("b1"), .string("Bel")], token: bel.token)
        try await steward.step(now: 1)
        let keepers = await steward.state.keepers
        let amaHouse = try XCTUnwrap(keepers.first { $0.name == "Ama" }?.house)
        func gift(_ nonce: String) async throws {
            let order = Command.gift(to: amaHouse, resource: .grain, amount: 1)
            try await db.call("order", [.string(nonce), .string(String(decoding: try JSONEncoder().encode(order), as: UTF8.self))], token: bel.token)
        }
        // Bel's gift is published and kept, but the answer is lost; Ama's
        // client reads it.
        try await gift("b2")
        await line.loseAnswer(to: "publish")
        do { try await steward.step(now: 2) } catch {}
        let first = try await heard(db, ama)
        let gifted = { (batch: HeardBatch) in batch.events.contains { if case .gifted = $0 { return true } else { return false } } }
        XCTAssertTrue(first.batches.contains(where: gifted), "Ama hears the first gift")
        // A second gift, and the steward goes on.
        try await gift("b3")
        try await steward.step(now: 3)
        let second = try await heard(db, ama)
        XCTAssertGreaterThan(second.version, first.version)
        let new = second.batches.filter { $0.version > first.version }
        XCTAssertEqual(new.count, 1, "The second gift, heard in a batch Ama's client hasn't read: \(second.batches.map(\.version))")
        XCTAssertEqual(new.first?.events.filter { if case .gifted = $0 { return true } else { return false } }.count, 1,
                       "and only the second: the first isn't told again")
        XCTAssertEqual(second.batches.filter { $0.version <= first.version }, first.batches.filter { $0.version <= first.version },
                       "What was told before is kept as it was")
    }
}
