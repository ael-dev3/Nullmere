import FoundationModels
import LauncherCore
import XCTest
@testable import LauncherKit

final class OnDeviceModelTests: XCTestCase {
    func testAvailabilityMapsToReadiness() {
        XCTAssertEqual(OnDeviceModel.readiness(for: .available), .ready)
        XCTAssertEqual(OnDeviceModel.readiness(for: .unavailable(.deviceNotEligible)), .deviceNotEligible)
        XCTAssertEqual(OnDeviceModel.readiness(for: .unavailable(.appleIntelligenceNotEnabled)), .appleIntelligenceNotEnabled)
        XCTAssertEqual(OnDeviceModel.readiness(for: .unavailable(.modelNotReady)), .modelNotReady)
    }

    /// Whatever this Mac supports, the framework gives a definite answer.
    func testTheSystemAnswers() {
        XCTAssertNotEqual(OnDeviceModel.current(), .checking)
    }
}
