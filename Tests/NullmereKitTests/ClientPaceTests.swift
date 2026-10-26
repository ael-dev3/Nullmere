import Foundation
@testable import NullmereCore
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
        for _ in 0..<40 {
            for house in realm.world.houses where !house.isEliminated { _ = realm.world.stewardTurn(for: house.id) }
            _ = realm.world.endWatch()
        }
        let session = GameSession(state: realm.world, store: LocalStore(directory: dir))
        XCTAssertNil(session.state.outcome, "The age goes on")
        // A step to free open ground beside each company that can move.
        var orders: [Command] = []
        for unit in session.state.units(of: session.player) where unit.movesLeft > 0 {
            let open = session.state.map.neighbors(of: unit.position).first { hex in
                guard let tile = session.state.map[hex], tile.terrain.isSettleable else { return false }
                return !session.state.units.contains { $0.position == hex } && session.state.hold(at: hex) == nil
            }
            if let open { orders.append(.move(unit: unit.id, to: open)) }
        }
        var times: [Double] = []
        for order in orders.prefix(12) {
            let start = Date()
            _ = session.perform(order)
            times.append(Date().timeIntervalSince(start) * 1000)
        }
        // Where the time goes, for whoever makes it faster.
        func measure(_ name: String, _ body: () -> Void) -> String {
            let start = Date()
            for _ in 0..<10 { body() }
            return "\(name) \(String(format: "%.1f", Date().timeIntervalSince(start) * 100)) ms"
        }
        let state = session.state, player = session.player
        let unit = state.units(of: player).first { $0.kind.isMilitary }
        print("PERF parts of a refresh: " + [
            measure("sight") { _ = state.visibility(for: player) },
            measure("territory") { _ = state.territory() },
            measure("threats") { _ = Sentinel.threats(in: state, player: player, visible: state.visibility(for: player)) },
            measure("tiles") { _ = TileTexture.bytes(for: state, viewer: player) },
            measure("reach") { if let unit { _ = state.reach(of: unit) } },
            measure("strikes") { if let unit { _ = state.strikeTargets(of: unit) } },
            measure("view") { _ = state.view(for: player) },
            measure("compare") { _ = state == state.view(for: player) },
        ].joined(separator: ", "))
        let sorted = times.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        print("PERF an order on a lake of \(session.state.houses.count) Houses at watch \(session.state.watch), \(session.state.units.count) companies: median \(String(format: "%.1f", median)) ms over \(times.count)")
        XCTAssertFalse(times.isEmpty, "Companies to order")
        XCTAssertLessThan(median, 16, "Less than a frame")
    }
}
