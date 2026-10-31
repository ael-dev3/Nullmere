import AppKit
import LauncherKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// A deed of the House's own made a ballad on this Mac, from the
/// Chronicle: asked for, read, sung to the realm or let be, and kept in
/// the realm's songbook for every House to read.
@MainActor
final class BalladPanelTests: XCTestCase {
    /// Makes every ballad the same two lines, at once.
    private struct Bard: Voice {
        func speak(_ moment: VoiceMoment) async -> String? { nil }

        func compose(_ moment: VoiceMoment) async -> String? {
            "The black water held the moon,\nand the walls of Vael fell."
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

    private func draw(_ view: some View, width: CGFloat = 400, height: CGFloat = 700) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    private func waitForDraft(of entry: Int, in session: GameSession) async throws {
        for _ in 0..<300 where session.balladDrafts[entry] == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func testADeedIsMadeABalladReadAndSung() async throws {
        var state = GameState(settings: GameSettings(seedText: "a ballad made", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        state.record(.battle, [me], "A battle at the Grey Ford: forty thousand troops met.")
        let entry = state.chronicle.count - 1
        let session = GameSession(state: state, store: LocalStore(directory: dir), voice: Bard())
        session.dismissSeatBriefing()
        XCTAssertTrue(session.makesBallads)

        // Asked for from the deed in the History, and read there.
        draw(ChroniclePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Make a ballad"), "Among \(shown)")
        try await waitForDraft(of: entry, in: session)
        XCTAssertEqual(session.balladDrafts[entry], "The black water held the moon,\nand the walls of Vael fell.")
        XCTAssertFalse(session.composing.contains(entry))
        draw(ChroniclePanel(session: session))

        // Sung to the realm: kept in the songbook, and under the deed.
        XCTAssertTrue(PressableButtons.press("Sing it"), "Among \(shown)")
        XCTAssertNil(session.balladDrafts[entry])
        let ballad = try XCTUnwrap(session.state.songbook.last)
        XCTAssertEqual(ballad.lines, ["The black water held the moon,", "and the walls of Vael fell."])
        XCTAssertEqual(ballad.entry, entry)
        draw(ChroniclePanel(session: session))
        XCTAssertFalse(PressableButtons.press("Make a ballad"), "Sung once: \(shown)")
        draw(ChroniclePanel(session: session, shown: .songs))
        XCTAssertEqual(Songbook.heading(ballad, in: session.state),
                       "\(session.state.houses[me].title), of the \(SeatBriefing.ordinal(state.chronicle[entry].watch)) watch: "
                       + "A battle at the Grey Ford: forty thousand troops met.")
        XCTAssertEqual(ChroniclePanel.subtitle(.songs), "The ballads the keepers have sung this age")
        XCTAssertFalse(session.singBallad(of: entry), "Nothing left to sing")
    }

    func testABalladMadeMayBeAskedAgainOrLetBe() async throws {
        var state = GameState(settings: GameSettings(seedText: "a ballad let be", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        state.record(.capture, [me], "Vael is taken by storm.")
        let entry = state.chronicle.count - 1
        let session = GameSession(state: state, store: LocalStore(directory: dir), voice: Bard())
        session.dismissSeatBriefing()
        session.makeBallad(of: entry)
        try await waitForDraft(of: entry, in: session)
        draw(ChroniclePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Another"), "Among \(shown)")
        try await waitForDraft(of: entry, in: session)
        XCTAssertNotNil(session.balladDrafts[entry])
        draw(ChroniclePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Let it be"), "Among \(shown)")
        XCTAssertNil(session.balladDrafts[entry])
        XCTAssertTrue(session.state.songbook.isEmpty, "Unsung")

        // Of a deed not its own, none is made; nor without a voice.
        session.makeBallad(of: 0)
        XCTAssertTrue(session.composing.isEmpty)
        let silent = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("silent")))
        XCTAssertFalse(silent.makesBallads)
        silent.makeBallad(of: entry)
        XCTAssertTrue(silent.composing.isEmpty)
        // An empty songbook says how one is filled.
        draw(ChroniclePanel(session: silent, shown: .songs))
    }
}
