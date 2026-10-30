import Foundation
import XCTest
@testable import NullmereCore

/// A war a keeper begins is a war the steward fights: it makes no peace
/// before it has had a watch of its own at war, the declaration throws
/// away the goodwill the keeper's gifts bought, and no gift shortens a far
/// stronger steward's war or calms its fear of a rising Moonspire.
final class WarInAWatchTests: XCTestCase {
    private func world(_ temperament: Temperament, seed: String = "war in a watch") throws -> (GameState, me: Int, steward: Int) {
        var state = GameState(settings: GameSettings(seedText: seed, keepers: 1))
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        state.houses[steward].temperament = temperament
        return (state, state.player, steward)
    }

    private func answered(_ events: [GameEvent]) -> Bool? {
        for case .proposalAnswered(.peace, _, _, let accepted) in events { return accepted }
        return nil
    }

    /// The exploit as it was staged: gifts worth thirty watches of war,
    /// war declared, and peace offered in the same watch.
    func testAStewardMakesNoPeaceInTheWatchItWasAttacked() throws {
        for temperament in Temperament.allCases {
            var (state, me, steward) = try world(temperament)
            state.gifts = [Gift(from: me, to: steward, worth: 310, watch: state.watch)]
            _ = try state.perform(.declareWar(on: steward), as: me)
            XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), false, "\(temperament): not in the watch it was attacked")
            XCTAssertEqual(state.stance(me, steward), .war)
        }
    }

    func testDeclaringWarThrowsAwayTheGoodwillGiftsBought() throws {
        var (state, me, steward) = try world(.steadfast)
        state.houses[me].stock.grain = 200
        _ = try state.perform(.gift(to: steward, resource: .grain, amount: 50), as: me)
        XCTAssertEqual(state.goodwill(from: me, to: steward), 50)
        _ = try state.perform(.declareWar(on: steward), as: me)
        XCTAssertEqual(state.goodwill(from: me, to: steward), 0, "Turned on, the steward forgets the gift")
        // A steadfast steward no stronger than the keeper makes peace once
        // the war has run three watches, as it would without the gift.
        state.watch += 2
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), false, "Two watches: not yet")
        state.units.removeAll { $0.owner == steward }
        state.watch += 1
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), true, "Three watches, and weaker: peace")
        // Gifts given in the peace that follows count again.
        _ = try state.perform(.gift(to: steward, resource: .grain, amount: 30), as: me)
        XCTAssertEqual(state.goodwill(from: me, to: steward), 30)
    }

    /// A keeper who refuses a steward's demand is at war in that watch;
    /// their gifts can't buy the peace back before the steward has had a
    /// watch to fight it.
    func testGiftsBuyNoPeaceBeforeTheStewardHasHadItsWatchAtWar() throws {
        var (state, me, steward) = try world(.steadfast)
        state.gifts = [Gift(from: me, to: steward, worth: 500, watch: state.watch)]
        _ = try state.propose(.tribute, from: steward, to: me)
        let demand = try XCTUnwrap(state.envoys.first { $0.from == steward })
        _ = try state.perform(.answer(envoy: demand.id, accept: false), as: me)
        XCTAssertEqual(state.stance(me, steward), .war)
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), false, "Not in the watch the war began")
        _ = state.endWatch()
        XCTAssertEqual(state.stance(me, steward), .war)
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), true, "Its watch had, the gifts soften it")
    }

    /// "A far stronger steward will not make peace until the war has run
    /// long": thirty watches of war, whatever was given before it.
    func testNoGiftShortensAFarStrongerStewardsWar() throws {
        var (state, me, steward) = try world(.steadfast)
        let seat = try XCTUnwrap(state.seat(of: steward))
        for _ in 0..<6 { state.placeUnit(.spear, for: steward, near: seat.position) }
        XCTAssertGreaterThan(state.strength(of: steward) * 2, state.strength(of: me) * 3, "Far the stronger")
        state.gifts = [Gift(from: me, to: steward, worth: 900, watch: state.watch)]
        state.watch += 1
        _ = try state.declareWar(by: steward, on: me)
        XCTAssertEqual(state.goodwill(from: me, to: steward), 900, "Its own war throws away nothing the keeper gave")
        state.watch += 5
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), false, "Five watches, however much was given")
        state.watch += 25
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), false, "Thirty watches: not yet long enough")
        state.watch += 1
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), true, "Thirty-one: long enough")
    }

    /// Stewards fear every rising Moonspire: goodwill doesn't buy a quick
    /// peace, or a pact, for the House raising one.
    func testNoGiftCalmsAStewardsFearOfARisingMoonspire() throws {
        var (state, me, steward) = try world(.steadfast)
        let spire = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[spire].levels[.moonspire] = 3
        state.gifts = [Gift(from: me, to: steward, worth: 500, watch: state.watch)]
        XCTAssertEqual(RivalMind(house: steward).spireThreats(in: state), [me])
        XCTAssertFalse(RivalMind(house: steward).accepts(.pact, from: me, in: state), "Goodwill wins no pact with a rising tower")
        _ = try state.declareWar(by: steward, on: me, fearingSpire: true)
        state.watch += 2
        XCTAssertEqual(answered(try state.perform(.propose(.peace, to: steward), as: me)), false, "Two watches into a war on a rising tower")
    }
}

