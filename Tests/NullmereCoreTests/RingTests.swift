import Foundation
import XCTest
@testable import NullmereCore

/// The Ring, Rise of Kingdoms' arena of commanders: keepers stand lines of
/// up to three commanders, challenge each other's three times a watch,
/// win or lose standing by their lines' weight with the realm's chance in
/// it, and the three standing highest are honoured at each full moon.
/// Stewards stand no line.
final class RingTests: XCTestCase {
    /// Two keepers, each with three commanders.
    private func realm(_ seed: String) throws -> (state: GameState, me: Int, rival: Int) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let rival = (me + 1) % state.houses.count
        state.houses[rival].isPlayer = true
        var random = SeededRandom(seed: 7)
        for house in [me, rival] {
            while state.commanders(of: house).count < 3 {
                _ = try XCTUnwrap(state.raiseCommander(for: house, using: &random))
            }
        }
        return (state, me, rival)
    }

    func testAKeeperStandsALineAndChallengesAnother() throws {
        var (state, me, rival) = try realm("the ring")
        let steward = (me + 2) % state.houses.count
        let mine = state.commanders(of: me).map(\.id)
        let theirs = state.commanders(of: rival).map(\.id)

        // Refused: a steward's line, an empty line or one too long, a
        // commander twice, another's commander; a challenge without a line.
        XCTAssertEqual(state.ringLineRefusal([state.commanders(of: steward)[0].id], as: steward), .notAKeeper)
        XCTAssertEqual(state.ringLineRefusal([], as: me), .invalidAmount)
        XCTAssertEqual(state.ringLineRefusal(mine + [theirs[0]], as: me), .invalidAmount)
        XCTAssertEqual(state.ringLineRefusal([mine[0], mine[0]], as: me), .invalidAmount)
        XCTAssertEqual(state.ringLineRefusal([theirs[0]], as: me), .notYours)
        XCTAssertEqual(state.challengeRefusal(of: rival, as: me), .noLineStanding)
        XCTAssertNil(state.ringLine(of: me))
        XCTAssertEqual(state.ringStanding(of: me), GameState.ringStart)
        XCTAssertEqual(state.ringRanks, [])

        // Stood, and told to its House alone.
        let stood = try state.perform(.standInTheRing(mine), as: me)
        XCTAssertEqual(stood, [.ringLineStood(house: me, line: mine)])
        XCTAssertEqual(state.ringLine(of: me), mine)
        let names = mine.compactMap { state.commander($0)?.name }
        let said = names.count < 3 ? names.joined(separator: " and ") : names.dropLast().joined(separator: ", ") + " and " + names.last!
        XCTAssertEqual(state.tidings(of: stood[0], for: me)?.text, "You stand \(said) in the Ring.", "Named as a list, \"A, B and C\"")
        XCTAssertNil(state.tidings(of: stood[0], for: rival))
        XCTAssertFalse(state.events(stood, heardBy: rival).contains(stood[0]))
        XCTAssertEqual(state.challengeRefusal(of: rival, as: me), .notApplicable, "The rival stands no line yet")
        XCTAssertEqual(state.challengeRefusal(of: me, as: me), .notApplicable, "Not its own")
        XCTAssertEqual(state.challengeRefusal(of: steward, as: me), .notApplicable, "Not a steward's House")
        _ = try state.perform(.standInTheRing([theirs[0]]), as: rival)
        XCTAssertEqual(state.ringRanks, [me, rival].sorted(), "Even standings by the House's place")
        // Every line in the Ring is seen, with what its commanders wear;
        // a commander outside it, leading nothing in sight, is not.
        XCTAssertNotNil(state.view(for: me).commander(theirs[0]))
        XCTAssertNil(state.view(for: me).commander(theirs[2]))
        XCTAssertEqual(state.view(for: me).ringWeight(ofLine: rival), state.ringWeight(ofLine: rival))

        // A line weighs its commanders' levels, talents and gear.
        let weight = mine.compactMap { state.commander($0) }.reduce(0) { $0 + state.ringWeight(of: $1) }
        XCTAssertEqual(state.ringWeight(ofLine: me), weight)
        XCTAssertEqual(state.ringWeight(of: try XCTUnwrap(state.commander(mine[0]))), 50, "A first-level commander, untaught and unarmed")

        // Three challenges a watch; each a bout told to both Houses.
        for made in 0..<GameState.ringChallenges {
            XCTAssertEqual(state.challengesMade(by: me), made)
            let events = try state.perform(.challenge(house: rival), as: me)
            guard case .bout(let bout)? = events.first else { return XCTFail("A bout") }
            XCTAssertEqual(bout.challenger, me)
            XCTAssertEqual(bout.defender, rival)
            XCTAssertEqual(bout.won, bout.challengerWeight > bout.defenderWeight)
            XCTAssertNotEqual(bout.winner, bout.loser)
            XCTAssertTrue((4...30).contains(bout.change))
            XCTAssertNotNil(state.tidings(of: events[0], for: me))
            XCTAssertEqual(state.tidings(of: events[0], for: bout.winner)?.tone, .good)
            XCTAssertEqual(state.tidings(of: events[0], for: bout.loser)?.tone, .bad)
            XCTAssertNil(state.tidings(of: events[0], for: steward))
            XCTAssertTrue(state.events(events, heardBy: rival).contains(events[0]))
            XCTAssertFalse(state.events(events, heardBy: steward).contains(events[0]))
        }
        XCTAssertEqual(state.challengeRefusal(of: rival, as: me), .challengesSpent)
        XCTAssertThrowsError(try state.perform(.challenge(house: rival), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .challengesSpent)
        }
        XCTAssertTrue(RuleError.challengesSpent.description.contains("three challenges"))
        XCTAssertTrue(RuleError.noLineStanding.description.contains("no line"))

        // Standing taken is standing given: the two still sum to two starts.
        XCTAssertEqual(state.ringStanding(of: me) + state.ringStanding(of: rival), 2 * GameState.ringStart)
        XCTAssertEqual(state.ring?.bouts.count, GameState.ringChallenges)

        // Kept with the world, and in every keeper's view.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.ring, state.ring)
        XCTAssertEqual(state.view(for: rival).ring, state.ring)

        // The next watch, three challenges again.
        state.watch += 1
        XCTAssertNil(state.challengeRefusal(of: rival, as: me))
    }

    /// The heavier line wins, for all the realm's chance; the lighter
    /// winning against a higher standing takes more.
    func testTheHeavierLineWinsAndStandingFollowsTheOdds() throws {
        var (state, me, rival) = try realm("weighed")
        let mine = state.commanders(of: me).map(\.id)
        for id in mine {
            let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == id })
            state.commanders?[index].experience = Commander.experience(forLevel: 10)
        }
        _ = try state.perform(.standInTheRing(mine), as: me)
        _ = try state.perform(.standInTheRing([state.commanders(of: rival)[0].id]), as: rival)
        XCTAssertGreaterThan(state.ringWeight(ofLine: me) * 80, state.ringWeight(ofLine: rival) * 120, "Beyond chance's reach")
        let events = try state.perform(.challenge(house: me), as: rival)
        guard case .bout(let bout)? = events.first else { return XCTFail("A bout") }
        XCTAssertFalse(bout.won, "The defender's heavier line holds")
        XCTAssertEqual(bout.winner, me)
        XCTAssertEqual(bout.change, 16, "Between even standings, sixteen")
        XCTAssertEqual(state.ringStanding(of: me), GameState.ringStart + 16)
        XCTAssertTrue(state.tidings(of: events[0], for: rival)?.text.contains("loses") == true)
        XCTAssertTrue(state.tidings(of: events[0], for: me)?.text.contains("wins") == true)

        // A commander lost to another House no longer weighs in the line.
        let given = try XCTUnwrap(state.commanders?.firstIndex { $0.id == mine[0] })
        state.commanders?[given].owner = rival
        XCTAssertLessThan(state.ringWeight(ofLine: me), mine.compactMap { state.commander($0) }.reduce(0) { $0 + state.ringWeight(of: $1) })

        // From one standing far higher, more is taken; from one lower, less.
        var ring = try XCTUnwrap(state.ring)
        ring.set(me, standing: 1500)
        ring.set(rival, standing: 1000)
        state.ring = ring
        let upset = try XCTUnwrap(state.ring)
        XCTAssertEqual(upset.entry(of: me)?.standing, 1500)
        XCTAssertEqual(min(max(16 + (1500 - 1000) / 25, 4), 30), 30)
        XCTAssertEqual(min(max(16 + (1000 - 1500) / 25, 4), 30), 4)
    }

    /// At each full moon the three standing highest are honoured, and every
    /// standing drifts halfway home.
    func testTheFullMoonHonoursTheHighest() throws {
        var (state, me, rival) = try realm("honoured")
        let third = (me + 2) % state.houses.count, fourth = (me + 3) % state.houses.count
        for house in [third, fourth] {
            state.houses[house].isPlayer = true
        }
        var ring = Ring()
        ring.set(fourth, line: [state.commanders(of: fourth)[0].id], standing: 1100)
        ring.set(me, line: state.commanders(of: me).map(\.id), standing: 1060)
        ring.set(rival, line: [state.commanders(of: rival)[0].id], standing: 980)
        ring.set(third, line: [state.commanders(of: third)[0].id], standing: 900)
        XCTAssertEqual(ring.entries.map(\.house), [me, rival, third, fourth].sorted(), "Kept in the order of their Houses")
        state.ring = ring
        XCTAssertEqual(state.ringRanks, [fourth, me, rival, third])

        // Not between full moons.
        state.watch = GameState.lunarMonth + 3
        XCTAssertEqual(state.turnTheRing(), [])
        XCTAssertEqual(state.ringStanding(of: fourth), 1100)

        state.watch = GameState.lunarMonth * 2
        let moonsalt = [fourth, me, rival, third].map { state.houses[$0].stock.moonsalt }
        let events = state.turnTheRing()
        XCTAssertEqual(events, [.ringHonoured(houses: [fourth, me, rival]),
                                .sculpturesFound(house: fourth, count: 6), .sculpturesFound(house: me, count: 4), .sculpturesFound(house: rival, count: 2)],
                       "Honoured with moonsalt, and sculptures for their commanders' stars")
        XCTAssertEqual(state.houses[fourth].stock.moonsalt, moonsalt[0] + 30)
        XCTAssertEqual(state.houses[me].stock.moonsalt, moonsalt[1] + 20)
        XCTAssertEqual(state.houses[rival].stock.moonsalt, moonsalt[2] + 10)
        XCTAssertEqual(state.houses[third].stock.moonsalt, moonsalt[3], "Fourth goes unhonoured")
        XCTAssertEqual([fourth, me, rival, third].map(state.ringStanding), [1050, 1030, 990, 950], "Halfway home")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "Your House stands second in the Ring at the full moon: 20 moonsalt to your stores.")
        XCTAssertEqual(state.tidings(of: events[0], for: third)?.tone, .neutral)
        let honoured = [fourth, me, rival].map { state.houses[$0].title }
        XCTAssertEqual(state.tidings(of: events[0], for: third)?.text,
                       "The Ring honours \(honoured[0]), \(honoured[1]) and \(honoured[2]) at the full moon.", "Named as a list")
        XCTAssertTrue(state.events(events, heardBy: third).contains(events[0]))

        // A fallen House is honoured no more.
        state.houses[fourth].isEliminated = true
        XCTAssertEqual(state.ringRanks, [me, rival, third])
        XCTAssertEqual(state.challengeRefusal(of: fourth, as: me), .notApplicable)
    }

    /// The bouts kept are the last two dozen.
    func testTheRingKeepsItsLastBouts() throws {
        var (state, me, rival) = try realm("kept bouts")
        _ = try state.perform(.standInTheRing(state.commanders(of: me).map(\.id)), as: me)
        _ = try state.perform(.standInTheRing(state.commanders(of: rival).map(\.id)), as: rival)
        for _ in 0..<10 {
            for (house, other) in [(me, rival), (rival, me)] {
                for _ in 0..<GameState.ringChallenges { _ = try state.perform(.challenge(house: other), as: house) }
            }
            state.watch += 1
        }
        XCTAssertEqual(state.ring?.bouts.count, GameState.boutsKept)
        XCTAssertEqual(state.ring?.bouts.last?.watch, state.watch - 1)
    }

    /// Stewards stand no line, so a world of stewards goes as it always did.
    func testStewardsStandNoLine() {
        var state = GameState(settings: GameSettings(seedText: "no ring", houseCount: 5, radius: 18))
        for _ in 0..<GameState.lunarMonth { _ = state.endWatch() }
        XCTAssertNil(state.ring)
    }
}
