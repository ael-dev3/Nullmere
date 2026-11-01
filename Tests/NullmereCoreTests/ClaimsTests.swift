import Foundation
import XCTest
@testable import NullmereCore

/// What the holds claim of the land is kept with the map's ground and
/// given again only to the same holds: whatever changed between, the kept
/// claims are the claims a realm with nothing kept makes afresh.
final class ClaimsTests: XCTestCase {
    /// The realm's territory with nothing kept: its copy through a save,
    /// whose map keeps nothing yet.
    private func fresh(_ state: GameState) throws -> [Int?] {
        try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)).territory()
    }

    func testKeptClaimsAreTheClaimsMadeAfresh() throws {
        var state = GameState(settings: GameSettings(seedText: "what the holds claim", houseCount: 4, radius: 16))
        let first = state.territory()
        XCTAssertEqual(state.territory(), first, "Asked again, the same")
        XCTAssertEqual(first, try fresh(state))

        // A beacon raised: the hold reaches further.
        let index = try XCTUnwrap(state.holds.indices.first)
        state.holds[index].levels[.beacon] = BuildingKind.beacon.maxLevel
        XCTAssertEqual(state.territory(), try fresh(state))
        XCTAssertNotEqual(state.territory(), first, "A beacon at its height claims more")

        // The ground changed under a claimed tile: it is claimed no more.
        let claimed = try XCTUnwrap(state.territory().indices.first { state.territory()[$0] != nil && state.map.hexes[$0] != state.holds[index].position })
        state.map.set(state.map.hexes[claimed], Tile(terrain: .still))
        XCTAssertNil(state.territory()[claimed], "Open water is no one's")
        XCTAssertEqual(state.territory(), try fresh(state))

        // Two copies of one map, their holds not the same, asking by turns.
        var other = state
        other.holds.removeLast()
        for _ in 0..<2 {
            XCTAssertEqual(state.territory(), try fresh(state))
            XCTAssertEqual(other.territory(), try fresh(other))
        }
        XCTAssertNotEqual(state.territory(), other.territory())

        // A copy whose ground changes keeps its own; the other's stands.
        var changed = state
        let before = state.territory()
        let tile = try XCTUnwrap(before.indices.first { before[$0] != nil && state.map.hexes[$0] != state.holds[index].position })
        changed.map.set(state.map.hexes[tile], Tile(terrain: .still))
        XCTAssertNil(changed.territory()[tile])
        XCTAssertEqual(state.territory(), before)
        XCTAssertEqual(changed.territory(), try fresh(changed))
    }
}
