import AppKit
import LauncherKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// Orders in the keeper's own words: the card opened by its key, the words
/// read by this Mac's model into the order book's lines, each shown with
/// what it would do or why it can't be given, and those the realm would
/// take given together; without the model, the order book's own lines
/// read as they are written.
@MainActor
final class OrdersCardTests: XCTestCase {
    /// Reads any words as the same lines, and keeps what it was asked.
    private actor Clerk: Voice {
        let answer: String?
        private(set) var asked: [(words: String, briefing: String)] = []

        init(answer: String?) {
            self.answer = answer
        }

        func speak(_ moment: VoiceMoment) async -> String? { nil }

        func read(orders words: String, briefing: String) async -> String? {
            asked.append((words, briefing))
            return answer
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

    private func draw(_ view: some View, width: CGFloat = 460, height: CGFloat = 300) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "orders in words", houseCount: 4, radius: 18, keepers: 1, rivers: true))
    }

    private func waitForReading(in session: GameSession) async throws {
        for _ in 0..<300 where session.ordersInWords?.reading == true {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(session.ordersInWords?.reading, false)
    }

    func testWordsAreReadIntoOrdersAndGivenTogether() async throws {
        let state = world()
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let companies = SpokenOrders.companies(in: state, player: me)
        let first = try XCTUnwrap(companies.first { $0.kind.isMilitary })
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == first.id }) + 1)"
        let clerk = Clerk(answer: "FORTIFY \(handle)\nBUILD Granary AT \(seat.name)\nTRAIN Dragons AT \(seat.name)")
        let session = GameSession(state: state, store: LocalStore(directory: dir), voice: clerk)
        session.dismissSeatBriefing()
        XCTAssertTrue(session.readsOrders)

        // Opened by its key, the line empty: nothing to read yet.
        XCTAssertNil(session.ordersInWords)
        XCTAssertTrue(session.handle(.orders))
        XCTAssertNotNil(session.ordersInWords)
        draw(OrdersCard(session: session))
        XCTAssertFalse(PressableButtons.press("Read"), "Nothing written: \(shown)")
        XCTAssertFalse(PressableButtons.press(OrdersCard.giveTitle(0)), "Nothing read yet")

        // Written in the keeper's words, read by the clerk with the briefing.
        let words = "Dig in my first company, raise a granary at home, and train dragons."
        draw(OrdersCard(session: session, words: words))
        XCTAssertTrue(PressableButtons.press("Read"), "Among \(shown)")
        XCTAssertEqual(session.ordersInWords?.reading, true)
        draw(OrdersCard(session: session))
        try await waitForReading(in: session)
        let asked = await clerk.asked
        XCTAssertEqual(asked.map { $0.words }, [words])
        XCTAssertEqual(asked.first?.briefing, SpokenOrders.briefing(for: state, player: me))
        let lines = try XCTUnwrap(session.ordersInWords?.lines)
        XCTAssertEqual(lines.map(\.command), [.fortify(unit: first.id), .build(hold: seat.id, kind: .granary), nil])
        XCTAssertNil(lines[0].why, "A fresh company may dig in")
        XCTAssertEqual(lines[2].why, "No company goes by the name Dragons.")
        XCTAssertEqual(OrderLine.spoken(lines[2]), "\(lines[2].told) Can't be given: No company goes by the name Dragons.")
        XCTAssertEqual(OrderLine.spoken(lines[0]), lines[0].told)
        XCTAssertFalse(session.ordersInWords?.unread ?? true)

        // Those the realm would take, given together; the card put away.
        let givable = lines.filter { $0.command != nil && $0.why == nil }
        draw(OrdersCard(session: session))
        XCTAssertTrue(PressableButtons.press(OrdersCard.giveTitle(givable.count)), "Among \(shown)")
        XCTAssertNil(session.ordersInWords, "Given, the card is put away")
        XCTAssertEqual(session.state.unit(first.id)?.fortified, true)
        XCTAssertEqual(session.giveOrders(), 0, "No card, nothing to give")
    }

    /// Without the model, the order book's lines read as they are written;
    /// words read again outdo a reading still under way; words that make
    /// no orders say so and leave nothing to give; Escape puts it away.
    func testWithoutTheModelTheOrderBooksLinesAreReadAsWritten() async throws {
        let state = world()
        let me = state.player
        let companies = SpokenOrders.companies(in: state, player: me)
        let first = try XCTUnwrap(companies.first { $0.kind.isMilitary })
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == first.id }) + 1)"
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        XCTAssertFalse(session.readsOrders)
        XCTAssertEqual(OrdersCard.prompt(readByModel: false), "Order book lines, as MARCH C1 TO a place")
        XCTAssertEqual(OrdersCard.prompt(readByModel: true), "Your orders, in your own words")
        XCTAssertEqual(OrdersCard.giveTitle(1), "Give the order")
        XCTAssertEqual(OrdersCard.giveTitle(3), "Give 3 orders")

        session.readOrders("FORTIFY \(handle)")
        XCTAssertNil(session.ordersInWords, "Nothing is read with the card put away")
        session.toggleOrders()
        session.readOrders("   ")
        XCTAssertEqual(session.ordersInWords?.serial, 0, "Nothing written, nothing read")

        session.readOrders("HALT \(handle)")
        session.readOrders("FORTIFY \(handle)")
        try await waitForReading(in: session)
        XCTAssertEqual(session.ordersInWords?.lines.map(\.command), [.fortify(unit: first.id)], "The later reading stands")
        draw(OrdersCard(session: session))

        session.readOrders("Bring me the moon in a bucket")
        try await waitForReading(in: session)
        XCTAssertEqual(session.ordersInWords?.lines, [])
        XCTAssertEqual(session.ordersInWords?.unread, true)
        draw(OrdersCard(session: session))
        XCTAssertEqual(session.giveOrders(), 0, "Nothing to give")
        XCTAssertNotNil(session.ordersInWords, "The card stays to be written again")

        XCTAssertTrue(session.handle(.escape))
        XCTAssertNil(session.ordersInWords, "Escape puts it away first")
        session.panel = .guide
        XCTAssertTrue(session.handle(.orders))
        XCTAssertTrue(session.handle(.orders))
        XCTAssertNil(session.ordersInWords, "Its key puts it away too")
        XCTAssertEqual(session.panel, .guide, "The panel open stays open")
    }

    /// No orders once the age has ended, nor from a House that has fallen.
    func testNoOrdersAfterTheAgeNorFromAFallenHouse() {
        var ended = world()
        ended.outcome = Outcome(winner: ended.player, kind: .ascendancy, watch: ended.watch)
        let after = GameSession(state: ended, store: LocalStore(directory: dir))
        after.toggleOrders()
        XCTAssertNil(after.ordersInWords)
        var fallen = world()
        fallen.houses[fallen.player].isEliminated = true
        let gone = GameSession(state: fallen, store: LocalStore(directory: dir))
        gone.dismissSeatBriefing()
        XCTAssertTrue(gone.handle(.orders))
        XCTAssertNil(gone.ordersInWords)
    }
}
