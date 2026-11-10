import AppKit
import FoundationModels
@testable import LauncherKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// Words for the House's dead from this Mac's own model, for a vigil:
/// asked from what the House's own reports tell of where and when its
/// companies fell; written, taken into the vigil's words with their
/// seconds; stopped mid-writing, nothing kept; troubled, the reason said;
/// with no model on this Mac, why not said before the keeper asks.
@MainActor
final class VigilWordsTests: XCTestCase {
    /// Writes the same words for any moment, and keeps what it was asked.
    private actor Mourner: Voice {
        let words: String?
        private(set) var asked: [VoiceMoment] = []

        init(words: String?) {
            self.words = words
        }

        func speak(_ moment: VoiceMoment) async -> String? {
            asked.append(moment)
            return words
        }
    }

    /// Writes slowly, until stopped, and keeps that it was.
    private actor SlowMourner: Voice {
        private(set) var stopped = false

        func speak(_ moment: VoiceMoment) async -> String? {
            try? await Task.sleep(for: .seconds(30))
            if Task.isCancelled { stopped = true }
            return "Too late"
        }
    }

    /// Writes nothing, and says why.
    private struct TroubledMourner: Voice {
        func speak(_ moment: VoiceMoment) async -> String? { nil }

        func speaking(_ moment: VoiceMoment) async -> WordsHeard {
            WordsHeard(words: nil, trouble: .slow)
        }
    }

    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        PressableButtons.isListening = true
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 330, height: CGFloat = 320) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    /// A keeper's House with a hold on the shore and two companies of war
    /// fallen, unmourned.
    private func world() throws -> (GameState, me: Int, hold: Hold) {
        var state = GameState(settings: GameSettings(seedText: "words for the dead", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock = Stock(grain: 300, timber: 100, stone: 100, moonsalt: 10)
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && state.map.neighbors(of: hex).contains { [.still, .shallows].contains(state.map[$0]?.terrain) }
        })
        let hold = Hold(id: state.takeID(), name: "Mournwater", owner: me, position: shore, isSeat: false, foundedWatch: 1)
        state.holds.append(hold)
        state.houses[me].unmourned = 2
        return (state, me, hold)
    }

    private func waitForWords(in session: GameSession) async throws {
        for _ in 0..<300 where session.vigilWording != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNil(session.vigilWording, "Done writing")
    }

    func testTheModelWritesWordsForTheDeadFromTheHousesOwnReports() async throws {
        let (state, me, hold) = try world()
        let mourner = Mourner(words: "For the spears who fell at the ford,   the water keeps their names.")
        let session = GameSession(state: state, store: LocalStore(directory: dir), voice: mourner)
        draw(VigilComposer(session: session, hold: hold, open: true))
        XCTAssertTrue(PressableButtons.press("Words from your Mac's model"), "Among \(shown)")
        XCTAssertNotNil(session.vigilWording, "The model at work")
        XCTAssertTrue(VigilWordingLine.atWork(began: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 1.44))
            .hasSuffix("writes words for your dead… 1.4 s"))
        draw(VigilComposer(session: session, hold: hold, open: true))
        XCTAssertTrue(shown.contains("Stop"), "Stopped at any moment, among \(shown)")
        try await waitForWords(in: session)
        let written = try XCTUnwrap(session.vigilWords)
        XCTAssertEqual(written.words, "For the spears who fell at the ford, the water keeps their names.", "Held to the words the realm carries")
        XCTAssertGreaterThanOrEqual(written.seconds, 0)
        XCTAssertEqual(VigilWordingLine.written(in: 2.44), "Written by Apple's on-device model in 2.4 s: keep them or change them.")
        draw(VigilComposer(session: session, hold: hold, open: true, draft: written.words))
        XCTAssertNil(session.vigilUnworded)

        // Asked as a vigil, from the House's own numbers.
        // The vigil among what the model was asked (the steward's welcome to
        // a House newly taken up comes before it).
        let heard = await mourner.asked
        let asked = try XCTUnwrap(heard.first { $0.kind == .vigil })
        XCTAssertEqual(asked.kind, .vigil)
        XCTAssertTrue(asked.facts.contains("Companies of war of theirs fallen in battle: 2."), "\(asked.facts)")
        XCTAssertTrue(asked.facts.contains { $0.hasPrefix("The dead were of \(state.houses[me].title)") })
        XCTAssertTrue(asked.prompt.contains("with no vow of vengeance"))

        // Kept, the next vigil begins with no words.
        XCTAssertTrue(session.perform(.keepVigil(words: written.words, hold: hold.id)))
        session.letVigilWordsBe()
        XCTAssertNil(session.vigilWords)
    }

    func testTheReportsOfBattlesLostAreWhereTheyFell() throws {
        let (state, me, _) = try world()
        let lost = BattleReport(id: 1, watch: 7, title: "Your Spears fell", place: "at Wenholme", outcome: .lost, lines: [])
        var field = BattleReport(id: 2, watch: 9, title: "Neither side gave way", place: "on the strand by Galstead", outcome: .held, lines: [])
        field.sides = [BattleReport.Side(title: "Your side", houses: 1, companies: 3, troops: 3_000, lost: 900, fallen: 1),
                       BattleReport.Side(title: "House Brine's side", houses: 1, companies: 2, troops: 2_000, lost: 400, fallen: 0)]
        let won = BattleReport(id: 3, watch: 10, title: "Your side held the field", place: "at Tirford", outcome: .won, lines: [])
        let moment = VoiceFacts.vigil(of: me, in: state, reports: [lost, field, won])
        XCTAssertTrue(moment.facts.contains("Some fell at Wenholme in watch 7."), "\(moment.facts)")
        XCTAssertTrue(moment.facts.contains("Some fell on the strand by Galstead in watch 9, against House Brine's side."), "\(moment.facts)")
        XCTAssertFalse(moment.facts.contains { $0.contains("Tirford") }, "Won without loss, none fell there")
        XCTAssertEqual(moment.facts.last, "The light is set on the water in watch \(state.watch).")
    }

    func testStoppedMidWritingNothingIsKept() async throws {
        let (state, _, hold) = try world()
        let mourner = SlowMourner()
        let session = GameSession(state: state, store: LocalStore(directory: dir), voice: mourner)
        session.wordVigil()
        XCTAssertNotNil(session.vigilWording)
        session.wordVigil()
        try await Task.sleep(for: .milliseconds(50))
        draw(VigilComposer(session: session, hold: hold, open: true))
        XCTAssertTrue(PressableButtons.press("Stop"), "Among \(shown)")
        XCTAssertNil(session.vigilWording, "Stopped at once")
        var waited = 0
        while await !mourner.stopped, waited < 200 {
            try await Task.sleep(for: .milliseconds(10))
            waited += 1
        }
        let stopped = await mourner.stopped
        XCTAssertTrue(stopped, "The model's asking cancelled with it")
        XCTAssertNil(session.vigilWords, "Nothing written kept")
        XCTAssertNil(session.vigilUnworded)
    }

    func testWhyTheModelWroteNoneIsSaid() async throws {
        let (state, _, hold) = try world()
        let session = GameSession(state: state, store: LocalStore(directory: dir), voice: TroubledMourner())
        session.wordVigil()
        try await waitForWords(in: session)
        XCTAssertNil(session.vigilWords)
        XCTAssertEqual(session.vigilUnworded, "No answer came from Apple's on-device model in time, so the words for your dead are yours to write.")
        draw(VigilComposer(session: session, hold: hold, open: true))

        // Garbled or silent, still said.
        let silent = GameSession(state: state, store: LocalStore(directory: dir), voice: Mourner(words: nil))
        silent.wordVigil()
        try await waitForWords(in: silent)
        XCTAssertEqual(silent.vigilUnworded, CounselTrouble.silent.unwritten)
        let garbled = GameSession(state: state, store: LocalStore(directory: dir), voice: Mourner(words: "http://nowhere"))
        garbled.wordVigil()
        try await waitForWords(in: garbled)
        XCTAssertEqual(garbled.vigilUnworded, CounselTrouble.garbled.unwritten, "Words the realm wouldn't carry are none")
    }

    func testWithNoModelOnThisMacWhyNotIsSaidBeforeAsking() throws {
        let (state, _, hold) = try world()
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.counselAvailability = { .unavailable(.deviceNotEligible) }
        XCTAssertEqual(session.vigilWordsUnwritten, "This device can't run Apple's on-device model, so the words for your dead are yours to write.")
        PressableButtons.forget("Words from your Mac's model")
        draw(VigilComposer(session: session, hold: hold, open: true))
        XCTAssertFalse(PressableButtons.press("Words from your Mac's model"), "No model to ask")
        session.wordVigil()
        XCTAssertNil(session.vigilWording, "Nothing asked of a model that isn't there")
        session.counselAvailability = { .unavailable(.appleIntelligenceNotEnabled) }
        XCTAssertEqual(session.vigilWordsUnwritten,
                       "Apple Intelligence is turned off in System Settings, so the words for your dead are yours to write.")
        session.counselAvailability = { .available }
        XCTAssertNil(session.vigilWordsUnwritten, "Ready since the game began: nothing to say before asking")
        let voiced = GameSession(state: state, store: LocalStore(directory: dir), voice: Mourner(words: "x"))
        XCTAssertNil(voiced.vigilWordsUnwritten)
    }
}
