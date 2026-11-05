import NullmereCore
@testable import NullmereModels
import XCTest

/// The Archive, modelled whole at each level: within its budget and richer
/// at each, its vane or its armillary turning, raised beside a crane.
final class ArchiveTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetAndGrows() {
        let counts = (1...5).map { Library.model(.study(level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.study(level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertEqual(Library.model(.work(.archive, level: 3)).mesh, Library.model(.study(level: 3)).mesh)
        XCTAssertTrue(Raising.families.contains(.archive))
    }

    func testItsVaneOrArmillaryTurns() throws {
        for level in 1...5 {
            let model = Library.model(.study(level: level))
            let part = try XCTUnwrap(model.rig.index(of: level <= 2 ? "archive vane" : "armillary"), "level \(level)")
            XCTAssertNotEqual(model.pose(.idle, at: 0)[part], model.pose(.idle, at: 0.4)[part], "level \(level)")
        }
    }
}
