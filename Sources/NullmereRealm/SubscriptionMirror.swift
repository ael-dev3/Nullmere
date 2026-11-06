import Foundation

/// The rows a SpacetimeDB subscription watches, kept as the server's
/// messages tell them: every row the queries match when the subscription
/// takes, then, transaction by transaction, the rows each let go and
/// wrote. Kept by the thread that hears the messages, in the order they
/// come, and read whole by whoever asks: a client reads what the realm
/// pushed rather than ask after it.
public final class SubscriptionMirror: @unchecked Sendable {
    /// A table's columns in the order the module declares them, which is
    /// how a transaction's rows come, and the column that tells its rows
    /// apart.
    public struct Table: Sendable, Equatable {
        public let columns: [String]
        public let key: String

        public init(columns: [String], key: String) {
            self.columns = columns
            self.key = key
        }
    }

    /// The realm module's tables and views a keeper's Mac watches.
    public static let realm: [String: Table] = [
        "status": Table(columns: ["id", "version", "status"], key: "id"),
        "my_view": Table(columns: ["keeper", "version", "view", "events"], key: "keeper"),
        "my_view_parts": Table(columns: ["key", "keeper", "name", "version", "text"], key: "key"),
        "my_replies": Table(columns: ["nonce", "keeper", "payload"], key: "nonce"),
    ]

    /// The queries that watch every one of the realm's tables a keeper reads.
    public static let realmQueries = ["SELECT * FROM status", "SELECT * FROM my_view", "SELECT * FROM my_view_parts",
                                      "SELECT * FROM my_replies"]

    private let lock = NSLock()
    private let tables: [String: Table]
    private var rows: [String: [String: [JSONValue]]] = [:]
    private var live = false
    private var heard = 0
    private var connections = 0

    public init(tables: [String: Table] = SubscriptionMirror.realm) {
        self.tables = tables
    }

    /// Whether the rows are the server's as they stand: the subscription
    /// took on this connection, and the line hasn't dropped since.
    public var isLive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return live
    }

    /// How many of the server's words have been taken: one more each time
    /// the rows may have changed.
    public var updates: Int {
        lock.lock()
        defer { lock.unlock() }
        return heard
    }

    /// How many times the subscription has taken: one more for each
    /// connection, its rows read afresh.
    public var connection: Int {
        lock.lock()
        defer { lock.unlock() }
        return connections
    }

    /// The line dropped: what is written meanwhile won't be told, so the
    /// rows held are no longer the server's.
    public func lost() {
        lock.lock()
        live = false
        lock.unlock()
    }

    /// Every row of a table, in the order of its columns.
    public func rows(of table: String) -> [[JSONValue]] {
        lock.lock()
        defer { lock.unlock() }
        return Array((rows[table] ?? [:]).values)
    }

    /// The row of a table whose key is `key`.
    public func row(of table: String, key: String) -> [JSONValue]? {
        lock.lock()
        defer { lock.unlock() }
        return rows[table]?[key]
    }

    /// Every table's rows at one moment, none of them halfway through a
    /// transaction.
    public func snapshot() -> [String: [[JSONValue]]] {
        lock.lock()
        defer { lock.unlock() }
        return rows.mapValues { Array($0.values) }
    }

    /// Takes a message from the server. True if it told the subscription's
    /// rows: the first of them, or what a transaction changed.
    @discardableResult
    public func apply(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = message.keys.first, let body = message[kind] as? [String: Any]
        else { return false }
        let changed: [Any]
        var first = false
        switch kind {
        case "InitialSubscription":
            changed = (body["database_update"] as? [String: Any])?["tables"] as? [Any] ?? []
            first = true
        case "TransactionUpdateLight":
            changed = (body["update"] as? [String: Any])?["tables"] as? [Any] ?? []
        case "TransactionUpdate":
            // A transaction that failed changed nothing.
            guard let committed = (body["status"] as? [String: Any])?["Committed"] as? [String: Any] else { return false }
            changed = committed["tables"] as? [Any] ?? []
        default:
            return false
        }
        // Read before taking the lock: a message can be large.
        var read: [(table: String, deletes: [[JSONValue]], inserts: [[JSONValue]])] = []
        for case let entry as [String: Any] in changed {
            guard let name = entry["table_name"] as? String, let table = tables[name] else { continue }
            var deletes: [[JSONValue]] = [], inserts: [[JSONValue]] = []
            for case let update as [String: Any] in entry["updates"] as? [Any] ?? [] {
                deletes += (update["deletes"] as? [Any] ?? []).compactMap { Self.row($0, of: table) }
                inserts += (update["inserts"] as? [Any] ?? []).compactMap { Self.row($0, of: table) }
            }
            read.append((name, deletes, inserts))
        }
        lock.lock()
        defer { lock.unlock() }
        if first {
            rows = [:]
            live = true
            connections += 1
        }
        for (name, deletes, inserts) in read {
            guard let table = tables[name], let at = table.columns.firstIndex(of: table.key) else { continue }
            var kept = rows[name] ?? [:]
            for row in deletes where row.count > at { kept[Self.key(row[at])] = nil }
            for row in inserts where row.count > at { kept[Self.key(row[at])] = row }
            rows[name] = kept
        }
        heard += 1
        return true
    }

    /// A row as a message has it, in the order of the table's columns: a
    /// transaction's rows come as JSON arrays of their values in that
    /// order, the first rows as JSON objects by column; each is the text
    /// of its JSON.
    static func row(_ value: Any, of table: Table) -> [JSONValue]? {
        var read = value
        if let text = value as? String {
            guard let parsed = try? JSONSerialization.jsonObject(with: Data(text.utf8)) else { return nil }
            read = parsed
        }
        if let values = read as? [Any] { return values.map(JSONValue.init(parsed:)) }
        if let byName = read as? [String: Any] { return table.columns.map { byName[$0].map(JSONValue.init(parsed:)) ?? .null } }
        return nil
    }

    /// A key as a row's text: a string as it is, a whole number in digits.
    static func key(_ value: JSONValue) -> String {
        switch value {
        case .string(let text): return text
        case .number(let number) where number == number.rounded() && abs(number) < 1e18: return String(Int64(number))
        case .number(let number): return String(number)
        case .bool(let bool): return String(bool)
        default: return ""
        }
    }
}

extension JSONValue {
    /// A value as `JSONSerialization` reads it: taken across as it is, not
    /// parsed again.
    init(parsed value: Any) {
        switch value {
        case let text as String:
            self = .string(text)
            return
        case let values as [Any]:
            self = .array(values.map(JSONValue.init(parsed:)))
            return
        case let byName as [String: Any]:
            self = .object(byName.mapValues(JSONValue.init(parsed:)))
            return
        default:
            break
        }
        #if canImport(Darwin)
        if let number = value as? NSNumber {
            self = CFGetTypeID(number) == CFBooleanGetTypeID() ? .bool(number.boolValue) : .number(number.doubleValue)
            return
        }
        #else
        if type(of: value) == Bool.self, let bool = value as? Bool {
            self = .bool(bool)
            return
        }
        if let whole = value as? Int {
            self = .number(Double(whole))
            return
        }
        if let number = value as? Double {
            self = .number(number)
            return
        }
        #endif
        self = .null
    }
}
