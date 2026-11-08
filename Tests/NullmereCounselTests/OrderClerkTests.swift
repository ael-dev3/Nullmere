import Foundation
import XCTest
@testable import NullmereCore
@testable import NullmereCounsel

/// The House's clerk apart from the model's own words: where the model
/// can't read, the words read as the order book's lines as written and why
/// told, the model never asked; the model asked the briefing and the
/// keeper's words, its answer read against the keeper's view; its failures
/// and its slowness told as themselves; a reading stopped, nothing read.
/// The model's own reading is heard on a device that can run it.
final class OrderClerkTests: XCTestCase {
    private func world() -> (GameState, Int) {
        let state = GameState(settings: GameSettings(seedText: "order clerk", houseCount: 4, radius: 18, keepers: 1))
        return (state.view(for: state.player), state.player)
    }

    private actor Asked {
        var prompts: [String] = []
        func add(_ prompt: String) { prompts.append(prompt) }
    }

    func testWhereTheModelCantReadTheWordsAreReadAsWritten() async {
        let (world, me) = world()
        let asked = Asked()
        let clerk = OrderClerk(trouble: { .unavailable(.deviceNotEligible) }) { prompt in
            await asked.add(prompt)
            return "FORTIFY C1"
        }
        XCTAssertEqual(clerk.unavailable, CounselTrouble.unavailable(.deviceNotEligible).ordersReadAsWritten)
        let reading = await clerk.read("FORTIFY C1", in: world, player: me)
        XCTAssertFalse(reading.byModel)
        XCTAssertEqual(reading.trouble, CounselTrouble.unavailable(.deviceNotEligible).unreadOrders)
        XCTAssertEqual(reading.lines, SpokenOrders.read("FORTIFY C1", in: world, player: me))
        let prompts = await asked.prompts
        XCTAssertTrue(prompts.isEmpty, "The model is never asked where it can't answer")
    }

    func testTheModelIsAskedTheBriefingAndItsAnswerIsRead() async {
        let (world, me) = world()
        let asked = Asked()
        let clerk = OrderClerk(trouble: { nil }) { prompt in
            await asked.add(prompt)
            return "FORTIFY C1\nNONE"
        }
        XCTAssertNil(clerk.unavailable)
        let reading = await clerk.read("dig in my first company", in: world, player: me)
        XCTAssertTrue(reading.byModel)
        XCTAssertNil(reading.trouble)
        XCTAssertNotNil(reading.seconds)
        XCTAssertEqual(reading.lines, SpokenOrders.read("FORTIFY C1", in: world, player: me))
        let prompts = await asked.prompts
        XCTAssertEqual(prompts, [SpokenOrders.asking("dig in my first company", in: world, player: me)])
    }

    func testTheModelsTroubleIsToldAndTheWordsReadAsWritten() async {
        let (world, me) = world()
        let busy = await OrderClerk(trouble: { nil }) { _ in throw CounselTrouble.busy }.read("FORTIFY C1", in: world, player: me)
        XCTAssertFalse(busy.byModel)
        XCTAssertEqual(busy.trouble, CounselTrouble.busy.unreadOrders)
        XCTAssertEqual(busy.lines, SpokenOrders.read("FORTIFY C1", in: world, player: me))
        let other = NSError(domain: "stars", code: 7, userInfo: [NSLocalizedDescriptionKey: "The stars are wrong."])
        let strange = await OrderClerk(trouble: { nil }) { _ in throw other }.read("FORTIFY C1", in: world, player: me)
        XCTAssertEqual(strange.trouble, CounselTrouble.failed("The stars are wrong.").unreadOrders)
    }

    /// A silent failure, the model asked again why it can't read now: its
    /// reason told where it gives one (Apple Intelligence turned off
    /// meanwhile), the words read as written.
    func testASilentModelIsAskedWhyAgain() async {
        let (world, me) = world()
        final class Asked: @unchecked Sendable {
            private let lock = NSLock()
            private var count = 0
            func next() -> Int { lock.lock(); defer { lock.unlock() }; count += 1; return count }
        }
        let asked = Asked()
        let stock = NSError(domain: "FoundationModels.LanguageModelSession.GenerationError", code: -1)
        let clerk = OrderClerk(trouble: { asked.next() == 1 ? nil : .unavailable(.appleIntelligenceOff) }) { _ in throw stock }
        let reading = await clerk.read("FORTIFY C1", in: world, player: me)
        XCTAssertFalse(reading.byModel)
        XCTAssertEqual(reading.trouble, CounselTrouble.unavailable(.appleIntelligenceOff).unreadOrders)
        XCTAssertEqual(reading.lines, SpokenOrders.read("FORTIFY C1", in: world, player: me))
        let still = await OrderClerk(trouble: { nil }) { _ in throw stock }.read("FORTIFY C1", in: world, player: me)
        XCTAssertEqual(still.trouble, CounselTrouble.silent.unreadOrders, "Still able to be asked: the silence, as it was")
    }

    func testASlowModelIsGivenUp() async {
        let (world, me) = world()
        let slow = OrderClerk(trouble: { nil }, patience: 0.2) { _ in
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return "FORTIFY C1"
        }
        let began = Date()
        let reading = await slow.read("FORTIFY C1", in: world, player: me)
        XCTAssertLessThan(Date().timeIntervalSince(began), 5, "Given up, not waited for")
        XCTAssertFalse(reading.byModel)
        XCTAssertEqual(reading.trouble, CounselTrouble.slow.unreadOrders)
    }

    func testAReadingStoppedReadsNothing() async {
        let (world, me) = world()
        let clerk = OrderClerk(trouble: { nil }) { _ in
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return "FORTIFY C1"
        }
        let reading = Task { await clerk.read("FORTIFY C1", in: world, player: me) }
        try? await Task.sleep(nanoseconds: 100_000_000)
        reading.cancel()
        let read = await reading.value
        XCTAssertEqual(read, .stopped)
        XCTAssertTrue(read.takeable.isEmpty)
    }

    func testTheClerkIsToldTheOrderBooksWays() {
        XCTAssertTrue(OrderClerk.instructions.contains("reply NONE"))
        XCTAssertTrue(OrderClerk.instructions.contains("C1, C2"))
        XCTAssertGreaterThan(OrderClerk.patience, 0)
    }
}
