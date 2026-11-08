import Foundation
import XCTest
@testable import NullmereCore

/// The report of what passed while a keeper was away, told to them: their
/// own House named as theirs, every other House by its name.
final class AwayWordsTests: XCTestCase {
    func testTheKeepersOwnHouseIsTheirs() {
        let title = "House Aurel"
        XCTAssertEqual(AwayReport.told("House Aurel founds Dremmarch on the barrows.", to: title),
                       "Your House founds Dremmarch on the barrows.")
        XCTAssertEqual(AwayReport.told("House Venn refuses tribute to House Aurel.", to: title),
                       "House Venn refuses tribute to your House.")
        XCTAssertEqual(AwayReport.told("The Lyceum rises: House Aurel answered best, 5 of 5.", to: title),
                       "The Lyceum rises: your House answered best, 5 of 5.")
        XCTAssertEqual(AwayReport.told("House Aurel declares war on House Venn. House Aurel's spears march.", to: title),
                       "Your House declares war on House Venn. Your House's spears march.")
        // Another House whose name begins as the keeper's does is its own.
        XCTAssertEqual(AwayReport.told("House Aurelin trades 90 stone to House Seris.", to: title),
                       "House Aurelin trades 90 stone to House Seris.")
        XCTAssertEqual(AwayReport.told("The lake lay still as glass.", to: title), "The lake lay still as glass.")
    }

    func testTheReportTellsTheChronicleToItsKeeper() throws {
        var state = GameState(settings: GameSettings(seedText: "away words", houseCount: 4, radius: 16, keepers: 1))
        let seen = LastSeen(of: state.player, in: state)
        for _ in 0..<30 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        let report = try XCTUnwrap(AwayReport(since: seen, now: state, player: state.player))
        let title = state.houses[state.player].title
        XCTAssertFalse(report.news.isEmpty, "Thirty watches leave something to tell")
        for line in report.news {
            XCTAssertFalse(line.contains(title), "The keeper's own House is theirs: \(line)")
        }
        let theirs = state.chronicle.filter { $0.watch > seen.watch && $0.houses.contains(state.player) }
        XCTAssertTrue(theirs.suffix(AwayReport.lines).allSatisfy { report.news.contains(AwayReport.told($0.text, to: title)) })
    }
}
