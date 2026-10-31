import Foundation
import XCTest
@testable import NullmereCore

/// Whispers on the water: a keeper's unsigned rumour about another House,
/// told to the realm without its teller or its truth; tried by the
/// Lanterns of a keeper scouting that House's holds; a false one naming its
/// teller, who pays the House it belied. Stewards whisper nothing.
final class WhisperTests: XCTestCase {
    /// Three keepers: the teller, the House whispered of, and a third who
    /// tries the whisper, with Lanterns beside the second's seat.
    private func realm(_ seed: String) throws -> (state: GameState, teller: Int, belied: Int, trier: Int, lantern: Int, seat: Hold) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let teller = state.player
        let belied = (teller + 1) % state.houses.count
        let trier = (teller + 2) % state.houses.count
        for house in [belied, trier] { state.houses[house].isPlayer = true }
        state.houses[teller].stock.moonsalt = 60
        let seat = try XCTUnwrap(state.seat(of: belied))
        let beside = try XCTUnwrap(state.map.neighbors(of: seat.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let lantern = Unit(id: state.takeID(), kind: .lantern, owner: trier, position: beside)
        state.units.append(lantern)
        return (state, teller, belied, trier, lantern.id, seat)
    }

    func testAFalseWhisperIsTriedAndItsTellerNamed() throws {
        var (state, teller, belied, trier, lantern, seat) = try realm("a false whisper")
        let steward = (teller + 3) % state.houses.count
        let claim = Whisper.Claim.seatBreached(house: belied)
        XCTAssertFalse(state.isTrue(claim), "The seat's walls stand whole")
        XCTAssertEqual(state.whisperRefusal(claim, as: steward), .notAKeeper, "Stewards whisper nothing")
        XCTAssertEqual(state.whisperRefusal(.granariesLow(house: teller), as: teller), .notApplicable, "Not of its own House")
        XCTAssertEqual(state.whisperRefusal(.hostGathered(house: belied, hold: 9_999), as: teller), .unknownHold)
        var poor = state
        poor.houses[teller].stock.moonsalt = 4
        XCTAssertEqual(poor.whisperRefusal(claim, as: teller), .shortOf(Stock(moonsalt: 6)))

        // Let loose: the realm hears it, unsigned; the teller alone hears whose it is.
        let events = try state.perform(.whisper(claim), as: teller)
        XCTAssertEqual(events, [.whispered(id: 1, claim: claim), .whisperLet(id: 1, by: teller)])
        XCTAssertEqual(state.houses[teller].stock.moonsalt, 50)
        XCTAssertEqual(state.whispersHeard.first?.truth, false)
        XCTAssertEqual(state.whisperRefusal(.granariesLow(house: belied), as: teller), .whisperedLately(until: state.watch + GameState.whisperRest))
        XCTAssertTrue(RuleError.whisperedLately(until: 9).description.contains("watch 9"))
        XCTAssertTrue(state.events(events, heardBy: trier).contains(events[0]))
        XCTAssertFalse(state.events(events, heardBy: trier).contains(events[1]), "Whose it is, the teller alone hears")
        XCTAssertEqual(state.tidings(of: events[0], for: trier)?.text, "A whisper on the water, unsigned: the walls of \(state.houses[belied].title)'s seat are broken.")
        XCTAssertEqual(state.tidings(of: events[0], for: belied)?.tone, .bad)
        XCTAssertTrue(state.tidings(of: events[1], for: teller)?.text.hasPrefix("You let a whisper loose") == true)
        XCTAssertNil(state.tidings(of: events[1], for: trier))

        // In every other keeper's view, neither whose it is nor whether it is true.
        let seen = try XCTUnwrap(state.view(for: trier).whispersHeard.first)
        XCTAssertNil(seen.by)
        XCTAssertNil(seen.truth)
        XCTAssertEqual(state.view(for: teller).whispersHeard.first?.by, teller)
        XCTAssertNil(state.view(for: teller).whispersHeard.first?.truth, "Not even the teller knows its truth for certain")

        // The third keeper's Lanterns scout the seat: the whisper is false, and its teller named and made to pay.
        let tried = try state.perform(.scout(unit: lantern, hold: seat.id), as: trier)
        XCTAssertTrue(tried.contains(.whisperTried(id: 1, house: trier, truth: false)))
        XCTAssertTrue(tried.contains(.whisperUnmasked(id: 1, teller: teller, belied: belied, paid: GameState.whisperPenalty)))
        XCTAssertEqual(state.houses[teller].stock.moonsalt, 50 - GameState.whisperPenalty)
        XCTAssertEqual(state.chronicle.last?.kind, .whisper)
        let unmasked = try XCTUnwrap(state.view(for: steward).whispersHeard.first)
        XCTAssertEqual(unmasked.by, teller, "Found false, whose it was is known to all")
        XCTAssertEqual(unmasked.truth, false)
        XCTAssertTrue(unmasked.triedBy.isEmpty, "Who tried it, each keeper knows of itself alone")
        let named = GameEvent.whisperUnmasked(id: 1, teller: teller, belied: belied, paid: 30)
        XCTAssertEqual(state.tidings(of: named, for: teller)?.tone, .bad)
        XCTAssertEqual(state.tidings(of: named, for: belied)?.tone, .good)
        XCTAssertTrue(state.tidings(of: named, for: steward)?.text.hasSuffix("it was \(state.houses[teller].title)'s.") == true)
        XCTAssertEqual(state.tidings(of: .whisperTried(id: 1, house: trier, truth: false), for: trier)?.tone, .good)
        XCTAssertNil(state.tidings(of: .whisperTried(id: 1, house: trier, truth: false), for: teller))
        XCTAssertTrue(state.events(tried, heardBy: steward).contains(named))

        // Tried once by each, kept with the world, and forgotten in time.
        XCTAssertEqual(state.tryWhispers(scouting: seat.id, as: trier), [])
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.whispers, state.whispers)
        state.watch += GameState.whispersKept
        state.keepWhispers()
        XCTAssertNil(state.whispers)
    }

