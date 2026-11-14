import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereLive
import NullmereLiveStage
import NullmereRealm

/// A small world of the rebuilt realm, as a subscription would hold its
/// rows: plain, a wood to the east, deep water in the far west; Ada's
/// city at 10, -4 with a Farm and a Wall; Bryn's at 14, -4; a grove at
/// 12, -2; Ada's army half way from her city to it; Bryn's army at work
/// there; a barrow of the Unquiet at 8, -2, and another of Bryn's armies
/// fighting at it. The viewer is Ada.
public enum LiveSample {
    private static func n(_ value: Double) -> JSONValue { .number(value) }
    private static func n(_ value: UInt64) -> JSONValue { .number(Double(value)) }
    private static func n(_ value: Int) -> JSONValue { .number(Double(value)) }

    public static func rows() -> [String: [[JSONValue]]] {
        func ground(_ hex: LiveHex) -> UInt8 {
            if hex.q <= -10 { return 0 }
            if hex.q >= 16 { return 5 }
            return 4
        }
        var chunks: [[JSONValue]] = []
        for cr in -3...2 {
            for cq in -3...2 {
                let bytes = (0..<256).map { index -> UInt8 in ground(LiveHex(q: cq * 16 + index % 16, r: cr * 16 + index / 16)) }
                chunks.append([n(LiveHex(q: cq, r: cr).packed), .string(bytes.map { String(format: "%02x", $0) }.joined())])
            }
        }
        let (ada, bryn, grove, barrow) = (LiveHex(q: 10, r: -4), LiveHex(q: 14, r: -4), LiveHex(q: 12, r: -2), LiveHex(q: 8, r: -2))
        func encoded(_ way: [LiveHex]) -> String {
            way.flatMap { hex -> [UInt8] in
                let (q, r) = (UInt16(bitPattern: Int16(hex.q)), UInt16(bitPattern: Int16(hex.r)))
                return [UInt8(q & 0xFF), UInt8(q >> 8), UInt8(r & 0xFF), UInt8(r >> 8)]
            }.map { String(format: "%02x", $0) }.joined()
        }
        let route = encoded([ada, LiveHex(q: 10, r: -3), LiveHex(q: 11, r: -3), LiveHex(q: 11, r: -2), grove])
        // Bryn's second army came to the barrow from the east.
        let toBarrow = encoded([LiveHex(q: 10, r: -2), LiveHex(q: 9, r: -2), barrow])
        return [
            "realm": [[n(0), n(42), n(1_000), n(1), n(1_000), n(2), n(40)]],
            "land": chunks,
            "player": [[n(1), n(9), .string("Ada"), n(1_000), .bool(true), n(1_000)], [n(2), n(8), .string("Bryn"), n(1_000), .bool(true), n(1_000)]],
            "me": [[n(1), n(9), .string("Ada"), n(1_000), .bool(true), n(1_000)]],
            "city": [[n(7), n(1), n(ada.packed), .string("Ada"), n(3), n(1_000), n(1_000), n(1)],
                     [n(8), n(2), n(bryn.packed), .string("Bryn"), n(8), n(9_000), n(1_000), n(1)]],
            "my_city": [[n(7), n(1), n(ada.packed), .string("Ada"), n(3), n(1_000), n(1_000), n(1)]],
            "my_buildings": [[n(21), n(7), n(1), n(3)], [n(22), n(7), n(2), n(2)], [n(23), n(7), n(12), n(11)]],
            "place": [[n(ada.packed), n(1), n(7)], [n(bryn.packed), n(1), n(8)], [n(grove.packed), n(2), n(5)], [n(barrow.packed), n(3), n(9)]],
            "barrow": [[n(9), n(barrow.packed), n(2), n(6)]],
            "site": [[n(5), n(grove.packed), n(2), n(4), n(80_000), n(4)]],
            "march": [[n(3), n(1), n(7), n(1), n(1), n(ada.packed), n(grove.packed), n(5), n(2_000), n(2_024), n(40), .string(route), n(1)],
                      [n(4), n(2), n(8), n(1), n(2), n(bryn.packed), n(grove.packed), n(5), n(2_000), n(2_600), n(90), .string(route), n(2)],
                      [n(6), n(2), n(8), n(2), n(4), n(bryn.packed), n(barrow.packed), n(9), n(2_010), n(2_025), n(50), .string(toBarrow), n(3)]],
            "my_squads": [[n(UInt64(3 << 16 | 1 << 8 | 1)), n(3), n(1), n(1), n(10), n(0)], [n(UInt64(3 << 16 | 3 << 8 | 2)), n(3), n(3), n(2), n(30), n(0)]],
        ]
    }
}

