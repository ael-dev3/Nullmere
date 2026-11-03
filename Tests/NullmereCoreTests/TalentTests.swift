import Foundation
import XCTest
@testable import NullmereCore

/// A commander's talents: a point at each level past the first, spent a
/// rank at a time in three trees of eight, a root branching in two to a
/// deep crown, each rank giving its edge again to the company it leads;
/// forgotten all at once, for moonsalt, to learn anew.
final class TalentTests: XCTestCase {
    /// A keeper's House, its commander raised to a level and of an
    /// archetype, at the head of the House's Spears.
    private func world(level: Int, archetype: Archetype = .vanguard) throws -> (GameState, me: Int, commander: Int, spear: Int) {
        var state = Scene.world("talents")
        let me = state.player
        let id = try XCTUnwrap(state.commanders(of: me).first).id
        let old = state.commanders![id - 1]
        var made = Commander(id: id, name: old.name, archetype: archetype, owner: me)
        made.experience = Commander.experience(forLevel: level)
        state.commanders![id - 1] = made
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        state.units[try XCTUnwrap(state.unitIndex(spear.id))].leader = id
        return (state, me, id, spear.id)
    }

    private func refusal(_ command: Command, in state: GameState, as house: Int) -> RuleError? {
        state.refusal(of: command, as: house)
    }

    /// The tree a commander has learned most in leads it, and is what its
    /// company shows on the march; ties go to the tree written first.
    func testACommandersLeadingTreeIsTheOneItLearnedMostIn() {
        var commander = Commander(id: 1, name: "Ves", archetype: Archetype.allCases[0], owner: 0)
        XCTAssertNil(commander.leadingTree, "Untaught")
        commander.talents = [.keenEdge, .thickHide]
        XCTAssertEqual(commander.leadingTree?.tree, .steel, "A tie goes to the first")
        commander.talents = [.keenEdge, .thickHide, .thickHide, .keenEyes]
        XCTAssertEqual(commander.leadingTree?.tree, .ward)
        XCTAssertEqual(commander.leadingTree?.ranks, 4)
    }

    func testThreeTreesOfEightEachARootTwoBranchesAndADeepCrown() {
        XCTAssertEqual(TalentTree.allCases.map(\.title), ["Steel", "Ward", "Road"])
        XCTAssertEqual(Talent.allCases.count, 24)
        for tree in TalentTree.allCases {
            let t = tree.talents
            XCTAssertEqual(t.count, 8)
            XCTAssertEqual(t[0].openers, [], "The root opens itself")
            XCTAssertEqual(t[1].openers, [t[0]], "Each branch grows from the root")
            XCTAssertEqual(t[3].openers, [t[0]])
            XCTAssertEqual(t[2].openers, [t[1]])
            XCTAssertEqual(t[4].openers, [t[3]])
            XCTAssertEqual(t[5].openers, [t[1], t[3]], "The deep talent from either branch")
            XCTAssertEqual(t[6].openers, [t[5]])
            XCTAssertEqual(t[7].openers, [t[6]])
            XCTAssertEqual(t.map(\.branch), [nil, 0, 0, 1, 1, nil, nil, nil])
            XCTAssertEqual(t.map(\.treePointsNeeded), [0, 0, 0, 0, 0, 6, 10, 16])
            XCTAssertEqual(t[7].ranks, 1, "Its crown a single rank")
            for (place, talent) in t.enumerated() {
                XCTAssertEqual(talent.tree, tree)
                XCTAssertEqual(talent.place, place)
                XCTAssertTrue((1...3).contains(talent.ranks))
                XCTAssertFalse(talent.title.isEmpty)
                XCTAssertFalse(talent.effect.isEmpty)
            }
            // A crown can be reached with a commander's points: its tree
            // holds enough ranks before it.
            XCTAssertGreaterThanOrEqual(t.prefix(7).reduce(0) { $0 + $1.ranks }, t[7].treePointsNeeded)
            XCTAssertFalse(tree.branches.0.isEmpty || tree.branches.1.isEmpty)
        }
        XCTAssertEqual(Set(Talent.allCases.map(\.title)).count, 24, "Each its own name")
        XCTAssertTrue(Talent.allCases.filter { $0 != .battleRage }.allSatisfy { !$0.edges.isEmpty }, "Every rank gives an edge, Battle Rage its fury")
        let ranks = Talent.allCases.reduce(0) { $0 + $1.ranks }
        XCTAssertEqual(ranks, 57)
        let trees = TalentTree.allCases.map { $0.talents.reduce(0) { $0 + $1.ranks } }.sorted(by: >)
        XCTAssertGreaterThan(Commander.highestLevel - 1, trees[0], "At its highest level a commander fills one tree")
        XCTAssertLessThan(Commander.highestLevel - 1, trees[0] + trees[1], "but never two: a choice to make")
        for archetype in Archetype.allCases {
            XCTAssertEqual(Set(Talent.path(for: archetype)), Set(TalentTree.allCases))
        }
    }

