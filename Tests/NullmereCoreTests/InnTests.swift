import XCTest
@testable import NullmereCore

/// The Lantern Inn: keys each watch, chests drawn by the realm, a commander
/// surely by the tenth gold chest.
final class InnTests: XCTestCase {
    func testKeysComeWithTheWatchAndAreKeptToFive() {
        var state = Scene.world("inn keys", houses: 4)
        let me = state.player
        XCTAssertEqual(state.innRefusal(.silver, as: me), .noInnKey(.silver))
        for _ in 0..<(InnKeys.goldEvery * 2) {
            state.turnInn()
            state.watch += 1
        }
        XCTAssertEqual(state.innKeys(of: me).silver, InnKeys.mostKeys, "No more than five kept")
        XCTAssertEqual(state.innKeys(of: me).gold, 2, "One every \(InnKeys.goldEvery) watches")
        XCTAssertEqual(state.innKeys(of: 1).silver, 0, "A steward's House goes to no inn")
        XCTAssertNil(state.view(for: 1).innBook?[me], "A House's keys are its own")
        XCTAssertEqual(state.view(for: me).innKeys(of: me), state.innKeys(of: me))
    }

    func testAChestIsOpenedWithAKeyAndItsDrawIsTheRealms() throws {
        var state = Scene.world("inn chests", houses: 4)
        let me = state.player
        state.turnInn()
        var twin = state
        let before = state.sculptures(of: me) + (state.satchel ?? []).filter { $0.house == me }.map(\.count).reduce(0, +)
        let events = try state.perform(.openInnChest(.silver), as: me)
        guard case .innChestOpened(me, .silver, let draw) = events.first else { return XCTFail("\(events)") }
        XCTAssertEqual(state.innKeys(of: me).silver, 0)
        let after = state.sculptures(of: me) + (state.satchel ?? []).filter { $0.house == me }.map(\.count).reduce(0, +)
        XCTAssertGreaterThan(after, before, "\(draw) is the House's")
        XCTAssertNotNil(state.tidings(of: events[0], for: me))
        XCTAssertNil(state.tidings(of: events[0], for: 1))
        XCTAssertTrue(state.events(events, heardBy: 1).filter { if case .innChestOpened = $0 { return true } else { return false } }.isEmpty)
        // The same realm draws the same.
        let again = try twin.perform(.openInnChest(.silver), as: me)
        XCTAssertEqual(again.first, events.first)
        XCTAssertThrowsError(try state.perform(.openInnChest(.silver), as: me)) { XCTAssertEqual($0 as? RuleError, .noInnKey(.silver)) }
    }

    func testAGoldChestForMoonsaltAndACommanderSurelyByTheTenth() throws {
        var state = Scene.world("inn gold", houses: 4)
        let me = state.player
        state.houses[me].stock = Stock(moonsalt: 0)
        XCTAssertEqual(state.innRefusal(.gold, as: me), .shortOf(Stock(moonsalt: 25)))
        state.houses[me].stock = Stock(moonsalt: 25 * InnKeys.surelyBy)
        let roster = state.commanders(of: me).count
        var commanders = 0
        for _ in 0..<InnKeys.surelyBy {
            let events = try state.perform(.openInnChest(.gold), as: me)
            if case .innChestOpened(_, .gold, .commander(let id)) = events.first {
                commanders += 1
                XCTAssertEqual(state.commander(id)?.owner, me)
                XCTAssertTrue(events.contains(.commanderJoined(commander: id, house: me)))
            }
        }
        XCTAssertEqual(state.houses[me].stock.moonsalt, 0, "Each paid for")
        XCTAssertGreaterThanOrEqual(commanders, 1, "Surely one by the tenth")
        XCTAssertEqual(state.commanders(of: me).count, roster + commanders)
    }
}
