@testable import NullmereCore
import XCTest
@testable import NullmereKit

@MainActor
final class AttentionTests: XCTestCase {
    func testTheDockCountsWatchesAndCallsOnce() {
        var attention = Attention()
        XCTAssertNil(attention.watchTurned(isActive: true, needsKeeper: true), "Looking: nothing to say")
        XCTAssertEqual(attention.watchTurned(isActive: false, needsKeeper: false), .init(badge: "1", bounce: false))
        XCTAssertEqual(attention.watchTurned(isActive: false, needsKeeper: true), .init(badge: "2", bounce: true))
        XCTAssertEqual(attention.watchTurned(isActive: false, needsKeeper: true), .init(badge: "3", bounce: false), "One call an absence")
        XCTAssertEqual(attention.returned(), .init(badge: nil, bounce: false))
        XCTAssertNil(attention.returned(), "Nothing left to clear")
        XCTAssertEqual(attention.watchTurned(isActive: false, needsKeeper: true), .init(badge: "1", bounce: true), "A new absence calls again")
        for _ in 0..<120 { _ = attention.watchTurned(isActive: false, needsKeeper: false) }
        XCTAssertEqual(attention.watchTurned(isActive: false, needsKeeper: false)?.badge, "99+")
    }

    func testASessionTellsTheDockWhenTheWatchTurnsUnseen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "elsewhere", houseCount: 3, radius: 16, keepers: 1)),
                                  store: LocalStore(directory: dir))
        var looking = false
        var signals: [Attention.Signal] = []
        session.isLooking = { looking }
        session.signal = { signals.append($0) }
        // A company that walks its watch out: when the watch turns it waits
        // anew.
        let unit = try XCTUnwrap(session.state.units(of: session.player).first { $0.movesLeft > 0 })
        while let here = session.state.unit(unit.id), here.movesLeft > 0 {
            let step = try XCTUnwrap(session.state.map.neighbors(of: here.position).first { hex in
                (session.state.map[hex]?.terrain.moveCost ?? 99) <= here.movesLeft
                    && session.state.unit(at: hex) == nil && session.state.hold(at: hex) == nil
            }, "Room to walk")
            XCTAssertTrue(session.perform(.move(unit: unit.id, to: step)))
        }
        session.endWatch()
        XCTAssertEqual(signals.first?.badge, "1", "The watch turned while the keeper was elsewhere")
        XCTAssertEqual(signals.first?.bounce, true, "A fresh watch has orders to give")
        looking = true
        session.keeperReturned()
        XCTAssertEqual(signals.last, .init(badge: nil, bounce: false))
        let count = signals.count
        session.endWatch()
        XCTAssertEqual(signals.count, count, "Seen: the Dock stays quiet")
    }

    /// What the keeper left as it was when they made ready is no call; what
    /// waits anew is: a company at the end of its march, a hold that can now
    /// pay for work it couldn't.
    func testOnlyWhatWaitsAnewCallsTheKeeper() throws {
        let state = GameState(settings: GameSettings(seedText: "left waiting", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player
        XCTAssertTrue(state.units(of: me).contains { $0.movesLeft > 0 }, "Companies left waiting")
        XCTAssertTrue(state.holds(of: me).contains { $0.project == nil && GameSession.couldBuild($0, in: state) }, "A hold left idle")
        XCTAssertFalse(GameSession.needsPlayer(after: [], from: state, to: state, player: me, threatened: []), "Nothing new")

        var marched = state
        let index = try XCTUnwrap(marched.units.firstIndex { $0.owner == me })
        marched.units[index].movesLeft = 0
        XCTAssertTrue(GameSession.needsPlayer(after: [], from: marched, to: state, player: me, threatened: []), "Its march done, it waits")

        var poor = state
        poor.houses[me].stock = Stock()
        XCTAssertTrue(GameSession.needsPlayer(after: [], from: poor, to: state, player: me, threatened: []), "Work it can now pay for")
    }
}
