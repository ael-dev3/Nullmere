import XCTest
@testable import NullmereKit

@MainActor
final class ConfirmationTests: XCTestCase {
    /// War takes two presses, with no clock to beat between them, however
    /// long reading or scanning to the button takes; asking another lets
    /// the first go, and so does a button leaving the view.
    func testWarTakesTwoPressesWithNoClockToBeat() {
        let presses = ArmedPress()
        let war = UUID(), disband = UUID()
        XCTAssertFalse(presses.press(war), "The first press only asks")
        XCTAssertTrue(presses.isArmed(war))
        XCTAssertTrue(presses.press(war), "The second acts, however long after")
        XCTAssertFalse(presses.isArmed(war), "and the button is quiet again")

        XCTAssertFalse(presses.press(war))
        XCTAssertFalse(presses.press(disband), "Asking another")
        XCTAssertFalse(presses.isArmed(war), "lets the first go")
        XCTAssertFalse(presses.press(war), "which asks again rather than acts")
        presses.letGo(disband)
        XCTAssertTrue(presses.isArmed(war), "Letting go of one leaves the armed one be")
        presses.letGo(war)
        XCTAssertNil(presses.armed, "A button leaving the view lets go")
    }
}
