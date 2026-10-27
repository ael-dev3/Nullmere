import Foundation
import XCTest
@testable import NullmereCore

/// How fast this machine runs the rules today: a fixed piece of the game's
/// own work, timed by this thread's CPU. scripts/perf-check.py scales the
/// CPU figures' allowances by it, so a slower shared runner doesn't fail
/// the build, while a slower path still does.
final class CalibrationTests: XCTestCase {
    func testTheMachinesPace() {
        var best = Double.infinity
        // The best of three: the machine at its steadiest.
        for _ in 0..<3 {
            let started = RealmTests.threadCPUSeconds()
            var state = GameState(settings: GameSettings(seedText: "calibration", houseCount: 6, radius: 22, keepers: 0))
            for _ in 0..<8 {
                for house in state.livingHouses { _ = state.stewardTurn(for: house.id) }
                _ = state.endWatch()
            }
            XCTAssertEqual(state.watch, 9)
            best = min(best, (RealmTests.threadCPUSeconds() - started) * 1000)
        }
        print("PERFMETRIC calibration.cpu \(String(format: "%.3f", best))")
    }
}
