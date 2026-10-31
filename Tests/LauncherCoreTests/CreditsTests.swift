import LauncherCore
import XCTest

/// The credits: who made the game and under what licence, rolled at an
/// even pace, still at the head and the end, and round again.
final class CreditsTests: XCTestCase {
    func testTheCreditsNameTheGameItsMakersAndItsLicences() {
        XCTAssertEqual(Credits.lines.first, Credits.Line(.title, "Nullmere Online"))
        let text = Credits.lines.map(\.text)
        XCTAssertTrue(text.contains("Apache License 2.0") || text.contains { $0.contains("Apache License 2.0") })
        XCTAssertTrue(text.contains { $0.contains("CC0 1.0") })
        XCTAssertEqual(Set(text).count, text.count, "No line twice")
        XCTAssertEqual(MenuItem.credits.title, "Credits")
    }

    func testTheCreditsRollEvenlyAndRoundAgain() {
        let (roll, window) = (600.0, 300.0)
        XCTAssertEqual(Credits.offset(at: 0, rollHeight: roll, windowHeight: window), 0)
        XCTAssertEqual(Credits.offset(at: Credits.rollPause - 0.1, rollHeight: roll, windowHeight: window), 0, "Still at the head")
        XCTAssertEqual(Credits.offset(at: Credits.rollPause + 10, rollHeight: roll, windowHeight: window), 10 * Credits.rollSpeed, accuracy: 1e-9)
        let through = (roll + window) / Credits.rollSpeed
        XCTAssertEqual(Credits.offset(at: Credits.rollPause + through + 0.5, rollHeight: roll, windowHeight: window), roll + window,
                       "Rolled through, and still at the end")
        let cycle = Credits.rollPause * 2 + through
        XCTAssertEqual(Credits.offset(at: cycle + 1, rollHeight: roll, windowHeight: window), 0, "Round again")
        XCTAssertEqual(Credits.offset(at: Credits.rollPause + 10, rollHeight: roll, windowHeight: window, unit: 2), 20 * Credits.rollSpeed,
                       accuracy: 1e-9, "At twice the size, twice as fast")
        XCTAssertEqual(Credits.offset(at: 50, rollHeight: 0, windowHeight: 0), 0)
    }
}
