import Foundation
import XCTest
@testable import NullmereCore

/// Dreams of the Still: at the dark of each moon a keeper's House is shown
/// one true thing it cannot see; stewards dream nothing.
final class DreamTests: XCTestCase {
    private func world(_ seed: String = "dreams") -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: 5, radius: 18, keepers: 1))
    }

    /// The Still dreams at the dark of the moon, and only then; the keeper's
    /// House dreams, the stewards' never.
    func testAKeepersHouseDreamsAtTheDarkOfTheMoon() {
        var state = world()
        let me = state.player
        XCTAssertEqual(GameState.dreamingMoon, 15)
        var dreamt: [GameEvent] = []
        while state.watch < GameState.dreamingMoon, state.outcome == nil {
            dreamt += state.endWatch().filter { if case .dreamt = $0 { return true } else { return false } }
        }
        XCTAssertEqual(state.watch, GameState.dreamingMoon)
        XCTAssertEqual(dreamt.count, 1, "One dream, the keeper's")
        guard case .dreamt(let dream)? = dreamt.first else { return XCTFail("No dream") }
        XCTAssertEqual(dream.house, me)
        XCTAssertEqual(dream.watch, GameState.dreamingMoon)
        XCTAssertEqual(state.dreams(of: me), [dream])
        XCTAssertEqual(state.tidings(of: .dreamt(dream), for: me)?.text, state.told(dream))
        XCTAssertNil(state.tidings(of: .dreamt(dream), for: (me + 1) % state.houses.count))
        XCTAssertTrue(state.told(dream).hasPrefix("The Still showed you "))

        // Heard and kept by the dreamer alone.
        let other = (me + 1) % state.houses.count
        XCTAssertFalse(state.events([.dreamt(dream)], heardBy: other).contains(.dreamt(dream)))
        XCTAssertEqual(state.view(for: other).dreams, [], "Not another's to read")
        XCTAssertEqual(state.view(for: me).dreams, [dream])
        let kept = try? JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept?.dreams, [dream])

        // A world of stewards dreams nothing.
        var stewards = GameState(settings: GameSettings(seedText: "dreams", houseCount: 5, radius: 18))
        for _ in 0..<GameState.dreamingMoon { _ = stewards.endWatch() }
        XCTAssertNil(stewards.dreams)
    }

    /// What the Still shows is true, chosen by the moon and the House: the
    /// greatest host of another House and where its largest company
    /// stands, the fullest stores of another, or a ruin unsearched where the
    /// dreamer has never been; the turn passes to the next with something
    /// to show.
    func testTheStillShowsWhatIsTrue() throws {
        var state = world("true dreams")
        let me = state.player
        let others = state.livingHouses.map(\.id).filter { $0 != me }
        // Each turn of the three.
        var seen: [String] = []
        for moon in 0..<3 {
            state.watch = moon * GameState.lunarMonth + GameState.dreamingMoon
            let sight = try XCTUnwrap(state.sight(for: me))
            switch sight {
            case .host(let house, let troops, let at):
                XCTAssertTrue(others.contains(house))
                XCTAssertEqual(troops, state.units(of: house).reduce(0) { $0 + state.troops(of: $1) })
                XCTAssertTrue(state.units(of: house).contains { $0.position == at })
                XCTAssertTrue(others.allSatisfy { state.units(of: $0).reduce(0) { $0 + state.troops(of: $1) } <= troops })
                seen.append("host")
            case .hoard(let house, let stock):
                XCTAssertTrue(others.contains(house))
                XCTAssertEqual(stock, state.houses[house].stock)
                seen.append("hoard")
            case .ruin(let at):
                let index = try XCTUnwrap(state.map.index(of: at))
                XCTAssertEqual(state.map[index].feature, .drownedRuin)
                XCTAssertFalse(state.houses[me].explored[index], "Where the dreamer has never been")
                seen.append("ruin")
            }
        }
        XCTAssertEqual(Set(seen).count, 3, "Each sight in its turn: \(seen)")

        // Told plainly, where it lies: by region where the world has them,
        // else by the lake's quarter.
        let host = Dream(house: me, watch: 15, sight: .host(house: others[0], troops: 4_000, at: state.holds[0].position))
        XCTAssertTrue(state.told(host).contains("4,000 troops"), state.told(host))
        XCTAssertTrue(state.told(host).contains("shore."), state.told(host))
        XCTAssertTrue(state.told(Dream(house: me, watch: 15, sight: .hoard(house: others[0], stock: Stock(grain: 5)))).contains("5 grain"))
        XCTAssertTrue(state.told(Dream(house: me, watch: 15, sight: .hoard(house: 99, stock: .zero))).contains("a fallen House"))
        let streams = GameState(settings: GameSettings(seedText: "dreams", houseCount: 6, radius: 18, keepers: 1, rivers: true))
        let heart = try XCTUnwrap(streams.atlas?.regions.first)
        XCTAssertEqual(streams.whereabouts(of: heart.heart), "in \(heart.name)")
        XCTAssertEqual(state.whereabouts(of: Hex(10, 0)), "on the lake's east shore")
        XCTAssertEqual(state.whereabouts(of: Hex(-10, 0)), "on the lake's west shore")
    }

    /// A House keeps its last few dreams; nothing to show, no dream.
    func testAHouseKeepsItsLastFewDreams() {
        var state = world("many dreams")
        let me = state.player
        for moon in 0..<6 {
            state.watch = moon * GameState.lunarMonth + GameState.dreamingMoon
            _ = state.dream()
        }
        XCTAssertEqual(state.dreams(of: me).count, GameState.dreamsKept)
        XCTAssertEqual(state.dreams(of: me).last?.watch, 5 * GameState.lunarMonth + GameState.dreamingMoon)
        state.watch += 1
        XCTAssertEqual(state.dream(), [], "Only at the dark of the moon")

        var alone = world("alone")
        for index in alone.houses.indices where index != alone.player { alone.houses[index].isEliminated = true }
        alone.watch = GameState.dreamingMoon
        alone.map = WorldMap(radius: alone.map.radius, fill: Tile(terrain: .greyfield))
        XCTAssertNil(alone.sight(for: alone.player), "No other House, no ruin: nothing to show")
        XCTAssertEqual(alone.dream(), [])
    }
}
