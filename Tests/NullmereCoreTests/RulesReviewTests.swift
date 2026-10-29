import Foundation
import XCTest
@testable import NullmereCore

/// Rules a keeper can't bend: no filling the chronicle for nothing, no
/// learning of ground or marches out of sight, no march stalled at a
/// foreign hold, no offer swallowed unanswered, no sight lent by a fallen
/// ally, no two Houses under one name, no liege bending the knee, no stores
/// past storage, and the walls described as they work.
final class RulesReviewTests: XCTestCase {
    private func newGame(_ seed: String = "rules reviewed") -> GameState {
        GameState(settings: GameSettings(seedText: seed, keepers: 1))
    }

    func testARefusedDemandWaitsBeforeItsMadeAgain() throws {
        var state = newGame()
        let me = state.player
        let other = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        // Matched as at the start, a steward refuses.
        _ = try state.perform(.propose(.tribute, to: other), as: me)
        XCTAssertNotNil(state.relation(me, other)?.tributeRefused, "Refused")
        let lines = state.chronicle.count
        XCTAssertThrowsError(try state.perform(.propose(.tribute, to: other), as: me))
        XCTAssertEqual(state.chronicle.count, lines, "Nothing more in the chronicle")
        state.watch += GameState.tributeRefusedRespite - 1
        XCTAssertTrue(state.refusedTributeLately(me, other), "Not before the respite")
        state.watch += 1
        XCTAssertFalse(state.refusedTributeLately(me, other), "After it, it may be made again")
        XCTAssertNoThrow(try state.perform(.propose(.tribute, to: other), as: me))
    }

    func testAPaidDemandWaitsBeforeItsMadeAgain() throws {
        var state = newGame()
        let me = state.player
        let other = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        // Stripped of its companies, a steward pays rather than fight.
        state.units.removeAll { $0.owner == other }
        _ = try state.perform(.propose(.tribute, to: other), as: me)
        XCTAssertNil(state.relation(me, other)?.tributeRefused, "Paid")
        XCTAssertTrue(state.paidTributeLately(me, other))
        XCTAssertThrowsError(try state.perform(.propose(.tribute, to: other), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .notApplicable)
        }
    }

    func testGiftsSentBackAndForthAreChronicledOnceAWatch() throws {
        var state = newGame()
        let me = state.player
        let other = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        let lines = state.chronicle.count
        for _ in 0..<4 {
            _ = try state.perform(.gift(to: other, resource: .grain, amount: GameState.notedGift), as: me)
            _ = try state.perform(.gift(to: me, resource: .grain, amount: GameState.notedGift), as: other)
        }
        XCTAssertEqual(state.chronicle.count, lines + 1)
    }

    func testAnotherHousesMarchIsHeardOnlyWhereItIsSeen() throws {
        let state = newGame()
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let seen = state.visibility(for: me)
        let near = try XCTUnwrap(seat.spiral(1).first { $0 != seat })
        let far = try XCTUnwrap(state.map.hexes.first { hex in state.map.index(of: hex).map { !seen[$0] } ?? false })
        let theirs = try XCTUnwrap(state.units.first { $0.owner != me })
        let heard = state.events([.moved(unit: theirs.id, path: [far, near])], heardBy: me)
        XCTAssertEqual(heard, [.moved(unit: theirs.id, path: [near])])
        XCTAssertEqual(state.events([.moved(unit: theirs.id, path: [far])], heardBy: me), [], "Unseen, unheard")
        let mine = try XCTUnwrap(state.units.first { $0.owner == me })
        XCTAssertEqual(state.events([.moved(unit: mine.id, path: [far, near])], heardBy: me), [.moved(unit: mine.id, path: [far, near])])
    }

