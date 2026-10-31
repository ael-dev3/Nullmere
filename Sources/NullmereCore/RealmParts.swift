import Foundation

/// The realm in parts, as SpacetimeDB keeps it: the map, each long list a
/// page of `RealmState.partPage` at a time, and the rest. The steward
/// writes only the parts that changed, so an order moving one company
/// sends a page of companies, not the whole world, and the chronicle and
/// the history, which only grow, send their last page alone. A keeper's
/// view goes in parts the same way, so what a pace changes in it is all
/// that is sent of it.
extension RealmState {
    public static let partPage = 32

    /// Each part's name and its JSON. Joined by `init(parts:)`, they give
    /// back this realm exactly.
    public func parts(using encoder: JSONEncoder) throws -> [String: String] {
        var parts: [String: String] = [:]
        var head = self
        head.world = try world.split(into: &parts, using: encoder)
        parts["head"] = String(decoding: try encoder.encode(head), as: UTF8.self)
        return parts
    }

    /// The realm from its parts. A page missing, or a part that isn't
    /// what its name says, is an error: a realm half read is no realm.
    public init(parts: [String: String]) throws {
        let decoder = JSONDecoder()
        var realm: RealmState = try GameState.part("head", of: parts, using: decoder)
        try realm.world.join(parts, using: decoder)
        self = realm
    }
}

extension RealmView {
    /// A keeper's view in parts, as the realm's world goes: its map, a
    /// page of each long list, and the rest. Joined by `init(parts:)`, they
    /// give back this view exactly. `sharing`, the world the view is of and
    /// its parts as written with the same encoder: the lists the view keeps
    /// as the world has them, its chronicle, relations and history, are
    /// taken from those parts, not written again for every keeper.
    public func parts(using encoder: JSONEncoder, sharing whole: (world: GameState, parts: [String: String])? = nil) throws -> [String: String] {
        var parts: [String: String] = [:]
        let head = RealmView(keeper: keeper, age: age, world: try world.split(into: &parts, using: encoder, sharing: whole))
        parts["head"] = String(decoding: try encoder.encode(head), as: UTF8.self)
        return parts
    }

    /// A keeper's view from its parts; one missing, or not what its name
    /// says, is an error.
    public init(parts: [String: String]) throws {
        let decoder = JSONDecoder()
        let head: RealmView = try GameState.part("head", of: parts, using: decoder)
        var world = head.world
        try world.join(parts, using: decoder)
        self.init(keeper: head.keeper, age: head.age, world: world)
    }
}

extension GameState {
    /// A world's map and each long list, a page at a time, into `parts`;
    /// what is left of it, the head, returned.
    func split(into parts: inout [String: String], using encoder: JSONEncoder,
               sharing whole: (world: GameState, parts: [String: String])? = nil) throws -> GameState {
        func text<T: Encodable>(_ value: T) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        func paged<T: Encodable>(_ name: String, _ items: [T]?) throws {
            guard let items else { return }
            try page(name, items)
        }
        /// A list the world has just the same, its pages taken as written.
        func shared<T: Encodable & Equatable>(_ name: String, _ items: [T]?, as theirs: (GameState) -> [T]?) throws {
            guard let items else { return }
            if let whole, theirs(whole.world) == items, whole.parts["\(name).0"] != nil {
                for (key, value) in whole.parts where key.hasPrefix(name + ".") { parts[key] = value }
                return
            }
            try page(name, items)
        }
        func page<T: Encodable>(_ name: String, _ items: [T]) throws {
            // An empty list keeps its first page, so a page lost is told
            // from a list with nothing in it.
            for start in stride(from: 0, to: max(items.count, 1), by: RealmState.partPage) {
                parts["\(name).\(start / RealmState.partPage)"] = try text(Array(items[start..<min(start + RealmState.partPage, items.count)]))
            }
        }
        var head = self
        parts["map"] = try text(map)
        head.map = GameState.noMap
        try paged("units", units)
        head.units = []
        try paged("houses", houses)
        head.houses = []
        try paged("holds", holds)
        head.holds = []
        try shared("relations", relations) { $0.relations }
        head.relations = []
        try shared("chronicle", chronicle) { $0.chronicle }
        head.chronicle = []
        try shared("recorded", recorded) { $0.recorded }
        head.recorded = recorded.map { _ in [] }
        // Lists a realm from before them doesn't have stay absent from it.
        try paged("commanders", commanders)
        head.commanders = commanders.map { _ in [] }
        try paged("wilds", wilds)
        head.wilds = wilds.map { _ in [] }
        try paged("sites", sites)
        head.sites = sites.map { _ in [] }
        try paged("armoury", armoury)
        head.armoury = armoury.map { _ in [] }
        // The songbook, like the Chronicle, is every keeper's to read.
        try shared("ballads", ballads) { $0.ballads }
        head.ballads = ballads.map { _ in [] }
        return head
    }

    /// A world's head given back its map and its long lists from `parts`.
    mutating func join(_ parts: [String: String], using decoder: JSONDecoder) throws {
        func pages<T: Decodable>(_ name: String, of type: T.Type) throws -> [T] {
            let count = max(parts.keys.filter { $0.hasPrefix(name + ".") }.count, 1)
            return try (0..<count).flatMap { try GameState.part("\(name).\($0)", of: parts, using: decoder, as: [T].self) }
        }
        map = try GameState.part("map", of: parts, using: decoder)
        units = try pages("units", of: Unit.self)
        houses = try pages("houses", of: House.self)
        holds = try pages("holds", of: Hold.self)
        relations = try pages("relations", of: Relation.self)
        chronicle = try pages("chronicle", of: ChronicleEntry.self)
        if recorded != nil {
            recorded = try pages("recorded", of: Snapshot.self)
        }
        if commanders != nil {
            commanders = try pages("commanders", of: Commander.self)
        }
        if wilds != nil {
            wilds = try pages("wilds", of: Wild.self)
        }
        if sites != nil {
            sites = try pages("sites", of: Site.self)
        }
        if armoury != nil {
            armoury = try pages("armoury", of: Gear.self)
        }
        if ballads != nil {
            ballads = try pages("ballads", of: Ballad.self)
        }
    }

    /// One part, read as what its name says it is.
    static func part<T: Decodable>(_ name: String, of parts: [String: String], using decoder: JSONDecoder, as type: T.Type = T.self) throws -> T {
        guard let text = parts[name] else { throw RealmPartsError.missing(name) }
        return try decoder.decode(T.self, from: Data(text.utf8))
    }

    /// The head's stand-in for the map, which is kept apart.
    static let noMap = WorldMap(radius: 1, fill: Tile(terrain: .still))
}

public enum RealmPartsError: Error, Equatable {
    case missing(String)
}
