import NullmereCore
@testable import NullmereModels
import XCTest

/// The Beacon, modelled whole at each of its three levels: within its
/// budget and richer at each, taller at each, its fire leaping.
final class BeaconTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetTallerAndRicher() {
        let models = (1...3).map { Library.model(.work(.beacon, level: $0)) }
        let counts = models.map(\.mesh.triangleCount)
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.beacon, level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[2], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        let heights = models.map(\.mesh.bounds.max.y)
        XCTAssertEqual(heights, heights.sorted(), "Taller at each level: \(heights)")
    }

    func testItsFireLeaps() throws {
        for level in 1...3 {
            let model = Library.model(.work(.beacon, level: level))
            let fire = try XCTUnwrap(model.rig.index(of: "beacon fire"), "level \(level)")
            XCTAssertNotEqual(model.pose(.idle, at: 0.05)[fire], model.pose(.idle, at: 0.3)[fire], "The fire leaps at level \(level)")
        }
    }
}