    func testADeepTalentWaitsOnPointsSpentInItsTreeAndACrownOnSixteen() throws {
        var (state, me, commander, _) = try world(level: 4)
        state.commanders![commander - 1].experience = Commander.experience(forLevel: Commander.highestLevel)
        for _ in 0..<3 { try state.perform(.learnTalent(commander: commander, talent: .keenEdge), as: me) }
        try state.perform(.learnTalent(commander: commander, talent: .rammingDrill), as: me)
        XCTAssertEqual(refusal(.learnTalent(commander: commander, talent: .bloodedSteel), in: state, as: me), .needsTreePoints(.steel, 6),
                       "Its branch learned, but too little of the tree")
        XCTAssertEqual(RuleError.needsTreePoints(.steel, 6).description, "Needs 6 points spent in Steel first.")
        // Points in another tree don't open it.
        for _ in 0..<3 { try state.perform(.learnTalent(commander: commander, talent: .thickHide), as: me) }
        XCTAssertEqual(refusal(.learnTalent(commander: commander, talent: .bloodedSteel), in: state, as: me), .needsTreePoints(.steel, 6))
        for _ in 0..<2 { try state.perform(.learnTalent(commander: commander, talent: .rammingDrill), as: me) }
        try state.perform(.learnTalent(commander: commander, talent: .bloodedSteel), as: me)
        XCTAssertEqual(refusal(.learnTalent(commander: commander, talent: .battleRage), in: state, as: me), .needsTreePoints(.steel, 10))
        for _ in 0..<3 { try state.perform(.learnTalent(commander: commander, talent: .sapperCraft), as: me) }
        try state.perform(.learnTalent(commander: commander, talent: .battleRage), as: me)
        XCTAssertEqual(refusal(.learnTalent(commander: commander, talent: .moonsteel), in: state, as: me), .needsTreePoints(.steel, 16))
        for _ in 0..<2 { try state.perform(.learnTalent(commander: commander, talent: .bloodedSteel), as: me) }
        for _ in 0..<3 { try state.perform(.learnTalent(commander: commander, talent: .huntersMark), as: me) }
        XCTAssertEqual(state.commander(commander)?.spent(in: .steel), 16)
        let before = try XCTUnwrap(state.commander(commander)).edge(.attack)
        try state.perform(.learnTalent(commander: commander, talent: .moonsteel), as: me)
        XCTAssertEqual(try XCTUnwrap(state.commander(commander)).edge(.attack), before + 8, "Its crown")
        XCTAssertEqual(state.problems(), [])
    }

