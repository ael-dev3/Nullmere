import Foundation
import XCTest
@testable import NullmereCore

/// A commander's look at the House's holds and what they may put forward
/// there: each hold's work and muster under way, its works, and what it may
/// raise or muster now and for what, as the rules would take them; a work
/// raised a level or a company mustered put to the keeper as the order book
/// reads BUILD and TRAIN, or told why not in the realm's words; and the
/// order book reading a work or kind named with its numeral, as a look
/// names them.
final class CounselHoldsTests: XCTestCase {
    /// A keeper's House with its seat idle, a Muster Hall raised there and
    /// stores enough to raise and muster, its first commander to counsel.
    private func world() throws -> (state: GameState, me: Int, seat: Hold, counsel: CommanderCounsel) {
        var state = GameState(settings: GameSettings(seedText: "holds in counsel", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        state.houses[me].stock = Stock(grain: 2_000, timber: 2_000, stone: 2_000, moonsalt: 200)
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].project = nil
        state.holds[index].training = nil
        state.holds[index].levels[.musterHall] = 1
        let counsel = try counsel(state)
        return (state, me, state.holds[index], counsel)
    }

    private func counsel(_ state: GameState) throws -> CommanderCounsel {
        let id = try XCTUnwrap(state.commanders(of: state.player).first).id
        return try XCTUnwrap(CommanderCounsel(state: state, player: state.player, commander: id))
    }

    func testACommanderLooksOverTheHousesHolds() throws {
        let made = try world()
        var state = made.state
        let me = made.me, seat = made.seat, counsel = made.counsel
        XCTAssertTrue(counsel.instructions.contains("at your House's affairs, at its holds,"))
        XCTAssertTrue(counsel.instructions.contains("for a company, for a hold of your House, for yourself"))
        let granary = BuildingKind.granary
        let next = seat.level(granary) + 1
        let report = counsel.holdsReport
        XCTAssertTrue(report.hasPrefix("\(seat.name), your seat, idle."), report)
        XCTAssertTrue(report.contains("It may raise now: "), report)
        XCTAssertTrue(report.contains("\(granary.title) \(BuildingKind.numeral(next)) (\(state.buildCost(of: granary, toLevel: next, for: me).description))"),
                      report)
        XCTAssertTrue(report.contains("It may muster now: "), report)
        XCTAssertTrue(report.contains("\(state.named(.spear, tier: 1, of: me)) (\(state.trainingCost(of: .spear, tier: 1, for: me).description))"),
                      report)
        let works = BuildingKind.allCases.filter { seat.level($0) > 0 }
        if let first = works.first {
            XCTAssertTrue(report.contains("Its works: \(first.title) \(BuildingKind.numeral(seat.level(first)))"), report)
        }
        // Only what the rules would take is offered: nothing a seat alone may raise at another hold, nothing past its height.
        for kind in BuildingKind.allCases where state.refusal(of: .build(hold: seat.id, kind: kind), as: me) != nil {
            XCTAssertFalse(report.contains(" \(kind.title) \(BuildingKind.numeral(seat.level(kind) + 1)) ("), "\(kind) is offered: \(report)")
        }

        // At work: what is under way, and nothing more raised or mustered there while it is.
        _ = try state.perform(.build(hold: seat.id, kind: granary), as: me)
        _ = try state.perform(.train(hold: seat.id, kind: .spear), as: me)
        let busy = try self.counsel(state).holdsReport
        let raising = try XCTUnwrap(state.hold(seat.id)?.project)
        let mustering = try XCTUnwrap(state.hold(seat.id)?.training)
        XCTAssertTrue(busy.hasPrefix("\(seat.name), your seat: raising its \(granary.title) to \(BuildingKind.numeral(next)), "
                                     + "\(GameState.watches(raising.watchesLeft)) to go; mustering \(state.named(.spear, tier: 1, of: me)), "
                                     + "\(GameState.watches(mustering.watchesLeft)) to go."), busy)
        XCTAssertFalse(busy.contains("It may raise"), busy)
        XCTAssertFalse(busy.contains("It may muster"), busy)

        // Short of every store: nothing may be raised or mustered, and it says so.
        var poor = try world().state
        poor.houses[me].stock = Stock()
        let bare = try self.counsel(poor).holdsReport
        XCTAssertTrue(bare.contains("It may raise nothing now."), bare)
        XCTAssertTrue(bare.contains("It may muster nothing now."), bare)
    }

    /// A seat without a Muster Hall musters no company of war: the look
    /// offers none, and a muster put forward is refused in the rules' words.
    func testAMusterWantsItsMusterHall() throws {
        var state = try world().state
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].levels[.musterHall] = nil
        let counsel = try self.counsel(state)
        XCTAssertFalse(counsel.holdsReport.contains("\(state.named(.spear, tier: 1, of: me)) ("), counsel.holdsReport)
        let refused = counsel.proposeForAHold("muster", hold: seat.name, what: "Spears")
        XCTAssertEqual(refused.command, .train(hold: seat.id, kind: .spear))
        XCTAssertEqual(refused.why, state.refusal(of: .train(hold: seat.id, kind: .spear), as: me)?.description)
        XCTAssertNotNil(refused.why)
    }

