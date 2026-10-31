import Foundation

/// A field of battle, in a realm's watch: where companies at war meet, one
/// battle of many companies. It is joined where one company strikes
/// another, and takes in every company that strikes or is struck near its
/// heart, each on its House's side. At each pace every company standing in
/// it strikes a foe of the other side within its reach, the one it fought
/// last while it can, so a company struck strikes back; and its Houses'
/// companies standing near with nothing else to do come into it. It is
/// over when a pace passes without a blow, when one side has none left
/// standing in it, or when it has gone on two watches; then every House
/// that fought in it has its report: each side's companies and troops, the
/// troops slain and lost, the companies fallen, and which side holds the
/// field.
public struct Field: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    /// Its heart: where the first blow fell.
    public let at: Hex
    /// The watch it was joined.
    public let joined: Int
    /// The Houses of its two sides, the first of each the House that
    /// struck first and the House it struck.
    public internal(set) var sides: [[Int]]
    /// Every company that has fought in it, in the order each came.
    public internal(set) var fighters: [Fighter]
    /// The paces it has gone on since it was joined.
    public internal(set) var paces: Int
    /// The side that holds the field, as it ends: the one with companies
    /// still in it when the other has none.
    public internal(set) var held: Int?

    public init(id: Int, at: Hex, joined: Int, first: Int, second: Int) {
        self.id = id
        self.at = at
        self.joined = joined
        self.sides = [[first], [second]]
        self.fighters = []
        self.paces = 0
        self.held = nil
    }

    /// How far from its heart a company fights in it: far enough that two
    /// armies met along a front fight one battle, not one for every few
    /// companies.
    public static let span = 5
    /// The longest it goes on: two watches of paces.
    public static let longest = 2 * GameState.pacesPerWatch
    /// The fewest companies that make it a battle the chronicle tells.
    public static let told = 6

    /// The side a House fights on, if it fights in it.
    public func side(of house: Int) -> Int? {
        sides.firstIndex { $0.contains(house) }
    }

    /// The companies a side brought to it.
    public func fighters(of side: Int) -> [Fighter] {
        fighters.filter { $0.side == side }
    }

    /// A side's troops, as each of its companies came into it.
    public func troops(of side: Int) -> Int {
        fighters(of: side).reduce(0) { $0 + $1.troops }
    }

    /// A side's troops lost in it.
    public func lost(by side: Int) -> Int {
        fighters(of: side).reduce(0) { $0 + $1.lost }
    }

    /// A side's troops still standing of those it brought.
    public func standing(of side: Int) -> Int {
        fighters(of: side).reduce(0) { $0 + max($1.troops - $1.lost, 0) }
    }

    /// A side's companies that fell in it.
    public func fallen(of side: Int) -> Int {
        fighters(of: side).filter(\.fell).count
    }

    /// A side's companies standing in it now, and their troops.
    public func inField(_ side: Int) -> (companies: Int, troops: Int) {
        let standing = fighters(of: side).filter(\.standing)
        return (standing.count, standing.reduce(0) { $0 + max($1.troops - $1.lost, 0) })
    }

    /// The company a fighter entry is for, if it fought here.
    public func fighter(_ unit: Int) -> Fighter? {
        fighters.first { $0.unit == unit }
    }

    /// Whether a company stands in it still.
    public func isStanding(_ unit: Int) -> Bool {
        fighter(unit)?.standing == true
    }
}

/// A company as it fought in a field: whose, on which side, what it was
/// as it came, and what it did and suffered there.
public struct Fighter: Codable, Equatable, Sendable {
    public let unit: Int
    public let owner: Int
    public let side: Int
    public let kind: UnitKind
    public let tier: Int
    /// The commander at its head as it came, by name.
    public let leader: String?
    /// Its troops as it came, and any healed before it came again.
    public internal(set) var troops: Int
    /// The foe's troops it slew there, and its own it lost.
    public internal(set) var slain: Int
    public internal(set) var lost: Int
    /// Whether it fell there.
    public internal(set) var fell: Bool
    /// Whether it is still in the field: not fallen, nor drawn off.
    public internal(set) var standing: Bool
    /// The company it fights: the one it struck last, or the one that
    /// struck it.
    public internal(set) var foe: Int?
    /// Whether its House sent it against its foe: then, its foe fallen in
    /// close battle, it takes its ground.
    public internal(set) var sent: Bool

