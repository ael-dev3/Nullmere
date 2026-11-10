import Foundation

/// A House named over its land as a keeper's view draws away from the holds
/// to take in the country, as Rise of Kingdoms' kingdom map names each
/// governor's city from afar: its name stands at its seat.
public struct NamedAfar: Equatable, Sendable {
    /// How a House named stands to the keeper's own, the order in which
    /// names are placed where they would crowd.
    public enum Standing: Int, Comparable, Sendable {
        case own, allied, atWar, other

        public static func < (a: Standing, b: Standing) -> Bool { a.rawValue < b.rawValue }
    }

    /// The House named.
    public let house: Int
    /// Its seat, where its name stands.
    public let seat: Hex
    /// How it stands to the keeper's House.
    public let standing: Standing
}

extension GameState {
    /// The Houses a keeper's map names from afar: every House still standing
    /// whose seat stands on ground the keeper's House has explored, its own
    /// always. They come in the order their names are placed where names
    /// would crowd, so the ones that matter most are never the ones left
    /// out: the keeper's own first, then its alliance's, then those at war
    /// with it, then the rest; within each, the nearest `centre` first (then
    /// by House, so the order never wavers as the view moves).
    public func namedFromAfar(by house: Int, around centre: Hex) -> [NamedAfar] {
        var named: [NamedAfar] = []
        for other in houses where !other.isEliminated {
            guard let seat = seat(of: other.id)?.position, other.id == house || isExplored(seat, by: house) else { continue }
            let standing: NamedAfar.Standing = other.id == house ? .own
                : areAllied(house, other.id) ? .allied
                : isAtWar(house, other.id) ? .atWar : .other
            named.append(NamedAfar(house: other.id, seat: seat, standing: standing))
        }
        return named.sorted {
            ($0.standing, $0.seat.distance(to: centre), $0.house) < ($1.standing, $1.seat.distance(to: centre), $1.house)
        }
    }
}
