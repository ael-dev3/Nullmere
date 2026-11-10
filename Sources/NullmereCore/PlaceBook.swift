import Foundation

/// A place a keeper keeps in their book to come back to (RoK's bookmarks):
/// where, the name it is kept by, and the watch it was kept.
public struct KeptPlace: Codable, Equatable, Sendable, Identifiable {
    public let at: Hex
    public var name: String
    public let kept: Int

    public init(at: Hex, name: String, kept: Int) {
        self.at = at
        self.name = name
        self.kept = kept
    }

    public var id: Hex { at }
}

/// The places a keeper keeps in their book, the newest first: one to a
/// hex, at most `limit` of them, each named as the keeper would say it
/// unless they name it otherwise. The keeper's own, kept by their Mac for
/// the age; the realm knows nothing of it.
public struct PlaceBook: Codable, Equatable, Sendable {
    public private(set) var places: [KeptPlace] = []

    /// How many places a book keeps, and how long a name may run.
    public static let limit = 20
    public static let longestName = 40

    public init() {}

    public func place(at hex: Hex) -> KeptPlace? {
        places.first { $0.at == hex }
    }

    public var isFull: Bool { places.count >= PlaceBook.limit }

    /// A name as a book keeps it: on one line, its words a space apart and
    /// none about them, no longer than `longestName`; nil if nothing is left.
    public static func kept(_ name: String) -> String? {
        let line = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !line.isEmpty else { return nil }
        return String(line.prefix(longestName)).trimmingCharacters(in: .whitespaces)
    }

    /// Keeps `hex` by `name` at `watch`, the newest first; false where the
    /// book keeps it already, is full, or the name is empty.
    @discardableResult
    public mutating func keep(_ hex: Hex, named name: String, at watch: Int) -> Bool {
        guard place(at: hex) == nil, !isFull, let name = PlaceBook.kept(name) else { return false }
        places.insert(KeptPlace(at: hex, name: name, kept: watch), at: 0)
        return true
    }

    /// Lets the place at `hex` go from the book, if it keeps it.
    public mutating func forget(_ hex: Hex) {
        places.removeAll { $0.at == hex }
    }

    /// Names the place at `hex` anew; false where the book doesn't keep it
    /// or the name is empty.
    @discardableResult
    public mutating func rename(_ hex: Hex, to name: String) -> Bool {
        guard let index = places.firstIndex(where: { $0.at == hex }), let name = PlaceBook.kept(name) else { return false }
        places[index].name = name
        return true
    }
}

extension PlaceBook {
    /// The book in a line, as the Mac's list folded away and the phone's
    /// menu say it.
    public var summary: String {
        guard let newest = places.first else {
            return "No places kept. Keep one from a hold or the ground to come back to it."
        }
        let count = places.count == 1 ? "1 place kept" : "\(places.count) places kept"
        return "\(count), the newest \(newest.name)."
    }

    /// Why the book can't keep another place, while it can't.
    public var refusal: String? {
        isFull ? "Your book keeps \(PlaceBook.limit) places: forget one to keep another." : nil
    }
}

extension GameState {
    /// What stands at a kept place now, if it goes by another name than it
    /// was kept by, and since when it is kept.
    public func keptLine(_ place: KeptPlace) -> String {
        let now = keptName(of: place.at)
        let since = "kept at watch \(place.kept)"
        return now == place.name ? since.prefix(1).uppercased() + since.dropFirst() : "\(now), \(since)"
    }

    /// What a place is called in a keeper's book unless they name it: the
    /// hold standing there, or its ground by the nearest hold within a few
    /// tiles, as a report says where something happened.
    public func keptName(of hex: Hex) -> String {
        if let hold = hold(at: hex) { return hold.name }
        let ground = map[hex].map { $0.terrain.ground } ?? "the field"
        let near = holds.filter { $0.position.distance(to: hex) <= 4 }
            .min { ($0.position.distance(to: hex), $0.id) < ($1.position.distance(to: hex), $1.id) }
        let named = near.map { "\(ground) by \($0.name)" } ?? ground
        return named.prefix(1).uppercased() + named.dropFirst()
    }
}
