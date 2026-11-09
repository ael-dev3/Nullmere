import Foundation

/// The realm's holds in the order they were founded, with where each lies
/// and whose each is kept beside them: the hold on a hex, a House's holds
/// and its seat are found at once, not sought through every hold of the
/// realm, which a realm of many seats can't afford for every look.
///
/// Every change passes through here (a hold founded, taken, moved or
/// written anew, one at a time or many), so what it keeps never strays
/// from the holds. It reads, compares and is written as the plain list it
/// holds.
public struct Holdings: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, ExpressibleByArrayLiteral,
                        Equatable, Codable, Sendable {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    private var list: [Hold]
    /// Where in the list the holds on each hex lie, in the list's order.
    private var board: [Hex: [Int]]
    /// Where in the list each House's holds lie, in the list's order.
    private var owned: [Int: [Int]]
    /// Where in the list the holds of each square of the land lie, in the
    /// list's order, the land cut into squares eight hexes across by its
    /// coordinates: the holds near a hex are found among a few squares'
    /// holds, not sought through every hold of the realm.
    private var squares: [Square: [Int]]

    struct Square: Hashable {
        let q: Int
        let r: Int

        init(q: Int, r: Int) {
            self.q = q
            self.r = r
        }

        /// The square a hex lies in.
        init(_ hex: Hex) {
            self.init(q: hex.q >> Holdings.squareShift, r: hex.r >> Holdings.squareShift)
        }
    }

    /// Squares of eight hexes a side.
    static let squareShift = 3
    /// What the holds claim of the land follows from: a token drawn anew,
    /// unlike any other drawn in any realm, whenever a hold is founded or
    /// lost, or one's id, place, founding, seat or Beacon changes. Holds
    /// with the same token claim the same land (`GameState.territory`):
    /// the claims kept for them are theirs without each hold being asked.
    private(set) var claims: UInt64 = Holdings.drawClaims()

    public init() {
        list = []
        board = [:]
        owned = [:]
        squares = [:]
    }

    public init(arrayLiteral elements: Hold...) {
        self.init(elements)
    }

    public init<S: Sequence>(_ elements: S) where S.Element == Hold {
        list = Array(elements)
        board = [:]
        owned = [:]
        squares = [:]
        lay()
    }

    public init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode([Hold].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(list)
    }

    /// The same holds, the same in every way, in the same order: what is
    /// kept beside them follows from them.
    public static func == (lhs: Holdings, rhs: Holdings) -> Bool {
        lhs.list == rhs.list
    }

    /// The holds of a stretch of the list, as they lie: a page of them
    /// compared where they lie, not copied out one by one.
    func page(_ range: Range<Int>) -> ArraySlice<Hold> {
        list[range]
    }

    /// The hold at a place as every keeper is told it (`Hold.toldAlike`),
    /// or, as its House's allies are, but for who lies in its beds. Neither
    /// moves it, gives it to another House nor changes what it claims, so
    /// nothing kept beside the holds is asked again.
    mutating func tellAlike(at place: Int, toAllies: Bool = false) {
        list[place].wounded = nil
        guard !toAllies else { return }
        list[place].project = nil
        list[place].training = nil
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

    public subscript(position: Int) -> Hold {
        // Read where it lies, not copied out whole: a hold carries its works,
        // its stores and its plans.
        _read { yield list[position] }
        set {
            let was = (list[position].position, list[position].owner)
            let claimed = Holdings.claim(of: list[position])
            list[position] = newValue
            moved(position, from: was)
            if Holdings.claim(of: list[position]) != claimed { claims = Holdings.drawClaims() }
        }
        // Changed where it lies; moved on the board, or to its new House, only
        // if it moved or was taken.
        _modify {
            let was = (list[position].position, list[position].owner)
            let claimed = Holdings.claim(of: list[position])
            yield &list[position]
            moved(position, from: was)
            if Holdings.claim(of: list[position]) != claimed { claims = Holdings.drawClaims() }
        }
    }

    /// What a hold claims of the land by: its id, where it stands, when it
    /// was founded, and how far it reaches (by its seat and Beacon).
    private static func claim(of hold: Hold) -> Claims.Claimant {
        Claims.Claimant(id: hold.id, position: hold.position, founded: hold.foundedWatch, reach: hold.territoryRadius)
    }

    /// A token for the holds' claims none drawn before it shares.
    private static func drawClaims() -> UInt64 {
        Tokens.next()
    }

    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with elements: C) where C.Element == Hold {
        claims = Holdings.drawClaims()
        if subrange.isEmpty, subrange.lowerBound == list.count {
            // Founded at the end, as holds are: each laid where it is, after
            // every other.
            for hold in elements {
                list.append(hold)
                Holdings.lay(list.count - 1, into: &board[hold.position, default: []])
                Holdings.lay(list.count - 1, into: &owned[hold.owner, default: []])
                Holdings.lay(list.count - 1, into: &squares[Square(hold.position), default: []])
            }
            return
        }
        // Anything else moves the places of those after it: laid out anew.
        list.replaceSubrange(subrange, with: elements)
        lay()
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        list.reserveCapacity(minimumCapacity)
    }

    /// Those that answer, as a plain list, as the holds were sifted before
    /// they kept a board: a board is laid only where one is asked for
    /// (`Holdings(_:)`).
    public func filter(_ isIncluded: (Hold) throws -> Bool) rethrows -> [Hold] {
        try list.filter(isIncluded)
    }

    // MARK: Where they lie, and whose

    /// Where in the list the first hold on a hex lies, as a walk down the
    /// list would find it.
    public func first(at hex: Hex) -> Int? {
        board[hex]?.first
    }

    /// Where in the list a House's holds lie, in the list's order.
    public func places(of house: Int) -> [Int] {
        owned[house] ?? []
    }

    /// How many holds a House holds.
    public func count(of house: Int) -> Int {
        owned[house]?.count ?? 0
    }

    /// Where in the list the hold of an id lies: found by halving the list,
    /// as holds are founded each with an id above the one before; one not
    /// found so is looked for in each, should any be out of that order.
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

    private mutating func moved(_ place: Int, from was: (position: Hex, owner: Int)) {
        let now = list[place]
        if now.position != was.position {
            Holdings.lift(place, from: &board, at: was.position)
            Holdings.lay(place, into: &board[now.position, default: []])
            if Square(now.position) != Square(was.position) {
                Holdings.lift(place, from: &squares, at: Square(was.position))
                Holdings.lay(place, into: &squares[Square(now.position), default: []])
            }
        }
        if now.owner != was.owner {
            Holdings.lift(place, from: &owned, at: was.owner)
            Holdings.lay(place, into: &owned[now.owner, default: []])
        }
    }

    private mutating func lay() {
        board = [:]
        owned = [:]
        squares = [:]
        for place in list.indices {
            board[list[place].position, default: []].append(place)
            owned[list[place].owner, default: []].append(place)
            squares[Square(list[place].position), default: []].append(place)
        }
    }

    /// Where in the list each hold within `range` of a hex lies, in the
    /// list's order: the holds of the few squares about it looked at, not
    /// every hold of the realm. None for a hex so far beyond the world that
    /// its squares can't be told.
    public func places(within range: Int, of hex: Hex) -> [Int] {
        let range = Swift.max(range, 0), far = Int.max / 4
        guard hex.q > -far, hex.q < far, hex.r > -far, hex.r < far, range < far else { return [] }
        let shift = Holdings.squareShift
        var found: [Int] = []
        for q in ((hex.q - range) >> shift)...((hex.q + range) >> shift) {
            for r in ((hex.r - range) >> shift)...((hex.r + range) >> shift) {
                guard let places = squares[Square(q: q, r: r)] else { continue }
                for place in places where list[place].position.distance(to: hex) <= range { found.append(place) }
            }
        }
        if found.count > 1 { found.sort() }
        return found
    }

    /// A place laid among others in the list's order: changed where it lies.
    private static func lay(_ place: Int, into places: inout [Int]) {
        var at = places.count
        while at > 0, places[at - 1] > place { at -= 1 }
        places.insert(place, at: at)
    }

    private static func lift<Key: Hashable>(_ place: Int, from places: inout [Key: [Int]], at key: Key) {
        // Looked at, and let go before the key's places are changed in place.
        let found: (count: Int, at: Int)? = places[key].flatMap { list in list.firstIndex(of: place).map { (list.count, $0) } }
        guard let found else { return }
        if found.count == 1 { places[key] = nil } else { places[key]?.remove(at: found.at) }
    }

    /// Whether what it keeps holds every hold where it lies, in its square
    /// and whose it is, and nothing else: for the tests.
    func boardHolds() -> Bool {
        var hexes: [Hex: [Int]] = [:], houses: [Int: [Int]] = [:], cut: [Square: [Int]] = [:]
        for place in list.indices {
            hexes[list[place].position, default: []].append(place)
            houses[list[place].owner, default: []].append(place)
            cut[Square(list[place].position), default: []].append(place)
        }
        return hexes == board && houses == owned && cut == squares
    }
}
