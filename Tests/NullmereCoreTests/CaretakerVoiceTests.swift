import Foundation
import XCTest
@testable import NullmereCore

/// The caretaker who kept a keeper's House greeting them on their return,
/// as a device's own model is asked to voice it: only what the report
/// holds, how long they were gone, the stores and holds as they changed,
/// the latest of the news that touched the House, and the standing orders
/// kept.
final class CaretakerVoiceTests: XCTestCase {
    private func away(watches: Int) throws -> (GameState, AwayReport) {
        var state = GameState(settings: GameSettings(seedText: "the caretaker's word", houseCount: 4, radius: 16, keepers: 1))
        let seen = LastSeen(of: state.player, in: state)
        for _ in 0..<watches {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        return (state, try XCTUnwrap(AwayReport(since: seen, now: state, player: state.player)))
    }

    func testTheCaretakerTellsWhatTheReportHolds() throws {
        let (state, report) = try away(watches: 30)
        XCTAssertEqual(report.watch, state.watch, "made at the watch the keeper came back to")
        let title = state.houses[state.player].title
        let moment = report.voiced(house: title)
        XCTAssertEqual(moment.task, Voicing.caretakerTask)
        XCTAssertEqual(moment.facts.first, "The caretaker kept \(title) while its keeper was away 30 watches.")
        for change in report.changes {
            let told = "\(abs(change.delta)) \(change.resource.title.lowercased())"
            XCTAssertTrue(moment.facts.contains { $0.contains(told) }, "\(told) told")
            let way = change.delta > 0 ? "The stores grew by" : "The stores fell by"
            XCTAssertTrue(moment.facts.contains { $0.hasPrefix(way) && $0.contains(told) }, "\(told) told as it went")
        }
        if let holds = report.holdsLine { XCTAssertTrue(moment.facts.contains(holds)) }
        XCTAssertFalse(report.news.isEmpty)
        for line in report.news.suffix(AwayReport.caretakerTells) {
            XCTAssertTrue(moment.facts.contains(line), "the latest news told: \(line)")
        }
        XCTAssertLessThanOrEqual(moment.facts.filter { report.news.contains($0) }.count, AwayReport.caretakerTells, "never more than a few")
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.caretakerTask))
        XCTAssertTrue(Voicing.caretakerTask.contains("keeping every number, name and event as given"))
    }

    func testOneWatchIsSaidAsOneAndMoreIsLeftToTheChronicle() throws {
        let (state, report) = try away(watches: 1)
        let moment = report.voiced(house: state.houses[state.player].title)
        XCTAssertTrue(moment.facts.first?.hasSuffix("away one watch.") ?? false, moment.facts.first ?? "")
        let more = report.news.count > AwayReport.caretakerTells || report.more > 0
        XCTAssertEqual(moment.facts.contains("More of it stands in the Chronicle."), more)
        let (long, gone) = try away(watches: 60)
        if gone.news.count > AwayReport.caretakerTells || gone.more > 0 {
            XCTAssertTrue(gone.voiced(house: long.houses[long.player].title).facts.contains("More of it stands in the Chronicle."))
        }
        XCTAssertEqual(report.voiced(house: "").facts.first, "The caretaker kept the House while its keeper was away one watch.")
    }

    func testTheStandingOrdersKeptAreSaid() throws {
        var state = GameState(settings: GameSettings(seedText: "the caretaker's orders", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let seen = LastSeen(of: me, in: state)
        _ = try state.perform(.stand(.home), as: me)
        for _ in 0..<(RealmState.caretakerAfter + 1) {
            _ = state.stewardTurn(for: me)
            _ = state.endWatch()
        }
        let report = try XCTUnwrap(AwayReport(since: seen, now: state, player: me))
        let standing = try XCTUnwrap(report.standing)
        XCTAssertTrue(report.voiced(house: state.houses[me].title).facts.contains(standing))
    }
}
