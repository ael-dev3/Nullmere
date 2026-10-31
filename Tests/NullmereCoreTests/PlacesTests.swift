import Foundation
import XCTest
@testable import NullmereCore

/// A keeper sets each work of a hold in a place of their own round the
/// keep: a work set where another stood trades places with it.
final class PlacesTests: XCTestCase {
    private func staged() throws -> (state: GameState, me: Int, seat: Int) {
        var state = Scene.world("places")
        let me = state.player
        let seat = try XCTUnwrap(state.holdIndex(try XCTUnwrap(state.seat(of: me)).id))
        state.holds[seat].levels[.granary] = 2
        state.holds[seat].levels[.sawpit] = 1
        state.holds[seat].levels[.walls] = 1
        return (state, me, seat)
    }

    func testAKeeperSetsAWorkInItsPlace() throws {
        var (state, me, seat) = try staged()
        let id = state.holds[seat].id
        XCTAssertNil(state.holds[seat].places, "None set: the works stand where their ground suits them")
        let events = try state.perform(.placeWork(hold: id, kind: .granary, place: 3), as: me)
        XCTAssertEqual(events, [.workPlaced(hold: id, kind: .granary, place: 3)])
        XCTAssertEqual(state.holds[seat].place(of: .granary), 3)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "The Granary of \(state.holds[seat].name) stands where you set it.")
        let other = (me + 1) % state.houses.count
        XCTAssertNil(state.tidings(of: events[0], for: other))
        XCTAssertTrue(state.events(events, heardBy: me).contains(events[0]))
        XCTAssertFalse(state.events(events, heardBy: other).contains(events[0]), "Its own keeper's alone")

        // Set where another stands, the two trade places; one set where an
        // unset work stood leaves that work to its ground.
        _ = try state.perform(.placeWork(hold: id, kind: .sawpit, place: 7), as: me)
        _ = try state.perform(.placeWork(hold: id, kind: .sawpit, place: 3), as: me)
        XCTAssertEqual(state.holds[seat].places, [.sawpit: 3, .granary: 7])
        _ = try state.perform(.placeWork(hold: id, kind: .granary, place: 11), as: me)
        _ = try state.perform(.placeWork(hold: id, kind: .granary, place: 3), as: me)
        XCTAssertEqual(state.holds[seat].places, [.granary: 3, .sawpit: 11])

        // A work rising may be set before it stands.
        state.holds[seat].project = Hold.Project(kind: .forge, targetLevel: 1, watchesLeft: 2)
        XCTAssertNil(state.placeRefusal(.forge, of: id, at: 17, as: me))

        // Kept with the hold.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.holds[seat].places, state.holds[seat].places)
    }

    func testOnlyAWorkStandingInTheKeepersHoldIsSet() throws {
        let (state, me, seat) = try staged()
        let id = state.holds[seat].id
        XCTAssertEqual(state.placeRefusal(.granary, of: 999, at: 0, as: me), .unknownHold)
        XCTAssertEqual(state.placeRefusal(.granary, of: id, at: 0, as: (me + 1) % state.houses.count), .notYours)
        XCTAssertEqual(state.placeRefusal(.walls, of: id, at: 0, as: me), .notApplicable, "The walls ring the keep")
        XCTAssertEqual(state.placeRefusal(.quarry, of: id, at: 0, as: me), .notApplicable, "Not raised")
        XCTAssertEqual(state.placeRefusal(.granary, of: id, at: Hold.placeCount, as: me), .notApplicable)
        XCTAssertEqual(state.placeRefusal(.granary, of: id, at: -1, as: me), .notApplicable)
        var refused = state
        XCTAssertThrowsError(try refused.perform(.placeWork(hold: id, kind: .quarry, place: 2), as: me)) {
            XCTAssertEqual($0 as? RuleError, .notApplicable)
        }
        XCTAssertNil(refused.holds[seat].places)
        let plain = String(decoding: try JSONEncoder().encode(state.holds[seat]), as: UTF8.self)
        XCTAssertFalse(plain.contains("places"), "A hold none were set in is kept as before")
    }
}
