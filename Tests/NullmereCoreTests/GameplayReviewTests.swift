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

    func testACaretakerSwearsASensiblePactAndNoOther() throws {
        var (realm, ama, _) = try realm()
        realm.depart("id-ama", now: 0)
        let others = realm.world.houses.filter { !$0.isPlayer }.map(\.id)
        let (friend, ally, foe, builder) = (others[0], others[1], others[2], others[3])
        func relate(_ a: Int, _ b: Int, _ stance: Stance) throws {
            let index = try XCTUnwrap(realm.world.relations.firstIndex { $0.first == min(a, b) && $0.second == max(a, b) })
            realm.world.relations[index].stance = stance
        }
        // Ama's House already sworn to one ally; the foe is at war with it.
        try relate(ama, ally, .pact)
        try relate(foe, ally, .war)
        // Each asks for a pact, each having given gifts enough to win one.
        realm.world.gifts = [friend, foe, builder].map { Gift(from: $0, to: ama, worth: 500, watch: realm.world.watch) }
        // The builder's Moonspire rises.
        let spire = try XCTUnwrap(realm.world.holds.firstIndex { $0.owner == builder && $0.isSeat })
        realm.world.holds[spire].levels[.moonspire] = 3
        for from in [friend, foe, builder] {
            realm.world.envoys.append(Envoy(id: realm.world.nextID, from: from, to: ama, proposal: .pact, arrived: realm.world.watch))
            realm.world.nextID += 1
        }
        _ = realm.tick(now: 180 * 3)
        XCTAssertEqual(realm.world.stance(ama, friend), .pact, "A friend's pact, sworn")
        XCTAssertNotEqual(realm.world.stance(ama, foe), .pact, "Not with a House at war with an ally")
        XCTAssertNotEqual(realm.world.stance(ama, builder), .pact, "Nor with one whose Moonspire the lake should stop")
        XCTAssertFalse(realm.world.envoys.contains { $0.to == ama }, "Every envoy answered")
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

/// Stewards that make a race of more than the Moonspire: every rising
/// spire is feared, only a House able to finish one begins it, holds
/// beyond the seat muster companies, and one coming late to an age takes
/// up the greatest House free.
final class StewardBalanceTests: XCTestCase {
    func testEveryRisingSpireIsFeared() throws {
        var state = GameState(settings: GameSettings(seedText: "two spires"))
        for (house, level) in [(1, 4), (2, 3), (3, 2)] {
            let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == house && $0.isSeat })
            state.holds[seat].levels[.moonspire] = level
        }
        XCTAssertEqual(RivalMind(house: 4).spireThreats(in: state), [1, 2], "The highest first; a second stage is no threat yet")
        XCTAssertEqual(RivalMind(house: 1).spireThreats(in: state), [2])
    }

    func testOnlyAHouseAbleToFinishTheMoonspireBeginsIt() throws {
        var state = GameState(settings: GameSettings(seedText: "who builds"))
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer && $0.temperament == .steadfast }?.id
            ?? state.houses.first { !$0.isPlayer }?.id)
        state.houses[steward].temperament = .steadfast
        state.watch = 40
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == steward && $0.isSeat })
        // Everything else built: only the Moonspire is left to wish for.
        for kind in BuildingKind.allCases where kind != .moonspire && !(kind.requiresSeat && !state.holds[seat].isSeat) {
            state.holds[seat].levels[kind] = kind.maxLevel
        }
        state.houses[steward].stock = Stock(grain: 300, timber: 300, stone: 300, moonsalt: 100)
        // Another House as built and with a second hold, the more
        // renowned; this one has only its seat: it waits.
        let rival = try XCTUnwrap(state.holds.firstIndex { $0.owner != steward && $0.isSeat })
        state.holds[rival].levels = state.holds[seat].levels
        let third = try XCTUnwrap(state.holds.firstIndex { $0.owner != steward && $0.owner != state.holds[rival].owner })
        state.holds[third].owner = state.holds[rival].owner
        state.holds[third].isSeat = false
        _ = state.stewardTurn(for: steward)
        XCTAssertNil(state.holds[seat].project, "Not with one hold and another House the greater")
        // The second hold its own, it is foremost on the lake, and begins.
        state.holds[third].owner = steward
        _ = state.stewardTurn(for: steward)
        XCTAssertEqual(state.holds[seat].project?.kind, .moonspire)
    }

    func testALateComerTakesUpTheGreatestHouseFree() throws {
        var realm = RealmState(name: "The Nullmere", seed: "late comer", seats: 6, radius: 20, watchLength: 180, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 0)
        let free = realm.world.houses.filter { !$0.isPlayer }.map(\.id)
        let greatest = try XCTUnwrap(free.last)
        let spare = try XCTUnwrap(realm.world.holds.firstIndex { $0.owner == free[0] })
        realm.world.holds[spare].owner = greatest
        realm.world.holds[spare].isSeat = false
        XCTAssertEqual(try realm.arrive("id-bel", name: "Bel", now: 1).house, greatest)
    }
}

