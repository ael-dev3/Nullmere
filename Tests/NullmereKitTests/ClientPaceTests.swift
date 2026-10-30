import Foundation
@testable import NullmereCore
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereKit
import NullmereTestSupport
import NullmereWorld

/// The client carries out every order on its own copy of the world at once
/// and redraws it; the realm's answer comes later, across the network. On
/// the realm's full lake, deep into an age, the order must take less than
/// a frame, even in a debug build.
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
        let house = try XCTUnwrap(realm.keeper("a")?.house)
        let session = GameSession(link: QuietLink(), house: house, world: realm.world.view(for: house), store: LocalStore(directory: dir))
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
        // Each order is reported as measured, with the clock on the wall
        // beside it, read outside the thread's CPU time: diagnostics only.
        var walls: [Double] = []
        for order in orders.prefix(12) {
            let wall = Date()
            let start = ThreadClock.milliseconds()
            _ = session.perform(order)
            times.append(ThreadClock.milliseconds() - start)
            walls.append(Date().timeIntervalSince(wall) * 1000)
        }
        // Where the time goes, for whoever makes it faster.
        func measure(_ name: String, _ body: () -> Void) -> String {
            let start = Date()
            for _ in 0..<10 { body() }
            return "\(name) \(String(format: "%.1f", Date().timeIntervalSince(start) * 100)) ms"
        }
        let state = session.state, player = session.player
        let ground = TileTexture.Ground(map: state.map)
        // The same texture, whether its ground is kept or made afresh.
        XCTAssertEqual(TileTexture.bytes(for: state, viewer: player, ground: ground), TileTexture.bytes(for: state, viewer: player))
        let elsewhere = GameState(settings: GameSettings(seedText: "another map", houseCount: 12, radius: 36, keepers: 1))
        XCTAssertEqual(TileTexture.bytes(for: state, viewer: player, ground: TileTexture.Ground(map: elsewhere.map)),
                       TileTexture.bytes(for: state, viewer: player), "Ground for another map is made again")
        let unit = state.units(of: player).first { $0.kind.isMilitary }
        print("PERF parts of a refresh: " + [
            measure("sight") { _ = state.visibility(for: player) },
            measure("territory") { _ = state.territory() },
            measure("threats") { _ = Sentinel.threats(in: state, player: player, visible: state.visibility(for: player)) },
            measure("tiles") { _ = TileTexture.bytes(for: state, viewer: player) },
            measure("tiles on known ground") {
                _ = TileTexture.bytes(for: state, viewer: player, visible: state.visibility(for: player), owners: state.territory(), ground: ground)
            },
            measure("reach") { if let unit { _ = state.reach(of: unit) } },
            measure("strikes") { if let unit { _ = state.strikeTargets(of: unit) } },
            measure("view") { _ = state.view(for: player) },
            measure("compare") { _ = state == state.view(for: player) },
        ].joined(separator: ", "))
        let sorted = times.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        print("PERFMETRIC order.cpu.p50 \(String(format: "%.3f", median))")
        print("PERF an order on a lake of \(session.state.houses.count) Houses at watch \(session.state.watch), \(session.state.units.count) companies: median \(String(format: "%.1f", median)) ms over \(times.count)")
        func list(_ values: [Double]) -> String { values.map { String(format: "%.2f", $0) }.joined(separator: " ") }
        print("PERF order samples as taken, thread CPU ms: \(list(times)); wall ms: \(list(walls))")
        XCTAssertFalse(times.isEmpty, "Companies to order")
        XCTAssertLessThan(median, 16, "Less than a frame")
    }
}

/// The realm across the network: it answers, but not within the frame.
@MainActor
private final class QuietLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}

@MainActor
final class IncomeBreakdownTests: XCTestCase {
    func testEachResourceSaysWhereItComesFrom() throws {
        var state = GameState(settings: GameSettings(seedText: "where it comes from", houseCount: 3, radius: 16, keepers: 1))
        for _ in 0..<20 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        let player = state.player
        let income = state.income(of: player)
        for resource in Resource.allCases {
            let breakdown = IncomeBreakdown(state: state, house: player, resource: resource)
            let expected = income[resource] - (resource == .grain ? state.upkeep(of: player) : 0)
            XCTAssertEqual(breakdown.net, expected, "\(resource): the lines add up to what the top bar shows")
            XCTAssertTrue(breakdown.summary.hasPrefix("\(resource.title): \(state.houses[player].stock[resource]) of "))
        }
        let grain = IncomeBreakdown(state: state, house: player, resource: .grain)
        let seat = try XCTUnwrap(state.seat(of: player))
        XCTAssertEqual(grain.lines.first?.label, seat.name, "The seat first")
        XCTAssertEqual(grain.lines.last?.label, "Companies eat")
        state.omen = nil
        XCTAssertNil(IncomeBreakdown(state: state, house: player, resource: .grain).omen, "No omen, nothing said of one")
        state.omen = Omen(kind: .leanWatch, began: state.watch, ends: state.watch + 3)
        XCTAssertEqual(IncomeBreakdown(state: state, house: player, resource: .grain).omen, "A Lean Watch takes a third of it.")
        XCTAssertNil(IncomeBreakdown(state: state, house: player, resource: .timber).omen)

        // The card the top bar opens, with its omen, and with nothing coming in.
        try Self.draw(IncomeCard(breakdown: IncomeBreakdown(state: state, house: player, resource: .grain)))
        var bare = state
        bare.holds.removeAll { $0.owner == player }
        bare.units.removeAll { $0.owner == player }
        let nothing = IncomeBreakdown(state: bare, house: player, resource: .moonsalt)
        XCTAssertTrue(nothing.lines.isEmpty)
        try Self.draw(IncomeCard(breakdown: nothing))
    }

    @MainActor
    static func draw(_ view: some View) throws {
        let renderer = ImageRenderer(content: view.frame(width: 320, height: 300).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
    }
}
