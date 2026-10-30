/// Where a commander wears a piece of gear: one of each.
public enum GearSlot: String, CaseIterable, Codable, Sendable {
    case weapon, armour, charm

    public var title: String {
        switch self {
        case .weapon: return "Weapon"
        case .armour: return "Armour"
        case .charm: return "Charm"
        }
    }
}

/// How fine a piece of gear is: what falls with the wilds of higher levels
/// is finer, and each step gives its edges again.
public enum GearQuality: Int, CaseIterable, Codable, Comparable, Sendable {
    case plain = 1, fine, masterwork, fabled

    public var title: String {
        switch self {
        case .plain: return "Plain"
        case .fine: return "Fine"
        case .masterwork: return "Masterwork"
        case .fabled: return "Fabled"
        }
    }

    /// What falls with a company of the wilds of a level: levels I to III
    /// leave plain gear, IV to VI fine, VII to IX masterwork, X fabled.
    public static func of(level: Int) -> GearQuality {
        switch level {
        case ...3: return .plain
        case 4...6: return .fine
        case 7...9: return .masterwork
        default: return .fabled
        }
    }

    public static func < (a: GearQuality, b: GearQuality) -> Bool { a.rawValue < b.rawValue }
}

/// A kind of gear: each kind of the wilds leaves its own.
public enum GearKind: String, CaseIterable, Codable, Sendable {
    /// Left by Saltwights: a blade of salt-hardened bone.
    case saltGlaive
    /// Left by Blackwood Reavers: an axe for doors and walls.
    case reaverAxe
    /// Left by the Barrowkin: plate from the old graves.
    case barrowPlate
    /// Left by the Drowned: mail that never dries.
    case drownedMail
    /// Left by Spine Hunters: a carved eye that finds the way.
    case huntersEye

    public var title: String {
        switch self {
        case .saltGlaive: return "Salt Glaive"
        case .reaverAxe: return "Reaver's Axe"
        case .barrowPlate: return "Barrowplate"
        case .drownedMail: return "Drowned Mail"
        case .huntersEye: return "Hunter's Eye"
        }
    }

    public var slot: GearSlot {
        switch self {
        case .saltGlaive, .reaverAxe: return .weapon
        case .barrowPlate, .drownedMail: return .armour
        case .huntersEye: return .charm
        }
    }

    /// What a plain piece gives the company its wearer leads; each step of
    /// quality gives it again.
    public var edges: [Edge: Int] {
        switch self {
        case .saltGlaive: return [.attack: 3, .hunting: 5]
        case .reaverAxe: return [.attack: 2, .wardDamage: 5]
        case .barrowPlate: return [.defense: 4, .healing: 1]
        case .drownedMail: return [.defense: 3, .garrison: 5]
        case .huntersEye: return [.hunting: 4, .gathering: 4, .load: 4]
        }
    }

    /// The kind each of the wilds leaves.
    public static func left(by wild: WildKind) -> GearKind {
        switch wild {
        case .saltwights: return .saltGlaive
        case .reavers: return .reaverAxe
        case .barrowkin: return .barrowPlate
        case .drowned: return .drownedMail
        case .spineHunters: return .huntersEye
        }
    }
}

/// A piece of gear a House holds: in its armoury, or worn by one of its
/// commanders.
public struct Gear: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let kind: GearKind
    public let quality: GearQuality
    public internal(set) var owner: Int
    /// The commander wearing it; nil while it lies in the armoury.
    public internal(set) var wornBy: Int?

    public init(id: Int, kind: GearKind, quality: GearQuality, owner: Int, wornBy: Int? = nil) {
        self.id = id
        self.kind = kind
        self.quality = quality
        self.owner = owner
        self.wornBy = wornBy
    }

    public var title: String { "\(quality.title) \(kind.title)" }

    public var slot: GearSlot { kind.slot }

    /// What it gives the company its wearer leads.
    public var edges: [Edge: Int] { kind.edges.mapValues { $0 * quality.rawValue } }

    /// What it gives, in a line.
    public var effect: String {
        let order: [Edge] = [.attack, .defense, .hunting, .wardDamage, .garrison, .gathering, .load, .healing]
        return order.compactMap { edge -> String? in
            guard let amount = edges[edge] else { return nil }
            switch edge {
            case .attack: return "+\(amount)% attack"
            case .defense: return "+\(amount)% defence"
            case .hunting: return "+\(amount)% against the wilds"
            case .wardDamage: return "+\(amount)% to blows on a ward"
            case .garrison: return "+\(amount)% defence within its walls"
            case .gathering: return "+\(amount)% gathered"
            case .load: return "+\(amount)% carried"
            case .healing: return "heals \(amount) more"
            default: return nil
            }
        }.joined(separator: ", ")
    }

    /// Moonsalt it is broken up for.
    public var scrap: Int { 5 * quality.rawValue }
}

extension GameState {
    /// The most gear a House's armoury keeps, worn or not; a piece found
    /// beyond it is broken up for its moonsalt.
    public static let armouryLimit = 12

