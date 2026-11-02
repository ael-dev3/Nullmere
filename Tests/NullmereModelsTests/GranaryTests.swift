import NullmereCore
@testable import NullmereModels
import XCTest

/// The Granary, modelled whole at each level: within its budget and
/// richer at each, its sack hoist swinging at the loft door.
final class GranaryTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetAndGrows() {
        let counts = (1...5).map { Library.model(.work(.granary, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.granary, level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertTrue(Estate.bespoke.contains(.granary))
    }

    func testTheSackHoistSwings() throws {
        for level in 1...5 {
            let model = Library.model(.work(.granary, level: level))
            let hoist = try XCTUnwrap(model.rig.index(of: "sack hoist"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0)[hoist].rotation, motion(.idle, 0.4)[hoist].rotation, "level \(level)")
        }
    }
}
