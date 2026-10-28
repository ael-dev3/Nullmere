import LauncherCore
import XCTest

/// The veil an open panel lays over the moon's image: an even pace each
/// way, settled at once when nothing animates, and drawn eased.
final class ReflectionVeilTests: XCTestCase {
    func testTheVeilMovesAtAnEvenPaceAndSettles() {
        var veil = ReflectionVeil()
        XCTAssertEqual(veil.value, 0)
        veil.advance(toward: 1, by: ReflectionVeil.duration / 4)
        XCTAssertEqual(veil.value, 0.25, accuracy: 1e-12)
        veil.advance(toward: 1, by: ReflectionVeil.duration)
        XCTAssertEqual(veil.value, 1, "Settled, not overshot")
        veil.advance(toward: 0, by: ReflectionVeil.duration / 2)
        XCTAssertEqual(veil.value, 0.5, accuracy: 1e-12)
        veil.advance(toward: 0, by: -1)
        XCTAssertEqual(veil.value, 0.5, accuracy: 1e-12, "Time never runs back")
        veil.advance(toward: 0, by: .infinity)
        XCTAssertEqual(veil.value, 0, "A lake that isn't animating settles at once")
        veil.advance(toward: 3, by: .infinity)
        XCTAssertEqual(veil.value, 1, "Within its bounds")
        XCTAssertEqual(ReflectionVeil(-2).value, 0)
    }

    func testTheVeilIsDrawnEased() {
        XCTAssertEqual(ReflectionVeil(0).shown, 0)
        XCTAssertEqual(ReflectionVeil(1).shown, 1)
        XCTAssertEqual(ReflectionVeil(0.5).shown, 0.5, accuracy: 1e-12)
        XCTAssertLessThan(ReflectionVeil(0.1).shown, 0.1, "Slow to begin")
        XCTAssertGreaterThan(ReflectionVeil(0.9).shown, 0.9, "and to end")
    }
}
