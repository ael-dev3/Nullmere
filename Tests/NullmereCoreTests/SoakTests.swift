import Foundation
import XCTest
@testable import NullmereCore

/// A full lake of each shape, played by its stewards for many watches: the
/// world must stay sound throughout, and come back whole from its words.
final class SoakTests: XCTestCase {
    func testEveryLakeStaysSoundThroughALongAge() throws {
        // Sixty watches each by default; CI's realm job plays a long age.
        let watches = ProcessInfo.processInfo.environment["NULLMERE_SOAK_WATCHES"].flatMap(Int.init) ?? 60
        let started = Date()
        for lake in Lake.allCases {
            var world = GameState(settings: GameSettings(seedText: "soak \(lake.rawValue)", houseCount: 12, radius: 36, keepers: 0, lake: lake))
            XCTAssertEqual(world.problems(), [], "\(lake) at the start")
            for watch in 1...watches where world.outcome == nil {
                _ = world.endWatch()
                if watch % 10 == 0 {
                    let problems = world.problems()
                    XCTAssertEqual(problems, [], "\(lake) at watch \(world.watch)")
                    if !problems.isEmpty { break }
                }
                if watch % 30 == 0 {
                    let back = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(world))
                    XCTAssertEqual(back, world, "\(lake) comes back whole at watch \(world.watch)")
                }
            }
            print("PERF soak of \(lake): watch \(world.watch), \(world.livingHouses.count) Houses standing, \(world.holds.count) holds")
        }
        let took = Date().timeIntervalSince(started)
        print("PERF soak of every lake in \(String(format: "%.1f", took)) s")
        // A second a watch on each lake is several times what it takes on a
        // busy runner: a rule that grew slow beyond reason fails here, and
        // doesn't run out CI's clock instead.
        XCTAssertLessThan(took, Double(watches * Lake.allCases.count), "The soak ran past its time")
    }

    func testAnUnsoundWorldIsCaught() {
        var world = GameState(settings: GameSettings(seedText: "unsound", houseCount: 3, radius: 16, keepers: 1))
        world.units[0].health = 0
        world.houses[1].stock.grain = -5
        let problems = world.problems()
        XCTAssertTrue(problems.contains { $0.contains("0 health") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("-5") }, "\(problems)")
    }
}
