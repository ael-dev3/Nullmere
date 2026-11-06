import Foundation
import XCTest
@testable import NullmereCore

/// The realm kept in parts comes back exactly as it was, however long it
/// has run, and a realm half kept is refused, not taken up half.
final class RealmPartsTests: XCTestCase {

    /// A keeper's view goes in parts as the world does, and comes back
    /// exactly: a fresh one, and one of a realm played on, its lists long
    /// enough to need pages.
    func testAViewInPartsComesBackExactly() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var realm = RealmState(name: "N", seed: "view in parts", seats: 6, now: 0)
        try realm.arrive("a", name: "Ama", now: 0)
        for watch in 1...12 {
            for pace in 1..<GameState.pacesPerWatch { _ = realm.world.walk(to: pace) }
            _ = realm.world.endWatch()
            if watch == 1 || watch == 12 {
                let view = try XCTUnwrap(realm.view(for: "a"))
                let parts = try view.parts(using: encoder)
                XCTAssertNotNil(parts["head"])
                XCTAssertNotNil(parts["map"])
                XCTAssertEqual(try RealmView(parts: parts), view)
                var missing = parts
                missing["map"] = nil
                XCTAssertThrowsError(try RealmView(parts: missing)) { error in
                    XCTAssertEqual(error as? RealmPartsError, .missing("map"))
                }
            }
        }
        let view = try XCTUnwrap(realm.view(for: "a"))
        let paged = try view.parts(using: encoder)
        XCTAssertNotNil(paged["relations.0"])
        XCTAssertEqual(paged.keys.filter { $0.hasPrefix("relations.") }.count, 1, "Fifteen relations to a page")

