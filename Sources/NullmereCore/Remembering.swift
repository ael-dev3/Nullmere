import Foundation

/// The Remembering: at each half moon, the lake sets every keeper's House
/// a riddle of the realm's own past, a line of its Chronicle or of the age
/// drowned beneath it with one House's name taken out, and four Houses'
/// names to choose from. Answered rightly before the next is set, it
/// brings moonsalt; a House answers each riddle once. The realm draws each
/// riddle from its own record, by the moon and the House, and judges it;
/// in a keeper's view the answer is kept until the riddle is answered.
/// Rise of Kingdoms' Lyceum asks of the world's lore; the Remembering asks
/// of what its keepers did. Stewards are set none, so a world of stewards
/// goes as it always did.
public struct Riddle: Codable, Equatable, Sendable {
    /// The keeper's House it is set for.
    public let house: Int
    /// The watch it was set.
    public let set: Int
    /// The line it asks of, with the name taken out.
    public let line: String
    /// The names to choose from, in the order shown.
    public let choices: [String]
    /// The name taken out: in a keeper's view, kept until it is answered.
    public internal(set) var answer: String?
    /// The name the House chose, once it has answered.
    public internal(set) var answered: String?

    public init(house: Int, set: Int, line: String, choices: [String], answer: String?, answered: String? = nil) {
        self.house = house
        self.set = set
        self.line = line
        self.choices = choices
        self.answer = answer
        self.answered = answered
    }

    /// Whether it was answered rightly.
    public var isRight: Bool { answered != nil && answered == answer }

    /// How it stands, in a line, on the Mac and the phone: set and what it
    /// brings, weighed, rightly remembered, or not.
    public var standingSaid: String {
        guard let answered else {
            return "Set at watch \(set): answer it rightly before the next half moon for \(GameState.riddleReward)."
        }
        // The answer is the realm's to tell; until it does, it weighs.
        guard let answer else { return "You said \(answered); the lake weighs your answer." }
        if isRight { return "Rightly remembered: it was \(answered)." }
        return "You said \(answered); it was \(answer)."
    }
}

extension GameState {
    /// The moon's ages at which riddles are set: its two halves.
    public static let riddleMoons: Set<Int> = [7, 22]
    /// What a riddle rightly answered brings.
    public static let riddleReward = Stock(moonsalt: 15)
    /// How old a line must be, in watches, to be asked of.
    public static let riddleAge = 3
    /// The Chronicle's kinds a riddle asks of: what Houses did.
    static let remembered: Set<ChronicleEntry.Kind> = [.founding, .war, .peace, .pact, .betrayal, .capture, .fall, .greatWork, .tribute]

    /// A keeper's House's riddle now, if it has one.
    public func riddle(of house: Int) -> Riddle? {
        riddles?.first { $0.house == house }
    }

    /// The riddle the lake would set a House now, if the realm's past holds
    /// one: a line of the Chronicle at least three watches old naming a
    /// House it could be told from, or a hold of the drowned age; and four
    /// names to choose from, the true one among them.
    func riddle(for house: Int) -> Riddle? {
        let titles = houses.map(\.title)
        return riddle(for: house, titles: titles, lines: rememberedLines(titles: titles))
    }

    /// The lines of the Chronicle a riddle could ask of now, and the House
    /// each names: the same for every House, so sought once for all the
    /// riddles a half moon sets, not through the whole Chronicle for each.
    func rememberedLines(titles: [String]) -> [(entry: Int, named: Int)] {
        var lines: [(entry: Int, named: Int)] = []
        for (index, entry) in chronicle.enumerated()
        where GameState.remembered.contains(entry.kind) && entry.watch + GameState.riddleAge <= watch {
            if let named = entry.houses.first(where: { titles.indices.contains($0) && entry.text.contains(titles[$0]) }) {
                lines.append((index, named))
            }
        }
        return lines
    }

    /// The riddle the lake would set a House now, from the lines that could
    /// be asked of (`rememberedLines`).
    private func riddle(for house: Int, titles: [String], lines: [(entry: Int, named: Int)]) -> Riddle? {
        var random = SeededRandom(seed: Seed.mix(settings.seed, UInt64(watch), UInt64(house) &+ 700))
        let drownedNames = Array(Set(drownedHolds.map(\.house))).sorted()
        let drowned = drownedNames.count >= 4 ? drownedHolds : []
        guard lines.count + drowned.count > 0 else { return nil }
        let pick = random.int(below: lines.count + drowned.count)
        let line: String, answer: String, names: [String]
        if pick < lines.count {
            let entry = chronicle[lines[pick].entry]
            answer = titles[lines[pick].named]
            line = "In the \(ordinal(entry.watch)) watch: " + entry.text.replacingOccurrences(of: answer, with: "———")
            names = titles
        } else {
            let hold = drowned[pick - lines.count]
            answer = hold.house
            line = "In the \(ordinal(hold.age)) age, ——— held \(hold.name), drowned now where it stood."
            names = drownedNames
        }
        var others = Array(Set(names.filter { $0 != answer })).sorted()
        guard others.count >= 3 else { return nil }
        random.shuffle(&others)
        var choices = [answer] + others.prefix(3)
        random.shuffle(&choices)
        return Riddle(house: house, set: watch, line: line, choices: choices, answer: answer)
    }

    /// At each half moon, a riddle for every keeper's House, the last one
    /// set it put away.
    mutating func setRiddles() -> [GameEvent] {
        guard GameState.riddleMoons.contains(GameState.moonAge(at: watch)) else { return [] }
        let keepers = houses.filter { $0.isPlayer && !$0.isEliminated }.map(\.id)
        let titles = houses.map(\.title)
        let lines = keepers.isEmpty ? [] : rememberedLines(titles: titles)
        let set = keepers.compactMap { riddle(for: $0, titles: titles, lines: lines) }
        guard !set.isEmpty || riddles != nil else { return [] }
        riddles = set.isEmpty ? nil : set
        return set.map { .riddleSet(house: $0.house) }
    }

    /// Why a House can't answer its riddle with this name now, if it can't.
    public func riddleRefusal(_ name: String, as house: Int) -> RuleError? {
        guard let riddle = riddle(of: house) else { return .notApplicable }
        guard riddle.answered == nil else { return .answeredAlready }
        guard riddle.choices.contains(name) else { return .notApplicable }
        return nil
    }

    /// A keeper answers their House's riddle: rightly, for moonsalt.
    mutating func answerRiddle(_ name: String, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = riddleRefusal(name, as: house) { throw refusal }
        guard var kept = riddles, let index = kept.firstIndex(where: { $0.house == house }) else { throw .notApplicable }
        kept[index].answered = name
        riddles = kept
        let right = kept[index].isRight
        if right { store(GameState.riddleReward, for: house) }
        return [.riddleAnswered(house: house, right: right, answer: kept[index].answer ?? name)]
    }
}
