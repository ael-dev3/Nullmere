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

extension ExpeditionTests {
    func testALineWeighsTogetherAndStarsAStageByItsMargin() throws {
        var state = Scene.world("expedition lines", houses: 3)
        let me = state.player
        while state.commanders(of: me).count < 3 { _ = state.commanderJoins(me, why: "joins") }
        let line = Array(state.commanders(of: me).prefix(3).map(\.id))
        for id in line { state.commanders![state.commanderIndex(id)!].experience = Commander.experience(forLevel: 10) }
        XCTAssertEqual(state.refusal(of: .ventureLine(commanders: line + [line[0]], stage: nil), as: me), .lineTooLong(3))
        XCTAssertEqual(state.refusal(of: .ventureLine(commanders: [], stage: nil), as: me), .lineTooLong(3))
        XCTAssertEqual(state.refusal(of: .ventureLine(commanders: [line[0]], stage: 2), as: me), .expeditionsDone, "Not past its next stage")
        XCTAssertEqual(GameState.stars(weight: 150, against: 100), 3)
        XCTAssertEqual(GameState.stars(weight: 125, against: 100), 2)
        XCTAssertEqual(GameState.stars(weight: 100, against: 100), 1)
        XCTAssertNil(GameState.stars(weight: 99, against: 100))
        let events = try state.perform(.ventureLine(commanders: line, stage: nil), as: me)
        guard case .expedition(let result) = try XCTUnwrap(events.first) else { return XCTFail() }
        XCTAssertEqual(result.line, line)
        XCTAssertEqual(result.weight, line.reduce(0) { $0 + state.ringWeight(of: state.commander($1)!) }, "Weighed together")
        let stars = try XCTUnwrap(result.stars)
        XCTAssertEqual(state.expeditionStars(of: me, stage: 1), stars)
        XCTAssertNil(state.view(for: 1).expeditionBest?[me], "Its House's own")
        if stars == 3 { XCTAssertTrue(events.contains(.sculpturesFound(house: me, count: GameState.threeStarSculptures))) }
        let first = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(first.contains("line of 3"), first)
        let spoils = ExpeditionStage.stage(1)!.spoils
        XCTAssertTrue(first.hasSuffix(": \(spoils.listedSaid) to your stores."), first)
        guard case .expedition(let taken) = events[0] else { return XCTFail() }
        XCTAssertNil(taken.again, "Taken the first time")
        // A stage won may be sent at again, for more stars, but its stores come once.
        state.turnExpeditions()
        XCTAssertNil(state.refusal(of: .ventureLine(commanders: line, stage: 1), as: me))
        let grain = state.houses[me].stock.grain
        let again = try state.perform(.ventureLine(commanders: line, stage: 1), as: me)
        XCTAssertEqual(state.houses[me].stock.grain, grain, "No stores a second time")
        // And told so: not stores it never had.
        guard case .expedition(let retaken) = try XCTUnwrap(again.first) else { return XCTFail() }
        XCTAssertTrue(retaken.won, "The same line, the same stage, the same watch")
        XCTAssertEqual(retaken.again, true)
        let told = try XCTUnwrap(state.tidings(of: again[0], for: me)).text
        XCTAssertTrue(told.contains(" again, stage 1 of the Spine, "), told)
        XCTAssertTrue(told.hasSuffix(": its spoils were your House's the first time."), told)
        XCTAssertFalse(told.contains("to your stores"), told)
        XCTAssertEqual(state.expeditionStage(of: me), 1)
        XCTAssertEqual(state.problems(), [])
    }
}
