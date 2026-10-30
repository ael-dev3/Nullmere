import Foundation

/// A House's settlement: its seat, or a hold founded later. A hold works
/// the land around it, builds, trains, and has a ward that attackers must
/// break before they can take it.
public struct Hold: Codable, Equatable, Identifiable, Sendable {
    public struct Project: Codable, Equatable, Sendable {
        public var kind: BuildingKind
        public var targetLevel: Int
        public var watchesLeft: Int
        /// The allied Houses that have helped it, if any.
        public var helpers: [Int]? = nil
    }

    public struct Training: Codable, Equatable, Sendable {
        public var kind: UnitKind
        public var watchesLeft: Int
        /// The tier it musters at; absent for the first, as in older saves.
        public var tier: Int?
        /// The allied Houses that have helped it, if any.
        public var helpers: [Int]?

        public init(kind: UnitKind, watchesLeft: Int, tier: Int? = nil) {
            self.kind = kind
            self.watchesLeft = watchesLeft
            self.tier = tier.flatMap { $0 > 1 ? $0 : nil }
            self.helpers = nil
        }

        /// The tier it musters at.
        public var musteredTier: Int { tier ?? 1 }
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
    /// Its House's companies of war carried here from the field, in the
    /// beds of its Infirmary until they are healed; absent while none are.
    public var wounded: [Wounded]?

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
        self.wounded = nil
    }

    public func level(_ kind: BuildingKind) -> Int {
        levels[kind] ?? 0
    }

    // Written in a fixed order, as a dictionary would be in any order: the
    // steward sends a keeper's view only when its words change.
    private enum CodingKeys: String, CodingKey {
        case id, name, owner, position, isSeat, levels, project, training, ward, struck, foundedWatch, wounded
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(owner, forKey: .owner)
        try container.encode(position, forKey: .position)
        try container.encode(isSeat, forKey: .isSeat)
        var built = container.nestedUnkeyedContainer(forKey: .levels)
        for kind in BuildingKind.allCases {
            if let level = levels[kind] {
                try built.encode(kind)
                try built.encode(level)
            }
        }
        try container.encodeIfPresent(project, forKey: .project)
        try container.encodeIfPresent(training, forKey: .training)
        try container.encode(ward, forKey: .ward)
        try container.encode(struck, forKey: .struck)
        try container.encode(foundedWatch, forKey: .foundedWatch)
        try container.encodeIfPresent(wounded, forKey: .wounded)
    }

    public var maximumWard: Int { Hold.maximumWard(wallLevel: level(.walls), isSeat: isSeat) }
    /// The companies its Infirmary can keep.
    public var beds: Int { Hold.beds(infirmaryLevel: level(.infirmary)) }
    /// Its beds no company lies in.
    public var freeBeds: Int { max(0, beds - (wounded?.count ?? 0)) }

    /// The companies an Infirmary of a level can keep: two at the first,
    /// one more at each level after.
    public static func beds(infirmaryLevel level: Int) -> Int {
        level > 0 ? level + 1 : 0
    }
    public var sight: Int { Hold.sight(beaconLevel: level(.beacon)) }
    public var territoryRadius: Int { Hold.territoryRadius(isSeat: isSeat, beaconLevel: level(.beacon)) }

    /// How much stronger a garrison stands within its own hold's walls, in
    /// percent of its defence.
    public static func garrisonBonus(wallLevel: Int) -> Int {
        15 + 10 * wallLevel
    }

    public static func maximumWard(wallLevel: Int, isSeat: Bool = false) -> Int {
        30 + 30 * wallLevel + (isSeat ? 20 : 0)
    }

    /// From this Muster Hall level, every company that takes more than a
    /// watch to train takes one fewer.
    public static let fasterTrainingAt = 3

    /// Watches a company takes to train at this hold, before its House's
    /// studies hasten it.
    public func trainingWatches(for kind: UnitKind, tier: Int = 1) -> Int {
        let watches = kind.trainWatches(tier: tier)
        return watches - (level(.musterHall) >= Hold.fasterTrainingAt && watches > 1 ? 1 : 0)
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
    /// Held by a keeper, a person, rather than played by a steward.
    public var isPlayer: Bool
    public var temperament: Temperament
    public var stock: Stock
    /// Tiles this House has ever seen, by map index.
    public var explored: [Bool]
    public var isEliminated: Bool
    /// The House this one has sworn fealty to, if any.
    public var liege: Int?
    /// What it has studied, and what it studies now.
    public var research = Research()

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

    // The explored ground travels as bits, eight tiles to a byte: a keeper's
    // view goes across the network whenever it changes.
    private enum CodingKeys: String, CodingKey {
        case id, name, sigil, isPlayer, temperament, stock, explored, exploredBits, isEliminated, liege, research
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sigil = try container.decode(Int.self, forKey: .sigil)
        isPlayer = try container.decode(Bool.self, forKey: .isPlayer)
        temperament = try container.decode(Temperament.self, forKey: .temperament)
        stock = try container.decode(Stock.self, forKey: .stock)
        if let bits = try container.decodeIfPresent(String.self, forKey: .exploredBits) {
            guard let explored = Bits.decode(bits) else {
                throw DecodingError.dataCorruptedError(forKey: .exploredBits, in: container, debugDescription: "Unreadable explored ground")
            }
            self.explored = explored
        } else {
            explored = try container.decode([Bool].self, forKey: .explored)
        }
        isEliminated = try container.decode(Bool.self, forKey: .isEliminated)
        liege = try container.decodeIfPresent(Int.self, forKey: .liege)
        // Saves from before studies know none.
        research = try container.decodeIfPresent(Research.self, forKey: .research) ?? Research()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sigil, forKey: .sigil)
        try container.encode(isPlayer, forKey: .isPlayer)
        try container.encode(temperament, forKey: .temperament)
        try container.encode(stock, forKey: .stock)
        try container.encode(Bits.encode(explored), forKey: .exploredBits)
        try container.encode(isEliminated, forKey: .isEliminated)
        try container.encodeIfPresent(liege, forKey: .liege)
        if !research.isEmpty { try container.encode(research, forKey: .research) }
    }
}

/// Booleans as "count:base64", eight to a byte.
enum Bits {
    static func encode(_ values: [Bool]) -> String {
        var bytes = [UInt8](repeating: 0, count: (values.count + 7) / 8)
        for (index, value) in values.enumerated() where value {
            bytes[index / 8] |= 1 << UInt8(index % 8)
        }
        return "\(values.count):" + Data(bytes).base64EncodedString()
    }

    static func decode(_ text: String) -> [Bool]? {
        let parts = text.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let count = Int(parts[0]), count >= 0,
              let data = Data(base64Encoded: String(parts[1])), data.count == (count + 7) / 8 else { return nil }
        let bytes = [UInt8](data)
        return (0..<count).map { bytes[$0 / 8] & (1 << UInt8($0 % 8)) != 0 }
    }
}