    func testAPointAtEachLevelSpentARankAtATime() throws {
        var (state, me, commander, spear) = try world(level: 4)
        XCTAssertEqual(state.commander(commander)?.talentPoints, 3)
        XCTAssertEqual(state.commander(commander)?.pointsLeft, 3)
        let attack = state.bonus(.attack(.spear), for: try XCTUnwrap(state.unit(spear)))

        XCTAssertEqual(refusal(.learnTalent(commander: commander, talent: .huntersMark), in: state, as: me), .needsTalent(.keenEdge))
        XCTAssertEqual(RuleError.needsTalent(.keenEdge).description, "Needs Keen Edge first.")
        XCTAssertEqual(refusal(.learnTalent(commander: 999, talent: .keenEdge), in: state, as: me), .unknownCommander)
        let theirs = try XCTUnwrap(state.commanders(of: 1).first).id
        XCTAssertEqual(refusal(.learnTalent(commander: theirs, talent: .keenEdge), in: state, as: me), .unknownCommander)

        let events = try state.perform(.learnTalent(commander: commander, talent: .keenEdge), as: me)
        XCTAssertEqual(events, [.talentLearned(commander: commander, house: me, talent: .keenEdge, rank: 1)])
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "\(try XCTUnwrap(state.commander(commander)).name) learns Keen Edge I.")
        XCTAssertNil(state.tidings(of: events[0], for: 1))
        XCTAssertEqual(state.events(events, heardBy: 1), [], "A House's commanders' talents are its own to know")
        XCTAssertEqual(state.events(events, heardBy: me), events)
        try state.perform(.learnTalent(commander: commander, talent: .keenEdge), as: me)
        XCTAssertEqual(state.bonus(.attack(.spear), for: try XCTUnwrap(state.unit(spear))), attack + 4, "Two ranks, two edges")
        try state.perform(.learnTalent(commander: commander, talent: .huntersMark), as: me)
        XCTAssertEqual(state.commander(commander)?.rank(of: .keenEdge), 2)
        XCTAssertEqual(state.commander(commander)?.edge(.hunting), 5)
        XCTAssertEqual(state.commander(commander)?.pointsLeft, 0)
        XCTAssertEqual(refusal(.learnTalent(commander: commander, talent: .keenEdge), in: state, as: me), .noTalentPoints)
        XCTAssertEqual(RuleError.noTalentPoints.description, "That commander has no talent point left; it gains one at each level.")

