import Foundation
@testable import NullmereCore
import XCTest
@testable import NullmereCompanionCore

/// What the phone lists of a House, read from the keeper's view: every
/// order it offers one the rules take as offered, and none it offers that
/// would do nothing; the stores, holds and words as the realm keeps them.
final class CompanionLedgerTests: XCTestCase {
    private func world() throws -> (GameState, Int) {
        var state = GameState(settings: GameSettings(seedText: "companion ledger", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        return (state, me)
    }

    /// Every order offered is one the rules would carry out as offered.
    private func assertTaken(_ orders: [CompanionLedger.Order], in state: GameState, as house: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        for order in orders {
            XCTAssertNil(state.refusal(of: order.command, as: house), "\(order.title) offered but refused", file: file, line: line)
        }
    }

    func testTheHousesWorksAndMustersAreThoseTheRulesTake() throws {
        let (state, me) = try world()
        let ledger = CompanionLedger(world: state, player: me)
        let seat = try XCTUnwrap(ledger.holds.first(where: \.isSeat))
        XCTAssertEqual(ledger.holds.first?.id, seat.id, "The seat first")
        XCTAssertTrue(seat.works.contains { $0.title == "Raise Granary I" }, "\(seat.works.map(\.title))")
        XCTAssertFalse(seat.musters.isEmpty)
        let hold = try XCTUnwrap(state.hold(seat.id))
        assertTaken(seat.works + seat.musters, in: state, as: me)
        // Raising one, the hold offers no other work until it is done; one
        // mustering, no other muster.
        var raising = state
        _ = try raising.perform(.build(hold: hold.id, kind: .granary), as: me)
        let busy = try XCTUnwrap(CompanionLedger(world: raising, player: me).holds.first(where: \.isSeat))
        XCTAssertTrue(busy.works.isEmpty)
        XCTAssertTrue(busy.work.contains { $0.hasPrefix("Raising Granary I,") }, "\(busy.work)")
        let muster = try XCTUnwrap(seat.musters.first)
        _ = try raising.perform(muster.command, as: me)
        let mustering = try XCTUnwrap(CompanionLedger(world: raising, player: me).holds.first(where: \.isSeat))
        XCTAssertTrue(mustering.musters.isEmpty)
        XCTAssertTrue(mustering.work.contains { $0.hasPrefix("Mustering ") }, "\(mustering.work)")
        // A House with nothing in its stores raises and musters nothing.
        var poor = state
        poor.houses[me].stock = .zero
        let bare = try XCTUnwrap(CompanionLedger(world: poor, player: me).holds.first(where: \.isSeat))
        XCTAssertTrue(bare.works.isEmpty)
        XCTAssertTrue(bare.musters.isEmpty)
    }

    func testACompanysStrikesAndGatheringAreThoseTheRulesTake() throws {
        var (state, me) = try world()
        // A company of war set beside a wild of the land, once the wilds rise.
        for _ in 0..<40 where state.wildsStanding.isEmpty && state.outcome == nil {
            _ = state.stewardTurn(for: me)
            _ = state.endWatch()
        }
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        let wild = try XCTUnwrap(state.wildsStanding.first, "The wilds rise within forty watches")
        let beside = try XCTUnwrap(wild.position.neighbors.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.wild(at: hex) == nil
                && state.hold(at: hex) == nil && state.lair(at: hex) == nil
        })
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: beside))
        XCTAssertEqual(spear.position, beside)
        let ledger = CompanionLedger(world: state, player: me)
        let company = try XCTUnwrap(ledger.companies.first { $0.id == spear.id })
        let strike = try XCTUnwrap(company.strikes.first { $0.title == "Strike the \(wild.kind.title)" }, "\(company.strikes.map(\.title))")
        XCTAssertEqual(strike.command, .attack(unit: spear.id, target: wild.position))
        assertTaken(company.strikes, in: state, as: me)
        // Gathering: at most the nearest few sites, each one the rules would send it to.
        XCTAssertLessThanOrEqual(company.gathers.count, CompanionLedger.sitesOffered)
        assertTaken(company.gathers, in: state, as: me)
        for gather in company.gathers { XCTAssertTrue(gather.title.hasPrefix("Gather ")) }
        // Its moves spent, it strikes nothing.
        let index = try XCTUnwrap(state.units.firstIndex { $0.id == spear.id })
        state.units[index].movesLeft = 0
        let spent = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertTrue(spent.strikes.isEmpty)
        // A founder strikes and gathers nothing, and is offered no fortifying.
        if let founder = ledger.companies.first(where: { state.unit($0.id)?.kind == .founder }) {
            XCTAssertTrue(founder.strikes.isEmpty)
            XCTAssertTrue(founder.gathers.isEmpty)
            XCTAssertFalse(founder.orders.contains { $0.title == "Fortify" })
        }
        // What each company is about, in a few words.
        XCTAssertEqual(company.doing, "At rest")
        var marching = state
        let seat = try XCTUnwrap(marching.seat(of: me))
        _ = try marching.perform(.move(unit: spear.id, to: seat.position), as: me)
        let moving = try XCTUnwrap(CompanionLedger(world: marching, player: me).companies.first { $0.id == spear.id })
        if marching.unit(spear.id)?.destination != nil {
            XCTAssertTrue(moving.doing.hasPrefix("Marching to "), moving.doing)
            XCTAssertTrue(moving.orders.contains { $0.title == "Halt" })
        }
    }
}
