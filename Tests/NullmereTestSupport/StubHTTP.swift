import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A web server in memory, for tests of code that speaks HTTP: a server
/// made by `StubHTTP.serve(_:)` has an address of its own, and a session
/// that sends each request for it to the handler given, which answers it.
/// Every request is kept to be looked at.
public final class StubHTTP: URLProtocol {
    /// What the server says to a request.
    public struct Answer: Sendable {
        public var status: Int
        public var headers: [String: String]
        public var body: Data

        public init(status: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
            self.status = status
            self.headers = headers
            self.body = body
        }

        public init(status: Int = 200, headers: [String: String] = [:], text: String) {
            self.init(status: status, headers: headers, body: Data(text.utf8))
        }
    }

    /// A request as it reached the server, its body read in full.
    public struct Received: Sendable {
        public let method: String
        public let url: URL
        public let headers: [String: String]
        public let body: Data

        public var text: String { String(decoding: body, as: UTF8.self) }
    }

    public typealias Handler = @Sendable (Received) throws -> Answer

    private static let lock = NSLock()
    private static var handlers: [String: Handler] = [:]
    private static var received: [String: [Received]] = [:]
    /// A server in memory: its address, a session that reaches it, and
    /// the requests it has had.
    public struct Server: @unchecked Sendable {
        public let address: URL
        public let session: URLSession
        let host: String

        public var requests: [Received] {
            StubHTTP.lock.lock()
            defer { StubHTTP.lock.unlock() }
            return StubHTTP.received[host] ?? []
        }
    }

    /// A server whose every request goes to `handler`. A handler that
    /// throws is a server out of reach: the request fails as a lost
    /// connection does.
    public static func serve(_ handler: @escaping Handler) -> Server {
        let host = "stub-\(UUID().uuidString.lowercased()).test"
        lock.lock()
        handlers[host] = handler
        received[host] = []
        lock.unlock()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubHTTP.self]
        return Server(address: URL(string: "https://\(host)")!, session: URLSession(configuration: configuration), host: host)
    }

    override public class func canInit(with request: URLRequest) -> Bool { true }
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public func startLoading() {
        let id = request.url?.host ?? ""
        let arrived = Received(method: request.httpMethod ?? "GET", url: request.url ?? URL(fileURLWithPath: "/"),
                               headers: request.allHTTPHeaderFields ?? [:], body: Self.body(of: request))
        Self.lock.lock()
        let handler = Self.handlers[id]
        Self.received[id, default: []].append(arrived)
        Self.lock.unlock()
        do {
            guard let handler else { throw URLError(.cannotConnectToHost) }
            let answer = try handler(arrived)
            let response = HTTPURLResponse(url: arrived.url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: answer.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: answer.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
        }
    }

    override public func stopLoading() {}

    /// A request's body: URLSession hands it on as a stream.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
