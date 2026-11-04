import XCTest
@testable import NullmereModels

/// The Lyceum's hall: a domed round house filling the heart of its hex,
/// within its budget, its braziers smoking and its orrery apart.
final class LyceumHallTests: XCTestCase {
    func testTheHallIsWholeWithinItsHexAndBudget() {
        let hall = Library.model(.lyceumHall)
        XCTAssertLessThanOrEqual(hall.mesh.triangleCount, ModelKey.lyceumHall.budget)
        XCTAssertGreaterThan(hall.mesh.triangleCount, 400, "columns, dome, doors and braziers")
        XCTAssertLessThanOrEqual(max(abs(hall.mesh.bounds.min.x), hall.mesh.bounds.max.x), 0.62)
        XCTAssertLessThanOrEqual(max(abs(hall.mesh.bounds.min.z), hall.mesh.bounds.max.z), 0.62)
        XCTAssertGreaterThan(hall.mesh.bounds.max.y, LyceumHall.crown, "its dome stands over its columns")
        XCTAssertEqual(Library.smoke(of: .lyceumHall).count, 4, "four braziers")
    }

    func testTheOrreryTurnsOverTheDomesEye() {
        let orrery = Library.model(.lyceumOrrery)
        XCTAssertLessThanOrEqual(orrery.mesh.triangleCount, ModelKey.lyceumOrrery.budget)
        XCTAssertGreaterThan(LyceumHall.orreryAt.y, LyceumHall.crown)
        XCTAssertLessThan(orrery.mesh.bounds.max.x, 0.1, "small enough to sit on the eye")
    }
}
