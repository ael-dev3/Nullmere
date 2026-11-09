import Foundation
import XCTest
@testable import NullmereCompanionCore
@testable import NullmereCore

/// Hamlets and barrows on the keeper's phone: the ones their House has
/// found marked on its chart, dim once sought, and a Lantern beside one
/// offered to seek it, as the Mac's panel offers it, where the rules would.
final class CompanionFindsTests: XCTestCase {
    func testThePhoneMarksTheHamletsFoundAndSeeksOneOnce() throws {
        var state = GameState(settings: GameSettings(seedText: "found from the phone", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        let hamlet = try XCTUnwrap(state.findsInLand.first { find in
            find.kind == .hamlet && find.position.distance(to: lantern.position) <= CompanionChart.mostRadius - 2
        }, "A hamlet within the chart's reach")
        let beside = try XCTUnwrap(hamlet.position.neighbors.first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil
        })
        state.units[try XCTUnwrap(state.unitIndex(lantern.id))].position = beside
        state.refreshSight()
        let seek = Command.seek(unit: lantern.id, find: hamlet.id)
        func company() throws -> CompanionLedger.Company {
            try XCTUnwrap(CompanionLedger(world: state.view(for: me), player: me).companies.first { $0.id == lantern.id })
        }
        func mark() throws -> CompanionChart.Mark {
            try XCTUnwrap(CompanionChart(world: state.view(for: me), player: me).marks.first { $0.id == "find \(hamlet.id)" })
        }
        let offered = try company().orders
        XCTAssertTrue(offered.contains { $0.title == "Seek out the hamlet of \(hamlet.name)" && $0.command == seek }, "\(offered.map(\.title))")
        let found = try mark()
        XCTAssertEqual(found.thing, .hamlet)
        XCTAssertEqual(found.hex, hamlet.position)
        XCTAssertEqual(found.name, "The hamlet of \(hamlet.name), not yet sought")
        XCTAssertFalse(found.dark)
        _ = try state.perform(seek, as: me)
        XCTAssertFalse(try company().orders.contains { $0.command == seek }, "Sought already")
        let sought = try mark()
        XCTAssertEqual(sought.name, "The hamlet of \(hamlet.name), sought")
        XCTAssertTrue(sought.dark, "drawn dim once sought")
        // Its place on the chart: what came of it as the chronicle keeps it,
        // and the key of its folk's words among the phone's voices, which
        // the phone's model is asked for as the Mac's is.
        let view = state.view(for: me)
        let place = CompanionChart(world: view, player: me).place(at: hamlet.position, in: view, player: me)
        let entry = try XCTUnwrap(view.discovery(of: hamlet, by: me))
        XCTAssertEqual(place.found, CompanionChart.Found(said: entry.text, voice: "find-\(hamlet.id)", who: "the hamlet's eldest"))
        let keyed = try XCTUnwrap(view.voicedMoments(for: me).first { $0.key == "find-\(hamlet.id)" })
        XCTAssertEqual(keyed.moment, view.voiced(hamlet, by: me))
        XCTAssertNil(CompanionChart(world: view, player: me).place(at: beside, in: view, player: me).found, "Nothing found beside it")
        // Another House's chart marks it only once it has seen its ground, never as sought by this one.
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        let theirs = CompanionChart(world: state.view(for: other), player: other).marks.first { $0.id == "find \(hamlet.id)" }
        XCTAssertEqual(theirs != nil, state.isExplored(hamlet.position, by: other))
        XCTAssertFalse(theirs?.dark ?? false)
        // A barrow marked as one.
        if let barrow = state.findsKnown(by: me).first(where: { $0.kind == .barrow }) {
            let barrowMark = CompanionChart(world: state.view(for: me), player: me).marks.first { $0.id == "find \(barrow.id)" }
            XCTAssertEqual(barrowMark?.thing ?? .barrow, .barrow)
        }
    }
}
