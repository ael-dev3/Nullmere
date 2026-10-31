import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// What is kept of the run under way, to know at the next launch whether it
/// ended as it should: the build, where the keeper was, and since when.
public struct RunMark: Codable, Equatable, Sendable {
    /// Where the keeper was.
    public enum Place: String, Codable, Sendable {
        case launcher
        case door
        case world

        var words: String {
            switch self {
            case .launcher: return "in the launcher"
            case .door: return "at the realm's front door"
            case .world: return "in the world"
            }
        }
    }

    public var version: String
    /// When the run began, and when the keeper came where they were, in
    /// seconds since 1970.
    public var began: Double
    public var place: Place
    public var since: Double
    /// The realm and the watch, in the world.
    public var realm: String?
    public var watch: Int?

    public init(version: String, began: Double, place: Place = .launcher, since: Double? = nil, realm: String? = nil, watch: Int? = nil) {
        self.version = version
        self.began = began
        self.place = place
        self.since = since ?? began
        self.realm = realm
        self.watch = watch
    }
}

/// The last run, when it stopped on a fault: where the keeper was, and what
/// stopped it, for the page the launcher opens on.
public struct Mishap: Equatable, Sendable {
    public let mark: RunMark
    /// What was caught as it stopped: a signal's name, or an exception.
    public let cause: String

    public init(mark: RunMark, cause: String) {
        self.mark = mark
        self.cause = cause
    }

    /// What stopped it, in a few words.
    public var what: String {
        let lines = cause.split(separator: "\n").map(String.init)
        if let exception = lines.first(where: { $0.hasPrefix("exception ") }) {
            return "an error it couldn't recover from (\(exception.dropFirst("exception ".count)))"
        }
        guard let signal = lines.last else { return "a fault" }
        switch signal {
        case "SIGTRAP", "SIGILL": return "a fault in the game itself (\(signal))"
        case "SIGSEGV", "SIGBUS": return "a fault reaching its memory (\(signal))"
        case "SIGABRT": return "a fault it gave up on (\(signal))"
        case "SIGFPE": return "a fault in its arithmetic (\(signal))"
        default: return "a fault (\(signal))"
        }
    }

    /// The page's account: where the keeper was, when, and what stopped it.
    public func account(timeZone: TimeZone = .current) -> String {
        var place = mark.place.words
        if mark.place == .world {
            let realm = mark.realm.map { " of \($0)" } ?? ""
            let watch = mark.watch.map { ", from the \(RunMark.ordinal($0)) watch" } ?? ""
            place = "in the world\(realm)\(watch)"
        }
        return "Nullmere Online stopped suddenly last time, \(place), on \(what). It began \(RunMark.time(mark.began, timeZone: timeZone))."
    }

    /// What a keeper's realm keeps whatever happened on their Mac.
    public static let reassurance = "Nothing of yours in the realm was lost: the realm holds your House, and after two watches a caretaker keeps it until you return."

    /// The report a keeper may send, the page's account with the build.
    public func report(timeZone: TimeZone = .current) -> String {
        """
        Nullmere Online \(mark.version) stopped suddenly.
        Where: \(mark.place.words)\(mark.realm.map { ", \($0)" } ?? "")\(mark.watch.map { ", watch \($0)" } ?? "")
        What: \(cause.split(separator: "\n").joined(separator: "; "))
        When: began \(RunMark.time(mark.began, timeZone: timeZone)), there since \(RunMark.time(mark.since, timeZone: timeZone))
        macOS keeps its own report in Console, under Crash Reports.
        """
    }

    /// Where the report goes: a new issue in the game's repository, written
    /// for the keeper to read before sending.
    public func reportAddress(timeZone: TimeZone = .current) -> URL? {
        var parts = URLComponents(string: "https://github.com/ael-dev3/Nullmere/issues/new")
        parts?.queryItems = [URLQueryItem(name: "title", value: "Nullmere Online \(mark.version) stopped \(mark.place.words)"),
                             URLQueryItem(name: "body", value: report(timeZone: timeZone))]
        return parts?.url
    }
}

extension RunMark {
    static func ordinal(_ number: Int) -> String {
        let tens = number % 100, ones = number % 10
        let suffix = (11...13).contains(tens) ? "th" : ones == 1 ? "st" : ones == 2 ? "nd" : ones == 3 ? "rd" : "th"
        return "\(number)\(suffix)"
    }

    static func time(_ seconds: Double, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMMM 'at' HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }
}

/// Keeps the mark of the run under way in a folder: written as the app
/// opens and as the keeper moves, let go as it quits as it should. A mark
/// left behind with a fault caught beside it is a run that stopped on that
/// fault; one with nothing beside it was quit by force, or the Mac stopped,
/// which the page doesn't make anything of.
public final class RunLedger: @unchecked Sendable {
    public let folder: URL
    /// The run before this one, if it stopped on a fault: read as the
    /// ledger is first made, before this run begins and lets it go.
    public let atLaunch: Mishap?
    private let lock = NSLock()
    private var mark: RunMark?

    public init(folder: URL) {
        self.folder = folder
        atLaunch = RunLedger.mishap(in: folder)
    }

