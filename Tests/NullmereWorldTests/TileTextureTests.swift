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
            XCTAssertEqual(Int(TileTexture.terrain(bytes[offset])), Terrain.allCases.firstIndex(of: state.map[index].terrain))
            if visible[index] {
                XCTAssertEqual(TileTexture.seen(bytes[offset + 1]), 2)
            }
        }
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let offset = ((seat.position.r + 14) * side + (seat.position.q + 14)) * 4
        XCTAssertEqual(TileTexture.owner(bytes, at: offset), state.houses[state.player].sigil + 1, "the seat is in its House's colour")
        XCTAssertEqual(bytes[offset + 1] & TileTexture.holdFlag, TileTexture.holdFlag, "the seat is lit")
        XCTAssertEqual(TileTexture.seen(bytes[offset + 1]), 2, "the seat watched, its flag apart")
        let explored = state.houses[state.player].explored
        for hold in state.holds where hold.owner != state.player {
            let index = try XCTUnwrap(state.map.index(of: hold.position))
            let o = ((hold.position.r + 14) * side + (hold.position.q + 14)) * 4
            XCTAssertEqual(bytes[o + 1] & TileTexture.holdFlag != 0, explored[index], "only known holds are lit")
        }
    }

    /// What the keeper knows of a tile and whether a hold stands on it
    /// share the feature byte, each in bits of its own; whose land it is
    /// has twelve bits, room for every House a lake seats.
    func testEveryHouseOfTheWidestLakeWashesItsLandInItsOwnColour() throws {
        XCTAssertLessThan(Feature.allCases.count + 1, Int(TileTexture.seenStep), "Features below the knowledge bits")
        XCTAssertEqual(TileTexture.seen(0), 0)
        XCTAssertEqual(TileTexture.seen(TileTexture.seenStep + 3), 1)
        XCTAssertEqual(TileTexture.seen(2 * TileTexture.seenStep | TileTexture.holdFlag | 5), 2)
        XCTAssertGreaterThanOrEqual(TileTexture.mostOwner, WorldGenerator.mostHouses, "A tile can name every House a lake seats")
        XCTAssertLessThan(Terrain.allCases.count, 16, "The terrain's code in the first byte's low half, under the owner's")
        let state = GameState(settings: GameSettings(seedText: "every colour", houseCount: 48, radius: 72))
        let bytes = TileTexture.bytes(for: state, viewer: 0, visible: [Bool](repeating: true, count: state.map.count))
        let side = TileTexture.side(for: state.map)
        var owners: Set<Int> = []
        for hold in state.holds where hold.isSeat {
            let offset = ((hold.position.r + 72) * side + (hold.position.q + 72)) * 4
            XCTAssertEqual(TileTexture.owner(bytes, at: offset), state.houses[hold.owner].sigil + 1)
            owners.insert(TileTexture.owner(bytes, at: offset))
        }
        XCTAssertEqual(owners.count, 48, "Forty-eight seats, forty-eight colours")
        XCTAssertGreaterThan(owners.max() ?? 0, 16, "Past the old sixteen")
    }

    /// A House of a realm of a thousand names its land as plainly as one of
    /// twelve: its sigil plus one over both bytes, past the fourth byte's
    /// 255, the terrain's code under it as it was; a sigil no tile can
    /// name, none the realm seats, names no other House's instead.
    func testATileNamesAHouseOfARealmOfAThousand() throws {
        var state = GameState(settings: GameSettings(seedText: "a thousand", houseCount: 3, radius: 14, keepers: 1))
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let side = TileTexture.side(for: state.map)
        let offset = ((seat.position.r + 14) * side + (seat.position.q + 14)) * 4
        let terrain = try XCTUnwrap(state.map[seat.position]).terrain.code
        for (sigil, named) in [(1_000, 1_001), (255, 256), (1_023, 1_024), (TileTexture.mostOwner - 1, TileTexture.mostOwner),
                               (5_000, TileTexture.mostOwner)] {
            state.houses[state.player].sigil = sigil
            let bytes = TileTexture.bytes(for: state, viewer: state.player)
            XCTAssertEqual(TileTexture.owner(bytes, at: offset), named, "Sigil \(sigil)")
            XCTAssertEqual(TileTexture.terrain(bytes[offset]), terrain, "The terrain as it was, under sigil \(sigil)")
        }
    }
}

private extension GameState {
    var playerHouse: House { houses[player] }
}

