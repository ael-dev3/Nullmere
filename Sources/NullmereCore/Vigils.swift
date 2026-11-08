/// Vigils for the fallen: a light set on the Still from a hold on its shore
/// by a keeper whose House has lost companies of war, with their words for
/// the dead. The whole realm sees it. It drifts on the lake's slow current
/// round its deep heart, never washing up, and burns a dozen watches before
/// it gutters out. Any other keeper may honour it, once: each honour counts
/// toward its keeper's renown as the age ends, and binds the honouring
/// House, while the light burns, to strike none of the mourning House's
/// companies or holds and call no rally on them. A battle already joined
/// goes on.
public struct Vigil: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    /// The House that keeps it.
    public let house: Int
    /// Its keeper's words for their dead.
    public let words: String
    /// The companies of war it was lit for: those its House had lost in
    /// battle since its last.
    public let fallen: Int
    /// The watch it was lit.
    public let lit: Int
    public internal(set) var position: Hex
    /// The Houses that have honoured it, in the order they did.
    public internal(set) var honouredBy: [Int]

    public init(id: Int, house: Int, words: String, fallen: Int, lit: Int, position: Hex, honouredBy: [Int] = []) {
        self.id = id
        self.house = house
        self.words = words
        self.fallen = fallen
        self.lit = lit
        self.position = position
        self.honouredBy = honouredBy
    }

    /// The watch it gutters out, and the truce of those who honoured it ends.
    public var until: Int { lit + GameState.vigilBurns }
}

extension GameState {
    /// What a vigil's light costs: a float of timber, a flame of moonsalt.
    public static let vigilCost = Stock(timber: 5, moonsalt: 1)
    /// The watches a vigil's light burns on the water.
    public static let vigilBurns = 12
    /// The most lights the lake carries at once, the oldest guttering first.
    public static let vigilsBurning = 120
    /// The renown each honour of a keeper's vigils is worth as the age
    /// ends, and how many honours count.
    public static let renownPerHonour = 2
    public static let honoursThatCount = 5

    /// What a vigil is, said where one may be kept, on the Mac and the phone.
    public static var vigilSaid: String {
        "A light set on the water for your House's fallen, with your words for them. The whole realm sees it drift until it gutters out, "
            + "\(watches(vigilBurns)) on. A House that honours it may strike none of yours while it burns, and each honour adds to your renown "
            + "at the age's end. It costs \(vigilCost), once your House has lost companies since its last."
    }

    /// Every vigil's light burning on the lake.
    public var vigilsOnTheLake: [Vigil] { vigils ?? [] }

    /// The vigil with an id, while its light burns.
    public func vigil(_ id: Int) -> Vigil? {
        vigilsOnTheLake.first { $0.id == id }
    }

    /// The companies of war a House has lost in battle since its keeper
    /// last kept a vigil for them.
    public func unmourned(by house: Int) -> Int {
        houses.indices.contains(house) ? houses[house].unmourned ?? 0 : 0
    }

    /// Why a House can't keep a vigil from a hold now, if it can't.
    public func vigilRefusal(_ words: String, from holdID: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard let hold = hold(holdID) else { return .unknownHold }
        guard hold.owner == house else { return .notYours }
        guard castingWater(beside: hold) != nil else { return .noWaterBeside }
        guard unmourned(by: house) > 0 else { return .noneUnmourned }
        guard Envoy.carried(words) != nil else { return .nothingToSay }
        guard houses[house].stock.covers(GameState.vigilCost) else { return .shortOf(houses[house].stock.shortfall(for: GameState.vigilCost)) }
        return nil
    }

    mutating func keepVigil(_ words: String, from holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = vigilRefusal(words, from: holdID, as: house) { throw refusal }
        let hold = self.hold(holdID)!
        houses[house].stock.debit(GameState.vigilCost)
        let vigil = Vigil(id: takeID(), house: house, words: Envoy.carried(words)!, fallen: unmourned(by: house), lit: watch,
                          position: castingWater(beside: hold)!)
        houses[house].unmourned = nil
        var all = vigilsOnTheLake + [vigil]
        var events: [GameEvent] = [.vigilKept(vigil)]
        // Past the most the lake carries, the oldest gutter out.
        while all.count > GameState.vigilsBurning {
            let out = all.removeFirst()
            events.append(.vigilOut(vigil: out.id, house: out.house, honours: out.honouredBy.count))
        }
        vigils = all
        return events
    }

    /// Why a House can't honour a vigil now, if it can't.
    public func honourRefusal(_ id: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard let vigil = vigil(id) else { return .noSuchVigil }
        guard vigil.house != house else { return .ownVigil }
        guard !vigil.honouredBy.contains(house) else { return .honouredAlready }
        return nil
    }

    mutating func honourVigil(_ id: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = honourRefusal(id, as: house) { throw refusal }
        let index = vigils!.firstIndex { $0.id == id }!
        vigils![index].honouredBy.append(house)
        let mourner = vigils![index].house
        if houses.indices.contains(mourner) { houses[mourner].honoured = (houses[mourner].honoured ?? 0) + 1 }
        return [.vigilHonoured(vigil: id, house: mourner, by: house)]
    }

