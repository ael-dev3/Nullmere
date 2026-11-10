import Foundation
import XCTest
@testable import NullmereCore

/// The Lanterns' word on a hold of another House they scouted, for a
/// device's own model to give: their report's own words alone, what they
/// scouted and when first; kept under the same key on the Mac and the phone
/// for the same scouting, another for another; never an order; none for a
/// report of anything but a scouting.
final class ScoutWordTests: XCTestCase {
    func testTheLanternsTellWhatTheirReportSaysAndNothingMore() throws {
        var state = Scene.world("the lanterns' word", houses: 4, radius: 18)
        let me = state.player, foe = 1
        let seat = try XCTUnwrap(state.seat(of: foe))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.units.removeAll { $0.position.distance(to: seat.position) <= 1 }
        let spear = state.put(.spear, tier: 2, of: foe, at: seat.position, health: 70)
        let commander = try XCTUnwrap(state.commanders(of: foe).first)
        state.units[try XCTUnwrap(state.unitIndex(spear))].leader = commander.id
        state.holds[index].training = Hold.Training(kind: .rider, watchesLeft: 2, tier: 2)
        state.houses[foe].stock = Stock(grain: 100, timber: 60, stone: 40, moonsalt: 10)
        let lantern = state.put(.lantern, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 2...2)))
        let events = try state.perform(.scout(unit: lantern, hold: seat.id), as: me)
        guard case .holdScouted(let scouting)? = events.first else { return XCTFail("A report: \(events)") }
        XCTAssertEqual(scouting, state.scouting(of: try XCTUnwrap(state.hold(seat.id)), by: me), "the report as the Lanterns see it now")
        let report = try XCTUnwrap(state.report(of: scouting, id: 3, for: me))

        let word = try XCTUnwrap(report.scoutWord)
        XCTAssertEqual(word.task, Voicing.scoutTask)
        XCTAssertEqual(word.facts.first, "\(report.title), \(report.place), at watch \(scouting.watch).")
        XCTAssertEqual(Array(word.facts.dropFirst()), report.lines.map { "\($0)." }, "its report's own lines, every one")
        XCTAssertTrue(word.facts.contains { $0.contains("led by \(commander.name)") }, word.facts.joined(separator: "\n"))
        XCTAssertTrue(word.facts.contains { $0.hasPrefix("Mustering ") }, word.facts.joined(separator: "\n"))
        XCTAssertTrue(word.facts.contains { $0.hasPrefix("Its taking would carry off ") }, word.facts.joined(separator: "\n"))
        // Never a word the voices keep from: no level, no turns.
        for fact in word.facts + [Voicing.scoutTask] {
            let words = Set(fact.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            XCTAssertTrue(words.isDisjoint(with: ["level", "levels", "turn", "turns"]), fact)
        }
        XCTAssertTrue(word.prompt.hasPrefix(Voicing.scoutTask))
        XCTAssertTrue(Voicing.scoutTask.contains("Propose nothing and promise nothing"), "a word, never an order")
        XCTAssertTrue(Voicing.scoutTask.contains("keeping every name and number as given"))

        // The same key however the report is filed, as the phone files its
        // own: kept alike on both; a key a voice's key can carry.
        let key = try XCTUnwrap(report.scoutWordKey)
        XCTAssertGreaterThan(key, 0)
        XCTAssertEqual(try XCTUnwrap(state.report(of: scouting, id: 9, for: me)).scoutWordKey, key)
        // The hold scouted at another watch, or seen otherwise: heard afresh.
        let later = ScoutReport(hold: scouting.hold, owner: scouting.owner, by: me, watch: scouting.watch + 1, garrison: scouting.garrison,
                                ward: scouting.ward, maximumWard: scouting.maximumWard, project: scouting.project,
                                training: scouting.training, spoils: scouting.spoils, wounded: scouting.wounded)
        XCTAssertNotEqual(try XCTUnwrap(state.report(of: later, id: 3, for: me)).scoutWordKey, key)
        let emptied = ScoutReport(hold: scouting.hold, owner: scouting.owner, by: me, watch: scouting.watch, garrison: [],
                                  ward: scouting.ward, maximumWard: scouting.maximumWard, project: scouting.project,
                                  training: scouting.training, spoils: scouting.spoils, wounded: scouting.wounded)
        XCTAssertNotEqual(try XCTUnwrap(state.report(of: emptied, id: 3, for: me)).scoutWordKey, key)

        // None for a report of a battle, nor for another House's scouting.
        let battle = BattleReport(id: 1, watch: 4, title: "Your Spears struck the wilds", place: "", outcome: .won, lines: ["It fell"])
        XCTAssertNil(battle.scoutWord)
        XCTAssertNil(battle.scoutWordKey)
        XCTAssertNil(state.report(of: scouting, id: 0, for: foe))
    }
}
