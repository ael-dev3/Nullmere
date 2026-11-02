import NullmereCore
@testable import NullmereModels
import XCTest

/// The Moonspire stands in a court of its own, richer with each stage, and
/// no common estate: within its budget, its crystal turning when crowned.
final class MoonspireTests: XCTestCase {
    func testItsCourtGrowsWithinItsBudget() {
        let counts = (1...5).map { Library.model(.work(.moonspire, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.moonspire, level: 1).budget }, "\(counts)")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500)
        XCTAssertTrue(Estate.bespoke.contains(.moonspire))
        for level in 1...5 {
            let tower = Works.moonspire(level, "tower").mesh.triangleCount
            XCTAssertGreaterThan(counts[level - 1], tower, "Its court laid about it at stage \(level)")
        }
        XCTAssertNotNil(Library.model(.work(.moonspire, level: 5)).motion, "The crowned spire's crystal turns")
    }
}
