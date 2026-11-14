import Foundation
import NullmereRealm

/// A hex of the world: east (`q`) and south-east (`r`) of the lake's heart.
public struct LiveHex: Hashable, Sendable {
    public let q: Int
    public let r: Int

    public init(q: Int, r: Int) {
        self.q = q
        self.r = r
    }

    /// A hex from the one number a row keeps it as.
    public init(packed: UInt64) {
        q = Int((packed >> 16) & 0xFFFF) - 32768
        r = Int(packed & 0xFFFF) - 32768
    }

    public var packed: UInt64 { (UInt64(q + 32768) << 16) | UInt64(r + 32768) }

    public func distance(to other: LiveHex) -> Int {
        let (dq, dr) = (q - other.q, r - other.r)
        return (abs(dq) + abs(dr) + abs(dq + dr)) / 2
    }

    /// Where its heart lies on the flat map: x east, y south, a hex's
    /// width across its flats the square root of three.
    public var centre: (x: Double, y: Double) { (3.0.squareRoot() * (Double(q) + Double(r) / 2), 1.5 * Double(r)) }
}

/// The four goods a city keeps.
public struct LiveGoods: Equatable, Sendable {
    public var grain: UInt64
    public var timber: UInt64
    public var stone: UInt64
    public var moonsalt: UInt64

    public init(grain: UInt64 = 0, timber: UInt64 = 0, stone: UInt64 = 0, moonsalt: UInt64 = 0) {
        self.grain = grain
        self.timber = timber
        self.stone = stone
        self.moonsalt = moonsalt
    }

    public var parts: [UInt64] { [grain, timber, stone, moonsalt] }

    /// Whether there is nothing of any of them.
    public var isNone: Bool { parts.allSatisfy { $0 == 0 } }

    /// Whether these goods pay a cost.
    public func covers(_ cost: LiveGoods) -> Bool {
        zip(parts, cost.parts).allSatisfy { $0 >= $1 }
    }
}

/// A row's values, read by their place among its columns.
struct Cells {
    let row: [JSONValue]

    func number(_ index: Int) -> Double? {
        guard row.indices.contains(index), case .number(let value) = row[index] else { return nil }
        return value
    }

    func unsigned(_ index: Int) -> UInt64? {
        number(index).flatMap { $0 >= 0 && $0 < 1.8e19 ? UInt64($0) : nil }
    }

    func whole(_ index: Int) -> Int? {
        number(index).flatMap { abs($0) < 9e18 ? Int($0) : nil }
    }

    func text(_ index: Int) -> String? {
        guard row.indices.contains(index), case .string(let value) = row[index] else { return nil }
        return value
    }

    /// True or false, which a pushed row may carry as 1 or 0.
    func flag(_ index: Int) -> Bool? {
        guard row.indices.contains(index) else { return nil }
        switch row[index] {
        case .bool(let value): return value
        case .number(let value) where value == 0 || value == 1: return value == 1
        default: return nil
        }
    }

    /// Bytes, which the server sends as hexadecimal text, or as a list of
    /// numbers.
    func bytes(_ index: Int) -> [UInt8]? {
        guard row.indices.contains(index) else { return nil }
        switch row[index] {
        case .string(let hex):
            guard hex.count % 2 == 0 else { return nil }
            var bytes: [UInt8] = []
            bytes.reserveCapacity(hex.count / 2)
            var at = hex.startIndex
            while at < hex.endIndex {
                let next = hex.index(at, offsetBy: 2)
                guard let byte = UInt8(hex[at..<next], radix: 16) else { return nil }
                bytes.append(byte)
                at = next
            }
            return bytes
        case .array(let values):
            return values.map { value -> UInt8 in
                if case .number(let number) = value, number >= 0, number < 256 { return UInt8(number) }
                return 0
            }
        default:
            return nil
        }
    }
}

/// The realm itself.
public struct LiveRealm: Equatable, Sendable {
    public let opened: Int
    public let pace: Int
    public let radius: Int

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let opened = cells.whole(2), let pace = cells.whole(3), let radius = cells.whole(6) else { return nil }
        (self.opened, self.pace, self.radius) = (opened, pace, radius)
    }
}

