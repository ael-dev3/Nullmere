import NullmereCore
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
}
