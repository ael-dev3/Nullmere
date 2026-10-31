import Foundation
import XCTest
@testable import NullmereCore

/// The veil of the Still, Rise of Kingdoms' peace shield: a keeper draws it
/// over their House's holds for eight watches, for moonsalt; while it lies
/// no hold of the House may be struck, rallied on or scouted; it lifts when
/// the House strikes another, and rests ten watches before it is drawn
/// again. Stewards draw none.
final class VeilTests: XCTestCase {
    /// Two keepers at war, the keeper's spear and Lanterns at the other's
    /// seat, which a rally of the keeper's alliance could be called on.
    private func war(_ seed: String) throws -> (state: GameState, me: Int, foe: Int, spear: Int, lantern: Int, seat: Hold) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let foe = (me + 1) % state.houses.count
        state.houses[foe].isPlayer = true
        state.houses[foe].stock.moonsalt = 100
        _ = try state.declareWar(by: me, on: foe)
        let seat = try XCTUnwrap(state.seat(of: foe))
        let beside = state.map.neighbors(of: seat.position).filter { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }
        XCTAssertGreaterThanOrEqual(beside.count, 2)
        let spear = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind.isMilitary })
        let lantern = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind == .lantern })
        state.units[spear].position = beside[0]
        state.units[lantern].position = beside[1]
        state.reveal(around: seat.position, range: 2, for: me)
        return (state, me, foe, state.units[spear].id, state.units[lantern].id, seat)
    }

    func testAVeiledHoldMayNotBeStruckRalliedOnOrScouted() throws {
        var (state, me, foe, spear, lantern, seat) = try war("a veil")
        let steward = (me + 2) % state.houses.count
        XCTAssertEqual(state.veilRefusal(as: steward), .notAKeeper, "Stewards draw none")
        var poor = state
        poor.houses[foe].stock.moonsalt = 10
        XCTAssertEqual(poor.veilRefusal(as: foe), .shortOf(Stock(moonsalt: 20)))

        // A rally called before the veil is drawn turns back when it lies.
        _ = try state.perform(.foundAlliance(name: "The Grey Oath"), as: me)
        let mine = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[mine].levels[.musterHall] = 1
        _ = try state.perform(.callRally(from: state.holds[mine].id, against: seat.id, watches: 2), as: me)
        let rally = try XCTUnwrap(state.ralliesStanding.first)

        let until = state.watch + GameState.veilLasts
        XCTAssertEqual(try state.perform(.drawVeil, as: foe), [.veilDrawn(house: foe, until: until)])
        XCTAssertTrue(state.isVeiled(foe))
        XCTAssertEqual(state.houses[foe].stock.moonsalt, 70)
        XCTAssertEqual(state.veilRefusal(as: foe), .veiledAlready(until: until))
        XCTAssertEqual(state.advanceRallies(), [.rallyDispersed(rally: rally.id, caller: me)])

        // Struck, rallied on, scouted: each refused while it lies.
        XCTAssertThrowsError(try state.perform(.attack(unit: spear, target: seat.position), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .veiled(until: until))
        }
        XCTAssertThrowsError(try state.perform(.callRally(from: state.holds[mine].id, against: seat.id, watches: 2), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .veiled(until: until))
        }
        XCTAssertThrowsError(try state.perform(.scout(unit: lantern, hold: seat.id), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .veiled(until: until))
        }
        XCTAssertTrue(RuleError.veiled(until: until).description.contains("until watch \(until)"))

        // Told to the realm, kept with the world and in every view.
        XCTAssertEqual(state.tidings(of: .veilDrawn(house: foe, until: until), for: foe)?.tone, .good)
        XCTAssertTrue(state.tidings(of: .veilDrawn(house: foe, until: until), for: me)?.text.hasSuffix("until watch \(until).") == true)
        XCTAssertTrue(state.events([.veilDrawn(house: foe, until: until)], heardBy: steward).contains(.veilDrawn(house: foe, until: until)))
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.veils, state.veils)
        XCTAssertEqual(state.view(for: me).veils, state.veils)
    }

    /// A House that strikes another lifts its own veil at once; it rests
    /// ten watches before it is drawn again, and is forgotten then.
    func testAVeilLiftsWhenItsHouseStrikesAnother() throws {
        var (state, me, foe, spear, _, _) = try war("lifted")
        _ = try state.perform(.drawVeil, as: foe)
        let mine = try XCTUnwrap(state.unit(spear))
        let striker = try XCTUnwrap(state.units.firstIndex { $0.owner == foe && $0.kind.isMilitary })
        let near = try XCTUnwrap(state.map.neighbors(of: mine.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        state.units[striker].position = near
        state.units[striker].movesLeft = state.units[striker].kind.movement
        let events = try state.perform(.attack(unit: state.units[striker].id, target: mine.position), as: foe)
        XCTAssertEqual(events.first, .veilLifted(house: foe, struck: true))
        XCTAssertFalse(state.isVeiled(foe))
        XCTAssertEqual(state.tidings(of: .veilLifted(house: foe, struck: true), for: foe)?.text,
                       "Your veil lifts: your House struck another. Your holds may be struck again.")
        XCTAssertEqual(state.tidings(of: .veilLifted(house: foe, struck: true), for: me)?.tone, .neutral)
        XCTAssertEqual(state.veilRefusal(as: foe), .veilResting(until: state.watch + GameState.veilRest))
        XCTAssertEqual(state.liftVeil(of: foe), [], "Lifted once")

        state.watch += GameState.veilRest
        XCTAssertNil(state.veilRefusal(as: foe))
        XCTAssertEqual(state.keepVeils(), [])
        XCTAssertNil(state.veils, "Rested, and forgotten")
    }

    /// Its watches out, a veil lifts of itself as the watch turns.
    func testAVeilsWatchesRunOut() throws {
        var (state, _, foe, _, _, _) = try war("run out")
        _ = try state.perform(.drawVeil, as: foe)
        var lifted: [GameEvent] = []
        for _ in 0..<GameState.veilLasts {
            lifted += state.endWatch().filter { if case .veilLifted = $0 { return true } else { return false } }
        }
        XCTAssertEqual(lifted, [.veilLifted(house: foe, struck: false)])
        XCTAssertFalse(state.isVeiled(foe))
        XCTAssertTrue(state.tidings(of: lifted[0], for: foe)?.text.contains("its watches are out") == true)
    }

    /// Stewards draw no veil, so a world of stewards goes as it always did.
    func testStewardsDrawNone() {
        var state = GameState(settings: GameSettings(seedText: "no veils", houseCount: 5, radius: 18))
        for _ in 0..<30 { _ = state.endWatch() }
        XCTAssertNil(state.veils)
        XCTAssertFalse(state.isVeiled(0))
    }
}