    public init(unit: Int, owner: Int, side: Int, kind: UnitKind, tier: Int, leader: String?, troops: Int) {
        self.unit = unit
        self.owner = owner
        self.side = side
        self.kind = kind
        self.tier = tier
        self.leader = leader
        self.troops = troops
        self.slain = 0
        self.lost = 0
        self.fell = false
        self.standing = true
        self.foe = nil
        self.sent = false
    }
}

extension GameState {
    /// The fields of battle going on.
    public var fieldsOfBattle: [Field] { fields ?? [] }

    public func field(_ id: Int) -> Field? {
        fields?.first { $0.id == id }
    }

    /// The field a company stands in, if it is in one.
    public func field(of unit: Int) -> Field? {
        fields?.first { $0.isStanding(unit) }
    }

    private func fieldIndex(_ id: Int) -> Int? {
        fields?.firstIndex { $0.id == id }
    }

    /// The side a House would fight on in a field: its own, or, new to it,
    /// the side none of whose Houses it is at war with while it is at war
    /// with a House of the other. None if it fits neither, or both.
    func side(for house: Int, in field: Field) -> Int? {
        if let side = field.side(of: house) { return side }
        let fits = field.sides.indices.filter { side in
            !field.sides[side].contains { isAtWar(house, $0) } && field.sides[1 - side].contains { isAtWar(house, $0) }
        }
        return fits.count == 1 ? fits[0] : nil
    }

    /// A blow between two companies in a realm's watch falls in a field of
    /// battle: the one near where either already stands, or any near whose
    /// sides take their Houses against each other, or else one joined
    /// there. Both come into it on their Houses' sides, leaving any other
    /// they stood in, and what each slew and lost is counted; the blow is
    /// told as the field's. `sent` says the striker was sent against the
    /// struck by its House.
    mutating func fieldBlow(_ events: [GameEvent], sent: Bool) -> [GameEvent] {
        guard isPaced, let at = events.firstIndex(where: { if case .battle = $0 { return true } else { return false } }),
              case .battle(var battle) = events[at], let struck = battle.defender else { return events }
        let striker = battle.attacker
        func fits(_ field: Field) -> Bool {
            guard field.at.distance(to: battle.at) <= Field.span,
                  let mine = side(for: battle.attackerOwner, in: field), let theirs = side(for: battle.defenderOwner, in: field) else { return false }
            return mine != theirs
        }
        var events = events
        let index: Int
        if let found = fieldsOfBattle.firstIndex(where: { ($0.isStanding(struck) || $0.isStanding(striker)) && fits($0) })
            ?? fieldsOfBattle.firstIndex(where: fits) {
            index = found
        } else {
            let field = Field(id: takeID(), at: battle.at, joined: watch, first: battle.attackerOwner, second: battle.defenderOwner)
            fields = fieldsOfBattle + [field]
            index = fields!.count - 1
            events.insert(.fieldJoined(field: field.id, at: field.at, first: battle.attackerOwner, second: battle.defenderOwner), at: at)
        }
        let field = fields![index].id
        tally(&battle, in: index, sent: sent)
        battle.field = field
        events[events.firstIndex(where: { if case .battle = $0 { return true } else { return false } })!] = .battle(battle)
        return events
    }

    /// A blow counted in a field: its striker and the struck in it on their
    /// sides, what each slew and lost, who fell; the struck turns on its
    /// striker unless it fights another it can still reach.
    private mutating func tally(_ battle: inout Battle, in index: Int, sent: Bool) {
        guard let struck = battle.defender else { return }
        let striker = battle.attacker
        let strikerAt = enter(striker, owner: battle.attackerOwner, kind: battle.attackerKind, troopsBefore: battle.lost ?? 0, in: index)
        let struckAt = enter(struck, owner: battle.defenderOwner, kind: battle.defenderKind ?? .spear, troopsBefore: battle.slain ?? 0, in: index)
        fields![index].fighters[strikerAt].slain += battle.slain ?? 0
        fields![index].fighters[strikerAt].lost += battle.lost ?? 0
        // Sent against the struck, it takes its ground; turned on another, it holds its own.
        if sent || fields![index].fighters[strikerAt].foe != struck { fields![index].fighters[strikerAt].sent = sent }
        fields![index].fighters[strikerAt].foe = struck
        fields![index].fighters[struckAt].slain += battle.lost ?? 0
        fields![index].fighters[struckAt].lost += battle.slain ?? 0
        if battle.attackerFell {
            fields![index].fighters[strikerAt].fell = true
            fields![index].fighters[strikerAt].standing = false
        }
        if battle.defenderFell {
            fields![index].fighters[struckAt].fell = true
            fields![index].fighters[struckAt].standing = false
        }
        let theirs = fields![index].fighters[struckAt]
        if theirs.foe.flatMap({ foe(theirs, in: fields![index], fighting: $0) }) == nil {
            fields![index].fighters[struckAt].foe = striker
            fields![index].fighters[struckAt].sent = false
        }
    }