    var markURL: URL { RunLedger.markURL(in: folder) }
    var causeURL: URL { RunLedger.causeURL(in: folder) }
    static func markURL(in folder: URL) -> URL { folder.appendingPathComponent("run.json") }
    static func causeURL(in folder: URL) -> URL { folder.appendingPathComponent("run-cause.txt") }

    /// The last run, if it stopped on a fault, as the folder holds it now.
    public func lastMishap() -> Mishap? {
        RunLedger.mishap(in: folder)
    }

    static func mishap(in folder: URL) -> Mishap? {
        guard let data = try? Data(contentsOf: markURL(in: folder)), let mark = try? JSONDecoder().decode(RunMark.self, from: data),
              let cause = try? String(contentsOf: causeURL(in: folder), encoding: .utf8) else { return nil }
        let caught = cause.trimmingCharacters(in: .whitespacesAndNewlines)
        return caught.isEmpty ? nil : Mishap(mark: mark, cause: caught)
    }

    /// This run begins, in the launcher: the last run's mark and cause let
    /// go, and the fault watch set on a fresh cause.
    public func begin(version: String, now: Double = Date().timeIntervalSince1970) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: causeURL)
        mark = RunMark(version: version, began: now)
        write()
        FaultWatch.watch(causeURL.path)
    }

    /// The keeper has come somewhere: noted, should the run stop there.
    /// Nothing is kept before the run begins, as in tests.
    public func note(_ place: RunMark.Place, realm: String? = nil, watch: Int? = nil, now: Double = Date().timeIntervalSince1970) {
        lock.lock()
        defer { lock.unlock() }
        guard var mark = self.mark else { return }
        mark.place = place
        mark.since = now
        mark.realm = realm
        mark.watch = watch
        self.mark = mark
        write()
    }

    /// The run ends as it should: nothing left behind.
    public func end() {
        lock.lock()
        defer { lock.unlock() }
        guard mark != nil else { return }
        mark = nil
        FaultWatch.stop()
        try? FileManager.default.removeItem(at: markURL)
        try? FileManager.default.removeItem(at: causeURL)
    }

    /// The mark as it stands, for tests.
    var current: RunMark? {
        lock.lock()
        defer { lock.unlock() }
        return mark
    }

    private func write() {
        guard let mark, let data = try? JSONEncoder().encode(mark) else { return }
        try? data.write(to: markURL, options: .atomic)
    }

    /// The app's own: in its Application Support folder.
    public static let shared = RunLedger(folder: (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory).appendingPathComponent("Nullmere Online", isDirectory: true))
}

/// Catches the faults that stop the app (a trap in the game's own code, a
/// bad reach for memory, an abort) and writes the fault's name to the cause
/// file before the app goes as it would have, so the next launch can say
/// what happened. What it does as the fault strikes is only what is safe
/// to do then: a fixed name written to a file opened beforehand.
public enum FaultWatch {
    /// The faults watched for.
    public static let signals: [Int32] = [SIGTRAP, SIGILL, SIGSEGV, SIGBUS, SIGABRT, SIGFPE]

    /// Watches, writing to the file at `path`, opened now.
    public static func watch(_ path: String) {
        stop()
        causeFile = open(path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        guard causeFile >= 0 else { return }
        for fault in signals {
            handlersBefore[fault] = signal(fault, faultHandler)
        }
    }

    /// Stops watching: the faults go where they went before.
    public static func stop() {
        guard causeFile >= 0 else { return }
        for fault in signals {
            signal(fault, handlersBefore[fault] ?? nil)
        }
        handlersBefore = [:]
        close(causeFile)
        causeFile = -1
    }

    /// Writes the fault's name, a line of its own, as the handler does.
    public static func record(_ fault: Int32) {
        recordFault(fault)
    }

    /// As a fault strikes: its name written, then the fault given back to
    /// the system, which ends the app and keeps its own report. Tests raise
    /// nothing.
    static func strike(_ fault: Int32, raising: (Int32) -> Int32 = raise) {
        recordFault(fault)
        signal(fault, nil)
        _ = raising(fault)
    }

    /// Writes a line the app caught in words (an exception's name and
    /// reason), before the fault that follows it.
    public static func record(exception: String) {
        guard causeFile >= 0 else { return }
        let line = "exception \(exception.replacingOccurrences(of: "\n", with: " "))\n"
        _ = line.withCString { write(causeFile, $0, strlen($0)) }
    }
}

/// The cause file, opened before any fault, for the handler to write to.
private var causeFile: Int32 = -1
/// What took each fault before the watch, given it back when it stops.
private var handlersBefore: [Int32: (@convention(c) (Int32) -> Void)?] = [:]

private func recordFault(_ fault: Int32) {
    guard causeFile >= 0 else { return }
    let name: StaticString
    switch fault {
    case SIGTRAP: name = "SIGTRAP\n"
    case SIGILL: name = "SIGILL\n"
    case SIGSEGV: name = "SIGSEGV\n"
    case SIGBUS: name = "SIGBUS\n"
    case SIGABRT: name = "SIGABRT\n"
    case SIGFPE: name = "SIGFPE\n"
    default: name = "SIGNAL\n"
    }
    _ = write(causeFile, name.utf8Start, name.utf8CodeUnitCount)
}

/// What takes a fault while the watch is set.
private func faultHandler(_ fault: Int32) {
    FaultWatch.strike(fault)
}
