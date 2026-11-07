import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereRealm

/// A client's line to a realm that a test can cut and mend where no relay
/// can stand between them, as before a realm served over TLS far away:
/// while it is cut, every request fails as one fails with no network, and
/// the server's word is lost with it, its subscription no longer alive
/// and its rows not the client's to read; mended, all of it goes through
/// again. A request already on its way when the line is cut is carried.
public final class SeverableLine: SpacetimeTransport, @unchecked Sendable {
    private let line: any SpacetimeTransport
    private let lock = NSLock()
    private var down = false

    public init(_ line: any SpacetimeTransport) {
        self.line = line
    }

    public var isCut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return down
    }

    public func cut() {
        lock.lock()
        down = true
        lock.unlock()
    }

    public func mend() {
        lock.lock()
        down = false
        lock.unlock()
    }

    /// Fails as a request fails with no network while the line is cut.
    private func through() throws {
        if isCut { throw URLError(.notConnectedToInternet) }
    }

    public func createIdentity() async throws -> SpacetimeCredentials {
        try through()
        return try await line.createIdentity()
    }

    public func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        try through()
        try await line.call(reducer, arguments, token: token)
    }

    public func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        try through()
        return try await line.query(sql, token: token)
    }

    public func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?) {
        try through()
        return try await line.queryDated(sql, token: token)
    }

    public func watch(_ queries: [String], token: String, changed: @escaping @Sendable () -> Void) async -> (any RealmWatch)? {
        let watch = await line.watch(queries, token: token) { [weak self] in
            if self?.isCut == false { changed() }
        }
        return watch.map { SeveredWatch(watch: $0, line: self) }
    }
}

/// The server's word through a line that may be cut: lost while it is.
private final class SeveredWatch: RealmWatch, @unchecked Sendable {
    let watch: any RealmWatch
    let line: SeverableLine

    init(watch: any RealmWatch, line: SeverableLine) {
        self.watch = watch
        self.line = line
    }

    var isAlive: Bool { !line.isCut && watch.isAlive }
    var mirror: SubscriptionMirror? { line.isCut ? nil : watch.mirror }
    func stop() { watch.stop() }
}
