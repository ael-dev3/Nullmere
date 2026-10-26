import Foundation
import NullmereCore
import XCTest
@testable import NullmereKit

/// The client redraws its copy of the world after every order the keeper
/// gives: on the realm's full lake, deep into an age, that must take less
/// than a frame.
@MainActor
final class ClientPaceTests: XCTestCase {
    func testAnOrderOnAFullLakeTakesLessThanAFrame() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var realm = RealmState(name: "The Nullmere", seed: "client pace", now: 0)
        try realm.arrive("a", name: "Ama", now: 0)
        for _ in 0..<80 {
            for house in realm.world.houses where !house.isEliminated { _ = realm.world.stewardTurn(for: house.id) }
            _ = realm.world.endWatch()
        }
        let session = GameSession(state: realm.world, store: LocalStore(directory: dir))
        let units = session.state.units(of: session.player).filter { !$0.fortified && $0.kind.isMilitary }
        var times: [Double] = []
        for unit in units.prefix(12) {
            let start = Date()
            _ = session.perform(.fortify(unit: unit.id))
            times.append(Date().timeIntervalSince(start) * 1000)
        }
        let sorted = times.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        print("PERF an order on a lake of \(session.state.houses.count) Houses at watch \(session.state.watch), \(session.state.units.count) companies: median \(String(format: "%.1f", median)) ms over \(times.count)")
        XCTAssertFalse(times.isEmpty, "Companies to order")
        XCTAssertLessThan(median, 16, "Less than a frame")
    }
}
