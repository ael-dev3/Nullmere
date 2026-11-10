import XCTest
@testable import NullmereCore

/// A commander in counsel knows themself as the Commanders board tells it,
/// their level, stars, talents and gear, and may put forward for themself
/// only what the rules would take: a talent's next rank, a piece of the
/// House's gear, a star raised with its sculptures; told why not otherwise.
final class CommanderSelfTests: XCTestCase {
    /// A keeper's House with one commander of level 4 who has learned Thick
    /// Hide twice, a point left to spend; a second commander; and gear: a
    /// blade the first wears, a charm unworn, and plate the second wears.
    private func scene() throws -> (state: GameState, me: Int, id: Int, other: Int) {
        var state = Scene.world("know thyself", houses: 4, radius: 18)
        let me = state.player
        let id = try XCTUnwrap(state.commanders(of: me).first).id
        let index = try XCTUnwrap(state.commanderIndex(id))
        state.commanders![index].experience = Commander.experience(forLevel: 4) + 30
        state.commanders![index].talents = [.thickHide, .thickHide]
        let other = (state.commanders ?? []).map(\.id).max()! + 1
        state.commanders!.append(Commander(id: other, name: "Corwen Ashby", archetype: .vanguard, owner: me))
        state.armoury = [Gear(id: 9_001, kind: .wardensBlade, quality: .fine, owner: me, wornBy: id),
                         Gear(id: 9_002, kind: .huntersEye, quality: .masterwork, owner: me),
                         Gear(id: 9_003, kind: .barrowPlate, quality: .plain, owner: me, wornBy: other)]
        return (state, me, id, other)
    }

    func testACommanderKnowsTheirLevelStarsTalentsAndGear() throws {
        let (state, me, id, _) = try scene()
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        let more = Commander.experience(forLevel: 5) - (Commander.experience(forLevel: 4) + 30)
        XCTAssertEqual(counsel.standingSaid, "You are of level 4, \(more) experience from level 5, with 1 star; 1 talent point yet to spend.")
        XCTAssertTrue(counsel.briefing.contains(counsel.standingSaid), "Briefed with it")
        XCTAssertTrue(counsel.instructions.contains("at yourself (your talents, stars and gear)"))

        let report = counsel.selfReport
        XCTAssertTrue(report.hasPrefix(counsel.standingSaid), report)
        XCTAssertTrue(report.contains("Stars: 1 of 5 · Next star: 10 sculptures, 0 kept."), report)
        XCTAssertTrue(report.contains("Your talents: Thick Hide II."), report)
        // Each root, and the two Thick Hide opens, each with what it gives.
        let open = [Talent.keenEdge, .thickHide, .fieldSurgeon, .gatewarden, .keenEyes]
        let commander = try XCTUnwrap(state.commander(id))
        XCTAssertEqual(Talent.allCases.filter { commander.learnRefusal(of: $0) == nil }, open)
        XCTAssertTrue(report.contains("Talents you may learn now: Keen Edge I (\(Talent.keenEdge.effect)); Thick Hide III (+2% defence a rank); "),
                      report)
        let blade = try XCTUnwrap(state.gear(9_001)), charm = try XCTUnwrap(state.gear(9_002))
        XCTAssertTrue(report.contains("You wear: \(blade.wornSaid) (\(blade.effect))."), report)
        XCTAssertTrue(report.contains("Your House's armoury holds, unworn: \(charm.keptSaid) (\(charm.effect))."), report)
        XCTAssertFalse(report.contains("Barrowplate"), "Another's worn piece is not the armoury's unworn")

        // Nothing learned, no gear and no point left: told so plainly.
        var bare = state
        let index = try XCTUnwrap(bare.commanderIndex(id))
        bare.commanders![index].experience = 0
        bare.commanders![index].talents = nil
        bare.armoury = []
        let plain = try XCTUnwrap(CommanderCounsel(state: bare, player: me, commander: id))
        XCTAssertEqual(plain.standingSaid, "You are of level 1, 50 experience from level 2, with 1 star; no talent point yet to spend.")
        XCTAssertTrue(plain.selfReport.contains("You have learned no talent yet."), plain.selfReport)
        XCTAssertFalse(plain.selfReport.contains("Talents you may learn now"), plain.selfReport)
        XCTAssertTrue(plain.selfReport.contains("You wear no gear. Your House's armoury holds no piece unworn."), plain.selfReport)
    }

