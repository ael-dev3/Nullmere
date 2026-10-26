import Foundation
import XCTest
@testable import NullmereCore

final class RealmTests: XCTestCase {
    private func realm(seats: Int = 4, watchLength: Double = 60) -> RealmState {
        RealmState(name: "The Nullmere", seed: "realm test", seats: seats, radius: 18, watchLength: watchLength, now: 0)
    }

    func testANewRealmIsHeldByStewards() {
        let realm = realm()
        XCTAssertEqual(realm.world.houses.count, 4)
        XCTAssertTrue(realm.world.houses.allSatisfy { !$0.isPlayer }, "No keeper yet")
        XCTAssertEqual(Set(realm.world.houses.map(\.name)).count, 4, "Every House its own name")
        XCTAssertEqual(realm.status(now: 0).freeSeats, 4)
    }

    func testKeepersArriveAndTakeSeats() throws {
        var realm = realm()
        let ilsen = try realm.arrive("id-ilsen", name: "  Ilsen ", now: 1)
        XCTAssertEqual(ilsen.name, "Ilsen")
        let seat = try XCTUnwrap(ilsen.house)
        XCTAssertTrue(realm.world.houses[seat].isPlayer)
        XCTAssertEqual(realm.world.houses[seat].title, "House Ilsen")
        XCTAssertTrue(realm.world.chronicle.contains { $0.text.contains("House Ilsen takes its seat") })

        XCTAssertThrowsError(try realm.arrive("id-other", name: "ilsen", now: 2)) { XCTAssertEqual($0 as? RealmError, .nameTaken) }
        let steward = realm.world.houses.first { !$0.isPlayer }!.name
        XCTAssertThrowsError(try realm.arrive("id-other", name: steward, now: 2)) { XCTAssertEqual($0 as? RealmError, .nameTaken) }
        for bad in ["", "x", "Name1", "-Ilsa", String(repeating: "a", count: 21)] {
            XCTAssertThrowsError(try realm.arrive("id-bad", name: bad, now: 2), bad) { XCTAssertEqual($0 as? RealmError, .nameInvalid) }
        }
        XCTAssertTrue(RealmState.isValidName("Mara d'Ost"))

        // A keeper returns by identity alone, to the same House.
        realm.depart("id-ilsen")
        XCTAssertFalse(realm.keeper("id-ilsen")!.isOnline)
        let back = try realm.arrive("id-ilsen", name: nil, now: 3)
        XCTAssertEqual(back.house, seat)
        XCTAssertEqual(realm.keepers.count, 1)
        XCTAssertThrowsError(try realm.arrive("id-stranger", name: nil, now: 3)) { XCTAssertEqual($0 as? RealmError, .nameInvalid) }
    }

    func testAFullRealmSeatsNoMore() throws {
        var realm = realm(seats: 2)
        try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        let late = try realm.arrive("c", name: "Cor", now: 0)
        XCTAssertNil(late.house)
        XCTAssertEqual(realm.status(now: 0).freeSeats, 0)
        XCTAssertThrowsError(try realm.perform(.fortify(unit: 1), by: "c")) { XCTAssertEqual($0 as? RealmError, .noSeat) }
    }

    func testOrdersOnlyForTheKeepersOwnHouse() throws {
        var realm = realm()
        let a = try realm.arrive("a", name: "Ama", now: 0)
        let b = try realm.arrive("b", name: "Bel", now: 0)
        let mine = try XCTUnwrap(realm.world.units(of: a.house!).first { $0.kind == .spear })
        let theirs = try XCTUnwrap(realm.world.units(of: b.house!).first { $0.kind == .spear })
        _ = try realm.perform(.fortify(unit: mine.id), by: "a")
        XCTAssertTrue(realm.world.unit(mine.id)!.fortified)
        XCTAssertThrowsError(try realm.perform(.fortify(unit: theirs.id), by: "a")) { error in
            guard case .rule = error as? RealmError else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try realm.perform(.fortify(unit: mine.id), by: "nobody")) { XCTAssertEqual($0 as? RealmError, .unknownKeeper) }
    }

    func testTheWatchTurnsWhenEveryoneOnlineIsReady() throws {
        var realm = realm()
        try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        XCTAssertNil(realm.setReady("a", true, now: 5))
        XCTAssertEqual(realm.status(now: 5).ready, 1)
        XCTAssertNotNil(realm.setReady("b", true, now: 6))
        XCTAssertEqual(realm.world.watch, 2)
        XCTAssertTrue(realm.keepers.allSatisfy { !$0.isReady }, "A new watch, no one ready")
        XCTAssertEqual(realm.status(now: 6).secondsLeft, 60)

        // One who leaves holds no one up.
        realm.depart("b")
        XCTAssertNotNil(realm.setReady("a", true, now: 7))
        XCTAssertEqual(realm.world.watch, 3)
    }