    /// A company comes into a field on its House's side, or stands in it
    /// again; it leaves any other field it stood in. Its troops as it came
    /// are those it stands with and those the blow just took. Where it is
    /// in the field's companies.
    private mutating func enter(_ unitID: Int, owner: Int, kind: UnitKind, troopsBefore taken: Int, in index: Int) -> Int {
        for other in fieldsOfBattle.indices where other != index {
            if let entry = fields![other].fighters.firstIndex(where: { $0.unit == unitID && $0.standing }) {
                fields![other].fighters[entry].standing = false
            }
        }
        let alive = unit(unitID)
        if let entry = fields![index].fighters.firstIndex(where: { $0.unit == unitID }) {
            // Back after drawing off: those healed since count as come.
            let fighter = fields![index].fighters[entry]
            let now = (alive.map(troops(of:)) ?? 0) + taken, was = max(fighter.troops - fighter.lost, 0)
            if !fighter.standing, now > was { fields![index].fighters[entry].troops += now - was }
            fields![index].fighters[entry].standing = alive != nil
            return entry
        }
        let field = fields![index]
        let side = side(for: owner, in: field)!
        if !fields![index].sides[side].contains(owner) { fields![index].sides[side].append(owner) }
        let tier = alive?.tier ?? 1
        let troops = (alive.map(troops(of:)) ?? 0) + taken
        let leader = alive?.leader.flatMap { commander($0)?.name }
        var fighter = Fighter(unit: unitID, owner: owner, side: side, kind: kind, tier: tier, leader: leader, troops: troops)
        fighter.standing = alive != nil
        fields![index].fighters.append(fighter)
        return fields![index].fighters.count - 1
    }

    /// The foe a fighter would strike, of those standing on the other side
    /// at war with its House and within its reach: the one named, if given;
    /// else the one it fights, while it can; else the nearest, the fewest
    /// troops first.
    func foe(_ fighter: Fighter, in field: Field, fighting named: Int? = nil) -> Unit? {
        guard let me = unit(fighter.unit) else { return nil }
        func reachable(_ other: Fighter) -> Unit? {
            guard other.side != fighter.side, other.standing, let them = unit(other.unit), isAtWar(me.owner, them.owner),
                  me.position.distance(to: them.position) <= me.kind.range else { return nil }
            return them
        }
        if let named { return field.fighter(named).flatMap(reachable) }
        if let current = fighter.foe, let them = field.fighter(current).flatMap(reachable) { return them }
        return field.fighters.compactMap(reachable).min { a, b in
            (me.position.distance(to: a.position), troops(of: a), a.id) < (me.position.distance(to: b.position), troops(of: b), b.id)
        }
    }

    /// The fields of battle go on for a pace: in each, the companies gone
    /// from it are out of it, its Houses' companies standing near with
    /// nothing else to do and a foe in reach come into it, and every
    /// company standing in it strikes a foe in reach, arrows first; a
    /// field where no blow fell, or with a side gone from it, or that has
    /// run its course, is over.
    mutating func fightFields() -> [GameEvent] {
        var events: [GameEvent] = []
        for id in fieldsOfBattle.map(\.id) {
            events += fightOn(id)
        }
        return events
    }

