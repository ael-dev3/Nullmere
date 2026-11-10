import Foundation
import XCTest
@testable import NullmereCore

/// Lanterns in counsel: a commander's look at them tells the hamlet or
/// barrow they stand by and may seek, and the hold of another House near
/// enough to scout, as the order book's briefing tells them; the commander
/// may put the seeking forward, read as the order book reads SEEK and
/// weighed by the rules, or told why not in the realm's words.
final class CounselSeekTests: XCTestCase {
    func testACommanderLooksAtLanternsByAFindAndPutsTheSeekingForward() throws {
        var state = Scene.world("seek in counsel", houses: 4, radius: 18)
        let me = state.player
        func open(_ hex: Hex) -> Bool {
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.isClear(hex)
        }
        let hamlet = try XCTUnwrap(state.findsInLand.first { $0.kind == .hamlet && $0.position.neighbors.contains(where: open) })
        let spot = try XCTUnwrap(hamlet.position.neighbors.first(where: open))
        state.reveal(around: hamlet.position, range: 2, for: me)
        let lantern = state.put(.lantern, of: me, at: spot)
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        func counsel() throws -> CommanderCounsel {
            try XCTUnwrap(CommanderCounsel(state: state.view(for: me), player: me, commander: commander.id))
        }
        let before = try counsel()
        let handle = try XCTUnwrap(before.handle(of: try XCTUnwrap(before.state.unit(lantern))))
        let report = before.report(on: handle)
        XCTAssertTrue(report.contains(", by \(hamlet.named), which it may seek (SEEK)"), report)
        XCTAssertTrue(CommanderCounsel.actions.contains("seek"))
        XCTAssertTrue(CommanderCounsel.onlyThese.contains("seek (a hamlet or barrow its Lanterns stand by, found but not yet sought)"))

        let seek = before.propose(" Seek ", company: handle, place: "")
        XCTAssertEqual(seek.line, "SEEK \(handle)")
        XCTAssertEqual(seek.command, .seek(unit: lantern, find: hamlet.id))
        XCTAssertTrue(seek.isGiven)
        XCTAssertEqual(seek.told, "Your \(SpokenOrders.named(try XCTUnwrap(before.state.unit(lantern)), in: before.state)) seek out \(hamlet.named).")

        // Sought: told no more, and seeking again is refused in the realm's words.
        _ = try state.perform(.seek(unit: lantern, find: hamlet.id), as: me)
        let after = try counsel()
        XCTAssertFalse(after.report(on: handle).contains("(SEEK)"), after.report(on: handle))
        let named = SpokenOrders.named(try XCTUnwrap(after.state.unit(lantern)), in: after.state)
        XCTAssertEqual(after.propose("seek", company: handle, place: "").why,
                       "Your \(named) stand by no hamlet or barrow your House has yet to seek.")
    }

    /// Lanterns near a hold of another House are told they may scout it,
    /// as the briefing tells them; a company of war near it is not.
    func testACommandersLookTellsTheHoldLanternsMayScout() throws {
        var state = Scene.world("scout in counsel", houses: 4, radius: 18)
        let me = state.player
        _ = try state.declareWar(by: me, on: 2)
        let seat = try XCTUnwrap(state.seat(of: me)), foe = try XCTUnwrap(state.seat(of: 2))
        state.reveal(around: foe.position, range: 2, for: me)
        let lantern = state.put(.lantern, of: me, at: try XCTUnwrap(state.freeHex(near: foe.position, within: 1...2)))
        let spear = state.put(.spear, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 1...2)))
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        let counsel = try XCTUnwrap(CommanderCounsel(state: state.view(for: me), player: me, commander: commander.id))
        let lanterns = try XCTUnwrap(counsel.handle(of: try XCTUnwrap(counsel.state.unit(lantern))))
        let spears = try XCTUnwrap(counsel.handle(of: try XCTUnwrap(counsel.state.unit(spear))))
        XCTAssertTrue(counsel.report(on: lanterns).contains(", near \(foe.name), which it may scout (SCOUT)"), counsel.report(on: lanterns))
        XCTAssertFalse(counsel.report(on: spears).contains("(SCOUT)"), counsel.report(on: spears))
        XCTAssertEqual(counsel.propose("scout", company: lanterns, place: foe.name).command, .scout(unit: lantern, hold: foe.id))
    }
}
