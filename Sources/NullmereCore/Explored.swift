import Foundation

/// The tiles a House has ever seen, by map index: one bit to a tile, read
/// and written as a list of yes and no. A lake of many seats has hundreds
/// of thousands of tiles for each of its hundreds of Houses, and a byte to
/// a tile would hold the realm's memory hostage to the square of its seats.
public struct Explored: RandomAccessCollection, MutableCollection, Equatable, Hashable, Sendable, ExpressibleByArrayLiteral {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    /// How many tiles it tells of.
    public private(set) var count: Int
    /// The tiles, sixty-four to a word, the first in each word's lowest bit;
    /// none set past the last tile.
    private(set) var words: [UInt64]

    public init() {
        count = 0
        words = []
    }

    public init(repeating value: Bool, count: Int) {
        self.count = Swift.max(count, 0)
        words = [UInt64](repeating: value ? ~0 : 0, count: (self.count + 63) / 64)
        if value { trim() }
    }

    public init<S: Sequence>(_ values: S) where S.Element == Bool {
        var words: [UInt64] = []
        var count = 0
        for value in values {
            if count % 64 == 0 { words.append(0) }
            if value { words[count / 64] |= 1 << UInt64(count % 64) }
            count += 1
        }
        self.count = count
        self.words = words
    }

    public init(arrayLiteral elements: Bool...) {
        self.init(elements)
    }

    /// Tiles told of by eight to a byte, the first in each byte's lowest
    /// bit, as they travel (`Bits`).
    init(count: Int, bytes: [UInt8]) {
        self.count = count
        var words = [UInt64](repeating: 0, count: (count + 63) / 64)
        for (index, byte) in bytes.enumerated() where byte != 0 && index / 8 < words.count {
            words[index / 8] |= UInt64(byte) << UInt64(8 * (index % 8))
        }
        self.words = words
        trim()
    }

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }
    public var indices: Range<Int> { 0..<count }
    public var isEmpty: Bool { count == 0 }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public func index(_ i: Int, offsetBy distance: Int) -> Int { i + distance }
    public func distance(from start: Int, to end: Int) -> Int { end - start }

    public subscript(position: Int) -> Bool {
        get {
            precondition(position >= 0 && position < count, "No tile \(position) of \(count)")
            return words[position >> 6] & (1 << UInt64(position & 63)) != 0
        }
        set {
            precondition(position >= 0 && position < count, "No tile \(position) of \(count)")
            if newValue {
                words[position >> 6] |= 1 << UInt64(position & 63)
            } else {
                words[position >> 6] &= ~(1 << UInt64(position & 63))
            }
        }
    }

    /// Whether any tile is told of as `value`: a word at a time.
    public func contains(_ value: Bool) -> Bool {
        value ? words.contains { $0 != 0 } : setCount < count
    }

    /// How many tiles are seen.
    public var setCount: Int {
        words.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    /// Each tile seen, by its index, in order: a word at a time, the unseen
    /// passed over sixty-four at once.
    func forEachSeen(_ body: (Int) -> Void) {
        for (word, bits) in words.enumerated() where bits != 0 {
            var rest = bits
            while rest != 0 {
                body(word << 6 | rest.trailingZeroBitCount)
                rest &= rest &- 1
            }
        }
    }

    /// The tiles as bytes, eight to a byte, the first in each byte's lowest
    /// bit: as many as the tiles need.
    var bytes: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: (count + 7) / 8)
        for index in bytes.indices {
            bytes[index] = UInt8(truncatingIfNeeded: words[index / 8] >> UInt64(8 * (index % 8)))
        }
        return bytes
    }

    /// The tiles as runs: how many unseen, then how many seen, and so on
    /// by turns to the last tile, the first run of unseen perhaps none. A
    /// House's ground lies together, so its hundreds of thousands of tiles
    /// are a few hundred runs. Found a word at a time.
    var runs: [Int] {
        var runs: [Int] = []
        var start = 0, seen = false
        while start < count {
            let end = next(from: start, otherThan: seen)
            runs.append(end - start)
            start = end
            seen.toggle()
        }
        return runs
    }

    /// The first tile from `start` on not told of as `value`, or `count`.
    private func next(from start: Int, otherThan value: Bool) -> Int {
        var word = start >> 6
        guard word < words.count else { return count }
        // The bits that differ from `value`, from `start` on.
        var bits = (value ? ~words[word] : words[word]) & (~0 << UInt64(start & 63))
        while bits == 0 {
            word += 1
            guard word < words.count else { return count }
            bits = value ? ~words[word] : words[word]
        }
        return Swift.min(word << 6 | bits.trailingZeroBitCount, count)
    }

    /// The tiles of `runs`, by turns unseen and seen; none if they don't come
    /// to `count` tiles, or a run but the first is of none.
    init?(count: Int, runs: [Int]) {
        guard count >= 0, runs.allSatisfy({ $0 >= 0 }), runs.dropFirst().allSatisfy({ $0 > 0 }) else { return nil }
        // Counted so that runs past the tiles are refused before their sum
        // could run past any number.
        var told = 0
        for run in runs {
            guard run <= count - told else { return nil }
            told += run
        }
        guard told == count else { return nil }
        self.init(repeating: false, count: count)
        var at = 0
        for (index, run) in runs.enumerated() {
            if index % 2 == 1 {
                for tile in at..<(at + run) { words[tile >> 6] |= 1 << UInt64(tile & 63) }
            }
            at += run
        }
    }

    /// No bit set past the last tile.
    private mutating func trim() {
        guard count % 64 != 0, !words.isEmpty else { return }
        words[words.count - 1] &= (1 << UInt64(count % 64)) - 1
    }
}

extension Explored {
    /// Nothing known of a map of `count` tiles: one kept for every map of
    /// that size, so every House told as a stranger knows the very same
    /// nothing, and two of them are found alike at a glance (one storage),
    /// not word by word across a wide lake's hundreds of thousands of tiles.
    public static func unknown(count: Int) -> Explored {
        NothingKnown.shared.explored(count: count)
    }
}

/// The nothing known of each map's size, made once.
private final class NothingKnown: @unchecked Sendable {
    static let shared = NothingKnown()
    private let lock = NSLock()
    private var kept: [Int: Explored] = [:]

    func explored(count: Int) -> Explored {
        lock.lock()
        defer { lock.unlock() }
        if let known = kept[count] { return known }
        let made = Explored(repeating: false, count: count)
        kept[count] = made
        return made
    }
}
