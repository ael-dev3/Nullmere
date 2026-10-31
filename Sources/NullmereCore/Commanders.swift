/// What a commander is: the kind of company it leads best.
public enum Archetype: String, CaseIterable, Codable, Sendable {
    /// Holds the line, and the walls.
    case warden
    /// Strikes first and hardest.
    case vanguard
    /// Sees far and rides fast, and hunts the wilds.
    case outrider
    /// Works the land's sites and brings the stores home.
    case gleaner
    /// Breaks wards.
    case wallbreaker

    public var title: String {
        switch self {
        case .warden: return "Warden"
        case .vanguard: return "Vanguard"
        case .outrider: return "Outrider"
        case .gleaner: return "Gleaner"
        case .wallbreaker: return "Wallbreaker"
        }
    }

    /// As a sentence names one: "a warden", "an outrider".
    public var named: String {
        let word = title.lowercased()
        return (self == .outrider ? "an " : "a ") + word
    }

    /// Each archetype's skills, found once.
    private static let skillTable: [Archetype: [Skill]] = Dictionary(grouping: Skill.allCases, by: \.archetype)

    /// Its four skills, in the order they come with its levels.
    public var skills: [Skill] { Archetype.skillTable[self] ?? [] }

    /// Its skill that fires in battle.
    public var active: Skill { skills[1] }
}

/// A gain a commander's skill gives the company it leads, whatever its
/// kind; in percent but for moves, sight and healing.
public enum Edge: Hashable, Sendable {
    case attack, defense, moves, sight, healing, garrison, wardDamage, gathering, load
    /// Attack against the wilds of the far country.
    case hunting
}

/// A commander's skill. Three are always with it from their level on; one,
/// its active skill, fires in battle once its fury has risen through enough
/// battles, then rises again.
public enum Skill: String, CaseIterable, Codable, Sendable {
    // Warden
    case shieldwall, holdFast, stonePatience, lastGate
    // Vanguard
    case spearhead, fellCharge, bloodPace, ironWill
    // Outrider
    case farEyes, harry, lightFoot, wildsbane
    // Gleaner
    case keenHands, closeRanks, deepPacks, quietRoads
    // Wallbreaker
    case ramsWeight, breach, siegeLines, undermine

    public var archetype: Archetype {
        switch self {
        case .shieldwall, .holdFast, .stonePatience, .lastGate: return .warden
        case .spearhead, .fellCharge, .bloodPace, .ironWill: return .vanguard
        case .farEyes, .harry, .lightFoot, .wildsbane: return .outrider
        case .keenHands, .closeRanks, .deepPacks, .quietRoads: return .gleaner
        case .ramsWeight, .breach, .siegeLines, .undermine: return .wallbreaker
        }
    }

    /// Its place among its archetype's four: the order they are written in.
    var place: Int { Skill.places[self] ?? 0 }

    private static let places: [Skill: Int] = Dictionary(uniqueKeysWithValues: allCases.enumerated().map { ($1, $0 % 4) })

    /// The commander's level it comes with.
    public var unlock: Int { [1, 5, 10, 20][place] }

    /// The second skill of each is the one that fires in battle.
    public var isActive: Bool { place == 1 }

    public var title: String {
        switch self {
        case .shieldwall: return "Shieldwall"
        case .holdFast: return "Hold Fast"
        case .stonePatience: return "Stone Patience"
        case .lastGate: return "Last Gate"
        case .spearhead: return "Spearhead"
        case .fellCharge: return "Fell Charge"
        case .bloodPace: return "Blood Pace"
        case .ironWill: return "Iron Will"
        case .farEyes: return "Far Eyes"
        case .harry: return "Harry"
        case .lightFoot: return "Light Foot"
        case .wildsbane: return "Wildsbane"
        case .keenHands: return "Keen Hands"
        case .closeRanks: return "Close Ranks"
        case .deepPacks: return "Deep Packs"
        case .quietRoads: return "Quiet Roads"
        case .ramsWeight: return "Ram's Weight"
        case .breach: return "Breach"
        case .siegeLines: return "Siege Lines"
        case .undermine: return "Undermine"
        }
    }

