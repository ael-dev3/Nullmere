import NullmereCore
@testable import NullmereModels
import XCTest

/// The Saltworks, modelled whole at each level: within its budget and
/// richer at each, its shaduf dipping or its brine wheel turning, its
/// boiling house smoking where it has one.
final class SaltworksTests: XCTestCase {
    func testEachLevelStandsWithinItsBudgetAndGrows() {
        let counts = (1...5).map { Library.model(.work(.saltworks, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.saltworks, level: 1).budget }, "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "Its greatest level near its budget")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertTrue(Estate.bespoke.contains(.saltworks))
    }

    func testItsBrineIsLiftedAndItsFurnaceSmokes() throws {
        for level in 1...5 {
            let model = Library.model(.work(.saltworks, level: level))
            let part = try XCTUnwrap(model.rig.index(of: level >= 4 ? "brine wheel" : "shaduf"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0)[part].rotation, motion(.idle, 0.4)[part].rotation, "level \(level)")
            XCTAssertEqual(Library.smoke(of: .work(.saltworks, level: level)).count, (3...4).contains(level) ? 1 : 0, "level \(level)")
        }
    }
}
