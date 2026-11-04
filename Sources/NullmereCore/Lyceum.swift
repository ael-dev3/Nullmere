/// The Lyceum (after Rise of Kingdoms' Lyceum of Wisdom): twice in every
/// ten watches the realm's scholars sit, and every keeper's House is set
/// the same five questions on the lore of the lake: its studies, its
/// items, its omens. Each House answers each once, and its answers are its
/// own until the Lyceum rises; then the realm judges them all, pays
/// moonsalt for every answer right and more to the three Houses that
/// answered best, and tells the whole realm how each House stood.
public enum Lyceum {
    /// It sits this many watches in every `every`.
    public static let every = 10
    public static let sits = 2
    public static let questions = 5
    /// Moonsalt for each answer right, and the first three's prizes.
    public static let perAnswer = 4
    public static let prizes = [20, 12, 6]

    /// Which sitting a watch falls in, if the Lyceum sits then.
    public static func sitting(at watch: Int) -> Int? {
        watch % every < sits ? watch / every : nil
    }
}

/// A question the Lyceum sets: four answers, one of them right.
public struct LyceumQuestion: Codable, Equatable, Sendable {
    public let text: String
    public let choices: [String]
    public let answer: Int
}

/// How a House stood when the Lyceum rose.
public struct LyceumStanding: Codable, Equatable, Sendable {
    public let house: Int
    public let right: Int
    public let moonsalt: Int
}

extension GameState {
    /// The questions of a sitting: the same for every House, drawn from the
    /// realm's seed.
    public func lyceumQuestions(sitting: Int) -> [LyceumQuestion] {
        var random = SeededRandom(seed: Seed.mix(settings.seed, 8_800, UInt64(sitting)))
        let lore: [[(title: String, effect: String)]] = [
            Study.allCases.map { ($0.title, $0.effect) },
            ItemKind.allCases.map { ($0.title, $0.effect) },
            OmenKind.allCases.map { ($0.title, $0.effect) },
        ]
        let asks = ["Which study gives this?", "Which item does this?", "Which omen brings this?"]
        var questions: [LyceumQuestion] = []
        var asked = Set<String>()
        while questions.count < Lyceum.questions {
            let kind = random.int(below: lore.count)
            let pool = lore[kind]
            guard pool.count >= 4 else { continue }
            let right = random.pick(pool)
            guard asked.insert(right.title).inserted else { continue }
            var wrong = pool.filter { $0.title != right.title }
            var choices = [right.title]
            while choices.count < 4 {
                let other = wrong.remove(at: random.int(below: wrong.count))
                choices.append(other.title)
            }
            // The right answer among the four by the draw, not always first.
            let at = random.int(below: 4)
            choices.swapAt(0, at)
            questions.append(LyceumQuestion(text: "\(asks[kind]) \u{201C}\(right.effect)\u{201D}", choices: choices, answer: at))
        }
        return questions
    }

    /// The questions sitting now, if the Lyceum sits: set in the world as
    /// it opens, so every keeper's view, which holds no seed, reads them.
    public var lyceumNow: [LyceumQuestion]? {
        Lyceum.sitting(at: watch) != nil ? lyceumSet : nil
    }

    /// The Lyceum opens: its questions set for every House to read.
    mutating func openLyceum() {
        guard let sitting = Lyceum.sitting(at: watch) else { return }
        lyceumSet = lyceumQuestions(sitting: sitting)
        lyceumBook = nil
        if lyceumHall == nil { lyceumHall = lyceumHallSite() }
    }

    /// Whether the Lyceum's hall is lit: while its scholars sit.
    public var lyceumHallLit: Bool { lyceumHall != nil && lyceumNow != nil }

    /// Where the Lyceum's hall is raised: the open land nearest the lake's
    /// heart, no hold, shrine or lair upon it, on no House's ground.
    func lyceumHallSite() -> Hex? {
        let taken = Set(holds.map(\.position) + (shrines ?? []).map(\.position) + (lairs ?? []).map(\.position))
        let land = territory()
        return Hex(0, 0).spiral(map.radius).first { hex in
            guard let tile = map[hex], !tile.terrain.isWater, tile.terrain.isPassable, !taken.contains(hex) else { return false }
            return territoryOwner(of: hex, in: land) == nil
        }
    }

    /// A House's answers this sitting, by question; nil where unanswered.
    public func lyceumAnswers(of house: Int) -> [Int?] {
        let given = lyceumBook?[house] ?? []
        return (0..<Lyceum.questions).map { index in index < given.count && given[index] >= 0 ? given[index] : nil }
    }

    /// Why a House can't give that answer now, if it can't.
    public func lyceumRefusal(question: Int, choice: Int, as house: Int) -> RuleError? {
        // Every House standing sits it, the stewards' as the keepers'.
        guard houses.indices.contains(house), !houses[house].isEliminated else { return .notAKeeper }
        guard lyceumNow != nil else { return .lyceumNotSitting }
        guard (0..<Lyceum.questions).contains(question), (0..<4).contains(choice) else { return .lyceumNoSuchAnswer }
        guard lyceumAnswers(of: house)[question] == nil else { return .lyceumAnswered }
        return nil
    }

    /// A House answers a question of the sitting Lyceum: kept as its own.
    mutating func answerLyceum(question: Int, choice: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = lyceumRefusal(question: question, choice: choice, as: house) { throw refusal }
        var given = lyceumBook?[house] ?? Array(repeating: -1, count: Lyceum.questions)
        while given.count < Lyceum.questions { given.append(-1) }
        given[question] = choice
        var book = lyceumBook ?? [:]
        book[house] = given
        lyceumBook = book
        return [.lyceumAnswered(house: house, question: question)]
    }

    /// As the watch turns: the Lyceum that sat until now rises and judges
    /// every House that answered, paid in moonsalt, the standings told to all.
    mutating func turnLyceum() -> [GameEvent] {
        if watch % Lyceum.every == 0 { openLyceum() }
        guard watch % Lyceum.every == Lyceum.sits, let questions = lyceumSet else { return [] }
        let book = lyceumBook ?? [:]
        lyceumSet = nil
        lyceumBook = nil
        guard !book.isEmpty else { return [] }
        var scored: [(house: Int, right: Int)] = book.keys.sorted().compactMap { house in
            guard houses.indices.contains(house), !houses[house].isEliminated else { return nil }
            let given = book[house] ?? []
            let right = questions.indices.filter { $0 < given.count && given[$0] == questions[$0].answer }.count
            return (house, right)
        }
        scored.sort { ($0.right, -$0.house) > ($1.right, -$1.house) }
        var standings: [LyceumStanding] = []
        for (place, entry) in scored.enumerated() {
            let prize = entry.right > 0 && place < Lyceum.prizes.count ? Lyceum.prizes[place] : 0
            let paid = entry.right * Lyceum.perAnswer + prize
            if paid > 0 { store(Stock(moonsalt: paid), for: entry.house) }
            standings.append(LyceumStanding(house: entry.house, right: entry.right, moonsalt: paid))
        }
        if let first = standings.first, first.right > 0 {
            record(.happening, [first.house], "The Lyceum rises: \(houses[first.house].title) answered best, \(first.right) of \(Lyceum.questions).")
        }
        return [.lyceumJudged(standings: standings)]
    }
}
