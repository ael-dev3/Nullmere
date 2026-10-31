import Foundation
import XCTest
@testable import NullmereCore

/// Ballads: a few short lines of verse about a deed in the Chronicle, made
/// on a keeper's Mac and sung to the realm, which holds them to plain words,
/// one of each deed for each House and one a watch, keeps them in its
/// songbook for every House to read, and remembers them in the keeper's
/// renown as the age ends.
final class BalladTests: XCTestCase {
    private let verse = """
    The black water held the moon,
    and the walls of Vael fell before the dawn.
    """

    /// A lake with two keepers, and a battle in the Chronicle that the first
    /// fought in; a founding none fought.
    private func world() -> (GameState, me: Int, other: Int, battle: Int, founding: Int) {
        var state = Scene.world("ballads", houses: 4, radius: 16)
        let me = state.player
        let other = (me + 1) % 4
        state.houses[other].isPlayer = true
        state.record(.battle, [me, (me + 2) % 4], "A battle at the Grey Ford: forty thousand troops met, and twelve thousand fell.")
        let battle = state.chronicle.count - 1
        state.record(.founding, [other], "A hold is raised at the water's edge.")
        return (state, me, other, battle, state.chronicle.count - 1)
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

    func testABalladOfADeedIsSungAndKeptInTheSongbook() throws {
        var (state, me, other, battle, _) = world()
        XCTAssertTrue(state.isSingable(battle, by: me))
        XCTAssertFalse(state.isSingable(battle, by: other), "Not a deed of theirs")
        let events = try state.perform(.sing(ballad: "  The black water held the moon,  \n\n and the walls of Vael fell before the dawn.", of: battle), as: me)
        let ballad = try XCTUnwrap(state.songbook.last)
        XCTAssertEqual(events, [.sung(ballad)])
        XCTAssertEqual(ballad.lines, ["The black water held the moon,", "and the walls of Vael fell before the dawn."], "Plain lines, the blank ones dropped")
        XCTAssertEqual(ballad.house, me)
        XCTAssertEqual(ballad.entry, battle)
        XCTAssertEqual(ballad.watch, state.watch)

        // Every House hears it, and reads it in the songbook.
        let watchNumber = ordinal(state.chronicle[battle].watch)
        XCTAssertEqual(state.tidings(of: .sung(ballad), for: other)?.text,
                       "\(state.houses[me].title) sings of the \(watchNumber) watch: “The black water held the moon,…”")
        XCTAssertEqual(state.tidings(of: .sung(ballad), for: me)?.text, "Your House sings of the \(watchNumber) watch: “The black water held the moon,…”")
        XCTAssertEqual(state.events([.sung(ballad)], heardBy: other), [.sung(ballad)])
        XCTAssertEqual(state.view(for: other).songbook, [ballad])
        XCTAssertEqual(state.problems(), [])

        // Kept as the world is, and in parts as the realm keeps it.
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)
        let realm = RealmState(name: "R", world: state, keeper: "ilsen", now: 0)
        XCTAssertEqual(try RealmState(parts: try realm.parts(using: JSONEncoder())), realm)
    }

    func testOnlyAPlainBalladOfOnesOwnDeedOnceAndOneAWatch() throws {
        let (state, me, other, battle, founding) = world()
        XCTAssertEqual(refusal(.sing(ballad: verse, of: founding), in: state, as: me), .notSingable, "A founding is no deed for a ballad")
        XCTAssertEqual(refusal(.sing(ballad: verse, of: battle), in: state, as: other), .notSingable, "Nor another House's battle")
        XCTAssertEqual(refusal(.sing(ballad: verse, of: 9_999), in: state, as: me), .notSingable)
        XCTAssertEqual(refusal(.sing(ballad: "One line alone.", of: battle), in: state, as: me), .notABallad)
        XCTAssertEqual(refusal(.sing(ballad: Array(repeating: "A line of the lake", count: 7).joined(separator: "\n"), of: battle), in: state, as: me),
                       .notABallad, "Seven lines are too many")
        XCTAssertEqual(refusal(.sing(ballad: "http://x.com\nwww.y.com", of: battle), in: state, as: me), .notABallad, "No addresses")
        let steward = state.houses.indices.first { !state.houses[$0].isPlayer }!
        XCTAssertEqual(refusal(.sing(ballad: verse, of: battle), in: state, as: steward), .notAKeeper)

        // A line too long is cut; once sung, not again, and one a watch.
        XCTAssertEqual(GameState.sung(String(repeating: "moon ", count: 40) + "\nand water")?.first?.count, GameState.balladLineLimit)
        var sung = state
        _ = try sung.perform(.sing(ballad: verse, of: battle), as: me)
        XCTAssertEqual(refusal(.sing(ballad: verse, of: battle), in: sung, as: me), .sungAlready)
        sung.record(.capture, [me], "Vael is taken.")
        XCTAssertEqual(refusal(.sing(ballad: verse, of: sung.chronicle.count - 1), in: sung, as: me), .sangThisWatch)
        sung.watch += 1
        XCTAssertNil(refusal(.sing(ballad: verse, of: sung.chronicle.count - 1), in: sung, as: me), "At the next watch")
        XCTAssertEqual(RuleError.notABallad.description, "A ballad is two to six short lines of plain words.")
        XCTAssertEqual(RuleError.notSingable.description, "That is no deed of your House's to sing of.")
        XCTAssertEqual(RuleError.sungAlready.description, "Your House has sung of that already.")
        XCTAssertEqual(RuleError.sangThisWatch.description, "Your House has sung this watch; sing again at the next.")

        // The age's end is anyone's to sing of.
        var ended = state
        ended.record(.ending, [], "The age ends.")
        XCTAssertTrue(ended.isSingable(ended.chronicle.count - 1, by: other))
    }

    func testTheSongbookKeepsTheLatestAndTheAgeRemembersTheSingers() throws {
        var (state, me, _, battle, _) = world()
        for watch in 0..<(GameState.songsKept + 3) {
            state.watch = 10 + watch
            state.record(.battle, [me], "Battle \(watch).")
            _ = try state.perform(.sing(ballad: verse, of: state.chronicle.count - 1), as: me)
        }
        XCTAssertEqual(state.songbook.count, GameState.songsKept, "The oldest let go")
        XCTAssertFalse(state.songbook.contains { $0.entry == battle })
        XCTAssertEqual(state.balladsCounted(of: me), GameState.balladsThatCount)

        // As the age ends, two renown for each ballad, five at the most.
        var realm = RealmState(name: "R", world: state, keeper: "ilsen", now: 0)
        let keeper = try XCTUnwrap(realm.keepers.firstIndex { $0.id == "ilsen" })
        XCTAssertEqual(realm.keepers[keeper].house, me)
        realm.world.outcome = Outcome(winner: (me + 1) % 4, kind: .ascendancy, watch: state.watch)
        let deeds = realm.world.deeds(of: me).count
        realm.rememberTheAge()
        XCTAssertEqual(realm.keepers[keeper].renown, 5 * deeds + 10 + GameState.renownPerBallad * GameState.balladsThatCount)

        // A ballad of a House that never was, or of no entry, is unsound.
        var unsound = state
        unsound.ballads = [Ballad(id: 1, house: 99, watch: 1, entry: 99_999, lines: ["one"])]
        XCTAssertEqual(unsound.problems().filter { $0.hasPrefix("Ballad 1") }.count, 3)
    }
}
