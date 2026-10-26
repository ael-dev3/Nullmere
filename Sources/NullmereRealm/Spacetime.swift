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
    public let description: String
    /// The server no longer takes the token: its database was made anew, or
    /// the identity is gone.
    public let isUnauthorized: Bool

    public init(_ description: String, isUnauthorized: Bool = false) {
        self.description = description
        self.isUnauthorized = isUnauthorized
    }

    public static let unauthorized = SpacetimeError("The realm no longer knows this Mac's key.", isUnauthorized: true)
}

/// What the realm needs of SpacetimeDB: an identity, reducer calls, and
/// SQL reads.
public protocol SpacetimeTransport: Sendable {
    func createIdentity() async throws -> SpacetimeCredentials
    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws
    /// The rows of a query, each the values of its columns in order.
    func query(_ sql: String, token: String) async throws -> [[JSONValue]]
}

/// SpacetimeDB's HTTP API: `/v1/identity`, and a database's `call` and `sql`.
public struct SpacetimeHTTP: SpacetimeTransport {
    public let server: URL
    public let database: String

    /// `address` names the server and the database: `http://127.0.0.1:3000/nullmere`.
    public init?(address: URL) {
        let parts = address.pathComponents.filter { $0 != "/" }
        guard let database = parts.last, var components = URLComponents(url: address, resolvingAgainstBaseURL: false) else { return nil }
        components.path = ""
        guard let server = components.url else { return nil }
        self.server = server
        self.database = database
    }

    public init(server: URL, database: String) {
        self.server = server
        self.database = database
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpacetimeError("No answer from the realm's server.") }
        if http.statusCode == 404 {
            throw SpacetimeError("The realm isn't open yet.")
        }
        if http.statusCode == 401 {
            throw SpacetimeError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw SpacetimeError(text.isEmpty ? "The realm's server answered \(http.statusCode)." : text)
        }
        return data
    }

    public func createIdentity() async throws -> SpacetimeCredentials {
        var request = URLRequest(url: server.appendingPathComponent("v1/identity"))
        request.httpMethod = "POST"
        return try JSONDecoder().decode(SpacetimeCredentials.self, from: try await send(request))
    }

    public func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        var request = URLRequest(url: server.appendingPathComponent("v1/database/\(database)/call/\(reducer)"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: arguments.map(\.json))
        _ = try await send(request)
    }

    public func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        var request = URLRequest(url: server.appendingPathComponent("v1/database/\(database)/sql"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(sql.utf8)
        struct Statement: Decodable {
            let rows: [[JSONValue]]
        }
        let statements = try JSONDecoder().decode([Statement].self, from: try await send(request))
        return statements.first?.rows ?? []
    }
}

/// SQL string literal: quotes doubled.
func sqlString(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
}
