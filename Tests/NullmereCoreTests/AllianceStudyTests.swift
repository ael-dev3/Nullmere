import Foundation
import XCTest
@testable import NullmereCore

/// Alliance studies: its leader chooses one, its Houses give stores toward
/// each grade, and each grade learned raises every House of the alliance;
/// every so much given brings the giver an hourglass.
final class AllianceStudyTests: XCTestCase {
    private struct Stage {
        var state: GameState
        let me: Int
        let ally: Int
        let alliance: Int
    }

    private func staged(_ seed: String = "alliance studies") throws -> Stage {
        var state = Scene.world(seed, houses: 4, radius: 16)
        let me = state.player, ally = 1
        _ = try state.perform(.foundAlliance(name: "The Long Table"), as: me)
        state.houses[ally].isPlayer = true
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: alliance, accept: true), as: ally)
        for house in [me, ally] {
            state.houses[house].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 60)
            // Of a people whose strengths touch none of the alliance's studies.
            state.houses[house].heritage = .saltborn
        }
        return Stage(state: state, me: me, ally: ally, alliance: alliance)
    }

    func testAnAllianceLearnsTogetherWhatItsHousesGiveFor() throws {
        var stage = try staged()
        let me = stage.me, ally = stage.ally
        XCTAssertThrowsError(try stage.state.perform(.giveToAlliance(Stock(grain: 10)), as: ally)) {
            XCTAssertEqual($0 as? RuleError, .noAllianceStudy, "Nothing pursued yet")
        }
        XCTAssertThrowsError(try stage.state.perform(.pursueAllianceStudy(.fieldcraft), as: ally)) {
            XCTAssertEqual($0 as? RuleError, .notAllianceLeader)
        }
        let chosen = try stage.state.perform(.pursueAllianceStudy(.fieldcraft), as: me)
        XCTAssertEqual(chosen, [.allianceStudyChosen(alliance: stage.alliance, study: .fieldcraft)])
        XCTAssertThrowsError(try stage.state.perform(.pursueAllianceStudy(.fieldcraft), as: me)) {
            XCTAssertEqual($0 as? RuleError, .alreadyPursued)
        }
        // Each gives part; the grade is learned once the two together pay it.
        let cost = AllianceStudy.fieldcraft.cost(grade: 1)
        let gathering = stage.state.bonus(.gathering, for: ally)
        let others = stage.state.bonus(.gathering, for: 2)
        let half = Stock(grain: cost.grain / 2, timber: cost.timber / 2, stone: cost.stone / 2)
        XCTAssertEqual(try stage.state.perform(.giveToAlliance(half), as: me),
                       [.allianceGift(house: me, alliance: stage.alliance, stock: half, study: .fieldcraft, grade: 1)])
        XCTAssertEqual(stage.state.bonus(.gathering, for: ally), gathering, "Not yet learned")
        let rest = Stock(grain: cost.grain - half.grain, timber: cost.timber - half.timber, stone: cost.stone - half.stone)
        let learned = try stage.state.perform(.giveToAlliance(rest), as: ally)
        XCTAssertEqual(learned.prefix(2), [.allianceGift(house: ally, alliance: stage.alliance, stock: rest, study: .fieldcraft, grade: 1),
                                           .allianceStudied(alliance: stage.alliance, study: .fieldcraft, grade: 1)])
        let lore = try XCTUnwrap(stage.state.alliance(of: me)?.lore)
        XCTAssertEqual(lore.grade(of: .fieldcraft), 1)
        XCTAssertEqual(lore.given, .zero)
        XCTAssertEqual(lore.next?.grade, 2, "Still pursued, at its next grade")
        XCTAssertEqual(stage.state.bonus(.gathering, for: ally), gathering + 5, "Every House of the alliance is raised")
        XCTAssertEqual(stage.state.bonus(.gathering, for: me), stage.state.bonus(.gathering, for: ally))
        XCTAssertEqual(stage.state.bonus(.gathering, for: 2), others, "Not another House")
        XCTAssertTrue(stage.state.chronicle.contains { $0.text == "The Long Table learns Fieldcraft I together." })
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testWhatIsGivenIsChecked() throws {
        var stage = try staged("gifts checked")
        _ = try stage.state.perform(.pursueAllianceStudy(.oathOfSteel), as: stage.me)
        XCTAssertThrowsError(try stage.state.perform(.giveToAlliance(.zero), as: stage.me)) {
            XCTAssertEqual($0 as? RuleError, .nothingGiven)
        }
        XCTAssertThrowsError(try stage.state.perform(.giveToAlliance(Stock(grain: -5, timber: 20)), as: stage.me)) {
            XCTAssertEqual($0 as? RuleError, .nothingGiven)
        }
        XCTAssertThrowsError(try stage.state.perform(.giveToAlliance(Stock(moonsalt: 500)), as: stage.me)) {
            XCTAssertEqual($0 as? RuleError, .shortOf(Stock(moonsalt: 440)))
        }
        XCTAssertThrowsError(try stage.state.perform(.giveToAlliance(Stock(grain: 5)), as: 3)) {
            XCTAssertEqual($0 as? RuleError, .notInAlliance)
        }
        XCTAssertThrowsError(try stage.state.perform(.pursueAllianceStudy(.oathOfSteel), as: 3)) {
            XCTAssertEqual($0 as? RuleError, .notInAlliance)
        }
        XCTAssertEqual(RuleError.noAllianceStudy.description, "Your alliance pursues no study: its leader chooses one in the Alliance screen.")
        XCTAssertEqual(RuleError.nothingGiven.description, "Give some of your stores, and none of them less than nothing.")
    }

    func testAStudyIsMasteredAtItsThirdGradeAndGiftsBringHourglasses() throws {
        var stage = try staged("studies mastered")
        let me = stage.me
        _ = try stage.state.perform(.pursueAllianceStudy(.shieldOath), as: me)
        let defence = stage.state.bonus(.defense(.rider), for: stage.ally)
        // Enough for every grade at once: each is learned in turn.
        let all = (1...AllianceStudy.grades).reduce(Stock.zero) { $0 + AllianceStudy.shieldOath.cost(grade: $1) }
        stage.state.houses[me].stock = all + Stock(grain: 10)
        let events = try stage.state.perform(.giveToAlliance(all), as: me)
        XCTAssertEqual(events.filter { if case .allianceStudied = $0 { return true } else { return false } },
                       (1...3).map { .allianceStudied(alliance: stage.alliance, study: .shieldOath, grade: $0) })
        let lore = try XCTUnwrap(stage.state.alliance(of: me)?.lore)
        XCTAssertNil(lore.pursuit, "Mastered, it is pursued no more")
        XCTAssertEqual(stage.state.bonus(.defense(.rider), for: stage.ally), defence + 9)
        XCTAssertThrowsError(try stage.state.perform(.pursueAllianceStudy(.shieldOath), as: me)) {
            XCTAssertEqual($0 as? RuleError, .allianceStudyMastered)
        }
        // The giver's hourglasses, one for every 300 given in barter worth.
        let worth = Resource.allCases.reduce(0) { $0 + all[$1] * $1.worth }
        XCTAssertEqual(lore.given(by: me), worth)
        XCTAssertTrue(events.contains(.itemsGiven(house: me, kind: .hourglass, count: worth / GameState.givenPerHourglass)))
        XCTAssertEqual(stage.state.items(.hourglass, of: me), worth / GameState.givenPerHourglass)
    }

    func testAnAlliancesStudiesAreItsOwnToKnowAndAreTold() throws {
        var stage = try staged("studies told")
        let me = stage.me
        let chosen = try stage.state.perform(.pursueAllianceStudy(.masonsCompact), as: me)
        let gift = try stage.state.perform(.giveToAlliance(Stock(grain: 40)), as: stage.ally)
        XCTAssertEqual(stage.state.events(chosen + gift, heardBy: me), chosen + gift, "Its Houses hear it")
        XCTAssertEqual(stage.state.events(chosen + gift, heardBy: 2), [], "Others don't")
        XCTAssertNotNil(stage.state.view(for: me).alliance(of: me)?.lore)
        XCTAssertNil(stage.state.view(for: 2).alliance(of: me)?.lore, "Its studies are its own")
        XCTAssertEqual(stage.state.tidings(of: chosen[0], for: stage.ally)?.text,
                       "Your alliance pursues Masons' Compact I: works rise 4% sooner.")
        XCTAssertEqual(stage.state.tidings(of: gift[0], for: stage.ally)?.text, "You give 40 grain toward Masons' Compact I.")
        XCTAssertEqual(stage.state.tidings(of: gift[0], for: me)?.text,
                       "\(stage.state.houses[stage.ally].title) gives 40 grain toward Masons' Compact I.")
        let studied = GameEvent.allianceStudied(alliance: stage.alliance, study: .masonsCompact, grade: 1)
        XCTAssertEqual(stage.state.tidings(of: studied, for: me)?.text, "Your alliance learns Masons' Compact I: works rise 4% sooner.")
        XCTAssertNil(stage.state.tidings(of: studied, for: 2))
        // Kept in saves.
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(stage.state))
        XCTAssertEqual(kept.alliance(of: me)?.lore, stage.state.alliance(of: me)?.lore)
        XCTAssertEqual(AllianceStudy.allCases.map(\.title), ["Fieldcraft", "Masons' Compact", "Drill Yards", "Oath of Steel", "Shield Oath",
                                                            "Shared Scrolls"])
        XCTAssertTrue(AllianceStudy.allCases.allSatisfy { !$0.effect(grade: 2).isEmpty && $0.cost(grade: 2) == $0.cost(grade: 1) * 2 })
    }

    func testStewardsOfAnAllianceStudyTogether() throws {
        var stage = try staged("stewards study")
        // Stewards both: the leader chooses a study, and both give of plenty.
        stage.state.houses[stage.me].isPlayer = false
        stage.state.houses[stage.ally].isPlayer = false
        var events: [GameEvent] = []
        for _ in 0..<6 {
            events += stage.state.stewardTurn(for: stage.me)
            events += stage.state.stewardTurn(for: stage.ally)
            stage.state.watch += 1
        }
        XCTAssertTrue(events.contains { if case .allianceStudyChosen = $0 { return true } else { return false } }, "\(events)")
        XCTAssertTrue(events.contains { if case .allianceGift(stage.ally, _, _, _, _) = $0 { return true } else { return false } })
        XCTAssertGreaterThan(stage.state.alliance(of: stage.me)?.lore?.given(by: stage.ally) ?? 0, 0)
    }

    func testAnAlliancesLoreOutOfTrueIsFound() throws {
        var stage = try staged("lore unsound")
        var lore = AllianceLore()
        lore.grades = [AllianceStudy.fieldcraft.rawValue: 4, "nonsense": 1]
        lore.pursuit = .fieldcraft
        let index = try XCTUnwrap(stage.state.alliances?.firstIndex { $0.id == stage.alliance })
        stage.state.alliances![index].lore = lore
        let problems = stage.state.problems()
        XCTAssertTrue(problems.contains("The Long Table knows Fieldcraft at grade 4"), "\(problems)")
        XCTAssertTrue(problems.contains("The Long Table knows a study called nonsense"), "\(problems)")
        XCTAssertTrue(problems.contains("The Long Table pursues Fieldcraft, mastered"), "\(problems)")
    }
}
