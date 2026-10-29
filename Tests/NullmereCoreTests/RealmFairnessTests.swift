import Foundation
import XCTest
@testable import NullmereCore

/// A realm fair to every keeper in it: one House's fall ends no one
/// else's age, the fallen don't hold up a watch, a seat counted free can be
/// taken, a new age seats those still coming, a name is short however it
/// is written, a House a keeper takes up never bends the knee for them, and
/// a keeper's view tells nothing another House keeps to itself.
final class RealmFairnessTests: XCTestCase {
    private func realm(seats: Int = 4) -> RealmState {
        RealmState(name: "The Nullmere", seed: "fair realm", seats: seats, radius: 18, watchLength: 60, now: 0)
    }

    /// Takes a House off the lake: its holds go to another, its companies
    /// are gone.
    private func fell(_ house: Int, to taker: Int, in world: inout GameState) {
        for index in world.holds.indices where world.holds[index].owner == house {
            world.holds[index].owner = taker
            world.holds[index].isSeat = false
        }
        world.units.removeAll { $0.owner == house }
        world.houses[house].isEliminated = true
    }

    func testOneHousesFallEndsNoOneElsesAge() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        XCTAssertEqual(realm.world.player, ama, "The first kept House is the world's player")
        fell(ama, to: bel, in: &realm.world)
        _ = realm.world.endWatch()
        XCTAssertNil(realm.world.outcome, "Three Houses still stand: the age goes on")

