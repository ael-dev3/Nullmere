/// Letters to the age to come: a keeper seals a letter under the stones of
/// a hold of their House, once an age, for moonsalt. As the age ends it
/// goes down with the hold, which the water lays among the first of the
/// drowned; in the next age the first company to search that drowned ruin
/// finds it, and the Chronicle tells every House its words, who sealed it
/// and in which age. A letter whose hold can't lie drowned goes down with
/// the nearest hold that does. Only a keeper seals one, so a world of
/// stewards goes as it always did.
public struct Letter: Codable, Equatable, Sendable {
    public let id: Int
    public internal(set) var words: String
    /// The House that sealed it, and the hold, as they were then: by index
    /// and id in the age it was sealed in, and by name for the ages after.
    public let house: Int
    public let holdID: Int
    public let from: String
    public let hold: String
    /// The watch it was sealed in; the age, once the water has it.
    public let watch: Int
    public internal(set) var age: Int?
    /// Where it lies drowned, once the water has it.
    public internal(set) var at: Hex?
    /// The House of the age after that found it, and the watch; absent
    /// until it is found.
    public internal(set) var foundBy: Int?
    public internal(set) var found: Int?

    public init(id: Int, words: String, house: Int, holdID: Int, from: String, hold: String, watch: Int) {
        self.id = id
        self.words = words
        self.house = house
        self.holdID = holdID
        self.from = from
        self.hold = hold
        self.watch = watch
    }
}

extension GameState {
    /// What sealing a letter costs.
    public static let letterCost = Stock(moonsalt: 20)

    /// The letters sealed in this age, for the age to come.
    public var lettersSealed: [Letter] { letters ?? [] }

    /// The letters of the age before, lying drowned with their holds, found
    /// or not.
    public var lettersOfOld: [Letter] { oldLetters ?? [] }

    /// The letter a House has sealed this age, if it has.
    public func letter(sealedBy house: Int) -> Letter? {
        lettersSealed.first { $0.house == house }
    }

    /// The letters of old not yet found at a hex.
    public func lettersUnfound(at hex: Hex) -> [Letter] {
        lettersOfOld.filter { $0.at == hex && $0.foundBy == nil }
    }

    /// Why a House can't seal these words in a hold now; nil if it can.
    public func sealRefusal(_ words: String, in holdID: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard let hold = hold(holdID) else { return .unknownHold }
        guard hold.owner == house else { return .notYours }
        guard Envoy.carried(words) != nil else { return .nothingToSay }
        // Every House of the age after reads it: a House barred from the
        // Words seals none while the bar holds.
        if let until = barredFromWords(house) { return .barredFromWords(until: until) }
        if letter(sealedBy: house) != nil { return .letterSealed }
        guard houses[house].stock.covers(GameState.letterCost) else { return .shortOf(houses[house].stock.shortfall(for: GameState.letterCost)) }
        return nil
    }

    mutating func sealLetter(_ words: String, in holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = sealRefusal(words, in: holdID, as: house) { throw refusal }
        let hold = self.hold(holdID)!
        houses[house].stock.debit(GameState.letterCost)
        let letter = Letter(id: takeID(), words: Envoy.carried(words)!, house: house, holdID: holdID, from: houses[house].title,
                            hold: hold.name, watch: watch)
        letters = lettersSealed + [letter]
        return [.letterSealed(hold: holdID, by: house)]
    }

    /// As a new age begins: the letters the age before sealed go down with
    /// their holds where the water laid them, or with the nearest it did.
    mutating func sinkLetters(of before: GameState, age: Int) {
        guard !before.lettersSealed.isEmpty, !drownedHolds.isEmpty else { return }
        var sunk: [Letter] = []
        for var letter in before.lettersSealed {
            guard let stood = before.hold(letter.holdID)?.position,
                  let lies = drownedHolds.min(by: { ($0.position.distance(to: stood), $0.position) < ($1.position.distance(to: stood), $1.position) })
            else { continue }
            letter.age = age - 1
            letter.at = lies.position
            sunk.append(letter)
        }
        guard !sunk.isEmpty else { return }
        oldLetters = sunk
        record(.beginning, [], sunk.count == 1 ? "A letter sealed in the age before lies with its drowned hold, for whoever searches it."
            : "\(sunk.count) letters sealed in the age before lie with their drowned holds, for whoever searches them.")
    }

    /// A company searching a drowned ruin finds the letters that lie there,
    /// and the Chronicle tells every House their words.
    mutating func findLetters(at hex: Hex, by house: Int) -> [GameEvent] {
        guard var all = oldLetters, all.contains(where: { $0.at == hex && $0.foundBy == nil }) else { return [] }
        var events: [GameEvent] = []
        for index in all.indices where all[index].at == hex && all[index].foundBy == nil {
            all[index].foundBy = house
            all[index].found = watch
            let letter = all[index]
            let age = letter.age.map { "the \(ordinal($0)) age" } ?? "an age before"
            record(.discovery, [house], "Among the drowned stones of \(letter.hold), \(houses[house].title) finds a letter of \(age), "
                   + "sealed by \(letter.from): “\(letter.words)”")
            events.append(.letterFound(letter: letter, by: house))
        }
        oldLetters = all
        return events
    }
}

extension Letter {
    /// The letter as its drowned ruin's record tells it: lying there unread,
    /// or found, with its words.
    public func told(in state: GameState) -> String {
        let age = self.age.map { "the \(ordinal($0)) age" } ?? "an age before"
        guard let finder = foundBy else {
            return "A letter of \(age), sealed by \(from), lies within, unread, for whoever searches the ruin."
        }
        let by = state.houses.indices.contains(finder) ? state.houses[finder].title : "a House since gone"
        return "A letter of \(age), sealed by \(from), found by \(by): “\(words)”"
    }
}
