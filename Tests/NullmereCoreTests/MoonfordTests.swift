import Foundation
import XCTest
@testable import NullmereCore

/// The Moonford: about each full moon from the first Sundering's on, a
/// ford laid bare across the lake along the moon's road, walked a step a
/// move, and the water back over it as the moon wanes.
final class MoonfordTests: XCTestCase {
    func testTheMoonsRoundOpensTheFordAboutEachFull() {
        XCTAssertFalse((0..<Sundering.first).contains { GameState.fordOpen(at: $0) }, "Not before the first Sundering")
        XCTAssertEqual((50...100).filter { GameState.fordOpen(at: $0) }, Array(55...64) + Array(85...94))
        XCTAssertTrue((145...154).allSatisfy { GameState.fordOpen(at: $0) }, "Open through the second Sundering's first ten watches")
        XCTAssertEqual(GameState.watchesToFord(from: 0), 55)
        XCTAssertEqual(GameState.watchesToFord(from: 60), 0)
        XCTAssertEqual(GameState.watchesToFord(from: 65), 20)
        XCTAssertEqual(GameState.fordWatchesLeft(at: 55), 10)
        XCTAssertEqual(GameState.fordWatchesLeft(at: 64), 1)
        XCTAssertEqual(GameState.fordWatchesLeft(at: 65), 0)
        XCTAssertEqual(GameState.moonAge(at: 60), 0, "Full")
        XCTAssertEqual(GameState.moonAge(at: 75), 15, "The dark of the moon")
    }

    /// A world a watch before the ford opens.
    private func eve(_ seed: String) -> GameState {
        var state = GameState(settings: GameSettings(seedText: seed, keepers: 1))
        state.watch = Sundering.first - 1
        return state
    }

