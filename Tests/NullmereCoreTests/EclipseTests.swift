import Foundation
import XCTest
@testable import NullmereCore

/// The Eclipse: at the full moon of the sixtieth watch, and of every
/// ninetieth after, the age drowned beneath this one walks. The Drowned
/// rise from its greatest holds bearing keepsakes, for five watches;
/// struck down, each gives up moonsalt and the Chronicle names its hold;
/// those still walking sink again. A first age, with nothing drowned
/// beneath it, has none.
final class EclipseTests: XCTestCase {
    /// A world with an age drowned beneath it: seven holds of it on open
    /// ground well away from this age's holds, the greater the more works.
    private func drownedWorld(_ seed: String) throws -> GameState {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        var open: [Hex] = []
        for hex in state.map.hexes where open.count < 7 {
            guard let tile = state.map[hex], tile.terrain.isPassable, !tile.terrain.isWater, tile.feature == nil, !state.isOccupied(hex),
                  state.holds.allSatisfy({ $0.position.distance(to: hex) >= 5 }), open.allSatisfy({ $0.distance(to: hex) >= 3 }) else { continue }
            open.append(hex)
        }
        XCTAssertEqual(open.count, 7)
        state.drowned = open.enumerated().map { index, hex in
            DrownedHold(position: hex, name: "Hold \(index)", house: "House Aske", age: 1, works: 3 * index, spire: 0)
        }
        return state
    }

    func testTheMoonIsEatenOnItsWatches() {
        XCTAssertFalse(GameState.isEclipse(at: 30))
        XCTAssertTrue(GameState.isEclipse(at: GameState.firstEclipse))
        XCTAssertFalse(GameState.isEclipse(at: 90))
        XCTAssertTrue(GameState.isEclipse(at: GameState.firstEclipse + GameState.eclipseEvery))
        XCTAssertEqual(GameState.moonAge(at: GameState.firstEclipse), 0, "At the full")
        XCTAssertEqual(GameState.moonAge(at: GameState.firstEclipse + GameState.eclipseEvery), 0)
        XCTAssertEqual(GameState.watchesToEclipse(from: 1), 59)
        XCTAssertEqual(GameState.watchesToEclipse(from: 60), 0)
        XCTAssertEqual(GameState.watchesToEclipse(from: 61), 89)
    }

    func testTheDrownedAgeWalksAtTheEclipseAndSinksAgain() throws {
        var state = try drownedWorld("an eaten moon")
        let me = state.player
        state.watch = GameState.firstEclipse - 1
        XCTAssertEqual(state.turnTheEclipse(), [], "Not before the eclipse")
        state.watch = GameState.firstEclipse
        let events = state.turnTheEclipse()
        XCTAssertEqual(events, [.eclipse(risen: GameState.eclipseRisen)])
        let walking = state.drownedWalking
        XCTAssertEqual(walking.count, GameState.eclipseRisen, "Six at most, the greatest first")
        XCTAssertEqual(Set(walking.compactMap(\.keepsake)), Set((1...6).map { "Hold \($0)" }), "The hold of no works stays sunk")
        XCTAssertTrue(walking.allSatisfy { $0.kind == .drowned && $0.raised == state.watch })
        XCTAssertEqual(walking.first { $0.keepsake == "Hold 6" }?.level, 7, "Its level as the works its hold had")
        for wild in walking {
            let hold = try XCTUnwrap(state.drownedHolds.first { $0.name == wild.keepsake })
            XCTAssertLessThanOrEqual(wild.position.distance(to: hold.position), 2, "Risen where its hold stood")
        }
        XCTAssertTrue(state.chronicle.last?.text.hasPrefix("The moon is eaten.") == true)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.tone, .bad)
        XCTAssertTrue(state.tidings(of: events[0], for: me)?.text.contains("6 companies of the Drowned") == true)
        for house in state.houses.indices { XCTAssertEqual(state.events(events, heardBy: house), events, "Every House sees the moon eaten") }
        XCTAssertEqual(state.problems(), [])
        // Not of the far country's wilds, which still rise in their turn.
        let wilds = state.wildsStanding.count
        state.raiseWilds()
        XCTAssertGreaterThan(state.wildsStanding.count, wilds)
        // Kept with the world.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.drownedWalking, state.drownedWalking)

