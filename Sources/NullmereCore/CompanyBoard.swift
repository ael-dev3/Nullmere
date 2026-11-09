/// The realm's companies in the order they were raised, with a board of
/// where each stands kept beside them: who stands on a hex is found at
/// once, not sought through every company of the realm, which a realm of
/// many seats can't afford for every company's every look about it.
///
/// Every change passes through here (a company raised, lost, moved or
/// written anew, one at a time or many), so the board never strays from
/// where the companies stand. It reads, compares and is written as the
/// plain list it holds.
public struct Companies: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, ExpressibleByArrayLiteral,
                         Equatable, Codable, Sendable {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    private var list: [Unit]
    /// The ids of the companies standing on each hex, lowest first: a hex
    /// a company has left is let go.
    private var board: [Hex: [Int]]
    /// The ids of each House's companies, lowest first.
    private var owned: [Int: [Int]]
    /// Where the companies stand, as a token drawn anew (unlike any drawn in
    /// any realm) whenever one moves, is raised or falls: companies holding
    /// the same token stand where they stood.
    private(set) var stand: UInt64 = Tokens.next()
    /// The latest changes to where they stand (a company moved, one fallen,
    /// or ones raised at the list's end), each from the token before it to
    /// the one it drew, so a look that last saw the companies at one of
    /// those tokens need bring up only those changed since (`SearchRoom`),
    /// not every company of the realm. Any other change begins them afresh.
    private var shifts: [Shift] = []

    struct Shift: Sendable {
        enum Kind: Sendable {
            case moved, fell, raised
        }

        let from: UInt64
        let to: UInt64
        let id: Int
        let kind: Kind
    }

    /// How many of the latest moves are kept.
    static let shiftsKept = 64

    public init() {
        list = []
        board = [:]
        owned = [:]
    }

    public init(arrayLiteral elements: Unit...) {
        self.init(elements)
    }

    public init<S: Sequence>(_ elements: S) where S.Element == Unit {
        list = Array(elements)
        board = [:]
        owned = [:]
        for unit in list { enter(unit) }
    }

    public init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode([Unit].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(list)
    }

    /// The same companies, the same in every way, in the same order: the
    /// board follows from them.
    public static func == (lhs: Companies, rhs: Companies) -> Bool {
        lhs.list == rhs.list
    }

    /// The companies of a stretch of the list, as they lie: a page of them
    /// compared where they lie, not copied out one by one.
    func page(_ range: Range<Int>) -> ArraySlice<Unit> {
        list[range]
    }

    // MARK: A list

    public var startIndex: Int { 0 }
    public var endIndex: Int { list.count }
    public var indices: Range<Int> { 0..<list.count }
    public var count: Int { list.count }
    public var isEmpty: Bool { list.isEmpty }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public func index(_ i: Int, offsetBy distance: Int) -> Int { i + distance }
    public func distance(from start: Int, to end: Int) -> Int { end - start }

    public subscript(position: Int) -> Unit {
        // Read where it lies, not copied out whole: a company is two
        // hundred bytes and asked after many thousand times a watch.
        _read { yield list[position] }
        set {
            let was = (id: list[position].id, at: list[position].position, owner: list[position].owner)
            list[position] = newValue
            moved(position, from: was)
        }
        // Changed where it lies; moved on the board only if it moved, and to
        // another House only if it was given over.
        _modify {
            let was = (id: list[position].id, at: list[position].position, owner: list[position].owner)
            yield &list[position]
            moved(position, from: was)
        }
    }

    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with elements: C) where C.Element == Unit {
        // One company fallen, or companies raised at the list's end, kept
        // among the changes; anything else begins them afresh.
        let fell = subrange.count == 1 && elements.isEmpty ? list[subrange.lowerBound].id : nil
        let raised = subrange.isEmpty && subrange.lowerBound == list.count ? elements.map(\.id) : []
        for index in subrange { leave(list[index].id, at: list[index].position, of: list[index].owner) }
        list.replaceSubrange(subrange, with: elements)
        for unit in elements { enter(unit) }
        if let fell {
            shift(fell, .fell)
        } else if !raised.isEmpty {
            for id in raised { shift(id, .raised) }
        } else {
            restand()
        }
    }

    /// What changed of where the companies stand since they stood at
    /// `token`, in the order it changed: nothing if they stand there still,
    /// nil if what changed since is not all kept (a company put among the
    /// rest, more changes than are kept, or a token these companies never
    /// stood at).
    func moved(since token: UInt64) -> [Shift]? {
        if token == stand { return [] }
        guard let start = shifts.lastIndex(where: { $0.from == token }) else { return nil }
        var at = token
        for shift in shifts[start...] {
            guard shift.from == at else { return nil }
            at = shift.to
        }
        return at == stand ? Array(shifts[start...]) : nil
    }

    /// One company moved, fallen or raised: a token drawn for where they
    /// stand now, and the change kept.
    private mutating func shift(_ id: Int, _ kind: Shift.Kind = .moved) {
        let to = Tokens.next()
        if shifts.count >= Companies.shiftsKept { shifts.removeFirst(shifts.count - Companies.shiftsKept + 1) }
        shifts.append(Shift(from: stand, to: to, id: id, kind: kind))
        stand = to
    }

    /// Companies changed otherwise: a token drawn afresh, and the changes
    /// kept begun again.
    private mutating func restand() {
        stand = Tokens.next()
        shifts.removeAll(keepingCapacity: true)
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        list.reserveCapacity(minimumCapacity)
    }

    /// Those that answer, as a plain list, as the companies were sifted
    /// before they kept a board: a board is laid only where one is asked
    /// for (`Companies(_:)`).
    public func filter(_ isIncluded: (Unit) throws -> Bool) rethrows -> [Unit] {
        try list.filter(isIncluded)
    }

    // MARK: Where they stand

    /// The ids of the companies standing on a hex, lowest first.
    public func ids(at hex: Hex) -> [Int] {
        board[hex] ?? []
    }

    /// Whether any company stands on a hex.
    public func isHeld(_ hex: Hex) -> Bool {
        board[hex] != nil
    }

    /// The ids of a House's companies, lowest first.
    public func ids(of house: Int) -> [Int] {
        owned[house] ?? []
    }

    /// Where in the list a House's companies lie, in the list's order.
    public func places(of house: Int) -> [Int] {
        guard let ids = owned[house] else { return [] }
        var places = ids.compactMap(index(ofID:))
        // As raised, lowest id first, the list's order already; sorted only
        // should any lie out of that order.
        if zip(places, places.dropFirst()).contains(where: { $0 >= $1 }) { places.sort() }
        return places
    }

    /// Where in the list the first company standing on a hex lies, as a
    /// walk down the list would find it first.
    public func first(at hex: Hex) -> Int? {
        guard let ids = board[hex] else { return nil }
        if ids.count == 1 { return index(ofID: ids[0]) }
        return ids.compactMap(index(ofID:)).min()
    }

    /// Where in the list the company of an id lies: found by halving the
    /// list, as companies are raised each with an id above the one before;
    /// one not found so is looked for in each, should any be out of that
    /// order.
    public func index(ofID id: Int) -> Int? {
        var low = 0, high = list.count
        while low < high {
            let middle = (low + high) / 2
            let found = list[middle].id
            if found == id { return middle }
            if found < id { low = middle + 1 } else { high = middle }
        }
        for index in list.indices where list[index].id == id { return index }
        return nil
    }

    private mutating func enter(_ unit: Unit) {
        Companies.lay(unit.id, into: &board[unit.position, default: []])
        Companies.lay(unit.id, into: &owned[unit.owner, default: []])
    }

    private mutating func leave(_ id: Int, at hex: Hex, of owner: Int) {
        Companies.lift(id, from: &board, at: hex)
        Companies.lift(id, from: &owned, at: owner)
    }

    private mutating func moved(_ place: Int, from was: (id: Int, at: Hex, owner: Int)) {
        let now = list[place]
        if now.id != was.id || now.position != was.at {
            Companies.lift(was.id, from: &board, at: was.at)
            Companies.lay(now.id, into: &board[now.position, default: []])
            if now.id == was.id { shift(now.id) } else { restand() }
        }
        if now.id != was.id || now.owner != was.owner {
            Companies.lift(was.id, from: &owned, at: was.owner)
            Companies.lay(now.id, into: &owned[now.owner, default: []])
        }
    }

    /// An id laid among others, lowest first: changed where it lies.
    private static func lay(_ id: Int, into ids: inout [Int]) {
        var place = ids.count
        while place > 0, ids[place - 1] > id { place -= 1 }
        ids.insert(id, at: place)
    }

    private static func lift<Key: Hashable>(_ id: Int, from ids: inout [Key: [Int]], at key: Key) {
        // Looked at, and let go before the key's ids are changed in place.
        let found: (count: Int, place: Int)? = ids[key].flatMap { list in list.firstIndex(of: id).map { (list.count, $0) } }
        guard let found else { return }
        if found.count == 1 { ids[key] = nil } else { ids[key]?.remove(at: found.place) }
    }

    /// Whether the board holds every company where it stands, and each
    /// House's its own, and nothing else: for the tests.
    func boardHolds() -> Bool {
        var hexes: [Hex: [Int]] = [:], houses: [Int: [Int]] = [:]
        for unit in list {
            hexes[unit.position, default: []].append(unit.id)
            houses[unit.owner, default: []].append(unit.id)
        }
        for key in hexes.keys { hexes[key]?.sort() }
        for key in houses.keys { houses[key]?.sort() }
        return hexes == board && houses == owned
    }
}
