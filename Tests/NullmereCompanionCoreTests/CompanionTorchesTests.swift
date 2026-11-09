import Foundation
import XCTest
@testable import NullmereCompanionCore
@testable import NullmereCore

/// Torches on the march on the keeper's phone: each company offered its
/// torches doused, and once it marches dark, lit again, as the Mac's panel
/// offers them; what it is about says it marches dark.
final class CompanionTorchesTests: XCTestCase {
    func testThePhoneDousesAndLightsACompanysTorches() throws {
        var state = GameState(settings: GameSettings(seedText: "torches on the phone", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let unit = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        let douse = Command.torches(unit: unit.id, lit: false), light = Command.torches(unit: unit.id, lit: true)
        func company() throws -> CompanionLedger.Company {
            try XCTUnwrap(CompanionLedger(world: state.view(for: me), player: me).companies.first { $0.id == unit.id })
        }
        let lit = try company()
        XCTAssertTrue(lit.orders.contains { $0.title == "Douse the torches" && $0.command == douse }, "\(lit.orders.map(\.title))")
        XCTAssertFalse(lit.orders.contains { $0.command == light }, "Lit already")
        XCTAssertFalse(lit.doing.contains("torches"))
        _ = try state.perform(douse, as: me)
        let dark = try company()
        XCTAssertTrue(dark.orders.contains { $0.title == "Light the torches" && $0.command == light })
        XCTAssertFalse(dark.orders.contains { $0.command == douse }, "Dark already")
        XCTAssertTrue(dark.doing.hasSuffix(", its torches doused"), dark.doing)
        _ = try state.perform(light, as: me)
        XCTAssertFalse(try company().doing.contains("torches"))
    }
}
