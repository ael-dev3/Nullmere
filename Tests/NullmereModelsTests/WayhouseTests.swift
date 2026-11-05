import NullmereCore
@testable import NullmereModels
import XCTest

/// The Wayhouse is modelled whole at each level, richer as it grows, within its
/// budget and slot, its sign swinging and its vane turning.
final class WayhouseTests: XCTestCase {
    func testEachLevelIsItsOwnAndWithinItsBudget() {
        let counts = (1...5).map { Library.model(.work(.wayhouse, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.wayhouse, level: 1).budget }, "\(counts)")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "\(counts)")
    }

    func testItsSignSwingsAndItsVaneTurns() throws {
        for level in 1...5 {
            let model = Library.model(.work(.wayhouse, level: level))
            let part = try XCTUnwrap(model.rig.index(of: "inn sign"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0)[part].rotation, motion(.idle, 0.4)[part].rotation, "level \(level)")
        }
        XCTAssertNotNil(Library.model(.work(.wayhouse, level: 4)).rig.index(of: "post vane"))
    }
}
