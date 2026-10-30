import Foundation
import XCTest
@testable import NullmereCore

/// Battle reports: a battle or a hunt as the keeper reads it afterwards,
/// told from their side, and none for battles their House had no part in.
final class ReportTests: XCTestCase {
    private func battle(attacker: Int, defender: Int, kind: UnitKind? = .spear, hold: Int? = nil, at hex: Hex,
                        attackerFell: Bool = false, defenderFell: Bool = false) -> Battle {
        Battle(attacker: 90, attackerOwner: attacker, attackerKind: .rider, defender: kind == nil ? nil : 91, defenderOwner: defender,
               defenderKind: kind, hold: hold, at: hex, damageDealt: 34, damageTaken: 12, attackerFell: attackerFell, defenderFell: defenderFell)
    }

    func testABattleIsToldFromTheKeepersSide() throws {
        let state = Scene.world("reports")
        let me = state.player
        let foe = (me + 1) % state.houses.count
        let seat = try XCTUnwrap(state.seat(of: me))
        let field = try XCTUnwrap(state.map.hexes.first { state.hold(at: $0) == nil && $0.distance(to: seat.position) == 2 })
        let foeName = state.houses[foe].title

        let won = try XCTUnwrap(state.report(of: battle(attacker: me, defender: foe, at: field, defenderFell: true), id: 1, for: me))
        XCTAssertEqual(won.title, "Your Riders struck \(foeName)'s Spears")
        XCTAssertEqual(won.outcome, .won)
        XCTAssertEqual(won.lines, ["Your Riders dealt 34", "Your Riders took 12 back", "\(foeName)'s Spears fell"])
        XCTAssertEqual(won.place, state.placeName(of: field))
        XCTAssertTrue(won.place.hasSuffix("by \(seat.name)"), won.place)
        XCTAssertEqual(won.watch, state.watch)
        XCTAssertEqual(won.id, 1)

        // Struck, and fallen: lost; struck and standing, the foe fallen striking: won.
        let struck = try XCTUnwrap(state.report(of: battle(attacker: foe, defender: me, at: field, defenderFell: true), id: 2, for: me))
        XCTAssertEqual(struck.title, "\(foeName)'s Riders struck your Spears")
        XCTAssertEqual(struck.outcome, .lost)
        XCTAssertEqual(struck.lines.last, "Your Spears fell")
        let repulsed = try XCTUnwrap(state.report(of: battle(attacker: foe, defender: me, at: field, attackerFell: true), id: 3, for: me))
        XCTAssertEqual(repulsed.outcome, .won)
        XCTAssertEqual(repulsed.lines.last, "\(foeName)'s Riders fell")
        XCTAssertEqual(try XCTUnwrap(state.report(of: battle(attacker: me, defender: foe, at: field), id: 4, for: me)).outcome, .held)
        XCTAssertEqual(try XCTUnwrap(state.report(of: battle(attacker: me, defender: foe, at: field, attackerFell: true), id: 5, for: me)).outcome,
                       .lost)

        // A hold's walls struck.
        let theirs = try XCTUnwrap(state.seat(of: foe))
        let walls = try XCTUnwrap(state.report(of: battle(attacker: me, defender: foe, kind: nil, hold: theirs.id, at: theirs.position),
                                               id: 6, for: me))
        XCTAssertEqual(walls.title, "Your Riders struck the walls of \(theirs.name)")
        XCTAssertEqual(walls.lines.first, "Your Riders dealt 34 to the ward")
        XCTAssertEqual(walls.place, "at \(theirs.name)")

        // Others' battles are no report of the keeper's.
        let others = (me + 2) % state.houses.count
        XCTAssertNil(state.report(of: battle(attacker: foe, defender: others, at: field), id: 7, for: me))
        XCTAssertEqual(state.placeName(of: Hex(999, 0)), "in the field")
    }

    func testAHuntIsToldWithItsSpoils() throws {
        let state = Scene.world("hunt reports")
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        func hunt(by owner: Int, wildFell: Bool = false, attackerFell: Bool = false) -> Hunt {
            Hunt(attacker: 90, attackerOwner: owner, attackerKind: .bow, wild: 900, wildKind: .drowned, level: 4, at: seat.position,
                 damageDealt: 20, damageTaken: 5, attackerFell: attackerFell, wildFell: wildFell,
                 spoils: wildFell ? Stock(grain: 40, moonsalt: 2) : Stock())
        }
        let felled = try XCTUnwrap(state.report(of: hunt(by: me, wildFell: true), id: 1, for: me))
        XCTAssertEqual(felled.title, "Your Bows struck the Drowned of level IV")
        XCTAssertEqual(felled.outcome, .won)
        XCTAssertEqual(felled.lines.last, "The Drowned fell, and gave up \(Stock(grain: 40, moonsalt: 2))")
        XCTAssertEqual(try XCTUnwrap(state.report(of: hunt(by: me), id: 2, for: me)).outcome, .held)
        let fallen = try XCTUnwrap(state.report(of: hunt(by: me, attackerFell: true), id: 3, for: me))
        XCTAssertEqual(fallen.outcome, .lost)
        XCTAssertEqual(fallen.lines.last, "Your Bows fell")
        XCTAssertNil(state.report(of: hunt(by: (me + 1) % state.houses.count), id: 4, for: me))
    }
}
