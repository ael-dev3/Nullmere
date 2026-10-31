import Foundation
import XCTest
@testable import NullmereCore

/// A seat raised anew, Rise of Kingdoms' teleport within a House's own
/// land: its works, walls and ward as they stood and the company keeping
/// its gates with it; not while beset, and once in thirty watches.
/// Stewards move no seat.
final class SeatMoveTests: XCTestCase {
    private func realm(_ seed: String) throws -> (state: GameState, me: Int, seat: Hold, ground: Hex) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock.moonsalt = 100
        let seat = try XCTUnwrap(state.seat(of: me))
        let ground = try XCTUnwrap(state.map.hexes.first { state.seatMoveRefusal(to: $0, as: me) == nil },
                                   "Open ground of the House's own land")
        return (state, me, seat, ground)
    }

    func testAKeeperRaisesTheSeatAnewOnItsOwnLand() throws {
        var (state, me, seat, ground) = try realm("a seat raised anew")
        let other = (me + 1) % state.houses.count
        let theirs = try XCTUnwrap(state.seat(of: other))
        XCTAssertEqual(state.seatMoveRefusal(to: ground, as: other), .notAKeeper, "Stewards move no seat")
        XCTAssertEqual(state.seatMoveRefusal(to: seat.position, as: me), .notApplicable)
        XCTAssertEqual(state.seatMoveRefusal(to: Hex(999, 999), as: me), .outsideTheWorld)
        let foreign = try XCTUnwrap(theirs.position.neighbors.first { state.territoryOwner(of: $0) == other && state.map[$0]?.terrain.isSettleable == true })
        XCTAssertEqual(state.seatMoveRefusal(to: foreign, as: me), .foreignTerritory)
        if let water = state.map.hexes.first(where: { state.map[$0]?.terrain.isSettleable == false && state.territoryOwner(of: $0) == me }) {
            if case .cannotSettle? = state.seatMoveRefusal(to: water, as: me) {} else { XCTFail("Not on water") }
        }
        var poor = state
        poor.houses[me].stock.moonsalt = 15
        XCTAssertEqual(poor.seatMoveRefusal(to: ground, as: me), .shortOf(Stock(moonsalt: 25)))
        var struck = state
        let index = try XCTUnwrap(struck.holdIndex(seat.id))
        struck.holds[index].ward -= 1
        XCTAssertEqual(struck.seatMoveRefusal(to: ground, as: me), .seatBeset, "Not with its ward short of whole")

        // Raised anew, with the company keeping its gates.
        let keeper = state.unit(at: seat.position)
        let clear = state.unit(at: ground) == nil
        let events = try state.perform(.raiseSeat(at: ground), as: me)
        XCTAssertEqual(events, [.seatRaisedAnew(hold: seat.id, house: me, from: seat.position, to: ground)])
        let moved = try XCTUnwrap(state.hold(seat.id))
        XCTAssertEqual(moved.position, ground)
        XCTAssertEqual(moved.raisedAnew, state.watch)
        XCTAssertEqual(moved.levels, seat.levels, "Its works as they stood")
        XCTAssertEqual(moved.ward, seat.ward)
        XCTAssertEqual(state.houses[me].stock.moonsalt, 60)
        if let keeper, clear { XCTAssertEqual(state.unit(keeper.id)?.position, ground, "The company at its gates goes with it") }
        XCTAssertEqual(state.chronicle.last?.kind, .founding)
        XCTAssertTrue(state.houses[me].explored[try XCTUnwrap(state.map.index(of: ground))])

        // Told; heard by its House and whoever sees it; kept with the world.
        let raised = events[0]
        XCTAssertEqual(state.tidings(of: raised, for: me)?.tone, .good)
        XCTAssertTrue(state.tidings(of: raised, for: other)?.text.contains("raises its seat") == true)
        XCTAssertTrue(state.events([raised], heardBy: me).contains(raised))
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.hold(seat.id)?.position, ground)
        XCTAssertEqual(kept.hold(seat.id)?.raisedAnew, state.watch)
        XCTAssertEqual(state.view(for: me).hold(seat.id)?.position, ground)

        // Once in thirty watches.
        let again = try XCTUnwrap(state.map.hexes.first { $0 != ground && state.territoryOwner(of: $0) == me && state.map[$0]?.terrain.isSettleable == true })
        XCTAssertEqual(state.seatMoveRefusal(to: again, as: me), .seatRaisedLately(until: state.watch + GameState.seatMoveRest))
    }

    /// Not with a foe at war within three tiles of the seat.
    func testABesetSeatStaysWhereItIs() throws {
        var (state, me, seat, ground) = try realm("a seat beset")
        let foe = (me + 1) % state.houses.count
        _ = try state.declareWar(by: me, on: foe)
        let near = try XCTUnwrap(seat.position.spiral(GameState.seatMoveFoeReach).first { hex in
            hex != seat.position && hex != ground && state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let striker = try XCTUnwrap(state.units.firstIndex { $0.owner == foe && $0.kind.isMilitary })
        state.units[striker].position = near
        XCTAssertEqual(state.seatMoveRefusal(to: ground, as: me), .seatBeset)
        XCTAssertThrowsError(try state.perform(.raiseSeat(at: ground), as: me))
        XCTAssertTrue(RuleError.seatBeset.description.contains("three tiles"))
    }

    /// Stewards move no seat, so a world of stewards goes as it always did.
    func testStewardsMoveNoSeat() {
        var state = GameState(settings: GameSettings(seedText: "seats stay", houseCount: 5, radius: 18))
        for _ in 0..<30 { _ = state.endWatch() }
        XCTAssertTrue(state.holds.allSatisfy { $0.raisedAnew == nil })
    }
}
