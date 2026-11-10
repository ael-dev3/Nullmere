import Foundation
import XCTest
@testable import NullmereCore

/// Ferries of the Still: a keeper's company at a shore hold of theirs is
/// poled across the still water to another of their shore holds through the
/// watch, landing as it turns, or turned back when the landing is held.
final class FerryTests: XCTestCase {
    /// Two shore holds of one keeper, apart across the lake, a company at
    /// the first.
    private func world() throws -> (GameState, me: Int, from: Int, to: Int, company: Int) {
        var state = Scene.world("ferries", houses: 4, radius: 16)
        let me = state.player
        state.houses[me].stock = Stock(grain: 500, timber: 100, stone: 100, moonsalt: 10)
        let shores = state.map.hexes.filter { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && state.map.neighbors(of: hex).contains { [.still, .shallows].contains(state.map[$0]?.terrain) }
        }
        let first = try XCTUnwrap(shores.first)
        let second = try XCTUnwrap(shores.max { $0.distance(to: first) < $1.distance(to: first) })
        let from = Hold(id: state.takeID(), name: "Saltwatch", owner: me, position: first, isSeat: false, foundedWatch: 1)
        let to = Hold(id: state.takeID(), name: "Farmere", owner: me, position: second, isSeat: false, foundedWatch: 1)
        state.holds += [from, to]
        let company = state.put(.spear, tier: 1, of: me, at: first)
        return (state, me, from.id, to.id, company)
    }

    func testACompanyIsPoledAcrossTheLakeAndLandsAsTheWatchTurns() throws {
        var (state, me, from, to, company) = try world()
        XCTAssertEqual(state.ferryLandings(for: company, as: me).map(\.id), [to])
        let timber = state.houses[me].stock.timber
        let events = try state.perform(.ferry(unit: company, to: to), as: me)
        XCTAssertEqual(events, [.setOnTheWater(unit: company, house: me, from: from, to: to)])
        XCTAssertEqual(state.houses[me].stock.timber, timber - GameState.ferryCost.timber, "The ferrymen paid")
        let barge = try XCTUnwrap(state.crossing(of: company))
        XCTAssertEqual(barge.from, from)
        XCTAssertEqual(barge.to, to)
        XCTAssertTrue(state.unit(company)?.acted == true, "Aboard, it does nothing else this watch")
        XCTAssertEqual(state.ferryRefusal(company, to: to, as: me), .alreadyOnTheWater)
        XCTAssertEqual(state.crossingSaid(of: company), "On the water for Farmere; they land as the watch turns.", "As the Mac and the phone tell it")
        XCTAssertNil(state.crossingSaid(of: state.units(of: me).first { $0.id != company }?.id ?? -1), "Ashore")
        let turned = state.endWatch()
        XCTAssertTrue(turned.contains(.ferried(unit: company, house: me, to: to, landed: true)))
        XCTAssertEqual(state.unit(company)?.position, state.hold(to)?.position, "Landed across the lake")
        XCTAssertNil(state.crossing(of: company))
        XCTAssertNil(state.crossingSaid(of: company), "Landed")
        XCTAssertEqual(state.tidings(of: .ferried(unit: company, house: me, to: to, landed: true), for: me)?.tone, .good)
        XCTAssertEqual(state.problems(), [])
    }

    func testAHeldLandingTurnsTheBargeBack() throws {
        var (state, me, _, to, company) = try world()
        _ = try state.perform(.ferry(unit: company, to: to), as: me)
        let there = try XCTUnwrap(state.hold(to)).position
        let blocker = state.put(.bow, tier: 1, of: me, at: there)
        let start = state.unit(company)?.position
        let turned = state.endWatch()
        XCTAssertTrue(turned.contains(.ferried(unit: company, house: me, to: to, landed: false)))
        XCTAssertEqual(state.unit(company)?.position, start, "Back where it set out")
        XCTAssertEqual(state.unit(blocker)?.position, there)
    }

    func testABargeIsHadOnlyWhereItMay() throws {
        var (state, me, from, to, company) = try world()
        let other = (me + 1) % 4
        state.houses[other].isPlayer = true
        XCTAssertEqual(state.ferryRefusal(company, to: to, as: other), .notYours)
        XCTAssertEqual(state.ferryRefusal(company, to: from, as: me), .unknownHold, "Not to where it stands")
        var poor = state
        poor.houses[me].stock = Stock()
        XCTAssertNotNil(poor.ferryRefusal(company, to: to, as: me))
        var spent = state
        spent.units[try XCTUnwrap(spent.unitIndex(company))].acted = true
        XCTAssertEqual(spent.ferryRefusal(company, to: to, as: me), .alreadyActed)
        var away = state
        away.units[try XCTUnwrap(away.unitIndex(company))].position = try XCTUnwrap(state.map.neighbors(of: state.hold(from)!.position)
            .first { state.map[$0]?.terrain.isPassable == true && !(state.map[$0]?.terrain.isWater ?? true) && state.hold(at: $0) == nil })
        XCTAssertEqual(away.ferryRefusal(company, to: to, as: me), .notAtAShoreHold)
        XCTAssertNil(state.ferryRefusal(company, to: to, as: me))
    }
}
