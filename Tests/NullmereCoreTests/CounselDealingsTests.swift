import Foundation
import XCTest
@testable import NullmereCore

/// A commander putting the House's dealings with another House to the
/// keeper: an envoy offering peace or a pact or demanding tribute, or war,
/// each read as the order book's line and weighed by the rules, or told why
/// not in the realm's words; war asked of the keeper again before it is
/// given, a pact's betrayal named as the Houses panel names it.
final class CounselDealingsTests: XCTestCase {
    private func counsel(_ state: GameState) throws -> CommanderCounsel {
        let id = try XCTUnwrap(state.commanders(of: state.player).first).id
        return try XCTUnwrap(CommanderCounsel(state: state, player: state.player, commander: id))
    }

    /// A keeper's House and another, at peace and sworn to no alliance.
    private func world() throws -> (state: GameState, me: Int, other: Int) {
        let state = GameState(settings: GameSettings(seedText: "dealings in counsel", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.map(\.id).first {
            $0 != me && state.stance(me, $0) == .peace && !state.areAllied(me, $0) && state.mayDemandTribute(by: me, of: $0)
        })
        return (state, me, other)
    }

    func testACommanderPutsTheHousesDealingsForward() throws {
        var (state, me, other) = try world()
        let title = state.houses[other].title
        let counsel = try counsel(state)
        XCTAssertTrue(counsel.instructions.contains("for your House's alliance, toward another House or in answer to an envoy"))
        XCTAssertEqual(CommanderCounsel.dealingActions, ["peace", "pact", "tribute", "war"])

        // At peace: a pact offered and tribute demanded, as the order book reads them.
        let pact = counsel.proposeDealing("pact", house: title)
        XCTAssertEqual(pact.line, "OFFER A PACT TO \(title)")
        XCTAssertEqual(pact.command, .propose(.pact, to: other))
        XCTAssertEqual(pact.told, "An envoy to \(title), offering a pact.")
        XCTAssertTrue(pact.isGiven)
        XCTAssertNil(pact.askedFirst, "An envoy is asked nothing more")
        let tribute = counsel.proposeDealing("Demand tribute", house: " \(title) ")
        XCTAssertEqual(tribute.line, "DEMAND TRIBUTE FROM \(title)")
        XCTAssertEqual(tribute.command, .propose(.tribute, to: other))
        XCTAssertTrue(tribute.isGiven)
        // Peace with a House already at peace: refused in the realm's words.
        let peace = counsel.proposeDealing("peace", house: title)
        XCTAssertEqual(peace.command, .propose(.peace, to: other))
        XCTAssertEqual(peace.why, RuleError.alreadyStance(.peace).description)
        XCTAssertFalse(peace.isGiven)
        XCTAssertEqual(peace.answer, "That cannot be ordered: \(RuleError.alreadyStance(.peace).description)")

        // War: put forward, and asked of the keeper again before it is given.
        let war = counsel.proposeDealing(" War ", house: title)
        XCTAssertEqual(war.line, "DECLARE WAR ON \(title)")
        XCTAssertEqual(war.command, .declareWar(on: other))
        XCTAssertEqual(war.told, "War on \(title).")
        XCTAssertTrue(war.isGiven)
        XCTAssertEqual(war.askedFirst, "War on \(title)?")
        XCTAssertEqual(war.answer, "Put forward to your keeper: War on \(title). The keeper decides.")

        // Nothing else, no House named, none such, nor the House's own.
        XCTAssertEqual(counsel.proposeDealing("feast", house: title).why, CommanderCounsel.onlyTheseForDealings)
        XCTAssertNil(counsel.proposeDealing("feast", house: title).command)
        XCTAssertEqual(counsel.proposeDealing("war", house: "  ").why, "A dealing with another House wants the House's name.")
        XCTAssertEqual(counsel.proposeDealing("war", house: "Nowhere").why, "No House goes by the name Nowhere.")
        XCTAssertEqual(counsel.proposeDealing("war", house: state.houses[me].title).why,
                       "No House goes by the name \(state.houses[me].title).")

        // At war: peace may be offered; war and tribute are refused, and nothing is asked first.
        _ = try state.perform(.declareWar(on: other), as: me)
        let atWar = try self.counsel(state)
        let offered = atWar.proposeDealing("offer peace", house: title)
        XCTAssertEqual(offered.command, .propose(.peace, to: other))
        XCTAssertTrue(offered.isGiven)
        let again = atWar.proposeDealing("war", house: title)
        XCTAssertEqual(again.why, RuleError.alreadyStance(.war).description)
        XCTAssertNil(again.askedFirst, "Nothing asked of what can't be given")
        XCTAssertEqual(atWar.proposeDealing("tribute", house: title).why, RuleError.notApplicable.description)
    }

    /// A pact broken by war is named for what it is, as the Houses panel names it.
    func testWarOnAHouseOfAPactIsAskedAsABetrayal() throws {
        var (state, me, other) = try world()
        state.setStance(.pact, between: me, and: other, by: me)
        let title = state.houses[other].title
        let war = try counsel(state).proposeDealing("war", house: title)
        XCTAssertEqual(war.command, .declareWar(on: other))
        XCTAssertTrue(war.isGiven)
        XCTAssertEqual(war.askedFirst, "Betray \(title)?")
        XCTAssertEqual(CommanderCounsel.warAsked(on: title, pact: false), "War on \(title)?")
        XCTAssertEqual(try counsel(state).proposeDealing("pact", house: title).why, RuleError.alreadyStance(.pact).description)
    }
}