    /// The vigil of a House's that another has honoured and still burns,
    /// the one burning longest if there are more: while it does, the
    /// honouring House may not strike the mourning one.
    public func vigilHonoured(by house: Int, of mourner: Int) -> Vigil? {
        vigilsOnTheLake.filter { $0.house == mourner && $0.honouredBy.contains(house) && watch < $0.until }
            .max { ($0.until, $0.id) < ($1.until, $1.id) }
    }

    /// Why a House may not strike another, if it honoured a vigil of
    /// theirs that still burns.
    func mourningRefusal(of house: Int, striking mourner: Int) -> RuleError? {
        vigilHonoured(by: house, of: mourner).map { .mourning(until: $0.until) }
    }

    /// A House's companies of war fallen in battle, counted for its
    /// keeper's next vigil.
    mutating func mourn(_ unit: Unit) {
        guard unit.kind.isMilitary, houses.indices.contains(unit.owner), houses[unit.owner].isPlayer else { return }
        houses[unit.owner].unmourned = unmourned(by: unit.owner) + 1
    }

    /// What a device's model is asked to write as a House's few words for
    /// its dead, on the Mac and the phone alike.
    public static let vigilWordsAsked = "Speak as the House itself, in the few words it sets on the still black water with a light for "
        + "its fallen: name where they fell, keeping every name and number as given, grave and plain, with no vow of vengeance. "
        + "One or two sentences, at most 30 words."

    /// What a House's few words for its dead are written from, on the Mac
    /// and the phone alike: whose they were, how many of its companies of
    /// war fell unmourned, where and when its latest three battles to cost
    /// it companies were fought as its reports tell them, and when the
    /// light is set.
    public func vigilFacts(of house: Int, reports: [BattleReport]) -> [String] {
        var facts: [String] = []
        if houses.indices.contains(house) {
            facts.append("The dead were of \(houses[house].title), of the \(heritage(of: house).title).")
        }
        facts.append("Companies of war of theirs fallen in battle: \(unmourned(by: house)).")
        let costly = reports.filter { $0.outcome == .lost || ($0.sides.first?.fallen ?? 0) > 0 }.sorted { ($0.watch, $0.id) < ($1.watch, $1.id) }
        for report in costly.suffix(3) {
            let foe = report.sides.count > 1 ? ", against \(report.sides[1].title)" : ""
            facts.append("Some fell \(report.place) in watch \(report.watch)\(foe).")
        }
        facts.append("The light is set on the water in watch \(watch).")
        return facts
    }

    /// Whose vigil it is, as the Mac and the phone head it.
    public func vigilTitle(_ vigil: Vigil, for viewer: Int) -> String {
        if vigil.house == viewer { return "Your House's vigil" }
        return houses.indices.contains(vigil.house) ? "\(houses[vigil.house].title)'s vigil" : "A fallen House's vigil"
    }

    /// A vigil as the Mac and the phone tell it: the companies it was lit
    /// for, its keeper's words, who has honoured it, and until when it burns.
    public func vigilLine(_ vigil: Vigil, for viewer: Int) -> String {
        let by = vigil.honouredBy.map { $0 == viewer ? "your House" : houses.indices.contains($0) ? houses[$0].title : "a fallen House" }
        let honoured = by.isEmpty ? "honoured by none yet" : by.count > 3 ? "honoured by \(GameState.counted(by.count)) Houses" : "honoured by \(listed(by))"
        return "For \(GameState.companies(vigil.fallen)) fallen: “\(vigil.words)” Lit in watch \(vigil.lit), \(honoured); it burns until watch \(vigil.until)."
    }

    /// What honouring a vigil binds the honouring House to, said beside the
    /// honouring of it on the Mac and the phone.
    public func honourSaid(_ vigil: Vigil) -> String {
        let mourner = houses.indices.contains(vigil.house) ? houses[vigil.house].title : "its House"
        return "Honour it, and your House may not strike \(mourner), nor rally on its holds, until watch \(vigil.until); "
            + "the honour adds to its keeper's renown as the age ends."
    }

    /// The honours of a House's vigils this age that count toward its
    /// keeper's renown as the age ends.
    public func honoursCounted(of house: Int) -> Int {
        guard houses.indices.contains(house) else { return 0 }
        return min(houses[house].honoured ?? 0, GameState.honoursThatCount)
    }

    /// The vigils as the watch turns: each light drifts a hex on with the
    /// current, never washing up, and gutters out when it has burned its
    /// watches.
    mutating func tendVigils() -> [GameEvent] {
        guard var all = vigils, !all.isEmpty else { return [] }
        var events: [GameEvent] = []
        for index in all.indices {
            if let on = downstream(of: all[index].position) { all[index].position = on }
        }
        for vigil in all where watch >= vigil.until {
            events.append(.vigilOut(vigil: vigil.id, house: vigil.house, honours: vigil.honouredBy.count))
        }
        all.removeAll { watch >= $0.until }
        vigils = all.isEmpty ? nil : all
        return events
    }
}