        // A House's own game still ends with its House.
        var own = GameState(settings: GameSettings(seedText: "one House", houseCount: 3, radius: 14, keepers: 1))
        let other = try XCTUnwrap(own.houses.first { !$0.isPlayer }).id
        fell(own.player, to: other, in: &own)
        _ = own.endWatch()
        XCTAssertNotNil(own.outcome)
    }

    func testTheAgeEndsWhenEveryKeepersHouseHasFallen() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let steward = try XCTUnwrap(realm.world.houses.first { !$0.isPlayer }).id
        fell(ama, to: steward, in: &realm.world)
        // Alone and fallen, her readiness still turns the watch, and the age
        // ends: the greatest House left holds the lake.
        XCTAssertNotNil(realm.setReady("id-ama", true, now: 2))
        let outcome = try XCTUnwrap(realm.world.outcome)
        XCTAssertEqual(outcome.kind, .dominion)
        XCTAssertFalse(realm.world.houses[outcome.winner].isPlayer)
        // A realm no keeper has come to yet goes on.
        var empty = self.realm()
        _ = empty.world.endWatch()
        XCTAssertNil(empty.world.outcome)
    }

    func testAWorldFromBeforeHasItsMoonFoundAgain() throws {
        var realm = realm()
        let water = realm.world.moonWater
        realm.world.moonWater = nil
        realm.fillIn()
        XCTAssertEqual(realm.world.moonWater, water)
    }

    func testTheFallenDontHoldUpTheWatch() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        fell(bel, to: ama, in: &realm.world)
        let watch = realm.world.watch
        XCTAssertNotNil(realm.setReady("id-ama", true, now: 2), "Ama alone stands; her readiness turns the watch")
        XCTAssertEqual(realm.world.watch, watch + 1)
    }

    func testAFallenKeeperMayTakeUpAFreeHouse() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        fell(bel, to: ama, in: &realm.world)
        XCTAssertTrue(realm.hasFreeSeat)
        XCTAssertEqual(try realm.arrive("id-bel", name: nil, now: 2, reseatsTheFallen: false).house, bel, "Heard from, not asking")
        let taken = try XCTUnwrap(realm.arrive("id-bel", name: nil, now: 3).house, "Asking, seated anew")
        XCTAssertNotEqual(taken, bel)
        XCTAssertFalse(realm.world.houses[taken].isEliminated)
        XCTAssertEqual(realm.world.houses[taken].name, "Bel")

        // With no House free, the fallen keep their fallen House and look on.
        var two = self.realm(seats: 2)
        let first = try XCTUnwrap(two.arrive("id-ama", name: "Ama", now: 1).house)
        let second = try XCTUnwrap(two.arrive("id-bel", name: "Bel", now: 1).house)
        fell(second, to: first, in: &two.world)
        XCTAssertFalse(two.hasFreeSeat)
        XCTAssertEqual(try two.arrive("id-bel", name: nil, now: 2).house, second)
    }

    func testASeatCountedFreeCanBeTaken() throws {
        var realm = realm(seats: 3)
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        for index in realm.world.houses.indices where index != ama {
            realm.world.houses[index].liege = ama
        }
        XCTAssertEqual(realm.status(now: 2).freeSeats, 0, "A sworn House is no seat")
        XCTAssertNil(try realm.arrive("id-cor", name: "Cor", now: 2).house)
    }

    func testANewAgeSeatsThoseStillComing() throws {
        var realm = realm()
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        _ = try realm.arrive("id-bel", name: "Bel", now: 1)
        _ = try realm.arrive("id-cor", name: "Cor", now: 1)
        _ = realm.setReady("id-bel", true, now: 5)
        XCTAssertEqual(realm.keeper("id-bel")?.hasPlayed, true)
        realm.depart("id-bel", now: 10)
        realm.depart("id-cor", now: 10)
        let later = 10 + RealmState.unplayedSeatHeldFor + 1
        realm.world.outcome = Outcome(winner: 0, kind: .dominion, watch: realm.world.watch)
        XCTAssertNotNil(realm.setReady("id-ama", true, now: later))
        XCTAssertEqual(realm.age, 2)
        XCTAssertNotNil(realm.keeper("id-ama")?.house, "There")
        XCTAssertNotNil(realm.keeper("id-bel")?.house, "Away less than a week, after playing")
        XCTAssertNil(realm.keeper("id-cor")?.house, "Away longer than an unplayed seat is held")
        XCTAssertNotNil(try realm.arrive("id-cor", name: nil, now: later + 1).house, "Seated as they come back")
    }

    func testANameIsShortHoweverItIsWritten() {
        XCTAssertTrue(RealmState.isValidName("Ilsë"))
        let stacked = "A" + String(repeating: "\u{0301}", count: 1500) + "b"
        XCTAssertEqual(stacked.count, 2)
        XCTAssertEqual(RealmState.nameProblem(stacked), "No more than twenty letters.")
    }

    func testAKeptHouseNeverBendsTheKneeForItsKeeper() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let other = try XCTUnwrap(realm.world.houses.first { !$0.isPlayer }).id
        let envoy = Envoy(id: realm.world.nextID, from: other, to: ama, proposal: .fealty, arrived: realm.world.watch)
        realm.world.nextID += 1
        realm.world.envoys.append(envoy)
        // Bel takes up the House that sent it.
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 2).house)
        XCTAssertEqual(bel, other)
        let events = try realm.perform(.answer(envoy: envoy.id, accept: true), by: "id-ama")
        XCTAssertNil(realm.world.houses[bel].liege)
        XCTAssertTrue(events.contains(.proposalAnswered(proposal: .fealty, from: bel, to: ama, accepted: false)))
    }

    func testAViewKeepsOtherHousesCounsel() throws {
        var world = GameState(settings: GameSettings(seedText: "kept counsel", houseCount: 3, radius: 16, keepers: 1))
        let me = world.player
        let others = world.houses.filter { !$0.isPlayer }.map(\.id)
        world.gifts = [Gift(from: others[0], to: others[1], worth: 5, watch: 1),
                       Gift(from: me, to: others[0], worth: 9, watch: 1)]
        let theirs = try XCTUnwrap(world.units.firstIndex { $0.owner == others[0] })
        // Their company stands beside my seat, bound elsewhere.
        let seat = try XCTUnwrap(world.seat(of: me)?.position)
        let beside = try XCTUnwrap(world.map.neighbors(of: seat).first { hex in
            world.map[hex]?.terrain.isPassable == true && world.unit(at: hex) == nil && world.hold(at: hex) == nil
        })
        world.units[theirs].destination = world.units[theirs].position
        world.units[theirs].position = beside
        let view = world.view(for: me)
        XCTAssertEqual(view.gifts, [Gift(from: me, to: others[0], worth: 9, watch: 1)], "Only the gifts their own House gave or took")
        let seen = try XCTUnwrap(view.units.first { $0.id == world.units[theirs].id })
        XCTAssertNil(seen.destination, "A company in sight, not its orders")
    }
}
