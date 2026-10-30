import Foundation
import XCTest
@testable import NullmereCore

/// The deeper systems' lists are kept in pages like the realm's others,
/// come back exactly, and a realm kept from before them comes back without
/// them, to take them up as it plays on.
final class DepthPartsTests: XCTestCase {
    private func realm() throws -> RealmState {
        var realm = RealmState(name: "The Nullmere", seed: "deep parts", seats: 12, radius: 36, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        // More commanders than a page holds.
        var random = SeededRandom(seed: 9)
        for house in realm.world.houses.indices {
            for _ in 0..<3 { realm.world.raiseCommander(for: house, using: &random) }
        }
        // The wilds risen to their number, and the land's sites found.
        for _ in 0..<30 { realm.world.raiseWilds() }
        for _ in 0..<30 { realm.world.raiseSites() }
        return realm
    }

    func testTheDeeperListsComeBackFromTheirPages() throws {
        let realm = try realm()
        XCTAssertGreaterThan(realm.world.roster.count, RealmState.partPage)
        XCTAssertEqual(realm.world.wildsStanding.count, 24)
        XCTAssertEqual(realm.world.sitesInLand.count, 36)
        let parts = try realm.parts(using: Scene.encoder)
        XCTAssertNotNil(parts["commanders.0"])
        XCTAssertNotNil(parts["commanders.1"])
        XCTAssertNotNil(parts["wilds.0"])
        XCTAssertNotNil(parts["sites.1"])
        XCTAssertFalse(parts["head"]?.contains("Saltborn") ?? true, "No commander kept in the head")
        XCTAssertEqual(try RealmState(parts: parts), realm)
    }

    func testARealmFromBeforeTheDeeperListsComesBackWithoutThem() throws {
        var older = try realm()
        older.world.commanders = nil
        older.world.wilds = nil
        older.world.sites = nil
        let parts = try older.parts(using: Scene.encoder)
        XCTAssertNil(parts["commanders.0"])
        XCTAssertNil(parts["wilds.0"])
        XCTAssertNil(parts["sites.0"])
        let back = try RealmState(parts: parts)
        XCTAssertNil(back.world.commanders)
        XCTAssertNil(back.world.wilds)
        XCTAssertNil(back.world.sites)
        var played = back
        _ = played.world.endWatch()
        XCTAssertTrue(played.world.livingHouses.allSatisfy { !played.world.commanders(of: $0.id).isEmpty }, "Taken up as it plays on")
        XCTAssertFalse(played.world.wildsStanding.isEmpty)
    }

    func testAPageMissingIsRefused() throws {
        var parts = try realm().parts(using: Scene.encoder)
        parts["commanders.0"] = nil
        XCTAssertThrowsError(try RealmState(parts: parts)) { error in
            XCTAssertEqual(error as? RealmPartsError, .missing("commanders.0"))
        }
    }
}