    func testACommanderPutsForwardATalentGearOrAStarAsTheRulesWeighThem() throws {
        var (state, me, id, other) = try scene()
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        let name = counsel.commander.name
        // A talent by its name, with or without its next rank's numeral.
        for asked in ["Thick Hide", "thick hide III", "the Thick Hide"] {
            let learn = counsel.proposeForSelf("learn", what: asked)
            XCTAssertEqual(learn.command, .learnTalent(commander: id, talent: .thickHide), asked)
            XCTAssertNil(learn.why, asked)
            XCTAssertEqual(learn.told, "\(name) learns Thick Hide III.")
            XCTAssertEqual(learn.line, "LEARN Thick Hide III")
        }
        let deep = counsel.proposeForSelf("learn", what: "Moonsteel")
        XCTAssertEqual(deep.why, state.refusal(of: .learnTalent(commander: id, talent: .moonsteel), as: me)?.description)
        XCTAssertNotNil(deep.why, "Not opened yet: the realm's own words")
        XCTAssertEqual(counsel.proposeForSelf("learn", what: "Dragonfire").why, "No talent goes by the name Dragonfire.")

        // A piece of the House's gear: from the armoury, or from another
        // commander, said so; not what they wear already.
        let charm = counsel.proposeForSelf("wear", what: "Hunter's Eye")
        XCTAssertEqual(charm.command, .wear(gear: 9_002, commander: id))
        XCTAssertNil(charm.why)
        XCTAssertEqual(charm.told, "\(name) takes up the Masterwork Hunter's Eye.")
        let plate = counsel.proposeForSelf("wear", what: "Plain Barrowplate")
        XCTAssertEqual(plate.command, .wear(gear: 9_003, commander: id))
        XCTAssertEqual(plate.told, "\(name) takes up the Plain Barrowplate, taken from Corwen Ashby.")
        XCTAssertEqual(counsel.proposeForSelf("wear", what: "Fine Warden's Blade").why, RuleError.alreadyWorn.description)
        XCTAssertEqual(counsel.proposeForSelf("wear", what: "Moonblade").why, "Your House holds no gear by the name Moonblade.")

        // A star with the House's sculptures, refused until it keeps them.
        let star = counsel.proposeForSelf("star", what: "")
        XCTAssertEqual(star.command, .raiseStar(commander: id))
        XCTAssertEqual(star.why, RuleError.needsSculptures(10).description)
        XCTAssertEqual(star.told, "\(name) is raised to 2 stars for 10 sculptures.")
        XCTAssertEqual(counsel.proposeForSelf("dance", what: "a jig").why, CommanderCounsel.onlyTheseForSelf)
        XCTAssertEqual(CommanderCounsel.ownActions, ["learn", "wear", "star", "read"])

        // Given, the rules carry each out, and the commander knows it after.
        state.sculptureCounts = [me: 10]
        let rich = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        for proposal in [rich.proposeForSelf("learn", what: "Thick Hide"), rich.proposeForSelf("wear", what: "Plain Barrowplate"),
                         rich.proposeForSelf("raise a star", what: "")] {
            XCTAssertNil(proposal.why, proposal.told)
            _ = try state.perform(try XCTUnwrap(proposal.command), as: me)
        }
        let after = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        XCTAssertEqual(after.commander.rank(of: .thickHide), 3)
        XCTAssertEqual(after.commander.starCount, 2)
        XCTAssertEqual(state.gear(9_003)?.wornBy, id)
        XCTAssertTrue(state.worn(by: other).isEmpty)
        XCTAssertTrue(after.selfReport.contains("Your talents: Thick Hide III."), after.selfReport)
        XCTAssertTrue(after.selfReport.contains("Stars: 2 of 5 · Next star: 20 sculptures, 0 kept."), after.selfReport)
        XCTAssertTrue(after.standingSaid.hasSuffix("with 2 stars; 1 talent point yet to spend."), "A star gives a point: \(after.standingSaid)")
    }
}