public struct LivePlayer: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let name: String
    public let joined: Int
    public let online: Bool
    public let seen: Int

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let name = cells.text(2), let joined = cells.whole(3), let online = cells.flag(4),
              let seen = cells.whole(5) else { return nil }
        (self.id, self.name, self.joined, self.online, self.seen) = (id, name, joined, online, seen)
    }
}

public struct LiveCity: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let owner: UInt64
    public let hex: LiveHex
    public let name: String
    public let keep: Int
    public let power: UInt64
    public let founded: Int
    public let builders: Int
    /// Until when it is at peace: no army may attack it before then.
    public let shield: Int

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let owner = cells.unsigned(1), let hex = cells.unsigned(2), let name = cells.text(3),
              let keep = cells.whole(4), let power = cells.unsigned(5), let founded = cells.whole(6), let builders = cells.whole(7)
        else { return nil }
        (self.id, self.owner, self.hex, self.name) = (id, owner, LiveHex(packed: hex), name)
        (self.keep, self.power, self.founded, self.builders) = (keep, power, founded, builders)
        shield = cells.whole(8) ?? 0
    }

    /// The seconds of peace it has left at a moment; none once it may be attacked.
    public func peace(at seconds: Double) -> Int { max(shield - Int(seconds), 0) }
}

/// What stands on a hex.
public struct LivePlace: Equatable, Sendable {
    public static let city = 1
    public static let site = 2
    public static let barrow = 3

    public let hex: LiveHex
    public let kind: Int
    public let id: UInt64

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let hex = cells.unsigned(0), let kind = cells.whole(1), let id = cells.unsigned(2) else { return nil }
        (self.hex, self.kind, self.id) = (LiveHex(packed: hex), kind, id)
    }
}

/// Goods lying on the land to be gathered.
public struct LiveSite: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let hex: LiveHex
    /// 1 grain, 2 timber, 3 stone, 4 moonsalt.
    public let kind: Int
    public let level: Int
    public let left: UInt64
    /// The march gathering there now; 0 for none.
    public let gatherer: UInt64

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let hex = cells.unsigned(1), let kind = cells.whole(2), let level = cells.whole(3),
              let left = cells.unsigned(4), let gatherer = cells.unsigned(5) else { return nil }
        (self.id, self.hex, self.kind, self.level, self.left, self.gatherer) = (id, LiveHex(packed: hex), kind, level, left, gatherer)
    }
}

/// An army out of its city.
public struct LiveMarch: Equatable, Sendable, Identifiable {
    /// What a march set out to do: to gather at a site, or to clear a
    /// barrow of the Unquiet.
    public static let gather = 1
    public static let hunt = 2
    /// To take another player's city by storm.
    public static let attack = 3

    public static let going = 1
    public static let working = 2
    public static let returning = 3
    /// Fighting where it stands, at `to`, until `arrives`.
    public static let fighting = 4

