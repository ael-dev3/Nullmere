import NullmereCore
@testable import NullmereModels
import XCTest

/// The Forge is modelled whole at each level, richer as it grows, within its
/// budget and slot, its hearths flickering and its hammer beating.
final class ForgeTests: XCTestCase {
    func testEachLevelIsItsOwnAndWithinItsBudget() {
        let counts = (1...5).map { Library.model(.work(.forge, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.forge, level: 1).budget }, "\(counts)")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "\(counts)")
    }

    func testItsHammerBeatsAndItsHearthFlickers() throws {
        for level in 1...5 {
            let model = Library.model(.work(.forge, level: level))
            let part = try XCTUnwrap(model.rig.index(of: level <= 2 ? "bellows" : "hammer"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0)[part].rotation, motion(.idle, 0.4)[part].rotation, "level \(level)")
        }
        XCTAssertNotNil(Library.model(.work(.forge, level: 4)).rig.index(of: "grindstone"))
    }
}
