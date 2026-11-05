import NullmereCore
@testable import NullmereModels
import XCTest

/// The Masons' Lodge, modelled whole at each level: within its budget and
/// richer at each level, the jib slewing its stone at every level and the
/// treadwheel turning from the fourth.
final class LodgeTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetAndGrows() {
        let counts = (1...5).map { Library.model(.work(.lodge, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.lodge, level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "Each level at least as rich as the one before: \(counts)")
    }

    func testTheJibSlewsAndTheTreadwheelTurns() throws {
        for level in 1...5 {
            let model = Library.model(.work(.lodge, level: level))
            let jib = try XCTUnwrap(model.rig.index(of: "lodge jib"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0)[jib].rotation, motion(.idle, 0.4)[jib].rotation, "The jib slews at level \(level)")
            let wheel = model.rig.index(of: "treadwheel")
            XCTAssertEqual(wheel != nil, level >= 4, "The treadwheel from the fourth level")
            if let wheel {
                XCTAssertNotEqual(motion(.idle, 0)[wheel].rotation, motion(.idle, 0.4)[wheel].rotation)
            }
        }
    }
}
