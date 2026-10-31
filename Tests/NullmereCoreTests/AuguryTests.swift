import Foundation
import XCTest
@testable import NullmereCore

/// The Augury: a keeper foretells a turn of the realm's course and stakes
/// moonsalt on it; other keepers back it or stand against it while the
/// first half of its span lasts; the realm judges it as the watches turn,
/// and the side that saw true shares every stake. Stewards take no part.
final class AuguryTests: XCTestCase {
    /// A realm of two keepers, each with moonsalt to stake, among stewards.
    private func realm(_ seed: String) -> (state: GameState, me: Int, rival: Int, others: [Int]) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 5, radius: 18, keepers: 1))
        let me = state.player
        let rival = (me + 1) % state.houses.count
        state.houses[rival].isPlayer = true
        for house in [me, rival] { state.houses[house].stock.moonsalt = 60 }
        return (state, me, rival, state.livingHouses.map(\.id).filter { $0 != me && $0 != rival })
    }

    func testAKeeperForetellsAndAnotherStandsAgainstIt() throws {
        var (state, me, rival, others) = realm("a prophecy")
        let claim = Prophecy.Claim.falls(house: others[0])
        let until = state.watch + 12
        XCTAssertEqual(state.prophecyRefusal(claim, until: until, moonsalt: 10, as: others[1]), .notAKeeper, "Stewards foretell nothing")
        XCTAssertEqual(state.prophecyRefusal(claim, until: state.watch + 2, moonsalt: 10, as: me), .invalidAmount, "Six watches ahead at least")
        XCTAssertEqual(state.prophecyRefusal(claim, until: until, moonsalt: 51, as: me), .invalidAmount)
        XCTAssertEqual(state.prophecyRefusal(claim, until: until, moonsalt: 50, as: me), nil)
        XCTAssertEqual(state.prophecyRefusal(.war(others[0], others[0]), until: until, moonsalt: 10, as: me), .notApplicable)
        XCTAssertEqual(state.prophecyRefusal(.spireRises(house: others[0], stage: 0), until: until, moonsalt: 10, as: me), .notApplicable)
        _ = try state.declareWar(by: me, on: others[1])
        XCTAssertEqual(state.prophecyRefusal(.war(me, others[1]), until: until, moonsalt: 10, as: me), .comeToPassAlready)
        var poor = state
        poor.houses[me].stock.moonsalt = 3
        XCTAssertEqual(poor.prophecyRefusal(claim, until: until, moonsalt: 10, as: me), .shortOf(Stock(moonsalt: 7)))

        let events = try state.perform(.prophesy(claim, until: until, moonsalt: 10), as: me)
        let prophecy = try XCTUnwrap(state.openProphecies.first)
        XCTAssertEqual(events, [.prophesied(prophecy)])
        XCTAssertEqual(state.houses[me].stock.moonsalt, 50)
        XCTAssertEqual(prophecy.stakesClose, prophecy.spoken + 6, "Halfway through its span")
        XCTAssertEqual(state.prophecyRefusal(.takesAHold(house: others[0]), until: until, moonsalt: 10, as: me), .prophecyOpen)
        XCTAssertEqual(state.chronicle.last?.kind, .augury)
        XCTAssertTrue(state.told(claim).hasSuffix("will fall"))

        // Another keeper stands against it, once, while stakes are open.
        XCTAssertEqual(state.stakeRefusal(on: prophecy.id, moonsalt: 10, as: me), .stakedAlready)
        XCTAssertEqual(state.stakeRefusal(on: 99, moonsalt: 10, as: rival), .unknownProphecy)
        XCTAssertEqual(state.stakeRefusal(on: prophecy.id, moonsalt: 10, as: others[1]), .notAKeeper)
        XCTAssertEqual(state.stakeRefusal(on: prophecy.id, moonsalt: 4, as: rival), .invalidAmount)
        var late = state
        late.watch = prophecy.stakesClose + 1
        XCTAssertEqual(late.stakeRefusal(on: prophecy.id, moonsalt: 10, as: rival), .stakesClosed(prophecy.stakesClose))
        let staked = try state.perform(.stake(prophecy: prophecy.id, backs: false, moonsalt: 30), as: rival)
        XCTAssertEqual(staked, [.staked(prophecy: prophecy.id, house: rival, backs: false, moonsalt: 30)])
        XCTAssertEqual(state.houses[rival].stock.moonsalt, 30)
        XCTAssertEqual(state.openProphecies.first?.laid(backing: false), 30)
        XCTAssertEqual(state.openProphecies.first?.pool, 40)
        XCTAssertEqual(state.stakeRefusal(on: prophecy.id, moonsalt: 10, as: rival), .stakedAlready)

        // Told to the realm, and kept with the world in every House's view.
        XCTAssertTrue(state.tidings(of: .prophesied(prophecy), for: me)?.text.hasPrefix("You foretell that ") == true)
        XCTAssertTrue(state.tidings(of: .prophesied(prophecy), for: rival)?.text.contains("back it or stand against it until watch") == true)
        XCTAssertTrue(state.tidings(of: staked[0], for: rival)?.text.hasPrefix("You lay 30 moonsalt against") == true)
        XCTAssertTrue(state.tidings(of: staked[0], for: me)?.text.contains("lays 30 moonsalt against") == true)
        XCTAssertNil(state.tidings(of: .staked(prophecy: 99, house: rival, backs: true, moonsalt: 5), for: me))
        XCTAssertTrue(state.events(staked, heardBy: others[0]).contains(staked[0]), "Heard by every House")
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.auguries, state.auguries)
        XCTAssertEqual(state.view(for: rival).auguries, state.auguries)
    }

    /// The realm judges: a prophecy that fails pays those who stood against
    /// it, one that comes to pass those who backed it, each by its stake;
    /// a hold taken is read from the Chronicle, a Moonspire from its stage;
    /// and when none saw true, the lake keeps every stake.
    func testTheRealmJudgesAndTheSideThatSawTrueShares() throws {
        var (state, me, rival, others) = realm("judged")
        let first = state.watch + 6
        _ = try state.perform(.prophesy(.falls(house: others[0]), until: first, moonsalt: 10), as: me)
        _ = try state.perform(.stake(prophecy: 1, backs: false, moonsalt: 20), as: rival)
        XCTAssertEqual(state.judgeProphecies(), [], "Not yet its watch, nor come to pass")
        state.watch = first
        let failed = state.judgeProphecies()
        XCTAssertEqual(failed, [.prophecyJudged(prophecy: 1, cameToPass: false, paid: [Prophecy.Stake(house: rival, backs: false, moonsalt: 30)])])
        XCTAssertEqual(state.houses[rival].stock.moonsalt, 70)
        XCTAssertEqual(state.prophecies.first?.cameToPass, false)
        XCTAssertEqual(state.tidings(of: failed[0], for: rival)?.text, "The prophecy that \(state.told(.falls(house: others[0]))) has failed: your House takes 30 moonsalt.")
        XCTAssertEqual(state.tidings(of: failed[0], for: me)?.tone, .bad, "Its stake lost")
        XCTAssertEqual(state.tidings(of: failed[0], for: others[1])?.tone, .neutral)

        // Two Houses go to war: it comes to pass, and its backers share.
        _ = try state.perform(.prophesy(.war(others[0], others[1]), until: state.watch + 10, moonsalt: 10), as: me)
        _ = try state.perform(.stake(prophecy: 2, backs: false, moonsalt: 10), as: rival)
        _ = try state.declareWar(by: others[0], on: others[1])
        XCTAssertEqual(state.judgeProphecies(), [.prophecyJudged(prophecy: 2, cameToPass: true, paid: [Prophecy.Stake(house: me, backs: true, moonsalt: 20)])])

        // A hold taken, as the Chronicle has it.
        _ = try state.perform(.prophesy(.takesAHold(house: others[1]), until: state.watch + 10, moonsalt: 10), as: me)
        XCTAssertEqual(state.judgeProphecies(), [])
        state.record(.capture, [others[1], others[0]], "A hold is taken.")
        XCTAssertEqual(state.judgeProphecies().count, 1)
        XCTAssertEqual(state.prophecies.last?.cameToPass, true)

        // A Moonspire's next stage, and none who saw true: the lake keeps it.
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == others[1] && $0.isSeat })
        _ = try state.perform(.prophesy(.spireRises(house: others[1], stage: 1), until: state.watch + 10, moonsalt: 10), as: rival)
        _ = try state.perform(.stake(prophecy: 4, backs: false, moonsalt: 10), as: me)
        let salt = state.houses[me].stock.moonsalt
        state.holds[seat].levels[.moonspire] = 1
        XCTAssertEqual(state.judgeProphecies(), [.prophecyJudged(prophecy: 4, cameToPass: true, paid: [Prophecy.Stake(house: rival, backs: true, moonsalt: 20)])])
        XCTAssertEqual(state.houses[me].stock.moonsalt, salt)
        _ = try state.perform(.prophesy(.falls(house: others[1]), until: state.watch + 6, moonsalt: 10), as: me)
        state.houses[me].isEliminated = true
        state.watch += 6
        XCTAssertEqual(state.judgeProphecies(), [.prophecyJudged(prophecy: 5, cameToPass: false, paid: [])], "None standing who saw true")

        // As the watch turns, too; and only the last few judged are kept.
        state.houses[me].isEliminated = false
        for _ in 0..<GameState.propheciesKept {
            _ = try state.perform(.prophesy(.spireRises(house: me, stage: BuildingKind.moonspire.maxLevel), until: state.watch + 6, moonsalt: 5), as: rival)
            state.watch += 5
            _ = state.endWatch()
        }
        XCTAssertEqual(state.prophecies.count, GameState.propheciesKept)
        XCTAssertTrue(state.prophecies.allSatisfy { !$0.isOpen })
    }

    /// Stewards foretell nothing, so a world of stewards goes as it always did.
    func testStewardsForetellNothing() {
        var state = GameState(settings: GameSettings(seedText: "no augury", houseCount: 5, radius: 18))
        for _ in 0..<30 { _ = state.endWatch() }
        XCTAssertNil(state.auguries)
        XCTAssertEqual(GameState.prophecySpan, 6...30)
        XCTAssertEqual(GameState.stakeBounds, 5...50)
    }
}
