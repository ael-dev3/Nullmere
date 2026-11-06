/// Who a House can send out from its holds.
public enum UnitKind: String, CaseIterable, Codable, Sendable, PlainCases {
    /// A scout carrying light into the dark country.
    case lantern
    case spear
    case bow
    case rider
    /// Engines of timber and rope that hurl stones from two tiles away:
    /// three times as hard as any other company on walls and wards, slow
    /// to learn and soft in the field, and no riders' match.
    case mangonel
    /// Settlers who found a new hold where they stand.
    case founder

    /// Its place among the kinds, for what is kept kind by kind in a list.
    var ordinal: Int {
        switch self {
        case .lantern: return 0
        case .spear: return 1
        case .bow: return 2
        case .rider: return 3
        case .mangonel: return 4
        case .founder: return 5
        }
    }

    /// How many kinds there are.
    static let count = allCases.count

    public var title: String {
        switch self {
        case .lantern: return "Lanterns"
        case .spear: return "Spears"
        case .bow: return "Bows"
        case .rider: return "Riders"
        case .mangonel: return "Mangonels"
        case .founder: return "Founders"
        }
    }

    public var attack: Int {
        switch self {
        case .lantern: return 1
        case .spear: return 6
        case .bow: return 5
        case .rider: return 8
        case .mangonel: return 4
        case .founder: return 0
        }
    }

    public var defense: Int {
        switch self {
        case .lantern: return 2
        case .spear: return 7
        case .bow: return 4
        case .rider: return 5
        case .mangonel: return 3
        case .founder: return 1
        }
    }

    public var movement: Int {
        switch self {
        case .lantern, .rider: return 4
        case .spear, .bow, .mangonel, .founder: return 2
        }
    }

    public var sight: Int {
        switch self {
        case .lantern: return 3
        default: return 2
        }
    }

