import Foundation
@testable import NullmereCore
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
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
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

    /// A keeper's view goes in parts too: an order sends the few parts of
    /// their view it changed, not their whole view again; what the server
    /// keeps of it joins into their view exactly; and a part their view no
    /// longer has is let go.
    func testAnOrderSendsOnlyThePartsOfAViewItChanged() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "view parts sent", seats: 12, watchLength: 600, now: 0)
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        try await steward.step(now: 1)
        let first = await db.viewPartsSent, firstBytes = await db.viewBytesSent
        let state = await steward.state
        let keeper = state.keepers[0]
        let whole = try XCTUnwrap(state.view(for: keeper.id)).parts(using: JSONEncoder()).count
        XCTAssertEqual(first, whole + 1, "Their whole view the first time: \(whole) parts, and the list of those told alike")
        let shown = try await db.keptView(of: ama.identity)
        XCTAssertEqual(shown, state.view(for: keeper.id))

        let spear = try XCTUnwrap(state.world.units(of: try XCTUnwrap(keeper.house)).first { $0.kind == .spear })
        let order = String(decoding: try JSONEncoder().encode(Command.fortify(unit: spear.id)), as: UTF8.self)
        try await db.call("order", [.string("a2"), .string(order)], token: ama.token)
        try await steward.step(now: 2)
        let fortified = await db.viewPartsSent - first
        let bytes = await db.viewBytesSent - firstBytes
        print("PERF an order sent \(fortified) parts, \(bytes / 1024) KB, of a keeper's view of \(whole) parts, \(firstBytes / 1024) KB")
        XCTAssertLessThan(bytes * 4, firstBytes, "A small share of the view's bytes")
        XCTAssertGreaterThan(fortified, 0)
        XCTAssertLessThanOrEqual(fortified, 2, "A page of companies and the head, not the \(whole) parts of the view")
        let now = await steward.state
        let kept = try await db.keptView(of: ama.identity)
        XCTAssertEqual(kept, now.view(for: keeper.id))
        XCTAssertEqual(kept?.world.unit(spear.id)?.fortified, true)

        // The row names their own parts and the version each was written
        // at, and the list of the pages told alike they take.
        let rows = try await db.query("SELECT * FROM my_view", token: ama.token)
        let row = try XCTUnwrap(ViewRow(try XCTUnwrap(rows.first?[2].string)))
        let list = await db.alikeKept[try XCTUnwrap(row.told)]
        let named = try XCTUnwrap(row.parts(told: try XCTUnwrap(list)))
        XCTAssertEqual(named.count, whole + 1, "Every part, and the list")
        XCTAssertEqual(Set(named.keys.filter { !ViewRow.isList($0) }.map(AlikePages.page(of:))).count, whole, "Every page named once")
        XCTAssertEqual(named["head"], 3, "Their head their own, written as the order changed it")
        XCTAssertTrue(named.keys.contains { AlikePages.isAlike($0) && AlikePages.page(of: $0) == "map" },
                      "The lake's pages as every keeper is told them, kept once")
        XCTAssertFalse(row.own.keys.contains(where: AlikePages.isAlike), "Those named by the list alone")
        XCTAssertEqual(named.values.max(), 3, "The parts the order changed written at the latest")
    }

    /// A part a keeper's view no longer has is let go: kept once with a
    /// page of companies too many, and then, taken up again by a steward
    /// with fewer, the page goes from what the server keeps of their view.
    func testAPartAViewNoLongerHasIsLetGo() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let ama = try await db.createIdentity()
        var realm = RealmState(name: "N", seed: "view parts gone", seats: 4, watchLength: 600, now: 0)
        let house = try XCTUnwrap(try realm.arrive(ama.identity, name: "Ama", now: 0).house)
        let seat = try XCTUnwrap(realm.world.seat(of: house)).position
        let ground = seat.spiral(6).filter { hex in
            realm.world.map[hex]?.terrain.isPassable == true && realm.world.unit(at: hex) == nil && realm.world.hold(at: hex) == nil
        }
        for hex in ground.prefix(RealmState.partPage + 4) {
            realm.world.units.append(Unit(id: realm.world.takeID(), kind: .spear, owner: house, position: hex))
        }
        await db.seed(world: try realm.parts(using: JSONEncoder()), version: 1)
        let first = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "view parts gone", seats: 4, watchLength: 600, now: 0)
        try await db.call("here", [.string("h1")], token: ama.token)
        try await first.step(now: 1)
        func names() async throws -> [String] {
            try await db.query("SELECT name, version, text FROM my_view_parts WHERE version > 0", token: ama.token).compactMap { $0.first?.string }
        }
        let paged = try await names()
        XCTAssertTrue(paged.contains("units.1"), "A second page of their companies")

        // Taken up again with the companies past the first page gone.
        var fewer = await first.state
        fewer.world.units.removeAll { $0.owner == house && $0.position != seat && ground.prefix(RealmState.partPage + 4).contains($0.position) }
        await db.seed(world: try fewer.parts(using: JSONEncoder()), version: await first.version)
        await db.advance(61)
        let second = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "view parts gone", seats: 4, watchLength: 600, now: 100)
        try await db.call("here", [.string("h2")], token: ama.token)
        try await second.step(now: 101)
        let left = try await names()
        XCTAssertFalse(left.contains("units.1"), "The page their view no longer has is let go")
        let state = await second.state
        let kept = try await db.keptView(of: ama.identity)
        XCTAssertEqual(kept, state.view(for: ama.identity))
    }

    /// A publication works out its keepers' views side by side, and they
    /// are the views it would have worked out one after another; one the
    /// realm doesn't know has none.
    func testViewsWorkedOutSideBySideAreTheViewsOneAfterAnother() async throws {
        var realm = RealmState(name: "P", seed: "side by side", seats: 6, radius: 20, watchLength: 60, now: 0)
        for (index, name) in ["Ama", "Bel", "Cai"].enumerated() { _ = try realm.arrive("id-\(name)", name: name, now: Double(index) * 3_600) }
        for _ in 0..<5 {
            for pace in 1..<GameState.pacesPerWatch { _ = realm.world.walk(to: pace) }
            _ = realm.world.endWatch()
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let parts = try realm.parts(using: encoder)
        let ways = realm.world.ways()
        let keepers = realm.keepers.map(\.id) + ["id-nobody"]
        var alone: [String: [String: String]] = [:]
        for keeper in keepers {
            guard let view = realm.view(for: keeper, ways: ways) else { continue }
            alone[keeper] = try view.parts(using: encoder, sharing: (realm.world, parts))
        }
        let together = try await RealmSteward.views(of: keepers, in: realm, ways: ways, sharing: parts).views
        XCTAssertEqual(together, alone)
        XCTAssertEqual(Set(together.keys), Set(realm.keepers.map(\.id)), "None for one the realm doesn't know")
    }

    /// The pages every keeper is told alike are kept once, as no keeper's:
    /// each keeper's view names the rows it has and joins into their view
    /// exactly, holding as its own only what is theirs; the first
    /// publication writes each keeper's own pages and each page told alike
    /// once; a page rewritten is a new row, and the old is let go once no
    /// view names it.
    func testThePagesEveryKeeperIsToldAlikeAreKeptOnce() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "told alike", seats: 6, watchLength: 60, now: 0)
        var keepers: [SpacetimeCredentials] = []
        for (index, name) in ["Ama", "Bel", "Cai"].enumerated() {
            let keeper = try await db.createIdentity()
            try await db.call("arrive", [.string("a\(index)"), .string(ArrivalPayload(name: name, compact: Compact.edition).encoded)], token: keeper.token)
            keepers.append(keeper)
        }
        try await steward.step(now: 1)
        func check(_ when: String) async throws {
            let state = await steward.state
            let kept = await db.alikeKept
            var named: Set<String> = []
            for keeper in keepers {
                let view = try await db.keptView(of: keeper.identity)
                XCTAssertEqual(view, state.view(for: keeper.identity), "\(when): their view as kept joins into their view exactly")
                let rows = try await db.query("SELECT * FROM my_view", token: keeper.token)
                let text = try XCTUnwrap(rows.first?[2].string)
                let row = try XCTUnwrap(ViewRow(text))
                let parts = try XCTUnwrap(row.parts(told: row.told.flatMap { kept[$0] }))
                XCTAssertTrue(parts.keys.contains("head"), "\(when): their head their own")
                XCTAssertTrue(parts.keys.contains(where: AlikePages.isAlike), "\(when): pages told alike")
                XCTAssertLessThan(text.utf8.count * 2, ViewRow(own: parts).text.utf8.count,
                                  "\(when): their row names their own parts and the list, not every part")
                named.formUnion(parts.keys.filter(AlikePages.isAlike))
            }
            XCTAssertEqual(Set(kept.keys), named, "\(when): the rows the views name kept, and no others")
            for (row, text) in kept { XCTAssertEqual(AlikePages.row(AlikePages.page(of: row), text), row, "\(when): each row its text's own") }
        }
        try await check("Arrived")

        // What the first publication wrote: each keeper's own pages, and each
        // page told alike once.
        let state = await steward.state
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let worked = try await RealmSteward.views(of: keepers.map(\.identity), in: state, ways: state.world.ways(),
                                                  sharing: try state.parts(using: encoder))
        var own = 0, alike: [String: String] = [:]
        for keeper in keepers {
            let named = AlikePages.named(try XCTUnwrap(worked.views[keeper.identity]), alike: worked.alike)
            for (name, text) in named {
                if AlikePages.isAlike(name) { alike[name] = text } else { own += text.utf8.count }
            }
        }
        let sent = await db.viewBytesSent
        let list = ViewRow.list(of: AlikePages.named(worked.alike, alike: worked.alike).keys)
        XCTAssertEqual(sent, own + alike.values.reduce(0) { $0 + $1.utf8.count } + list.text.utf8.count,
                       "Their own pages, and those told alike once, and the list of them")
        let everyView = try keepers.reduce(0) { total, keeper in
            total + (try XCTUnwrap(state.view(for: keeper.identity)).parts(using: encoder)).values.reduce(0) { $0 + $1.utf8.count }
        }
        print("PERF three keepers' views first written in \(sent / 1024) KB, against \(everyView / 1024) KB for the three views whole")
        XCTAssertLessThan(sent, everyView, "Less than their views written whole")

        // A watch's turn rewrites pages; each new text a new row, and the
        // rows no view names any longer let go.
        let before = await db.alikeKept
        try await steward.step(now: 62)
        let turned = await steward.state.world.watch
        XCTAssertEqual(turned, 2)
        try await check("The watch turned")
        let after = await db.alikeKept
        XCTAssertFalse(Set(after.keys).subtracting(before.keys).isEmpty, "Pages rewritten, under rows of their own")
        XCTAssertFalse(Set(before.keys).subtracting(after.keys).isEmpty, "The old let go")
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
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
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
        try await db.heard(by: keeper.token)
    }

    func testWhatAKeptPublicationToldIsNotToldAgainUnderANewVersion() async throws {
        let db = FakeSpacetime()
        let line = Flaky(db)
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: line, token: key.token, name: "N", seed: "told once", seats: 4, watchLength: 600, now: 0)
        let ama = try await db.createIdentity(), bel = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        try await db.call("arrive", [.string("b1"), .string(ArrivalPayload(name: "Bel", compact: Compact.edition).encoded)], token: bel.token)
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
