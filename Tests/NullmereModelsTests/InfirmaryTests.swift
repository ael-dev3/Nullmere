import NullmereCore
@testable import NullmereModels
import XCTest

/// The Infirmary, modelled whole at each level: within its budget and
/// richer at each, its well's windlass turning, its ward smoking from the
/// second level.
final class InfirmaryTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetAndGrows() {
        let counts = (1...5).map { Library.model(.work(.infirmary, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.infirmary, level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertTrue(Estate.bespoke.contains(.infirmary))
    }

    func testItsWellTurnsAndItsWardSmokes() throws {
        for level in 1...5 {
            let model = Library.model(.work(.infirmary, level: level))
            let drum = try XCTUnwrap(model.rig.index(of: "well windlass"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0)[drum].rotation, motion(.idle, 0.4)[drum].rotation, "level \(level)")
            XCTAssertEqual(Library.smoke(of: .work(.infirmary, level: level)).count, level >= 2 ? 1 : 0, "level \(level)")
        }
    }
}
