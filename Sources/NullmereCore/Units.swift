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
        case .lantern: return "Lantern"
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
    }
}
