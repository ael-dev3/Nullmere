import Foundation
import XCTest
@testable import NullmereCore

/// Who stood on each side, as a battle report pictures them: the House's
/// own side first and the foe's second, each side by a few faces (a kind of
/// company of a House once, the most troops first, three at most), a
/// company in its House's colours at its tier as it stands, a hold whose
/// ward was struck, the wilds and their lairs in no House's; a scouting
/// pictured by none. The Mac paints each face from the world's own models.
final class ReportFacesTests: XCTestCase {
    private typealias Face = BattleReport.Face

    /// A keeper's House with its first spear company, raised to the third tier.
    private func world() throws -> (GameState, me: Int, foe: Int, spear: NullmereCore.Unit) {
        var world = Scene.world("report faces")
        let me = world.player
        let spear = try XCTUnwrap(world.units(of: me).first { $0.kind == .spear })
        world.units[try XCTUnwrap(world.unitIndex(spear.id))].tier = 3
        return (world, me, (me + 1) % world.houses.count, try XCTUnwrap(world.unit(spear.id)))
    }

    func testAFieldIsPicturedByEachSidesCompaniesTheMostTroopsFirst() {
        var field = Field(id: 5, at: Hex(0, 0), joined: 3, first: 0, second: 1)
        field.sides[0].append(2)
        let ours: [(UnitKind, Int, Int, Int)] = [(.spear, 1, 0, 2_000), (.bow, 2, 0, 5_000), (.spear, 3, 0, 9_000),
                                                 (.spear, 1, 2, 4_000), (.rider, 1, 0, 1_000), (.mangonel, 1, 0, 3_000)]
        for (index, (kind, tier, owner, troops)) in ours.enumerated() {
            field.fighters.append(Fighter(unit: 100 + index, owner: owner, side: 0, kind: kind, tier: tier, leader: nil, troops: troops))
        }
        field.fighters.append(Fighter(unit: 300, owner: 1, side: 1, kind: .rider, tier: 2, leader: nil, troops: 6_000))
        field.held = 0
        let state = Scene.world("field faces", houses: 3)
        let report = state.report(of: field, id: 1, for: 0)
        XCTAssertEqual(report?.faces, [[Face(.company(.spear, tier: 3), of: 0), Face(.bow, tier: 2, of: 0), Face(.spear, tier: 1, of: 2)],
                                       [Face(.company(.rider, tier: 2), of: 1)]],
                       "The most troops first, each kind of each House once (the lesser spears are pictured by the greatest), three at most")
        XCTAssertEqual(state.report(of: field, id: 1, for: 1)?.faces.first, [Face(.company(.rider, tier: 2), of: 1)], "Each House's own side first")
    }

    func testABlowIsPicturedByTheCompanyThatStruckAndWhatItStruck() throws {
        let (world, me, foe, spear) = try world()
        func battle(attacking: Bool, unit: Int, struck: UnitKind? = .rider, hold: Int? = nil) -> Battle {
            Battle(attacker: attacking ? unit : 9_999, attackerOwner: attacking ? me : foe, attackerKind: .spear,
                   defender: struck == nil ? nil : (attacking ? 9_999 : unit), defenderOwner: attacking ? foe : me,
                   defenderKind: struck == nil ? nil : (attacking ? struck : .spear), hold: hold,
                   at: spear.position, damageDealt: 30, damageTaken: 10, attackerFell: false, defenderFell: false)
        }
        XCTAssertEqual(world.report(of: battle(attacking: true, unit: spear.id), id: 1, for: me)?.faces,
                       [[Face(.company(.spear, tier: 3), of: me)], [Face(.company(.rider, tier: 1), of: foe)]],
                       "The House's company at its tier as it stands; a foe's company gone at the first")
        XCTAssertEqual(world.report(of: battle(attacking: false, unit: spear.id), id: 2, for: me)?.faces,
                       [[Face(.company(.spear, tier: 3), of: me)], [Face(.company(.spear, tier: 1), of: foe)]], "Struck, its own side still first")
        let seat = try XCTUnwrap(world.holds.first { $0.owner == foe && $0.isSeat })
        XCTAssertEqual(world.report(of: battle(attacking: true, unit: spear.id, struck: nil, hold: seat.id), id: 3, for: me)?.faces.last,
                       [Face(.hold(seat: true), of: foe)], "A seat's ward struck pictures the seat, in its keeper's colours")
        var taken = world
        taken.holds[try XCTUnwrap(taken.holds.firstIndex { $0.id == seat.id })].isSeat = false
        XCTAssertEqual(taken.report(of: battle(attacking: true, unit: spear.id, struck: nil, hold: seat.id), id: 4, for: me)?.faces.last,
                       [Face(.hold(seat: false), of: foe)], "Any other hold pictures a hold")
    }

    func testTheWildsAndTheirLairsArePicturedInNoHousesColours() throws {
        let (world, me, foe, spear) = try world()
        let hunt = Hunt(attacker: spear.id, attackerOwner: me, attackerKind: .spear, wild: 1, wildKind: .reavers, level: 5, at: spear.position,
                        damageDealt: 20, damageTaken: 5, attackerFell: false, wildFell: true, spoils: .zero)
        XCTAssertEqual(world.report(of: hunt, id: 1, for: me)?.faces,
                       [[Face(.company(.spear, tier: 3), of: me)], [Face(.wild(.reavers, level: 5), of: nil)]])
        let strikes = [LairAssault.Strike(unit: 7_001, owner: foe, kind: .rider, from: spear.position, dealt: 40, taken: 0, fell: false),
                       LairAssault.Strike(unit: spear.id, owner: me, kind: .spear, from: spear.position, dealt: 30, taken: 4, fell: false)]
        let assault = LairAssault(rally: 3, caller: foe, lair: 9, kind: .saltwights, level: 2, at: spear.position, strikes: strikes,
                                  before: 300, strength: 230, might: 300, shares: [.init(house: foe, spoils: .zero), .init(house: me, spoils: .zero)])
        XCTAssertEqual(world.report(of: assault, id: 2, for: me)?.faces,
                       [[Face(.company(.spear, tier: 3), of: me), Face(.company(.rider, tier: 1), of: foe)], [Face(.lair(.saltwights), of: nil)]],
                       "The House's own companies of the host first, its allies' after")
    }

    func testAScoutingIsPicturedByNone() throws {
        let (world, me, foe, _) = try world()
        let hold = try XCTUnwrap(world.holds.first { $0.owner == foe })
        let scouting = ScoutReport(hold: hold.id, owner: foe, by: me, watch: world.watch, garrison: [], ward: 10, maximumWard: 10,
                                   project: nil, training: nil, spoils: .zero, wounded: 0)
        XCTAssertEqual(world.report(of: scouting, id: 1, for: me)?.faces, [])
    }
}

private extension BattleReport.Face {
    init(_ kind: UnitKind, tier: Int, of house: Int) {
        self.init(.company(kind, tier: tier), of: house)
    }
}
