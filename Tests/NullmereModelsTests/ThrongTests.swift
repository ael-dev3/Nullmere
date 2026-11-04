import XCTest
@testable import NullmereModels

/// A company in a field of battle shows its troops' throng: more figures
/// the more troops stand, in ranks toward the foe, every one in its hex.
final class ThrongTests: XCTestCase {
    func testAThrongGrowsWithItsTroopsAndStaysInItsHex() {
        let spear = ModelKey.figure(.spear, tier: 5)
        XCTAssertEqual(Formation.throngCount(spear, troops: 0), 0)
        XCTAssertEqual(Formation.throngCount(spear, troops: 100), Formation.strength(spear), "never fewer than its formation")
        XCTAssertEqual(Formation.throngCount(spear, troops: 25_000), Formation.throngMost, "a drilled company of 25,000 fills its hex")
        XCTAssertLessThan(Formation.throngCount(spear, troops: 12_000), Formation.throngMost)
        let places = Formation.throng(count: Formation.throngMost, seed: 7)
        XCTAssertEqual(places.count, Formation.throngMost)
        for place in places { XCTAssertLessThanOrEqual((place.x * place.x + place.z * place.z).squareRoot(), Formation.hexInner) }
        XCTAssertEqual(places, Formation.throng(count: Formation.throngMost, seed: 7), "the same each frame")
        XCTAssertGreaterThan(places.map(\.z).max()!, 0.1, "pressed toward its front")
        XCTAssertLessThan(places.map(\.z).min()!, -0.1, "and back to its rear")
        let set = Set(places.map { "\(Int($0.x * 100)) \(Int($0.z * 100))" })
        XCTAssertEqual(set.count, places.count, "no two figures on one spot")
    }
}
