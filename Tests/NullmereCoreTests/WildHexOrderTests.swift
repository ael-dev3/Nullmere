import XCTest
@testable import NullmereCore

/// A keeper's order carries a client-chosen Hex. The realm must treat a
/// hex far outside the world as simply out of bounds, never let its
/// coordinates overflow the arithmetic that places it.
final class WildHexOrderTests: XCTestCase {
    private func newGame() -> GameState {
        GameState(settings: GameSettings(seedText: "the still water", keepers: 1))
    }

    private static let wild: [Hex] = [
        Hex(Int.max, 0), Hex(Int.min, 0), Hex(0, Int.max), Hex(0, Int.min),
        Hex(Int.max, Int.max), Hex(Int.min, Int.min), Hex(Int.max, Int.min),
    ]

    func testMapContainsRejectsWildCoordinatesWithoutTrapping() {
        let map = newGame().map
        for hex in Self.wild {
            XCTAssertFalse(map.contains(hex), "\(hex) is far outside the world")
            XCTAssertNil(map[hex], "\(hex) has no tile")
            XCTAssertNil(map.index(of: hex), "\(hex) has no index")
        }
    }

    func testAnOrderToMoveToAWildHexIsRefusedNotACrash() {
        var state = newGame()
        let unit = state.units(of: 0).first!
        for hex in Self.wild {
            XCTAssertThrowsError(try state.perform(.move(unit: unit.id, to: hex), as: 0), "\(hex)") { error in
                XCTAssertEqual(error as? RuleError, .outsideTheWorld, "\(hex)")
            }
        }
    }
}
