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
    /// How many Houses' relations go to a page: those kept of every two
    /// Houses whose first is one of so many, each a line of a few bytes
    /// that changes only as their dealings do. The realm keeps one only for
    /// two Houses that have dealt, so a realm of thousands of Houses is a
    /// page for every 32 of them, each changed only as they deal.
    public static let relationPage = 32
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
    /// The Houses and the holds go in their pages as a keeper of no House
    /// is told them, so every view's pages of them are alike; the keeper's
    /// own House and holds, and what their allies tell them of theirs, go
    /// apart in "own".
    public func parts(using encoder: JSONEncoder, reusing written: [GameState.Written]) throws -> [String: String] {
        var parts: [String: String] = [:]
        var told = world
        var own = Own()
        let unknown = Explored.unknown(count: world.map.count)
        // Each asked where it lies whether it is told alike already, as all
        // but a view's own and its allies' are: only those are copied.
        for index in told.houses.indices where !told.houses[index].isToldAlike(unknown: unknown) {
            own.houses.append(told.houses[index])
            told.houses[index] = told.houses[index].toldAlike(unknown: unknown)
        }
        for index in told.holds.indices where !told.holds[index].isToldAlike {
            own.holds.append(told.holds[index])
            told.holds.tellAlike(at: index)
        }
        let head = RealmView(keeper: keeper, age: age, world: try told.split(into: &parts, using: encoder, reusing: written))
        parts["head"] = String(decoding: try encoder.encode(head), as: UTF8.self)
        if !own.houses.isEmpty || !own.holds.isEmpty {
            parts[RealmView.ownPart] = String(decoding: try encoder.encode(own), as: UTF8.self)
        }
        return parts
    }

    /// The part a view's own Houses and holds go in.
    public static let ownPart = "own"

    /// What a view holds that no other keeper is told: their own House and
    /// holds, and what their allies tell them of theirs, whole.
    struct Own: Codable, Equatable {
        var houses: [House] = []
        var holds: [Hold] = []
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
    /// tiles each of its pages ("ground.0", "ground.1", ...) holds, the
    /// ground of each as the map itself writes it, and the relief of every
    /// tile apart ("relief"). A map kept before its ground went as its runs
    /// has the cells of each page ("map.0", ...) instead.
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
        func paged<T: Encodable & Equatable, Items: Paged>(_ name: String, _ items: Items?, page size: Int = RealmState.partPage,
                                                           as theirs: (GameState) -> Items?) throws where Items.Element == T {
            guard let items else { return }
            let others = written.map { (theirs($0.world), $0.parts) }
            // A list kept in the very storage of one written, as a view keeps
            // what it hides nothing of, is that list, page for page: nothing
            // of it is compared.
            let same = others.map { list, _ -> Bool in
                guard let list, list.count == items.count else { return false }
                return GameState.sameStorage(list.page(0..<list.count), items.page(0..<items.count))
            }
            // An empty list keeps its first page, so a page lost is told
            // from a list with nothing in it.
            for start in stride(from: 0, to: max(items.count, 1), by: size) {
                let end = min(start + size, items.count)
                let key = "\(name).\(start / size)"
                // The same page there: the same items, and no more after
                // them on it.
                let alike = others.indices.first { index in
                    let (list, theirParts) = others[index]
                    guard let list, theirParts[key] != nil, min(start + size, list.count) == end else { return false }
                    return same[index] || GameState.sameItems(list.page(start..<end), items.page(start..<end))
                }
                parts[key] = try alike.flatMap { others[$0].1[key] } ?? text(Array(items.page(start..<end)))
            }
        }
        var head = self
        // The map's ground, a page at a time; a page just as it is in a
        // world written with pages of the same size is taken as written
        // there.
        let pages = MapPages(radius: map.radius, page: RealmState.mapPage)
        let mapHead = try text(pages)
        parts["map"] = mapHead
        let mapped = written.filter { $0.parts["map"] == mapHead }
        for page in 0..<pages.count {
            let key = "ground.\(page)", range = pages.tiles(of: page)
            let alike = mapped.first { $0.parts[key] != nil && map.hasTheGround(of: $0.world.map, onPage: page, tiles: range) }
            parts[key] = alike?.parts[key] ?? WorldMap.ground(of: map.tiles[range])
        }
        // And its relief, whole: told alike however much of the lake a
        // keeper knows, and the same from the age's first watch to its last.
        let level = written.first { $0.parts["relief"] != nil && $0.world.map.hasTheRelief(of: map) }
        parts["relief"] = level?.parts["relief"] ?? WorldMap.relief(of: map.tiles)
        head.map = GameState.noMap
        try paged("units", units) { $0.units }
        head.units = []
        try paged("houses", houses) { $0.houses }
        head.houses = []
        try paged("holds", holds) { $0.holds }
        head.holds = []
        // The relations kept, a page for the pairs whose first House is
        // each `relationPage` Houses in turn: a page changes only as its
        // own Houses deal, however many pairs come to be kept before it.
        let blocks = max((houses.count + RealmState.relationPage - 1) / RealmState.relationPage, 1)
        let theirRelations = written.map { ($0.world.relations, $0.parts) }
        for block in 0..<blocks {
            let key = "relations.\(block)"
            let ours = relations.firstIndices(of: block)
            let alike = theirRelations.first { list, theirParts in
                guard theirParts[key] != nil else { return false }
                let theirs = list.firstIndices(of: block)
                return GameState.sameItems(list[theirs], relations[ours])
            }
            parts[key] = try alike.flatMap { $0.1[key] } ?? text(Array(relations[ours]))
        }
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
        // The deeds every House has done this age, the same in every view,
        // apart from the head that is written at every pace.
        try paged("deeds", deedsDone) { $0.deedsDone }
        head.deedsDone = deedsDone.map { _ in [] }
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
        // What a pace changes of the head apart from it, so a pace writes a
        // few hundred bytes, not the whole head again (95 KB of a realm of
        // ninety-six seats, every keeper's view's head with it): where the
        // watch's paces stand, the same in every view, apart from what is on
        // the road, which a keeper is told of their own and which seldom
        // changes, as a march, once begun, stands as it was begun.
        let pace = Pace(of: self)
        if let same = written.first(where: { $0.parts[GameState.pacePart] != nil && Pace(of: $0.world) == pace }) {
            parts[GameState.pacePart] = same.parts[GameState.pacePart]
        } else {
            parts[GameState.pacePart] = try text(pace)
        }
        let goings = Goings(of: self)
        if let same = written.first(where: { $0.parts[GameState.goingsPart] != nil && Goings(of: $0.world) == goings }) {
            parts[GameState.goingsPart] = same.parts[GameState.goingsPart]
        } else {
            parts[GameState.goingsPart] = try text(goings)
        }
        head.pacing = nil
        head.draws = 0
        head.nextID = 0
        head.envoys = []
        head.marches = nil
        head.gifts = nil
        // What every keeper is told alike of the realm as it stands, apart
        // from the head too: the same in every view, and every House's
        // strength and might in it move at nearly every pace of a wide
        // realm while the rest of a keeper's head stands (at 384 seats,
        // every keeper's head, 16 KB, was written again at every pace).
        let common = Common(of: self)
        if let same = written.first(where: { $0.parts[GameState.commonPart] != nil && Common(of: $0.world) == common }) {
            parts[GameState.commonPart] = same.parts[GameState.commonPart]
        } else {
            parts[GameState.commonPart] = try text(common)
        }
        head.reputed = nil
        head.reputedMight = nil
        head.stillHour = nil
        head.happening = nil
        // And the rest of what every keeper is told alike of the realm,
        // which changes as the watch turns, if then (its settings, the
        // Lyceum's questions, the charges done, the Sundering, the omens);
        // what is a keeper's own and seldom changes (their dreams, riddles,
        // letters, satchel, what they see of shrines and lairs); and the
        // words they hear, which change as anyone speaks: each a part of
        // its own, so the head, written for every keeper as every watch
        // turns, is the little that changes with it (at 384 seats, 2.9 KB
        // of every keeper's 3.2 was the rest).
        for (name, made) in [(GameState.realmPart, try text(Realm(of: self))), (GameState.keepsPart, try text(Keeps(of: self))),
                             (GameState.wordsPart, try text(Words(of: self)))] {
            parts[name] = written.lazy.compactMap { $0.parts[name] }.first { $0 == made } ?? made
        }
        Realm.clear(&head)
        Keeps.clear(&head)
        head.words = nil
        return head
    }

    /// Whether two stretches of items lie in the very same storage: one
    /// kept in another's, as a copy keeps the list it was made from until
    /// either changes.
    static func sameStorage<T>(_ a: ArraySlice<T>, _ b: ArraySlice<T>) -> Bool {
        a.count == b.count && a.withUnsafeBufferPointer { ours in b.withUnsafeBufferPointer { ours.baseAddress == $0.baseAddress } }
    }

    /// Whether two stretches of items are the same, item by item, compared
    /// where they lie: a hold or a company, hundreds of bytes and many
    /// lists of its own, is never copied out only to be compared.
    static func sameItems<T: Equatable>(_ a: ArraySlice<T>, _ b: ArraySlice<T>) -> Bool {
        guard a.count == b.count else { return false }
        return a.withUnsafeBufferPointer { ours in
            b.withUnsafeBufferPointer { theirs in
                if ours.baseAddress == theirs.baseAddress { return true }
                for index in ours.indices where ours[index] != theirs[index] { return false }
                return true
            }
        }
    }

    /// The part what a pace changes of the head goes in.
    public static let pacePart = "pace"

    /// The part what every keeper is told alike of the realm as it stands
    /// goes in.
    public static let commonPart = "common"

    /// What every keeper is told alike of the realm as it stands: every
    /// House's strength and might as all are told them, the glimpses of the
    /// Still Hour, and the realm's happening.
    struct Common: Codable, Equatable {
        var reputed: [Int]?
        var reputedMight: [Int]?
        var stillHour: StillHour?
        var happening: Happening?

        init(of world: GameState) {
            reputed = world.reputed
            reputedMight = world.reputedMight
            stillHour = world.stillHour
            happening = world.happening
        }
    }

    /// The part the rest of what every keeper is told alike of the realm
    /// goes in.
    public static let realmPart = "realm"

    /// The part what is a keeper's own and seldom changes goes in.
    public static let keepsPart = "keeps"

    /// The part the words a keeper hears go in.
    public static let wordsPart = "words"

    /// The head's stand-in for the realm's settings, which are kept apart.
    static let noSettings = GameSettings(seedText: "")

    /// The rest of what every keeper is told alike of the realm as it
    /// stands, apart from every House's strength: its settings and its
    /// end, the omens and the eclipse, the Spire's titles, the Augury, the
    /// veils, the Ring, the ripples, the monument, the mirror's walks, the
    /// Lyceum's questions and its hall, the calm, the lairs' ladder, the
    /// oaths, the deep water, the broken Spire, the edicts, the Sundering
    /// and those before it this age, its ford and the drowned crown, the charges done, and where the
    /// realm's rounds of words begin.
    struct Realm: Codable, Equatable {
        var settings: GameSettings
        var outcome: Outcome?
        var omen: Omen?
        var omenLifted: Int?
        var bestowals: [Bestowal]?
        var auguries: [Prophecy]?
        var veils: [Veil]?
        var ring: Ring?
        var ripples: [Int]?
        var ventured: [Int]?
        var monument: Monument?
        var mirrorWalks: [MirrorWalk]?
        var mirrorWalked: [Int: Int]?
        var lyceumSet: [LyceumQuestion]?
        var lyceumHall: Hex?
        var calm: Int?
        var lairLadder: [Int: Int]?
        var eclipse: Int?
        var oaths: [Oath]?
        var moonWater: DeepWater?
        var brokenSpire: BrokenSpire?
        var edicts: [Edict]?
        var sundering: Sundering?
        var sunderings: [Sundering]?
        var ford: [Hex]?
        var crown: DrownedCrown?
        var unsundered: Bool?
        var chargesDone: [Int]?
        var dealing: Dealing?

        init(of world: GameState) {
            settings = world.settings
            outcome = world.outcome
            omen = world.omen
            omenLifted = world.omenLifted
            bestowals = world.bestowals
            auguries = world.auguries
            veils = world.veils
            ring = world.ring
            ripples = world.ripples
            ventured = world.ventured
            monument = world.monument
            mirrorWalks = world.mirrorWalks
            mirrorWalked = world.mirrorWalked
            lyceumSet = world.lyceumSet
            lyceumHall = world.lyceumHall
            calm = world.calm
            lairLadder = world.lairLadder
            eclipse = world.eclipse
            oaths = world.oaths
            moonWater = world.moonWater
            brokenSpire = world.brokenSpire
            edicts = world.edicts
            sundering = world.sundering
            sunderings = world.sunderings
            ford = world.ford
            crown = world.crown
            unsundered = world.unsundered
            chargesDone = world.chargesDone
            dealing = world.dealing
        }

        /// Into a world read from its head.
        func put(into world: inout GameState) {
            world.settings = settings
            world.outcome = outcome
            world.omen = omen
            world.omenLifted = omenLifted
            world.bestowals = bestowals
            world.auguries = auguries
            world.veils = veils
            world.ring = ring
            world.ripples = ripples
            world.ventured = ventured
            world.monument = monument
            world.mirrorWalks = mirrorWalks
            world.mirrorWalked = mirrorWalked
            world.lyceumSet = lyceumSet
            world.lyceumHall = lyceumHall
            world.calm = calm
            world.lairLadder = lairLadder
            world.eclipse = eclipse
            world.oaths = oaths
            world.moonWater = moonWater
            world.brokenSpire = brokenSpire
            world.edicts = edicts
            world.sundering = sundering
            world.sunderings = sunderings
            world.ford = ford
            world.crown = crown
            world.unsundered = unsundered
            world.chargesDone = chargesDone
            world.dealing = dealing
        }

        /// None of it, but the settings a head can't be without.
        init(empty settings: GameSettings) {
            self.settings = settings
        }

        /// Out of a head, which keeps a stand-in for its settings.
        static func clear(_ head: inout GameState) {
            Realm(empty: GameState.noSettings).put(into: &head)
        }
    }

    /// What is a keeper's own and seldom changes: their dreams, their
    /// whispers, their riddles, their listening stones and what they hear,
    /// their sculptures, letters and pedlar, how far they have gone up the
    /// Spine, their keys at the Inn, the Houses they hide, their answers at
    /// the Lyceum, their false reflections, their letters to the age to
    /// come and those of the age before, their standing orders, their
    /// alliances, their reports and bars on words, the drowned holds,
    /// bottles, barges, rallies, fields of battle, shrines, lairs,
    /// standards, halls and storehouses they know of, the vigils burning
    /// for the fallen, the fires in the blackwood and their ash, the pleas
    /// their folk have brought them, how their envoys were answered and
    /// how they answered others', their satchel and their makings.
    struct Keeps: Codable, Equatable {
        var dreams: [Dream]?
        var whispers: [Whisper]?
        var riddles: [Riddle]?
        var listeningStones: [ListeningStone]?
        var sculptureCounts: [Int: Int]?
        var mail: [Missive]?
        var pedlars: [Pedlar]?
        var expeditions: [Int: Int]?
        var expeditionBest: [Int: [Int: Int]]?
        var innBook: [Int: InnKeys]?
        var hidden: [Int: [Int]]?
        var lyceumBook: [Int: [Int]]?
        var reflections: [FalseReflection]?
        var soundings: [Sounding]?
        var listened: [Int: Hex]?
        var letters: [Letter]?
        var oldLetters: [Letter]?
        var standing: [StandingOrders]?
        var alliances: [Alliance]?
        var reports: [WordReport]?
        var bars: [WordsBar]?
        var drowned: [DrownedHold]?
        var bottles: [Bottle]?
        var vigils: [Vigil]?
        var wildfires: [Wildfire]?
        var unlit: [Int]?
        var waiting: [Int]?
        var finds: [Find]?
        var sought: [Int: [Int]]?
        var watchfires: [Watchfire]?
        var petitions: [Petition]?
        var answers: [EnvoyAnswer]?
        var allianceMarks: [AllianceMark]?
        var barges: [Ferrying]?
        var rallies: [Rally]?
        var fields: [Field]?
        var shrines: [Shrine]?
        var lairs: [Lair]?
        var standards: [Standard]?
        var halls: [AllianceHall]?
        var storehouses: [Storehouse]?
        var satchel: [ItemStack]?
        var makings: [MakingStack]?

        init(of world: GameState) {
            dreams = world.dreams
            whispers = world.whispers
            riddles = world.riddles
            listeningStones = world.listeningStones
            sculptureCounts = world.sculptureCounts
            mail = world.mail
            pedlars = world.pedlars
            expeditions = world.expeditions
            expeditionBest = world.expeditionBest
            innBook = world.innBook
            hidden = world.hidden
            lyceumBook = world.lyceumBook
            reflections = world.reflections
            soundings = world.soundings
            listened = world.listened
            letters = world.letters
            oldLetters = world.oldLetters
            standing = world.standing
            alliances = world.alliances
            reports = world.reports
            bars = world.bars
            drowned = world.drowned
            bottles = world.bottles
            vigils = world.vigils
            wildfires = world.wildfires
            unlit = world.unlit
            waiting = world.waiting
            finds = world.finds
            sought = world.sought
            watchfires = world.watchfires
            petitions = world.petitions
            answers = world.answers
            allianceMarks = world.allianceMarks
            barges = world.barges
            rallies = world.rallies
            fields = world.fields
            shrines = world.shrines
            lairs = world.lairs
            standards = world.standards
            halls = world.halls
            storehouses = world.storehouses
            satchel = world.satchel
            makings = world.makings
        }

        /// Into a world read from its head.
        func put(into world: inout GameState) {
            world.dreams = dreams
            world.whispers = whispers
            world.riddles = riddles
            world.listeningStones = listeningStones
            world.sculptureCounts = sculptureCounts
            world.mail = mail
            world.pedlars = pedlars
            world.expeditions = expeditions
            world.expeditionBest = expeditionBest
            world.innBook = innBook
            world.hidden = hidden
            world.lyceumBook = lyceumBook
            world.reflections = reflections
            world.soundings = soundings
            world.listened = listened
            world.letters = letters
            world.oldLetters = oldLetters
            world.standing = standing
            world.alliances = alliances
            world.reports = reports
            world.bars = bars
            world.drowned = drowned
            world.bottles = bottles
            world.vigils = vigils
            world.wildfires = wildfires
            world.unlit = unlit
            world.waiting = waiting
            world.finds = finds
            world.sought = sought
            world.watchfires = watchfires
            world.petitions = petitions
            world.answers = answers
            world.allianceMarks = allianceMarks
            world.barges = barges
            world.rallies = rallies
            world.fields = fields
            world.shrines = shrines
            world.lairs = lairs
            world.standards = standards
            world.halls = halls
            world.storehouses = storehouses
            world.satchel = satchel
            world.makings = makings
        }

        /// None of it.
        init() {}

        /// Out of a head.
        static func clear(_ head: inout GameState) {
            Keeps().put(into: &head)
        }
    }

    /// The words a keeper hears.
    struct Words: Codable, Equatable {
        var words: [Word]?

        init(of world: GameState) {
            words = world.words
        }
    }

    /// The part what is on the road goes in.
    public static let goingsPart = "goings"

    /// What a pace changes of a world's head: where the watch's paces
    /// stand, the draws made and the next id.
    struct Pace: Codable, Equatable {
        var pacing: Pacing?
        var draws: UInt64
        var nextID: Int

        init(of world: GameState) {
            pacing = world.pacing
            draws = world.draws
            nextID = world.nextID
        }
    }

    /// What is on the road: the envoys, the marches under way and the gifts
    /// on their way. A world written before it went apart from the pace
    /// keeps it with the pace.
    struct Goings: Codable, Equatable {
        var envoys: [Envoy]
        var marches: [March]?
        var gifts: [Gift]?

        init(of world: GameState) {
            envoys = world.envoys
            marches = world.marches
            gifts = world.gifts
        }
    }

    /// A world's head given back its map and its long lists from `parts`;
    /// with `read`, each part decoded only if its text is new.
    mutating func join(_ parts: [String: String], using decoder: JSONDecoder, read: PartsRead? = nil) throws {
        func pages<T: Decodable>(_ name: String, of type: T.Type) throws -> [T] {
            let count = max(parts.keys.filter { $0.hasPrefix(name + ".") }.count, 1)
            return try (0..<count).flatMap { try GameState.part("\(name).\($0)", of: parts, using: decoder, as: [T].self, read: read) }
        }
        let apart = parts["ground.0"] != nil
        if apart || parts["map.0"] != nil {
            // The map in pages: as many as its head says, each of as many
            // tiles as it says.
            let pages: MapPages = try GameState.part("map", of: parts, using: decoder, read: read)
            // No more pages than there are parts: a head that says otherwise
            // is refused before anything is laid out for it.
            guard (1...MapPages.widest).contains(pages.radius), pages.page >= 1, pages.count <= parts.count else {
                throw RealmPartsError.unreadable("map")
            }
            // A page read, or taken as read when its text is as it was.
            func value<T>(_ name: String, _ decode: (String) -> T?) throws -> T {
                func decoded(_ text: String) throws -> T {
                    guard let value = decode(text) else { throw RealmPartsError.unreadable(name) }
                    return value
                }
                if let read { return try read.value(name, in: parts, decoded) }
                guard let text = parts[name] else { throw RealmPartsError.missing(name) }
                return try decoded(text)
            }
            // The relief first: a byte at the least for each tile, it tells
            // of no more of them than it holds, before the ground's runs are
            // laid out for as many.
            let reliefs: [Int]? = apart ? try value("relief", WorldMap.reliefs(fromText:)) : nil
            if let reliefs, reliefs.count != WorldMap.count(radius: pages.radius) { throw RealmPartsError.unreadable("relief") }
            var tiles: [Tile] = []
            for page in 0..<pages.count {
                let count = pages.tiles(of: page).count
                let name = apart ? "ground.\(page)" : "map.\(page)"
                let paged: [Tile]
                if apart {
                    paged = try value(name) { WorldMap.tiles(fromGround: $0, count: count) }
                } else {
                    paged = try value(name, WorldMap.tiles(fromCells:))
                }
                guard paged.count == count else { throw RealmPartsError.unreadable(name) }
                tiles += paged
            }
            if let reliefs {
                for index in tiles.indices { tiles[index].relief = reliefs[index] }
            }
            guard let whole = WorldMap(radius: pages.radius, tiles: tiles) else { throw RealmPartsError.unreadable("map") }
            map = whole
        } else {
            map = try GameState.part("map", of: parts, using: decoder, read: read)
        }
        // What a pace changes, apart from the head; a world written before
        // it went apart keeps it in its head.
        if parts[GameState.pacePart] != nil {
            let pace = try GameState.part(GameState.pacePart, of: parts, using: decoder, as: Pace.self, read: read)
            pacing = pace.pacing
            draws = pace.draws
            nextID = pace.nextID
            let goings = try GameState.part(parts[GameState.goingsPart] == nil ? GameState.pacePart : GameState.goingsPart, of: parts,
                                            using: decoder, as: Goings.self, read: read)
            envoys = goings.envoys
            marches = goings.marches
            gifts = goings.gifts
        }
        // And what every keeper is told alike; a world written before it
        // went apart keeps it in its head.
        if parts[GameState.commonPart] != nil {
            let common = try GameState.part(GameState.commonPart, of: parts, using: decoder, as: Common.self, read: read)
            reputed = common.reputed
            reputedMight = common.reputedMight
            stillHour = common.stillHour
            happening = common.happening
        }
        // And the rest of what every keeper is told alike, what is a
        // keeper's own and the words they hear; a world written before they
        // went apart keeps them in its head.
        if parts[GameState.realmPart] != nil {
            try GameState.part(GameState.realmPart, of: parts, using: decoder, as: Realm.self, read: read).put(into: &self)
        }
        if parts[GameState.keepsPart] != nil {
            try GameState.part(GameState.keepsPart, of: parts, using: decoder, as: Keeps.self, read: read).put(into: &self)
        }
        if parts[GameState.wordsPart] != nil {
            words = try GameState.part(GameState.wordsPart, of: parts, using: decoder, as: Words.self, read: read).words
        }
        units = Companies(try pages("units", of: Unit.self))
        houses = try pages("houses", of: House.self)
        // The deeds done, in pages; a world written before kept them in its head.
        if deedsDone != nil, parts["deeds.0"] != nil {
            deedsDone = try pages("deeds", of: DeedDone.self)
        }
        holds = Holdings(try pages("holds", of: Hold.self))
        // A view's own House and holds, and what allies tell of theirs, over
        // the pages every keeper is told alike.
        if parts[RealmView.ownPart] != nil {
            let own = try GameState.part(RealmView.ownPart, of: parts, using: decoder, as: RealmView.Own.self, read: read)
            for house in own.houses {
                guard houses.indices.contains(house.id), houses[house.id].id == house.id else { throw RealmPartsError.unreadable(RealmView.ownPart) }
                houses[house.id] = house
            }
            for hold in own.holds {
                guard let index = holds.index(ofID: hold.id) else { throw RealmPartsError.unreadable(RealmView.ownPart) }
                holds[index] = hold
            }
        }
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

/// A list a world keeps in pages: a plain list, or its holds or its
/// companies, each an array underneath, so a page of it is a stretch of
/// that array, compared where it lies.
extension [Relation] {
    /// Where the relations kept whose first House is one of a page's lie:
    /// the Houses `page * RealmState.relationPage` and the next so many.
    func firstIndices(of page: Int) -> Range<Int> {
        func place(_ house: Int) -> Int {
            var low = 0, high = count
            while low < high {
                let middle = (low + high) / 2
                if self[middle].first < house { low = middle + 1 } else { high = middle }
            }
            return low
        }
        return place(page * RealmState.relationPage)..<place((page + 1) * RealmState.relationPage)
    }
}

protocol Paged: RandomAccessCollection where Index == Int, Element: Equatable {
    /// The items of a stretch of the list, as they lie.
    func page(_ range: Range<Int>) -> ArraySlice<Element>
}

extension Array: Paged where Element: Equatable {
    func page(_ range: Range<Int>) -> ArraySlice<Element> { self[range] }
}

extension Holdings: Paged {}

extension Companies: Paged {}
