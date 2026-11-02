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
        XCTAssertEqual(Estate.dress(Library.model(.work(.walls, level: 2)), .walls, level: 2).mesh.triangleCount,
                       Library.model(.work(.walls, level: 2)).mesh.triangleCount, "The walls' estate is their own towers")
    }

    func testLayeringKeepsEachMeshsFineWorkFine() {
        var a = MeshBuilder(), b = MeshBuilder()
        a.box(center: .zero, size: Vec3(repeating: 0.1), turn: 0, color: Palette.stone)
        a.fine { $0.box(center: .zero, size: Vec3(repeating: 0.01), turn: 0, color: Palette.stone) }
        b.box(center: .zero, size: Vec3(repeating: 0.1), turn: 0, color: Palette.timber)
        let laid = Estate.layered(a.mesh, b.mesh)
        XCTAssertEqual(laid.triangleCount, a.mesh.triangleCount + b.mesh.triangleCount)
        XCTAssertEqual(laid.fineFrom, a.mesh.coarseIndexCount + b.mesh.coarseIndexCount)
        XCTAssertEqual(Estate.layered(a.mesh, Mesh()), a.mesh)
    }

    /// The sawpit works: at its first two levels the pit-saw rocks in its
    /// cut through the working clip; from the third a horse walks the gin
    /// that drives the frame saw.
    func testTheSawpitSaws() throws {
        for level in 1...5 {
            let model = Library.model(.work(.sawpit, level: level))
            let saw = try XCTUnwrap(model.rig.index(of: level <= 2 ? "pit-saw" : "gin"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            let early = motion(.idle, 0.0), later = motion(.idle, 0.35)
            XCTAssertNotEqual(early[saw].rotation, later[saw].rotation, "The saw moves at level \(level)")
        }
        XCTAssertTrue(Estate.bespoke.contains(.sawpit))
        XCTAssertEqual(Estate.parts(4, .granary).count, 2)
    }
}
