import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The night's brightness, as the keeper chooses it in the realm's
/// Settings: dark as the lake was made, or lighter, every pass of the
/// picture taking it alike as the frame's exposure.
final class NightTests: XCTestCase {
    func testTheNightIsDarkAsMadeOrLighterByChoice() {
        XCTAssertEqual(Night.allCases.map(\.title), ["Dark", "Moonlit", "Bright"])
        XCTAssertEqual(Night.dark.exposure, 1, "The night as the lake was made")
        XCTAssertEqual(Night.allCases.map(\.exposure), Night.allCases.map(\.exposure).sorted(), "Each lighter than the last")
        XCTAssertLessThanOrEqual(Night.bright.exposure, 2, "Still a night")
        XCTAssertEqual(Night(stored: 0), .dark)
        XCTAssertEqual(Night(stored: 1), .moonlit)
        XCTAssertEqual(Night(stored: 2), .bright)
        XCTAssertEqual(Night(stored: 9), .dark, "A choice that doesn't read is the night as made")
        XCTAssertEqual(Night(stored: -1), .dark)
        XCTAssertEqual(Night.key, "world.night")

        // Carried into every pass as the frame's exposure.
        let terrain = TerrainMesh(relief: Relief(map: WorldMap(radius: 8, fill: Tile(terrain: .greyfield))))
        for night in Night.allCases {
            let frame = FrameUniforms.make(camera: Camera(), size: CGSize(width: 800, height: 600), pixelsPerPoint: 2, time: 0, motion: 1,
                                           radius: 8, terrain: terrain, hovered: nil, selected: nil, exposure: night.exposure)
            XCTAssertEqual(frame.haze.z, night.exposure)
        }
    }
}