    public let id: UInt64
    public let owner: UInt64
    public let city: UInt64
    public let kind: Int
    public let state: Int
    public let from: LiveHex
    public let to: LiveHex
    public let target: UInt64
    public let departed: Int
    public let arrives: Int
    public let soldiers: UInt64
    /// The way it is on now, hex by hex.
    public let route: [LiveHex]

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let owner = cells.unsigned(1), let city = cells.unsigned(2), let kind = cells.whole(3),
              let state = cells.whole(4), let from = cells.unsigned(5), let to = cells.unsigned(6), let target = cells.unsigned(7),
              let departed = cells.whole(8), let arrives = cells.whole(9), let soldiers = cells.unsigned(10), let route = cells.bytes(11)
        else { return nil }
        (self.id, self.owner, self.city, self.kind, self.state) = (id, owner, city, kind, state)
        (self.from, self.to, self.target) = (LiveHex(packed: from), LiveHex(packed: to), target)
        (self.departed, self.arrives, self.soldiers) = (departed, arrives, soldiers)
        self.route = stride(from: 0, to: route.count - 3, by: 4).map { at in
            let q = Int16(bitPattern: UInt16(route[at]) | UInt16(route[at + 1]) << 8)
            let r = Int16(bitPattern: UInt16(route[at + 2]) | UInt16(route[at + 3]) << 8)
            return LiveHex(q: Int(q), r: Int(r))
        }
    }

    /// How far through what it is doing it is at a moment, 0 to 1.
    public func progress(at seconds: Double) -> Double {
        let whole = Double(max(arrives - departed, 1))
        return min(max((seconds - Double(departed)) / whole, 0), 1)
    }

    /// Whether it stands where it came to, at work or in a fight.
    public var stands: Bool { state == LiveMarch.working || state == LiveMarch.fighting }

    /// Where it is on the flat map at a moment: along its way at an even
    /// pace while it marches; at its site while it works there, or at its
    /// barrow while it fights.
    public func position(at seconds: Double) -> (x: Double, y: Double) {
        guard !stands, route.count > 1 else { return (stands ? to : route.first ?? from).centre }
        let along = progress(at: seconds) * Double(route.count - 1)
        let step = min(Int(along), route.count - 2)
        let (a, b, t) = (route[step].centre, route[step + 1].centre, along - Double(step))
        return (a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }
}

/// What a building costs and gives at a level, in this realm.
public struct LiveBlueprint: Equatable, Sendable {
    public let building: Int
    public let level: Int
    public let name: String
    public let cost: LiveGoods
    public let seconds: Int
    public let hourly: LiveGoods
    public let opensAt: Int
    public let needsBuilding: Int
    public let needsLevel: Int
    public let power: UInt64

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let building = cells.whole(1), let level = cells.whole(2), let name = cells.text(3), let seconds = cells.whole(8),
              let opensAt = cells.whole(13), let needsBuilding = cells.whole(14), let needsLevel = cells.whole(15),
              let power = cells.unsigned(16) else { return nil }
        let amounts = (4...12).map { cells.unsigned($0) ?? 0 }
        (self.building, self.level, self.name, self.seconds) = (building, level, name, seconds)
        cost = LiveGoods(grain: amounts[0], timber: amounts[1], stone: amounts[2], moonsalt: amounts[3])
        hourly = LiveGoods(grain: amounts[5], timber: amounts[6], stone: amounts[7], moonsalt: amounts[8])
        (self.opensAt, self.needsBuilding, self.needsLevel, self.power) = (opensAt, needsBuilding, needsLevel, power)
    }
}

/// What one soldier of a kind and tier is and costs, in this realm.
public struct LiveSoldier: Equatable, Sendable {
    public let kind: Int
    public let tier: Int
    public let name: String
    public let attack: UInt64
    public let defence: UInt64
    public let health: UInt64
    /// Tenths of a second to cross a hex.
    public let pace: Int
    public let load: UInt64
    public let power: UInt64
    public let cost: LiveGoods
    /// Thousandths of a second to train one.
    public let millis: Int
    public let building: Int
    public let needsLevel: Int

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let kind = cells.whole(1), let tier = cells.whole(2), let name = cells.text(3), let attack = cells.unsigned(4),
              let defence = cells.unsigned(5), let health = cells.unsigned(6), let pace = cells.whole(7), let load = cells.unsigned(8),
              let power = cells.unsigned(9), let millis = cells.whole(14), let building = cells.whole(15), let needsLevel = cells.whole(16)
        else { return nil }
        (self.kind, self.tier, self.name, self.attack, self.defence, self.health) = (kind, tier, name, attack, defence, health)
        (self.pace, self.load, self.power, self.millis, self.building, self.needsLevel) = (pace, load, power, millis, building, needsLevel)
        cost = LiveGoods(grain: cells.unsigned(10) ?? 0, timber: cells.unsigned(11) ?? 0, stone: cells.unsigned(12) ?? 0,
                         moonsalt: cells.unsigned(13) ?? 0)
    }
}

/// A building in the player's city: level 0 while it is first raised.
public struct LiveBuilding: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let city: UInt64
    public let kind: Int
    public let level: Int

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let city = cells.unsigned(1), let kind = cells.whole(2), let level = cells.whole(3) else { return nil }
        (self.id, self.city, self.kind, self.level) = (id, city, kind, level)
    }
}