        // A level more, a point more; a talent at its last rank is done.
        state.commanders![commander - 1].experience = Commander.experience(forLevel: 5)
        try state.perform(.learnTalent(commander: commander, talent: .keenEdge), as: me)
        XCTAssertEqual(refusal(.learnTalent(commander: commander, talent: .keenEdge), in: state, as: me), .talentMastered)
        let board = try XCTUnwrap(state.commander(commander)).talentTrees
        XCTAssertEqual(board.map(\.tree), TalentTree.allCases)
        XCTAssertEqual(board.map(\.spent), [4, 0, 0])
        XCTAssertEqual(board[0].lines.map(\.rank), [3, 1, 0, 0, 0, 0, 0, 0])
        XCTAssertTrue(board[0].lines[0].isMastered)
        XCTAssertEqual(board[0].lines[2].refusal, .noTalentPoints, "Open, but no point to spend")
        XCTAssertEqual(board[0].lines[3].refusal, .noTalentPoints, "The other branch, open from the root")
        XCTAssertEqual(board[0].lines[4].refusal, .needsTalent(.rammingDrill), "Shut until the one before is learned")
        XCTAssertEqual(board[1].lines[0].refusal, .noTalentPoints)
        XCTAssertEqual(state.problems(), [])
    }

    func testTalentsStrengthenTheCompanyLedAndRageHastensTheFury() throws {
        var (state, me, commander, spear) = try world(level: 30, archetype: .vanguard)
        let unit = try XCTUnwrap(state.unit(spear))
        let before = (attack: state.bonus(.attack(.spear), for: unit), defense: state.bonus(.defense(.spear), for: unit),
                      moves: state.movement(of: unit), sight: state.bonus(.sight, for: unit))
        XCTAssertEqual(try XCTUnwrap(state.commander(commander)).cadence, Skill.fellCharge.cadence)
        // Deep into Steel and Ward, each to its tenth point and past, and
        // Road to its sixth: every point a commander at its highest has.
        for talent in [Talent.keenEdge, .keenEdge, .keenEdge, .huntersMark, .rammingDrill, .rammingDrill, .rammingDrill,
                       .bloodedSteel, .bloodedSteel, .bloodedSteel, .battleRage,
                       .thickHide, .thickHide, .thickHide, .fieldSurgeon, .gatewarden, .gatewarden, .gatewarden,
                       .ironRanks, .ironRanks, .ironRanks, .unbroken,
                       .keenEyes, .gleanersHand, .gleanersHand, .gleanersHand, .deepSaddlebags, .deepSaddlebags, .longStride] {
            try state.perform(.learnTalent(commander: commander, talent: talent), as: me)
        }
        let led = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(state.bonus(.attack(.spear), for: led), before.attack + 6 + 9 + 3)
        XCTAssertEqual(state.bonus(.defense(.spear), for: led), before.defense + 6 + 9 + 6)
        XCTAssertEqual(state.movement(of: led), before.moves + 1, "Long Stride: a move further")
        XCTAssertEqual(state.bonus(.sight, for: led), before.sight + 1)
        XCTAssertEqual(state.bonus(.healing, for: led) - state.bonus(.healing, for: me), 2, "Field Surgeon")
        XCTAssertEqual(try XCTUnwrap(state.commander(commander)).cadence, Skill.fellCharge.cadence - 1, "Battle Rage: a battle sooner")
        state.commanders![commander - 1].fury = Skill.fellCharge.cadence - 2
        XCTAssertEqual(state.furyReady(of: led), .fellCharge, "Ready a battle sooner")
        XCTAssertEqual(state.commander(commander)?.pointsLeft, 0)
    }

    func testTalentsForgottenForMoonsaltToLearnAnew() throws {
        var (state, me, commander, _) = try world(level: 6)
        XCTAssertEqual(refusal(.forgetTalents(commander: commander), in: state, as: me), .nothingToForget)
        XCTAssertEqual(RuleError.nothingToForget.description, "That commander has learned no talents.")
        for talent in [Talent.thickHide, .thickHide, .fieldSurgeon] {
            try state.perform(.learnTalent(commander: commander, talent: talent), as: me)
        }
        state.houses[me].stock.moonsalt = 5
        XCTAssertEqual(refusal(.forgetTalents(commander: commander), in: state, as: me), .shortOf(Stock(moonsalt: 15)))
        state.houses[me].stock.moonsalt = 30
        let events = try state.perform(.forgetTalents(commander: commander), as: me)
        XCTAssertEqual(events, [.talentsForgotten(commander: commander, house: me)])
        XCTAssertEqual(state.houses[me].stock.moonsalt, 10)
        XCTAssertEqual(state.commander(commander)?.talents, [])
        XCTAssertEqual(state.commander(commander)?.pointsLeft, 5, "Every point back")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "\(try XCTUnwrap(state.commander(commander)).name) forgets their talents, to learn them anew.")
        XCTAssertEqual(state.events(events, heardBy: 2), [])
    }

    func testStewardsSpendTheirPointsAlongTheirArchetypesTrees() throws {
        var state = Scene.world("steward talents", houses: 3)
        let steward = 1
        let id = try XCTUnwrap(state.commanders(of: steward).first).id
        state.commanders![id - 1].experience = Commander.experience(forLevel: 8)
        let archetype = try XCTUnwrap(state.commander(id)).archetype
        let events = state.growTalents(for: steward)
        let grown = try XCTUnwrap(state.commander(id))
        XCTAssertEqual(grown.pointsLeft, 0, "Every point spent")
        XCTAssertEqual(events.count, 7)
        let first = Talent.path(for: archetype)[0].talents
        XCTAssertEqual(grown.rank(of: first[0]), first[0].ranks, "Its first tree's first talent to its last rank")
        XCTAssertTrue(grown.talentTrees.first { $0.tree == Talent.path(for: archetype)[0] }!.spent >= 5)
        XCTAssertEqual(state.growTalents(for: steward), [], "Nothing left to spend")

        // And in their turn among the stewards.
        state.commanders![id - 1].experience = Commander.experience(forLevel: 9)
        state.stewardTurn(for: steward)
        XCTAssertEqual(state.commander(id)?.pointsLeft, 0)
        XCTAssertEqual(state.problems(), [])
    }

    func testTalentsAreKeptAndOlderSavesHaveNone() throws {
        var (state, me, commander, _) = try world(level: 3)
        try state.perform(.learnTalent(commander: commander, talent: .keenEyes), as: me)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["talents"], in: state))
        XCTAssertNil(older.commander(commander)?.talents)
        XCTAssertEqual(older.commander(commander)?.pointsLeft, 2)
        XCTAssertEqual(older.commander(commander)?.edge(.sight), 0)
    }
}
