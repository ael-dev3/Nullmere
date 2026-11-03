import XCTest
@testable import NullmereCore

/// The realm's calendar: what is coming, foretold from its courses.
final class CalendarTests: XCTestCase {
    func testTheCalendarForetellsEachCourseOnItsWatch() throws {
        var state = Scene.world("calendar", houses: 4)
        let me = state.player
        state.watch = Happening.first + Happening.every - 5
        let entries = state.calendar(for: me)
        XCTAssertTrue(entries.allSatisfy { (state.watch + 1...state.watch + GameState.calendarSpan).contains($0.watch) })
        XCTAssertEqual(entries.map(\.watch), entries.map(\.watch).sorted(), "In the order it comes")
        let happening = try XCTUnwrap(entries.first { if case .happening = $0.kind { return true } else { return false } })
        XCTAssertEqual(happening.watch, Happening.first + Happening.every)
        for entry in entries {
            switch entry.kind {
            case .stillHour: XCTAssertTrue(GameState.isStillHour(at: entry.watch))
            case .fordOpens: XCTAssertTrue(GameState.fordOpen(at: entry.watch))
            case .fordCloses: XCTAssertFalse(GameState.fordOpen(at: entry.watch))
            case .dreams: XCTAssertEqual(GameState.moonAge(at: entry.watch), GameState.dreamingMoon)
            case .pedlar: XCTAssertEqual(GameState.pedlarComes(to: me, from: entry.watch), entry.watch)
            default: break
            }
            XCTAssertFalse(entry.title.isEmpty)
        }
        XCTAssertTrue(entries.contains { $0.kind == .stillHour })
        XCTAssertTrue(entries.contains { $0.kind == .pedlar }, "A keeper's own pedlar")
        XCTAssertFalse(state.calendar(for: 1).contains { $0.kind == .pedlar }, "A steward's House has none")
        // A keeper's copy foretells as the realm does.
        XCTAssertEqual(state.view(for: me).calendar(for: me), entries)
        // And the happening it named is the one that begins.
        guard case .happening(let kind) = happening.kind else { return XCTFail() }
        state.watch = happening.watch
        let begun = state.turnHappenings()
        XCTAssertTrue(begun.contains(.happeningBegun(kind: kind, ends: happening.watch + Happening.lasts)), "\(begun)")
        XCTAssertTrue(state.calendar(for: me).contains(CalendarEntry(watch: happening.watch + Happening.lasts, kind: .happeningEnds(kind))))
    }
}
