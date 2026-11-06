import Foundation

/// The realm in parts, as SpacetimeDB keeps it: the map a page of
/// `RealmState.mapPage` tiles at a time, each long list a page of
/// `RealmState.partPage` at a time, and the rest. The steward writes only
/// the parts that changed, so an order moving one company sends a page of
/// companies, not the whole world, and the chronicle and the history,
/// which only grow, send their last page alone. A keeper's view goes in
/// parts the same way, so what a pace changes in it is all that is sent of
/// it, and a page of it just as every keeper is told it is written once for
/// all of them.
extension RealmState {
    public static let partPage = 32
    /// How many of the map's tiles go to a part: a wide lake's map is a
    /// megabyte, and a keeper's view of it changes only where they explore.
    public static let mapPage = 2_048

    /// Each part's name and its JSON. Joined by `init(parts:)`, they give
    /// back this realm exactly.
    public func parts(using encoder: JSONEncoder) throws -> [String: String] {
        try parts(using: encoder, reusing: [])
    }

    /// Its parts, each page of the map and of a long list that is just as
    /// it was in a world already written (`reusing`, each a world and its
    /// parts as written with the same encoder) taken as written there.
    public func parts(using encoder: JSONEncoder, reusing written: [GameState.Written]) throws -> [String: String] {
        var parts: [String: String] = [:]
        var head = self
        head.world = try world.split(into: &parts, using: encoder, reusing: written)
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
        try parts(using: encoder, reusing: whole.map { [$0] } ?? [])
    }

    /// A keeper's view in parts, each page of its map and of its long lists
    /// that is just as it is in a world already written (`reusing`: the
    /// world the view is of, or the view of a keeper of no House, each with
    /// its parts as written with the same encoder) taken as written there:
    /// most of every view is what every keeper is told alike, written once.
    public func parts(using encoder: JSONEncoder, reusing written: [GameState.Written]) throws -> [String: String] {
        var parts: [String: String] = [:]
        let head = RealmView(keeper: keeper, age: age, world: try world.split(into: &parts, using: encoder, reusing: written))
        parts["head"] = String(decoding: try encoder.encode(head), as: UTF8.self)
        return parts
    }

    /// A keeper's view from its parts; one missing, or not what its name
    /// says, is an error. With `read`, what a keeper's Mac has read of its
    /// view before: each part decoded only if its text is new, the rest
    /// taken as read, and the view the same as read afresh.
    public init(parts: [String: String], read: PartsRead? = nil) throws {
        let decoder = JSONDecoder()
        let head: RealmView = try GameState.part("head", of: parts, using: decoder, read: read)
        var world = head.world
        try world.join(parts, using: decoder, read: read)
        read?.keepOnly(parts.keys)
        self.init(keeper: head.keeper, age: head.age, world: world)
    }
}

/// What a keeper's Mac has read of its view, part by part: each part
/// decoded once, when its text is new, and kept with that text. A view's
/// publication rewrites a few of its parts (its head, the companies that
/// moved, the map they explored), so joined from parts already read the
/// view decodes those few, not the whole realm again; and is the view read
/// afresh, to the last field.
public final class PartsRead: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [String: (text: String, value: Any)] = [:]
    /// How many parts it has decoded, for its tests.
    private(set) var decoded = 0

    /// How many parts it holds as read.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return kept.count
    }

    public init() {}

    /// What the part `name` of `parts` reads as: decoded by `read` only if
    /// its text is not the text it was last read from.
    func value<T>(_ name: String, in parts: [String: String], _ read: (String) throws -> T) throws -> T {
        guard let text = parts[name] else { throw RealmPartsError.missing(name) }
        lock.lock()
        let known = kept[name]
        lock.unlock()
        if let known, known.text == text, let value = known.value as? T { return value }
        let value = try read(text)
        lock.lock()
        kept[name] = (text, value)
        decoded += 1
        lock.unlock()
        return value
    }

    /// Lets go of what it read of parts no longer among these.
    func keepOnly<Names: Sequence>(_ names: Names) where Names.Element == String {
        let current = Set(names)
        lock.lock()
        kept = kept.filter { current.contains($0.key) }
        lock.unlock()
    }

    /// Lets go of all it has read: a view from another realm, or read anew.
    public func forget() {
        lock.lock()
        kept.removeAll()
        lock.unlock()
    }
}

