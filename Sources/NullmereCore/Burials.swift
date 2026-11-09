/// The unquiet dead (an invention of Nullmere's own): a keeper's troops
/// fallen in battle lie where they fell until a company buries them. Left
/// unburied on a field where many fell, at the dark of the moon they rise
/// as Barrowkin, the restless dead of the barrows, and stand there, every
/// House's foe, until some House strikes them down; a field where fewer
/// fell the land takes back at the dark of the moon. A company standing
/// on the field may bury them instead, any House's dead, its watch spent
/// raising a barrow over them, and each field a keeper's House buries adds
/// to its keeper's renown as the age ends. The Houses the stewards keep
/// bury their own as they fall, so a world they play alone is the same
/// with this as without it.
public struct FieldOfDead: Codable, Equatable, Sendable {
    /// Where they lie.
    public let at: Hex
    /// How many troops lie there unburied.
    public internal(set) var troops: Int
    /// The Houses whose dead they are, in the order they fell there.
    public internal(set) var houses: [Int]
    /// The watch the first of them fell.
    public let since: Int

    public init(at: Hex, troops: Int, houses: [Int], since: Int) {
        self.at = at
        self.troops = troops
        self.houses = houses
        self.since = since
    }
}

/// A barrow raised over a field's dead: where, how many lie in it, the
/// House that buried them and when, and the Houses whose dead they are.
public struct Grave: Codable, Equatable, Sendable {
    public let at: Hex
    public let troops: Int
    public let house: Int
    public let watch: Int
    /// The Houses whose dead lie in it, in the order they fell there; nil
    /// for a barrow raised before this was kept.
    public let dead: [Int]?

    public init(at: Hex, troops: Int, house: Int, watch: Int, dead: [Int]? = nil) {
        self.at = at
        self.troops = troops
        self.house = house
        self.watch = watch
        self.dead = dead
    }

    /// The barrow's own number, the same wherever it is told: from the
    /// watch it was raised and where (no two are raised on one hex in one
    /// watch), never below nought for a realm's ground.
    public var key: Int {
        watch * 4_000_000 + (at.q + 1_000) * 2_000 + (at.r + 1_000)
    }
}

extension GameState {
    /// The fewest troops left unburied on a field that rise at the dark of
    /// the moon, and how many more for each level they rise at past the
    /// first.
    public static let unquietAt = 6_000
    public static let unquietPerLevel = 4_000
    /// The renown each field a House buries is worth as the age ends, and
    /// how many count.
    public static let renownPerBurial = 2
    public static let burialsThatCount = 5
    /// The most barrows the land keeps, the oldest sinking into it.
    public static let gravesKept = 120

    /// What burying the dead is, said where a company may, on the Mac and
    /// the phone.
    public static var burialSaid: String {
        "Your company spends its watch burying the dead that lie here under a barrow, any House's. Left unburied where "
            + "\(counted(unquietAt)) troops or more lie, at the dark of the moon they rise as Barrowkin and stand there, every House's foe. "
            + "Each field your House buries adds to your renown as the age ends."
    }

    /// Every field where a keeper's dead lie unburied.
    public var fieldsOfDead: [FieldOfDead] { unburied ?? [] }

    /// The dead lying unburied on a hex, if any lie there.
    public func fieldOfDead(at hex: Hex) -> FieldOfDead? {
        unburied?.first { $0.at == hex }
    }

    /// Every barrow raised over a field's dead this age.
    public var gravesRaised: [Grave] { graves ?? [] }

    /// The watches until the dark of the moon, when the unquiet rise; 0 at it.
    public func watchesToTheDark(from watch: Int) -> Int {
        let age = GameState.moonAge(at: watch)
        return (GameState.dreamingMoon - age + GameState.lunarMonth) % GameState.lunarMonth
    }

    /// The dead lying unburied on a field, as the Mac and the phone say it
    /// to `house`: how many and whose, and what comes of them at the dark
    /// of the moon.
    public func fieldOfDeadSaid(_ field: FieldOfDead, for house: Int) -> String {
        let whose = field.houses == [house] ? "your House's" : field.houses.contains(house) ? "your House's and others'" : "other Houses'"
        let left = watchesToTheDark(from: watch)
        let when = "at the dark of the moon, in \(GameState.watches(left == 0 ? GameState.lunarMonth : left))"
        let fate = field.troops >= GameState.unquietAt ? "\(when.prefix(1).uppercased() + when.dropFirst()), they rise as Barrowkin, unless buried."
            : "The land takes them back \(when)."
        return "\(GameState.counted(field.troops)) troops of \(whose) dead lie unburied here. \(fate)"
    }

    /// A barrow raised over a field's dead, as the Mac and the phone say it.
    public func graveSaid(_ grave: Grave, for house: Int) -> String {
        let who = grave.house == house ? "your House" : houses.indices.contains(grave.house) ? houses[grave.house].title : "a fallen House"
        return "A barrow over \(GameState.counted(grave.troops)) troops, raised by \(who) in watch \(grave.watch)."
    }

    /// The barrow raised on a hex, the latest if more than one.
    public func grave(at hex: Hex) -> Grave? {
        graves?.last { $0.at == hex }
    }