    /// Every skill's edges, found once.
    private static let edgeTable: [Skill: [Edge: Int]] = Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.makeEdges()) })

    /// What a skill always gives the company led.
    public var edges: [Edge: Int] { Skill.edgeTable[self] ?? [:] }

    private func makeEdges() -> [Edge: Int] {
        switch self {
        case .shieldwall: return [.defense: 10]
        case .stonePatience: return [.healing: 5]
        case .lastGate: return [.garrison: 15]
        case .spearhead: return [.attack: 10]
        case .bloodPace: return [.moves: 1]
        case .ironWill: return [.attack: 8, .defense: 8]
        case .farEyes: return [.sight: 1]
        case .lightFoot: return [.moves: 1]
        case .wildsbane: return [.hunting: 20]
        case .keenHands: return [.gathering: 15]
        case .deepPacks: return [.load: 20]
        case .quietRoads: return [.defense: 15]
        case .ramsWeight: return [.wardDamage: 15]
        case .siegeLines: return [.attack: 10]
        case .undermine: return [.wardDamage: 15]
        case .holdFast, .fellCharge, .harry, .closeRanks, .breach: return [:]
        }
    }

    /// Battles its fury takes to rise before an active skill fires.
    public var cadence: Int {
        switch self {
        case .harry, .closeRanks: return 2
        default: return 3
        }
    }

    /// What an active skill does to the battle it fires in, in percent:
    /// to the blows its company deals, and to those it takes.
    public var fury: (dealt: Int, taken: Int) {
        switch self {
        case .holdFast: return (100, 50)
        case .fellCharge: return (150, 100)
        case .harry: return (140, 100)
        case .closeRanks: return (100, 60)
        case .breach: return (160, 100)
        default: return (100, 100)
        }
    }

    /// What it does, in a line.
    public var effect: String {
        switch self {
        case .shieldwall: return "+10% defence"
        case .holdFast: return "In every third battle, its company takes half the blow"
        case .stonePatience: return "Heals 5 more each watch at rest"
        case .lastGate: return "+15% defence within its House's own walls"
        case .spearhead: return "+10% attack"
        case .fellCharge: return "In every third battle, its company's blow falls half again as hard"
        case .bloodPace: return "A move further each watch"
        case .ironWill: return "+8% attack and defence"
        case .farEyes: return "Sees a tile further"
        case .harry: return "In every second battle, its company's blow falls four tenths harder"
        case .lightFoot: return "A move further each watch"
        case .wildsbane: return "+20% attack against the wilds"
        case .keenHands: return "+15% gathered each watch"
        case .closeRanks: return "In every second battle, its company takes four tenths less of the blow"
        case .deepPacks: return "+20% carried home"
        case .quietRoads: return "+15% defence"
        case .ramsWeight: return "+15% to blows on a ward"
        case .breach: return "In every third battle, its company's blow falls three fifths harder"
        case .siegeLines: return "+10% attack"
        case .undermine: return "+15% to blows on a ward"
        }
    }
}

/// One of a House's commanders: named, of an archetype, rising in level
/// with experience, leading one company at a time.
public struct Commander: Codable, Equatable, Identifiable, Sendable {
    /// Its place among the realm's commanders, from one.
    public let id: Int
    public let name: String
    public let archetype: Archetype
    public internal(set) var owner: Int
    public internal(set) var experience: Int
    /// The watch it is whole again, if it was carried from a fallen company.
    public internal(set) var woundedUntil: Int?
    /// Battles fought since its active skill last fired.
    public internal(set) var fury: Int
    /// The talents it has learned, a rank an entry, in the order learned;
    /// absent in saves from before talents.
    public internal(set) var talents: [Talent]?

