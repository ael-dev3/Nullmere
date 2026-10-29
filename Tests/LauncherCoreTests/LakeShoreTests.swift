import XCTest
@testable import LauncherCore

/// The far shore drawn without Metal is the shader's own: the same hash,
/// noise and shapes, giving the same heights, worked as the GPU works them.
final class LakeShoreTests: XCTestCase {
    /// Heights the shader's formulas give in single precision, as worked
    /// out apart from this code.
    func testTheShoreIsTheShadersOwn() {
        XCTAssertEqual(Double(LakeShore.hash(3, 5)), 0.576125, accuracy: 0.002)
        XCTAssertEqual(Double(LakeShore.hash(-7.5, 12.25)), 0.358341, accuracy: 0.002)
        for (x, mesas, bank) in [(0.1, 0.016296, 0.005936), (0.5, 0.053624, 0.005830), (0.77, 0.060210, 0.004562),
                                 (1.0, 0.060168, 0.006459), (1.3, 0.016758, 0.004919)] {
            XCTAssertEqual(LakeShore.mesas(x), mesas, accuracy: 0.0008, "Mesas at \(x)")
            XCTAssertEqual(LakeShore.bank(x), bank, accuracy: 0.0004, "Bank at \(x)")
        }
    }

    /// A broad range across most of a view, no higher than the tallest, and
    /// a bank lower still.
    func testTheShoreKeepsItsShape() {
        let xs = stride(from: 0.0, through: 1.54, by: 0.002).map { $0 }
        let heights = xs.map(LakeShore.mesas)
        XCTAssertLessThanOrEqual(heights.max() ?? 1, LakeShore.tallest)
        XCTAssertGreaterThanOrEqual(heights.min() ?? -1, 0)
        let standing = Double(heights.filter { $0 > 0.02 }.count) / Double(heights.count)
        XCTAssertEqual(standing, 0.6, accuracy: 0.15, "Mesas stand along most of the view")
        XCTAssertLessThan(xs.map(LakeShore.bank).max() ?? 1, 0.0085, "The bank stays low")
    }
}
