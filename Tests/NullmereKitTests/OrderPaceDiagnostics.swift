import Foundation
@testable import NullmereCore
import NullmereRealm
import XCTest
@testable import NullmereKit

/// Diagnostics, held to no baseline and scored by nothing: the client pace
/// test's orders made again, on a session of their own, with a fixed piece
/// of the rules' own work timed by this thread's CPU just before and just
/// after them, to say how fast the machine was then. The figure CI holds is
/// ClientPaceTests' `order.cpu.p50`, which this neither prints nor touches;
/// and this runs after it, as test classes run in the order of their names.
@MainActor
final class OrderPaceDiagnostics: XCTestCase {
    func testTheOrdersBesideAFixedPieceOfWork() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        // The client pace test's lake and orders, made the same way.
        var realm = RealmState(name: "The Nullmere", seed: "client pace", now: 0)
        try realm.arrive("a", name: "Ama", now: 0)
        for _ in 0..<40 {
            for house in realm.world.houses where !house.isEliminated { _ = realm.world.stewardTurn(for: house.id) }
            _ = realm.world.endWatch()
        }
        let house = try XCTUnwrap(realm.keeper("a")?.house)
        let session = GameSession(link: SilentLink(), house: house, world: realm.world.view(for: house), store: LocalStore(directory: dir))
        var orders: [Command] = []
        for unit in session.state.units(of: session.player) where unit.movesLeft > 0 {
            let open = session.state.map.neighbors(of: unit.position).first { hex in
                guard let tile = session.state.map[hex], tile.terrain.isSettleable else { return false }
                return !session.state.units.contains { $0.position == hex } && session.state.hold(at: hex) == nil
            }
            if let open { orders.append(.move(unit: unit.id, to: open)) }
        }

        // One watch of the stewards' turns on a small, fixed lake, three times.
        let reference = GameState(settings: GameSettings(seedText: "order reference", houseCount: 4, radius: 14, keepers: 0))
        func referenceWork() -> [Double] {
            (0..<3).map { _ in
                var state = reference
                let start = ThreadClock.milliseconds()
                for house in state.livingHouses { _ = state.stewardTurn(for: house.id) }
                _ = state.endWatch()
                return ThreadClock.milliseconds() - start
            }
        }
        let before = referenceWork()
        var times: [Double] = []
        for order in orders.prefix(12) {
            let start = ThreadClock.milliseconds()
            _ = session.perform(order)
            times.append(ThreadClock.milliseconds() - start)
        }
        let after = referenceWork()

        func list(_ values: [Double]) -> String { values.map { String(format: "%.2f", $0) }.joined(separator: " ") }
        print("PERF diagnostic, held to no baseline: a fixed piece of work and the orders, thread CPU ms: "
              + "before \(list(before)); orders \(list(times)); after \(list(after))")
        XCTAssertFalse(times.isEmpty, "Companies to order")
    }
}

/// The realm across the network: it answers, but not here.
@MainActor
private final class SilentLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