    public init(id: Int, name: String, archetype: Archetype, owner: Int) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.owner = owner
        self.experience = 0
        self.woundedUntil = nil
        self.fury = 0
    }

    public static let highestLevel = 30

    /// Experience to reach a level: half again as much from each to the next.
    public static func experience(forLevel level: Int) -> Int {
        25 * (level - 1) * level
    }

    public static func level(forExperience experience: Int) -> Int {
        // The highest level its experience reaches, counted up: each level
        // asks more than the one before.
        var level = 1
        while level < highestLevel, Commander.experience(forLevel: level + 1) <= experience { level += 1 }
        return level
    }

    public var level: Int { Commander.level(forExperience: experience) }

    /// Its skills come to it as it rises.
    public var skills: [Skill] { archetype.skills.filter { $0.unlock <= level } }

    /// Whether it is wounded at a watch.
    public func isWounded(at watch: Int) -> Bool {
        (woundedUntil ?? 0) > watch
    }

    /// What its skills and its talents always give the company it leads.
    public func edge(_ edge: Edge) -> Int {
        let level = self.level
        var total = talentEdge(edge)
        for skill in archetype.skills where skill.unlock <= level {
            total += skill.edges[edge] ?? 0
        }
        return total
    }
}

extension GameState {
    /// Every commander of the realm, its fallen Houses' too.
    public var roster: [Commander] { commanders ?? [] }

    /// A commander by id.
    public func commander(_ id: Int) -> Commander? {
        commanderIndex(id).map { commanders![$0] }
    }

    /// Where a commander is kept: at its id's place in the realm, or, in a
    /// keeper's view, which knows only some, wherever it is.
    func commanderIndex(_ id: Int) -> Int? {
        guard let commanders else { return nil }
        if id >= 1, id <= commanders.count, commanders[id - 1].id == id { return id - 1 }
        return commanders.firstIndex { $0.id == id }
    }

    /// A House's commanders.
    public func commanders(of house: Int) -> [Commander] {
        roster.filter { $0.owner == house }
    }

    /// The company a commander leads, if any.
    public func company(ledBy commander: Int) -> Unit? {
        units.first { $0.leader == commander }
    }

    /// The most commanders a House keeps.
    public static let rosterLimit = 5
    /// The levels of a seat's Muster Hall at which a captain rises from
    /// the ranks; Banner Lore brings another at each of its grades.
    public static let captainsAt = [3, 5]
    /// Watches a commander carried from a fallen company takes to mend.
    public static let woundWatches = 4

    /// A company's figure for something its House's studies and its
    /// commander change: what `bonus(_:for:)` gives its House, what its
    /// heritage gives its own company, and what its commander's skills,
    /// talents and gear give it.
    public func bonus(_ bonus: Bonus, for unit: Unit) -> Int {
        self.bonus(bonus, for: unit, house: self.bonus(bonus, for: unit.owner))
    }

    /// A company's bonus with its House's own already weighed: its
    /// signature's edge and its commander's added.
    func bonus(_ bonus: Bonus, for unit: Unit, house: Int) -> Int {
        var house = house
        switch bonus {
        case .attack(unit.kind), .defense(unit.kind):
            if isSignature(unit) { house += Heritage.signatureEdge }
        default:
            break
        }
        guard let id = unit.leader, let commander = commander(id) else { return house }
        switch bonus {
        case .attack(let kind) where kind == unit.kind: return house + edge(.attack, of: commander)
        case .defense(let kind) where kind == unit.kind: return house + edge(.defense, of: commander)
        case .moves(let kind) where kind == unit.kind: return house + edge(.moves, of: commander)
        case .sight: return house + edge(.sight, of: commander)
        case .healing: return house + edge(.healing, of: commander)
        case .garrison: return house + edge(.garrison, of: commander)
        case .wardDamage: return house + edge(.wardDamage, of: commander)
        case .gathering: return house + edge(.gathering, of: commander)
        case .load: return house + edge(.load, of: commander)
        default: return house
        }
    }