/// A vassal can't win while it serves: its finished Moonspire wins
/// nothing, it raises no stage of one while sworn, the works on one stop
/// when it bends the knee, and no one fears a tower that can't rise.
final class VassalSpireTests: XCTestCase {
    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "a vassal's tower", keepers: 1))
    }

    func testAVassalsFinishedMoonspireWinsNothingWhileItServes() throws {
        var state = world()
        let vassal = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        state.houses[vassal].liege = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == vassal && $0.isSeat })
        state.holds[seat].levels[.moonspire] = BuildingKind.moonspire.maxLevel
        _ = state.endWatch()
        XCTAssertNil(state.outcome, "Sworn to another, it can't be ascendant")
        XCTAssertNil(state.standing(of: vassal).threat, "and the race warns of nothing")
    }

    func testAVassalRaisesNoStageOfTheMoonspire() throws {
        var state = world()
        let vassal = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        state.houses[vassal].temperament = .steadfast
        state.watch = 40
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == vassal && $0.isSeat })
        // Everything else built, stores to spare and the most renowned on
        // the lake: free, it would begin.
        for kind in BuildingKind.allCases where kind != .moonspire { state.holds[seat].levels[kind] = kind.maxLevel }
        state.houses[vassal].stock = Stock(grain: 300, timber: 300, stone: 300, moonsalt: 100)
        var free = state
        _ = free.stewardTurn(for: vassal)
        XCTAssertEqual(free.holds[seat].project?.kind, .moonspire, "Free, it begins")
        state.houses[vassal].liege = state.player
        XCTAssertThrowsError(try state.perform(.build(hold: state.holds[seat].id, kind: .moonspire), as: vassal)) { error in
            XCTAssertEqual(error as? RuleError, .notApplicable, "The rules refuse it")
        }
        _ = state.stewardTurn(for: vassal)
        XCTAssertNotEqual(state.holds[seat].project?.kind, .moonspire, "Sworn, it doesn't")
    }

    func testBendingTheKneeStopsTheWorksOnAMoonspire() throws {
        var state = world()
        let stewards = state.houses.filter { !$0.isPlayer }.map(\.id)
        let (vassal, liege) = (stewards[0], stewards[1])
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == vassal && $0.isSeat })
        state.holds[seat].levels[.moonspire] = 4
        state.holds[seat].project = Hold.Project(kind: .moonspire, targetLevel: 5, watchesLeft: 1)
        XCTAssertEqual(RivalMind(house: liege).spireThreats(in: state), [vassal])
        _ = try state.propose(.fealty, from: vassal, to: liege)
        XCTAssertEqual(state.houses[vassal].liege, liege)
        XCTAssertNil(state.holds[seat].project, "Its tower's works stop")
        XCTAssertEqual(state.holds[seat].level(.moonspire), 4, "What stands, stands")
        XCTAssertEqual(RivalMind(house: liege).spireThreats(in: state), [], "A tower that can't rise is feared by no one")
        _ = state.endWatch()
        XCTAssertNil(state.outcome)
    }
}

