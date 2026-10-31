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
        XCTAssertEqual(paged.keys.filter { $0.hasPrefix("relations.") }.count, 1, "Fifteen relations to a page of 32")

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
