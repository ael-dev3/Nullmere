import AppKit
import NullmereCore
import SwiftUI
import XCTest
@testable import NullmereKit

@MainActor
final class AwayReportTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func later(_ state: GameState, by watches: Int) -> GameState {
        var world = state
        for _ in 0..<watches {
            _ = world.stewardTurn(for: world.player)
            _ = world.endWatch()
        }
        return world
    }

    func testAReturningKeeperHearsWhatPassedWhileAway() throws {
        let store = LocalStore(directory: dir)
        let state = GameState(settings: GameSettings(seedText: "away a while", houseCount: 4, radius: 16))
        let first = GameSession(state: state, store: store)
        XCTAssertNil(first.awayReport, "The first time in, there's nothing to tell")

        let world = later(state, by: 24)
        let back = GameSession(state: world, store: store)
        let report = try XCTUnwrap(back.awayReport)
        XCTAssertEqual(report.watches, 24)
        XCTAssertEqual(report.title, "While you were away, 24 watches passed")
        XCTAssertLessThanOrEqual(report.news.count, AwayReport.lines)
        let told = world.chronicle.filter { $0.watch > 1 && ($0.houses.contains(state.player) || $0.kind == .fall || $0.kind == .ending) }
        XCTAssertEqual(report.news, Array(told.suffix(AwayReport.lines).map(\.text)))
        XCTAssertEqual(report.holdsChange, world.holds(of: state.player).count - state.holds(of: state.player).count)
        for change in report.changes {
            XCTAssertEqual(change.delta, world.houses[state.player].stock[change.resource] - state.houses[state.player].stock[change.resource])
        }
        back.dismissAwayReport()
        XCTAssertNil(back.awayReport)

        // Seen now: entering again tells nothing new.
        XCTAssertNil(GameSession(state: world, store: store).awayReport)
        try keep(AwayCard(report: report) {}, as: "game-away.png")
    }

    func testAKeeperTakingUpTheirHouseIsBriefedOnce() throws {
        let store = LocalStore(directory: dir)
        var state = GameState(settings: GameSettings(seedText: "taking a seat", houseCount: 5, radius: 16))
        let rival = try XCTUnwrap(state.houses.first { !$0.isPlayer })
        _ = try state.perform(.declareWar(on: rival.id), as: state.player)
        // Three watches pass; the rivals' offers wait on the keeper's answer.
        for _ in 0..<3 { _ = state.endWatch() }
        let session = GameSession(state: state, store: store)
        let briefing = try XCTUnwrap(session.seatBriefing)
        XCTAssertNil(session.awayReport, "The first time in, a briefing, not a report")
        XCTAssertEqual(briefing.title, "You take up \(state.houses[state.player].title)")
        let seat = try XCTUnwrap(state.seat(of: state.player))
        XCTAssertTrue(briefing.facts[0].hasPrefix("Your seat is \(seat.name)"))
        XCTAssertTrue(briefing.facts.contains("The age is at watch 4; the stewards kept your House until now."))
        XCTAssertTrue(briefing.facts.contains { $0.contains("You are at war with") && $0.contains(rival.title) }, "\(briefing.facts)")
        XCTAssertTrue(briefing.facts.contains { $0.hasPrefix("Of 5 Houses around the lake, yours is ") })
        XCTAssertEqual(briefing.steps.count, state.holds(of: state.player).contains { $0.project == nil } ? 3 : 2)
        XCTAssertTrue(briefing.steps.last!.contains("⌘↩"))
        session.dismissSeatBriefing()
        XCTAssertNil(session.seatBriefing)
        XCTAssertNil(GameSession(state: state, store: store).seatBriefing, "Once an age")
        try keep(SeatBriefingCard(briefing: briefing, colour: .orange) {}, as: "game-briefing.png")

        XCTAssertEqual(SeatBriefing.list(["A", "B", "C"]), "A, B and C")
        XCTAssertEqual(SeatBriefing.ordinal(12), "twelfth")
    }

    func testTheReportSpeaksPlainly() throws {
        let state = GameState(settings: GameSettings(seedText: "plain words", houseCount: 3, radius: 16))
        let seen = LastSeen(watch: state.watch, stock: state.houses[state.player].stock, holds: state.holds(of: state.player).count)
        XCTAssertNil(AwayReport(since: seen, now: state, player: state.player), "No watch passed")
        let one = try XCTUnwrap(AwayReport(since: seen, now: later(state, by: 1), player: state.player))
        XCTAssertEqual(one.title, "While you were away, a watch passed")
        let moreHolds = LastSeen(watch: 0, stock: seen.stock, holds: seen.holds - 2)
        XCTAssertEqual(AwayReport(since: moreHolds, now: state, player: state.player)?.holdsLine, "You hold 2 more holds.")
        let fewer = LastSeen(watch: 0, stock: seen.stock, holds: seen.holds + 1)
        XCTAssertEqual(AwayReport(since: fewer, now: state, player: state.player)?.holdsLine, "You lost a hold.")
    }

    /// Writes the card where CI prints its screenshots.
    private func keep(_ view: some View, as name: String) throws {
        let renderer = ImageRenderer(content: view.padding(30).background(Color.black))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        guard let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] else { return }
        let build = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: build.appendingPathComponent(name))
    }
}
