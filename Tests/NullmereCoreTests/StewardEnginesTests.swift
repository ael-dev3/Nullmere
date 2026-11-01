import Foundation
import XCTest
@testable import NullmereCore

/// Stewards' Mangonels: at war, with a Muster Hall of IV, a steward musters
/// an engine now and then, a sixth of its army and three at the most; at a
/// siege an engine never goes in, but stands off at its reach on open
/// ground and hurls its stones at the walls from there.
final class StewardEnginesTests: XCTestCase {
    /// A steward rich enough for anything, with a Muster Hall of IV, and a
    /// foe it is at war with.
    private func atWar() throws -> (GameState, steward: Int, seat: Int, foe: Int) {
        var state = GameState(settings: GameSettings(seedText: "engines of the stewards", keepers: 1))
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        state.houses[steward].temperament = .steadfast
        state.watch = 70
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == steward && $0.isSeat })
        for kind in [BuildingKind.granary, .sawpit, .quarry, .saltworks] { state.holds[seat].levels[kind] = kind.maxLevel }
        state.holds[seat].levels[.walls] = 2
        state.holds[seat].levels[.beacon] = 1
        state.holds[seat].levels[.musterHall] = 4
        let room = state.storage(of: steward)
        state.houses[steward].stock = Stock(grain: room, timber: room, stone: room, moonsalt: room)
        // Another House the more renowned, so this one leaves the Moonspire be.
        let other = try XCTUnwrap(state.holds.firstIndex { $0.owner != steward && $0.isSeat })
        state.holds[other].levels = [.granary: 5, .sawpit: 5, .quarry: 5, .saltworks: 5, .walls: 5, .beacon: 3, .musterHall: 3]
        let foe = try XCTUnwrap(state.houses.first { $0.id != steward && !$0.isPlayer }?.id)
        _ = try state.declareWar(by: steward, on: foe)
        return (state, steward, seat, foe)
    }

    /// What the steward's seat musters over forty watches, each tried afresh.
    private func mustered(_ state: GameState, steward: Int, seat: Int) -> [UnitKind] {
        (70..<110).compactMap { watch in
            var trial = state
            trial.watch = watch
            trial.draws = UInt64(watch)
            _ = trial.stewardTurn(for: steward)
            return trial.holds[seat].training?.kind
        }
    }

    func testAStewardAtWarMustersAnEngineNowAndThen() throws {
        let (state, steward, seat, _) = try atWar()
        let kinds = mustered(state, steward: steward, seat: seat)
        let engines = kinds.filter { $0 == .mangonel }.count
        XCTAssertGreaterThan(engines, 4, "At war, an engine now and then: \(kinds)")
        XCTAssertGreaterThan(kinds.filter { $0 != .mangonel && $0.isMilitary }.count, engines, "More of the army than engines")

        // At peace, none.
        var peace = state
        for other in peace.houses.indices where peace.isAtWar(steward, other) { peace.setStance(.peace, between: steward, and: other, by: steward) }
        XCTAssertFalse(mustered(peace, steward: steward, seat: seat).contains(.mangonel), "At peace, no engines")

        // Three already, none more.
        var three = state
        let ground = three.holds[seat].position.spiral(4).dropFirst().filter { hex in
            three.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !three.isOccupied(hex)
        }
        for hex in ground.prefix(RivalMind.mostEngines) { _ = three.put(.mangonel, of: steward, at: hex) }
        XCTAssertFalse(mustered(three, steward: steward, seat: seat).contains(.mangonel), "No more than three")

        // Without the moonsalt for an engine, spears rather than nothing.
        var poor = state
        poor.houses[steward].stock.moonsalt = 0
        let kinds2 = mustered(poor, steward: steward, seat: seat)
        XCTAssertFalse(kinds2.contains(.mangonel))
        XCTAssertFalse(kinds2.isEmpty, "Never an idle hall")
    }

    /// At a siege, an engine stands off at its reach and breaks the walls
    /// from there, never stepping onto the hold.
    func testAnEngineStandsOffAtItsReachAndBreaksTheWalls() throws {
        var (state, steward, _, foe) = try atWar()
        state.houses[steward].explored = Array(repeating: true, count: state.map.count)
        // The foe's seat, bare of its companies, the steward's only foe at war.
        let target = try XCTUnwrap(state.seat(of: foe))
        state.units.removeAll { $0.owner == foe }
        for other in state.houses.indices where other != foe && state.isAtWar(steward, other) {
            state.setStance(.peace, between: steward, and: other, by: steward)
        }
        let start = try XCTUnwrap(target.position.spiral(4).first { hex in
            hex.distance(to: target.position) == 4 && state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
                && !state.isOccupied(hex)
        })
        let engine = state.put(.mangonel, tier: 3, of: steward, at: start)
        let ward = try XCTUnwrap(state.hold(target.id)).ward
        var closest = Int.max
        for _ in 0..<6 {
            let index = try XCTUnwrap(state.unitIndex(engine))
            state.units[index].movesLeft = state.movement(of: state.units[index])
            _ = state.stewardTurn(for: steward)
            let at = try XCTUnwrap(state.unit(engine)).position
            closest = min(closest, at.distance(to: target.position))
            XCTAssertNotEqual(at, target.position, "Never onto the hold")
        }
        XCTAssertEqual(closest, UnitKind.mangonel.range, "It stands off at its reach")
        XCTAssertLessThan(try XCTUnwrap(state.hold(target.id)).ward, ward, "The walls broken from there")
        XCTAssertEqual(state.hold(target.id)?.owner, foe, "An engine takes no hold")

        // Its standoff: open ground at its reach, the nearest the engine.
        let mind = RivalMind(house: steward)
        let unit = try XCTUnwrap(state.unit(engine))
        let stand = try XCTUnwrap(mind.standoff(for: unit, from: target.position, in: state))
        XCTAssertEqual(stand.distance(to: target.position), UnitKind.mangonel.range)
        XCTAssertTrue(stand == unit.position || !state.isOccupied(stand))
    }
}