    /// Bows and Mangonels strike from two tiles away and take no blow in return.
    public var range: Int { self == .bow || self == .mangonel ? 2 : 1 }

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
        case .mangonel: return 4
        }
    }

    public var cost: Stock {
        switch self {
        case .lantern: return Stock(grain: 15, timber: 10)
        case .spear: return Stock(grain: 25, timber: 15, stone: 10)
        case .bow: return Stock(grain: 25, timber: 30)
        case .rider: return Stock(grain: 40, timber: 15, stone: 10, moonsalt: 8)
        case .mangonel: return Stock(grain: 20, timber: 50, stone: 30, moonsalt: 6)
        case .founder: return Stock(grain: 60, timber: 40, stone: 30)
        }
    }

    public var trainWatches: Int {
        switch self {
        case .lantern: return 1
        case .spear, .bow: return 2
        case .rider, .mangonel, .founder: return 3
        }
    }

    /// Grain eaten each watch.
    public var upkeep: Int { self == .lantern ? 0 : 1 }

    /// Percent bonus when fighting riders.
    public var bonusAgainstRiders: Int { self == .spear ? 50 : 0 }

    /// Percent bonus when fighting Mangonels: riders fall on them.
    public var bonusAgainstMangonels: Int { self == .rider ? 50 : 0 }

    /// What its blows take from walls and wards, in percent of what
    /// another company's of its strength would.
    public var wardPercent: Int { self == .mangonel ? 300 : 100 }

    // MARK: Tiers

    /// Whether it musters in tiers, I to V: the companies of war do;
    /// Lanterns and Founders muster in one.
    public var hasTiers: Bool { self == .spear || self == .bow || self == .rider || self == .mangonel }

    /// Its highest tier: V for a company of war, I for the rest.
    public var highestTier: Int { hasTiers ? Unit.highestTier : 1 }

    /// The Muster Hall level a tier of this kind needs: the kind's own, and
    /// for a tier beyond the first, as high as the tier.
    public func requiredMuster(tier: Int) -> Int {
        tier <= 1 ? requiredMuster : max(requiredMuster, tier)
    }

    /// What a company of this kind costs at a tier, before its House's
    /// studies: dearer with each tier, and moonsalt from the third.
    public func cost(tier: Int) -> Stock {
        let index = Unit.tierIndex(tier, of: self)
        var price = cost.scaled(percent: Unit.tierCost[index])
        price.moonsalt += Unit.tierMoonsalt[index]
        return price
    }

    /// Attack at a tier, as a keeper reads it, rounded.
    public func attack(tier: Int) -> Int {
        (attack * Unit.tierMight[Unit.tierIndex(tier, of: self)] + 50) / 100
    }

    /// Defence at a tier, as a keeper reads it, rounded.
    public func defense(tier: Int) -> Int {
        (defense * Unit.tierMight[Unit.tierIndex(tier, of: self)] + 50) / 100
    }

    /// Grain a company of this tier eats each watch.
    public func upkeep(tier: Int) -> Int {
        upkeep == 0 ? 0 : Unit.tierUpkeep[Unit.tierIndex(tier, of: self)]
    }

    /// Watches a company of this tier takes to train, before a Muster Hall
    /// or studies hasten it.
    public func trainWatches(tier: Int) -> Int {
        trainWatches + Unit.tierWatches[Unit.tierIndex(tier, of: self)]
    }
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
    /// Its tier, I to V: a company of war mustered higher is stronger,
    /// hardier, dearer and hungrier. Lanterns and Founders are of the first.
    public var tier: Int
    /// The commander leading it, if one does.
    public var leader: Int?
    /// A second commander riding with its leader, if one does: half its
    /// edges added to the company's, a point more when the two are of one
    /// kind (RoK's secondary commander).
    public var second: Int?
    /// What it has been sent to do beyond a march, if anything.
    public var errand: Errand?
    /// What it carries home from the land's sites, if anything.
    public var load: Stock?
    /// Troops drilled into it at a Muster Hall beyond its first muster.
    public var drilled: Int?
    /// Where it drills, for as long as it stands there: one of its House's
    /// holds with a Muster Hall.
    public var drillAt: Hex?
    /// The watches of work it still gives its site before it turns for
    /// home, when it was sent for so many; nil, until it carries all it can.
    public var gatherFor: Int?
    /// The way it has yet to go to its destination, as last found: the
    /// hexes it steps through, in order. Kept by the realm alone; no
    /// keeper's view carries it.
    public internal(set) var way: [Hex]?

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

    /// The highest tier a company can be mustered at.
    public static let highestTier = 5
    /// A tier's attack and defence, in percent of the first tier's.
    public static let tierMight = [100, 125, 155, 190, 230]
    /// A tier's body, in percent of the first's: health is a hundredth of
    /// a company whatever its tier, and a blow takes that much less of a
    /// hardier one.
    public static let tierBody = [100, 115, 130, 150, 175]
    /// A tier's price, in percent of the first's, and the moonsalt it adds.
    static let tierCost = [100, 165, 250, 360, 500]
    static let tierMoonsalt = [0, 0, 3, 8, 15]
    /// Grain a tier eats each watch, and the watches it adds to training.
    static let tierUpkeep = [1, 1, 2, 2, 3]
    static let tierWatches = [0, 0, 1, 1, 2]

    /// A tier as an index into the tier tables: within the kind's own range.
    static func tierIndex(_ tier: Int, of kind: UnitKind) -> Int {
        min(max(tier, 1), kind.highestTier) - 1
    }

    public init(id: Int, kind: UnitKind, owner: Int, position: Hex, tier: Int = 1) {
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
        self.tier = min(max(tier, 1), kind.highestTier)
        self.leader = nil
        self.errand = nil
        self.second = nil
        self.load = nil
        self.drilled = nil
        self.drillAt = nil
        self.way = nil
    }

    private enum CodingKeys: String, CodingKey {
        /// The company in one line, comma by comma: its id, kind, owner, q
        /// and r, health, moves left, whether fortified and whether it acted
        /// (1 or 0), experience and tier; then, as far as it has any of them,
        /// its destination ("q:r"), leader, second and the troops drilled.
        case line = "u"
        case id, kind, owner, position, health, movesLeft, destination, fortified, acted, experience, tier, leader, second, errand, load, drilled, drillAt, way
    }

    /// Its line (`CodingKeys.line`): a company travels in a few dozen bytes,
    /// a page of them a few, where every field named was five times as many.
    var line: String {
        func field(_ value: Int?) -> String { value.map(String.init) ?? "" }
        var fields = [field(id), kind.rawValue, field(owner), field(position.q), field(position.r), field(health), field(movesLeft),
                      fortified ? "1" : "0", acted ? "1" : "0", field(experience), field(tier)]
        let rest = [destination.map { "\($0.q):\($0.r)" } ?? "", field(leader), field(second), field(drilled)]
        if let last = rest.lastIndex(where: { !$0.isEmpty }) { fields += rest[...last] }
        return fields.joined(separator: ",")
    }

    // A way is written as a march's is: its first hex and a digit for each
    // step after.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(line, forKey: .line)
        try container.encodeIfPresent(errand, forKey: .errand)
        try container.encodeIfPresent(load, forKey: .load)
        try container.encodeIfPresent(drillAt, forKey: .drillAt)
        try container.encodeIfPresent(way.flatMap(March.way(of:)), forKey: .way)
    }

    /// Games saved before veterancy have no experience recorded; it starts at
    /// zero. Those saved before tiers are of the first. Companies written
    /// before they went as lines are read field by field.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let line = try container.decodeIfPresent(String.self, forKey: .line) {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            func unreadable() -> DecodingError {
                DecodingError.dataCorruptedError(forKey: .line, in: container, debugDescription: "Unreadable company: \(line)")
            }
            func number(_ index: Int) throws -> Int? {
                guard index < fields.count, !fields[index].isEmpty else { return nil }
                guard let value = Int(fields[index]) else { throw unreadable() }
                return value
            }
            func flag(_ index: Int) throws -> Bool {
                guard fields[index] == "0" || fields[index] == "1" else { throw unreadable() }
                return fields[index] == "1"
            }
            // As many fields as it writes, and none left empty at its end.
            guard (11...15).contains(fields.count), fields.count == 11 || !fields[fields.count - 1].isEmpty,
                  let kind = UnitKind(rawValue: String(fields[1])),
                  let id = try number(0), let owner = try number(2), let q = try number(3), let r = try number(4),
                  let health = try number(5), let movesLeft = try number(6), let experience = try number(9), let tier = try number(10)
            else { throw unreadable() }
            self.id = id
            self.kind = kind
            self.owner = owner
            position = Hex(q, r)
            self.health = health
            self.movesLeft = movesLeft
            fortified = try flag(7)
            acted = try flag(8)
            self.experience = experience
            self.tier = tier
            if fields.count > 11, !fields[11].isEmpty {
                let ends = fields[11].split(separator: ":", omittingEmptySubsequences: false)
                guard ends.count == 2, let q = Int(ends[0]), let r = Int(ends[1]) else { throw unreadable() }
                destination = Hex(q, r)
            } else {
                destination = nil
            }
            leader = try number(12)
            second = try number(13)
            drilled = try number(14)
        } else {
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
            tier = try container.decodeIfPresent(Int.self, forKey: .tier) ?? 1
            leader = try container.decodeIfPresent(Int.self, forKey: .leader)
            second = try container.decodeIfPresent(Int.self, forKey: .second)
            drilled = try container.decodeIfPresent(Int.self, forKey: .drilled)
        }
        errand = try container.decodeIfPresent(Errand.self, forKey: .errand)
        load = try container.decodeIfPresent(Stock.self, forKey: .load)
        drillAt = try container.decodeIfPresent(Hex.self, forKey: .drillAt)
        if let way = try container.decodeIfPresent(String.self, forKey: .way) {
            guard let route = March.route(fromWay: way) else {
                throw DecodingError.dataCorruptedError(forKey: .way, in: container, debugDescription: "Unreadable way")
            }
            self.way = route
        } else {
            way = nil
        }
    }
}
