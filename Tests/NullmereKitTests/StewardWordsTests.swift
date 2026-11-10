import AppKit
import NullmereModels
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The steward who kept the House welcoming its keeper the first time they
/// take it up: this Mac's model is asked first of all, under the watch the
/// House was taken up at, from what the House knows alone; the briefing
/// card shows the welcome above its facts; begun before the welcome comes,
/// its asking stops and nothing of it is kept.
@MainActor
final class StewardWordsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func world() -> GameState {
        var state = GameState(settings: GameSettings(seedText: "the steward's welcome", houseCount: 4, radius: 16, keepers: 1))
        for _ in 0..<6 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        return state
    }

    func testTheStewardWelcomesTheKeeperAboveTheBriefing() async throws {
        let state = world()
        let me = state.player
        let session = GameSession(link: WelcomeLink(), house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Steward())
        let briefing = try XCTUnwrap(session.seatBriefing, "a House new to the keeper is briefed")
        XCTAssertEqual(briefing.watch, state.watch)
        let key = GameSession.Spoken.steward(briefing.watch)
        XCTAssertEqual(key.key, "steward-\(briefing.watch)")
        XCTAssertEqual(GameSession.Spoken(key: key.key), key)
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[key] == nil, session.unvoiced[key] == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(session.spoken[key], Steward.words, "kept under the watch the House was taken up at")
        let moment = try XCTUnwrap(VoiceFacts.steward(for: me, in: session.state))
        XCTAssertEqual(moment.kind, .steward)
        XCTAssertEqual(moment.facts, try XCTUnwrap(session.state.stewardWelcome(for: me)).facts)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.stewardTask), moment.prompt)
        XCTAssertTrue(session.stillVoiced(key), "wanted while the briefing stands")
        // The briefing card shows the welcome, kept with CI's screenshots.
        try CardShot.keep(SeatBriefingCard(briefing: briefing, colour: .orange, session: session) {}.padding(20),
                          as: "game-briefing-steward.png")
        session.dismissSeatBriefing()
        XCTAssertFalse(session.stillVoiced(key), "the briefing put away, the welcome wanted no longer")
    }

    func testBegunBeforeTheWelcomeComesItsAskingStops() async throws {
        let state = world()
        let me = state.player
        let session = GameSession(link: WelcomeLink(), house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Lingering())
        let key = GameSession.Spoken.steward(try XCTUnwrap(session.seatBriefing).watch)
        let deadline = Date().addingTimeInterval(5)
        while session.voicing?.key != key, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(session.voicing?.key, key, "asked first of all")
        session.dismissSeatBriefing()
        let stopped = Date().addingTimeInterval(5)
        while session.voicing?.key == key, Date() < stopped { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNotEqual(session.voicing?.key, key, "its asking stopped")
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(session.spoken[key], "nothing of it kept")
    }
}

/// Gives the steward's welcome at once.
private struct Steward: Voice {
    static let words = "The House is yours, keeper. We kept its seat by the Still and its peace with every House, and give both into your hands."
    func speak(_ moment: VoiceMoment) async -> String? { moment.kind == .steward ? Steward.words : nil }
}

/// Gives words only after a long while, so the asking may be stopped.
private struct Lingering: Voice {
    func speak(_ moment: VoiceMoment) async -> String? {
        try? await Task.sleep(for: .seconds(4))
        return Task.isCancelled ? nil : "Too late to greet anyone."
    }
}

/// A realm that hears nothing it is sent.
private final class WelcomeLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
