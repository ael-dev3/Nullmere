/// The Ring, Rise of Kingdoms' arena of commanders: a keeper stands a line
/// of up to three of their House's commanders in it, and challenges another
/// keeper's line with their own, up to three times a watch. The line that
/// weighs the more wins, each weighed by its commanders' levels, talents
/// and gear, with the realm's chance in it; the winner takes standing from
/// the loser, the more the higher the loser stood. At each full moon the
/// three standing highest are honoured with moonsalt, and every standing
/// drifts halfway back to where all began. No company fights and
/// no commander is hurt. Stewards stand no line, so a world of stewards
/// goes as it always did.
public struct Ring: Codable, Equatable, Sendable {
    /// A House of the Ring: the line it stands, its commanders in order,
    /// and its standing.
    public struct Entry: Codable, Equatable, Sendable {
        public let house: Int
        public internal(set) var line: [Int]
        public internal(set) var standing: Int

        public init(house: Int, line: [Int], standing: Int) {
            self.house = house
            self.line = line
            self.standing = standing
        }
    }

    /// One bout: who challenged whom, what each line weighed with the
    /// realm's chance in it, who won, and the standing that changed hands.
    public struct Bout: Codable, Equatable, Sendable {
        public let watch: Int
        public let challenger: Int
        public let defender: Int
        public let challengerWeight: Int
        public let defenderWeight: Int
        public let won: Bool
        public let change: Int

        public init(watch: Int, challenger: Int, defender: Int, challengerWeight: Int, defenderWeight: Int, won: Bool, change: Int) {
            self.watch = watch
            self.challenger = challenger
            self.defender = defender
            self.challengerWeight = challengerWeight
            self.defenderWeight = defenderWeight
            self.won = won
            self.change = change
        }

        /// The House that won it.
        public var winner: Int { won ? challenger : defender }
        /// The House that lost it.
        public var loser: Int { won ? defender : challenger }
    }

    /// Its Houses, by their place.
    public internal(set) var entries: [Entry]
    /// The bouts lately fought, the latest last.
    public internal(set) var bouts: [Bout]

    public init(entries: [Entry] = [], bouts: [Bout] = []) {
        self.entries = entries
        self.bouts = bouts
    }

    func entry(of house: Int) -> Entry? {
        entries.first { $0.house == house }
    }

    /// Sets a House's line or standing, keeping the entries in the order of
    /// their Houses, so the Ring is written the same way every time.
    mutating func set(_ house: Int, line: [Int]? = nil, standing: Int? = nil) {
        if let index = entries.firstIndex(where: { $0.house == house }) {
            if let line { entries[index].line = line }
            if let standing { entries[index].standing = standing }
        } else {
            entries.append(Entry(house: house, line: line ?? [], standing: standing ?? GameState.ringStart))
            entries.sort { $0.house < $1.house }
        }
    }
}

extension GameState {
    /// Commanders a line holds at most.
    public static let ringLine = 3
    /// Challenges a House may make each watch.
    public static let ringChallenges = 3
    /// Where every standing begins.
    public static let ringStart = 1000
    /// The bouts the realm keeps.
    public static let boutsKept = 24
    /// What the three standing highest are given at each full moon.
    public static let ringHonours = [30, 20, 10]

    /// A House's standing in the Ring.
    public func ringStanding(of house: Int) -> Int {
        ring?.entry(of: house)?.standing ?? GameState.ringStart
    }

    /// The line a House stands in the Ring, if it stands one.
    public func ringLine(of house: Int) -> [Int]? {
        guard let line = ring?.entry(of: house)?.line, !line.isEmpty else { return nil }
        return line
    }

    /// What a commander weighs in the Ring: its level, its talents and the
    /// gear it wears.
    public func ringWeight(of commander: Commander) -> Int {
        let gear = worn(by: commander.id).reduce(0) { $0 + $1.quality.rawValue * 6 }
        return 40 + commander.level * 10 + (commander.talents?.count ?? 0) * 4 + gear
    }

    /// What a House's line weighs, before chance: its commanders still its own.
    public func ringWeight(ofLine house: Int) -> Int {
        (ringLine(of: house) ?? []).compactMap { commander($0) }.filter { $0.owner == house }.reduce(0) { $0 + ringWeight(of: $1) }
    }

