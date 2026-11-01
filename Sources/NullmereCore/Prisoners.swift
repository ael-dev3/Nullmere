/// Prisoners who talk: a commander whose company a keeper's House fells
/// is taken prisoner, not carried home wounded. Their captor may question
/// them once a watch, and the realm tells the captor one true thing of the
/// prisoner's House, each time the next: its army, its greatest company
/// and where it stands, its stores, the hold it means to take, and the
/// walls of its seat. The captor's Mac's model gives it in the prisoner's
/// voice. The prisoner's House may ransom them for moonsalt, the more the
/// higher their level; the captor may let them go; and after twenty
/// watches they slip away. Freed, they come home to mend. Only a keeper's
/// House takes prisoners, so a world of stewards goes as it always did.
public struct Captivity: Codable, Equatable, Sendable {
    /// The House that holds them, and the watch they were taken.
    public let by: Int
    public let since: Int
    /// How many times they have been questioned, and the watch last.
    public internal(set) var questioned: Int
    public internal(set) var lastQuestioned: Int?
    /// What they have told, in order: their captor's alone to know.
    public internal(set) var told: [String]?
}

extension GameState {
    /// Watches a prisoner is held before they slip away.
    public static let captivityLasts = 20

    /// What a House pays to ransom its commander: ten moonsalt a level,
    /// twenty at the least.
    public static func ransom(for commander: Commander) -> Stock {
        Stock(moonsalt: max(20, 10 * commander.level))
    }

    /// The commanders of other Houses a House holds prisoner.
    public func prisoners(heldBy house: Int) -> [Commander] {
        roster.filter { $0.captive?.by == house }
    }

    /// A fallen company's commander taken prisoner, where a keeper's House
    /// felled it; nil where none is taken, and the commander goes home
    /// wounded as before.
    mutating func takePrisoner(of unit: Unit, by captor: Int?) -> [GameEvent]? {
        guard let captor, houses.indices.contains(captor), houses[captor].isPlayer, captor != unit.owner,
              let id = unit.leader, let index = commanderIndex(id), commanders![index].captive == nil else { return nil }
        commanders![index].captive = Captivity(by: captor, since: watch, questioned: 0, lastQuestioned: nil)
        commanders![index].fury = 0
        record(.commander, [captor, unit.owner], "\(houses[captor].title) takes \(commanders![index].name) of \(houses[unit.owner].title) prisoner.")
        return [.commanderTaken(commander: id, house: unit.owner, by: captor)]
    }

    /// Why a House can't question a commander now; nil if it can.
    public func questionRefusal(_ commanderID: Int, as house: Int) -> RuleError? {
        guard let captive = commander(commanderID)?.captive, captive.by == house else { return .notYourPrisoner }
        if captive.lastQuestioned == watch { return .questionedThisWatch }
        return nil
    }

    mutating func question(_ commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = questionRefusal(commanderID, as: house) { throw refusal }
        let index = commanderIndex(commanderID)!
        let word = word(from: commanders![index])
        commanders![index].captive!.questioned += 1
        commanders![index].captive!.lastQuestioned = watch
        commanders![index].captive!.told = (commanders![index].captive!.told ?? []) + [word]
        return [.prisonerQuestioned(commander: commanderID, by: house, word: word)]
    }

    /// The true things a prisoner knows of their House, in the order they
    /// are told: its army, its greatest company, its stores, the hold it
    /// means to take (where it means to take one), and its seat's walls.
    public func knowledge(of house: Int) -> [String] {
        let title = houses[house].title
        var known: [String] = []
        let army = units(of: house).filter(\.kind.isMilitary)
        let troops = army.reduce(0) { $0 + self.troops(of: $1) }
        known.append(army.isEmpty ? "\(title) has no company of war at all."
            : "\(title) has \(army.count == 1 ? "one company" : "\(army.count) companies") of war, \(GameState.counted(troops)) troops in all.")
        if let greatest = army.max(by: { (self.troops(of: $0), $1.id) < (self.troops(of: $1), $0.id) }) {
            known.append("The greatest company of \(title) is its \(greatest.kind.title), \(GameState.counted(self.troops(of: greatest))) troops, "
                + "\(placeName(of: greatest.position)).")
        }
        let stock = houses[house].stock
        known.append(stock.isZero ? "\(title) has nothing in store." : "\(title) has \(stock) in store.")
        if let target = meant(by: house) {
            known.append("\(title) means to take \(target.name) next.")
        }
        if let seat = seat(of: house) {
            let walls = seat.level(.walls)
            known.append(walls == 0 ? "\(seat.name), the seat of \(title), has no walls; its ward stands at \(seat.ward)."
                : "The walls of \(seat.name), the seat of \(title), stand at the \(ordinal(walls)) level; its ward at \(seat.ward).")
        }
        return known
    }