    private mutating func fightOn(_ id: Int) -> [GameEvent] {
        guard var index = fieldIndex(id) else { return [] }
        settle(index)
        drawIn(index)
        let order = fields![index].fighters.enumerated().sorted { a, b in
            (-a.element.kind.range, a.offset) < (-b.element.kind.range, b.offset)
        }.map(\.element.unit)
        var events: [GameEvent] = []
        var struck = false
        for unitID in order {
            index = fieldIndex(id)!
            let field = fields![index]
            guard let fighter = field.fighter(unitID), fighter.standing, let unit = unit(unitID), unit.kind.isMilitary,
                  unit.destination == nil, let foe = foe(fighter, in: field) else { continue }
            // Sent against this foe, it takes the fallen's ground; else it holds its own.
            let holding = !(fighter.sent && fighter.foe == foe.id)
            var blow = fight(attacker: unitID, defender: foe.id, at: foe.position, holdingGround: holding)
            if let striker = unitIndex(unitID) { units[striker].acted = true }
            if let at = blow.firstIndex(where: { if case .battle = $0 { return true } else { return false } }),
               case .battle(var battle) = blow[at] {
                tally(&battle, in: index, sent: false)
                battle.field = id
                blow[at] = .battle(battle)
            }
            events += blow
            struck = true
        }
        index = fieldIndex(id)!
        fields![index].paces += 1
        settle(index)
        let field = fields![index]
        let standing = field.sides.indices.map { side in field.fighters.contains { $0.side == side && $0.standing } }
        if !struck || standing.contains(false) || field.paces >= Field.longest {
            events += end(index)
        }
        return events
    }

    /// Those fallen, gone from its span, on the march or of a House fallen
    /// are no longer in a field.
    private mutating func settle(_ index: Int) {
        let field = fields![index]
        for (entry, fighter) in field.fighters.enumerated() where fighter.standing {
            guard let unit = unit(fighter.unit) else {
                fields![index].fighters[entry].standing = false
                fields![index].fighters[entry].fell = true
                continue
            }
            if unit.position.distance(to: field.at) > Field.span || unit.destination != nil || houses[unit.owner].isEliminated {
                fields![index].fighters[entry].standing = false
            }
        }
    }

    /// A field's Houses' companies of war standing near it, with no march
    /// or errand of their own and a foe of the field within their reach,
    /// come into it; none that stands in another.
    private mutating func drawIn(_ index: Int) {
        let field = fields![index]
        let houses = Set(field.sides.joined())
        for unit in units.sorted(by: { $0.id < $1.id }) where houses.contains(unit.owner) {
            guard unit.kind.isMilitary, unit.destination == nil, unit.errand == nil, unit.position.distance(to: field.at) <= Field.span,
                  !field.isStanding(unit.id), self.field(of: unit.id) == nil, let side = field.side(of: unit.owner) else { continue }
            let incoming = Fighter(unit: unit.id, owner: unit.owner, side: side, kind: unit.kind, tier: unit.tier, leader: nil, troops: 0)
            guard foe(incoming, in: fields![index]) != nil else { continue }
            _ = enter(unit.id, owner: unit.owner, kind: unit.kind, troopsBefore: 0, in: index)
        }
    }

    /// A field over: which side holds it, told in the chronicle if it was
    /// a battle of many companies, and to every House in it.
    private mutating func end(_ index: Int) -> [GameEvent] {
        var field = fields!.remove(at: index)
        if fields!.isEmpty { fields = nil }
        let standing = field.sides.indices.map { side in field.fighters.contains { $0.side == side && $0.standing } }
        field.held = standing == [true, false] ? 0 : standing == [false, true] ? 1 : nil
        if field.fighters.count >= Field.told {
            func named(_ side: Int) -> String {
                let titles = field.sides[side].map { houses[$0].title }
                return titles.count == 1 ? titles[0] : titles.dropLast().joined(separator: ", ") + " and " + titles.last!
            }
            let leaders = field.sides.map { houses[$0[0]].title }
            let held = field.held.map { "\(leaders[$0])'s side holds the field" } ?? "neither side gives way"
            record(.battle, Array(field.sides.joined()),
                   "The battle \(placeName(of: field.at)): \(named(0)) against \(named(1)), "
                   + "\(GameState.counted(field.troops(of: 0) + field.troops(of: 1))) troops in all; \(leaders[0])'s side loses "
                   + "\(GameState.counted(field.lost(by: 0))) and \(leaders[1])'s \(GameState.counted(field.lost(by: 1))), and \(held).")
        }
        return [.fieldEnded(field)]
    }
}
