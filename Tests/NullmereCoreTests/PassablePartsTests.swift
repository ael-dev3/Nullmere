import Foundation
import XCTest
@testable import NullmereCore

/// The stretches of passable ground: no march crosses from one to another,
/// and ground walled in by the Spine is a stretch of its own.
final class PassablePartsTests: XCTestCase {
    func testNoWayRunsBetweenTwoStretches() throws {
        var state = GameState(settings: GameSettings(seedText: "passable parts", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let unit = try XCTUnwrap(state.units(of: me).first)
        // A hex walled in by the Spine, away from every company and hold.
        let walled = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isPassable == true && hex.distance(to: unit.position) >= 4
                && hex.spiral(1).allSatisfy { state.unit(at: $0) == nil && state.hold(at: $0) == nil }
        })
        for hex in walled.neighbors where state.map[hex] != nil {
            state.map.set(hex, Tile(terrain: .spine))
        }
        let parts = state.map.passableParts()
        func part(_ hex: Hex) -> Int32 { parts[state.map.index(of: hex)!] }
        XCTAssertEqual(parts.filter { $0 == part(walled) }.count, 1, "Walled in, a stretch of its own")
        XCTAssertNotEqual(part(walled), part(unit.position))
        XCTAssertNil(state.path(for: unit, to: walled))
        for hex in walled.neighbors where state.map[hex] != nil {
            XCTAssertEqual(part(hex), -1, "The Spine is no stretch at all")
        }
        // Wherever a way runs, it runs within one stretch.
        for target in state.map.hexes.filter({ $0.distance(to: unit.position) <= 6 }) {
            if state.path(for: unit, to: target) != nil {
                XCTAssertEqual(part(target), part(unit.position), "\(target)")
            }
        }
    }
}
