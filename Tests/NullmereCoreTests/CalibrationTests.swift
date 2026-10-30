import Foundation
import XCTest
@testable import NullmereCore

/// How fast this machine runs today: a fixed piece of plain work, none of
/// it the game's, timed by this thread's CPU. scripts/perf-check.py scales
/// the CPU figures' allowances by it, so a slower shared runner doesn't
/// fail the build; and since none of the game's code is in it, the game's
/// code growing slower can't raise its own allowance and pass.
final class CalibrationTests: XCTestCase {
    func testTheMachinesPace() {
        var best = Double.infinity
        // The best of three: the machine at its steadiest.
        for _ in 0..<3 {
            let started = RealmTests.threadCPUSeconds()
            var folded = 0
            for round in 0..<6 {
                folded ^= Self.plainWork(seed: UInt64(round))
            }
            XCTAssertNotEqual(folded, 0)
            best = min(best, (RealmTests.threadCPUSeconds() - started) * 1000)
        }
        print("PERFMETRIC calibration.cpu \(String(format: "%.3f", best))")

        // The game's own work beside it, told and never held: how the two
        // compare on this machine, for whoever sets the baselines.
        let started = RealmTests.threadCPUSeconds()
        var state = GameState(settings: GameSettings(seedText: "calibration", houseCount: 6, radius: 22, keepers: 0))
        for _ in 0..<8 {
            for house in state.livingHouses { _ = state.stewardTurn(for: house.id) }
            _ = state.endWatch()
        }
        XCTAssertEqual(state.watch, 9)
        print("PERF calibration beside the game's own work: plain \(String(format: "%.1f", best)) ms, "
              + "eight watches of six stewards \(String(format: "%.1f", (RealmTests.threadCPUSeconds() - started) * 1000)) ms")
    }

    /// Numbers drawn, sorted, counted into a dictionary and folded together:
    /// work of the kind the rules do, in plain code that never changes.
    static func plainWork(seed: UInt64) -> Int {
        var state = 0x9E37_79B9_7F4A_7C15 &+ seed
        var numbers: [Int] = []
        numbers.reserveCapacity(40_000)
        for _ in 0..<40_000 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            numbers.append(Int(truncatingIfNeeded: state >> 33) % 10_000)
        }
        numbers.sort()
        var counts: [Int: Int] = [:]
        for number in numbers { counts[number, default: 0] += 1 }
        var fold = 0.0
        for (key, count) in counts.sorted(by: { $0.key < $1.key }) {
            fold += sin(Double(key)) * Double(count)
        }
        return Int(fold * 1_000) ^ counts.count
    }
}