    /// The hold a House means to take: the one its steward lays siege to,
    /// or, for a keeper's House, the enemy hold most of its marching
    /// companies are bound for.
    func meant(by house: Int) -> Hold? {
        guard livingHouses.contains(where: { isAtWar(house, $0.id) }) else { return nil }
        if !houses[house].isPlayer {
            return RivalMind(house: house).siegePlan(in: self).flatMap { hold(at: $0.target) }
        }
        var bound: [Int: Int] = [:]
        for unit in units(of: house) where unit.kind.isMilitary {
            guard let to = unit.destination, let target = holds.first(where: { $0.position.distance(to: to) <= 1 && isAtWar(house, $0.owner) })
            else { continue }
            bound[target.id, default: 0] += 1
        }
        return bound.max { ($0.value, $1.key) < ($1.value, $0.key) }.flatMap { hold($0.key) }
    }

    /// What a prisoner tells when questioned: the next true thing in turn.
    func word(from prisoner: Commander) -> String {
        let known = knowledge(of: prisoner.owner)
        return known[(prisoner.captive?.questioned ?? 0) % known.count]
    }

    /// Why a House can't ransom its commander now; nil if it can.
    public func ransomRefusal(_ commanderID: Int, as house: Int) -> RuleError? {
        guard let commander = commander(commanderID), commander.owner == house, commander.captive != nil else { return .notAPrisoner }
        let price = GameState.ransom(for: commander)
        guard houses[house].stock.covers(price) else { return .shortOf(houses[house].stock.shortfall(for: price)) }
        return nil
    }

    mutating func ransom(_ commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = ransomRefusal(commanderID, as: house) { throw refusal }
        let index = commanderIndex(commanderID)!
        let captor = commanders![index].captive!.by
        let price = GameState.ransom(for: commanders![index])
        houses[house].stock.debit(price)
        if houses.indices.contains(captor), !houses[captor].isEliminated { store(price, for: captor) }
        record(.commander, [house, captor], "\(houses[house].title) ransoms \(commanders![index].name) from \(houses[captor].title) for \(price).")
        return free(index, why: .ransomed)
    }

    /// The captor lets a prisoner go, for nothing.
    mutating func release(_ commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let index = commanderIndex(commanderID), commanders![index].captive?.by == house else { throw .notYourPrisoner }
        record(.commander, [house, commanders![index].owner],
               "\(houses[house].title) lets \(commanders![index].name) of \(houses[commanders![index].owner].title) go.")
        return free(index, why: .released)
    }

    /// As the watch turns: prisoners held their full time slip away, and
    /// those whose captor has fallen walk free.
    mutating func keepPrisoners() -> [GameEvent] {
        guard let all = commanders, all.contains(where: { $0.captive != nil }) else { return [] }
        var events: [GameEvent] = []
        for index in all.indices {
            guard let captive = all[index].captive else { continue }
            let gone = !houses.indices.contains(captive.by) || houses[captive.by].isEliminated
            guard gone || watch - captive.since >= GameState.captivityLasts else { continue }
            record(.commander, [all[index].owner], "\(all[index].name) slips away from \(houses.indices.contains(captive.by) ? houses[captive.by].title : "their captors") and comes home.")
            events += free(index, why: .escaped)
        }
        return events
    }

    /// A prisoner freed comes home to mend.
    private mutating func free(_ index: Int, why: Freed) -> [GameEvent] {
        let by = commanders![index].captive!.by
        commanders![index].captive = nil
        commanders![index].woundedUntil = watch + GameState.woundWatches
        return [.prisonerFreed(commander: commanders![index].id, house: commanders![index].owner, by: by, why: why)]
    }
}

/// How a prisoner came to be free.
public enum Freed: String, Codable, Equatable, Sendable {
    case ransomed, released, escaped
}
