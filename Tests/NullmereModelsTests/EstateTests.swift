import NullmereCore
@testable import NullmereModels
import XCTest

/// The estate a work raises about itself level by level: every family but
/// the walls grows by more than a thousand triangles from its first level
/// to its greatest, stays within its budget, and its estate's fine work is
/// kept for the near view.
final class EstateTests: XCTestCase {
    func testEveryWorkGrowsItsEstateWithinItsBudget() {
        for kind in BuildingKind.allCases where kind != .walls {
            let first = Library.model(.work(kind, level: 1)).mesh
            let greatest = Library.model(.work(kind, level: kind.maxLevel)).mesh
            XCTAssertLessThanOrEqual(greatest.triangleCount, Estate.ceiling, "\(kind)")
            XCTAssertGreaterThan(greatest.triangleCount, first.triangleCount + (kind.maxLevel >= 5 ? 1000 : 300), "\(kind) grows")
            XCTAssertNotNil(greatest.fineFrom, "\(kind) keeps fine work for the near view")
        }
        for level in 1...2 {
            XCTAssertGreaterThan(Library.model(.walls(level: level)).mesh.triangleCount, 2200, "The walls' own work at level \(level)")
        }
    }

    /// The sawpit works: at its first two levels the pit-saw rocks in its
    /// cut through the working clip; from the third a horse walks the gin
    /// that drives the frame saw.
    func testTheSawpitSaws() throws {
        for level in 1...5 {
            let model = Library.model(.work(.sawpit, level: level))
            let saw = try XCTUnwrap(model.rig.index(of: level <= 2 ? "pit-saw" : "gin"), "level \(level)")
            XCTAssertNotEqual(model.pose(.idle, at: 0)[saw], model.pose(.idle, at: 0.35)[saw], "The saw moves at level \(level)")
        }
    }
}