extension GameState {
    /// A world and its parts as written: what a page just as it is there is
    /// taken from, not written again.
    public typealias Written = (world: GameState, parts: [String: String])

    /// This world in parts as a view's world goes, `head` the rest of it:
    /// what views of it take their pages from (`RealmView.parts(using:reusing:)`).
    public func parts(using encoder: JSONEncoder, reusing written: [Written] = []) throws -> [String: String] {
        var parts: [String: String] = [:]
        let head = try split(into: &parts, using: encoder, reusing: written)
        parts["head"] = String(decoding: try encoder.encode(head), as: UTF8.self)
        return parts
    }

    /// The map's head among its parts: how wide the world is and how many
    /// tiles each of its pages ("map.0", "map.1", ...) holds, the cells of
    /// each as the map itself writes them.
    struct MapPages: Codable, Equatable {
        let radius: Int
        let page: Int

        /// Wider than any lake a realm raises, by far.
        static let widest = 1 << 14

        var count: Int { (WorldMap.count(radius: radius) + page - 1) / page }

        /// The tiles of a page, by their indices.
        func tiles(of page: Int) -> Range<Int> {
            page * self.page..<min((page + 1) * self.page, WorldMap.count(radius: radius))
        }
    }

    /// A world's map and each long list, a page at a time, into `parts`;
    /// what is left of it, the head, returned. A page just as it is in a
    /// world already written (`written`, searched in order) is taken as
    /// written there.
    func split(into parts: inout [String: String], using encoder: JSONEncoder, reusing written: [Written] = []) throws -> GameState {
        func text<T: Encodable>(_ value: T) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        func paged<T: Encodable & Equatable, Items: RandomAccessCollection>(_ name: String, _ items: Items?, as theirs: (GameState) -> Items?) throws
            where Items.Element == T, Items.Index == Int {
            guard let items else { return }
            let others = written.map { (theirs($0.world), $0.parts) }
            // An empty list keeps its first page, so a page lost is told
            // from a list with nothing in it.
            for start in stride(from: 0, to: max(items.count, 1), by: RealmState.partPage) {
                let end = min(start + RealmState.partPage, items.count)
                let key = "\(name).\(start / RealmState.partPage)"
                // The same page there: the same items, and no more after
                // them on it.
                let alike = others.first { list, theirParts in
                    guard let list, theirParts[key] != nil, min(start + RealmState.partPage, list.count) == end else { return false }
                    return list[start..<end].elementsEqual(items[start..<end])
                }
                parts[key] = try alike?.1[key] ?? text(Array(items[start..<end]))
            }
        }
        var head = self
        // The map, a page at a time; a page just as it is in a world written
        // with pages of the same size is taken as written there.
        let pages = MapPages(radius: map.radius, page: RealmState.mapPage)
        let mapHead = try text(pages)
        parts["map"] = mapHead
        let mapped = written.filter { $0.parts["map"] == mapHead }
        for page in 0..<pages.count {
            let key = "map.\(page)", range = pages.tiles(of: page)
            let alike = mapped.first { $0.parts[key] != nil && $0.world.map.tiles[range] == map.tiles[range] }
            parts[key] = alike?.parts[key] ?? WorldMap.cells(of: map.tiles[range])
        }
        head.map = GameState.noMap
        try paged("units", units) { $0.units }
        head.units = []
        try paged("houses", houses) { $0.houses }
        head.houses = []
        try paged("holds", holds) { $0.holds }
        head.holds = []
        try paged("relations", relations) { $0.relations }
        head.relations = []
        try paged("chronicle", chronicle) { $0.chronicle }
        head.chronicle = []
        try paged("recorded", recorded) { $0.recorded }
        head.recorded = recorded.map { _ in [] }
        // Lists a realm from before them doesn't have stay absent from it.
        try paged("commanders", commanders) { $0.commanders }
        head.commanders = commanders.map { _ in [] }
        try paged("wilds", wilds) { $0.wilds }
        head.wilds = wilds.map { _ in [] }
        try paged("sites", sites) { $0.sites }
        head.sites = sites.map { _ in [] }
        try paged("armoury", armoury) { $0.armoury }
        head.armoury = armoury.map { _ in [] }
        // The songbook, like the Chronicle, is every keeper's to read.
        try paged("ballads", ballads) { $0.ballads }
        head.ballads = ballads.map { _ in [] }
        // The atlas, the same all age long and in every view, apart: the
        // head, written at every pace, leaves it out, keeping only an empty
        // one to say there is one.
        if let atlas {
            if let same = written.first(where: { $0.world.atlas == atlas && $0.parts["atlas"] != nil }) {
                parts["atlas"] = same.parts["atlas"]
            } else {
                parts["atlas"] = try text(atlas)
            }
            head.atlas = Atlas(rivers: [], regions: [], crests: [])
        }
        return head
    }

