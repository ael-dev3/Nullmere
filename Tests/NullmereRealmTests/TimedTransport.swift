import Foundation
@testable import NullmereRealm

/// A transport whose every call and query is timed, kept in a log shared
/// by a crowd's clients and its steward: what their seconds went on.
final class TimedTransport: SpacetimeTransport, @unchecked Sendable {
    struct Entry {
        let who: String
        let what: String
        let start: Double
        let took: Double
        let bytes: Int
    }

    final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [Entry] = []

        func add(_ entry: Entry) {
            lock.lock()
            entries.append(entry)
            lock.unlock()
        }

        func entries(from start: Double, to end: Double) -> [Entry] {
            lock.lock()
            defer { lock.unlock() }
            return entries.filter { $0.start >= start && $0.start <= end }
        }

        /// What each kind of request took between `start` and `end`, the
        /// steward's and the keepers' apart: how many, how long at the
        /// half and the ninetieth part and at most, and the kilobytes read.
        func told(from start: Double, to end: Double) -> String {
            let window = entries(from: start, to: end)
            let kinds = Dictionary(grouping: window) { "\($0.who == "steward" ? "steward" : "keepers") \($0.what)" }
            return kinds.sorted { $0.key < $1.key }.map { kind, entries in
                let took = entries.map(\.took).sorted()
                func at(_ part: Double) -> Double { took[min(took.count - 1, Int(Double(took.count) * part))] }
                return String(format: "%@ ×%d: %.0f/%.0f/%.0f ms, %d KB", kind, entries.count, at(0.5) * 1000, at(0.9) * 1000,
                              (took.last ?? 0) * 1000, entries.reduce(0) { $0 + $1.bytes } / 1024)
            }.joined(separator: "; ")
        }

        /// The steward's requests between `start` and `end`, each as when
        /// it began after `start` and how long it took.
        func stewardsRound(from start: Double, to end: Double) -> String {
            entries(from: start, to: end).filter { $0.who == "steward" }.map {
                String(format: "%@ +%.2f s %.0f ms", $0.what, $0.start - start, $0.took * 1000)
            }.joined(separator: ", ")
        }
    }

    let inner: any SpacetimeTransport
    let who: String
    let log: Log

    init(_ inner: any SpacetimeTransport, who: String, log: Log) {
        self.inner = inner
        self.who = who
        self.log = log
    }

    /// A query's kind: the table it reads, and how.
    static func kind(of sql: String) -> String {
        let words = sql.split(separator: " ")
        let table = words.firstIndex(of: "FROM").flatMap { words.indices.contains($0 + 1) ? String(words[$0 + 1]) : nil } ?? "?"
        if sql.contains("name =") { return table + " by name" }
        if sql.contains("version >") { return table + " since" }
        return table
    }

    private func timed<T>(_ what: String, bytes: (T) -> Int = { _ in 0 }, _ body: () async throws -> T) async throws -> T {
        let start = Date().timeIntervalSince1970
        do {
            let result = try await body()
            log.add(Entry(who: who, what: what, start: start, took: Date().timeIntervalSince1970 - start, bytes: bytes(result)))
            return result
        } catch {
            log.add(Entry(who: who, what: what + " failed", start: start, took: Date().timeIntervalSince1970 - start, bytes: 0))
            throw error
        }
    }

    private static func size(_ rows: [[JSONValue]]) -> Int {
        rows.reduce(0) { $0 + $1.reduce(0) { $0 + ($1.string?.utf8.count ?? 8) } }
    }

    func createIdentity() async throws -> SpacetimeCredentials {
        try await timed("identity") { try await inner.createIdentity() }
    }

    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        try await timed("call " + reducer) { try await inner.call(reducer, arguments, token: token) }
    }

    func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        try await timed(Self.kind(of: sql), bytes: Self.size) { try await inner.query(sql, token: token) }
    }

    func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?) {
        try await timed(Self.kind(of: sql), bytes: { Self.size($0.rows) }) { try await inner.queryDated(sql, token: token) }
    }

    func watch(_ queries: [String], token: String, changed: @escaping @Sendable () -> Void) async -> (any RealmWatch)? {
        await inner.watch(queries, token: token, changed: changed)
    }
}
