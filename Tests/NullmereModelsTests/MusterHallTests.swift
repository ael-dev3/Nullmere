import NullmereCore
@testable import NullmereModels
import XCTest

/// The Muster Hall, modelled whole at each level: within its budget and
/// richer at each, its quintain spinning and, at the fifth, its drum beaten.
final class MusterHallTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetAndGrows() {
        let counts = (1...5).map { Library.model(.work(.musterHall, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.musterHall, level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertTrue(Raising.families.contains(.musterHall), "It rises with its truss lifted")
    }

    func testTheQuintainSpinsAndTheDrumIsBeaten() throws {
        for level in 1...5 {
            let model = Library.model(.work(.musterHall, level: level))
            let motion = try XCTUnwrap(model.motion)
            let quintain = try XCTUnwrap(model.rig.index(of: "quintain"), "level \(level)")
            XCTAssertNotEqual(motion(.idle, 0)[quintain].rotation, motion(.idle, 0.4)[quintain].rotation, "level \(level)")
            XCTAssertEqual(model.rig.index(of: "drumstick") != nil, level == 5)
        }
    }
}
