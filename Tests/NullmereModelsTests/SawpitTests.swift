import NullmereCore
@testable import NullmereModels
import XCTest

/// The Sawpit is modelled whole at each level, richer as it grows, within its
/// budget and slot, its saw always at work.
final class SawpitTests: XCTestCase {
    func testEachLevelIsItsOwnAndWithinItsBudget() {
        let counts = (1...5).map { Library.model(.work(.sawpit, level: $0)).mesh.triangleCount }
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.sawpit, level: 1).budget }, "\(counts)")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500, "\(counts)")
        XCTAssertTrue(Estate.bespoke.contains(.sawpit))
    }

    func testItsSawWorks() throws {
        for level in 1...5 {
            let model = Library.model(.work(.sawpit, level: level))
            let part = try XCTUnwrap(model.rig.index(of: level <= 2 ? "pit-saw" : "frame saw"), "level \(level)")
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0)[part].rotation, motion(.idle, 0.4)[part].rotation, "level \(level)")
        }
        XCTAssertNotNil(Library.model(.work(.sawpit, level: 4)).rig.index(of: "gin"))
    }
}