    func testTheFordLiesAcrossTheLakeForEveryHouseToSee() throws {
        var state = eve("the full moon")
        let course = state.fordCourse()
        XCTAssertFalse(course.isEmpty, "The moon's road over the deep water")
        XCTAssertTrue(course.allSatisfy { state.map[$0]?.terrain == .still })
        XCTAssertEqual(Set(course.map(\.r)).count, 2, "Two hexes wide")

        let events = state.endWatch()
        XCTAssertEqual(state.watch, Sundering.first)
        XCTAssertTrue(events.contains(.fordOpened(closes: Sundering.first + GameState.fordLasts)), "\(events)")
        XCTAssertEqual(state.ford, course)
        for hex in course {
            XCTAssertEqual(state.map[hex]?.terrain, .ford)
            let index = try XCTUnwrap(state.map.index(of: hex))
            XCTAssertTrue(state.houses.filter { !$0.isEliminated }.allSatisfy { $0.explored[index] }, "Lit for every House")
        }
        XCTAssertTrue(Terrain.ford.isPassable && Terrain.ford.isWater && !Terrain.ford.isSettleable)
        XCTAssertEqual(Terrain.ford.moveCost, 1, "A step a move")
        XCTAssertTrue(state.chronicle.contains { $0.kind == .omen && $0.text.contains("a ford of shingle") })

        // Shore to shore: each row's ends meet ground a company may stand
        // on or wade, so the way across is open.
        for row in Set(course.map(\.r)) {
            let hexes = course.filter { $0.r == row }.map(\.q)
            let west = Hex(try XCTUnwrap(hexes.min()) - 1, row), east = Hex(try XCTUnwrap(hexes.max()) + 1, row)
            XCTAssertEqual(state.map[west]?.terrain.isPassable, true, "Its western end reaches the shore")
            XCTAssertEqual(state.map[east]?.terrain.isPassable, true, "and its eastern")
        }

        // Every keeper's view shows it, explored or not before.
        let view = state.view(for: state.player)
        XCTAssertTrue(course.allSatisfy { view.map[$0]?.terrain == .ford })
        XCTAssertNotNil(state.tidings(of: .fordOpened(closes: Sundering.first + GameState.fordLasts), for: state.player))

        // Kept as the world is.
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)
    }

    func testAMarchCrossesTheLakeByTheFord() throws {
        var state = eve("across the water")
        _ = state.endWatch()
        let course = try XCTUnwrap(state.ford)
        let row = course[0].r
        let hexes = course.filter { $0.r == row }.map(\.q)
        let west = Hex(try XCTUnwrap(hexes.min()) - 1, row), east = Hex(try XCTUnwrap(hexes.max()) + 1, row)
        let id = state.takeID()
        var walker = NullmereCore.Unit(id: id, kind: .rider, owner: state.player, position: west)
        state.units.removeAll { $0.position == west }
        state.units.append(walker)
        walker = try XCTUnwrap(state.unit(id))
        let way = try XCTUnwrap(state.path(for: walker, to: east), "A way over the ford")
        XCTAssertTrue(way.contains { course.contains($0) }, "It goes by the ford")
        XCTAssertLessThanOrEqual(way.count, hexes.count + 4, "Straight across")
    }

    func testTheWaterComesBackAndCarriesCompaniesAshore() throws {
        var state = eve("the waning")
        _ = state.endWatch()
        let course = try XCTUnwrap(state.ford)
        let middle = course[course.count / 2]
        let id = state.takeID()
        state.units.append(NullmereCore.Unit(id: id, kind: .spear, owner: state.player, position: middle))
        state.watch = Sundering.first + GameState.fordLasts - 1
        let events = state.endWatch()
        XCTAssertNil(state.ford, "Under water again")
        XCTAssertTrue(course.allSatisfy { state.map[$0]?.terrain == .still })
        XCTAssertTrue(events.contains(.fordClosed(carried: 1)), "\(events)")
        let carried = try XCTUnwrap(state.unit(id))
        let ground = try XCTUnwrap(state.map[carried.position])
        XCTAssertTrue(ground.terrain.isPassable && !ground.terrain.isWater, "On the shore: \(ground.terrain)")
        XCTAssertLessThanOrEqual(carried.health, 100 - GameState.tideToll + 10, "Worn by the tide, healing a little as the watch turned")
        XCTAssertNil(carried.destination)
        XCTAssertTrue(events.contains { if case .carriedAshore(id, _, middle, carried.position) = $0 { return true } else { return false } })
        XCTAssertEqual(state.tidings(of: .carriedAshore(unit: id, owner: state.player, from: middle, to: carried.position), for: state.player)?.tone, .bad)
        XCTAssertNil(state.tidings(of: .carriedAshore(unit: id, owner: state.player, from: middle, to: carried.position), for: (state.player + 1) % state.houses.count))

        // A march bound for the ford ends as the water comes back, and no
        // company ever steps into the Still.
        var bound = eve("bound for the ford")
        _ = bound.endWatch()
        let crossing = try XCTUnwrap(bound.ford)
        let row = crossing.filter { $0.r == crossing[0].r }.map(\.q)
        let shore = Hex(try XCTUnwrap(row.min()) - 1, crossing[0].r)
        bound.units.removeAll { $0.position == shore }
        let walker = bound.takeID()
        bound.units.append(NullmereCore.Unit(id: walker, kind: .spear, owner: bound.player, position: shore))
        let far = Hex(try XCTUnwrap(row.max()), crossing[0].r)
        bound.units[try XCTUnwrap(bound.unitIndex(walker))].destination = far
        bound.watch = Sundering.first + GameState.fordLasts - 1
        _ = bound.endWatch()
        let stood = try XCTUnwrap(bound.unit(walker))
        XCTAssertNil(stood.destination, "Bound for water, the march ends")
        XCTAssertNotEqual(bound.map[stood.position]?.terrain, .still)
        // Even a march found before the water came back steps no further than the shore.
        var late = bound
        late.units[try XCTUnwrap(late.unitIndex(walker))].destination = far
        late.units[try XCTUnwrap(late.unitIndex(walker))].movesLeft = late.movement(of: stood)
        _ = late.march(walker, planned: [far])
        XCTAssertNotEqual(late.map[try XCTUnwrap(late.unit(walker)).position]?.terrain, .still, "Never into the Still")
        XCTAssertNil(late.unit(walker)?.destination)
        XCTAssertEqual(late.problems(), [])

        // A lake with no deep water has no ford.
        var shallow = eve("no deep water")
        for index in 0..<shallow.map.count where shallow.map[index].terrain == .still {
            shallow.map.set(index: index, Tile(terrain: .shallows))
        }
        XCTAssertTrue(shallow.fordCourse().isEmpty)
        _ = shallow.endWatch()
        XCTAssertNil(shallow.ford)
    }
}
