import Foundation
import XCTest
@testable import NullmereCore

/// A company across the lake by barge from the order book and from counsel:
/// FERRY <company> TO <hold> read into the order the realm would take, or
/// told why not; the briefing and a commander's look at the company telling
/// where it may land and for what, or where it is bound on the water; and a
/// commander putting a crossing forward the same way.
final class FerryOrdersTests: XCTestCase {
    /// Two shore holds of the keeper's, apart across the lake, a company of
    /// war at the first with a commander at its head.
    private func world() throws -> (state: GameState, me: Int, from: Hold, to: Hold, company: NullmereCore.Unit) {
        var state = GameState(settings: GameSettings(seedText: "ferried by word", houseCount: 4, radius: 16, keepers: 1))
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
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: first))
        state.units[try XCTUnwrap(state.unitIndex(spear.id))].position = first
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        _ = try state.perform(.assign(commander: commander.id, unit: spear.id), as: me)
        return (state, me, from, to, try XCTUnwrap(state.unit(spear.id)))
    }

    /// The company's handle in the order book: C and its place among the House's companies.
    private func handle(of unit: NullmereCore.Unit, in state: GameState, player: Int) throws -> String {
        "C\(try XCTUnwrap(SpokenOrders.companies(in: state, player: player).firstIndex { $0.id == unit.id }) + 1)"
    }

    func testAFerryIsReadFromTheOrderBook() throws {
        var (state, me, _, to, company) = try world()
        let c = try handle(of: company, in: state, player: me)
        XCTAssertTrue(SpokenOrders.forms.contains("FERRY <company> TO <hold>"))
        let read = try XCTUnwrap(SpokenOrders.read("ferry \(c) to farmere", in: state, player: me).first)
        XCTAssertEqual(read.command, .ferry(unit: company.id, to: to.id))
        XCTAssertEqual(read.told, "Your \(SpokenOrders.named(company, in: state)) are poled across the lake to Farmere, for \(GameState.ferryCost).")
        XCTAssertNil(read.why)
        XCTAssertEqual(SpokenOrders.read("FERRY C99 TO Farmere", in: state, player: me).first?.why, "Your House has no company C99.")
        XCTAssertEqual(SpokenOrders.read("FERRY \(c) TO Nowhere", in: state, player: me).first?.why, "Your House holds no hold by the name Nowhere.")
        XCTAssertEqual(SpokenOrders.read("FERRY \(c) TO Saltwatch", in: state, player: me).first?.why,
                       RuleError.unknownHold.description, "Not to the hold it stands at")

        // The briefing tells where it may land and for what.
        let line = "at a shore hold whence it may be ferried across the lake to Farmere for \(GameState.ferryCost) (FERRY)"
        XCTAssertTrue(SpokenOrders.briefing(for: state, player: me).contains(line), SpokenOrders.briefing(for: state, player: me))
        // Short of what the ferrymen ask: refused, and not told.
        var poor = state
        poor.houses[me].stock.timber = 0
        XCTAssertEqual(SpokenOrders.read("FERRY \(c) TO Farmere", in: poor, player: me).first?.why,
                       RuleError.shortOf(poor.houses[me].stock.shortfall(for: GameState.ferryCost)).description)
        XCTAssertFalse(SpokenOrders.briefing(for: poor, player: me).contains("(FERRY)"))

        // On the water: where it is bound, and no crossing offered again.
        _ = try state.perform(.ferry(unit: company.id, to: to.id), as: me)
        let briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains(", on the water for Farmere; they land as the watch turns"), briefing)
        XCTAssertFalse(briefing.contains("(FERRY)"))
        XCTAssertEqual(SpokenOrders.read("FERRY \(c) TO Farmere", in: state, player: me).first?.why, RuleError.alreadyOnTheWater.description)
    }

    func testACommanderPutsACrossingForward() throws {
        let (state, me, _, to, company) = try world()
        let commander = try XCTUnwrap(company.leader)
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander))
        let c = try XCTUnwrap(counsel.handle(of: company))
        XCTAssertTrue(CommanderCounsel.actions.contains("ferry"))
        XCTAssertTrue(CommanderCounsel.onlyThese.hasSuffix("or ferry (across the lake by barge, from a shore hold of your House's to another)."))
        // Its look at the company tells where it may land.
        XCTAssertTrue(counsel.report(on: c).contains("at a shore hold whence it may be ferried across the lake to Farmere"), counsel.report(on: c))

        let crossing = counsel.propose("Ferry", company: c, place: " Farmere ")
        XCTAssertEqual(crossing.line, "FERRY \(c) TO Farmere")
        XCTAssertEqual(crossing.command, .ferry(unit: company.id, to: to.id))
        XCTAssertTrue(crossing.isGiven)
        XCTAssertEqual(counsel.propose("ferry", company: c, place: "").why, "A crossing of the lake wants the hold to land at.")
        XCTAssertEqual(counsel.propose("ferry", company: c, place: "Nowhere").why, "Your House holds no hold by the name Nowhere.")
    }
}
