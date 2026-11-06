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

    public init() {
        list = []
        board = [:]
    }

    public init(arrayLiteral elements: Unit...) {
        self.init(elements)
    }

    public init<S: Sequence>(_ elements: S) where S.Element == Unit {
        list = Array(elements)
        board = [:]
        for unit in list { stand(unit.id, on: unit.position) }
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
            let was = list[position]
            list[position] = newValue
            if was.id != newValue.id || was.position != newValue.position {
                leave(was.id, from: was.position)
                stand(newValue.id, on: newValue.position)
            }
        }
        // Changed where it lies; moved on the board only if it moved.
        _modify {
            let id = list[position].id, at = list[position].position
            yield &list[position]
            if list[position].id != id || list[position].position != at {
                leave(id, from: at)
                stand(list[position].id, on: list[position].position)
            }
        }
    }

    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with elements: C) where C.Element == Unit {
        for index in subrange { leave(list[index].id, from: list[index].position) }
        list.replaceSubrange(subrange, with: elements)
        for unit in elements { stand(unit.id, on: unit.position) }
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

    private mutating func stand(_ id: Int, on hex: Hex) {
        Companies.insert(id, into: &board[hex, default: []])
    }

    /// An id laid among a hex's, lowest first: changed where it lies.
    private static func insert(_ id: Int, into ids: inout [Int]) {
        var place = ids.count
        while place > 0, ids[place - 1] > id { place -= 1 }
        ids.insert(id, at: place)
    }

    private mutating func leave(_ id: Int, from hex: Hex) {
        // Looked at, and let go before the hex's ids are changed in place.
        let found: (count: Int, place: Int)? = board[hex].flatMap { ids in ids.firstIndex(of: id).map { (ids.count, $0) } }
        guard let found else { return }
        if found.count == 1 { board[hex] = nil } else { board[hex]?.remove(at: found.place) }
    }

    /// Whether the board holds every company where it stands and nothing
    /// else: for the tests.
    func boardHolds() -> Bool {
        var expected: [Hex: [Int]] = [:]
        for unit in list { expected[unit.position, default: []].append(unit.id) }
        for key in expected.keys { expected[key]?.sort() }
        return expected == board
    }
}
