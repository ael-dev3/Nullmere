/// Who a House can send out from its holds.
public enum UnitKind: String, CaseIterable, Codable, Sendable {
    /// A scout carrying light into the dark country.
    case lantern
    case spear
    case bow
    case rider
    /// Settlers who found a new hold where they stand.
    case founder

    public var title: String {
        switch self {
        case .lantern: return "Lanterns"
        case .spear: return "Spears"
        case .bow: return "Bows"
        case .rider: return "Riders"
        case .founder: return "Founders"
        }
    }

    public var attack: Int {
        switch self {
        case .lantern: return 1
        case .spear: return 6
        case .bow: return 5
        case .rider: return 8
        case .founder: return 0
        }
    }

    public var defense: Int {
        switch self {
        case .lantern: return 2
        case .spear: return 7
        case .bow: return 4
        case .rider: return 5
        case .founder: return 1
        }
    }

    public var movement: Int {
        switch self {
        case .lantern, .rider: return 4
        case .spear, .bow, .founder: return 2
        }
    }

    public var sight: Int {
        switch self {
        case .lantern: return 3
        default: return 2
        }
    }

    /// Bows strike from two tiles away and take no blow in return.
    public var range: Int { self == .bow ? 2 : 1 }

    public var isMilitary: Bool { attack > 1 }

    /// Military units that can take a hold once its ward falls.
    public var canCapture: Bool { self == .spear || self == .rider }

    /// Muster Hall level needed to train this; zero needs none.
    public var requiredMuster: Int {
        switch self {
        case .lantern, .founder: return 0
        case .spear: return 1
        case .bow: return 2
        case .rider: return 3
        }
    }

    public var cost: Stock {
        switch self {
        case .lantern: return Stock(grain: 15, timber: 10)
        case .spear: return Stock(grain: 25, timber: 15, stone: 10)
        case .bow: return Stock(grain: 25, timber: 30)
        case .rider: return Stock(grain: 40, timber: 15, stone: 10, moonsalt: 8)
        case .founder: return Stock(grain: 60, timber: 40, stone: 30)
        }
    }

    public var trainWatches: Int {
        switch self {
        case .lantern: return 1
        case .spear, .bow: return 2
        case .rider, .founder: return 3
        }
    }

    /// Grain eaten each watch.
    public var upkeep: Int { self == .lantern ? 0 : 1 }

    /// Percent bonus when fighting riders.
    public var bonusAgainstRiders: Int { self == .spear ? 50 : 0 }
}

/// A unit in the field.
public struct Unit: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public var kind: UnitKind
    public var owner: Int
    public var position: Hex
    /// 0...100.
    public var health: Int
    public var movesLeft: Int
    /// Where it is going, if further than one watch's march.
    public var destination: Hex?
    public var fortified: Bool
    /// Whether it moved or fought this watch, which stops it healing.
    public var acted: Bool
    /// Battles survived; see `rank`.
    public var experience: Int

    /// Veterancy: none, then Blooded, Hardened and Sworn as battles are
    /// survived. Each rank adds a tenth to attack and defence.
    public var rank: Int { Unit.rank(forExperience: experience) }

    /// Battles survived to reach each rank.
    public static let rankThresholds = [2, 5, 9]
    public static let rankTitles = ["", "Blooded", "Hardened", "Sworn"]
    /// Percent added to attack and defence for each rank.
    public static let rankBonus = 10

    public static func rank(forExperience experience: Int) -> Int {
        rankThresholds.filter { experience >= $0 }.count
    }

    public init(id: Int, kind: UnitKind, owner: Int, position: Hex) {
        self.id = id
        self.kind = kind
        self.owner = owner
        self.position = position
        self.health = 100
        self.movesLeft = kind.movement
        self.destination = nil
        self.fortified = false
        self.acted = false
        self.experience = 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, owner, position, health, movesLeft, destination, fortified, acted, experience
    }

    /// Games saved before veterancy have no experience recorded; it starts at zero.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        kind = try container.decode(UnitKind.self, forKey: .kind)
        owner = try container.decode(Int.self, forKey: .owner)
        position = try container.decode(Hex.self, forKey: .position)
        health = try container.decode(Int.self, forKey: .health)
        movesLeft = try container.decode(Int.self, forKey: .movesLeft)
        destination = try container.decodeIfPresent(Hex.self, forKey: .destination)
        fortified = try container.decode(Bool.self, forKey: .fortified)
        acted = try container.decode(Bool.self, forKey: .acted)
        experience = try container.decodeIfPresent(Int.self, forKey: .experience) ?? 0
    }
}
