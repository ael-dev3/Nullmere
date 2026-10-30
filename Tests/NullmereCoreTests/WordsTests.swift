import Foundation
import XCTest
@testable import NullmereCore

/// The keepers' words: a line of plain speech to the whole realm or to an
/// alliance alone, cleaned as an envoy's words are, a watch's worth at
/// most, the latest kept; heard by those they were said to, and by no one
/// else.
final class WordsTests: XCTestCase {
    /// A lake with two keepers, the first sworn to an alliance with a
    /// steward's House; a third House apart.
    private func world() throws -> (GameState, me: Int, other: Int, ally: Int, apart: Int) {
        var state = Scene.world("words", houses: 6, radius: 20)
        let me = state.player
        let (other, ally, apart) = ((me + 1) % 6, (me + 2) % 6, (me + 3) % 6)
        state.houses[other].isPlayer = true
        _ = try state.perform(.foundAlliance(name: "The Grey Hand"), as: me)
        let banner = try XCTUnwrap(state.alliance(of: me))
        let index = try XCTUnwrap(state.alliances?.firstIndex { $0.id == banner.id })
        state.alliances![index].members.append(ally)
        return (state, me, other, ally, apart)
    }

    func testWordsAreSaidToTheRealmOrToAnAllianceAlone() throws {
        var (state, me, other, ally, apart) = try world()
        let events = try state.perform(.say(words: "  Well met,\tneighbours!  ", toAlliance: false), as: me)
        let word = try XCTUnwrap(state.wordsSaid.last)
        XCTAssertEqual(events, [.said(word)])
        XCTAssertEqual(word.text, "Well met, neighbours!", "one line, as an envoy carries it")
        XCTAssertNil(word.alliance)
        XCTAssertEqual(word.from, me)
        XCTAssertEqual(word.watch, state.watch)
        _ = try state.perform(.say(words: "Hold the ford", toAlliance: true), as: me)
        let sworn = try XCTUnwrap(state.wordsSaid.last)
        XCTAssertEqual(sworn.alliance, state.alliance(of: me)?.id)

        // Heard by those they were said to, and by no one else.
        XCTAssertEqual(state.words(heardBy: other).map(\.text), ["Well met, neighbours!"])
        XCTAssertEqual(state.words(heardBy: ally).map(\.text), ["Well met, neighbours!", "Hold the ford"])
        XCTAssertEqual(state.view(for: other).wordsSaid.map(\.text), ["Well met, neighbours!"], "the alliance's words kept from its view")
        XCTAssertEqual(state.view(for: ally).wordsSaid.count, 2)
        XCTAssertEqual(state.events([.said(word), .said(sworn)], heardBy: apart), [.said(word)])
        XCTAssertEqual(state.events([.said(word), .said(sworn)], heardBy: ally), [.said(word), .said(sworn)])

        // Told as tidings to others, in the words said.
        XCTAssertEqual(state.tidings(of: .said(word), for: other)?.text, "\(state.houses[me].title): “Well met, neighbours!”")
        XCTAssertEqual(state.tidings(of: .said(sworn), for: ally)?.text, "\(state.houses[me].title) to your alliance: “Hold the ford”")
        XCTAssertNil(state.tidings(of: .said(word), for: me), "one's own words are not news")
    }

    func testOnlyAKeepersPlainWordsAreCarriedAWatchsWorthAtMost() throws {
        var (state, me, other, ally, _) = try world()
        func refusal(_ words: String, toAlliance: Bool = false, as house: Int) -> RuleError? {
            var trial = state
            do {
                try trial.perform(.say(words: words, toAlliance: toAlliance), as: house)
                return nil
            } catch {
                return error
            }
        }
        XCTAssertEqual(refusal("Hail", as: ally), .notAKeeper, "a steward's House says nothing")
        XCTAssertEqual(refusal("   ", as: me), .nothingToSay)
        XCTAssertEqual(refusal("see www.example.com", as: me), .nothingToSay, "no addresses")
        XCTAssertEqual(refusal("Hail", toAlliance: true, as: other), .notInAlliance)
        XCTAssertNil(refusal(String(repeating: "a", count: 400), as: me))
        _ = try state.perform(.say(words: String(repeating: "a", count: 400), toAlliance: false), as: me)
        XCTAssertEqual(state.wordsSaid.last?.text.count, Envoy.wordsLimit, "cut to what an envoy carries")
        for line in 1..<GameState.wordsPerWatch {
            _ = try state.perform(.say(words: "Line \(line)", toAlliance: false), as: me)
        }
        XCTAssertEqual(refusal("One more", as: me), .saidEnough)
        XCTAssertEqual(state.sayRefusal("One more", toAlliance: false, as: me), .saidEnough)
        XCTAssertNil(refusal("Mine to say", as: other), "another keeper's watch is their own")
        state.watch += 1
        XCTAssertNil(refusal("A new watch", as: me))
        XCTAssertEqual(RuleError.saidEnough.description, "You have said all a watch allows; say more as the watch turns.")
        XCTAssertFalse(RuleError.nothingToSay.description.isEmpty)
        XCTAssertFalse(RuleError.notAKeeper.description.isEmpty)
        XCTAssertEqual(state.sayRefusal("Hail", toAlliance: false, as: 99), .notAKeeper)
    }

    func testTheLatestWordsAreKeptAndTravelWithTheRealm() throws {
        var (state, me, other, _, _) = try world()
        for line in 0..<(GameState.wordsKept + 10) {
            state.watch = line / 10
            _ = try state.perform(.say(words: "Line \(line)", toAlliance: false), as: line % 2 == 0 ? me : other)
        }
        XCTAssertEqual(state.wordsSaid.count, GameState.wordsKept)
        XCTAssertEqual(state.wordsSaid.first?.text, "Line 10", "the oldest let go")
        XCTAssertEqual(state.wordsSaid.last?.text, "Line \(GameState.wordsKept + 9)")
        // Kept with the world, and with the realm's parts.
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(saved.wordsSaid, state.wordsSaid)
        var realm = RealmState(name: "The Nullmere", seed: "words", seats: 6, radius: 20, watchLength: 600, now: 0)
        realm.world = state
        let joined = try RealmState(parts: realm.parts(using: JSONEncoder()))
        XCTAssertEqual(joined.world.wordsSaid, state.wordsSaid)
        // A world from before words has none, and says the first.
        var older = try JSONDecoder().decode(GameState.self, from: Scene.without(["words"], in: state))
        XCTAssertTrue(older.wordsSaid.isEmpty)
        _ = try older.perform(.say(words: "First", toAlliance: false), as: me)
        XCTAssertEqual(older.wordsSaid.map(\.text), ["First"])
    }
}
