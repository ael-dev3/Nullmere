import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The realm's word, pushed as it happens, that what a keeper watches has
/// changed: the link reads it then, not at its next poll.
public protocol RealmWatch: AnyObject, Sendable {
    /// Whether the word is coming: connected and subscribed.
    var isAlive: Bool { get }
    func stop()
}

/// SpacetimeDB's subscriptions, as its JSON WebSocket protocol says them.
enum SpacetimeSubscription {
    static let protocolName = "v1.json.spacetimedb"

    /// The message that subscribes to `queries`.
    static func subscribe(_ queries: [String], request: UInt32 = 1) -> String {
        let message: [String: Any] = ["Subscribe": ["query_strings": queries, "request_id": request]]
        let data = (try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    enum Heard: Equatable {
        /// The subscription took, or what it watches changed.
        case changed
        /// Something else: who the client is, or an answer to another question.
        case other
        /// The server refused the subscription.
        case refused(String)
    }

    /// What a message from the server says, by its one top-level key.
    static func heard(_ text: String) -> Heard {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = object.keys.first
        else { return .other }
        switch kind {
        case "InitialSubscription", "TransactionUpdate", "TransactionUpdateLight", "SubscribeApplied", "SubscribeMultiApplied":
            return .changed
        case "SubscriptionError":
            let detail = (object[kind] as? [String: Any])?["error"] as? String
            return .refused(detail ?? "The realm refused the subscription.")
        default:
            return .other
        }
    }

    /// A database's subscription address: `ws` for `http`, `wss` for `https`.
    static func address(server: URL, database: String) -> URL? {
        guard var components = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        switch components.scheme {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: return nil
        }
        components.path = "/v1/database/\(database)/subscribe"
        components.queryItems = [URLQueryItem(name: "compression", value: "None")]
        return components.url
    }
}

/// A subscription kept open to SpacetimeDB: connects, subscribes, tells of
/// each change, and when the line drops tries again, further apart each
/// time, until stopped. Over `ws://` it speaks for itself; over `wss://`,
/// through the system's WebSockets where it has them.
final class SpacetimeWatch: RealmWatch, @unchecked Sendable {
    private let address: URL
    private let token: String
    private let queries: [String]
    private let changed: @Sendable () -> Void
    private let lock = NSLock()
    private var alive = false
    private var stopped = false
    private var plain: PlainWebSocket?
    private var system: AnyObject?
    /// Seconds before trying again after the line drops, doubling to a minute.
    static let firstRetry = 2.0
    static let longestRetry = 60.0

    /// Whether a plain `ws://` realm, too, is heard through the system's
    /// WebSockets: for testing them on a Mac.
    private let throughTheSystem: Bool

    init(address: URL, token: String, queries: [String], throughTheSystem: Bool = false, changed: @escaping @Sendable () -> Void) {
        self.address = address
        self.token = token
        self.queries = queries
        self.throughTheSystem = throughTheSystem
        self.changed = changed
    }

    var isAlive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return alive && !stopped
    }

    private var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    private func setAlive(_ value: Bool) {
        lock.lock()
        alive = value
        lock.unlock()
    }

    func start() {
        let thread = Thread { [weak self] in self?.keep() }
        thread.name = "Nullmere realm watch"
        thread.start()
    }

    func stop() {
        lock.lock()
        stopped = true
        alive = false
        let plain = self.plain
        let system = self.system
        lock.unlock()
        plain?.close()
        #if canImport(Darwin)
        (system as? URLSessionWebSocketTask)?.cancel(with: .goingAway, reason: nil)
        #else
        _ = system
        #endif
    }

    /// Connects, listens until the line drops, and tries again.
    private func keep() {
        var wait = SpacetimeWatch.firstRetry
        while !isStopped {
            if listen() { wait = SpacetimeWatch.firstRetry }
            setAlive(false)
            guard !isStopped else { return }
            Thread.sleep(forTimeInterval: wait * Double.random(in: 0.8...1.2))
            wait = min(wait * 2, SpacetimeWatch.longestRetry)
        }
    }

    /// One connection, listened to until it drops. True if it was heard from.
    private func listen() -> Bool {
        let headers = ["Authorization": "Bearer \(token)"]
        if address.scheme == "ws", !throughTheSystem {
            guard let socket = try? PlainWebSocket.open(address, protocols: [SpacetimeSubscription.protocolName], headers: headers) else {
                return false
            }
            lock.lock()
            plain = socket
            lock.unlock()
            defer { socket.close() }
            guard (try? socket.send(text: SpacetimeSubscription.subscribe(queries))) != nil else { return false }
            var heard = false
            while !isStopped, let text = try? socket.receive() {
                guard hear(text) else { return heard }
                heard = true
            }
            return heard
        }
        #if canImport(Darwin)
        return listenThroughTheSystem(headers: headers)
        #else
        return false
        #endif
    }

    /// Tells of a message; false if the realm refused the subscription.
    private func hear(_ text: String) -> Bool {
        switch SpacetimeSubscription.heard(text) {
        case .changed:
            setAlive(true)
            changed()
            return true
        case .other:
            return true
        case .refused:
            return false
        }
    }

    #if canImport(Darwin)
    /// What one wait on the system's socket brought.
    private final class Received: @unchecked Sendable {
        var result: Result<URLSessionWebSocketTask.Message, any Error>?
    }

    /// The system's WebSockets, for `wss://`: a realm reached over TLS.
    private func listenThroughTheSystem(headers: [String: String]) -> Bool {
        var request = URLRequest(url: address)
        request.setValue(SpacetimeSubscription.protocolName, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let task = URLSession.shared.webSocketTask(with: request)
        lock.lock()
        system = task
        lock.unlock()
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }
        let sent = DispatchSemaphore(value: 0)
        let failed = Received()
        task.send(.string(SpacetimeSubscription.subscribe(queries))) { error in
            if let error { failed.result = .failure(error) }
            sent.signal()
        }
        sent.wait()
        if case .failure = failed.result { return false }
        var heard = false
        while !isStopped {
            let received = Received()
            let arrived = DispatchSemaphore(value: 0)
            task.receive { result in
                received.result = result
                arrived.signal()
            }
            arrived.wait()
            guard case .success(let message) = received.result else { break }
            let text: String
            switch message {
            case .string(let string): text = string
            case .data(let data): text = String(decoding: data, as: UTF8.self)
            @unknown default: text = ""
            }
            guard hear(text) else { break }
            heard = true
        }
        return heard
    }
    #endif
}
