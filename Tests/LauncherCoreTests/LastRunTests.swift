import Foundation
import XCTest
@testable import LauncherCore

/// The mark of the run under way, let go as it ends as it should; a fault
/// caught as it stops, written beside it; and the page the next launch
/// opens on, saying what happened.
final class LastRunTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        FaultWatch.stop()
        try? FileManager.default.removeItem(at: folder)
    }

    private let utc = TimeZone(identifier: "UTC")!
    /// 31 October 2026, 18:42 UTC.
    private let evening = 1_793_472_120.0

    func testARunThatEndsAsItShouldLeavesNothing() throws {
        let ledger = RunLedger(folder: folder)
        XCTAssertNil(ledger.lastMishap(), "No run before")
        ledger.note(.world, realm: "The Nullmere", watch: 3)
        XCTAssertNil(ledger.current, "Nothing kept before the run begins, as in tests")
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledger.markURL.path))

        ledger.begin(version: "1.2.0", now: evening)
        XCTAssertEqual(ledger.current, RunMark(version: "1.2.0", began: evening))
        ledger.note(.door, now: evening + 60)
        ledger.note(.world, realm: "The Nullmere", watch: 23, now: evening + 90)
        let kept = try JSONDecoder().decode(RunMark.self, from: Data(contentsOf: ledger.markURL))
        XCTAssertEqual(kept, RunMark(version: "1.2.0", began: evening, place: .world, since: evening + 90, realm: "The Nullmere", watch: 23))
        XCTAssertNil(ledger.lastMishap(), "Under way, with no fault caught: nothing to tell")

        ledger.end()
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledger.markURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledger.causeURL.path))
        XCTAssertNil(ledger.lastMishap())
        ledger.end()
    }

    /// A fault as it strikes: its name written beside the mark, which the
    /// next launch reads as the run that stopped; the next run begun lets
    /// both go.
    func testAFaultCaughtIsToldAtTheNextLaunch() throws {
        let ledger = RunLedger(folder: folder)
        ledger.begin(version: "1.2.0", now: evening)
        ledger.note(.world, realm: "The Nullmere", watch: 23, now: evening + 90)
        FaultWatch.record(SIGSEGV)
        let mishap = try XCTUnwrap(RunLedger(folder: folder).lastMishap(), "The next launch reads it")
        XCTAssertEqual(mishap.cause, "SIGSEGV")
        XCTAssertEqual(mishap.mark.watch, 23)
        XCTAssertEqual(mishap.account(timeZone: utc),
                       "Nullmere Online stopped suddenly last time, in the world of The Nullmere, from the 23rd watch, on a fault reaching its memory (SIGSEGV). It began 31 October at 18:42.")

        // The next run begins: the last run's fault is let go, though the
        // ledger, made before, still holds what it found.
        let next = RunLedger(folder: folder)
        XCTAssertEqual(next.atLaunch, mishap)
        next.begin(version: "1.2.1", now: evening + 600)
        XCTAssertNil(next.lastMishap())
        XCTAssertEqual(next.atLaunch, mishap, "Read once, as it was made")
        next.end()
        XCTAssertNil(RunLedger(folder: folder).atLaunch)
    }

    /// An exception caught in words comes before the abort that follows it,
    /// and the page tells the exception.
    func testAnExceptionIsToldInItsOwnWords() throws {
        let ledger = RunLedger(folder: folder)
        ledger.begin(version: "1.2.0", now: evening)
        FaultWatch.record(exception: "NSRangeException: index 4 beyond\nbounds")
        FaultWatch.record(SIGABRT)
        let mishap = try XCTUnwrap(ledger.lastMishap())
        XCTAssertEqual(mishap.cause, "exception NSRangeException: index 4 beyond bounds\nSIGABRT")
        XCTAssertEqual(mishap.what, "an error it couldn't recover from (NSRangeException: index 4 beyond bounds)")
        XCTAssertTrue(mishap.account(timeZone: utc).hasPrefix("Nullmere Online stopped suddenly last time, in the launcher, on an error"))
    }

    /// Each fault in plain words; the place in each.
    func testEveryFaultAndPlaceIsSaidPlainly() {
        let mark = RunMark(version: "1.0.0", began: evening)
        for (cause, words) in [("SIGTRAP", "a fault in the game itself (SIGTRAP)"), ("SIGILL", "a fault in the game itself (SIGILL)"),
                               ("SIGBUS", "a fault reaching its memory (SIGBUS)"), ("SIGABRT", "a fault it gave up on (SIGABRT)"),
                               ("SIGFPE", "a fault in its arithmetic (SIGFPE)"), ("SIGNAL", "a fault (SIGNAL)")] {
            XCTAssertEqual(Mishap(mark: mark, cause: cause).what, words)
        }
        var door = mark
        door.place = .door
        XCTAssertTrue(Mishap(mark: door, cause: "SIGTRAP").account(timeZone: utc).contains("last time, at the realm's front door, on"))
        var world = mark
        world.place = .world
        XCTAssertTrue(Mishap(mark: world, cause: "SIGTRAP").account(timeZone: utc).contains("last time, in the world, on"), "Neither realm nor watch known")
        XCTAssertEqual(RunMark.ordinal(1), "1st")
        XCTAssertEqual(RunMark.ordinal(12), "12th")
        XCTAssertEqual(RunMark.ordinal(22), "22nd")
        XCTAssertEqual(RunMark.ordinal(103), "103rd")
        XCTAssertEqual(RunMark.ordinal(111), "111th")
        XCTAssertTrue(Mishap.reassurance.contains("caretaker"))
    }

    /// The report a keeper may send: the build, where, what and when, as a
    /// new issue in the repository for them to read before sending.
    func testTheReportSaysWhatHappenedForAnIssue() throws {
        let mark = RunMark(version: "1.2.0", began: evening, place: .world, since: evening + 90, realm: "The Nullmere", watch: 23)
        let mishap = Mishap(mark: mark, cause: "exception NSRangeException: out\nSIGABRT")
        let report = mishap.report(timeZone: utc)
        XCTAssertEqual(report, """
            Nullmere Online 1.2.0 stopped suddenly.
            Where: in the world, The Nullmere, watch 23
            What: exception NSRangeException: out; SIGABRT
            When: began 31 October at 18:42, there since 31 October at 18:43
            macOS keeps its own report in Console, under Crash Reports.
            """)
        let address = try XCTUnwrap(mishap.reportAddress(timeZone: utc))
        XCTAssertTrue(address.absoluteString.hasPrefix("https://github.com/ael-dev3/Nullmere/issues/new?"))
        let items = URLComponents(url: address, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "title" }?.value, "Nullmere Online 1.2.0 stopped in the world")
        XCTAssertEqual(items.first { $0.name == "body" }?.value, report)
    }

    /// A mark left with nothing caught beside it (quit by force, or the Mac
    /// stopped) makes no page, nor does a mark that can't be read.
    func testNothingCaughtMakesNoPage() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ledger = RunLedger(folder: folder)
        try JSONEncoder().encode(RunMark(version: "1.0.0", began: evening)).write(to: ledger.markURL)
        XCTAssertNil(ledger.lastMishap(), "No cause file")
        try Data("  \n".utf8).write(to: ledger.causeURL)
        XCTAssertNil(ledger.lastMishap(), "An empty cause")
        try Data("not a mark".utf8).write(to: ledger.markURL)
        try Data("SIGSEGV\n".utf8).write(to: ledger.causeURL)
        XCTAssertNil(ledger.lastMishap(), "A mark that can't be read")
        // With no watch set, nothing is written.
        FaultWatch.stop()
        FaultWatch.record(SIGBUS)
        FaultWatch.record(exception: "nothing")
        XCTAssertEqual(try String(contentsOf: ledger.causeURL, encoding: .utf8), "SIGSEGV\n")
        XCTAssertEqual(FaultWatch.signals.count, 6)
        // A cause file that can't be opened: nothing is watched.
        FaultWatch.watch(folder.appendingPathComponent("no such folder/run-cause.txt").path)
        FaultWatch.record(SIGBUS)
        XCTAssertEqual(try String(contentsOf: ledger.causeURL, encoding: .utf8), "SIGSEGV\n")
        XCTAssertEqual(Mishap(mark: RunMark(version: "1", began: 0), cause: "").what, "a fault", "Nothing said of it")
    }

    /// As a fault strikes, the handler writes its name and gives the fault
    /// back to the system (here, raising nothing); a signal not watched for
    /// is written by a name of its own.
    func testAFaultStrikesAndIsGivenBack() throws {
        let ledger = RunLedger(folder: folder)
        ledger.begin(version: "1.0.0", now: evening)
        var raised: [Int32] = []
        FaultWatch.strike(SIGFPE) { raised.append($0); return 0 }
        FaultWatch.record(SIGUSR1)
        XCTAssertEqual(raised, [SIGFPE], "Given back to the system")
        XCTAssertEqual(try String(contentsOf: ledger.causeURL, encoding: .utf8), "SIGFPE\nSIGNAL\n")
        XCTAssertEqual(ledger.lastMishap()?.what, "a fault (SIGNAL)")
        ledger.end()
    }

    /// The app's own ledger lies in its Application Support folder.
    func testTheAppsLedgerLiesInItsOwnFolder() {
        XCTAssertEqual(RunLedger.shared.folder.lastPathComponent, "Nullmere Online")
        XCTAssertNil(RunLedger.shared.current, "Not begun outside the app")
    }
}