/// Something the player's city has under way.
public struct LiveJob: Equatable, Sendable, Identifiable {
    public static let raise = 1
    public static let train = 2
    /// Wounded being healed: its level their tier, its amount how many.
    public static let heal = 3

    public let id: UInt64
    public let city: UInt64
    public let kind: Int
    /// The building raised, or the building that trains.
    public let subject: UInt64
    /// The level it is raised to, or the tier trained.
    public let level: Int
    /// How many soldiers are in training.
    public let amount: UInt64
    public let started: Int
    public let ends: Int

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let city = cells.unsigned(1), let kind = cells.whole(2), let subject = cells.unsigned(3),
              let level = cells.whole(4), let amount = cells.unsigned(5), let started = cells.whole(6), let ends = cells.whole(7)
        else { return nil }
        (self.id, self.city, self.kind, self.subject, self.level, self.amount, self.started, self.ends) = (id, city, kind, subject, level, amount, started, ends)
    }

    /// How far through it is at a moment, 0 to 1.
    public func progress(at seconds: Double) -> Double {
        min(max((seconds - Double(started)) / Double(max(ends - started, 1)), 0), 1)
    }

    /// The seconds it has left at a moment.
    public func left(at seconds: Double) -> Double { max(Double(ends) - seconds, 0) }
}

/// The player's city's goods, as they stood when the realm last touched
/// them, with what brings them up to any moment since.
public struct LiveStock: Equatable, Sendable {
    public let city: UInt64
    public let goods: LiveGoods
    public let asOf: Int
    public let hourly: LiveGoods
    /// What each good had earned toward its next unit, in 3,600ths.
    let parts: [UInt64]
    public let holds: UInt64

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let city = cells.unsigned(0), let asOf = cells.whole(5), let holds = cells.unsigned(14) else { return nil }
        let amounts = (1...13).map { cells.unsigned($0) ?? 0 }
        (self.city, self.asOf, self.holds) = (city, asOf, holds)
        goods = LiveGoods(grain: amounts[0], timber: amounts[1], stone: amounts[2], moonsalt: amounts[3])
        hourly = LiveGoods(grain: amounts[5], timber: amounts[6], stone: amounts[7], moonsalt: amounts[8])
        parts = Array(amounts[9...12])
    }

    /// The goods at a moment: each grown by its hourly rate since the
    /// stock was last settled, never past what the city holds, as the
    /// realm itself reckons them (`rules::grown` in the module).
    public func goods(at seconds: Double) -> LiveGoods {
        let elapsed = UInt64(max(seconds - Double(asOf), 0))
        let grown = zip(zip(goods.parts, hourly.parts), parts).map { pair, part -> UInt64 in
            let (amount, rate) = pair
            guard amount < holds else { return amount }
            return min(amount + (rate * elapsed + part) / 3_600, holds)
        }
        return LiveGoods(grain: grown[0], timber: grown[1], stone: grown[2], moonsalt: grown[3])
    }
}

/// The player's troops of one kind and tier in their city.
public struct LiveTroop: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let kind: Int
    public let tier: Int
    public let ready: UInt64
    public let wounded: UInt64

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let kind = cells.whole(2), let tier = cells.whole(3), let ready = cells.unsigned(4),
              let wounded = cells.unsigned(5) else { return nil }
        (self.id, self.kind, self.tier, self.ready, self.wounded) = (id, kind, tier, ready, wounded)
    }
}

/// The soldiers of one kind and tier in one of the player's marches.
public struct LiveSquad: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let march: UInt64
    public let kind: Int
    public let tier: Int
    /// How many march fit to fight, and how many it carries wounded.
    public let count: UInt64
    public let wounded: UInt64

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let march = cells.unsigned(1), let kind = cells.whole(2), let tier = cells.whole(3),
              let count = cells.unsigned(4), let wounded = cells.unsigned(5) else { return nil }
        (self.id, self.march, self.kind, self.tier, self.count, self.wounded) = (id, march, kind, tier, count, wounded)
    }
}