/// A line to no realm at all: it holds the rows a test gives it, tells
/// the session when they change, and keeps what was asked of it.
public final class StandInLine: LiveLine, @unchecked Sendable {
    private let lock = NSLock()
    private var rows: [String: [[JSONValue]]] = [:]
    private var told: (@Sendable () -> Void)?
    private var calls: [String] = []
    private var refusal: String?
    private var reachable = true
    private var broken = false

    public init(rows: [String: [[JSONValue]]] = [:], reachable: Bool = true) {
        self.rows = rows
        self.reachable = reachable
    }

    private func locked<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    public var world: LiveWorld { LiveWorld(snapshot: locked { rows }) }
    public var asked: [String] { locked { calls } }

    /// Changes the rows held, and tells whoever watches.
    public func change(_ edit: (inout [String: [[JSONValue]]]) -> Void) {
        let tell = locked { () -> (@Sendable () -> Void)? in
            edit(&rows)
            return told
        }
        tell?()
    }

    /// From here on everything asked is refused in these words; nil to
    /// agree again. Or fails as a line that has dropped.
    public func refuse(_ words: String?) { locked { refusal = words } }
    public func drop() { locked { broken = true } }

    public func watch(changed: @escaping @Sendable () -> Void) async -> Bool {
        locked { told = changed }
        return reachable
    }

    public func close() { locked { calls.append("close") } }

    private func take(_ call: String) throws {
        let (words, down) = locked { () -> (String?, Bool) in
            calls.append(call)
            return (refusal, broken)
        }
        if down { throw URLError(.notConnectedToInternet) }
        if let words { throw LiveRefusal(words: words) }
    }

    private func listed(_ soldiers: [(kind: Int, tier: Int, count: UInt64)]) -> String {
        soldiers.map { "\($0.count) of \($0.kind).\($0.tier)" }.joined(separator: ", ")
    }

    public func join(name: String) async throws { try take("join \(name)") }
    public func build(_ kind: Int) async throws { try take("build \(kind)") }
    public func upgrade(building: UInt64) async throws { try take("upgrade \(building)") }
    public func train(building: UInt64, tier: Int, count: UInt64) async throws { try take("train \(count) of tier \(tier) in \(building)") }
    public func gather(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws { try take("gather at \(hex.q), \(hex.r) with \(listed(soldiers))") }
    public func hunt(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws { try take("hunt at \(hex.q), \(hex.r) with \(listed(soldiers))") }
    public func attack(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws { try take("attack at \(hex.q), \(hex.r) with \(listed(soldiers))") }
    public func heal(kind: Int, tier: Int, count: UInt64) async throws { try take("heal \(count) of \(kind).\(tier)") }
    public func read(report: UInt64) async throws { try take("read \(report)") }
    public func forget(report: UInt64) async throws { try take("forget \(report)") }
    public func recall(march: UInt64) async throws { try take("recall \(march)") }
    public func foundAlliance(name: String, tag: String) async throws { try take("found \(name) [\(tag)]") }
    public func joinAlliance(_ alliance: UInt64) async throws { try take("join alliance \(alliance)") }
    public func leaveAlliance() async throws { try take("leave alliance") }
    public func answer(applicant: UInt64, admit: Bool) async throws { try take("\(admit ? "admit" : "turn away") \(applicant)") }
    public func expel(_ player: UInt64) async throws { try take("expel \(player)") }
    public func setRank(of player: UInt64, to rank: Int) async throws { try take("rank \(player) \(rank)") }
    public func setAlliance(open: Bool, words: String) async throws { try take("alliance \(open ? "open" : "closed"): \(words)") }
    public func say(_ words: String, withinAlliance: Bool) async throws { try take("say \(withinAlliance ? "within" : "to all"): \(words)") }
}

/// How many times something has been tried.
public final class Tries: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    public init() {}

    public func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}
