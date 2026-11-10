import Foundation
import XCTest
@testable import NullmereCore

/// Merit with an alliance and its stall (Rise of Kingdoms' alliance credits
/// and shop): earned helping allies' works and giving toward the alliance's
/// study, kept by the alliance for each of its Houses, and spent at its
/// stall on one of every kind of thing a satchel holds; told to the House
/// alone, refused in the realm's words, known in counsel.
final class AllianceStallTests: XCTestCase {
    /// A keeper's alliance of two: the keeper's House and a steward's.
    private func sworn() throws -> (state: GameState, me: Int, ally: Int) {
        var state = GameState(settings: GameSettings(seedText: "the alliance's stall", houseCount: 12, radius: 36, keepers: 1))
        let me = state.player, ally = 1
        state.houses[ally].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Hearthward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        XCTAssertTrue(state.areAllied(me, ally))
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        return (state, me, ally)
    }

    func testMeritIsEarnedHelpingAlliesAndGivingTowardTheStudy() throws {
        var (state, me, ally) = try sworn()
        XCTAssertEqual(state.merit(of: me), 0)
        let named = try XCTUnwrap(state.alliance(of: me)).name
        XCTAssertEqual(state.meritSaid(of: me), "Your merit with \(named): 0.")
        XCTAssertNil(state.meritSaid(of: 2), "Sworn to none")

        // Three of an ally's things helped: ten merit for each.
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == ally && $0.isSeat })
        state.holds[seat].project = Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 5)
        state.holds[seat].training = Hold.Training(kind: .spear, watchesLeft: 2)
        state.houses[ally].research.pursuit = Pursuit(study: .drill, grade: 1, watchesLeft: 3)
        let events = try state.perform(.help(house: ally), as: me)
        XCTAssertEqual(events, [.helpGiven(by: me, to: ally, count: 3)])
        XCTAssertEqual(state.merit(of: me), 3 * GameState.meritPerHelp)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "You help 3 of \(state.houses[ally].title)'s works, for 30 merit with your alliance.")

        // Given toward the study: one for each ten worth, none lost to rounding.
        _ = try state.perform(.pursueAllianceStudy(.fieldcraft), as: me)
        var gift = Stock()
        gift[.grain] = 25
        _ = try state.perform(.giveToAlliance(gift), as: me)
        XCTAssertEqual(state.merit(of: me), 32)
        gift[.grain] = 15
        _ = try state.perform(.giveToAlliance(gift), as: me)
        XCTAssertEqual(state.merit(of: me), 34, "Forty grain given, four merit")
        XCTAssertEqual(state.merit(of: ally), 0, "Each House's own")
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)

        // Known to the alliance's own Houses, and to no other.
        XCTAssertEqual(state.view(for: me).merit(of: me), 34)
        XCTAssertNil(state.view(for: 2).alliance(of: me)?.merit, "Another House's view")

        // Kept by the alliance for a House that leaves, as it left it.
        var left = state
        _ = try left.perform(.leaveAlliance, as: ally)
        XCTAssertEqual(left.merit(of: me), 34)
    }

    func testTheStallTradesMeritForWhatItKeeps() throws {
        var (state, me, ally) = try sworn()
        XCTAssertEqual(GameState.stall, ItemKind.allCases, "One of every kind")
        XCTAssertEqual(GameState.stallSaid(.hourglass), "Take a Salt Hourglass for 60 merit")
        state.earnMerit(100, by: me)
        XCTAssertNil(state.stallRefusal(.hourglass, as: me))
        XCTAssertEqual(state.stallRefusal(.tome, as: me), .shortOfMerit(50))
        XCTAssertEqual(RuleError.shortOfMerit(50).description, "Short of 50 merit with your alliance.")
        XCTAssertEqual(state.stallRefusal(.hourglass, as: 2), .notInAlliance)

        let before = state.items(.mendingDraught, of: me)
        let events = try state.perform(.takeFromStall(.mendingDraught), as: me)
        XCTAssertEqual(events.first, .takenFromStall(house: me, item: .mendingDraught, merit: 80))
        XCTAssertEqual(state.items(.mendingDraught, of: me), before + 1)
        XCTAssertEqual(state.merit(of: me), 20)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "You take a Mending Draught from the alliance's stall for 80 merit; 20 left.")
        XCTAssertNil(state.tidings(of: events[0], for: ally))
        XCTAssertFalse(state.events(events, heardBy: ally).contains(events[0]), "Told to the House alone")
        XCTAssertThrowsError(try state.perform(.takeFromStall(.hourglass), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .shortOfMerit(40))
        }
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)

        // Merit never runs past the most kept.
        state.earnMerit(20_000, by: me)
        XCTAssertEqual(state.merit(of: me), GameState.mostMerit)
    }

    func testACommanderKnowsTheMeritAndWhatItReaches() throws {
        var (state, me, _) = try sworn()
        let id = try XCTUnwrap(state.commanders(of: me).first).id
        let named = try XCTUnwrap(state.alliance(of: me)).name
        let bare = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        XCTAssertTrue(bare.allianceReport.contains("Your merit with \(named): 0. It reaches nothing at the alliance's stall yet."),
                      bare.allianceReport)
        state.earnMerit(60, by: me)
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        XCTAssertTrue(counsel.allianceReport.contains("Your merit with \(named): 60. At the alliance's stall it would take any of: "
                                                      + "Salt Hourglass, Cache of Grain, Cache of Timber, Cache of Stone."),
                      counsel.allianceReport)
    }
}
