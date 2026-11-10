import XCTest
@testable import NullmereCore

/// Tomes of old campaigns (Rise of Kingdoms' tomes of knowledge): read by a
/// commander of the House for experience, told to the House alone, refused
/// in the realm's words, never opened as another item is, and put forward
/// by a commander in counsel; kept out of the Lyceum's questions, so a
/// realm's sittings stay as they were drawn.
final class TomeTests: XCTestCase {
    private func scene() throws -> (state: GameState, me: Int, id: Int) {
        var state = Scene.world("old campaigns", houses: 3, radius: 16)
        let me = state.player
        let id = try XCTUnwrap(state.commanders(of: me).first).id
        state.commanders![try XCTUnwrap(state.commanderIndex(id))].experience = 0
        _ = state.give(.tome, 2, to: me)
        return (state, me, id)
    }

    func testACommanderReadsATomeAndRises() throws {
        var (state, me, id) = try scene()
        XCTAssertEqual(ItemKind.tome.counted(2), "2 Tomes of Old Campaigns")
        XCTAssertEqual(ItemKind.tome.effect, "300 experience to a commander of the House who reads it")
        XCTAssertTrue(ItemKind.tome.needsCommander)
        XCTAssertFalse(ItemKind.hourglass.needsCommander)
        XCTAssertNil(state.tomeRefusal(for: id, as: me))
        // 300 experience from nothing reaches level 4 (150 for III, 300 for IV).
        XCTAssertEqual(state.tomeSaid(for: id), "Read a Tome of Old Campaigns: 300 experience, to level 4")
        let events = try state.perform(.readTome(commander: id), as: me)
        XCTAssertEqual(events, [.tomeRead(commander: id, house: me), .commanderRose(commander: id, house: me, level: 4)])
        XCTAssertEqual(state.commander(id)?.experience, 300)
        XCTAssertEqual(state.items(.tome, of: me), 1)
        let name = try XCTUnwrap(state.commander(id)).name
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "\(name) reads a Tome of Old Campaigns: 300 experience.")
        let other = (me + 1) % state.houses.count
        XCTAssertNil(state.tidings(of: events[0], for: other))
        XCTAssertTrue(state.events(events, heardBy: other).filter { if case .tomeRead = $0 { return true } else { return false } }.isEmpty)
        // A second rises less: level 5 asks 500, and 600 is short of VI's 750.
        XCTAssertEqual(state.tomeSaid(for: id), "Read a Tome of Old Campaigns: 300 experience, to level 5")
        _ = try state.perform(.readTome(commander: id), as: me)
        XCTAssertEqual(state.items(.tome, of: me), 0)
        XCTAssertTrue(state.satchel(of: me).isEmpty, "Spent, gone from the satchel")
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
    }

    func testATomeIsRefusedWhereTheRulesSayNo() throws {
        let (state, me, id) = try scene()
        func refused(_ change: (inout GameState) -> Void, as house: Int? = nil, commander: Int? = nil) -> RuleError? {
            var changed = state
            change(&changed)
            return changed.refusal(of: .readTome(commander: commander ?? id), as: house ?? me)
        }
        XCTAssertEqual(refused({ $0.satchel = [] }), .noItem, "None kept")
        XCTAssertEqual(refused({ _ in }, commander: 9_999), .unknownCommander)
        let other = (me + 1) % state.houses.count
        let theirs = try XCTUnwrap(state.commanders(of: other).first).id
        XCTAssertEqual(refused({ $0.satchel = [ItemStack(house: other, kind: .tome, count: 1)] }, as: other, commander: id), .unknownCommander,
                       "Another House's commander reads none of its tomes")
        XCTAssertNil(refused({ $0.satchel = [ItemStack(house: other, kind: .tome, count: 1)] }, as: other, commander: theirs))
        XCTAssertEqual(refused({ world in
            world.commanders![world.commanderIndex(id)!].experience = Commander.experience(forLevel: Commander.highestLevel)
        }), .maxLevel)
        // Not opened as another item is.
        var opened = state
        XCTAssertThrowsError(try opened.perform(.useItem(.tome, hold: nil), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .readByACommander)
        }
        XCTAssertEqual(RuleError.readByACommander.description, "A tome is read by one of your commanders: give it to one from their line.")
        // The Lyceum asks of the satchel's older kinds alone.
        for sitting in 0..<6 {
            for question in state.lyceumQuestions(sitting: sitting) {
                XCTAssertFalse(question.choices.contains(ItemKind.tome.title), "\(question)")
            }
        }
    }

    func testACommanderKnowsTheTomesAndMayPutOneForward() throws {
        let (state, me, id) = try scene()
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        XCTAssertTrue(counsel.selfReport.contains("Your House keeps 2 Tomes of Old Campaigns; reading one gives 300 experience."),
                      counsel.selfReport)
        let read = counsel.proposeForSelf("read", what: "")
        XCTAssertEqual(read.command, .readTome(commander: id))
        XCTAssertNil(read.why)
        XCTAssertEqual(read.line, "READ A TOME")
        XCTAssertEqual(read.told, "\(counsel.commander.name) reads a Tome of Old Campaigns: 300 experience.")
        XCTAssertTrue(CommanderCounsel.onlyTheseForSelf.hasSuffix("or to read one of its tomes."))
        var bare = state
        bare.satchel = []
        let none = try XCTUnwrap(CommanderCounsel(state: bare, player: me, commander: id))
        XCTAssertFalse(none.selfReport.contains("Tome"), none.selfReport)
        XCTAssertEqual(none.proposeForSelf("read a tome", what: "").why, RuleError.noItem.description)
    }
}
