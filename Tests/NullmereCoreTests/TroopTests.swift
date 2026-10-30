import Foundation
import XCTest
@testable import NullmereCore

/// Companies counted in troops: so many at full muster by kind and tier,
/// as many standing as their health is a share of; a House's army is all
/// its companies of war together; a battle is told in the troops each
/// side slew and lost.
final class TroopTests: XCTestCase {
    func testACompanyMustersItsTroopsByKindAndTier() {
        XCTAssertEqual(UnitKind.spear.troops(tier: 1), 1_200)
        XCTAssertEqual(UnitKind.spear.troops(tier: 5), 2_400)
        XCTAssertEqual(UnitKind.bow.troops(tier: 3), 1_500)
        XCTAssertEqual(UnitKind.rider.troops(tier: 2), 1_000)
        XCTAssertEqual(UnitKind.lantern.troops(tier: 4), 60)
        XCTAssertEqual(UnitKind.founder.troops(tier: 1), 250)
        XCTAssertEqual(UnitKind.spear.troops(tier: 0), 1_200, "Tiers held to I through V")
        XCTAssertEqual(UnitKind.spear.troops(tier: 9), 2_400)
        for kind in UnitKind.allCases {
            for tier in 1..<5 {
                XCTAssertLessThanOrEqual(kind.troops(tier: tier), kind.troops(tier: tier + 1), "\(kind) grows with its tier")
            }
        }
        XCTAssertEqual(GameState.counted(0), "0")
        XCTAssertEqual(GameState.counted(999), "999")
        XCTAssertEqual(GameState.counted(1_000), "1,000")
        XCTAssertEqual(GameState.counted(12_400), "12,400")
        XCTAssertEqual(GameState.counted(1_234_567), "1,234,567")
        XCTAssertEqual(GameState.counted(-1_500), "-1,500")
    }

    func testAnArmyIsItsCompaniesOfWarsTroops() throws {
        var state = Scene.world("troops", houses: 4, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        state.units.removeAll { $0.owner == me }
        XCTAssertEqual(state.army(of: me), 0)
        let spear = state.put(.spear, tier: 3, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 1...1)), health: 50)
        _ = state.put(.lantern, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 2...2)))
        let rider = state.put(.rider, tier: 5, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3)))
        XCTAssertEqual(state.troops(of: try XCTUnwrap(state.unit(spear))), 900, "Half of 1,800")
        XCTAssertEqual(state.troops(of: try XCTUnwrap(state.unit(rider))), 1_600)
        XCTAssertEqual(state.army(of: me), 2_500, "Its Lanterns are no army")
        XCTAssertEqual(state.army(of: 99), 0)
    }

    func testABattleCountsTheTroopsEachSideSlewAndLost() throws {
        var state = Scene.world("troops fought", houses: 4, radius: 18)
        let me = state.player, foe = (me + 1) % state.houses.count
        let seat = try XCTUnwrap(state.seat(of: me))
        let at = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        let beside = try XCTUnwrap(state.freeHex(near: at, within: 1...1))
        let spear = state.put(.spear, tier: 2, of: me, at: at)
        let theirs = state.put(.bow, tier: 1, of: foe, at: beside, health: 80)
        _ = try state.declareWar(by: me, on: foe)
        let before = (mine: state.troops(of: try XCTUnwrap(state.unit(spear))), foes: state.troops(of: try XCTUnwrap(state.unit(theirs))))
        XCTAssertEqual(before.foes, 800)
        let events = try state.perform(.attack(unit: spear, target: beside), as: me)
        let battle = try XCTUnwrap(events.compactMap { event -> Battle? in
            if case .battle(let battle) = event { return battle }
            return nil
        }.first)
        let after = (mine: state.unit(spear).map(state.troops(of:)) ?? 0, foes: state.unit(theirs).map(state.troops(of:)) ?? 0)
        XCTAssertEqual(battle.slain, before.foes - after.foes)
        XCTAssertEqual(battle.lost, before.mine - after.mine)
        XCTAssertGreaterThan(try XCTUnwrap(battle.slain), 0)
        let report = try XCTUnwrap(state.report(of: battle, id: 1, for: me))
        XCTAssertEqual(report.lines[0], "Your Spears dealt \(battle.damageDealt), slaying \(GameState.counted(battle.slain!))")
        if battle.lost! > 0 {
            XCTAssertEqual(report.lines[1], "Your Spears took \(battle.damageTaken) back, losing \(GameState.counted(battle.lost!))")
        }
        // Told in saves as it was counted.
        let kept = try JSONDecoder().decode(Battle.self, from: try JSONEncoder().encode(battle))
        XCTAssertEqual(kept, battle)

        // A hold's ward struck slays none; what was struck back is lost.
        var siege = Scene.world("troops besiege", houses: 4, radius: 18)
        let hold = try XCTUnwrap(siege.seat(of: foe))
        let gate = try XCTUnwrap(siege.freeHex(near: hold.position, within: 1...1))
        siege.units.removeAll { $0.owner == foe && $0.position.distance(to: hold.position) <= 1 }
        let striker = siege.put(.spear, tier: 5, of: me, at: gate)
        _ = try siege.declareWar(by: me, on: foe)
        let struck = try siege.perform(.attack(unit: striker, target: hold.position), as: me)
        let blow = try XCTUnwrap(struck.compactMap { event -> Battle? in
            if case .battle(let battle) = event { return battle }
            return nil
        }.first)
        XCTAssertNil(blow.slain)
        XCTAssertEqual(blow.lost, UnitKind.spear.troops(tier: 5) - (siege.unit(striker).map(siege.troops(of:)) ?? 0))
        let walls = try XCTUnwrap(siege.report(of: blow, id: 2, for: me))
        XCTAssertTrue(walls.lines[0].hasPrefix("Your Spears dealt \(blow.damageDealt) to the ward"), walls.lines[0])
    }
}
