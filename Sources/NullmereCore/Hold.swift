/// A House's settlement: its seat, or a hold founded later. A hold works
/// the land around it, builds, trains, and has a ward that attackers must
/// break before they can take it.
public struct Hold: Codable, Equatable, Identifiable, Sendable {
    public struct Project: Codable, Equatable, Sendable {
        public var kind: BuildingKind
        public var targetLevel: Int
        public var watchesLeft: Int
    }

    public struct Training: Codable, Equatable, Sendable {
        public var kind: UnitKind
        public var watchesLeft: Int
    }

    public let id: Int
    public var name: String
    public var owner: Int
    public let position: Hex
    public var isSeat: Bool
    public var levels: [BuildingKind: Int]
    public var project: Project?
    public var training: Training?
    public var ward: Int
    /// Struck this watch, so its ward doesn't recover.
    public var struck: Bool
    public let foundedWatch: Int

    public init(id: Int, name: String, owner: Int, position: Hex, isSeat: Bool, foundedWatch: Int) {
        self.id = id
        self.name = name
        self.owner = owner
        self.position = position
        self.isSeat = isSeat
        self.levels = [:]
        self.project = nil
        self.training = nil
        self.ward = Hold.maximumWard(wallLevel: 0, isSeat: isSeat)
        self.struck = false
        self.foundedWatch = foundedWatch
    }

    public func level(_ kind: BuildingKind) -> Int {
        levels[kind] ?? 0
    }

    public var maximumWard: Int { Hold.maximumWard(wallLevel: level(.walls), isSeat: isSeat) }
    public var sight: Int { Hold.sight(beaconLevel: level(.beacon)) }
    public var territoryRadius: Int { Hold.territoryRadius(isSeat: isSeat, beaconLevel: level(.beacon)) }

    public static func maximumWard(wallLevel: Int, isSeat: Bool = false) -> Int {
        30 + 30 * wallLevel + (isSeat ? 20 : 0)
    }

    public static func sight(beaconLevel: Int) -> Int {
        2 + beaconLevel
    }

    public static func territoryRadius(isSeat: Bool, beaconLevel: Int) -> Int {
        (isSeat ? 2 : 1) + (beaconLevel >= 2 ? 1 : 0)
    }

    /// Ward regained each watch the hold isn't struck.
    public static let wardRecovery = 10

    /// What a blow takes from a ward, before chance.
    public static func strikeDamage(attack: Int, health: Int) -> Int {
        12 + attack * 4 * health / 100
    }
}

/// How a rival House tends to play.
public enum Temperament: String, CaseIterable, Codable, Sendable {
    /// Expands fast and strikes when stronger.
    case ambitious
    /// Builds, fortifies and reaches for the Moonspire.
    case steadfast
    /// Keeps its word and fights only when wronged.
    case wary
    /// Makes pacts, then breaks them when it pays.
    case cunning

    public var title: String {
        switch self {
        case .ambitious: return "Ambitious"
        case .steadfast: return "Steadfast"
        case .wary: return "Wary"
        case .cunning: return "Cunning"
        }
    }
}

/// One of the great Houses around the lake.
public struct House: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public var name: String
    /// Index into the House colours.
    public var sigil: Int
    public var isPlayer: Bool
    public var temperament: Temperament
    public var stock: Stock
    /// Tiles this House has ever seen, by map index.
    public var explored: [Bool]
    public var isEliminated: Bool
    /// The House this one has sworn fealty to, if any.
    public var liege: Int?

    public var title: String { "House \(name)" }

    public init(id: Int, name: String, sigil: Int, isPlayer: Bool, temperament: Temperament, tileCount: Int) {
        self.id = id
        self.name = name
        self.sigil = sigil
        self.isPlayer = isPlayer
        self.temperament = temperament
        self.stock = Stock(grain: 60, timber: 50, stone: 40, moonsalt: 5)
        self.explored = Array(repeating: false, count: tileCount)
        self.isEliminated = false
    }
}
