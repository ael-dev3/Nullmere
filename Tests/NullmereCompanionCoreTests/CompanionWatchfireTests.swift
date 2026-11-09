import Foundation
import XCTest
@testable import NullmereCompanionCore
@testable import NullmereCore

/// Watchfires on the keeper's phone: lighting one offered on open ground of
/// the House's own land, as the Mac's ground panel offers it, and every
/// watchfire charted, named as the Mac names it.
final class CompanionWatchfireTests: XCTestCase {
    func testThePhoneLightsAWatchfireAndChartsIt() throws {
        var state = GameState(settings: GameSettings(seedText: "watchfire on the phone", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock.timber = 100
        let owners = state.territory()
        let at = try XCTUnwrap(state.map.hexes.first { hex in
            guard let terrain = state.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && state.hold(at: hex) == nil && state.territoryOwner(of: hex, in: owners) == me
        })
        let offered = CompanionChart.raisings(at: at, in: state.view(for: me), player: me)
        let order = try XCTUnwrap(offered.flatMap(\.orders).first { $0.command == .watchfire(at) }, "\(offered.flatMap(\.orders).map(\.title))")
        XCTAssertEqual(order.title, "Light a watchfire, for \(Watchfire.cost)")
        XCTAssertTrue(offered.contains { $0.said == Watchfire.explained })
        XCTAssertFalse(CompanionChart.raisings(at: try XCTUnwrap(state.seat(of: me)).position, in: state.view(for: me), player: me)
            .flatMap(\.orders).contains { if case .watchfire = $0.command { return true } else { return false } }, "Never in a hold")
        _ = try state.perform(order.command, as: me)
        XCTAssertFalse(CompanionChart.raisings(at: at, in: state.view(for: me), player: me).flatMap(\.orders).contains { $0.command == .watchfire(at) },
                       "Burning there already")
        let chart = CompanionChart(world: state.view(for: me), player: me)
        let mark = try XCTUnwrap(chart.marks.first { $0.hex == at && $0.thing == .watchfire })
        XCTAssertEqual(mark.side, .own)
        XCTAssertEqual(mark.name, "Your watchfire, \(GameState.watches(Watchfire.burns)) more")
        // Another House's phone charts it too, as that House's.
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        let theirs = CompanionChart(world: state.view(for: other), player: other)
        if theirs.contains(at) {
            XCTAssertEqual(theirs.marks.first { $0.thing == .watchfire }?.name, "\(state.houses[me].title)'s watchfire, \(GameState.watches(Watchfire.burns)) more")
        }
    }

    /// Where the phone's check on CI lights its watchfire: with the stores a
    /// keeper comes into the realm with, the chart offers one in the place
    /// the keeper taps on each tile of open ground of the House's own land
    /// two or three tiles from its seat, and there are such tiles, in realms
    /// of every seed tried.
    func testAKeeperComingInIsOfferedAWatchfireNearTheSeat() throws {
        for seed in ["watchfire near the seat", "smoke test", "the far shore", "cold water"] {
            var realm = RealmState(name: "The Nullmere", seed: seed, seats: 6, radius: 18, watchLength: 600, now: 0)
            _ = try realm.arrive("id-ama", name: "Ama", now: 1)
            let me = try XCTUnwrap(realm.world.houses.first { $0.isPlayer }).id
            XCTAssertGreaterThanOrEqual(realm.world.houses[me].stock.timber, Watchfire.cost.timber, seed)
            let view = realm.world.view(for: me)
            let chart = CompanionChart(world: view, player: me)
            let open = chart.cells.filter { cell in
                let distance = cell.hex.distance(to: chart.center)
                return cell.explored && cell.land == .own && cell.terrain.isPassable && !cell.terrain.isWater
                    && distance >= 2 && distance <= 3 && !chart.marks.contains { $0.hex == cell.hex }
            }
            XCTAssertFalse(open.isEmpty, seed)
            for cell in open {
                let orders = chart.place(at: cell.hex, in: view, player: me).raisings.flatMap(\.orders)
                XCTAssertTrue(orders.contains { $0.command == .watchfire(cell.hex) }, "\(seed): \(cell.hex) \(orders.map(\.title))")
            }
        }
    }
}