    func testTheWatchTurnsWhenItsTimeRunsOutButAnEmptyRealmSleeps() throws {
        var realm = realm(watchLength: 60)
        XCTAssertNil(realm.tick(now: 1_000), "No one there: the realm sleeps")
        try realm.arrive("a", name: "Ama", now: 1_000)
        XCTAssertNil(realm.tick(now: 1_030))
        XCTAssertEqual(realm.status(now: 1_030).secondsLeft, 30)
        XCTAssertNotNil(realm.tick(now: 1_060))
        XCTAssertEqual(realm.world.watch, 2)
        realm.depart("a")
        XCTAssertNil(realm.tick(now: 5_000))
        XCTAssertEqual(realm.world.watch, 2)
    }

    func testKeepersTreatWithEachOther() throws {
        var realm = realm()
        let a = try realm.arrive("a", name: "Ama", now: 0)
        let b = try realm.arrive("b", name: "Bel", now: 0)
        _ = try realm.perform(.propose(.pact, to: b.house!), by: "a")
        let envoy = try XCTUnwrap(realm.world.envoys.first)
        XCTAssertEqual(envoy.from, a.house)
        XCTAssertEqual(envoy.to, b.house)
        XCTAssertThrowsError(try realm.perform(.answer(envoy: envoy.id, accept: true), by: "a"), "Only its addressee answers")
        _ = try realm.perform(.answer(envoy: envoy.id, accept: true), by: "b")
        XCTAssertEqual(realm.world.stance(a.house!, b.house!), .pact)
    }

    func testStewardsPlayTheSeatsNoOneHolds() throws {
        var realm = realm()
        try realm.arrive("a", name: "Ama", now: 0)
        let before = realm.world
        for watch in 1...15 {
            _ = realm.setReady("a", true, now: Double(watch))
        }
        XCTAssertEqual(realm.world.watch, 16)
        let stewards = realm.world.houses.filter { !$0.isPlayer }.map(\.id)
        let moved = realm.world.units.contains { unit in
            stewards.contains(unit.owner) && before.unit(unit.id).map { $0.position != unit.position } ?? true
        }
        XCTAssertTrue(moved, "The stewards' companies go about their business")
    }

    func testANewAgeFollowsAVictory() throws {
        var realm = realm()
        let a = try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        realm.world.outcome = Outcome(winner: a.house!, kind: .dominion, watch: 1)
        XCTAssertTrue(realm.status(now: 0).isEnding)
        realm.depart("b")
        XCTAssertNotNil(realm.setReady("a", true, now: 10))
        XCTAssertEqual(realm.age, 2)
        XCTAssertNil(realm.world.outcome)
        XCTAssertEqual(realm.world.watch, 1)
        XCTAssertEqual(realm.keepers.compactMap(\.house).count, 2, "Every keeper seated again, present or not")
        XCTAssertEqual(realm.world.houses[realm.keeper("a")!.house!].title, "House Ama")
    }

    func testTheRealmKeeps() throws {
        var realm = realm()
        try realm.arrive("a", name: "Ama", now: 0)
        _ = realm.setReady("a", true, now: 1)
        let data = try JSONEncoder().encode(realm)
        XCTAssertEqual(try JSONDecoder().decode(RealmState.self, from: data), realm)
    }
}

final class RealmAroundAWorldTests: XCTestCase {
    func testOneHousesGameIsARealmWithOneKeeper() throws {
        let world = GameState(settings: GameSettings(seedText: "one house", houseCount: 3, radius: 16))
        var realm = RealmState(name: "Rehearsal", world: world, keeper: "me", now: 0)
        XCTAssertEqual(realm.keeper("me")?.house, world.player)
        XCTAssertEqual(realm.world, world)
        XCTAssertNil(realm.tick(now: 1_000_000), "No watch turns of itself")
        let events = realm.stewardOrders(for: "me")
        XCTAssertFalse(events.isEmpty, "The steward gives the House its orders")
        XCTAssertNotNil(realm.setReady("me", true, now: 1))
        XCTAssertEqual(realm.world.watch, 2)
    }
}
