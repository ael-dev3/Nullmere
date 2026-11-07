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

    /// The House's commanders as the Mac's board orders them, each with
    /// how they stand; one held prisoner may not be asked for counsel.
    func testTheHousesCommandersAndHowTheyStand() throws {
        var (state, me) = try world()
        let first = try XCTUnwrap(state.commanders(of: me).first, "Every House begins with a commander")
        let ledger = CompanionLedger(world: state, player: me)
        let listed = try XCTUnwrap(ledger.commanders.first { $0.id == first.id })
        XCTAssertEqual(listed.name, first.name)
        XCTAssertEqual(listed.title, "\(first.archetype.title) · level \(first.level)")
        XCTAssertTrue(listed.canCounsel)
        if let unit = state.company(ledBy: first.id) {
            XCTAssertEqual(listed.standing, "Leads the \(SpokenOrders.named(unit, in: state))")
        } else {
            XCTAssertEqual(listed.standing, "Free to lead a company of war")
        }
        // Wounded, and then taken.
        let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == first.id })
        state.commanders?[index].woundedUntil = state.watch + 3
        XCTAssertEqual(CompanionLedger(world: state, player: me).commanders.first { $0.id == first.id }?.standing,
                       "Wounded: whole again in 3 watches")
        let captor = (me + 1) % state.houses.count
        state.commanders?[index].captive = Captivity(by: captor, since: state.watch, questioned: 0)
        let held = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == first.id })
        XCTAssertEqual(held.standing, "Held prisoner by \(state.houses[captor].title)")
        XCTAssertFalse(held.canCounsel)
        XCTAssertNotEqual(CompanionLedger(world: state, player: me), ledger, "A commander's standing changes the ledger")
    }

    /// What the phone offers the House's alliance, each the rules would
    /// take: help for an ally's works under way, a company sent to a rally
    /// of the House's side, and a company sent to keep an ally's gates.
    func testAllianceHelpRalliesAndGatesAreThoseTheRulesTake() throws {
        var (state, me) = try world()
        let seat = try XCTUnwrap(state.seat(of: me))
        let walker = Unit(id: -1, kind: .spear, owner: me, position: seat.position)
        let others = state.houses.indices.filter { $0 != me }
        let ally = try XCTUnwrap(others.first { other in
            state.seat(of: other).map { state.path(for: walker, to: $0.position) != nil } ?? false
        }, "An ally's seat the House's companies can reach")
        let foe = try XCTUnwrap(others.first { $0 != ally })
        state.houses[ally].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Hostward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        XCTAssertTrue(state.areAllied(me, ally))
        XCTAssertTrue(CompanionLedger(world: state, player: me).helps.isEmpty, "Nothing of theirs under way")

        // Help: an ally raising a work.
        state.houses[ally].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        let allySeat = try XCTUnwrap(state.seat(of: ally))
        _ = try state.perform(.build(hold: allySeat.id, kind: .granary), as: ally)
        let help = try XCTUnwrap(CompanionLedger(world: state, player: me).helps.first)
        XCTAssertEqual(help.command, .help(house: ally))
        XCTAssertEqual(help.title, "Help \(state.houses[ally].title), \(state.helpable(by: me, for: ally)) under way")
        assertTaken([help], in: state, as: me)
        var helped = state
        _ = try helped.perform(help.command, as: me)
        XCTAssertTrue(CompanionLedger(world: helped, player: me).helps.isEmpty, "Helped, nothing left to help")

        // Keeping an ally's gates: their seat, the company free to go.
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: seat.position))
        var company = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertEqual(company.gates.map(\.command), [.reinforce(unit: spear.id, hold: allySeat.id)])
        XCTAssertEqual(company.gates.first?.title, "Keep the gates of \(allySeat.name)")
        assertTaken(company.gates, in: state, as: me)
        XCTAssertTrue(company.rallies.isEmpty, "No rally called")

        // A rally of the House's own, against a foe's seat it knows.
        _ = try state.declareWar(by: me, on: foe)
        let seatIndex = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[seatIndex].levels[.musterHall] = 1
        let foeSeat = try XCTUnwrap(state.seat(of: foe))
        state.reveal(around: foeSeat.position, range: 0, for: me)
        _ = try state.perform(.callRally(from: seat.id, against: foeSeat.id, watches: 2), as: me)
        let rally = try XCTUnwrap(state.ralliesStanding.first)
        company = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertEqual(company.rallies.map(\.command), [.joinRally(rally: rally.id, unit: spear.id)])
        XCTAssertEqual(company.rallies.first?.title, "Join the rally against \(foeSeat.name)")
        assertTaken(company.rallies, in: state, as: me)
        // Sent to it, it is offered neither again, nor any gates, while on its errand.
        _ = try state.perform(.joinRally(rally: rally.id, unit: spear.id), as: me)
        company = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertTrue(company.rallies.isEmpty)
        XCTAssertTrue(company.gates.isEmpty)
        XCTAssertEqual(state.joinRallyRefusal(rally.id, with: spear.id, as: me), .alreadyRallying)
        // A company not of war is sent to neither.
        if let founder = state.units(of: me).first(where: { !$0.kind.isMilitary }) {
            let plain = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == founder.id })
            XCTAssertTrue(plain.rallies.isEmpty)
            XCTAssertTrue(plain.gates.isEmpty)
        }
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
