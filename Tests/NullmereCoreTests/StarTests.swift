import XCTest
@testable import NullmereCore

/// Commanders' stars: one to begin with, raised to five by sculptures won
/// breaking lairs and in the Ring; each star past the first strengthens
/// the company led and gives a talent point.
final class StarTests: XCTestCase {
    func testAStarIsRaisedForSculpturesAndStrengthensTheCompanyLed() throws {
        var state = Scene.world("stars", houses: 3)
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        XCTAssertEqual(commander.starCount, 1)
        XCTAssertEqual(Commander.sculpturesToRaise(from: 1), 10)
        XCTAssertEqual(Commander.sculpturesToRaise(from: 4), 80)
        XCTAssertNil(Commander.sculpturesToRaise(from: 5))
        XCTAssertEqual(state.refusal(of: .raiseStar(commander: commander.id), as: me), .needsSculptures(10))
        XCTAssertEqual(RuleError.needsSculptures(10).description, "Its next star takes 10 sculptures.")
        let theirs = try XCTUnwrap(state.commanders(of: 1).first)
        XCTAssertEqual(state.refusal(of: .raiseStar(commander: theirs.id), as: me), .unknownCommander)

        let found = state.giveSculptures(12, to: me)
        XCTAssertEqual(found, [.sculpturesFound(house: me, count: 12)])
        XCTAssertNotNil(state.tidings(of: found[0], for: me))
        XCTAssertEqual(state.events(found, heardBy: 1), [], "A House's sculptures are its own")
        XCTAssertNil(state.view(for: 1).sculptureCounts?[me])
        XCTAssertEqual(state.view(for: me).sculptureCounts?[me], 12)

        let before = (attack: commander.edge(.attack), defense: commander.edge(.defense), points: commander.talentPoints)
        let events = try state.perform(.raiseStar(commander: commander.id), as: me)
        XCTAssertEqual(events, [.commanderStarred(commander: commander.id, house: me, stars: 2)])
        let raised = try XCTUnwrap(state.commander(commander.id))
        XCTAssertEqual(raised.starCount, 2)
        XCTAssertEqual(state.sculptures(of: me), 2)
        XCTAssertEqual(raised.edge(.attack), before.attack + Commander.starEdge)
        XCTAssertEqual(raised.edge(.defense), before.defense + Commander.starEdge)
        XCTAssertEqual(raised.talentPoints, before.points + 1, "A talent point more")
        XCTAssertGreaterThan(state.ringWeight(of: raised), state.ringWeight(of: commander), "It weighs more in the Ring")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "\(raised.name) rises to 2 stars.")
        XCTAssertEqual(state.refusal(of: .raiseStar(commander: commander.id), as: me), .needsSculptures(20))

        // To five, and no more.
        _ = state.giveSculptures(20 + 40 + 80, to: me)
        for _ in 0..<3 { _ = try state.perform(.raiseStar(commander: commander.id), as: me) }
        XCTAssertEqual(state.commander(commander.id)?.starCount, Commander.mostStars)
        XCTAssertEqual(state.refusal(of: .raiseStar(commander: commander.id), as: me), .starsFull)
        XCTAssertEqual(state.problems(), [])
    }

    func testStewardsSetTheirSculpturesForTheirHighestCommander() throws {
        var state = Scene.world("stewards' stars", houses: 3)
        let steward = 1
        _ = state.giveSculptures(35, to: steward)
        let events = state.raiseStars(for: steward)
        XCTAssertEqual(events.count, 2, "Two stars: 10 and 20")
        XCTAssertEqual(state.sculptures(of: steward), 5)
        XCTAssertEqual(state.commanders(of: steward).map(\.starCount).max(), 3)
    }

    func testTheRingsHonouredWinSculptures() throws {
        XCTAssertEqual(GameState.ringSculptures.count, GameState.ringHonours.count, "One for each honoured")
        XCTAssertEqual(GameState.ringSculptures, GameState.ringSculptures.sorted(by: >), "The first the most")
    }
}
