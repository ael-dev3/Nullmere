import LauncherCore
import XCTest

/// Lines said for the smoke tests: always in a debug build, which tests are.
final class ReportingTests: XCTestCase {
    func testADebugBuildSaysItsLines() {
        #if DEBUG
        XCTAssertTrue(Reporting.isOn)
        #endif
        Reporting.say("REPORTING the lake renders")
    }
}
