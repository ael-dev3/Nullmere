import Foundation
import XCTest
@testable import NullmereCore

/// The realm's balance, as a review of many played ages found it wanting:
/// no steward trades below even, however much it lacks or likes the
/// keeper, so goods can't be pumped back and forth for profit; and two
/// Moonspires finished in one watch go to the greater realm, not the
/// earlier seat.
final class GameplayReviewTests: XCTestCase {
    func testNoStewardTradesBelowEven() throws {
        var state = GameState(settings: GameSettings(seedText: "no pump"))
        let me = state.player
        for steward in state.houses where !steward.isPlayer {
            let other = steward.id
            // As kindly disposed as it can be: sworn to a pact, given gifts,
            // lacking what it is offered and with plenty of what it pays.
            state.houses[other].temperament = .steadfast
            let index = try XCTUnwrap(state.relations.firstIndex { $0.first == min(me, other) && $0.second == max(me, other) })
            state.relations[index].stance = .pact
            state.gifts = [Gift(from: me, to: other, worth: 500, watch: state.watch)]
            let room = state.storage(of: other)
            state.houses[other].stock.grain = 0
            state.houses[other].stock.stone = room
            let mind = RivalMind(house: other)
            XCTAssertTrue(mind.acceptsTrade(Trade(give: .grain, 100, for: .stone, 100), from: me, in: state), "Even, it takes")
            XCTAssertFalse(mind.acceptsTrade(Trade(give: .grain, 100, for: .stone, 101), from: me, in: state), "Below even, never")
        }
    }

    func testTradingBackAndForthGainsNothing() throws {
        var state = GameState(settings: GameSettings(seedText: "no pump"))
        let me = state.player
        let other = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        state.houses[other].temperament = .steadfast
        let room = state.storage(of: other)
        state.houses[other].stock.grain = room / 10
        state.houses[other].stock.stone = room / 10
        state.houses[me].stock.grain = 300
        state.houses[me].stock.stone = 300
        let worth = { state.houses[me].stock.grain + state.houses[me].stock.stone }
        let start = worth()
        let mind = RivalMind(house: other)
        for round in 0..<20 {
            let (give, take): (Resource, Resource) = round.isMultiple(of: 2) ? (.grain, .stone) : (.stone, .grain)
            // The best it takes, each way.
            guard let best = (1...200).reversed().first(where: { mind.acceptsTrade(Trade(give: give, 50, for: take, $0), from: me, in: state) }),
                  state.canSettle(Trade(give: give, 50, for: take, best), from: me, to: other) else { continue }
            _ = try state.offerTrade(Trade(give: give, 50, for: take, best), from: me, to: other)
        }
        XCTAssertLessThanOrEqual(worth(), start, "Nothing made from nothing")
    }

    func testTwoMoonspiresFinishedTogetherGoToTheGreaterRealm() throws {
        var state = GameState(settings: GameSettings(seedText: "spires together"))
        let first = 0, second = 1
        for house in [first, second] {
            let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == house && $0.isSeat })
            state.holds[seat].levels[.moonspire] = BuildingKind.moonspire.maxLevel
        }
        // The later seat rules more of the lake.
        let spare = try XCTUnwrap(state.holds.firstIndex { $0.owner != first && $0.owner != second })
        state.holds[spare].owner = second
        _ = state.endWatch()
        let outcome = try XCTUnwrap(state.outcome)
        XCTAssertEqual(outcome.kind, .ascendancy)
        XCTAssertEqual(outcome.winner, second)
    }
}

/// A keeper away is not a House left to fall: after two watches a
/// caretaker keeps it, answering envoys and tending its holds but starting
/// nothing; and the keepers there can't hurry the lake past those away.
final class AbsentKeeperTests: XCTestCase {
    private func realm() throws -> (RealmState, ama: Int, bel: Int) {
        var realm = RealmState(name: "The Nullmere", seed: "kept while away", seats: 12, radius: 36, watchLength: 180, now: 0)
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 0).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 0).house)
        return (realm, ama, bel)
    }

    func testAHouseKeptWhileItsKeeperIsAwayStandsAndStartsNothing() throws {
        var (realm, ama, _) = try realm()
        realm.depart("id-ama", now: 0)
        var now = 0.0
        // A stronger House demands tribute; another asks for fealty.
        let others = realm.world.houses.filter { !$0.isPlayer }.map(\.id)
        realm.world.envoys.append(Envoy(id: realm.world.nextID, from: others[0], to: ama, proposal: .fealty, arrived: realm.world.watch))
        realm.world.nextID += 1
        let holds = realm.world.holds(of: ama).count
        for _ in 0..<80 {
            now += 180
            _ = realm.tick(now: now)
        }
        let world = realm.world
        XCTAssertFalse(world.houses[ama].isEliminated, "Kept, it stands")
        XCTAssertGreaterThanOrEqual(world.holds(of: ama).count, holds, "and holds what it held")
        XCTAssertNil(world.houses[ama].liege, "It never bent the knee for its keeper")
        XCTAssertFalse(world.envoys.contains { $0.to == ama && $0.proposal == .fealty }, "The envoy was answered")
        XCTAssertFalse(world.relations.contains { relation in
            (relation.first == ama || relation.second == ama) && relation.stance == .war && relation.aggressor == ama
        }, "No war of its making")
        XCTAssertGreaterThan(world.units(of: ama).count, 0, "Its companies kept up")
    }

    func testAHouseAwayOnlyAMomentIsLeftAsItsKeeperLeftIt() throws {
        var (realm, ama, _) = try realm()
        realm.depart("id-ama", now: 170)
        let units = realm.world.units(of: ama)
        _ = realm.tick(now: 180)
        XCTAssertEqual(realm.world.units(of: ama).map(\.position), units.map(\.position), "Not yet kept: nothing moved for it")
    }

    func testTheFewThereCantHurryTheLakePastTheManyAway() throws {
        var (realm, _, _) = try realm()
        // Both there: ready, the watch turns at once.
        _ = realm.setReady("id-ama", true, now: 1)
        XCTAssertNotNil(realm.setReady("id-bel", true, now: 1))
        XCTAssertEqual(realm.world.watch, 2)
        // Bel away: Ama alone is fewer than half? No: one of two is half,
        // and half may hurry it.
        realm.depart("id-bel", now: 2)
        XCTAssertNotNil(realm.setReady("id-ama", true, now: 3))
        XCTAssertEqual(realm.world.watch, 3)
        // A third keeper seated and away: one of three can't.
        _ = try realm.arrive("id-cor", name: "Cor", now: 4)
        realm.depart("id-cor", now: 4)
        XCTAssertNil(realm.setReady("id-ama", true, now: 5), "Not before a third of a watch")
        XCTAssertNil(realm.tick(now: 3 + 59))
        XCTAssertNotNil(realm.tick(now: 3 + 60), "Ready, and the shortest watch past: it turns")
        XCTAssertEqual(realm.world.watch, 4)
    }
}
