import XCTest
@testable import NullmereCore

/// Expeditions up the Spine: a commander sent at its House's next stage
/// once a watch, weighed against the stage's host.
final class ExpeditionTests: XCTestCase {
    func testTwelveStagesEachHarderTheThirdsWithSculptures() {
        XCTAssertNil(ExpeditionStage.stage(0))
        XCTAssertNil(ExpeditionStage.stage(ExpeditionStage.count + 1))
        let stages = (1...ExpeditionStage.count).compactMap(ExpeditionStage.stage)
        XCTAssertEqual(stages.count, 12)
        XCTAssertEqual(stages.map(\.strength), stages.map(\.strength).sorted(), "Each harder than the last")
        XCTAssertEqual(Set(stages.map(\.name)).count, 12)
        XCTAssertEqual(stages.filter { $0.sculptures > 0 }.map(\.number), [3, 6, 9, 12])
        for number in 1...12 {
            XCTAssertTrue((-10...10).contains(GameState.expeditionSwing(house: 3, stage: number, watch: 40)))
        }
    }

    func testACommanderTakesAStageOrComesHomeWoundedOnceAWatch() throws {
        var state = Scene.world("expeditions", houses: 3)
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        XCTAssertEqual(state.expeditionStage(of: me), 0)
        // A strong commander takes the first stage.
        state.commanders![commander - 1].experience = Commander.experience(forLevel: 12)
        let before = state.houses[me].stock
        let events = try state.perform(.venture(commander: commander), as: me)
        guard case .expedition(let result) = try XCTUnwrap(events.first) else { return XCTFail("\(events)") }
        XCTAssertTrue(result.won, "\(result)")
        XCTAssertEqual(state.expeditionStage(of: me), 1)
        XCTAssertGreaterThan(state.houses[me].stock.grain, before.grain, "The stage's stores")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.tone, .good)
        XCTAssertNil(state.tidings(of: events[0], for: 1))
        XCTAssertEqual(state.events(events, heardBy: 1), [], "Its House's alone")
        XCTAssertNil(state.view(for: 1).expeditions?[me])
        XCTAssertEqual(state.refusal(of: .venture(commander: commander), as: me), .venturedThisWatch)
        XCTAssertEqual(RuleError.venturedThisWatch.description, "Your House has sent an expedition this watch already.")
        XCTAssertEqual(state.refusal(of: .venture(commander: commander), as: 1), .unknownCommander)
        // A weak commander at a far stage is thrown back, wounded.
        state.turnExpeditions()
        state.expeditions![me] = 10
        state.commanders![commander - 1].experience = 0
        let lost = try state.perform(.venture(commander: commander), as: me)
        guard case .expedition(let failed) = try XCTUnwrap(lost.first) else { return XCTFail() }
        XCTAssertFalse(failed.won)
        XCTAssertEqual(state.expeditionStage(of: me), 10, "No stage taken")
        XCTAssertEqual(state.tidings(of: lost[0], for: me)?.tone, .bad)
        state.turnExpeditions()
        XCTAssertEqual(state.refusal(of: .venture(commander: commander), as: me), .commanderWounded(state.watch + 1))
        XCTAssertEqual(state.problems(), [])
    }

    func testAThirdStageBringsSculptures() throws {
        var state = Scene.world("expedition sculptures", houses: 3)
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        state.commanders![commander - 1].experience = Commander.experience(forLevel: Commander.highestLevel)
        state.expeditions = [me: 2]
        let events = try state.perform(.venture(commander: commander), as: me)
        XCTAssertTrue(events.contains(.sculpturesFound(house: me, count: ExpeditionStage.stage(3)!.sculptures)), "\(events)")
    }
}
