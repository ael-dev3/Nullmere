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
        func mark() throws -> CompanionChart.Mark {
            try XCTUnwrap(CompanionChart(world: state.view(for: me), player: me).marks.first { $0.id == "company \(unit.id)" })
        }
        let lit = try company()
        XCTAssertTrue(lit.orders.contains { $0.title == "Douse the torches" && $0.command == douse }, "\(lit.orders.map(\.title))")
        XCTAssertFalse(lit.orders.contains { $0.command == light }, "Lit already")
        XCTAssertFalse(lit.doing.contains("torches"))
        let litMark = try mark()
        XCTAssertFalse(litMark.dark)
        XCTAssertFalse(litMark.name.contains("dark"), litMark.name)
        _ = try state.perform(douse, as: me)
        let dark = try company()
        XCTAssertTrue(dark.orders.contains { $0.title == "Light the torches" && $0.command == light })
        XCTAssertFalse(dark.orders.contains { $0.command == douse }, "Dark already")
        XCTAssertTrue(dark.doing.hasSuffix(", its torches doused"), dark.doing)
        // On the chart, drawn hollow and named so.
        let darkMark = try mark()
        XCTAssertTrue(darkMark.dark)
        XCTAssertTrue(darkMark.name.hasSuffix(", marching dark"), darkMark.name)
        _ = try state.perform(light, as: me)
        XCTAssertFalse(try company().doing.contains("torches"))
        XCTAssertFalse(try mark().dark)
    }

    /// Marching dark in the blackwood, a company is offered to lie in wait,
    /// and once it waits, to stand down, as the Mac's panel offers it; out
    /// of the wood or with its torches lit, neither.
    func testThePhoneHasACompanyLieInWaitInTheWood() throws {
        var state = GameState(settings: GameSettings(seedText: "waiting on the phone", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let unit = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        // Blackwood the House knows, as its keeper sees it on the phone.
        let seen = state.view(for: me)
        let wood = try XCTUnwrap(state.map.hexes.filter { hex in
            seen.isCover(hex) && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }.min { $0.distance(to: unit.position) < $1.distance(to: unit.position) })
        state.units[try XCTUnwrap(state.unitIndex(unit.id))].position = wood
        let wait = Command.lieInWait(unit: unit.id, waiting: true), standDown = Command.lieInWait(unit: unit.id, waiting: false)
        func orders() throws -> [CompanionLedger.Order] {
            try XCTUnwrap(CompanionLedger(world: state.view(for: me), player: me).companies.first { $0.id == unit.id }).orders
        }
        XCTAssertFalse(try orders().contains { $0.command == wait }, "Its torches lit")
        _ = try state.perform(.torches(unit: unit.id, lit: false), as: me)
        let offered = try orders()
        XCTAssertTrue(offered.contains { $0.title == "Lie in wait" && $0.command == wait }, "\(offered.map(\.title))")
        XCTAssertFalse(try orders().contains { $0.command == standDown })
        _ = try state.perform(wait, as: me)
        XCTAssertTrue(try orders().contains { $0.title == "Stand down" && $0.command == standDown })
        XCTAssertFalse(try orders().contains { $0.command == wait }, "Waiting already")
    }
}
