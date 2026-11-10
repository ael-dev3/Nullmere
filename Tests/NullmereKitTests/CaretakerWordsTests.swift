import AppKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The caretaker who kept a keeper's House greeting them on their return:
/// this Mac's model is asked, first of all, for the caretaker's word under
/// the watch the keeper came back to, from what the report holds; the away
/// card shows it over the report; a card dismissed before the word is
/// given wants it no longer.
@MainActor
final class CaretakerWordsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A House seen at its first watch, and the world a dozen watches on.
    private func away() -> (LocalStore, GameState) {
        let store = LocalStore(directory: dir)
        var world = GameState(settings: GameSettings(seedText: "the caretaker greets", houseCount: 4, radius: 16, keepers: 1))
        _ = GameSession(state: world, store: store)
        for _ in 0..<12 {
            _ = world.stewardTurn(for: world.player)
            _ = world.endWatch()
        }
        return (store, world)
    }

    func testTheCaretakerGreetsTheKeeperComeBackInTheirOwnWords() async throws {
        let (store, world) = away()
        let back = GameSession(state: world, store: store, voice: Keeper())
        let report = try XCTUnwrap(back.awayReport)
        XCTAssertEqual(report.watch, world.watch)
        let key = GameSession.Spoken.caretaker(report.watch)
        XCTAssertEqual(key.key, "caretaker-\(world.watch)")
        XCTAssertEqual(GameSession.Spoken(key: key.key), key)
        let deadline = Date().addingTimeInterval(5)
        while back.spoken[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(back.spoken[key], Keeper.words, "kept under the watch the keeper came back to")
        let moment = VoiceFacts.caretaker(report, house: world.player, in: world)
        XCTAssertEqual(moment.kind, .caretaker)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.caretakerTask), moment.prompt)
        XCTAssertEqual(moment.facts, report.voiced(house: world.houses[world.player].title).facts)
        // The card shows the word over the report, kept with CI's screenshots.
        try CardShot.keep(AwayCard(report: report, session: back) {}.padding(20), as: "game-away-caretaker.png")
        back.dismissAwayReport()
        XCTAssertFalse(back.stillVoiced(key), "a card gone is spoken for no longer")
    }

    func testACardDismissedBeforeTheCaretakerSpeaksWantsTheWordNoLonger() async throws {
        let (store, world) = away()
        let back = GameSession(state: world, store: store, voice: Slow())
        let report = try XCTUnwrap(back.awayReport)
        let key = GameSession.Spoken.caretaker(report.watch)
        let deadline = Date().addingTimeInterval(6)
        while back.voicing?.key != key, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(back.voicing?.key, key, "the caretaker asked first of all")
        back.dismissAwayReport()
        try await Task.sleep(for: .milliseconds(Int(Slow.takes * 1000) + 500))
        XCTAssertNil(back.spoken[key], "no word kept for a card dismissed")
        XCTAssertNotEqual(back.voicing?.key, key)
    }
}

/// Gives the caretaker's word at once.
private struct Keeper: Voice {
    static let words = "You are home, my lord. Twelve watches passed; the granaries are fuller, and the realm was quiet about our walls."
    func speak(_ moment: VoiceMoment) async -> String? { Keeper.words }
}

/// Takes its time over every word, giving none once stopped.
private struct Slow: Voice {
    static let takes = 1.5
    func speak(_ moment: VoiceMoment) async -> String? {
        try? await Task.sleep(for: .seconds(Slow.takes))
        return Task.isCancelled ? nil : "Too late."
    }
}
