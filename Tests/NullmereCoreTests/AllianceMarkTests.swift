import Foundation
import XCTest
@testable import NullmereCore

/// Alliance marks (Rise of Kingdoms' alliance markers): a keeper leading an
/// alliance marks ground its House has seen, to gather there, strike there,
/// hold it or beware it, with a few words of their own; the alliance's
/// Houses see each mark and hear of it, no other House does; three at most,
/// a fourth or a mark on marked ground taking another's place; lifted by the
/// leader, lapsed after their time, gone with the alliance; never made by a
/// steward, so a world stewards play alone is untouched.
final class AllianceMarkTests: XCTestCase {
    /// A keeper's House leading an alliance with a steward's House sworn to
    /// it, and a third House outside it.
    private func allied(_ seed: String = "alliance marks") throws -> (GameState, me: Int, ally: Int, other: Int, alliance: Int) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 6, radius: 20, keepers: 1))
        let me = state.player
        let others = state.houses.indices.filter { $0 != me }
        _ = try state.perform(.foundAlliance(name: "Lantern Oath"), as: me)
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        let index = try XCTUnwrap(state.alliances?.firstIndex { $0.id == alliance })
        state.alliances![index].members.append(others[0])
        XCTAssertTrue(state.areAllied(me, others[0]))
        return (state, me, others[0], others[1], alliance)
    }

    private func refusal(_ command: Command, in state: GameState, as house: Int) -> RuleError? {
        var trial = state
        do {
            try trial.perform(command, as: house)
            return nil
        } catch {
            return error
        }
    }

    /// Ground the keeper's House has seen, by its seat.
    private func seen(_ state: GameState, by house: Int, _ index: Int = 1) throws -> Hex {
        let seat = try XCTUnwrap(state.seat(of: house)).position
        let around = seat.neighbors.filter { hex in
            state.map.index(of: hex).map { state.houses[house].explored[$0] } ?? false
        }
        return try XCTUnwrap(around.dropFirst(index - 1).first)
    }

    func testTheLeaderMarksGroundTheAllianceAloneSees() throws {
        var (state, me, ally, other, alliance) = try allied()
        let ground = try seen(state, by: me)
        let events = try state.perform(.markGround(ground, .gather, words: "  Bring the spears!  "), as: me)
        let mark = try XCTUnwrap(state.marks(of: alliance).first)
        XCTAssertEqual(events, [.groundMarked(mark)])
        XCTAssertEqual(mark.kind, .gather)
        XCTAssertEqual(mark.at, ground)
        XCTAssertEqual(mark.by, me)
        XCTAssertEqual(mark.made, state.watch)
        XCTAssertEqual(mark.words, "Bring the spears!")
        XCTAssertEqual(mark.said, "Gather here: “Bring the spears!”")
        XCTAssertEqual(mark.lapses, state.watch + AllianceMark.lasts)
        // Its Houses see it and hear of it; no other House does.
        XCTAssertEqual(state.marksSeen(by: me), [mark])
        XCTAssertEqual(state.marksSeen(by: ally), [mark])
        XCTAssertEqual(state.marksSeen(by: other), [])
        XCTAssertEqual(state.view(for: ally).allianceMarks, [mark])
        XCTAssertNil(state.view(for: other).allianceMarks)
        XCTAssertEqual(state.events(events, heardBy: ally), events)
        XCTAssertEqual(state.events(events, heardBy: other), [])
        let place = state.placeName(of: ground)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "You mark the ground \(place) for the alliance. Gather here: “Bring the spears!”")
        XCTAssertEqual(state.tidings(of: events[0], for: ally)?.text,
                       "\(state.houses[me].title) marks the ground \(place) for the alliance. Gather here: “Bring the spears!”")
        XCTAssertNil(state.tidings(of: events[0], for: other))
        // Each kind says what it bids, and its maker and time are said.
        XCTAssertEqual(AllianceMark.Kind.allCases.map(\.title), ["Gather here", "Strike here", "Hold this ground", "Beware"])
        XCTAssertEqual(AllianceMark.Kind.allCases.map(\.word), ["Gather", "Strike", "Hold", "Beware"])
        XCTAssertEqual(AllianceMark.explained, "The alliance's Houses see a mark where it lies and hear of it; no other House does. "
                       + "Each stands 24 watches, 3 at most: another takes the oldest's place, and a mark on marked ground that one's.")
        XCTAssertEqual(state.markMaker(mark), "Marked by \(state.houses[me].title); it lapses in \(AllianceMark.lasts) watches.")
        XCTAssertEqual(state.marksSaid(of: alliance),
                       ["Gather here, \(place): “Bring the spears!”. Marked by \(state.houses[me].title); it lapses in \(AllianceMark.lasts) watches."])
        XCTAssertEqual(state.marksSaid(of: alliance + 1), [])
        var late = state
        late.watch = mark.lapses - 1
        XCTAssertEqual(late.markMaker(mark), "Marked by \(state.houses[me].title); it lapses in 1 watch.")
        XCTAssertEqual(state.problems(), [], "A world with a mark is sound")
    }

    func testOnlyAKeeperLeadingAnAllianceMarksGroundTheyHaveSeen() throws {
        let (state, me, ally, other, _) = try allied()
        let ground = try seen(state, by: me)
        XCTAssertEqual(refusal(.markGround(ground, .strike, words: nil), in: state, as: ally), .notAKeeper, "A steward marks nothing")
        XCTAssertEqual(state.markRefusal(at: ground, as: 99), .notAKeeper)
        var keeper = state
        keeper.houses[ally].isPlayer = true
        XCTAssertEqual(refusal(.markGround(ground, .strike, words: nil), in: keeper, as: ally), .notAllianceOfficer, "A sworn House follows its leader's marks")
        keeper.houses[other].isPlayer = true
        XCTAssertEqual(refusal(.markGround(ground, .strike, words: nil), in: keeper, as: other), .notInAlliance)
        XCTAssertEqual(refusal(.markGround(Hex(9_999, 9_999), .strike, words: nil), in: state, as: me), .notApplicable)
        let unseen = try XCTUnwrap(state.map.hexes.first { hex in
            state.map.index(of: hex).map { !state.houses[me].explored[$0] } ?? false
        })
        XCTAssertEqual(refusal(.markGround(unseen, .beware, words: nil), in: state, as: me), .unexplored)
        XCTAssertNil(refusal(.markGround(ground, .beware, words: nil), in: state, as: me))
    }

    func testThreeAtMostAFourthOrMarkedGroundTakingAnothersPlace() throws {
        var (state, me, _, _, alliance) = try allied()
        let grounds = try (1...4).map { try seen(state, by: me, $0) }
        for (ground, kind) in zip(grounds.prefix(3), [AllianceMark.Kind.gather, .strike, .hold]) {
            _ = try state.perform(.markGround(ground, kind, words: nil), as: me)
        }
        let first = try XCTUnwrap(state.marks(of: alliance).first)
        let events = try state.perform(.markGround(grounds[3], .beware, words: nil), as: me)
        XCTAssertEqual(events.first, .markLifted(first, lapsed: false), "The oldest gives way")
        XCTAssertEqual(state.marks(of: alliance).map(\.at), Array(grounds.dropFirst()))
        // A mark on marked ground takes that one's place.
        let second = try XCTUnwrap(state.marks(of: alliance).first)
        let again = try state.perform(.markGround(second.at, .strike, words: "Now"), as: me)
        XCTAssertEqual(again.first, .markLifted(second, lapsed: false))
        XCTAssertEqual(state.marks(of: alliance).count, AllianceMark.most)
        XCTAssertEqual(state.marks(of: alliance).last?.kind, .strike)
        XCTAssertEqual(state.marks(of: alliance).filter { $0.at == second.at }.count, 1)
        XCTAssertEqual(state.problems(), [])
    }

    func testTheLeaderLiftsAMarkAndMarksLapseOrGoWithTheirAlliance() throws {
        var (state, me, ally, _, alliance) = try allied()
        _ = try state.perform(.markGround(try seen(state, by: me), .hold, words: nil), as: me)
        let mark = try XCTUnwrap(state.marks(of: alliance).first)
        XCTAssertEqual(refusal(.unmarkGround(mark.id), in: state, as: ally), .notAllianceOfficer)
        XCTAssertEqual(refusal(.unmarkGround(99_999), in: state, as: me), .notApplicable)
        var lifted = state
        XCTAssertEqual(try lifted.perform(.unmarkGround(mark.id), as: me), [.markLifted(mark, lapsed: false)])
        XCTAssertNil(lifted.allianceMarks)
        XCTAssertEqual(lifted.tidings(of: .markLifted(mark, lapsed: false), for: ally)?.text,
                       "The alliance's mark \(lifted.placeName(of: mark.at)) (Hold this ground) is lifted.")

        // Its time passed, it lapses as the watch turns.
        var lapsing = state
        lapsing.watch = mark.lapses - 1
        XCTAssertEqual(lapsing.lapseMarks(), [])
        lapsing.watch = mark.lapses
        XCTAssertEqual(lapsing.lapseMarks(), [.markLifted(mark, lapsed: true)])
        XCTAssertNil(lapsing.allianceMarks)
        XCTAssertEqual(lapsing.tidings(of: .markLifted(mark, lapsed: true), for: me)?.text,
                       "The alliance's mark \(lapsing.placeName(of: mark.at)) (Hold this ground) lapses.")
        var turned = state
        turned.watch = mark.lapses - 1
        let told = turned.endWatch()
        XCTAssertTrue(told.contains(.markLifted(mark, lapsed: true)), "The watch's turn lapses it")

        // Gone with its alliance.
        var parted = state
        _ = try parted.perform(.leaveAlliance, as: ally)
        _ = try parted.perform(.leaveAlliance, as: me)
        XCTAssertNil(parted.alliance(of: me))
        XCTAssertNil(parted.allianceMarks)
        XCTAssertEqual(parted.problems(), [])
    }

    func testAMarksWordsArePlainAndShort() {
        XCTAssertNil(GameState.markWords(nil))
        XCTAssertNil(GameState.markWords("   "))
        XCTAssertNil(GameState.markWords("see www.example.com"), "No addresses")
        XCTAssertEqual(GameState.markWords("Hold\nthe ford"), "Hold the ford")
        XCTAssertEqual(GameState.markWords(String(repeating: "a", count: 80))?.count, AllianceMark.wordsLimit)
    }

    func testAnUnsoundMarkIsSaid() throws {
        var (state, me, _, _, alliance) = try allied()
        _ = try state.perform(.markGround(try seen(state, by: me), .gather, words: nil), as: me)
        let mark = try XCTUnwrap(state.marks(of: alliance).first)
        var astray = state
        astray.allianceMarks = [AllianceMark(id: mark.id, alliance: 77, kind: .gather, at: mark.at, by: me, made: 1)]
        XCTAssertEqual(astray.problems().filter { $0.hasPrefix("Alliance mark ") }.count, 1)
        var crowded = state
        crowded.allianceMarks = (0..<4).map { AllianceMark(id: 900 + $0, alliance: alliance, kind: .beware, at: mark.at, by: me, made: 1) }
        XCTAssertEqual(crowded.problems().filter { $0.hasSuffix("marks, more than \(AllianceMark.most)") }.count, 1)
    }

    /// Stewards make no marks: a world they play alone keeps none, and its
    /// watches are as they were.
    func testAWorldOfStewardsKeepsNoMarks() {
        var state = GameState(settings: GameSettings(seedText: "no marks", houseCount: 6, radius: 18, keepers: 0))
        for _ in 0..<40 where state.outcome == nil {
            for house in state.livingHouses.map(\.id) { _ = state.stewardTurn(for: house) }
            _ = state.endWatch()
        }
        XCTAssertNil(state.allianceMarks)
    }
}