        // The lists a view keeps as the world has them are taken from the
        // world's parts, and come to the same parts as written for it.
        let world = try realm.parts(using: encoder)
        XCTAssertEqual(try view.parts(using: encoder, sharing: (realm.world, world)), paged)
        // A list the view has otherwise is written for it, not taken.
        var other = realm.world
        other.chronicle.removeLast()
        let unlike = try view.parts(using: encoder, sharing: (other, world))
        XCTAssertEqual(unlike, paged)
    }
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// The relations of a realm of many Houses, one for every two of them,
    /// go a thousand to a page, and come back exactly; a view keeping them
    /// as the world does takes the world's pages of them as written, and a
    /// view whose relations are its own, though alike, takes them too.
    func testRelationsGoAThousandToAPage() throws {
        let realm = RealmState(name: "N", seed: "many dealings", seats: 48, now: 0)
        XCTAssertGreaterThan(realm.world.relations.count, RealmState.relationPage)
        let world = try realm.parts(using: encoder)
        let pages = world.keys.filter { $0.hasPrefix("relations.") }.sorted()
        XCTAssertEqual(pages, ["relations.0", "relations.1"])
        XCTAssertEqual(try RealmState(parts: world), realm)

        let shared = realm.world
        let taken = try shared.parts(using: encoder, reusing: [(realm.world, world)])
        for page in pages { XCTAssertEqual(taken[page], world[page], "\(page) as written") }
        // The same relations kept apart, their storage its own: still alike,
        // page for page.
        var apart = realm.world
        apart.relations = realm.world.relations.map { $0 }
        apart.relations.append(apart.relations.removeLast())
        let alike = try apart.parts(using: encoder, reusing: [(realm.world, world)])
        for page in pages { XCTAssertEqual(alike[page], world[page]) }
        // One relation otherwise: its page written anew, the other as written.
        var unlike = realm.world
        unlike.relations[RealmState.relationPage + 3].since += 1
        let rewritten = try unlike.parts(using: encoder, reusing: [(realm.world, world)])
        XCTAssertEqual(rewritten["relations.0"], world["relations.0"])
        XCTAssertNotEqual(rewritten["relations.1"], world["relations.1"])
        var back = try JSONDecoder().decode(GameState.self, from: Data(try XCTUnwrap(rewritten["head"]).utf8))
        try back.join(rewritten, using: JSONDecoder())
        XCTAssertEqual(back.relations, unlike.relations)
    }

    /// What a pace changes of the head goes in a part of its own: the head
    /// holds none of it, a pace walked writes it and not the head, and the
    /// realm comes back exactly; a world written while it rode in the head
    /// reads as it did.
    func testAPaceGoesApartFromTheHead() throws {
        var realm = try played(watches: 3)
        XCTAssertEqual(try RealmState(parts: try realm.parts(using: encoder)), realm)
        let before = try realm.world.parts(using: encoder)
        let pace = try XCTUnwrap(before[GameState.pacePart])
        XCTAssertTrue(pace.contains("draws"), pace)
        let head = try JSONDecoder().decode(GameState.self, from: Data(try XCTUnwrap(before["head"]).utf8))
        XCTAssertNil(head.pacing)
        XCTAssertEqual(head.draws, 0)
        XCTAssertEqual(head.nextID, 0)
        XCTAssertTrue(head.envoys.isEmpty)

        // A pace walked: its part written anew, the head as it was.
        let world = realm.world
        _ = realm.world.walk(to: 1)
        let after = try realm.world.parts(using: encoder, reusing: [(world, try world.parts(using: encoder))])
        let worldBefore = try world.parts(using: encoder)
        XCTAssertNotEqual(after[GameState.pacePart], worldBefore[GameState.pacePart])
        XCTAssertEqual(after["head"], worldBefore["head"], "The head untouched by a pace")
        var walked = try JSONDecoder().decode(GameState.self, from: Data(try XCTUnwrap(after["head"]).utf8))
        try walked.join(after, using: JSONDecoder())
        XCTAssertEqual(walked, realm.world)

        // A world written before: the pace in its head, no part of its own.
        var older = worldBefore
        older[GameState.pacePart] = nil
        older[GameState.goingsPart] = nil
        var oldHead = head
        oldHead.pacing = world.pacing
        oldHead.draws = world.draws
        oldHead.nextID = world.nextID
        oldHead.envoys = world.envoys
        oldHead.marches = world.marches
        oldHead.gifts = world.gifts
        older["head"] = String(decoding: try encoder.encode(oldHead), as: UTF8.self)
        var read = try JSONDecoder().decode(GameState.self, from: Data(try XCTUnwrap(older["head"]).utf8))
        try read.join(older, using: JSONDecoder())
        XCTAssertEqual(read, world)
    }

    /// Where the watch's paces stand is the same in every view, told alike;
    /// what is on the road goes apart from it, each keeper told their own,
    /// and stands as a pace is walked. A world written while both went in
    /// the pace's part reads as it did.
    func testWhatIsOnTheRoadGoesApartFromThePace() throws {
        var realm = try played(watches: 3)
        let commons = realm.world.viewCommons(ways: realm.world.ways())
        let stranger = try realm.world.view(for: -1, commons: commons).parts(using: encoder)
        for keeper in realm.keepers {
            let parts = try XCTUnwrap(realm.view(for: keeper.id, commons: commons)).parts(using: encoder)
            XCTAssertEqual(parts[GameState.pacePart], stranger[GameState.pacePart], "\(keeper.name)'s pace as every keeper's")
            XCTAssertNotNil(parts[GameState.goingsPart])
        }
        let before = try realm.world.parts(using: encoder)
        XCTAssertFalse(try XCTUnwrap(before[GameState.pacePart]).contains("envoys"))
        let world = realm.world
        _ = realm.world.walk(to: 1)
        let after = try realm.world.parts(using: encoder, reusing: [(world, before)])
        if realm.world.envoys == world.envoys, realm.world.marches == world.marches, realm.world.gifts == world.gifts {
            XCTAssertEqual(after[GameState.goingsPart], before[GameState.goingsPart], "What is on the road as it was")
        }
        XCTAssertNotEqual(after[GameState.pacePart], before[GameState.pacePart])

        // Written while what is on the road went with the pace.
        var older = before
        let pace = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(before[GameState.pacePart]).utf8)) as? [String: Any] ?? [:]
        let goings = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(before[GameState.goingsPart]).utf8)) as? [String: Any] ?? [:]
        older[GameState.pacePart] = String(decoding: try JSONSerialization.data(withJSONObject: pace.merging(goings) { $1 }, options: [.sortedKeys]),
                                           as: UTF8.self)
        older[GameState.goingsPart] = nil
        var read = try JSONDecoder().decode(GameState.self, from: Data(try XCTUnwrap(older["head"]).utf8))
        try read.join(older, using: JSONDecoder())
        XCTAssertEqual(read, world)
        let cache = PartsRead()
        for _ in 0..<2 {
            var again = try JSONDecoder().decode(GameState.self, from: Data(try XCTUnwrap(older["head"]).utf8))
            try again.join(older, using: JSONDecoder(), read: cache)
            XCTAssertEqual(again, world, "And again, read by what was read")
        }
    }

    /// What every keeper is told alike of the realm as it stands goes apart
    /// from the head, the same in every view: a House's strength changed,
    /// that part is written anew and every head stands; and a world or
    /// view written before, with it in its head, reads as it did.
    func testWhatEveryKeeperIsToldAlikeGoesApartFromTheHead() throws {
        let realm = try played(watches: 3)
        let commons = realm.world.viewCommons(ways: realm.world.ways())
        let stranger = realm.world.view(for: -1, commons: commons)
        let told = try XCTUnwrap(try stranger.parts(using: encoder)[GameState.commonPart])
        XCTAssertTrue(told.contains("reputed"), told)
        for keeper in realm.keepers {
            let view = try XCTUnwrap(realm.view(for: keeper.id, commons: commons))
            let parts = try view.parts(using: encoder)
            XCTAssertEqual(parts[GameState.commonPart], told, "\(keeper.name)'s told as every keeper is")
            let head = try XCTUnwrap(parts["head"])
            XCTAssertFalse(head.contains("reputed"), "Every House's strength out of the head")
            XCTAssertEqual(try RealmView(parts: parts), view)
        }
        XCTAssertEqual(try RealmState(parts: try realm.parts(using: encoder)), realm)

        // A House's strength as all are told it otherwise: the part told
        // alike written anew, the head as it was.
        let keeper = realm.keepers[0]
        let view = try XCTUnwrap(realm.view(for: keeper.id, commons: commons))
        var stronger = view
        var world = stronger.world
        world.reputed = world.reputed.map { reputed in reputed.map { $0 + 1 } }
        stronger = RealmView(keeper: view.keeper, age: view.age, world: world)
        let before = try view.parts(using: encoder)
        let after = try stronger.parts(using: encoder, reusing: [(view.world, before)])
        XCTAssertNotEqual(after[GameState.commonPart], before[GameState.commonPart])
        XCTAssertEqual(after["head"], before["head"], "The head untouched")
        XCTAssertEqual(try RealmView(parts: after), stronger)

        // A view written before: what is told alike in its head, no part
        // of its own.
        var older = before
        older[GameState.commonPart] = nil
        var oldHead = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(before["head"]).utf8)) as? [String: Any] ?? [:]
        var oldWorld = oldHead["world"] as? [String: Any] ?? [:]
        let common = try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(before[GameState.commonPart]).utf8)) as? [String: Any] ?? [:]
        for (key, value) in common { oldWorld[key] = value }
        oldHead["world"] = oldWorld
        older["head"] = String(decoding: try JSONSerialization.data(withJSONObject: oldHead, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertEqual(try RealmView(parts: older), view)
    }

    /// A full realm, a few watches in, its chronicle long.
    private func played(watches: Int) throws -> RealmState {
        var realm = RealmState(name: "The Nullmere", seed: "in parts", seats: 12, radius: 36, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        _ = try realm.arrive("id-bel", name: "Bel", now: 1)
        for watch in 0..<watches {
            _ = realm.setReady("id-ama", true, now: Double(2 + watch))
            _ = realm.setReady("id-bel", true, now: Double(2 + watch))
        }
        let first = realm.world.chronicle[0]
        realm.world.chronicle += Array(repeating: first, count: 2 * RealmState.partPage)
        return realm
    }

    func testAPlayedRealmComesBackWhole() throws {
        let realm = try played(watches: 5)
        let parts = try realm.parts(using: encoder)
        XCTAssertGreaterThan(realm.world.chronicle.count, RealmState.partPage, "Long enough to need pages")
        XCTAssertNotNil(parts["chronicle.1"])
        XCTAssertNotNil(parts["units.1"])
        XCTAssertEqual(try RealmState(parts: parts), realm)
        XCTAssertEqual(try encoder.encode(RealmState(parts: parts)), try encoder.encode(realm), "To the byte")
        // No part is the whole world over again.
        let whole = try encoder.encode(realm).count
        XCTAssertLessThan(parts.values.map(\.utf8.count).max() ?? 0, whole / 3)
    }

    func testANewRealmAndOneFromBeforeTheHistoryComeBackWhole() throws {
        let fresh = try played(watches: 0)
        XCTAssertEqual(try RealmState(parts: fresh.parts(using: encoder)), fresh)
        var older = fresh
        older.world.recorded = nil
        XCTAssertEqual(try RealmState(parts: older.parts(using: encoder)), older)
    }

    func testARealmHalfKeptIsRefused() throws {
        var parts = try played(watches: 0).parts(using: encoder)
        parts["units.0"] = nil
        XCTAssertThrowsError(try RealmState(parts: parts)) { error in
            XCTAssertEqual(error as? RealmPartsError, .missing("units.0"))
        }
        parts = try played(watches: 0).parts(using: encoder)
        parts["map"] = nil
        XCTAssertThrowsError(try RealmState(parts: parts))
    }

    func testAWatchTurnedChangesOnlySomeParts() throws {
        var realm = try played(watches: 5)
        XCTAssertGreaterThan(realm.world.chronicle.count, RealmState.partPage)
        let before = try realm.parts(using: encoder)
        _ = realm.setReady("id-ama", true, now: 200)
        _ = realm.setReady("id-bel", true, now: 200)
        let after = try realm.parts(using: encoder)
        XCTAssertEqual(after["map"], before["map"], "The ground stays as it was")
        XCTAssertEqual(after["chronicle.0"], before["chronicle.0"], "and the chronicle's early pages")
    }
}
