import XCTest
@testable import NullmereCore

/// The Beacon's watch: marches bound for a beaconed hold told to its keeper
/// alone, more of them the higher the Beacon.
final class WarningTests: XCTestCase {
    private func staged(grade: Int) throws -> (GameState, Int, Hold, NullmereCore.Unit) {
        var state = Scene.world("beacon watch", houses: 4)
        let me = state.player
        let index = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[index].levels[.beacon] = grade
        let seat = state.holds[index]
        let foe = (me + 1) % state.houses.count
        let start = try XCTUnwrap(seat.position.ring(seat.sight + 2).first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        var company = NullmereCore.Unit(id: state.takeID(), kind: .rider, owner: foe, position: start)
        company.destination = seat.position
        state.units.append(company)
        return (state, me, seat, company)
    }

    func testABeaconWarnsOfAMarchBoundForItsHoldTellingMoreAsItRises() throws {
        let (none, me0, _, _) = try staged(grade: 0)
        XCTAssertTrue(none.marchWarnings(for: me0).isEmpty, "No Beacon, no warning")
        let (first, me, seat, company) = try staged(grade: 1)
        XCTAssertEqual(first.marchWarnings(for: me), [MarchWarning(hold: seat.id, from: company.position, house: nil, kind: nil, troops: nil, watches: nil)])
        let (second, _, _, _) = try staged(grade: 2)
        XCTAssertEqual(second.marchWarnings(for: me).first?.house, company.owner)
        XCTAssertEqual(second.marchWarnings(for: me).first?.kind, .rider)
        XCTAssertNil(second.marchWarnings(for: me).first?.troops)
        let (third, _, _, _) = try staged(grade: 3)
        let told = try XCTUnwrap(third.marchWarnings(for: me).first)
        XCTAssertEqual(told.troops, third.troops(of: company))
        XCTAssertEqual(told.watches, (company.position.distance(to: seat.position) + UnitKind.rider.movement - 1) / UnitKind.rider.movement)
        // In the keeper's view alone, and the company itself unseen still.
        let view = third.view(for: me)
        XCTAssertEqual(view.warnings, third.marchWarnings(for: me))
        XCTAssertNil(third.view(for: company.owner).warnings?.first { $0.hold == seat.id })
        XCTAssertNil(third.warnings, "The realm's own world keeps none")
    }

    func testOnlyAMarchBoundForTheHoldIsToldOf() throws {
        var (state, me, seat, company) = try staged(grade: 3)
        let index = try XCTUnwrap(state.unitIndex(company.id))
        state.units[index].destination = nil
        XCTAssertTrue(state.marchWarnings(for: me).isEmpty, "Standing still")
        state.units[index].destination = seat.position.ring(seat.territoryRadius + 3).first
        XCTAssertTrue(state.marchWarnings(for: me).isEmpty, "Bound elsewhere")
        state.units[index].destination = seat.position
        state.units[index].kind = .lantern
        XCTAssertTrue(state.marchWarnings(for: me).isEmpty, "Lanterns are no company of war")
    }
}