    func testAMarchIntoTheUnknownTellsNothingOfIt() throws {
        var state = newGame()
        let me = state.player
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let hidden = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isPassable == false && !state.isExplored(hex, by: me)
        })
        // Unknown ground: ordered as any other, and the company goes as near
        // as it can come.
        XCTAssertNoThrow(try state.perform(.move(unit: spear.id, to: hidden), as: me))
        let moved = try XCTUnwrap(state.unit(spear.id))
        XCTAssertLessThanOrEqual(moved.position.distance(to: hidden), spear.position.distance(to: hidden))
        // Once it is known, it is refused as it is.
        state.reveal(around: hidden, range: 0, for: me)
        state.units[try XCTUnwrap(state.unitIndex(spear.id))].movesLeft = UnitKind.spear.movement
        XCTAssertThrowsError(try state.perform(.move(unit: spear.id, to: hidden), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .impassable(try! XCTUnwrap(state.map[hidden]).terrain))
        }
    }

    func testARouteKeepsClearOfAForeignHold() throws {
        var state = newGame()
        let me = state.player
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let target = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: spear.position) == 6 && state.map[hex]?.terrain.isPassable == true
                && state.unit(at: hex) == nil && state.hold(at: hex) == nil && state.path(for: spear, to: hex) != nil
        })
        let route = try XCTUnwrap(state.path(for: spear, to: target))
        let middle = route[route.count / 2]
        let other = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        state.holds.append(Hold(id: state.nextID, name: "In the Way", owner: other, position: middle, isSeat: false, foundedWatch: 1))
        state.nextID += 1
        if let around = state.path(for: spear, to: target) {
            XCTAssertFalse(around.contains(middle), "Round it, not through")
        }
        XCTAssertEqual(state.path(for: spear, to: middle)?.last, middle, "Unless it is the goal")
    }

    func testAPendingTradeSwallowsNoOtherOffer() throws {
        var state = newGame()
        let me = state.player
        let other = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        state.houses[other].isPlayer = true
        _ = try state.perform(.offerTrade(Trade(give: .grain, 10, for: .timber, 8), to: other, words: nil), as: me)
        let pact = try state.perform(.propose(.pact, to: other), as: me)
        guard case .envoyArrived(let envoy)? = pact.first else { return XCTFail("\(pact)") }
        XCTAssertEqual(envoy.proposal, .pact)
        XCTAssertThrowsError(try state.perform(.propose(.pact, to: other), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .envoyWaiting)
        }
    }

    func testAFallenHouseSeesThroughNoAlly() throws {
        var state = newGame()
        let me = state.player
        let ally = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        let conqueror = try XCTUnwrap(state.houses.first { !$0.isPlayer && $0.id != ally }).id
        let index = try XCTUnwrap(state.relations.firstIndex { $0.first == min(me, ally) && $0.second == max(me, ally) })
        state.relations[index].stance = .pact
        let allied = state.visibility(for: me).filter { $0 }.count
        for hold in state.holds.indices where state.holds[hold].owner == me { state.holds[hold].owner = conqueror }
        _ = state.eliminate(me, by: conqueror)
        XCTAssertEqual(state.stance(me, ally), .peace, "Its pacts end with it")
        XCTAssertEqual(state.visibility(for: me).filter { $0 }.count, 0, "It sees nothing (it saw \(allied))")
    }

    func testNoTwoStandingHousesShareANameInANewAge() throws {
        var realm = RealmState(name: "The Nullmere", seed: "one name each", seats: 12, radius: 36, watchLength: 600, now: 0)
        let first = try XCTUnwrap(realm.arrive("id-ilsen", name: "Ilsen", now: 1).house)
        let taken = Names.houses.first { name in !realm.world.houses.contains { $0.name == name } }
        let named = try XCTUnwrap(taken, "The name Ilsen's House bore is free")
        _ = try realm.arrive("id-other", name: named, now: 1)
        XCTAssertNotNil(realm.keeper("id-ilsen")?.house)
        _ = first
        realm.world.outcome = Outcome(winner: 0, kind: .dominion, watch: realm.world.watch)
        _ = realm.setReady("id-ilsen", true, now: 2)
        _ = realm.setReady("id-other", true, now: 2)
        XCTAssertEqual(realm.age, 2)
        let names = realm.world.livingHouses.map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count, "\(names)")
        XCTAssertTrue(realm.world.houses.contains { $0.name == named && $0.isPlayer })
    }

    func testALiegeOfOthersCantBendTheKnee() throws {
        var state = newGame()
        let stewards = state.houses.filter { !$0.isPlayer }.map(\.id)
        let (liege, vassal, overlord) = (stewards[0], stewards[1], stewards[2])
        state.houses[vassal].liege = liege
        XCTAssertThrowsError(try state.perform(.propose(.fealty, to: overlord), as: liege)) { error in
            XCTAssertEqual(error as? RuleError, .notApplicable)
        }
    }

    func testTributeComesNoFurtherThanStorage() throws {
        var state = newGame()
        let me = state.player
        let other = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        let room = state.storage(of: me)
        state.houses[me].stock.grain = room
        state.houses[other].stock.grain = 900
        state.settle(.tribute, between: me, and: other, by: me)
        XCTAssertEqual(state.houses[me].stock.grain, room, "What there's no room for is lost on the road")
        XCTAssertLessThan(state.houses[other].stock.grain, 900, "Though it was paid")
    }

    func testTheWallsAreDescribedAsTheyWork() {
        XCTAssertEqual(BuildingKind.walls.effect(atLevel: 5), "Ward \(Hold.maximumWard(wallLevel: 5)), garrison +65% defence")
        XCTAssertEqual(BuildingKind.walls.effect(atLevel: 1, isSeat: true), "Ward 80, garrison +25% defence")
        XCTAssertEqual(Hold.garrisonBonus(wallLevel: 0), 15)
    }
}