    /// The fields a keeper's House has buried this age that count toward
    /// its keeper's renown as the age ends.
    public func burialsCounted(of house: Int) -> Int {
        guard houses.indices.contains(house) else { return 0 }
        return min(houses[house].buried ?? 0, GameState.burialsThatCount)
    }

    /// A keeper's House's troops fallen at a hex lie there unburied; a
    /// steward's House buries its own as they fall.
    mutating func layTheFallen(_ troops: Int, of house: Int, at hex: Hex) {
        guard troops > 0, houses.indices.contains(house), houses[house].isPlayer else { return }
        var fields = unburied ?? []
        if let index = fields.firstIndex(where: { $0.at == hex }) {
            fields[index].troops += troops
            if !fields[index].houses.contains(house) { fields[index].houses.append(house) }
        } else {
            fields.append(FieldOfDead(at: hex, troops: troops, houses: [house], since: watch))
        }
        unburied = fields
    }

    /// Why a company can't bury the dead where it stands, if it can't: one
    /// of the House's own companies of war that hasn't yet acted this
    /// watch, on a field where dead lie unburied.
    public func burialRefusal(by unitID: Int, as house: Int) -> RuleError? {
        guard outcome == nil else { return .gameOver }
        guard let unit = unit(unitID) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard unit.kind.isMilitary else { return .cannotFight }
        guard !unit.acted else { return .spentThisWatch }
        guard fieldOfDead(at: unit.position) != nil else { return .noDeadHere }
        return nil
    }

    /// A company buries the dead where it stands under a barrow, its watch
    /// spent.
    mutating func bury(by unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = burialRefusal(by: unitID, as: house) { throw refusal }
        guard let index = unitIndex(unitID), let field = fieldOfDead(at: units[index].position) else { throw .unknownUnit }
        units[index].acted = true
        units[index].movesLeft = 0
        units[index].destination = nil
        unburied = fieldsOfDead.filter { $0.at != field.at }.nilIfEmpty
        var kept = gravesRaised + [Grave(at: field.at, troops: field.troops, house: house, watch: watch, dead: field.houses)]
        if kept.count > GameState.gravesKept { kept.removeFirst(kept.count - GameState.gravesKept) }
        graves = kept
        houses[house].buried = (houses[house].buried ?? 0) + 1
        record(.battle, [house] + field.houses.filter { $0 != house },
               "\(houses[house].title) buries the dead \(placeName(of: field.at)), \(GameState.counted(field.troops)) troops, under a barrow.")
        return [.buried(field, by: house)]
    }

    /// At the dark of the moon the dead left unburied rise where enough of
    /// them lie, on their field or the nearest open ground within two
    /// tiles, a company of Barrowkin the stronger the more of them; the
    /// land takes back the rest.
    mutating func raiseTheUnquiet() -> [GameEvent] {
        guard GameState.moonAge(at: watch) == GameState.dreamingMoon, let fields = unburied, !fields.isEmpty else { return [] }
        unburied = nil
        var events: [GameEvent] = []
        for field in fields where field.troops >= GameState.unquietAt {
            guard let at = field.at.spiral(2).first(where: { hex in
                guard let tile = map[hex], tile.terrain.isPassable, !tile.terrain.isWater else { return false }
                return !isOccupied(hex) && shrine(at: hex) == nil
            }) else { continue }
            let level = min(Wild.highestLevel, 1 + (field.troops - GameState.unquietAt) / GameState.unquietPerLevel)
            if wilds == nil { wilds = [] }
            let risen = Wild(id: takeID(), kind: .barrowkin, level: level, position: at, raised: watch)
            wilds!.append(risen)
            record(.hunt, field.houses, "At the dark of the moon the dead left unburied \(placeName(of: field.at)) rise, "
                   + "\(GameState.counted(field.troops)) troops, and stand there as Barrowkin.")
            events.append(.unquietRose(field, wild: risen.id, at: at, level: level))
        }
        return events
    }
}

extension Voicing {
    /// The words cut on the standing stone at the head of a barrow a
    /// keeper's House raised over a field's dead.
    public static let graveTask = "Give the words cut on the standing stone at the head of this barrow, raised over the dead of a battle: "
        + "whose dead lie here, where they fell and who raised the barrow over them, old and plain, keeping every name and number as given. "
        + "One or two lines, at most 30 words."
}

extension GameState {
    /// A barrow the House raised, for the device's model to give the words
    /// cut on its stone: who raised it and when, over how many, whose dead
    /// they are and where they fell. Nil for one another House raised.
    public func voiced(_ grave: Grave, for house: Int) -> Voicing.Moment? {
        guard grave.house == house, houses.indices.contains(house) else { return nil }
        let whose = (grave.dead ?? [grave.house]).filter { houses.indices.contains($0) }.map { houses[$0].title }
        var facts = ["\(houses[house].title) raised this barrow in watch \(grave.watch) over \(GameState.counted(grave.troops)) troops."]
        if !whose.isEmpty { facts.append("The dead are of \(listed(whose)).") }
        facts.append("They fell \(placeName(of: grave.at)).")
        return Voicing.Moment(task: Voicing.graveTask, facts: facts)
    }
}

private extension Array {
    /// The array, or nil where it is empty.
    var nilIfEmpty: [Element]? { isEmpty ? nil : self }
}
