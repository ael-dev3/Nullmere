import XCTest
@testable import NullmereCore

/// A steward at war with a great army leads it out as one host: sworn to
/// no alliance it raises its own banner, calls the host on the foe's hold
/// from its Muster Hall, sends every company it can spare, and sets out
/// with them together. A lesser army does not.
final class GreatHostTests: XCTestCase {
    private func staged(companies: Int, troops: Int) throws -> (GameState, Int, Int) {
        var state = GameState(settings: GameSettings(seedText: "a great host", houseCount: 4, radius: 18, keepers: 0))
        let foe = 0, steward = 1
        let seat = try XCTUnwrap(state.seat(of: foe))
        let spot = try XCTUnwrap(seat.position.spiral(8).first { $0.distance(to: seat.position) >= 6 && state.canFound(at: $0, for: steward) == nil })
        var hold = Hold(id: state.takeID(), name: "Harrowgate", owner: steward, position: spot, isSeat: false, foundedWatch: 1)
        hold.levels[.musterHall] = 2
        state.holds.append(hold)
        state.houses[steward].explored = Array(repeating: true, count: state.map.count)
        _ = try state.declareWar(by: steward, on: foe)
        state.edicts = nil
        state.veils = nil
        state.units.removeAll { $0.owner == steward && $0.kind.isMilitary }
        var raised = 0
        for hex in spot.spiral(3) where raised < companies {
            guard state.map[hex].map({ $0.terrain.isPassable && !$0.terrain.isWater }) == true, state.unit(at: hex) == nil, state.hold(at: hex) == nil,
                  state.wild(at: hex) == nil else { continue }
            var unit = Unit(id: state.takeID(), kind: .spear, owner: steward, position: hex, tier: 5)
            unit.drilled = troops - state.firstMuster(of: unit)
            state.units.append(unit)
            raised += 1
        }
        return (state, steward, foe)
    }

    func testAGreatArmyIsLedOutAsOneHost() throws {
        var (state, steward, foe) = try staged(companies: 8, troops: 25_000)
        var called: Int?, set: Int?
        for _ in 0..<4 {
            for event in state.endWatch() {
                if case .rallyCalled(let rally, let caller, _) = event, caller == steward { called = rally }
                if case .rallySetOut(let rally, let caller, _, let defender, let companies) = event, caller == steward {
                    XCTAssertEqual(defender, foe)
                    XCTAssertGreaterThanOrEqual(companies, RivalMind.greatHostCompanies, "the host sets out whole")
                    set = rally
                }
            }
        }
        XCTAssertNotNil(state.alliance(of: steward), "sworn to none, it raised its own banner")
        XCTAssertNotNil(called, "it called its host")
        XCTAssertEqual(set, called, "and led it out")
    }

    func testALesserArmyCallsNoHost() throws {
        var (state, steward, _) = try staged(companies: 3, troops: 25_000)
        XCTAssertNil(RivalMind(house: steward).greatHost(in: state, random: &rand))
        for event in state.endWatch() {
            if case .rallyCalled(_, let caller, _) = event { XCTAssertNotEqual(caller, steward) }
        }
    }
    private var rand = SeededRandom(seed: 1)
}