    private func isKeeper(_ house: Int) -> Bool {
        houses.indices.contains(house) && houses[house].isPlayer && !houses[house].isEliminated
    }

    /// Why a House can't stand this line now, if it can't: a keeper's, of
    /// one to three of its own commanders, each once.
    public func ringLineRefusal(_ line: [Int], as house: Int) -> RuleError? {
        guard isKeeper(house) else { return .notAKeeper }
        guard (1...GameState.ringLine).contains(line.count), Set(line).count == line.count else { return .invalidAmount }
        guard line.allSatisfy({ commander($0)?.owner == house }) else { return .notYours }
        return nil
    }

    /// A keeper stands a line of their commanders in the Ring.
    mutating func standInTheRing(_ line: [Int], as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = ringLineRefusal(line, as: house) { throw refusal }
        var kept = ring ?? Ring()
        kept.set(house, line: line)
        ring = kept
        return [.ringLineStood(house: house, line: line)]
    }

    /// The challenges a House has made this watch.
    public func challengesMade(by house: Int) -> Int {
        (ring?.bouts ?? []).filter { $0.challenger == house && $0.watch == watch }.count
    }

    /// Why a House can't challenge another's line now, if it can't: both
    /// keepers' Houses with a line of their own commanders standing, not
    /// itself, and a challenge left it this watch.
    public func challengeRefusal(of defender: Int, as house: Int) -> RuleError? {
        guard isKeeper(house) else { return .notAKeeper }
        guard ringWeight(ofLine: house) > 0 else { return .noLineStanding }
        guard defender != house, isKeeper(defender), ringWeight(ofLine: defender) > 0 else { return .notApplicable }
        guard challengesMade(by: house) < GameState.ringChallenges else { return .challengesSpent }
        return nil
    }

    /// A keeper's line challenges another's: each weighed, with a draw of
    /// the realm's chance a fifth either way; the heavier wins, a tie the
    /// defender's, and takes standing from the loser.
    mutating func challenge(_ defender: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = challengeRefusal(of: defender, as: house) { throw refusal }
        var random = random()
        let challengerWeight = ringWeight(ofLine: house) * random.int(in: 80...120) / 100
        let defenderWeight = ringWeight(ofLine: defender) * random.int(in: 80...120) / 100
        let won = challengerWeight > defenderWeight
        let (winner, loser) = won ? (house, defender) : (defender, house)
        // Standing taken from one higher is the more, from one lower the less.
        let change = min(max(16 + (ringStanding(of: loser) - ringStanding(of: winner)) / 25, 4), 30)
        var kept = ring ?? Ring()
        kept.set(winner, standing: ringStanding(of: winner) + change)
        kept.set(loser, standing: ringStanding(of: loser) - change)
        let bout = Ring.Bout(watch: watch, challenger: house, defender: defender, challengerWeight: challengerWeight,
                             defenderWeight: defenderWeight, won: won, change: change)
        kept.bouts = Array((kept.bouts + [bout]).suffix(GameState.boutsKept))
        ring = kept
        return [.bout(bout)]
    }

    /// The keepers' Houses of the Ring by standing, the highest first, ties
    /// by the House's place.
    public var ringRanks: [Int] {
        guard let ring else { return [] }
        return ring.entries.map(\.house).filter(isKeeper).sorted { a, b in
            let first = ringStanding(of: a), second = ringStanding(of: b)
            return first != second ? first > second : a < b
        }
    }

    /// At each full moon: the three standing highest are honoured with
    /// moonsalt, and every standing drifts halfway back to the start.
    mutating func turnTheRing() -> [GameEvent] {
        guard var kept = ring, !kept.entries.isEmpty, GameState.moonAge(at: watch) == 0 else { return [] }
        let honoured = Array(ringRanks.prefix(GameState.ringHonours.count))
        for (place, house) in honoured.enumerated() {
            store(Stock(moonsalt: GameState.ringHonours[place]), for: house)
        }
        for index in kept.entries.indices {
            kept.entries[index].standing = GameState.ringStart + (kept.entries[index].standing - GameState.ringStart) / 2
        }
        ring = kept
        return honoured.isEmpty ? [] : [.ringHonoured(houses: honoured)]
    }
}