/// A barrow of the Unquiet on the land, for players to clear.
public struct LiveBarrow: Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let hex: LiveHex
    /// How strong it is, 1 to 25.
    public let level: Int
    /// The march fighting there now; 0 for none.
    public let fighter: UInt64

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let hex = cells.unsigned(1), let level = cells.whole(2), let fighter = cells.unsigned(3)
        else { return nil }
        (self.id, self.hex, self.level, self.fighter) = (id, LiveHex(packed: hex), level, fighter)
    }
}

/// What the player has for hunting the Unquiet: their energy as it stood
/// when the realm last touched it, with what brings it up to any moment
/// since, and the strongest barrow they have cleared.
public struct LiveHunt: Equatable, Sendable {
    public let energy: Int
    public let asOf: Int
    public let most: Int
    /// The thousandths of a second that bring one point back.
    public let pointMillis: Int
    public let cleared: Int

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let energy = cells.whole(1), let asOf = cells.whole(2), let most = cells.whole(3), let pointMillis = cells.whole(4),
              let cleared = cells.whole(5) else { return nil }
        (self.energy, self.asOf, self.most, self.pointMillis, self.cleared) = (energy, asOf, most, pointMillis, cleared)
    }

    /// The energy at a moment: grown by a point every so often since it
    /// was last settled, never past the most a player keeps, as the realm
    /// itself reckons it (`rules::hunt_of` in the module).
    public func energy(at seconds: Double) -> Int {
        guard energy < most, pointMillis > 0 else { return energy }
        let gone = Int(max(seconds - Double(asOf), 0)) * 1_000
        return min(energy + gone / pointMillis, most)
    }

    /// The strongest barrow the player may attack.
    public var mayAttack: Int { cleared + 1 }
}

/// What happened to one of the player's armies, as the realm told it.
public struct LiveReport: Equatable, Sendable, Identifiable {
    /// A fight at a barrow: `foe` is the barrow's level.
    public static let hunt = 1
    /// The player's army at another's city, and another's army at the
    /// player's own: `foe` is the other player's number.
    public static let attack = 2
    public static let defence = 3

    public let id: UInt64
    public let at: Int
    public let kind: Int
    public let hex: LiveHex
    public let won: Bool
    /// The other side: a barrow's level, or a player's number.
    public let foe: UInt64
    public let rounds: Int
    /// The player's soldiers: how many fought, and of them how many came
    /// away wounded and how many died.
    public let fought: UInt64
    public let wounded: UInt64
    public let dead: UInt64
    /// The other side's: how many stood, and how many fell.
    public let stood: UInt64
    public let fell: UInt64
    public let spoils: LiveGoods
    /// The whole of it in the realm's own words.
    public let words: String
    public let read: Bool

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let id = cells.unsigned(0), let at = cells.whole(2), let kind = cells.whole(3), let hex = cells.unsigned(4),
              let won = cells.flag(5), let foe = cells.unsigned(6), let rounds = cells.whole(7), let words = cells.text(17),
              let read = cells.flag(18) else { return nil }
        let counts = (8...16).map { cells.unsigned($0) ?? 0 }
        (self.id, self.at, self.kind, self.hex, self.won, self.foe, self.rounds) = (id, at, kind, LiveHex(packed: hex), won, foe, rounds)
        (fought, wounded, dead, stood, fell) = (counts[0], counts[1], counts[2], counts[3], counts[4])
        spoils = LiveGoods(grain: counts[5], timber: counts[6], stone: counts[7], moonsalt: counts[8])
        (self.words, self.read) = (words, read)
    }
}

/// What one of the player's marches carries home.
public struct LiveHaul: Equatable, Sendable {
    public let march: UInt64
    public let goods: LiveGoods

    init?(_ row: [JSONValue]) {
        let cells = Cells(row: row)
        guard let march = cells.unsigned(0) else { return nil }
        self.march = march
        goods = LiveGoods(grain: cells.unsigned(2) ?? 0, timber: cells.unsigned(3) ?? 0, stone: cells.unsigned(4) ?? 0,
                          moonsalt: cells.unsigned(5) ?? 0)
    }
}
