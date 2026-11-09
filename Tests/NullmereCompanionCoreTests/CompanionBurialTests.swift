import Foundation
import XCTest
@testable import NullmereCompanionCore
@testable import NullmereCore

/// The unquiet dead on the keeper's phone: a company of war standing where
/// the House's dead lie unburied is offered Bury the dead, as the Mac's
/// panel offers it, where the rules would take it, and not once it is done.
final class CompanionBurialTests: XCTestCase {
    func testThePhoneOffersToBuryTheDeadWhereTheyLie() throws {
        var state = GameState(settings: GameSettings(seedText: "burial on the phone", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        let lantern = try XCTUnwrap(state.placeUnit(.lantern, tier: 1, for: me, near: company.position))
        func orders(of id: Int, in world: GameState) throws -> [CompanionLedger.Order] {
            try XCTUnwrap(CompanionLedger(world: world.view(for: me), player: me).companies.first { $0.id == id }).orders
        }
        let bury = Command.bury(unit: company.id)
        XCTAssertFalse(try orders(of: company.id, in: state).contains { $0.command == bury }, "none lie there yet")
        state.layTheFallen(2_500, of: me, at: company.position)
        state.layTheFallen(400, of: me, at: lantern.position)
        let offered = try orders(of: company.id, in: state)
        XCTAssertTrue(offered.contains { $0.title == "Bury the dead" && $0.command == bury }, "\(offered.map(\.title))")
        XCTAssertFalse(try orders(of: lantern.id, in: state).contains { $0.title == "Bury the dead" }, "a company of war buries them")
        _ = try state.perform(bury, as: me)
        XCTAssertFalse(try orders(of: company.id, in: state).contains { $0.command == bury }, "buried, nothing more to bury")
        XCTAssertEqual(state.view(for: me).gravesRaised.count, 1)
    }
}