/// Seats fair whatever their number: spread evenly round the lake, none
/// hemmed in with little land of its own, which seat a House takes the
/// luck of the draw, and no steward always first to act.
final class SeatFairnessTests: XCTestCase {
    func testEverySeatHasRoomAndLandOfItsOwn() {
        for (seed, lake) in zip(["fair 20", "fair 39", "fair 5"], [Lake.round, .isles, .twin]) {
            let world = GameState(settings: GameSettings(seedText: seed, houseCount: 12, radius: 36, keepers: 0, lake: lake))
            let seats = world.houses.map { world.seat(of: $0.id)!.position }
            let lands = seats.enumerated().map { i, seat in
                seat.spiral(6).filter { tile in
                    guard let terrain = world.map[tile]?.terrain, terrain.isSettleable else { return false }
                    let mine = tile.distance(to: seat)
                    return seats.enumerated().allSatisfy { $0.offset == i || $0.element.distance(to: tile) > mine }
                }.count
            }
            let nearest = seats.enumerated().map { i, seat in
                seats.enumerated().filter { $0.offset != i }.map { $0.element.distance(to: seat) }.min()!
            }
            XCTAssertGreaterThanOrEqual(nearest.min()!, 8, "\(seed): seats well apart \(nearest)")
            XCTAssertGreaterThanOrEqual(Double(lands.min()!) / Double(lands.max()!), 0.35, "\(seed): none hemmed in \(lands)")
        }
    }

    func testWhoGoesFirstGoesRoundTheLake() {
        var world = GameState(settings: GameSettings(seedText: "turns", houseCount: 6, radius: 20, keepers: 0))
        var firsts: [Int] = []
        for _ in 0..<6 {
            firsts.append(world.stewardOrder.first!)
            XCTAssertEqual(Set(world.stewardOrder), Set(world.livingHouses.filter { !$0.isPlayer }.map(\.id)), "Every steward, once")
            world.watch += 1
        }
        XCTAssertEqual(Set(firsts).count, 6, "Each first in turn: \(firsts)")
    }
}

/// Stewards with the means use the whole of what the lake offers: a third
/// muster hall and riders, walls on the border, beacons for the land they
/// claim; and riders it can't pay for become spears, not nothing.
final class StewardKitTests: XCTestCase {
    private func wealthy() throws -> (GameState, steward: Int, seat: Int) {
        var state = GameState(settings: GameSettings(seedText: "the whole kit"))
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        state.houses[steward].temperament = .steadfast
        state.watch = 70
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == steward && $0.isSeat })
        for kind in [BuildingKind.granary, .sawpit, .quarry, .saltworks] { state.holds[seat].levels[kind] = kind.maxLevel }
        state.holds[seat].levels[.walls] = 2
        state.holds[seat].levels[.beacon] = 1
        state.holds[seat].levels[.musterHall] = 2
        let room = state.storage(of: steward)
        state.houses[steward].stock = Stock(grain: room, timber: room, stone: room, moonsalt: room)
        // Another House the more renowned, so this one leaves the Moonspire be.
        let other = try XCTUnwrap(state.holds.firstIndex { $0.owner != steward && $0.isSeat })
        state.holds[other].levels = [.granary: 5, .sawpit: 5, .quarry: 5, .saltworks: 5, .walls: 5, .beacon: 3, .musterHall: 3]
        return (state, steward, seat)
    }

    func testAWealthyStewardRaisesItsMusterHallThenItsBeacons() throws {
        var (state, steward, seat) = try wealthy()
        _ = state.stewardTurn(for: steward)
        XCTAssertEqual(state.holds[seat].project?.kind, .musterHall, "A third muster hall, for riders")
        state.holds[seat].project = nil
        state.holds[seat].levels[.musterHall] = 3
        _ = state.stewardTurn(for: steward)
        XCTAssertEqual(state.holds[seat].project?.kind, .beacon, "Then beacons, for the land they claim")
    }

    func testAStewardAtWarTrainsRiders() throws {
        var (state, steward, seat) = try wealthy()
        state.holds[seat].levels[.musterHall] = 3
        let foe = try XCTUnwrap(state.houses.first { $0.id != steward && !$0.isPlayer }?.id)
        _ = try state.declareWar(by: steward, on: foe)
        var riders = 0
        for watch in 70..<90 {
            var trial = state
            trial.watch = watch
            trial.draws = UInt64(watch)
            _ = trial.stewardTurn(for: steward)
            if trial.holds[seat].training?.kind == .rider { riders += 1 }
        }
        XCTAssertGreaterThan(riders, 4, "At war, riders, often")
        // Without the moonsalt for riders, spears.
        state.houses[steward].stock.moonsalt = 0
        var spears = 0
        for watch in 70..<90 {
            var trial = state
            trial.watch = watch
            trial.draws = UInt64(watch)
            _ = trial.stewardTurn(for: steward)
            XCTAssertNotEqual(trial.holds[seat].training?.kind, .rider)
            if trial.holds[seat].training?.kind == .spear { spears += 1 }
        }
        XCTAssertGreaterThan(spears, 10, "Spears instead, never an idle hall")
    }

    func testABorderHoldWallsItself() throws {
        var (state, steward, seat) = try wealthy()
        state.holds[seat].levels[.musterHall] = 3
        state.holds[seat].levels[.walls] = 1
        state.holds[seat].levels[.beacon] = 3
        let neighbour = try XCTUnwrap(state.holds.firstIndex { $0.owner != steward })
        // Another House's hold, close by.
        let near = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: state.holds[seat].position) == 6 && state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil
        })
        state.holds.append(Hold(id: state.nextID, name: "Close By", owner: state.holds[neighbour].owner, position: near, isSeat: false, foundedWatch: 1))
        state.nextID += 1
        _ = state.stewardTurn(for: steward)
        XCTAssertEqual(state.holds[seat].project?.kind, .walls)
    }
}
