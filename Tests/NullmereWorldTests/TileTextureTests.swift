@testable import NullmereCore
@testable import NullmereWorld
import XCTest

final class TileTextureTests: XCTestCase {
    func testEachTileLandsAtItsAxialTexel() throws {
        let state = GameState(settings: GameSettings(seedText: "tile texture", houseCount: 3, radius: 14, keepers: 1))
        let side = TileTexture.side(for: state.map)
        let bytes = TileTexture.bytes(for: state, viewer: state.player)
        XCTAssertEqual(side, 29)
        XCTAssertEqual(bytes.count, side * side * 4)
        let visible = state.visibility(for: state.player)
        for (index, hex) in state.map.hexes.enumerated() {
            let offset = ((hex.r + 14) * side + (hex.q + 14)) * 4
            XCTAssertEqual(Int(bytes[offset]), Terrain.allCases.firstIndex(of: state.map[index].terrain))
            if visible[index] {
                XCTAssertEqual(bytes[offset + 3] / 16, 2)
            }
        }
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let offset = ((seat.position.r + 14) * side + (seat.position.q + 14)) * 4
        XCTAssertEqual(Int(bytes[offset + 3] % 16), state.houses[state.player].sigil + 1, "the seat is in its House's colour")
        XCTAssertEqual(bytes[offset + 1] & TileTexture.holdFlag, TileTexture.holdFlag, "the seat is lit")
        let explored = state.houses[state.player].explored
        for hold in state.holds where hold.owner != state.player {
            let index = try XCTUnwrap(state.map.index(of: hold.position))
            let o = ((hold.position.r + 14) * side + (hold.position.q + 14)) * 4
            XCTAssertEqual(bytes[o + 1] & TileTexture.holdFlag != 0, explored[index], "only known holds are lit")
        }
    }
}

private extension GameState {
    var playerHouse: House { houses[player] }
}