    /// The chance, in a hundred, that a company of the wilds of a level
    /// leaves a piece of gear as it falls.
    public static func gearChance(level: Int) -> Int {
        min(80, 20 + 6 * level)
    }

    /// Every piece of gear the realm's Houses hold.
    public var gear: [Gear] { armoury ?? [] }

    /// A House's gear, worn or not.
    public func gear(of house: Int) -> [Gear] {
        gear.filter { $0.owner == house }
    }

    /// A piece of gear by id.
    public func gear(_ id: Int) -> Gear? {
        armoury?.first { $0.id == id }
    }

    /// What a commander wears.
    public func worn(by commander: Int) -> [Gear] {
        gear.filter { $0.wornBy == commander }
    }

    /// What a commander's skills, talents and gear give the company it leads.
    public func edge(_ edge: Edge, of commander: Commander) -> Int {
        commander.edge(edge) + worn(by: commander.id).reduce(0) { $0 + ($1.edges[edge] ?? 0) }
    }

    /// Whether a company of the wilds struck down leaves gear: drawn from
    /// the wild itself and the watch, apart from the watch's other draws,
    /// so the hunt goes as it would have without it.
    func leavesGear(_ wild: Wild) -> Bool {
        var draw = SeededRandom(seed: Seed.mix(Seed.mix(settings.seed, 700 + UInt64(wild.id)), UInt64(max(watch, 0))))
        return draw.int(in: 1...100) <= GameState.gearChance(level: wild.level)
    }

    /// A House finds a piece of gear on the wilds it struck down: kept in
    /// its armoury, or, the armoury full, broken up for moonsalt at once.
    mutating func findGear(on wild: Wild, by house: Int) -> [GameEvent] {
        guard leavesGear(wild) else { return [] }
        return awardGear(from: wild.kind, level: wild.level, to: house)
    }

    /// A piece of gear a kind of the wilds leaves, as fine as its level,
    /// for a House: into its armoury, or broken up for moonsalt if that
    /// is full.
    mutating func awardGear(from kind: WildKind, level: Int, to house: Int) -> [GameEvent] {
        let piece = Gear(id: takeID(), kind: GearKind.left(by: kind), quality: GearQuality.of(level: level), owner: house)
        if gear(of: house).count >= GameState.armouryLimit {
            store(Stock(moonsalt: piece.scrap), for: house)
            return [.gearFound(house: house, gear: piece, from: kind), .gearScrapped(house: house, gear: piece.id, moonsalt: piece.scrap)]
        }
        armoury = gear + [piece]
        return [.gearFound(house: house, gear: piece, from: kind)]
    }

    private func gearIndex(_ id: Int, of house: Int) throws(RuleError) -> Int {
        guard let index = armoury?.firstIndex(where: { $0.id == id }), armoury![index].owner == house else { throw .unknownGear }
        return index
    }

    /// A commander takes up a piece of gear; what it wore in that slot goes
    /// back to the armoury, and the piece leaves whoever wore it before.
    mutating func wear(_ gearID: Int, on commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try gearIndex(gearID, of: house)
        guard let commander = commander(commanderID), commander.owner == house else { throw .unknownCommander }
        guard armoury![index].wornBy != commanderID else { throw .alreadyWorn }
        let slot = armoury![index].slot
        for other in armoury!.indices where armoury![other].wornBy == commanderID && armoury![other].slot == slot {
            armoury![other].wornBy = nil
        }
        armoury![index].wornBy = commanderID
        return [.gearWorn(commander: commanderID, house: house, gear: gearID)]
    }

    /// A piece of gear taken off, back to the armoury.
    mutating func takeOff(_ gearID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try gearIndex(gearID, of: house)
        guard let wearer = armoury![index].wornBy else { throw .notWorn }
        armoury![index].wornBy = nil
        return [.gearTakenOff(commander: wearer, house: house, gear: gearID)]
    }

    /// A piece of gear broken up for its moonsalt, whoever wore it.
    mutating func breakUp(_ gearID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try gearIndex(gearID, of: house)
        let piece = armoury!.remove(at: index)
        store(Stock(moonsalt: piece.scrap), for: house)
        return [.gearScrapped(house: house, gear: piece.id, moonsalt: piece.scrap)]
    }

    /// A steward arms its commanders: in each slot, the finest piece it
    /// holds that no other commander of its wears.
    mutating func armCommanders(for house: Int) -> [GameEvent] {
        var events: [GameEvent] = []
        for commander in commanders(of: house) {
            for slot in GearSlot.allCases {
                let wearing = worn(by: commander.id).first { $0.slot == slot }
                let best = gear(of: house).filter { $0.slot == slot && $0.wornBy == nil }
                    .max { ($0.quality, -$0.id) < ($1.quality, -$1.id) }
                guard let best, best.quality > (wearing?.quality ?? .plain) || wearing == nil else { continue }
                events += (try? wear(best.id, on: commander.id, as: house)) ?? []
            }
        }
        return events
    }
}
