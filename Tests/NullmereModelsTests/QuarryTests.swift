import NullmereCore
@testable import NullmereModels
import XCTest

/// The Quarry, modelled whole at each level: within its budget and richer
/// at each, its face cut deeper, what lifts its stone at work.
final class QuarryTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetAndGrows() {
        let counts = (1...5).map { Library.model(.work(.quarry, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.quarry, level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
    }

    func testWhatLiftsTheStoneWorks() throws {
        let parts = ["quarry windlass", "quarry tackle", "quarry boom", "quarry treadwheel", "quarry trolley"]
        for level in 1...5 {
            let model = Library.model(.work(.quarry, level: level))
            let part = try XCTUnwrap(model.rig.index(of: parts[level - 1]), "level \(level)")
            XCTAssertNotEqual(model.pose(.idle, at: 0)[part], model.pose(.idle, at: 0.4)[part], "level \(level)")
        }
    }
}
