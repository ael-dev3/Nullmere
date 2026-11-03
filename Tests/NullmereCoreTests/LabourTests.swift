import XCTest
@testable import NullmereCore

/// The watch's labours: three of five set each watch for a keeper's House,
/// counted as it does them, vigour for each done, chests at its marks.
final class LabourTests: XCTestCase {
    func testThreeOfFiveLaboursAWatchTheSameForTheSameWatch() {
        for house in 0..<6 {
            for watch in 0..<40 {
                let kinds = GameState.labourKinds(for: house, at: watch)
                XCTAssertEqual(kinds.count, 3)
                XCTAssertEqual(Set(kinds).count, 3)
                XCTAssertEqual(kinds, GameState.labourKinds(for: house, at: watch))
            }
        }
        let kinds = Set((0..<40).flatMap { GameState.labourKinds(for: 0, at: $0) })
        XCTAssertEqual(kinds, Set(LabourKind.allCases), "Every labour comes round")
    }

    func testLaboursAreCountedRewardedAndOpenChests() throws {
        var state = Scene.world("labours", houses: 4)
        let me = state.player
        XCTAssertNil(state.labours(of: me))
        _ = state.turnLabours()
        let set = try XCTUnwrap(state.labours(of: me))
        XCTAssertEqual(set.tasks.count, 3)
        XCTAssertNil(state.labours(of: 1), "A steward's House has none")
        XCTAssertNil(state.view(for: 1).labours(of: me), "Its House's own")
        // A labour done, counted as it is done, rewarded as the watch turns.
        let kind = set.tasks[0].kind
        state.labourBook![me]!.tasks[0].done = kind.measure
        state.labourBook![me]!.vigour = Labours.chests[0] - Labours.vigourPerLabour
        let before = state.houses[me].stock
        let events = state.turnLabours()
        XCTAssertTrue(events.contains(.labourDone(house: me, kind: kind)))
        XCTAssertTrue(events.contains(.chestOpened(house: me, chest: 1)), "\(events)")
        XCTAssertGreaterThan(state.houses[me].stock.grain + state.houses[me].stock.timber, before.grain + before.timber)
        XCTAssertNotNil(state.tidings(of: .chestOpened(house: me, chest: 1), for: me))
        XCTAssertNil(state.tidings(of: .chestOpened(house: me, chest: 1), for: 1))
        XCTAssertEqual(state.events(events, heardBy: 1).filter { if case .labourDone = $0 { return true } else { return false } }, [])
        let next = try XCTUnwrap(state.labours(of: me))
        XCTAssertEqual(next.opened, 1)
        XCTAssertTrue(next.tasks.allSatisfy { $0.done == 0 }, "A new watch's labours, begun")
    }

    func testWhatAHouseDoesCountsTowardItsLabour() throws {
        var state = Scene.world("labours counted", houses: 4)
        let me = state.player
        state.labourBook = [me: Labours(watch: state.watch, tasks: [Labour(kind: .gather, done: 0), Labour(kind: .raise, done: 0)], vigour: 0, opened: 0)]
        let hold = try XCTUnwrap(state.holds(of: me).first).id
        state.countLabours([.delivered(unit: 0, owner: me, hold: hold, load: Stock(grain: 100, timber: 60)),
                            .delivered(unit: 0, owner: 1, hold: hold, load: Stock(grain: 500)),
                            .buildingCompleted(hold: hold, kind: .granary, level: 2)])
        XCTAssertEqual(state.labours(of: me)?.tasks[0].done, 160, "Its own deliveries, not another's")
        XCTAssertEqual(state.labours(of: me)?.tasks[1].isDone, true)
        XCTAssertEqual(state.problems(), [])
    }
}
