import Foundation
import XCTest
@testable import NullmereCore

/// Deeds for the House's alliance in the order book and in counsel: stores
/// given toward its study, a thing taken from its stall for the House's
/// merit, an ally's works helped and the shares of its spoils taken up;
/// each line read into the order the realm would take, or told why not, and
/// a commander putting each forward the same way.
final class AllianceDeedsTests: XCTestCase {
    /// A keeper's alliance of two: the keeper's House and a steward's.
    private func sworn() throws -> (state: GameState, me: Int, ally: Int) {
        var state = GameState(settings: GameSettings(seedText: "alliance deeds", houseCount: 12, radius: 36, keepers: 1))
        let me = state.player, ally = 1
        state.houses[ally].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Hearthward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        return (state, me, ally)
    }

    private func gift(_ amount: Int, _ resource: Resource) -> Stock {
        var stock = Stock()
        stock[resource] = amount
        return stock
    }

    func testTheStudyAndTheStallAreReadFromTheOrderBook() throws {
        var (state, me, ally) = try sworn()
        XCTAssertTrue(SpokenOrders.forms.contains("GIVE <amount> <store> TO THE STUDY"))
        XCTAssertTrue(SpokenOrders.forms.contains("TAKE <thing> FROM THE STALL"))

        // Toward the study: refused while the alliance pursues none.
        let unpursued = try XCTUnwrap(SpokenOrders.read("GIVE 50 GRAIN TO THE STUDY", in: state, player: me).first)
        XCTAssertEqual(unpursued.command, .giveToAlliance(gift(50, .grain)))
        XCTAssertEqual(unpursued.told, "50 grain given toward your alliance's study.")
        XCTAssertEqual(unpursued.why, RuleError.noAllianceStudy.description)
        _ = try state.perform(.pursueAllianceStudy(.fieldcraft), as: me)
        let given = try XCTUnwrap(SpokenOrders.read("give 50 grain to the alliance's study", in: state, player: me).first)
        XCTAssertEqual(given.told, "50 grain given toward Fieldcraft I.")
        XCTAssertNil(given.why)
        // To a House, a gift as ever.
        let title = state.houses[ally].title
        XCTAssertEqual(SpokenOrders.read("GIVE 50 GRAIN TO \(title)", in: state, player: me).first?.command,
                       .gift(to: ally, resource: .grain, amount: 50))

        // From the stall, by its whole name or one word only it holds.
        state.earnMerit(100, by: me)
        let lines = SpokenOrders.read("TAKE A SALT HOURGLASS FROM THE STALL\nTAKE TOME FROM THE STALL\nTAKE CACHE FROM THE STALL\nTAKE THE SHARES",
                                      in: state, player: me)
        XCTAssertEqual(lines.map(\.command), [.takeFromStall(.hourglass), .takeFromStall(.tome), nil, .takeShares])
        XCTAssertEqual(lines[0].told, "Your House takes a Salt Hourglass from the alliance's stall for 60 merit.")
        XCTAssertNil(lines[0].why)
        XCTAssertEqual(lines[1].why, RuleError.shortOfMerit(50).description)
        XCTAssertEqual(lines[2].why, "The alliance's stall keeps nothing called CACHE.", "Four caches: name one whole")

        // The briefing tells the study pursued and what the merit reaches.
        let briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains("Your alliance pursues Fieldcraft I; your House may give stores toward it (GIVE <amount> <store> TO THE STUDY)."),
                      briefing)
        XCTAssertTrue(briefing.contains("Your House's merit with the alliance is 100; at its stall it may take any of (TAKE <thing> FROM THE STALL): "
                                        + "Salt Hourglass, Cache of Grain, Cache of Timber, Cache of Stone, Cache of Moonsalt, Mending Draught."),
                      briefing)
        var poor = state
        _ = try poor.perform(.takeFromStall(.mendingDraught), as: me)
        XCTAssertTrue(SpokenOrders.briefing(for: poor, player: me).contains("Your House's merit with the alliance is 20; it reaches nothing at the stall yet."))
    }

    func testACommanderPutsAllianceDeedsForward() throws {
        var (state, me, ally) = try sworn()
        _ = try state.perform(.pursueAllianceStudy(.fieldcraft), as: me)
        state.earnMerit(100, by: me)
        let id = try XCTUnwrap(state.commanders(of: me).first).id
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        XCTAssertTrue(counsel.instructions.contains("for your House's alliance"))
        XCTAssertEqual(CommanderCounsel.allianceActions, ["help", "shares", "give", "take"])

        let title = state.houses[ally].title
        XCTAssertEqual(counsel.proposeForAlliance("help", what: title).command, .help(house: ally))
        XCTAssertEqual(counsel.proposeForAlliance("shares", what: "").command, .takeShares)
        let give = counsel.proposeForAlliance("give", what: "50 grain")
        XCTAssertEqual(give.command, .giveToAlliance(gift(50, .grain)))
        XCTAssertNil(give.why)
        XCTAssertEqual(give.line, "GIVE 50 grain TO THE STUDY")
        let take = counsel.proposeForAlliance("Take", what: " Salt Hourglass ")
        XCTAssertEqual(take.command, .takeFromStall(.hourglass))
        XCTAssertNil(take.why)
        XCTAssertTrue(take.isGiven)
        XCTAssertEqual(counsel.proposeForAlliance("take", what: "Tome of Old Campaigns").why, RuleError.shortOfMerit(50).description)
        XCTAssertEqual(counsel.proposeForAlliance("dance", what: "").why, CommanderCounsel.onlyTheseForAlliance)
        XCTAssertEqual(counsel.proposeForAlliance("help", what: "").why,
                       "That wants a name: the House to help, the stores to give or the thing to take.")
    }
}