    func testACommanderPutsAWorkOrAMusterForward() throws {
        let (state, me, seat, counsel) = try world()
        XCTAssertEqual(CommanderCounsel.holdActions, ["raise", "muster"])
        let raise = counsel.proposeForAHold("raise", hold: seat.name, what: "Granary \(BuildingKind.numeral(seat.level(.granary) + 1))")
        XCTAssertEqual(raise.line, "BUILD Granary \(BuildingKind.numeral(seat.level(.granary) + 1)) AT \(seat.name)")
        XCTAssertEqual(raise.command, .build(hold: seat.id, kind: .granary))
        XCTAssertEqual(raise.told, "\(seat.name) raises its Granary.")
        XCTAssertTrue(raise.isGiven)
        XCTAssertNil(raise.askedFirst)
        let muster = counsel.proposeForAHold(" Muster ", hold: " \(seat.name) ", what: "Spears I")
        XCTAssertEqual(muster.command, .train(hold: seat.id, kind: .spear))
        XCTAssertEqual(muster.told, "\(seat.name) musters a company of Spears.")
        XCTAssertTrue(muster.isGiven)

        // Refused in the realm's words: no such hold, no such work or kind, short of stores, busy.
        XCTAssertEqual(counsel.proposeForAHold("raise", hold: "Nowhere", what: "Granary").why, "Your House holds no hold by the name Nowhere.")
        XCTAssertEqual(counsel.proposeForAHold("raise", hold: seat.name, what: "Dance Hall").why, "No work goes by the name Dance Hall.")
        XCTAssertEqual(counsel.proposeForAHold("muster", hold: seat.name, what: "Dragons").why, "No company goes by the name Dragons.")
        var poor = state
        poor.houses[me].stock = Stock()
        XCTAssertEqual(try self.counsel(poor).proposeForAHold("muster", hold: seat.name, what: "Spears").why,
                       poor.refusal(of: .train(hold: seat.id, kind: .spear), as: me)?.description)
        var busy = state
        _ = try busy.perform(.build(hold: seat.id, kind: .granary), as: me)
        XCTAssertEqual(try self.counsel(busy).proposeForAHold("raise", hold: seat.name, what: "Granary").why, RuleError.busy.description)

        // Nothing else, and nothing without the hold or what is wanted there.
        XCTAssertEqual(counsel.proposeForAHold("feast", hold: seat.name, what: "Granary").why, CommanderCounsel.onlyTheseForHolds)
        XCTAssertEqual(counsel.proposeForAHold("raise", hold: "", what: "Granary").why,
                       "That wants the hold, and the work to raise or the kind of company to muster there.")
        XCTAssertEqual(counsel.proposeForAHold("muster", hold: seat.name, what: " ").why,
                       "That wants the hold, and the work to raise or the kind of company to muster there.")
    }

    /// The order book reads a work or kind named with its numeral, as a
    /// look names them, and a name that only ends like one as itself.
    func testTheOrderBookReadsAWorkOrKindWithItsNumeral() throws {
        let (state, me, seat, _) = try world()
        XCTAssertEqual(SpokenOrders.read("BUILD the granary iii AT \(seat.name)", in: state, player: me).first?.command,
                       .build(hold: seat.id, kind: .granary))
        XCTAssertEqual(SpokenOrders.read("TRAIN Spears I AT \(seat.name)", in: state, player: me).first?.command,
                       .train(hold: seat.id, kind: .spear))
        XCTAssertEqual(SpokenOrders.unnumbered("Muster Hall IV"), "muster hall")
        XCTAssertEqual(SpokenOrders.unnumbered("Granary"), "granary")
        XCTAssertEqual(SpokenOrders.unnumbered("IV"), "iv", "A numeral alone is a name, not a level")
        XCTAssertEqual(SpokenOrders.unnumbered("Spears XI"), "spears xi", "Only the numerals of a level or tier are set aside")
    }
}
