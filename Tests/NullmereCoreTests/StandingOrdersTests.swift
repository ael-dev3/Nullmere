import Foundation
import XCTest
@testable import NullmereCore

/// Standing orders: a keeper tells the caretaker that keeps their House
/// while they are away what to muster, what to raise first, to keep every
/// company home, whether to make peace and whether to pay tribute; the
/// caretaker does so, and no other House knows them.
final class StandingOrdersTests: XCTestCase {
    /// A keeper's House rich enough for anything, its seat's Muster Hall at
    /// the third level, and a steward of the lake.
    private func keeperWorld(_ seed: String) throws -> (GameState, me: Int, seat: Int, steward: Int) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        for kind in [BuildingKind.granary, .sawpit, .quarry, .saltworks] { state.holds[seat].levels[kind] = 3 }
        state.holds[seat].levels[.musterHall] = 3
        let room = state.storage(of: me)
        state.houses[me].stock = Stock(grain: room, timber: room, stone: room, moonsalt: room)
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        return (state, me, seat, steward)
    }

    func testAKeeperGivesStandingOrdersAndClearsThem() throws {
        var (state, me, _, steward) = try keeperWorld("standing orders given")
        XCTAssertTrue(state.standingOrders(of: me).isEmpty, "None until given")
        XCTAssertEqual(state.standingOrders(of: me).said, "While you are away, your caretaker keeps your House as it sees fit.")
        XCTAssertEqual(state.standRefusal(.home, as: steward), .notAKeeper, "A steward has no caretaker")
        XCTAssertEqual(state.standRefusal(.muster(.lantern), as: me), .notACompanyOfWar)
        XCTAssertEqual(RuleError.notACompanyOfWar.description, "Only a company of war is mustered by a standing order.")
        XCTAssertThrowsError(try state.perform(.standDown, as: me)) { XCTAssertEqual($0 as? RuleError, .noStandingOrders) }

        var events: [GameEvent] = []
        for order in [StandingOrder.muster(.bow), .raise(.walls), .home, .peace(false), .tribute(true)] {
            events += try state.perform(.stand(order), as: me)
        }
        XCTAssertEqual(events, Array(repeating: .standingOrdersGiven(house: me), count: 5))
        let orders = state.standingOrders(of: me)
        XCTAssertEqual(orders.muster, .bow)
        XCTAssertEqual(orders.raise, .walls)
        XCTAssertEqual(orders.home, true)
        XCTAssertEqual(orders.peace, false)
        XCTAssertEqual(orders.tribute, true)
        XCTAssertEqual(orders.said, "While you are away, your caretaker musters only \(UnitKind.bow.title); raises the Walls first wherever it can; "
                       + "keeps every company on your land; makes peace with no House; and pays any tribute demanded.")
        // A later order of a kind stands in for the earlier.
        _ = try state.perform(.stand(.peace(true)), as: me)
        XCTAssertEqual(state.standingOrders(of: me).peace, true)
        XCTAssertTrue(state.standingOrders(of: me).told.contains("makes peace with any House that offers it, and sues for it in every war"))
        XCTAssertEqual(state.tidings(of: .standingOrdersGiven(house: me), for: me)?.text, state.standingOrders(of: me).said)
        XCTAssertNil(state.tidings(of: .standingOrdersGiven(house: me), for: steward))

        // No other House knows them, nor hears them given.
        XCTAssertEqual(state.view(for: me).standingOrders(of: me), state.standingOrders(of: me))
        XCTAssertTrue(state.view(for: steward).standingOrders(of: me).isEmpty)
        XCTAssertEqual(state.events([.standingOrdersGiven(house: me)], heardBy: steward), [])
        // Kept with the world.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.standingOrders(of: me), state.standingOrders(of: me))

        // Cleared, the caretaker keeps the House as it sees fit.
        XCTAssertEqual(try state.perform(.standDown, as: me), [.standingOrdersGiven(house: me)])
        XCTAssertTrue(state.standingOrders(of: me).isEmpty)
        XCTAssertNil(state.standing)
    }

    /// What the seat musters over forty watches kept, each tried afresh.
    private func mustered(_ state: GameState, house: Int, seat: Int) -> [UnitKind] {
        (40..<80).compactMap { watch in
            var trial = state
            trial.watch = watch
            trial.draws = UInt64(watch)
            _ = trial.stewardTurn(for: house, caretaking: true)
            return trial.holds[seat].training?.kind
        }
    }

    func testTheCaretakerMustersOnlyTheKindItIsTold() throws {
        var (state, me, seat, _) = try keeperWorld("standing muster")
        let free = mustered(state, house: me, seat: seat).filter(\.isMilitary)
        XCTAssertGreaterThan(Set(free).count, 1, "Left to itself, more than one kind: \(free)")
        _ = try state.perform(.stand(.muster(.bow)), as: me)
        let told = mustered(state, house: me, seat: seat)
        XCTAssertFalse(told.filter(\.isMilitary).isEmpty, "It still musters: \(told)")
        XCTAssertEqual(Set(told.filter(\.isMilitary)), [.bow], "Only Bows: \(told)")
        // One it can't muster at all, none rather than another.
        _ = try state.perform(.stand(.muster(.mangonel)), as: me)
        XCTAssertFalse(mustered(state, house: me, seat: seat).contains { $0.isMilitary }, "No Mangonels below a Muster Hall of IV, and nothing else")
    }

    func testTheCaretakerRaisesTheWorkItIsToldFirst() throws {
        var (state, me, seat, _) = try keeperWorld("standing works")
        state.watch = 12
        var free = state
        _ = free.stewardTurn(for: me, caretaking: true)
        XCTAssertNotEqual(free.holds[seat].project?.kind, .wayhouse, "Left to itself, another work")
        _ = try state.perform(.stand(.raise(.wayhouse)), as: me)
        _ = state.stewardTurn(for: me, caretaking: true)
        XCTAssertEqual(state.holds[seat].project?.kind, .wayhouse)
        // Where it can't be raised, the caretaker raises what it would.
        var full = state
        full.holds[seat].project = nil
        full.holds[seat].levels[.wayhouse] = BuildingKind.wayhouse.maxLevel
        _ = full.stewardTurn(for: me, caretaking: true)
        XCTAssertNotNil(full.holds[seat].project)
        XCTAssertNotEqual(full.holds[seat].project?.kind, .wayhouse)
        // A steward of the same lake never heeds them.
        XCTAssertEqual(RivalMind(house: me).caretaking, false)
    }

    func testTheCaretakerKeepsEveryCompanyHome() throws {
        var (state, me, seat, steward) = try keeperWorld("standing home")
        _ = try state.declareWar(by: steward, on: me)
        state.houses[me].explored = Array(repeating: true, count: state.map.count)
        // A company of the keeper's far from home, nearer the foe's seat than its own.
        let foeSeat = try XCTUnwrap(state.seat(of: steward)).position
        let home = state.holds[seat].position
        let owners = state.territory()
        let far = try XCTUnwrap(state.map.hexes.filter { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !state.isOccupied(hex)
                && state.territoryOwner(of: hex, in: owners) == nil && hex.distance(to: foeSeat) < hex.distance(to: home)
                && hex.distance(to: home) >= 6
        }.min { ($0.distance(to: foeSeat), $0) < ($1.distance(to: foeSeat), $1) })
        state.units.removeAll { $0.owner == me && $0.kind.isMilitary }
        let company = state.put(.spear, of: me, at: far)
        _ = try state.perform(.stand(.home), as: me)
        for _ in 0..<12 {
            let index = try XCTUnwrap(state.unitIndex(company))
            state.units[index].movesLeft = state.movement(of: state.units[index])
            _ = state.stewardTurn(for: me, caretaking: true)
            guard state.unit(company) != nil else { break }
        }
        let unit = try XCTUnwrap(state.unit(company), "Kept home, it lives")
        XCTAssertEqual(state.territoryOwner(of: unit.position), me, "Home on its own land")
        XCTAssertTrue(unit.fortified, "and dug in there")
    }

    func testTheCaretakerMakesPeaceAndPaysTributeAsItIsTold() throws {
        var (state, me, _, steward) = try keeperWorld("standing peace")
        // A war one watch old: a steward in the keeper's place would not yet end it.
        _ = try state.declareWar(by: steward, on: me)
        state.watch += 1
        XCTAssertFalse(RivalMind(house: me).accepts(.peace, from: steward, in: state), "Too young a war")
        func offered(_ proposal: Proposal, to state: GameState) -> GameState {
            var state = state
            state.envoys.append(Envoy(id: state.takeID(), from: steward, to: me, proposal: proposal, arrived: state.watch))
            _ = state.stewardTurn(for: me, caretaking: true)
            return state
        }
        var peaceful = state
        _ = try peaceful.perform(.stand(.peace(true)), as: me)
        XCTAssertEqual(offered(.peace, to: peaceful).stance(me, steward), .peace, "Peace with any who offer it")
        // And sued for in every war, whoever is the stronger.
        var suing = peaceful
        let events = suing.stewardTurn(for: me, caretaking: true)
        XCTAssertTrue(events.contains { event in
            if case .proposalAnswered(.peace, me, steward, _) = event { return true }
            return false
        } || suing.envoys.contains { $0.from == me && $0.proposal == .peace }, "Peace sued for: \(events)")

        // Made with none: a war old enough to end goes on.
        var warlike = state
        warlike.watch += 30
        XCTAssertTrue(RivalMind(house: me).accepts(.peace, from: steward, in: warlike), "Long enough for a steward")
        _ = try warlike.perform(.stand(.peace(false)), as: me)
        let after = offered(.peace, to: warlike)
        XCTAssertEqual(after.stance(me, steward), .war, "Peace with no House")
        var quiet = warlike
        XCTAssertFalse(quiet.stewardTurn(for: me, caretaking: true).contains { event in
            if case .proposalAnswered(.peace, me, _, _) = event { return true }
            return false
        }, "Nor sued for")

        // Tribute: paid where told, whoever demands it; refused where told.
        var calm = state
        calm.setStance(.peace, between: me, and: steward, by: me)
        var paying = calm
        _ = try paying.perform(.stand(.tribute(true)), as: me)
        let grain = paying.houses[me].stock.grain
        XCTAssertFalse(RivalMind(house: me).accepts(.tribute, from: steward, in: paying), "A steward as strong would refuse")
        let paid = offered(.tribute, to: paying)
        XCTAssertLessThan(paid.houses[me].stock.grain + paid.houses[me].stock.timber + paid.houses[me].stock.stone,
                          grain + paying.houses[me].stock.timber + paying.houses[me].stock.stone, "Paid")
        XCTAssertEqual(paid.stance(me, steward), .peace)
        var refusing = calm
        _ = try refusing.perform(.stand(.tribute(false)), as: me)
        XCTAssertEqual(offered(.tribute, to: refusing).stance(me, steward), .war, "Refused, and war for it")
    }

    /// A world of stewards has no standing orders, and goes as it did.
    func testStewardsGiveNone() {
        var stewards = GameState(settings: GameSettings(seedText: "stewards stand no orders", houseCount: 4, radius: 18))
        for _ in 0..<20 { _ = stewards.endWatch() }
        XCTAssertNil(stewards.standing)
    }
}