    /// The active skill a company's commander fires in its next battle, if
    /// its fury is ready.
    public func furyReady(of unit: Unit) -> Skill? {
        guard let id = unit.leader, let commander = commander(id) else { return nil }
        let active = commander.archetype.active
        guard commander.level >= active.unlock, commander.fury + 1 >= commander.cadence else { return nil }
        return active
    }

    /// What a company's commander's fury does to its next battle, in percent:
    /// to the blows it deals, and to those it takes.
    func fury(of unit: Unit) -> (dealt: Int, taken: Int) {
        furyReady(of: unit)?.fury ?? (100, 100)
    }

    // MARK: Gaining commanders

    /// Commanders' given names and the names the lake knows them by.
    static let commanderNames = [
        "Ivo", "Maera", "Tolan", "Sehra", "Corwen", "Ilse", "Brannoc", "Odile", "Veyl", "Ansel", "Kestra", "Hollis",
        "Renn", "Mabyn", "Orrin", "Sabeth", "Edric", "Wenna", "Caddoc", "Lisbet", "Tamsin", "Garrow", "Isel", "Faolan",
    ]
    static let commanderEpithets = [
        "Saltborn", "the Grey", "of the Reeds", "Ashhand", "Stillwater", "the Patient", "Ninefold", "Lanternbearer",
        "of Blackwood", "the Quiet", "Barrowkin", "Moonward", "the Unbent", "Greycloak", "of the Shallows", "Tallow",
    ]

    /// A commander raised for a House, named as no other commander on the
    /// lake is, of an archetype the draw gives unless one is asked.
    @discardableResult
    mutating func raiseCommander(for house: Int, archetype: Archetype? = nil, using random: inout SeededRandom) -> Commander? {
        guard houses.indices.contains(house), !houses[house].isEliminated,
              commanders(of: house).count < GameState.rosterLimit else { return nil }
        let used = Set(roster.map(\.name))
        var name = random.pick(GameState.commanderNames) + " " + random.pick(GameState.commanderEpithets)
        for _ in 0..<32 where used.contains(name) {
            name = random.pick(GameState.commanderNames) + " " + random.pick(GameState.commanderEpithets)
        }
        if used.contains(name) { name += " \(roster.count + 1)" }
        let kind = archetype ?? random.pick(Archetype.allCases)
        let commander = Commander(id: (roster.map(\.id).max() ?? 0) + 1, name: name, archetype: kind, owner: house)
        commanders = roster + [commander]
        return commander
    }

    /// A commander comes to a House: by the draw of the watch.
    mutating func commanderJoins(_ house: Int, archetype: Archetype? = nil, why: String) -> [GameEvent] {
        var random = random()
        guard let joined = raiseCommander(for: house, archetype: archetype, using: &random) else { return [] }
        record(.commander, [house], "\(joined.name), \(joined.archetype.named), \(why) \(houses[house].title).")
        return [.commanderJoined(commander: joined.id, house: house)]
    }

    /// Every House's first commander, as an age begins, or as a world from
    /// before commanders is taken up.
    mutating func raiseFirstCommanders() {
        var random = SeededRandom(seed: Seed.mix(settings.seed, 300))
        if commanders == nil { commanders = [] }
        for house in houses.indices where !houses[house].isEliminated && commanders(of: house).isEmpty {
            raiseCommander(for: house, using: &random)
        }
    }

    // MARK: Leading

    /// Why a House can't give a company a commander, if it can't.
    public func assignRefusal(of commanderID: Int, to unitID: Int, as house: Int) -> RuleError? {
        guard let commander = commander(commanderID), commander.owner == house else { return .unknownCommander }
        if commander.isWounded(at: watch) { return .commanderWounded((commander.woundedUntil ?? watch) - watch) }
        if company(ledBy: commanderID) != nil { return .commanderLeads }
        guard let unit = unit(unitID) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard unit.kind.isMilitary else { return .cannotLead(unit.kind) }
        guard unit.leader == nil else { return .alreadyLed }
        guard holds(of: house).contains(where: { $0.position.distance(to: unit.position) <= 1 }) else { return .awayFromHolds }
        return nil
    }