    /// A true whisper is never traced: those who try it learn it true, and
    /// no one learns whose it was.
    func testATrueWhisperIsNeverTraced() throws {
        var (state, teller, belied, trier, lantern, seat) = try realm("a true whisper")
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].ward = 1
        let claim = Whisper.Claim.seatBreached(house: belied)
        XCTAssertTrue(state.isTrue(claim))
        _ = try state.perform(.whisper(claim), as: teller)
        let tried = try state.perform(.scout(unit: lantern, hold: seat.id), as: trier)
        XCTAssertTrue(tried.contains(.whisperTried(id: 1, house: trier, truth: true)))
        XCTAssertFalse(tried.contains { if case .whisperUnmasked = $0 { return true } else { return false } })
        let seen = try XCTUnwrap(state.view(for: trier).whispersHeard.first)
        XCTAssertEqual(seen.truth, true)
        XCTAssertNil(seen.by, "Never traced")
        XCTAssertEqual(state.tidings(of: .whisperTried(id: 1, house: trier, truth: true), for: trier)?.text,
                       "Your Lanterns find the whisper that the walls of \(state.houses[belied].title)'s seat are broken true.")
        // Past its reach, Lanterns try it no more.
        var late = state
        late.watch += GameState.whisperReach + 1
        late.whispers?[0].triedBy = []
        XCTAssertEqual(late.tryWhispers(scouting: seat.id, as: trier), [])
    }

    /// Each claim weighed as the realm knows it.
    func testClaimsAreWeighedAsTheRealmKnowsThem() throws {
        var (state, _, belied, _, _, seat) = try realm("claims weighed")
        let host = Whisper.Claim.hostGathered(house: belied, hold: seat.id)
        XCTAssertEqual(host.house, belied)
        let near = state.units.filter { $0.owner == belied && $0.kind.isMilitary && $0.position.distance(to: seat.position) <= 2 }
        XCTAssertEqual(state.isTrue(host), near.reduce(0) { $0 + state.troops(of: $1) } >= GameState.gatheredHost)
        for _ in 0..<3 {
            let hex = try XCTUnwrap(state.freeHex(near: seat.position, within: 1...2))
            _ = state.put(.spear, tier: 5, of: belied, at: hex)
        }
        XCTAssertTrue(state.isTrue(host), "Three companies of Spears of V are a host")
        XCTAssertFalse(state.isTrue(.hostGathered(house: belied, hold: 9_999)))
        state.houses[belied].stock.grain = 0
        XCTAssertTrue(state.isTrue(.granariesLow(house: belied)))
        state.houses[belied].stock.grain = 5_000
        XCTAssertFalse(state.isTrue(.granariesLow(house: belied)))
        XCTAssertTrue(state.told(host).hasSuffix("gathers its host at \(seat.name)"))
        XCTAssertEqual(state.told(.granariesLow(house: belied)), "the granaries of \(state.houses[belied].title) run low")
        let seatless = (belied + 1) % state.houses.count
        state.holds.removeAll { $0.owner == seatless && $0.isSeat }
        XCTAssertFalse(state.isTrue(.seatBreached(house: seatless)))
    }

    /// Stewards whisper nothing, so a world of stewards goes as it always did.
    func testStewardsWhisperNothing() {
        var state = GameState(settings: GameSettings(seedText: "no whispers", houseCount: 5, radius: 18))
        for _ in 0..<30 { _ = state.endWatch() }
        XCTAssertNil(state.whispers)
    }
}