        // They walk their watches, then sink.
        state.watch += GameState.eclipseLasts - 1
        XCTAssertEqual(state.turnTheEclipse(), [])
        state.watch += 1
        let ended = state.turnTheEclipse()
        XCTAssertEqual(ended, [.eclipseEnded(sank: GameState.eclipseRisen)])
        XCTAssertTrue(state.drownedWalking.isEmpty)
        XCTAssertEqual(state.tidings(of: ended[0], for: me)?.text, "The moon comes back, and 6 of the Drowned sink again.")
        XCTAssertEqual(state.tidings(of: GameEvent.eclipseEnded(sank: 0), for: me)?.text, "The moon comes back.")
        XCTAssertEqual(state.tidings(of: GameEvent.eclipseEnded(sank: 1), for: me)?.text, "The moon comes back, and the last of the Drowned sinks again.")
        XCTAssertTrue(state.tidings(of: GameEvent.eclipse(risen: 1), for: me)?.text.contains("a company of the Drowned") == true)
    }

    /// One laid to rest gives up its keepsake: moonsalt for each of its
    /// levels, with what the Drowned carry, and the Chronicle names its hold.
    func testOneLaidToRestGivesUpItsKeepsake() throws {
        var state = try drownedWorld("a keepsake taken")
        let me = state.player
        state.watch = GameState.firstEclipse
        _ = state.turnTheEclipse()
        let drowned = try XCTUnwrap(state.drownedWalking.min { $0.level < $1.level })
        let beside = try XCTUnwrap(drowned.position.neighbors.first { state.map[$0]?.terrain.isPassable == true && state.isClear($0) })
        let placed = state.put(.spear, tier: 5, of: me, at: beside)
        var struck: [GameEvent] = []
        var strikes = 0
        while state.wildsStanding.contains(where: { $0.id == drowned.id }), strikes < 30 {
            let index = try XCTUnwrap(state.unitIndex(placed))
            state.units[index].movesLeft = state.movement(of: state.units[index])
            state.units[index].health = 100
            struck = try state.perform(.attack(unit: placed, target: drowned.position), as: me)
            strikes += 1
        }
        let hunt = try XCTUnwrap(struck.lazy.compactMap { event -> Hunt? in if case .hunted(let hunt) = event { return hunt } else { return nil } }.first)
        XCTAssertTrue(hunt.wildFell)
        XCTAssertEqual(hunt.spoils, drowned.spoils + GameState.keepsake * drowned.level, "Its keepsake with its spoils")
        XCTAssertEqual(state.chronicle.last { $0.kind == .hunt }?.text,
                       "\(state.houses[me].title) lays the drowned of \(try XCTUnwrap(drowned.keepsake)) to rest, and takes up its keepsake.")
    }

    /// A first age has nothing drowned beneath it: no eclipse raises
    /// anything, so a world of stewards goes through its sixtieth watch as
    /// it always did.
    func testAFirstAgeHasNoEclipse() {
        var state = GameState(settings: GameSettings(seedText: "no eclipse", houseCount: 4, radius: 18, keepers: 1))
        state.watch = GameState.firstEclipse
        XCTAssertEqual(state.turnTheEclipse(), [])
        XCTAssertTrue(state.drownedWalking.isEmpty)
        var stewards = GameState(settings: GameSettings(seedText: "stewards under the moon", houseCount: 4, radius: 18))
        for _ in 0..<GameState.firstEclipse { _ = stewards.endWatch() }
        XCTAssertTrue(stewards.wildsStanding.allSatisfy { $0.keepsake == nil })
        XCTAssertFalse(stewards.chronicle.contains { $0.text.hasPrefix("The moon is eaten") })
    }
}