    mutating func assign(_ commanderID: Int, to unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = assignRefusal(of: commanderID, to: unitID, as: house) { throw refusal }
        units[unitIndex(unitID)!].leader = commanderID
        return [.commanderAssigned(commander: commanderID, unit: unitID)]
    }

    mutating func unassign(_ commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let commander = commander(commanderID), commander.owner == house else { throw .unknownCommander }
        guard let index = units.firstIndex(where: { $0.leader == commanderID }) else { throw .notLeading }
        units[index].leader = nil
        return [.commanderReleased(commander: commanderID)]
    }

    /// A company has fallen: its commander is carried back to the seat,
    /// wounded.
    mutating func woundCommander(of unit: Unit) -> [GameEvent] {
        guard let id = unit.leader, let index = commanderIndex(id) else { return [] }
        commanders![index].woundedUntil = watch + GameState.woundWatches
        commanders![index].fury = 0
        return [.commanderWounded(commander: id, house: unit.owner)]
    }

    /// Experience for a company's commander, with what its House's studies
    /// add; and its rise, if it rises.
    mutating func teach(_ unit: Unit, _ amount: Int) -> [GameEvent] {
        guard amount > 0, let id = unit.leader, let index = commanderIndex(id) else { return [] }
        let commander = commanders![index]
        let before = commander.level
        let gained = amount * (100 + bonus(.commanderExperience, for: commander.owner)) / 100
        commanders![index].experience = min(commander.experience + gained, Commander.experience(forLevel: Commander.highestLevel))
        let after = commanders![index].level
        guard after > before else { return [] }
        if after % 10 == 0 {
            record(.commander, [commander.owner], "\(commander.name) of \(houses[commander.owner].title) rises to the \(after)th level; the lake speaks of them.")
        }
        return [.commanderRose(commander: id, house: commander.owner, level: after)]
    }

    /// One side of a battle as its commander comes out of it: the company as
    /// it went in, the skill it fired, whether it fell, what it learned.
    struct Stir {
        let unit: Unit
        let fired: Skill?
        let fell: Bool
        let experience: Int
    }

    /// No fury: blows as they fall.
    static let calm = (dealt: 100, taken: 100)

    /// A blow as the furies on either side make it: the striker's on what
    /// it deals, the struck's on what it takes.
    static func furious(_ damage: Int, dealtBy striker: (dealt: Int, taken: Int), takenBy struck: (dealt: Int, taken: Int)) -> Int {
        damage * striker.dealt / 100 * struck.taken / 100
    }

    /// After a battle, each side's commander: a skill fired is told, and its
    /// fury begins again, or else it rises; and one whose company lives
    /// learns from the fight. One whose company fell was carried home.
    mutating func stirCommanders(_ sides: [Stir], at hex: Hex) -> [GameEvent] {
        var events: [GameEvent] = []
        for side in sides {
            guard let id = side.unit.leader, let index = commanderIndex(id) else { continue }
            if let fired = side.fired {
                events.append(.skillFired(commander: id, house: side.unit.owner, skill: fired, at: hex))
            }
            guard !side.fell else { continue }
            commanders![index].fury = side.fired == nil ? commanders![index].fury + 1 : 0
            events += teach(side.unit, side.experience)
        }
        return events
    }

    /// Experience a battle gives a company's commander: for being in it, for
    /// the blow it dealt, and more for a foe that fell.
    static func battleExperience(dealt: Int, felled: Bool) -> Int {
        10 + dealt / 2 + (felled ? 30 : 0)
    }
}