    /// A world's head given back its map and its long lists from `parts`;
    /// with `read`, each part decoded only if its text is new.
    mutating func join(_ parts: [String: String], using decoder: JSONDecoder, read: PartsRead? = nil) throws {
        func pages<T: Decodable>(_ name: String, of type: T.Type) throws -> [T] {
            let count = max(parts.keys.filter { $0.hasPrefix(name + ".") }.count, 1)
            return try (0..<count).flatMap { try GameState.part("\(name).\($0)", of: parts, using: decoder, as: [T].self, read: read) }
        }
        if parts["map.0"] != nil {
            // The map in pages: as many as its head says, each the cells of
            // as many tiles as it says.
            let pages: MapPages = try GameState.part("map", of: parts, using: decoder, read: read)
            // No more pages than there are parts: a head that says otherwise
            // is refused before anything is laid out for it.
            guard (1...MapPages.widest).contains(pages.radius), pages.page >= 1, pages.count <= parts.count else {
                throw RealmPartsError.unreadable("map")
            }
            var tiles: [Tile] = []
            for page in 0..<pages.count {
                let name = "map.\(page)"
                func cells(_ text: String) throws -> [Tile] {
                    guard let tiles = WorldMap.tiles(fromCells: text) else { throw RealmPartsError.unreadable(name) }
                    return tiles
                }
                let paged: [Tile]
                if let read {
                    paged = try read.value(name, in: parts, cells)
                } else {
                    guard let text = parts[name] else { throw RealmPartsError.missing(name) }
                    paged = try cells(text)
                }
                guard paged.count == pages.tiles(of: page).count else { throw RealmPartsError.unreadable(name) }
                tiles += paged
            }
            guard let whole = WorldMap(radius: pages.radius, tiles: tiles) else { throw RealmPartsError.unreadable("map") }
            map = whole
        } else {
            map = try GameState.part("map", of: parts, using: decoder, read: read)
        }
        units = Companies(try pages("units", of: Unit.self))
        houses = try pages("houses", of: House.self)
        holds = Holdings(try pages("holds", of: Hold.self))
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
        if atlas != nil {
            atlas = try GameState.part("atlas", of: parts, using: decoder, read: read)
        }
    }

    /// One part, read as what its name says it is: with `read`, decoded
    /// only if its text is new.
    static func part<T: Decodable>(_ name: String, of parts: [String: String], using decoder: JSONDecoder, as type: T.Type = T.self,
                                   read: PartsRead? = nil) throws -> T {
        if let read { return try read.value(name, in: parts) { try decoder.decode(T.self, from: Data($0.utf8)) } }
        guard let text = parts[name] else { throw RealmPartsError.missing(name) }
        return try decoder.decode(T.self, from: Data(text.utf8))
    }

    /// The head's stand-in for the map, which is kept apart.
    static let noMap = WorldMap(radius: 1, fill: Tile(terrain: .still))
}

public enum RealmPartsError: Error, Equatable {
    case missing(String)
    /// A part there, but not what its name says it is.
    case unreadable(String)
}
