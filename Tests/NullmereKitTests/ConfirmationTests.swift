import XCTest
@testable import NullmereKit

final class ConfirmationTests: XCTestCase {
    func testWarTakesTwoPressesCloseTogether() {
        var confirmation = Confirmation()
        let start = Date()
        XCTAssertFalse(confirmation.press(at: start), "The first press only asks")
        XCTAssertTrue(confirmation.isArmed(at: start.addingTimeInterval(1)))
        XCTAssertTrue(confirmation.press(at: start.addingTimeInterval(2)), "The second, soon after, acts")
        XCTAssertFalse(confirmation.isArmed(at: start.addingTimeInterval(2)), "and the button is quiet again")

        XCTAssertFalse(confirmation.press(at: start.addingTimeInterval(10)))
        XCTAssertFalse(confirmation.press(at: start.addingTimeInterval(10 + Confirmation.window + 1)), "Too late: it only asks again")
        confirmation.lapse(at: start.addingTimeInterval(100))
        XCTAssertNil(confirmation.armedAt)
    }
}
