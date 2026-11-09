import Foundation
import XCTest
@testable import NullmereCompanionCore
@testable import NullmereCore

/// The unquiet dead on the keeper's phone: a company of war standing where
/// the House's dead lie unburied is offered Bury the dead, as the Mac's
/// panel offers it, where the rules would take it, and not once it is done;
/// the chart marks the dead lying unburied and the barrow raised over them,
/// and the words cut on its stone are asked of the phone's model.
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
        // The chart marks the dead lying unburied, as the Mac's panel says them.
        func chart(_ world: GameState) -> CompanionChart { CompanionChart(world: world.view(for: me), player: me) }
        let lying = try XCTUnwrap(chart(state).marks.first { $0.thing == .dead && $0.hex == company.position })
        XCTAssertEqual(lying.name, state.view(for: me).fieldOfDeadSaid(try XCTUnwrap(state.fieldOfDead(at: company.position)), for: me))
        XCTAssertEqual(lying.side, .own)
        _ = try state.perform(bury, as: me)
        XCTAssertFalse(try orders(of: company.id, in: state).contains { $0.command == bury }, "buried, nothing more to bury")
        XCTAssertEqual(state.view(for: me).gravesRaised.count, 1)
        // Buried: the barrow marked where they lay, and its place gives the
        // key of the words cut on its stone among the phone's voices, which
        // the phone's model is asked for as the Mac's is.
        let view = state.view(for: me)
        let grave = try XCTUnwrap(view.grave(at: company.position))
        XCTAssertFalse(chart(state).marks.contains { $0.thing == .dead && $0.hex == company.position }, "none lie there now")
        let barrow = try XCTUnwrap(chart(state).marks.first { $0.thing == .grave && $0.hex == company.position })
        XCTAssertEqual(barrow.name, view.graveSaid(grave, for: me))
        XCTAssertEqual(barrow.side, .own)
        let place = chart(state).place(at: company.position, in: view, player: me)
        XCTAssertEqual(place.stone, CompanionChart.Found(said: view.graveSaid(grave, for: me), voice: "grave-\(grave.key)",
                                                         who: CompanionChart.graveVoice))
        XCTAssertTrue(place.lines.contains(view.graveSaid(grave, for: me)))
        let keyed = try XCTUnwrap(view.voicedMoments(for: me).first { $0.key == "grave-\(grave.key)" })
        XCTAssertEqual(keyed.moment, view.voiced(grave, for: me))
        // Another House sees no stone of its own there to word.
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        XCTAssertFalse(state.view(for: other).voicedMoments(for: other).contains { $0.key.hasPrefix("grave-") })
        XCTAssertNil(CompanionChart(world: state.view(for: other), player: other)
            .place(at: company.position, in: state.view(for: other), player: other).stone)
    }
}
