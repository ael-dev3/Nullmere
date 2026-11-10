import Foundation
import XCTest
@testable import NullmereCompanionCore
@testable import NullmereCore

/// The search on the phone's chart, as the Mac's Seek on the land: among
/// what the House has seen on the chart, the nearest its seat first; the
/// same kind sought again, the next, round again; another kind afresh; none
/// seen said so; sought afresh from the world as it stands each time.
final class ChartSeekingTests: XCTestCase {
    func testTheNearestOnTheChartIsSoughtThenTheNextRoundAgain() throws {
        var world = GameState(settings: GameSettings(seedText: "seeking on the phone", houseCount: 4, radius: 16, keepers: 1))
        let me = world.player
        let seat = try XCTUnwrap(world.seat(of: me)).position
        world.reveal(around: seat, range: 6, for: me)
        world.wilds = []
        world.sites = []
        // Both in sight, for the phone holds the keeper's view, and a view
        // holds only the wilds in sight.
        let sight = world.visibility(for: me)
        func ground(_ distance: Int) -> Hex? {
            world.map.hexes.first { hex in
                hex.distance(to: seat) == distance && world.hold(at: hex) == nil && world.map.index(of: hex).map { sight[$0] } == true
            }
        }
        let near = try XCTUnwrap(ground(1))
        let far = try XCTUnwrap((2...4).reversed().lazy.compactMap { ground($0) }.first)
        world.wilds = [Wild(id: 1, kind: .reavers, level: 4, position: far, raised: 1),
                       Wild(id: 2, kind: .saltwights, level: 2, position: near, raised: 1)]
        var view = world.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        XCTAssertEqual(chart.center, seat)
        XCTAssertTrue(chart.contains(near) && chart.contains(far))

        var seeking = ChartSeeking()
        XCTAssertNil(seeking.line(on: chart), "nothing said before a search")
        XCTAssertEqual(seeking.seek(.wilds, on: chart, in: view, player: me), near, "the nearest the seat first")
        XCTAssertEqual(seeking.line(on: chart), "Saltwights, level II, \(GameState.waySaid(to: near, from: seat)) of your seat; 1 of 2 seen")
        XCTAssertEqual(seeking.seek(.wilds, on: chart, in: view, player: me), far, "sought again, the next")
        XCTAssertEqual(seeking.line(on: chart), "Blackwood Reavers, level IV, \(GameState.waySaid(to: far, from: seat)) of your seat; 2 of 2 seen")
        XCTAssertEqual(seeking.seek(.wilds, on: chart, in: view, player: me), near, "round to the nearest again")

        // Another kind afresh, and none seen said so.
        XCTAssertNil(seeking.seek(.timber, on: chart, in: view, player: me))
        XCTAssertEqual(seeking.line(on: chart), Seeking.timber.noneSeen)
        XCTAssertEqual(seeking.seek(.wilds, on: chart, in: view, player: me), near, "back to the wilds, the nearest again")

        // Sought afresh each time: the nearest struck down, the next finds what is left.
        view.wilds = view.wilds?.filter { $0.position != near }
        XCTAssertEqual(seeking.seek(.wilds, on: chart, in: view, player: me), far)
        XCTAssertEqual(seeking.line(on: chart)?.hasSuffix("; the only one seen"), true, seeking.line(on: chart) ?? "")
    }

    func testEachKindIsFoundByItsOwnMarks() {
        XCTAssertEqual(ChartSeeking.things(of: .wilds), [.wild])
        XCTAssertEqual(ChartSeeking.things(of: .moonsalt), [.site])
        XCTAssertEqual(ChartSeeking.things(of: .lairs), [.lair])
        XCTAssertEqual(ChartSeeking.things(of: .shrines), [.shrine])
        XCTAssertEqual(ChartSeeking.things(of: .finds), [.hamlet, .barrow])
    }
}
