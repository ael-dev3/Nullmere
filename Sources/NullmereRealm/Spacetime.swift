import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A value as SpacetimeDB's HTTP API returns it: JSON of any shape.
public enum JSONValue: Decodable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let bool = try? container.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? container.decode(Double.self) { self = .number(number) }
        else if let string = try? container.decode(String.self) { self = .string(string) }
        else if let array = try? container.decode([JSONValue].self) { self = .array(array) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public var string: String? { if case .string(let value) = self { return value } else { return nil } }
    public var number: Double? { if case .number(let value) = self { return value } else { return nil } }
}

/// Who a client is to SpacetimeDB: its identity, and the token that proves it.
public struct SpacetimeCredentials: Codable, Equatable, Sendable {
    public let identity: String
    public let token: String

    public init(identity: String, token: String) {
        self.identity = identity
        self.token = token
    }
}

/// An argument to a reducer.
public enum ReducerArgument: Sendable, Equatable {
    case string(String)
    case bool(Bool)
    case integer(UInt64)
    case strings([String])
    case integers([UInt64])

    var json: Any {
        switch self {
        case .string(let value): return value
        case .bool(let value): return value
        case .integer(let value): return value
        case .strings(let value): return value
        case .integers(let value): return value
        }
    }
}

public struct SpacetimeError: Error, Equatable, CustomStringConvertible, Sendable {
    /// What went wrong, as the link or the server said it: for whoever runs
    /// the realm. A keeper is told `RealmTrouble.words(for:)`.
    public let description: String
    /// The server doesn't take the token: it was made anew, or the identity
    /// is gone, or it is out of sorts. The key is kept all the same.
    public let isUnauthorized: Bool
    /// The status the server refused with, when it answered at all.
    public let status: Int?

    public init(_ description: String, isUnauthorized: Bool = false, status: Int? = nil) {
        self.description = description
        self.isUnauthorized = isUnauthorized
        self.status = status
    }

    public static let unauthorized = SpacetimeError("The realm doesn't accept this Mac's key just now. The key is kept, and offered again in a while.",
                                                    isUnauthorized: true, status: 401)
    /// The realm's module has no such request: it and this version of the
    /// game don't match.
    public static let unknownRequest = "The realm doesn't know what this version of Nullmere Online asks of it: one of the two is newer than the other."
}

/// What the realm needs of SpacetimeDB: an identity, reducer calls, and
/// SQL reads.
public protocol SpacetimeTransport: Sendable {
    func createIdentity() async throws -> SpacetimeCredentials
    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws
    /// The rows of a query, each the values of its columns in order.
    func query(_ sql: String, token: String) async throws -> [[JSONValue]]
    /// A query's rows, and the server's clock when it answered, if it said.
    func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?)
}

extension SpacetimeTransport {
    public func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?) {
        (try await query(sql, token: token), nil)
    }
}

/// SpacetimeDB's HTTP API: `/v1/identity`, and a database's `call` and `sql`.
public struct SpacetimeHTTP: SpacetimeTransport, @unchecked Sendable {
    public let server: URL
    public let database: String
    /// The session requests go by: the shared one, but for tests.
    let session: URLSession
    /// Seconds a request may take: a request in flight as the Mac sleeps,
    /// or as the network goes, fails soon after rather than holding up
    /// the next poll for a minute.
    public static let timeout: TimeInterval = 15

    /// `address` names the server and the database: `http://127.0.0.1:3000/nullmere`.
    public init?(address: URL, session: URLSession = .shared) {
        let parts = address.pathComponents.filter { $0 != "/" }
        guard let database = parts.last, var components = URLComponents(url: address, resolvingAgainstBaseURL: false) else { return nil }
        components.path = ""
        guard let server = components.url else { return nil }
        self.init(server: server, database: database, session: session)
    }

    public init(server: URL, database: String, session: URLSession = .shared) {
        self.server = server
        self.database = database
        self.session = session
    }

    private func send(_ request: URLRequest) async throws -> Data {
        try await sendDated(request).data
    }

    /// An answer, and the server's clock by its `Date` header.
    private func sendDated(_ request: URLRequest) async throws -> (data: Data, date: Date?) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpacetimeError("No answer from the realm.") }
        if http.statusCode == 404 {
            // A database not there, or a request its module doesn't have.
            let said = String(decoding: data, as: UTF8.self).lowercased()
            if said.contains("procedure") || said.contains("reducer") {
                throw SpacetimeError(SpacetimeError.unknownRequest, status: 404)
            }
            throw SpacetimeError("The realm isn't open yet.", status: 404)
        }
        if http.statusCode == 401 {
            throw SpacetimeError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw SpacetimeError(text.isEmpty ? "The realm answered \(http.statusCode)." : text, status: http.statusCode)
        }
        return (data, (http.value(forHTTPHeaderField: "Date")).flatMap(Self.httpDate))
    }

    /// An HTTP date: "Mon, 26 Oct 2026 22:04:54 GMT".
    static func httpDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: text)
    }

    public func createIdentity() async throws -> SpacetimeCredentials {
        var request = URLRequest(url: server.appendingPathComponent("v1/identity"))
        request.timeoutInterval = SpacetimeHTTP.timeout
        request.httpMethod = "POST"
        return try JSONDecoder().decode(SpacetimeCredentials.self, from: try await send(request))
    }

    public func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        var request = URLRequest(url: server.appendingPathComponent("v1/database/\(database)/call/\(reducer)"))
        request.timeoutInterval = SpacetimeHTTP.timeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: arguments.map(\.json))
        _ = try await send(request)
    }

    public func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        try await queryDated(sql, token: token).rows
    }

    public func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?) {
        var request = URLRequest(url: server.appendingPathComponent("v1/database/\(database)/sql"))
        request.timeoutInterval = SpacetimeHTTP.timeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(sql.utf8)
        struct Statement: Decodable {
            let rows: [[JSONValue]]
        }
        let (data, date) = try await sendDated(request)
        let statements = try JSONDecoder().decode([Statement].self, from: data)
        return (statements.first?.rows ?? [], date)
    }
}

/// SQL string literal: quotes doubled.
func sqlString(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
}
