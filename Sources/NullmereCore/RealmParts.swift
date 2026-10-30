import Foundation

/// The realm in parts, as SpacetimeDB keeps it: the map, each long list a
/// page of `RealmState.partPage` at a time, and the rest. The steward
/// writes only the parts that changed, so an order moving one company
/// sends a page of companies, not the whole world, and the chronicle and
/// the history, which only grow, send their last page alone.
extension RealmState {
    public static let partPage = 32

    /// Each part's name and its JSON. Joined by `init(parts:)`, they give
    /// back this realm exactly.
    public func parts(using encoder: JSONEncoder) throws -> [String: String] {
        var parts: [String: String] = [:]
        func text<T: Encodable>(_ value: T) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        func paged<T: Encodable>(_ name: String, _ items: [T]?) throws {
            guard let items else { return }
            // An empty list keeps its first page, so a page lost is told
            // from a list with nothing in it.
            for start in stride(from: 0, to: max(items.count, 1), by: RealmState.partPage) {
                parts["\(name).\(start / RealmState.partPage)"] = try text(Array(items[start..<min(start + RealmState.partPage, items.count)]))
            }
        }
        var head = self
        parts["map"] = try text(world.map)
        head.world.map = RealmState.noMap
        try paged("units", world.units)
        head.world.units = []
        try paged("houses", world.houses)
        head.world.houses = []
        try paged("holds", world.holds)
        head.world.holds = []
        try paged("relations", world.relations)
        head.world.relations = []
        try paged("chronicle", world.chronicle)
        head.world.chronicle = []
        try paged("recorded", world.recorded)
        head.world.recorded = world.recorded.map { _ in [] }
        // Lists a realm from before them doesn't have stay absent from it.
        try paged("commanders", world.commanders)
        head.world.commanders = world.commanders.map { _ in [] }
        try paged("wilds", world.wilds)
        head.world.wilds = world.wilds.map { _ in [] }
        parts["head"] = try text(head)
        return parts
    }

    /// The realm from its parts. A page missing, or a part that isn't
    /// what its name says, is an error: a realm half read is no realm.
    public init(parts: [String: String]) throws {
        let decoder = JSONDecoder()
        func value<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
            guard let text = parts[name] else { throw RealmPartsError.missing(name) }
            return try decoder.decode(T.self, from: Data(text.utf8))
        }
        func pages<T: Decodable>(_ name: String, of type: T.Type) throws -> [T] {
            let count = max(parts.keys.filter { $0.hasPrefix(name + ".") }.count, 1)
            return try (0..<count).flatMap { try value("\(name).\($0)", as: [T].self) }
        }
        var realm: RealmState = try value("head")
        realm.world.map = try value("map")
        realm.world.units = try pages("units", of: Unit.self)
        realm.world.houses = try pages("houses", of: House.self)
        realm.world.holds = try pages("holds", of: Hold.self)
        realm.world.relations = try pages("relations", of: Relation.self)
        realm.world.chronicle = try pages("chronicle", of: ChronicleEntry.self)
        if realm.world.recorded != nil {
            realm.world.recorded = try pages("recorded", of: Snapshot.self)
        }
        if realm.world.commanders != nil {
            realm.world.commanders = try pages("commanders", of: Commander.self)
        }
        if realm.world.wilds != nil {
            realm.world.wilds = try pages("wilds", of: Wild.self)
        }
        self = realm
    }

    /// The head's stand-in for the map, which is kept apart.
    private static let noMap = WorldMap(radius: 1, fill: Tile(terrain: .still))
}

public enum RealmPartsError: Error, Equatable {
    case missing(String)
}
