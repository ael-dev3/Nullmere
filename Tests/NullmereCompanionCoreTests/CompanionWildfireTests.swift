import Foundation
import XCTest
@testable import NullmereCompanionCore
@testable import NullmereCore

/// Fire in the blackwood on the keeper's phone: the order to set it,
/// offered where the rules would take it, and the fire and its ash drawn on
/// the chart, under all else on their ground, named as the Mac names them.
final class CompanionWildfireTests: XCTestCase {
    func testThePhoneOffersTheFireAndChartsItAndItsAsh() throws {
        var state = GameState(settings: GameSettings(seedText: "fire on the phone", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let owners = state.territory()
        let sites = Set(state.sitesInLand.map(\.position))
        let at = try XCTUnwrap(state.map.hexes.filter { hex in
            state.isBlackwood(hex) && state.hold(at: hex) == nil && !sites.contains(hex) && state.unit(at: hex) == nil
                && (state.territoryOwner(of: hex, in: owners) ?? me) == me && hex.distance(to: seat) <= 4
                && hex.neighbors.filter(state.isBlackwood).count >= 3
        }.min { ($0.distance(to: seat), $0.q, $0.r) < ($1.distance(to: seat), $1.q, $1.r) })
        let unit = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: me, near: at))
        let index = try XCTUnwrap(state.unitIndex(unit.id))
        state.units[index].position = at
        state.units[index].movesLeft = state.movement(of: state.units[index])
        state.omen = nil

        let offer = Command.kindle(unit: unit.id)
        let ledger = CompanionLedger(world: state.view(for: me), player: me)
        let company = try XCTUnwrap(ledger.companies.first { $0.id == unit.id })
        XCTAssertTrue(company.orders.contains { $0.title == "Set the wood alight" && $0.command == offer }, "\(company.orders.map(\.title))")
        _ = try state.perform(offer, as: me)
        XCTAssertFalse(try XCTUnwrap(CompanionLedger(world: state.view(for: me), player: me).companies.first { $0.id == unit.id })
            .orders.contains { $0.command == offer }, "Not twice on burning ground")

        // On the keeper's chart, the fire first, named as the Mac's hover names it.
        let burning = CompanionChart(world: state.view(for: me), player: me)
        let fire = try XCTUnwrap(burning.marks.first { $0.hex == at && $0.thing == .fire })
        XCTAssertEqual(fire.name, "Blackwood ablaze, \(GameState.watches(Wildfire.burns)) more")
        XCTAssertEqual(fire.side, .own)
        XCTAssertEqual(burning.marks.firstIndex { $0.thing == .fire }, 0, "drawn under all else")
        // Burnt out, it is ash on the chart.
        state.units.removeAll { $0.id == unit.id }
        state.wildfires = [Wildfire(at: at, by: me, caught: state.watch - 4, out: state.watch - 1)]
        let chart = CompanionChart(world: state.view(for: me), player: me)
        let ash = try XCTUnwrap(chart.marks.first { $0.hex == at })
        XCTAssertEqual(ash.thing, .ash)
        XCTAssertEqual(ash.name, "Blackwood burnt, the wood back in \(GameState.watches(Wildfire.ash - 1))")
    }
}
